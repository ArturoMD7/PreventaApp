import 'package:flutter/foundation.dart' show kIsWeb;
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
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');
    return user.id;
  }

  void _triggerSync() {
    if (kIsWeb) return;
    SyncService().syncAll();
  }

  // ---- Negocio ----
  Future<Negocio?> getNegocio() async {
    if (kIsWeb) {
      try {
        final data = await _supabase
            .from('negocios')
            .select()
            .eq('id', _userId)
            .single();
        return Negocio.fromMap(data);
      } catch (_) {
        return null;
      }
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db!.query('negocios', where: 'id = ?', whereArgs: [_userId]);
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
    if (kIsWeb) {
      await _supabase.from('negocios').upsert({
        'id': _userId,
        'nombre_negocio': negocio.nombreNegocio,
        'ticket_header': negocio.ticketHeader,
        'ticket_footer': negocio.ticketFooter,
      });
      return;
    }

    final db = await _dbHelper.database;
    final map = {
      'id': _userId,
      'nombre_negocio': negocio.nombreNegocio,
      'ticket_header': negocio.ticketHeader,
      'ticket_footer': negocio.ticketFooter,
      'sync_status': 1
    };
    await db!.insert('negocios', map, conflictAlgorithm: ConflictAlgorithm.replace);
    _triggerSync();
  }

  // ---- Clientes ----
  Future<List<Cliente>> getClientes() async {
    if (kIsWeb) {
      final data = await _supabase
          .from('clientes')
          .select()
          .eq('user_id', _userId)
          .order('nombre');
      return data.map((e) => Cliente.fromMap(e)).toList();
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db!.query('clientes', where: 'user_id = ?', whereArgs: [_userId], orderBy: 'nombre');
    return maps.map((e) => Cliente.fromMap(e)).toList();
  }

  Future<void> insertCliente(Cliente cliente) async {
    if (kIsWeb) {
      final map = cliente.toMap();
      map['id'] = _uuid.v4();
      map['user_id'] = _userId;
      await _supabase.from('clientes').insert(map);
      return;
    }

    final db = await _dbHelper.database;
    final map = cliente.toMap();
    map['id'] = _uuid.v4();
    map['sync_status'] = 1;
    await db!.insert('clientes', map);
    _triggerSync();
  }

  Future<void> updateCliente(Cliente cliente) async {
    if (kIsWeb) {
      await _supabase.from('clientes').update(cliente.toMap()).eq('id', cliente.id as Object);
      return;
    }

    final db = await _dbHelper.database;
    final map = cliente.toMap();
    map['sync_status'] = 1;
    await db!.update('clientes', map, where: 'id = ?', whereArgs: [cliente.id]);
    _triggerSync();
  }

  // ---- Categorías ----
  Future<List<Categoria>> getCategorias() async {
    if (kIsWeb) {
      final data = await _supabase
          .from('categorias')
          .select()
          .eq('user_id', _userId)
          .order('nombre');
      return data.map((e) => Categoria.fromMap(e)).toList();
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db!.query('categorias', where: 'user_id = ?', whereArgs: [_userId], orderBy: 'nombre');
    return maps.map((e) => Categoria.fromMap(e)).toList();
  }

  // ---- Productos ----
  Future<List<Producto>> getProductos() async {
    if (kIsWeb) {
      final data = await _supabase
          .from('productos')
          .select('*, categorias(nombre)')
          .eq('user_id', _userId)
          .order('nombre');
      return data.map((e) => Producto.fromMap(e)).toList();
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db!.rawQuery('''
      SELECT p.*, c.nombre as categoria_nombre 
      FROM productos p 
      LEFT JOIN categorias c ON p.categoria_id = c.id 
      WHERE p.user_id = ? 
      ORDER BY p.nombre
    ''', [_userId]);
    return maps.map((e) => Producto.fromMap(e)).toList();
  }

  Future<void> insertProducto(Producto p) async {
    if (kIsWeb) {
      final map = p.toMap();
      map['id'] = _uuid.v4();
      map['user_id'] = _userId;
      await _supabase.from('productos').insert(map);
      return;
    }

    final db = await _dbHelper.database;
    final map = p.toMap();
    map['id'] = _uuid.v4();
    map['sync_status'] = 1;
    await db!.insert('productos', map);
    _triggerSync();
  }

  Future<void> updateProducto(Producto p) async {
    if (kIsWeb) {
      await _supabase.from('productos').update(p.toMap()).eq('id', p.id as Object);
      return;
    }

    final db = await _dbHelper.database;
    final map = p.toMap();
    map['sync_status'] = 1;
    await db!.update('productos', map, where: 'id = ?', whereArgs: [p.id]);
    _triggerSync();
  }

  // ---- Ventas ----
  Future<List<Venta>> getVentas() async {
    if (kIsWeb) {
      final data = await _supabase
          .from('ventas')
          .select('*, clientes(nombre)')
          .eq('user_id', _userId)
          .order('fecha', ascending: false);
      return data.map((e) => Venta.fromMap(e)).toList();
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db!.rawQuery('''
      SELECT v.*, c.nombre as cliente_nombre 
      FROM ventas v 
      LEFT JOIN clientes c ON v.cliente_id = c.id 
      WHERE v.user_id = ? 
      ORDER BY v.fecha DESC
    ''', [_userId]);
    return maps.map((e) => Venta.fromMap(e)).toList();
  }

  Future<Venta> insertVenta(Venta v, List<DetalleVenta> detalles) async {
    final ventaId = _uuid.v4();

    if (kIsWeb) {
      final ventaMap = v.toMap();
      ventaMap['id'] = ventaId;
      ventaMap['user_id'] = _userId;
      await _supabase.from('ventas').insert(ventaMap);

      for (var d in detalles) {
        final dMap = d.toMap();
        dMap['id'] = _uuid.v4();
        dMap['venta_id'] = ventaId;
        await _supabase.from('detalles_venta').insert(dMap);
      }

      ventaMap['cliente_nombre'] = v.clienteNombre;
      return Venta.fromMap(Map<String, dynamic>.from(ventaMap));
    }

    final db = await _dbHelper.database;
    final ventaMap = v.toMap();
    ventaMap['id'] = ventaId;
    ventaMap['sync_status'] = 1;

    await db!.transaction((txn) async {
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

    final insertedMap = Map<String, dynamic>.from(ventaMap);
    insertedMap['cliente_nombre'] = v.clienteNombre;
    return Venta.fromMap(insertedMap);
  }

  Future<void> updateEstadoVenta(String id, String estado) async {
    if (kIsWeb) {
      final Map<String, dynamic> updateData = {'estado': estado};
      if (estado == 'entregado') {
        updateData['fecha_entrega'] = DateTime.now().toIso8601String();
      } else if (estado == 'pendiente') {
        updateData['fecha_entrega'] = null;
      }
      await _supabase.from('ventas').update(updateData).eq('id', id);
      return;
    }

    final db = await _dbHelper.database;
    final Map<String, dynamic> updateData = {'estado': estado, 'sync_status': 1};
    if (estado == 'entregado') {
      updateData['fecha_entrega'] = DateTime.now().toIso8601String();
    } else if (estado == 'pendiente') {
      updateData['fecha_entrega'] = null;
    }
    await db!.update('ventas', updateData, where: 'id = ?', whereArgs: [id]);
    _triggerSync();
  }

  Future<List<DetalleVenta>> getDetallesVenta(String ventaId) async {
    if (kIsWeb) {
      final data = await _supabase
          .from('detalles_venta')
          .select('*, productos(nombre)')
          .eq('venta_id', ventaId);
      return data.map((e) => DetalleVenta.fromMap(e)).toList();
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db!.rawQuery('''
      SELECT d.*, p.nombre as producto_nombre 
      FROM detalles_venta d 
      LEFT JOIN productos p ON d.producto_id = p.id 
      WHERE d.venta_id = ?
    ''', [ventaId]);
    return maps.map((e) => DetalleVenta.fromMap(e)).toList();
  }

  // ---- Créditos ----
  Future<List<Credito>> getCreditos() async {
    if (kIsWeb) {
      final data = await _supabase
          .from('creditos')
          .select('*, clientes(nombre)')
          .eq('user_id', _userId)
          .order('fecha', ascending: false);
      return data.map((e) => Credito.fromMap(e)).toList();
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db!.rawQuery('''
      SELECT cr.*, c.nombre as cliente_nombre 
      FROM creditos cr 
      LEFT JOIN clientes c ON cr.cliente_id = c.id 
      WHERE cr.user_id = ? 
      ORDER BY cr.fecha DESC
    ''', [_userId]);
    return maps.map((e) => Credito.fromMap(e)).toList();
  }

  Future<void> insertCredito(Credito c) async {
    if (kIsWeb) {
      final map = c.toMap();
      map['id'] = _uuid.v4();
      map['user_id'] = _userId;
      await _supabase.from('creditos').insert(map);
      return;
    }

    final db = await _dbHelper.database;
    final map = c.toMap();
    map['id'] = _uuid.v4();
    map['sync_status'] = 1;
    await db!.insert('creditos', map);
    _triggerSync();
  }

  Future<void> updateSaldoCredito(String id, double nuevoSaldo) async {
    if (kIsWeb) {
      await _supabase.from('creditos').update({'saldo_pendiente': nuevoSaldo}).eq('id', id);
      return;
    }

    final db = await _dbHelper.database;
    await db!.update('creditos', {'saldo_pendiente': nuevoSaldo, 'sync_status': 1},
        where: 'id = ?', whereArgs: [id]);
    _triggerSync();
  }

  // ---- Préstamos (Envases) ----
  Future<List<Prestamo>> getPrestamos() async {
    if (kIsWeb) {
      final data = await _supabase
          .from('prestamos')
          .select('*, clientes(nombre)')
          .eq('user_id', _userId)
          .order('fecha_prestamo', ascending: false);
      return data.map((e) => Prestamo.fromMap(e)).toList();
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db!.rawQuery('''
      SELECT p.*, c.nombre as cliente_nombre 
      FROM prestamos p 
      LEFT JOIN clientes c ON p.cliente_id = c.id 
      WHERE p.user_id = ? 
      ORDER BY p.fecha_prestamo DESC
    ''', [_userId]);
    return maps.map((e) => Prestamo.fromMap(e)).toList();
  }

  Future<void> insertPrestamo(Prestamo p) async {
    if (kIsWeb) {
      final map = p.toMap();
      map['id'] = _uuid.v4();
      map['user_id'] = _userId;
      await _supabase.from('prestamos').insert(map);
      return;
    }

    final db = await _dbHelper.database;
    final map = p.toMap();
    map['id'] = _uuid.v4();
    map['sync_status'] = 1;
    await db!.insert('prestamos', map);
    _triggerSync();
  }

  Future<void> updateDevolucionPrestamo(String id, DateTime fechaDevolucion) async {
    if (kIsWeb) {
      await _supabase
          .from('prestamos')
          .update({'fecha_devolucion': fechaDevolucion.toIso8601String()}).eq('id', id);
      return;
    }

    final db = await _dbHelper.database;
    await db!.update('prestamos', {
      'fecha_devolucion': fechaDevolucion.toIso8601String(),
      'sync_status': 1
    }, where: 'id = ?', whereArgs: [id]);
    _triggerSync();
  }

  // ---- Deletions (supabase directo + local) ----

  Future<void> _refreshSessionIfNeeded() async {
    try {
      await _supabase.auth.refreshSession();
    } catch (_) {}
  }

  Future<void> deleteCliente(String id) async {
    if (!kIsWeb) {
      final db = await _dbHelper.database;
      await db!.delete('clientes', where: 'id = ?', whereArgs: [id]);
    }
    await _refreshSessionIfNeeded();
    try {
      await _supabase.from('clientes').delete().eq('id', id);
    } catch (e) {
      print('Error eliminando cliente de Supabase: $e');
    }
  }

  Future<void> insertCategoria(Categoria cat) async {
    if (kIsWeb) {
      final map = cat.toMap();
      map['id'] = _uuid.v4();
      map['user_id'] = _userId;
      await _supabase.from('categorias').insert(map);
      return;
    }

    final db = await _dbHelper.database;
    final map = cat.toMap();
    map['id'] = _uuid.v4();
    map['sync_status'] = 1;
    await db!.insert('categorias', map);
    _triggerSync();
  }

  Future<void> deleteProducto(String id) async {
    if (!kIsWeb) {
      final db = await _dbHelper.database;
      await db!.delete('productos', where: 'id = ?', whereArgs: [id]);
    }
    await _refreshSessionIfNeeded();
    try {
      await _supabase.from('productos').delete().eq('id', id);
    } catch (e) {
      print('Error eliminando producto de Supabase: $e');
    }
  }

  Future<void> deleteVenta(String id) async {
    if (!kIsWeb) {
      final db = await _dbHelper.database;
      await db!.delete('detalles_venta', where: 'venta_id = ?', whereArgs: [id]);
      await db.delete('ventas', where: 'id = ?', whereArgs: [id]);
    }
    await _refreshSessionIfNeeded();
    try {
      await _supabase.from('detalles_venta').delete().eq('venta_id', id);
      await _supabase.from('ventas').delete().eq('id', id);
    } catch (e) {
      print('Error eliminando venta de Supabase: $e');
    }
  }

  Future<void> deleteCredito(String id) async {
    if (!kIsWeb) {
      final db = await _dbHelper.database;
      await db!.delete('creditos', where: 'id = ?', whereArgs: [id]);
    }
    await _refreshSessionIfNeeded();
    try {
      await _supabase.from('creditos').delete().eq('id', id);
    } catch (e) {
      print('Error eliminando crédito de Supabase: $e');
    }
  }

  Future<void> deletePrestamo(String id) async {
    if (!kIsWeb) {
      final db = await _dbHelper.database;
      await db!.delete('prestamos', where: 'id = ?', whereArgs: [id]);
    }
    await _refreshSessionIfNeeded();
    try {
      await _supabase.from('prestamos').delete().eq('id', id);
    } catch (e) {
      print('Error eliminando préstamo de Supabase: $e');
    }
  }
}
