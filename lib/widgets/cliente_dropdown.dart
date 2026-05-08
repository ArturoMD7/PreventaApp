import 'package:flutter/material.dart';
import 'package:refrescos_app/services/data_service.dart';
import 'package:refrescos_app/models/cliente.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClienteDropdown extends StatefulWidget {
  final Function(String?, String?) onClienteSelected;
  final String? selectedClienteId;

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
  String? _selectedClienteId;
  final DataService _dbService = DataService();

  @override
  void initState() {
    super.initState();
    _cargarClientes();
    _selectedClienteId = widget.selectedClienteId;
  }

  Future<void> _cargarClientes() async {
    try {
      final clientes = await _dbService.getClientes();
      setState(() {
        _clientes = clientes;
      });
    } catch (e) {
      // Ignorar o loguear error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedClienteId,
        decoration: const InputDecoration(
          labelText: 'Seleccionar Cliente',
          border: OutlineInputBorder(),
        ),
        items: _clientes.map((Cliente cliente) {
          return DropdownMenuItem<String>(
            value: cliente.id,
            child: Text(cliente.nombre),
          );
        }).toList(),
        onChanged: (String? value) {
          setState(() {
            _selectedClienteId = value;
          });
          
          final currentUserId = Supabase.instance.client.auth.currentUser!.id;
          final clienteSeleccionado = _clientes.firstWhere(
            (cliente) => cliente.id == value,
            orElse: () => Cliente(id: '', userId: currentUserId, nombre: ''),
          );
          
          widget.onClienteSelected(value, clienteSeleccionado.nombre);
        },
      ),
    );
  }
}
