import 'package:flutter/material.dart';
import 'package:refrescos_app/models/cliente.dart';
import 'package:refrescos_app/database/database_helper.dart';
import 'package:refrescos_app/widgets/cliente_dialog.dart';

class ClientesScreen extends StatefulWidget {
  @override
  _ClientesScreenState createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> _clientes = [];
  List<Cliente> _clientesFiltrados = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
    _searchController.addListener(_filtrarClientes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    setState(() => _isLoading = true);
    final clientes = await _dbHelper.getClientes();
    setState(() {
      _clientes = clientes;
      _clientesFiltrados = clientes;
      _isLoading = false;
    });
  }

  void _filtrarClientes() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _clientesFiltrados = _clientes);
    } else {
      setState(() {
        _clientesFiltrados = _clientes.where((cliente) {
          final nombre = cliente.nombre.toLowerCase();
          final telefono = cliente.telefono?.toLowerCase() ?? '';
          return nombre.contains(query) || telefono.contains(query);
        }).toList();
      });
    }
  }

  // Mostrar diálogo para agregar o editar cliente
  void _mostrarDialogo({Cliente? cliente}) async {
    final resultado = await showDialog<Cliente>(
      context: context,
      builder: (context) => ClienteDialog(cliente: cliente),
    );

    if (resultado != null) {
      if (cliente == null) {
        // Nuevo cliente: insertar en BD
        await _dbHelper.insertCliente(resultado);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente agregado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Cliente existente: actualizar en BD
        await _dbHelper.updateCliente(resultado);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente actualizado correctamente'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      _cargarClientes(); // refrescar lista después de guardar
    }
  }

  // Eliminar cliente con confirmación
  void _eliminarCliente(Cliente cliente) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar cliente'),
        content: Text('¿Estás seguro de que deseas eliminar a ${cliente.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await _dbHelper.deleteCliente(cliente.id!);
      _cargarClientes();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cliente eliminado correctamente'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildClientesList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando clientes...'),
          ],
        ),
      );
    }

    if (_clientesFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No hay clientes registrados'
                  : 'No se encontraron clientes',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            if (_searchController.text.isEmpty)
              Text(
                'Presiona el botón + para agregar el primer cliente',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _clientesFiltrados.length,
      itemBuilder: (context, index) {
        final cliente = _clientesFiltrados[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[700],
              child: Text(
                cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : 'C',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              cliente.nombre,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(cliente.telefono!),
                    ],
                  ),
                if (cliente.direccion != null && cliente.direccion!.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          cliente.direccion!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, size: 20),
                  color: Colors.blue,
                  onPressed: () => _mostrarDialogo(cliente: cliente),
                  tooltip: 'Editar cliente',
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 20),
                  color: Colors.red,
                  onPressed: () => _eliminarCliente(cliente),
                  tooltip: 'Eliminar cliente',
                ),
              ],
            ),
            onTap: () => _mostrarDialogo(cliente: cliente),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Clientes"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarClientes,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar clientes...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          
          // Contador de resultados
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_clientesFiltrados.length} de ${_clientes.length} clientes',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  Chip(
                    label: Text('Búsqueda activa'),
                    backgroundColor: Colors.blue[100],
                  ),
              ],
            ),
          ),
          
          // Lista de clientes
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargarClientes,
              child: _buildClientesList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogo(),
        child: Icon(Icons.add),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        tooltip: 'Agregar nuevo cliente',
      ),
    );
  }
}