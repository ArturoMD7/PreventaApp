import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:refrescos_app/services/data_service.dart';
import 'package:refrescos_app/models/cliente.dart';
import 'package:refrescos_app/models/venta.dart';

class RutasScreen extends StatefulWidget {
  @override
  _RutasScreenState createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  final DataService _dbService = DataService();
  bool _isLoading = true;
  List<Cliente> _clientesPendientes = [];
  int _totalPedidosPendientes = 0;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _cargarRutas();
  }

  Future<void> _cargarRutas() async {
    setState(() => _isLoading = true);
    try {
      // 1. Traer ventas pendientes
      final ventas = await _dbService.getVentas();
      final ventasPendientes = ventas.where((v) => v.estado == 'pendiente').toList();
      _totalPedidosPendientes = ventasPendientes.length;

      // 2. Extraer IDs únicos de clientes con entregas pendientes
      final Set<String> idsPendientes = ventasPendientes.map((v) => v.clienteId).whereType<String>().toSet();

      // 3. Traer todos los clientes y filtrar
      final todosClientes = await _dbService.getClientes();
      
      _clientesPendientes = todosClientes.where((c) {
        return idsPendientes.contains(c.id) && c.latitud != null && c.longitud != null;
      }).toList();

      // Ajustar centro del mapa si hay clientes
      if (_clientesPendientes.isNotEmpty) {
        // Un pequeño delay para que el mapa se inicialice primero
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
             _mapController.move(
               LatLng(_clientesPendientes.first.latitud!, _clientesPendientes.first.longitud!), 
               12.0
             );
          } catch (_) {}
        });
      }

    } catch (e) {
      print("Error cargando rutas: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas de Entrega'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarRutas,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(23.6345, -102.5528), // Centro de México default
                  initialZoom: 5.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.PreventaAPP',
                  ),
                  MarkerLayer(
                    markers: _clientesPendientes.map((cliente) {
                      return Marker(
                        point: LatLng(cliente.latitud!, cliente.longitud!),
                        width: 120,
                        height: 60,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue, width: 1),
                              ),
                              child: Text(
                                cliente.nombre,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 30,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              
              // Panel de información inferior
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.delivery_dining, color: Colors.blue[800], size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_totalPedidosPendientes pedidos pendientes',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              Text(
                                '${_clientesPendientes.length} ubicados en el mapa',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
