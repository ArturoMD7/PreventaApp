import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:refrescos_app/services/database_helper.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSyncing = false;

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<void> syncAll() async {
    if (_isSyncing || _userId == null) return;
    
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.every((element) => element == ConnectivityResult.none)) return;

    _isSyncing = true;
    try {
      // Refrescar sesión si está próxima a expirar o ya expiró
      try {
        await _supabase.auth.refreshSession();
      } catch (_) {
        // Si el refresh falla (sesión totalmente inválida), no bloqueamos el sync
        // El usuario deberá volver a iniciar sesión
      }

      await _pushUnsyncedData();
      await _pullRemoteData();
    } catch (e) {
      print('Error durante sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ---- PUSH (Subir a Supabase) ----
  Future<void> _pushUnsyncedData() async {
    final db = await _dbHelper.database;
    final tables = [
      'negocios', 'clientes', 'categorias', 'productos',
      'ventas', 'detalles_venta', 'creditos', 'prestamos'
    ];

    for (String table in tables) {
      final unsyncedRows = await db.query(table, where: 'sync_status = ?', whereArgs: [1]);
      if (unsyncedRows.isEmpty) continue;

      for (var row in unsyncedRows) {
        final Map<String, dynamic> uploadData = Map<String, dynamic>.from(row);
        uploadData.remove('sync_status'); // Supabase no necesita esta columna
        
        try {
          await _supabase.from(table).upsert(uploadData);
          // Si tiene éxito, lo marcamos como sincronizado
          await db.update(table, {'sync_status': 0}, where: 'id = ?', whereArgs: [row['id']]);
        } catch (e) {
          print('Error subiendo a $table: $e');
        }
      }
    }
  }

  // ---- PULL (Descargar de Supabase) ----
  Future<void> _pullRemoteData() async {
    final db = await _dbHelper.database;

    final tables = [
      'negocios', 'clientes', 'categorias', 'productos',
      'ventas', 'detalles_venta', 'creditos', 'prestamos'
    ];

    for (String table in tables) {
      try {
        List<Map<String, dynamic>> response;
        if (table == 'negocios') {
           response = await _supabase.from(table).select().eq('id', _userId as Object);
        } else if (table == 'detalles_venta') {
           // Los detalles no tienen user_id, debemos traer los de nuestras ventas
           final ventas = await db.query('ventas', columns: ['id']);
           if (ventas.isEmpty) continue;
           final ventaIds = ventas.map((v) => v['id']).toList();
           response = await _supabase.from(table).select().inFilter('venta_id', ventaIds);
        } else {
           response = await _supabase.from(table).select().eq('user_id', _userId as Object);
        }

        await db.transaction((txn) async {
          // Borrar todos los locales que ya estaban sincronizados para dar paso a la versión más nueva
          await txn.delete(table, where: 'sync_status = ?', whereArgs: [0]);
          
          for (var row in response) {
            // Verificar si el registro está modificado localmente y aún no sube
            final localModificado = await txn.query(table, where: 'id = ? AND sync_status = ?', whereArgs: [row['id'], 1]);
            
            if (localModificado.isEmpty) {
              final insertData = Map<String, dynamic>.from(row);
              insertData.remove('created_at');
              insertData['sync_status'] = 0;
              // Para clientes: usar el teléfono real si está disponible
              if (table == 'clientes' &&
                  insertData['telefono_real'] != null &&
                  (insertData['telefono_real'] as String).isNotEmpty) {
                insertData['telefono'] = insertData['telefono_real'];
              }
              await txn.insert(table, insertData,
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        });

        // ── EXTRA: cuando bajamos ventas, asegurarnos de tener los clientes
        //    referenciados (pueden haber sido creados desde la app cliente)
        if (table == 'ventas' && response.isNotEmpty) {
          await _pullClientesReferenciados(db, response);
        }
      } catch (e) {
        print('Error bajando de $table: $e');
      }
    }
  }

  /// Descarga de Supabase los registros de `clientes` referenciados en ventas
  /// que aún no existen en el SQLite local del proveedor.
  Future<void> _pullClientesReferenciados(
      dynamic db, List<Map<String, dynamic>> ventas) async {
    // Recopilar cliente_ids presentes en las ventas
    final clienteIds = ventas
        .where((v) => v['cliente_id'] != null)
        .map((v) => v['cliente_id'] as String)
        .toSet()
        .toList();

    if (clienteIds.isEmpty) return;

    // Filtrar los que ya existen en SQLite
    final List<String> faltantes = [];
    for (final cid in clienteIds) {
      final local = await db.query('clientes', where: 'id = ?', whereArgs: [cid]);
      if (local.isEmpty) faltantes.add(cid);
    }

    if (faltantes.isEmpty) return;

    try {
      final remoteClientes = await _supabase
          .from('clientes')
          .select()
          .inFilter('id', faltantes);

      for (var row in remoteClientes) {
        final insertData = Map<String, dynamic>.from(row);
        insertData.remove('created_at');
        insertData['sync_status'] = 0;
        // Mostrar el teléfono real si existe, de lo contrario dejar el UUID
        if (insertData['telefono_real'] != null &&
            (insertData['telefono_real'] as String).isNotEmpty) {
          insertData['telefono'] = insertData['telefono_real'];
        }
        // Usar replace para que datos actualizados de Supabase sobrescriban el local
        await db.insert('clientes', insertData,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      print('Error jalando clientes referenciados: $e');
    }
  }
}
