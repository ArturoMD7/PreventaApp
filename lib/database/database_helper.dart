import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:refrescos_app/models/cliente.dart';
import 'package:refrescos_app/models/marca.dart';
import 'package:refrescos_app/models/producto.dart';
import 'package:refrescos_app/models/venta.dart';
import 'package:refrescos_app/models/detalle_venta.dart';
import 'package:refrescos_app/models/credito.dart';
import 'package:refrescos_app/models/envase.dart';


class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'refrescos_db.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clientes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        telefono TEXT,
        direccion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE marcas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE productos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        marca_id INTEGER,
        costo REAL NOT NULL,
        precio REAL NOT NULL,
        stock INTEGER DEFAULT 0,
        FOREIGN KEY (marca_id) REFERENCES marcas(id)
      )
    ''');

    // En database_helper.dart, modifica la tabla ventas:
    await db.execute('''
      CREATE TABLE ventas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER,
        fecha TEXT NOT NULL,
        fecha_entrega TEXT, -- NUEVO CAMPO
        total REAL NOT NULL,
        estado TEXT DEFAULT 'pendiente',
        FOREIGN KEY (cliente_id) REFERENCES clientes(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE detalles_venta(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER,
        producto_id INTEGER,
        cantidad INTEGER NOT NULL,
        precio_unitario REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (venta_id) REFERENCES ventas(id),
        FOREIGN KEY (producto_id) REFERENCES productos(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE creditos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER,
        monto REAL NOT NULL,
        saldo_pendiente REAL NOT NULL,
        fecha TEXT NOT NULL,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE envases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER,
        producto_id INTEGER,
        cantidad INTEGER NOT NULL,
        fecha_prestamo TEXT NOT NULL,
        fecha_devolucion TEXT,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id),
        FOREIGN KEY (producto_id) REFERENCES productos(id)
      )
    ''');
  }

  // Métodos para Clientes
Future<int> insertCliente(Cliente cliente) async {
  final db = await database;
  return await db.insert('clientes', cliente.toMap());
}

Future<List<Cliente>> getClientes() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query('clientes');
  return List.generate(maps.length, (i) {
    return Cliente.fromMap(maps[i]);
  });
}

Future<int> updateCliente(Cliente cliente) async {
  final db = await database;
  return await db.update(
    'clientes',
    cliente.toMap(),
    where: 'id = ?',
    whereArgs: [cliente.id],
  );
}


// En database_helper.dart
Future<int> updateEstadoVenta(int id, String estado) async {
  final db = await database;
  
  Map<String, dynamic> values = {'estado': estado};
  
  // Si se marca como entregado, registrar la fecha de entrega
  if (estado == 'entregado') {
    values['fecha_entrega'] = DateTime.now().toIso8601String();
  }
  // Si se reactiva desde descartado, limpiar la fecha de entrega
  else if (estado == 'pendiente') {
    values['fecha_entrega'] = null;
  }
  
  return await db.update(
    'ventas',
    values,
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<int> descartarVentasAntiguas(DateTime fechaLimite) async {
  final db = await database;
  return await db.update(
    'ventas',
    {'estado': 'descartado'},
    where: 'fecha < ? AND estado != ?',
    whereArgs: [fechaLimite.toIso8601String(), 'descartado'],
  );
}


Future<int> deleteVenta(int id) async {
  final db = await database;
  
  // Primero eliminar los detalles de venta
  await db.delete(
    'detalles_venta',
    where: 'venta_id = ?',
    whereArgs: [id],
  );
  
  // Luego eliminar la venta
  return await db.delete(
    'ventas',
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<int> deleteCliente(int id) async {
  final db = await database;
  return await db.delete(
    'clientes',
    where: 'id = ?',
    whereArgs: [id],
  );
}

  // Métodos para Marcas
  Future<int> insertMarca(Marca marca) async {
    final db = await database;
    return await db.insert('marcas', marca.toMap());
  }

  Future<List<Marca>> getMarcas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('marcas');
    return List.generate(maps.length, (i) {
      return Marca.fromMap(maps[i]);
    });
  }

  // Métodos para Productos
  Future<int> insertProducto(Producto producto) async {
    final db = await database;
    return await db.insert('productos', producto.toMap());
  }

  Future<List<Producto>> getProductos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('productos');
    return List.generate(maps.length, (i) {
      return Producto.fromMap(maps[i]);
    });
  }

  Future<List<Producto>> getProductosConMarca() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, m.nombre as marca_nombre 
      FROM productos p 
      LEFT JOIN marcas m ON p.marca_id = m.id
    ''');
    return List.generate(maps.length, (i) {
      return Producto.fromMap(maps[i]);
    });
  }

  Future<int> updateProducto(Producto producto) async {
    final db = await database;
    return await db.update(
      'productos',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );
  }

  Future<int> deleteProducto(int id) async {
    final db = await database;
    return await db.delete(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos para Ventas
  Future<int> insertVenta(Venta venta) async {
    final db = await database;
    return await db.insert('ventas', venta.toMap());
  }


Future<List<Venta>> getVentas() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT v.*, c.nombre as cliente_nombre 
    FROM ventas v 
    JOIN clientes c ON v.cliente_id = c.id
    ORDER BY v.fecha DESC
  ''');
  return List.generate(maps.length, (i) {
    return Venta.fromMap(maps[i]);
  });
}


  // Métodos para Detalles de Venta
  Future<int> insertDetalleVenta(DetalleVenta detalle) async {
    final db = await database;
    return await db.insert('detalles_venta', detalle.toMap());
  }

  Future<List<DetalleVenta>> getDetallesVenta(int ventaId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT dv.*, p.nombre as producto_nombre 
      FROM detalles_venta dv 
      JOIN productos p ON dv.producto_id = p.id
      WHERE dv.venta_id = ?
    ''', [ventaId]);
    return List.generate(maps.length, (i) {
      return DetalleVenta.fromMap(maps[i]);
    });
  }

  // Métodos para Créditos
  Future<int> insertCredito(Credito credito) async {
    final db = await database;
    return await db.insert('creditos', credito.toMap());
  }

  Future<List<Credito>> getCreditos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.*, cl.nombre as cliente_nombre 
      FROM creditos c 
      JOIN clientes cl ON c.cliente_id = cl.id
      ORDER BY c.fecha DESC
    ''');
    return List.generate(maps.length, (i) {
      return Credito.fromMap(maps[i]);
    });
  }


  // Métodos para eliminar créditos y envases
  Future<int> deleteCredito(int id) async {
    final db = await database;
    return await db.delete('creditos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteEnvase(int id) async {
    final db = await database;
    return await db.delete('envases', where: 'id = ?', whereArgs: [id]);
  }


  Future<int> updateSaldoCredito(int id, double nuevoSaldo) async {
    final db = await database;
    return await db.update(
      'creditos',
      {'saldo_pendiente': nuevoSaldo},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos para Envases
  Future<int> insertEnvase(Envase envase) async {
    final db = await database;
    return await db.insert('envases', envase.toMap());
  }

  Future<List<Envase>> getEnvases() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, cl.nombre as cliente_nombre, p.nombre as producto_nombre 
      FROM envases e 
      JOIN clientes cl ON e.cliente_id = cl.id
      JOIN productos p ON e.producto_id = p.id
      ORDER BY e.fecha_prestamo DESC
    ''');
    return List.generate(maps.length, (i) {
      return Envase.fromMap(maps[i]);
    });
  }

  Future<int> updateDevolucionEnvase(int id, DateTime fechaDevolucion) async {
    final db = await database;
    return await db.update(
      'envases',
      {'fecha_devolucion': fechaDevolucion.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}