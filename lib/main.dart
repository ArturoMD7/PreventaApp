import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import 'package:refrescos_app/services/sync_service.dart';
import 'package:refrescos_app/services/database_helper.dart';
import 'package:refrescos_app/screens/login_screen.dart';
import 'package:refrescos_app/screens/venta_screen.dart';
import 'package:refrescos_app/screens/productos_screen.dart';
import 'package:refrescos_app/screens/tickets_screen.dart';
import 'package:refrescos_app/screens/total_screen.dart';
import 'package:refrescos_app/screens/clientes_screen.dart';
import 'package:refrescos_app/screens/corte_screen.dart';
import 'package:refrescos_app/screens/creditos_prestamos_screen.dart';
import 'package:refrescos_app/screens/impresora_screen.dart';
import 'package:refrescos_app/screens/configuracion_screen.dart';
import 'package:refrescos_app/screens/rutas_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // Inicializar Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Inicializar Base de Datos Local
  await DatabaseHelper().database;

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _revisarConectividadInicial();
    _subscription = Connectivity().onConnectivityChanged.listen(_manejarCambioConectividad);
  }

  Future<void> _revisarConectividadInicial() async {
    final result = await Connectivity().checkConnectivity();
    _manejarCambioConectividad(result);
  }

  void _manejarCambioConectividad(List<ConnectivityResult> result) {
    final offline = result.every((element) => element == ConnectivityResult.none);
    
    if (_isOffline && !offline) {
      // Regresó el internet, sincronizar con Supabase
      SyncService().syncAll();
    }

    
    if (mounted) {
      setState(() {
        _isOffline = offline;
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Azul corporativo elegante
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF3B82F6),
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
      ),
      builder: (context, child) {
        return Column(
          children: [
            Expanded(child: child!),
            if (_isOffline)
              Container(
                width: double.infinity,
                color: Colors.red[600],
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Text(
                  'Sin conexión a internet - Modo Local',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        );
      },
      home: Supabase.instance.client.auth.currentUser != null
          ? MainScreen()
          : LoginScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _bottomNavScreens = <Widget>[
    VentaScreen(),
    ProductosScreen(),
    TicketsScreen(),
    RutasScreen(),
    TotalScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Iniciar sincronización al cargar la app principal
    SyncService().syncAll();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openDrawerScreen(Widget screen) {
    Navigator.pop(context); // cerrar drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _signOut() async {
    await Supabase.instance.client.auth.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 'Usuario';
    final userEmail = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Punto de Venta"),
      ),
      body: _bottomNavScreens.elementAt(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Venta'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Productos'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Tickets'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Rutas'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Resumen'),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A),
              ),
              accountName: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(userEmail),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 24, color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text("Clientes"),
                    onTap: () => _openDrawerScreen(ClientesScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: const Text("Corte de Caja"),
                    onTap: () => _openDrawerScreen(CorteScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.credit_card),
                    title: const Text("Créditos / Préstamos"),
                    onTap: () => _openDrawerScreen(CreditosPrestamosScreen()),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("Configuración del Negocio"),
                    onTap: () => _openDrawerScreen(ConfiguracionScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.print),
                    title: const Text("Configurar Impresora"),
                    onTap: () => _openDrawerScreen(ImpresoraScreen()),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red)),
              onTap: _signOut,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
