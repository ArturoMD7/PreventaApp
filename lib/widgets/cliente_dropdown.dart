import 'package:flutter/material.dart';
import 'package:refrescos_app/database/database_helper.dart';
import 'package:refrescos_app/models/cliente.dart';

// Modifica tu ClienteDropdown para que devuelva más información
class ClienteDropdown extends StatefulWidget {
  final Function(int?, String?) onClienteSelected; // Ahora devuelve ID y nombre
  final int? selectedClienteId;

  const ClienteDropdown({
    Key? key,
    required this.onClienteSelected,
    this.selectedClienteId,
  }) : super(key: key);

  @override
  _ClienteDropdownState createState() => _ClienteDropdownState();
}

class _ClienteDropdownState extends State<ClienteDropdown> {
  List<Cliente> _clientes = [];
  int? _selectedClienteId;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
    _selectedClienteId = widget.selectedClienteId;
  }

  Future<void> _cargarClientes() async {
    final dbHelper = DatabaseHelper();
    final clientes = await dbHelper.getClientes();
    setState(() {
      _clientes = clientes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButtonFormField<int>(
        value: _selectedClienteId,
        decoration: InputDecoration(
          labelText: 'Seleccionar Cliente',
          border: OutlineInputBorder(),
        ),
        items: _clientes.map((Cliente cliente) {
          return DropdownMenuItem<int>(
            value: cliente.id,
            child: Text(cliente.nombre),
          );
        }).toList(),
        onChanged: (int? value) {
          setState(() {
            _selectedClienteId = value;
          });
          
          // Encontrar el cliente seleccionado para obtener su nombre
          final clienteSeleccionado = _clientes.firstWhere(
            (cliente) => cliente.id == value,
            orElse: () => Cliente(id: -1, nombre: ''),
          );
          
          widget.onClienteSelected(value, clienteSeleccionado.nombre);
        },
      ),
    );
  }
}