import 'package:flutter/material.dart';
import 'package:refrescos_app/database/database_helper.dart';
import 'package:intl/intl.dart';

class CorteScreen extends StatefulWidget {
  @override
  _CorteScreenState createState() => _CorteScreenState();
}

class _CorteScreenState extends State<CorteScreen> {
  double _totalVentas = 0.0;
  double _totalCostos = 0.0;
  double _ganancias = 0.0;
  int _ventasCount = 0;
  int _ventasDescartadasCount = 0;
  DateTime _fechaSeleccionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargarCorte();
  }

  // En corte_screen.dart
Future<void> _cargarCorte() async {
  final dbHelper = DatabaseHelper();
  
  // Formatear fecha para consulta
  final fechaFormateada = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
  
  // Obtener ventas ENTREGADAS en la fecha seleccionada (usando fecha_entrega)
  final ventas = await dbHelper.database.then((db) => db.rawQuery('''
    SELECT v.*, SUM(dv.cantidad * p.costo) as total_costos
    FROM ventas v
    JOIN detalles_venta dv ON v.id = dv.venta_id
    JOIN productos p ON dv.producto_id = p.id
    WHERE date(v.fecha_entrega) = ? -- ¡IMPORTANTE! Usar fecha_entrega, no fecha
    GROUP BY v.id
  ''', [fechaFormateada]));
  
  // Calcular totales
  double totalVentas = 0.0;
  double totalCostos = 0.0;
  int ventasCount = 0;
  
  for (var venta in ventas) {
    totalVentas += venta['total'] as double;
    totalCostos += venta['total_costos'] as double;
    ventasCount++;
  }
  
  setState(() {
    _totalVentas = totalVentas;
    _totalCostos = totalCostos;
    _ganancias = totalVentas - totalCostos;
    _ventasCount = ventasCount;
  });
}

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = picked;
      });
      _cargarCorte();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Corte de Caja')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: Text('Seleccionar Fecha'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaSeleccionada)),
              trailing: IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () => _seleccionarFecha(context),
              ),
            ),
            Divider(),
            Card(
              child: ListTile(
                title: Text('Total Ventas'),
                trailing: Text('\$${_totalVentas.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            Card(
              child: ListTile(
                title: Text('Total Costos'),
                trailing: Text('\$${_totalCostos.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
            Card(
              color: _ganancias >= 0 ? Colors.green[100] : Colors.red[100],
              child: ListTile(
                title: Text('Ganancias'),
                trailing: Text('\$${_ganancias.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _ganancias >= 0 ? Colors.green : Colors.red)),
              ),
            ),
            Card(
              child: ListTile(
                title: Text('Número de Ventas'),
                subtitle: _ventasDescartadasCount > 0 
                  ? Text('$_ventasDescartadasCount descartadas')
                  : null,
                trailing: Text('$_ventasCount',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_ventasDescartadasCount > 0)
              Card(
                color: Colors.orange[100],
                child: ListTile(
                  leading: Icon(Icons.info, color: Colors.orange[800]),
                  title: Text('Incluye $_ventasDescartadasCount ventas descartadas',
                      style: TextStyle(color: Colors.orange[800])),
                  subtitle: Text('Estas ventas se completaron pero fueron marcadas como descartadas posteriormente'),
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _cargarCorte,
              child: Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}