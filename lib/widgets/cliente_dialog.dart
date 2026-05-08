import 'package:flutter/material.dart';
import 'package:refrescos_app/models/cliente.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:refrescos_app/screens/seleccionar_ubicacion_screen.dart';

class ClienteDialog extends StatefulWidget {
  final Cliente? cliente;

  const ClienteDialog({Key? key, this.cliente}) : super(key: key);

  @override
  _ClienteDialogState createState() => _ClienteDialogState();
}

class _ClienteDialogState extends State<ClienteDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _nombre;
  String? _telefono;
  String? _direccion;
  double? _latitud;
  double? _longitud;

  @override
  void initState() {
    super.initState();
    _nombre = widget.cliente?.nombre ?? '';
    _telefono = widget.cliente?.telefono;
    _direccion = widget.cliente?.direccion;
    _latitud = widget.cliente?.latitud;
    _longitud = widget.cliente?.longitud;
  }

  void _abrirMapa() async {
    LatLng? inicial;
    if (_latitud != null && _longitud != null) {
      inicial = LatLng(_latitud!, _longitud!);
    }

    final LatLng? seleccion = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SeleccionarUbicacionScreen(ubicacionInicial: inicial),
      ),
    );

    if (seleccion != null) {
      setState(() {
        _latitud = seleccion.latitude;
        _longitud = seleccion.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación capturada correctamente'), backgroundColor: Colors.green),
      );
    }
  }

  void _guardar() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final currentUserId = Supabase.instance.client.auth.currentUser!.id;

      final cliente = Cliente(
        id: widget.cliente?.id,
        userId: widget.cliente?.userId ?? currentUserId,
        nombre: _nombre,
        telefono: _telefono,
        direccion: _direccion,
        latitud: _latitud,
        longitud: _longitud,
      );

      Navigator.of(context).pop(cliente);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.cliente == null ? "Nuevo Cliente" : "Editar Cliente"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _nombre,
                decoration: const InputDecoration(labelText: "Nombre"),
                validator: (value) =>
                    value == null || value.isEmpty ? "Campo requerido" : null,
                onSaved: (value) => _nombre = value!,
              ),
              TextFormField(
                initialValue: _telefono,
                decoration: const InputDecoration(labelText: "Teléfono"),
                onSaved: (value) => _telefono = value,
              ),
              TextFormField(
                initialValue: _direccion,
                decoration: const InputDecoration(labelText: "Dirección descriptiva"),
                onSaved: (value) => _direccion = value,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _abrirMapa,
                icon: const Icon(Icons.map),
                label: Text(
                  _latitud != null && _longitud != null
                      ? "Cambiar Ubicación Guardada"
                      : "Fijar en Mapa",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _latitud != null ? Colors.green[100] : Colors.blue[50],
                  foregroundColor: _latitud != null ? Colors.green[800] : Colors.blue[800],
                ),
              ),
              if (_latitud != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '📍 Ubicación guardada',
                    style: TextStyle(color: Colors.green[700], fontSize: 12),
                  ),
                )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Cancelar"),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text("Guardar"),
          onPressed: _guardar,
        ),
      ],
    );
  }
}
