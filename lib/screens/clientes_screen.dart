import 'package:flutter/material.dart';
import 'package:refrescos_app/models/cliente.dart';
import 'package:refrescos_app/services/data_service.dart';
import 'package:refrescos_app/services/sync_service.dart';
import 'package:refrescos_app/widgets/cliente_dialog.dart';

class ClientesScreen extends StatefulWidget {
  @override
  _ClientesScreenState createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> _clientes = [];
  List<Cliente> _clientesFiltrados = [];
  final DataService _dbService = DataService();
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

  Future<void> _sincronizarYCargar() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Sincronizando con servidor...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
    await SyncService().syncAll();
    await _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    setState(() => _isLoading = true);
    try {
      final clientes = await _dbService.getClientes();
      setState(() {
        _clientes = clientes;
        _clientesFiltrados = clientes;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar clientes: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
      setState(() => _isLoading = true);
      try {
        if (cliente == null) {
          await _dbService.insertCliente(resultado);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente agregado correctamente'), backgroundColor: Colors.green),
          );
        } else {
          await _dbService.updateCliente(resultado);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente actualizado correctamente'), backgroundColor: Colors.blue),
          );
        }
        await _cargarClientes();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar cliente: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Eliminar cliente con confirmación
  void _eliminarCliente(Cliente cliente) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Estás seguro de que deseas eliminar a ${cliente.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      setState(() => _isLoading = true);
      try {
        await _dbService.deleteCliente(cliente.id!);
        await _cargarClientes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente eliminado correctamente'), backgroundColor: Colors.red),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar cliente: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildClientesList() {
    if (_isLoading) {
      return const Center(
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
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No hay clientes registrados'
                  : 'No se encontraron clientes',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (_searchController.text.isEmpty)
              const Text(
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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[700],
              child: Text(
                cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : 'C',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              cliente.nombre,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(cliente.telefono!),
                    ],
                  ),
                if (cliente.direccion != null && cliente.direccion!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
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
                  icon: const Icon(Icons.edit, size: 20),
                  color: Colors.blue,
                  onPressed: () => _mostrarDialogo(cliente: cliente),
                  tooltip: 'Editar cliente',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
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
        title: const Text("Clientes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _sincronizarYCargar,
            tooltip: 'Sincronizar y actualizar',
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
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
                    label: const Text('Búsqueda activa'),
                    backgroundColor: Colors.blue[100],
                  ),
              ],
            ),
          ),
          
          // Lista de clientes
          Expanded(
            child: RefreshIndicator(
              onRefresh: _sincronizarYCargar,
              child: _buildClientesList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogo(),
        tooltip: 'Agregar nuevo cliente',
        child: const Icon(Icons.add),
      ),
    );
  }
}
