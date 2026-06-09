import 'package:flutter/material.dart';
import 'package:refrescos_app/services/data_service.dart';
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
  DateTime _fechaSeleccionada = DateTime.now();
  final DataService _dbService = DataService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarCorte();
  }

  Future<void> _cargarCorte() async {
    setState(() => _isLoading = true);
    try {
      final fechaSeleccionadaInicio = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day);
      final fechaSeleccionadaFin = fechaSeleccionadaInicio.add(const Duration(days: 1));

      final ventas = await _dbService.getVentas();
      
      // Filtrar ventas entregadas en la fecha seleccionada
      final ventasDelDia = ventas.where((v) {
        if (v.estado != 'entregado' && v.estado != 'descartado') return false;
        if (v.fechaEntrega == null) return false;
        
        return v.fechaEntrega!.isAfter(fechaSeleccionadaInicio) && 
               v.fechaEntrega!.isBefore(fechaSeleccionadaFin);
      }).toList();

      double totalVentas = 0.0;
      double totalCostos = 0.0;
      
      // Obtener costo de cada producto para el cálculo de costos
      final productos = await _dbService.getProductos();
      final costoProductos = <String, double>{};
      for (var producto in productos) {
        if (producto.id != null) {
          costoProductos[producto.id!] = producto.costo;
        }
      }

      for (var venta in ventasDelDia) {
        totalVentas += venta.total;
        final detalles = await _dbService.getDetallesVenta(venta.id!);

        for (var detalle in detalles) {
          final costoUnitario = costoProductos[detalle.productoId] ?? 0.0;
          totalCostos += costoUnitario * detalle.cantidad;
        }
      }
      
      setState(() {
        _totalVentas = totalVentas;
        _totalCostos = totalCostos;
        _ganancias = totalVentas - totalCostos;
        _ventasCount = ventasDelDia.length;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
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
      appBar: AppBar(title: const Text('Corte de Caja')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: const Text('Seleccionar Fecha'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaSeleccionada)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _seleccionarFecha(context),
              ),
            ),
            const Divider(),
            Card(
              child: ListTile(
                title: const Text('Total Ventas'),
                trailing: Text('\$${_totalVentas.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Total Costos'),
                trailing: Text('\$${_totalCostos.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            Card(
              color: _ganancias >= 0 ? Colors.green[100] : Colors.red[100],
              child: ListTile(
                title: const Text('Ganancias brutas'),
                trailing: Text('\$${_ganancias.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _ganancias >= 0 ? Colors.green : Colors.red)),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Número de Ventas'),
                trailing: Text('$_ventasCount',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _cargarCorte,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
