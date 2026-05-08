import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'preventa_offline.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE clientes ADD COLUMN latitud REAL');
      await db.execute('ALTER TABLE clientes ADD COLUMN longitud REAL');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Todos llevan sync_status: 0 = sincronizado con Supabase, 1 = pendiente de subir
    
    await db.execute('''
      CREATE TABLE negocios(
        id TEXT PRIMARY KEY,
        nombre_negocio TEXT,
        ticket_header TEXT,
        ticket_footer TEXT,
        sync_status INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE clientes(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        nombre TEXT,
        telefono TEXT,
        direccion TEXT,
        latitud REAL,
        longitud REAL,
        sync_status INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categorias(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        nombre TEXT,
        sync_status INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE productos(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        categoria_id TEXT,
        nombre TEXT,
        costo REAL,
        precio REAL,
        stock INTEGER,
        sync_status INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ventas(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        cliente_id TEXT,
        total REAL,
        estado TEXT,
        fecha TEXT,
        fecha_entrega TEXT,
        sync_status INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE detalles_venta(
        id TEXT PRIMARY KEY,
        venta_id TEXT,
        producto_id TEXT,
        cantidad INTEGER,
        precio_unitario REAL,
        subtotal REAL,
        sync_status INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE creditos(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        cliente_id TEXT,
        monto_total REAL,
        saldo_pendiente REAL,
        estado TEXT,
        fecha TEXT,
        sync_status INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE prestamos(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        cliente_id TEXT,
        descripcion TEXT,
        cantidad INTEGER,
        estado TEXT,
        fecha_prestamo TEXT,
        fecha_devolucion TEXT,
        sync_status INTEGER DEFAULT 0
      )
    ''');
  }

  // Utilidad para limpiar toda la base local (usada al cerrar sesión o resincronizar masivamente)
  Future<void> clearAllTables() async {
    final db = await database;
    await db.execute('DELETE FROM detalles_venta');
    await db.execute('DELETE FROM ventas');
    await db.execute('DELETE FROM prestamos');
    await db.execute('DELETE FROM creditos');
    await db.execute('DELETE FROM productos');
    await db.execute('DELETE FROM categorias');
    await db.execute('DELETE FROM clientes');
    await db.execute('DELETE FROM negocios');
  }
}
