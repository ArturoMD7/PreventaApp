import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:refrescos_app/services/database_helper.dart';
import 'package:refrescos_app/services/sync_service.dart';
import 'package:refrescos_app/models/cliente.dart';
import 'package:refrescos_app/models/categoria.dart';
import 'package:refrescos_app/models/producto.dart';
import 'package:refrescos_app/models/venta.dart';
import 'package:refrescos_app/models/detalle_venta.dart';
import 'package:refrescos_app/models/credito.dart';
import 'package:refrescos_app/models/prestamo.dart';
import 'package:refrescos_app/models/negocio.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  String get _userId {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');
    return user.id;
  }

  void _triggerSync() {
    // Al escribir localmente, intentamos hacer push si hay red.
    SyncService().syncAll();
  }

  // ---- Negocio ----
  Future<Negocio?> getNegocio() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('negocios', where: 'id = ?', whereArgs: [_userId]);
    if (maps.isNotEmpty) {
      return Negocio(
        id: maps.first['id'],
        nombreNegocio: maps.first['nombre_negocio'],
        ticketHeader: maps.first['ticket_header'],
        ticketFooter: maps.first['ticket_footer'],
      );
    }
    return null;
  }

  Future<void> updateNegocio(Negocio negocio) async {
    final db = await _dbHelper.database;
    final map = {
      'id': _userId,
      'nombre_negocio': negocio.nombreNegocio,
      'ticket_header': negocio.ticketHeader,
      'ticket_footer': negocio.ticketFooter,
      'sync_status': 1
    };
    await db.insert('negocios', map, conflictAlgorithm: ConflictAlgorithm.replace);
    _triggerSync();
  }

  // ---- Clientes ----
  Future<List<Cliente>> getClientes() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('clientes', where: 'user_id = ?', whereArgs: [_userId], orderBy: 'nombre');
    return maps.map((e) => Cliente.fromMap(e)).toList();
  }

  Future<void> insertCliente(Cliente cliente) async {
    final db = await _dbHelper.database;
    final map = cliente.toMap();
    map['id'] = _uuid.v4();
    map['sync_status'] = 1;
    await db.insert('clientes', map);
    _triggerSync();
  }

  Future<void> updateCliente(Cliente cliente) async {
    final db = await _dbHelper.database;
    final map = cliente.toMap();
    map['sync_status'] = 1;
    await db.update('clientes', map, where: 'id = ?', whereArgs: [cliente.id]);
    _triggerSync();
  }

  // ---- Categorías ----
  Future<List<Categoria>> getCategorias() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('categorias', where: 'user_id = ?', whereArgs: [_userId], orderBy: 'nombre');
    return maps.map((e) => Categoria.fromMap(e)).toList();
  }

  // ---- Productos ----
  Future<List<Producto>> getProductos() async {
    final db = await _dbHelper.database;
    // Hacemos JOIN local para traer el nombre de la categoría
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, c.nombre as categoria_nombre 
      FROM productos p 
      LEFT JOIN categorias c ON p.categoria_id = c.id 
      WHERE p.user_id = ? 
      ORDER BY p.nombre
    ''', [_userId]);
    return maps.map((e) => Producto.fromMap(e)).toList();
  }

  Future<void> insertProducto(Producto p) async {
    final db = await _dbHelper.database;
    final map = p.toMap();
    map['id'] = _uuid.v4();
    map['sync_status'] = 1;
    await db.insert('productos', map);
    _triggerSync();
  }

  Future<void> updateProducto(Producto p) async {
    final db = await _dbHelper.database;
    final map = p.toMap();
    map['sync_status'] = 1;
    await db.update('productos', map, where: 'id = ?', whereArgs: [p.id]);
    _triggerSync();
  }

  // ---- Ventas ----
  Future<List<Venta>> getVentas() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT v.*, c.nombre as cliente_nombre 
      FROM ventas v 
      LEFT JOIN clientes c ON v.cliente_id = c.id 
      WHERE v.user_id = ? 
      ORDER BY v.fecha DESC
    ''', [_userId]);
    return maps.map((e) => Venta.fromMap(e)).toList();
  }

  Future<Venta> insertVenta(Venta v, List<DetalleVenta> detalles) async {
    final db = await _dbHelper.database;
    final ventaId = _uuid.v4();
    
    final ventaMap = v.toMap();
    ventaMap['id'] = ventaId;
    ventaMap['sync_status'] = 1;

    await db.transaction((txn) async {
      await txn.insert('ventas', ventaMap);
      for (var d in detalles) {
        final dMap = d.toMap();
        dMap['id'] = _uuid.v4();
        dMap['venta_id'] = ventaId;
        dMap['sync_status'] = 1;
        await txn.insert('detalles_venta', dMap);
      }
    });

    _triggerSync();
    
    // Devolver la venta con el ID real local
    final insertedMap = Map<String, dynamic>.from(ventaMap);
    insertedMap['cliente_nombre'] = v.clienteNombre; // Preservar para la UI actual
    return Venta.fromMap(insertedMap);
  }

  Future<void> updateEstadoVenta(String id, String estado) async {
    final db = await _dbHelper.database;
    final Map<String, dynamic> updateData = {'estado': estado, 'sync_status': 1};
    if (estado == 'entregado') {
      updateData['fecha_entrega'] = DateTime.now().toIso8601String();
    } else if (estado == 'pendiente') {
      updateData['fecha_entrega'] = null;
    }
    await db.update('ventas', updateData, where: 'id = ?', whereArgs: [id]);
    _triggerSync();
  }

  Future<List<DetalleVenta>> getDetallesVenta(String ventaId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT d.*, p.nombre as producto_nombre 
      FROM detalles_venta d 
      LEFT JOIN productos p ON d.producto_id = p.id 
      WHERE d.venta_id = ?
    ''', [ventaId]);
    return maps.map((e) => DetalleVenta.fromMap(e)).toList();
  }

  // ---- Créditos ----
  Future<List<Credito>> getCreditos() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT cr.*, c.nombre as cliente_nombre 
      FROM creditos cr 
      LEFT JOIN clientes c ON cr.cliente_id = c.id 
      WHERE cr.user_id = ? 
      ORDER BY cr.fecha DESC
    ''', [_userId]);
    return maps.map((e) => Credito.fromMap(e)).toList();
  }

  Future<void> insertCredito(Credito c) async {
    final db = await _dbHelper.database;
    final map = c.toMap();
    map['id'] = _uuid.v4();
    map['sync_status'] = 1;
    await db.insert('creditos', map);
    _triggerSync();
  }

  Future<void> updateSaldoCredito(String id, double nuevoSaldo) async {
    final db = await _dbHelper.database;
    await db.update('creditos', {'saldo_pendiente': nuevoSaldo, 'sync_status': 1}, where: 'id = ?', whereArgs: [id]);
    _triggerSync();
  }

  // ---- Préstamos (Envases) ----
  Future<List<Prestamo>> getPrestamos() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, c.nombre as cliente_nombre 
      FROM prestamos p 
      LEFT JOIN clientes c ON p.cliente_id = c.id 
      WHERE p.user_id = ? 
      ORDER BY p.fecha_prestamo DESC
    ''', [_userId]);
    return maps.map((e) => Prestamo.fromMap(e)).toList();
  }

  Future<void> insertPrestamo(Prestamo p) async {
    final db = await _dbHelper.database;
    final map = p.toMap();
    map['id'] = _uuid.v4();
    map['sync_status'] = 1;
    await db.insert('prestamos', map);
    _triggerSync();
  }

  Future<void> updateDevolucionPrestamo(String id, DateTime fechaDevolucion) async {
    final db = await _dbHelper.database;
    await db.update('prestamos', {
      'fecha_devolucion': fechaDevolucion.toIso8601String(),
      'sync_status': 1
    }, where: 'id = ?', whereArgs: [id]);
    _triggerSync();
  }

  // ---- Deletions (Direct to Supabase + Local Delete) ----

  /// Intenta refrescar la sesión de Supabase antes de operaciones directas.
  Future<void> _refreshSessionIfNeeded() async {
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {}
  }

  Future<void> deleteCliente(String id) async {
    final db = await _dbHelper.database;
    await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
    await _refreshSessionIfNeeded();
    try { await Supabase.instance.client.from('clientes').delete().eq('id', id); } catch (e) {
      print('Error eliminando cliente de Supabase: $e');
    }
  }

  Future<void> insertCategoria(Categoria cat) async {
    final db = await _dbHelper.database;
    final map = cat.toMap();
    map['id'] = _uuid.v4();
    map['sync_status'] = 1;
    await db.insert('categorias', map);
    _triggerSync();
  }

  Future<void> deleteProducto(String id) async {
    final db = await _dbHelper.database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
    await _refreshSessionIfNeeded();
    try { await Supabase.instance.client.from('productos').delete().eq('id', id); } catch (e) {
      print('Error eliminando producto de Supabase: $e');
    }
  }

  Future<void> deleteVenta(String id) async {
    final db = await _dbHelper.database;
    await db.delete('ventas', where: 'id = ?', whereArgs: [id]);
    await _refreshSessionIfNeeded();
    try { await Supabase.instance.client.from('ventas').delete().eq('id', id); } catch (e) {
      print('Error eliminando venta de Supabase: $e');
    }
  }

  Future<void> deleteCredito(String id) async {
    final db = await _dbHelper.database;
    await db.delete('creditos', where: 'id = ?', whereArgs: [id]);
    await _refreshSessionIfNeeded();
    try { await Supabase.instance.client.from('creditos').delete().eq('id', id); } catch (e) {
      print('Error eliminando crédito de Supabase: $e');
    }
  }

  Future<void> deletePrestamo(String id) async {
    final db = await _dbHelper.database;
    await db.delete('prestamos', where: 'id = ?', whereArgs: [id]);
    await _refreshSessionIfNeeded();
    try { await Supabase.instance.client.from('prestamos').delete().eq('id', id); } catch (e) {
      print('Error eliminando préstamo de Supabase: $e');
    }
  }
}
