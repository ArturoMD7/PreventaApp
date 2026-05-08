import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:refrescos_app/services/data_service.dart';
import 'package:refrescos_app/models/credito.dart';
import 'package:refrescos_app/models/prestamo.dart';
import 'package:refrescos_app/widgets/cliente_dropdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreditosPrestamosScreen extends StatefulWidget {
  @override
  _CreditosPrestamosScreenState createState() => _CreditosPrestamosScreenState();
}

class _CreditosPrestamosScreenState extends State<CreditosPrestamosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Credito> _creditos = [];
  List<Prestamo> _prestamos = [];
  List<Credito> _creditosFiltrados = [];
  List<Prestamo> _prestamosFiltrados = [];
  String _filtroEstadoCreditos = 'todos'; // 'todos', 'pendientes', 'pagados'
  String _filtroEstadoPrestamos = 'todos'; // 'todos', 'pendientes', 'devueltos'
  final DataService _dbService = DataService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final creditos = await _dbService.getCreditos();
      final prestamos = await _dbService.getPrestamos();
      
      setState(() {
        _creditos = creditos;
        _prestamos = prestamos;
        _aplicarFiltros();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    // Filtrar créditos
    _creditosFiltrados = _creditos.where((credito) {
      if (_filtroEstadoCreditos == 'pendientes') {
        return credito.saldoPendiente > 0;
      } else if (_filtroEstadoCreditos == 'pagados') {
        return credito.saldoPendiente <= 0;
      }
      return true; // 'todos'
    }).toList();

    // Filtrar prestamos
    _prestamosFiltrados = _prestamos.where((prestamo) {
      if (_filtroEstadoPrestamos == 'pendientes') {
        return prestamo.fechaDevolucion == null;
      } else if (_filtroEstadoPrestamos == 'devueltos') {
        return prestamo.fechaDevolucion != null;
      }
      return true; // 'todos'
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos y Préstamos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.credit_card), text: 'Créditos'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Préstamos'),
          ],
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
        controller: _tabController,
        children: [
          _buildCreditosTab(),
          _buildPrestamosTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _mostrarDialogoCredito(),
              tooltip: 'Nuevo Crédito',
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              onPressed: () => _mostrarDialogoPrestamo(),
              tooltip: 'Nuevo Préstamo',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildCreditosTab() {
    final totalPendiente = _creditosFiltrados
        .where((c) => c.saldoPendiente > 0)
        .fold(0.0, (sum, c) => sum + c.saldoPendiente);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filtroEstadoCreditos,
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(value: 'pendientes', child: Text('Pendientes')),
                    DropdownMenuItem(value: 'pagados', child: Text('Pagados')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filtroEstadoCreditos = value!;
                      _aplicarFiltros();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  'Total: \$${totalPendiente.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.blue,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarDatos,
            child: _creditosFiltrados.isEmpty
                ? const Center(child: Text('No hay créditos registrados'))
                : ListView.builder(
                    itemCount: _creditosFiltrados.length,
                    itemBuilder: (context, index) {
                      final credito = _creditosFiltrados[index];
                      return _buildCreditoCard(credito);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreditoCard(Credito credito) {
    final bool estaPagado = credito.saldoPendiente <= 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: estaPagado ? Colors.green[50] : null,
      child: ListTile(
        leading: Icon(
          estaPagado ? Icons.check_circle : Icons.pending_actions,
          color: estaPagado ? Colors.green : Colors.orange,
        ),
        title: Text(
          credito.clienteNombre ?? 'Cliente desconocido',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: estaPagado ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monto original: \$${credito.monto.toStringAsFixed(2)}'),
            Text('Saldo pendiente: \$${credito.saldoPendiente.toStringAsFixed(2)}',
                style: TextStyle(
                  color: credito.saldoPendiente > 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                )),
            Text('Fecha: ${DateFormat('dd/MM/yyyy').format(credito.fecha)}'),
            if (estaPagado) const Text('PAGADO COMPLETO', style: TextStyle(color: Colors.green)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!estaPagado)
              IconButton(
                icon: const Icon(Icons.payment, color: Colors.blue),
                onPressed: () => _mostrarDialogoAbono(credito),
                tooltip: 'Registrar abono',
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmarEliminarCredito(credito),
              tooltip: 'Eliminar crédito',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrestamosTab() {
    final pendientesCount = _prestamosFiltrados.where((e) => e.fechaDevolucion == null).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filtroEstadoPrestamos,
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(value: 'pendientes', child: Text('Pendientes')),
                    DropdownMenuItem(value: 'devueltos', child: Text('Devueltos')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filtroEstadoPrestamos = value!;
                      _aplicarFiltros();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text('$pendientesCount pendientes'),
                backgroundColor: Colors.orange,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarDatos,
            child: _prestamosFiltrados.isEmpty
                ? const Center(child: Text('No hay préstamos registrados'))
                : ListView.builder(
                    itemCount: _prestamosFiltrados.length,
                    itemBuilder: (context, index) {
                      final prestamo = _prestamosFiltrados[index];
                      return _buildPrestamoCard(prestamo);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrestamoCard(Prestamo prestamo) {
    final bool estaDevuelto = prestamo.fechaDevolucion != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: estaDevuelto ? Colors.green[50] : null,
      child: ListTile(
        leading: Icon(
          estaDevuelto ? Icons.check_circle : Icons.pending,
          color: estaDevuelto ? Colors.green : Colors.orange,
        ),
        title: Text(
          prestamo.clienteNombre ?? 'Cliente desconocido',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: estaDevuelto ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Descripción: ${prestamo.descripcion}'),
            Text('Cantidad: ${prestamo.cantidad}'),
            Text('Préstamo: ${DateFormat('dd/MM/yyyy').format(prestamo.fechaPrestamo)}'),
            if (estaDevuelto)
              Text('Devolución: ${DateFormat('dd/MM/yyyy').format(prestamo.fechaDevolucion!)}'),
            if (!estaDevuelto)
              const Text('PENDIENTE', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: !estaDevuelto
            ? IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => _registrarDevolucion(prestamo.id!),
                tooltip: 'Marcar como devuelto',
              )
            : IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmarEliminarPrestamo(prestamo),
                tooltip: 'Eliminar registro',
              ),
      ),
    );
  }

  void _mostrarDialogoCredito() {
    showDialog(
      context: context,
      builder: (context) => CreditoDialog(),
    ).then((_) => _cargarDatos());
  }

  void _mostrarDialogoPrestamo() {
    showDialog(
      context: context,
      builder: (context) => PrestamoDialog(),
    ).then((_) => _cargarDatos());
  }

  void _mostrarDialogoAbono(Credito credito) {
    final _abonoController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Abono'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${credito.clienteNombre}'),
            Text('Saldo actual: \$${credito.saldoPendiente.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _abonoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto del abono',
                prefixText: '\$ ',
              ),
              validator: (value) {
                if (value == null || value.isEmpty || double.tryParse(value) == null) {
                  return 'Ingresa un monto válido';
                }
                final abono = double.parse(value);
                if (abono <= 0) {
                  return 'El abono debe ser mayor a cero';
                }
                if (abono > credito.saldoPendiente) {
                  return 'El abono no puede ser mayor al saldo pendiente';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_abonoController.text.isNotEmpty) {
                final abono = double.parse(_abonoController.text);
                final nuevoSaldo = credito.saldoPendiente - abono;
                try {
                  await _dbService.updateSaldoCredito(credito.id!, nuevoSaldo);
                  Navigator.of(context).pop();
                  _cargarDatos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Abono de \$${abono.toStringAsFixed(2)} registrado')),
                  );
                } catch(e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Registrar Abono'),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarDevolucion(String prestamoId) async {
    try {
      await _dbService.updateDevolucionPrestamo(prestamoId, DateTime.now());
      _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Préstamo marcado como devuelto')),
      );
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _confirmarEliminarCredito(Credito credito) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Crédito'),
        content: const Text('¿Estás seguro de eliminar este crédito? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _dbService.deleteCredito(credito.id!);
                Navigator.of(context).pop();
                _cargarDatos();
              } catch(e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarPrestamo(Prestamo prestamo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Registro de Préstamo'),
        content: const Text('¿Estás seguro de eliminar este registro de préstamo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _dbService.deletePrestamo(prestamo.id!);
                Navigator.of(context).pop();
                _cargarDatos();
              } catch(e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class CreditoDialog extends StatefulWidget {
  @override
  _CreditoDialogState createState() => _CreditoDialogState();
}

class _CreditoDialogState extends State<CreditoDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedClienteId;
  final _montoController = TextEditingController();
  final DataService _dbService = DataService();

  Future<void> _guardarCredito() async {
    if (_formKey.currentState!.validate() && _selectedClienteId != null) {
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;
      final credito = Credito(
        userId: currentUserId,
        clienteId: _selectedClienteId!,
        monto: double.parse(_montoController.text),
        saldoPendiente: double.parse(_montoController.text),
        fecha: DateTime.now(),
      );
      try {
        await _dbService.insertCredito(credito);
        Navigator.of(context).pop();
      } catch(e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Crédito'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClienteDropdown(
              onClienteSelected: (clienteId, nombreCliente) {
                setState(() {
                  _selectedClienteId = clienteId;
                });
              },
            ),
            TextFormField(
              controller: _montoController,
              decoration: const InputDecoration(labelText: 'Monto'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty || double.tryParse(value) == null) {
                  return 'Ingresa un monto válido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardarCredito,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class PrestamoDialog extends StatefulWidget {
  @override
  _PrestamoDialogState createState() => _PrestamoDialogState();
}

class _PrestamoDialogState extends State<PrestamoDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedClienteId;
  final _descripcionController = TextEditingController();
  final _cantidadController = TextEditingController();
  final DataService _dbService = DataService();

  Future<void> _guardarPrestamo() async {
    if (_formKey.currentState!.validate() && 
        _selectedClienteId != null) {
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;
      final prestamo = Prestamo(
        userId: currentUserId,
        clienteId: _selectedClienteId!,
        descripcion: _descripcionController.text,
        cantidad: int.parse(_cantidadController.text),
        fechaPrestamo: DateTime.now(),
      );
      try {
        await _dbService.insertPrestamo(prestamo);
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Préstamo'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClienteDropdown(
              onClienteSelected: (clienteId, nombreCliente) {
                setState(() {
                  _selectedClienteId = clienteId;
                });
              },
            ),
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(labelText: 'Descripción (Ej. 2 Envases Coca-Cola)'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa una descripción';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _cantidadController,
              decoration: const InputDecoration(labelText: 'Cantidad'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty || int.tryParse(value) == null) {
                  return 'Ingresa una cantidad válida';
                }
                if (int.parse(value) <= 0) {
                  return 'La cantidad debe ser mayor a cero';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardarPrestamo,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
