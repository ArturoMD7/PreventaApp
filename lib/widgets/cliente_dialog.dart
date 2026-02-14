import 'package:flutter/material.dart';
import 'package:refrescos_app/models/cliente.dart';

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

  @override
  void initState() {
    super.initState();
    _nombre = widget.cliente?.nombre ?? '';
    _telefono = widget.cliente?.telefono;
    _direccion = widget.cliente?.direccion;
  }

  void _guardar() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final cliente = Cliente(
        id: widget.cliente?.id,
        nombre: _nombre,
        telefono: _telefono,
        direccion: _direccion,
      );

      Navigator.of(context).pop(cliente); // Devuelve el cliente al showDialog
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
                decoration: const InputDecoration(labelText: "Dirección"),
                onSaved: (value) => _direccion = value,
              ),
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
