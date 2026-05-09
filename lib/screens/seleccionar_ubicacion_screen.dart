import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class SeleccionarUbicacionScreen extends StatefulWidget {
  final LatLng? ubicacionInicial;

  const SeleccionarUbicacionScreen({Key? key, this.ubicacionInicial}) : super(key: key);

  @override
  _SeleccionarUbicacionScreenState createState() => _SeleccionarUbicacionScreenState();
}

class _SeleccionarUbicacionScreenState extends State<SeleccionarUbicacionScreen> {
  late LatLng _ubicacionActual;
  final MapController _mapController = MapController();
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    // Centro de México por defecto si no hay ubicación inicial
    _ubicacionActual = widget.ubicacionInicial ?? const LatLng(23.6345, -102.5528);
    
    if (widget.ubicacionInicial == null) {
      _obtenerUbicacionActual();
    }
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() {
      _isLoadingLocation = true;
    });

    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están deshabilitados.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Los permisos de ubicación fueron denegados.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Los permisos de ubicación están permanentemente denegados.');
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      final nuevaUbicacion = LatLng(position.latitude, position.longitude);
      setState(() {
        _ubicacionActual = nuevaUbicacion;
      });
      _mapController.move(nuevaUbicacion, 16.0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.orange),
      );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _moverPin(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      _ubicacionActual = latlng;
    });
  }

  void _confirmarUbicacion() {
    Navigator.of(context).pop(_ubicacionActual);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Ubicación'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _ubicacionActual,
              initialZoom: widget.ubicacionInicial != null ? 15.0 : 5.0,
              onTap: _moverPin,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.PreventaAPP',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _ubicacionActual,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Instrucción superpuesta
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _isLoadingLocation 
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Obteniendo tu ubicación actual...')
                      ],
                    )
                  : const Text(
                      'Toca cualquier punto en el mapa para colocar el marcador en la ubicación del cliente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
              ),
            ),
          ),
          // Botón confirmar
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              onPressed: _confirmarUbicacion,
              icon: const Icon(Icons.check),
              label: const Text('Confirmar Ubicación', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          )
        ],
      ),
    );
  }
}
