import 'package:flutter/material.dart';
import 'package:refrescos_app/screens/creditos_envases_screen.dart';
import 'package:refrescos_app/screens/corte_screen.dart';
import 'package:refrescos_app/screens/productos_screen.dart';
import 'package:refrescos_app/screens/tickets_screen.dart';
import 'package:refrescos_app/screens/total_screen.dart';
import 'package:refrescos_app/screens/venta_screen.dart';
import 'package:refrescos_app/screens/clientes_screen.dart';
import 'package:refrescos_app/screens/impresora_screen.dart';
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PreventaAPP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
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
    TotalScreen(),
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PreventaAPP"),
      ),
      body: _bottomNavScreens.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Venta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Productos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.summarize),
            label: 'Total',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menú Opciones',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Clientes"),
              onTap: () => _openDrawerScreen(ClientesScreen()), // 👈 aquí
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text("Corte"),
              onTap: () => _openDrawerScreen(CorteScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text("Créditos / Envases"),
              onTap: () => _openDrawerScreen(CreditosEnvasesScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text("Configurar impresora"),
              onTap: () => _openDrawerScreen(ImpresoraScreen()),
          ),

          ],
        ),
      ),
    );
  }
}
