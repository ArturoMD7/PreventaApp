import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:refrescos_app/database/database_helper.dart';
import 'package:refrescos_app/models/cliente.dart';
import 'package:refrescos_app/models/credito.dart';
import 'package:refrescos_app/models/envase.dart';
import 'package:refrescos_app/models/producto.dart';
import 'package:refrescos_app/widgets/cliente_dropdown.dart';

class CreditosEnvasesScreen extends StatefulWidget {
  @override
  _CreditosEnvasesScreenState createState() => _CreditosEnvasesScreenState();
}

class _CreditosEnvasesScreenState extends State<CreditosEnvasesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Credito> _creditos = [];
  List<Envase> _envases = [];
  List<Credito> _creditosFiltrados = [];
  List<Envase> _envasesFiltrados = [];
  String _filtroEstadoCreditos = 'todos'; // 'todos', 'pendientes', 'pagados'
  String _filtroEstadoEnvases = 'todos'; // 'todos', 'pendientes', 'devueltos'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final dbHelper = DatabaseHelper();
    final creditos = await dbHelper.getCreditos();
    final envases = await dbHelper.getEnvases();
    
    setState(() {
      _creditos = creditos;
      _envases = envases;
      _aplicarFiltros();
    });
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

    // Filtrar envases
    _envasesFiltrados = _envases.where((envase) {
      if (_filtroEstadoEnvases == 'pendientes') {
        return envase.fechaDevolucion == null;
      } else if (_filtroEstadoEnvases == 'devueltos') {
        return envase.fechaDevolucion != null;
      }
      return true; // 'todos'
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Créditos y Envases'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.credit_card), text: 'Créditos'),
            Tab(icon: Icon(Icons.local_drink), text: 'Envases'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreditosTab(),
          _buildEnvasesTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _mostrarDialogoCredito(),
              child: Icon(Icons.add),
              tooltip: 'Nuevo Crédito',
            )
          : FloatingActionButton(
              onPressed: () => _mostrarDialogoEnvase(),
              child: Icon(Icons.add),
              tooltip: 'Nuevo Envase',
            ),
    );
  }

  Widget _buildCreditosTab() {
    final totalPendiente = _creditosFiltrados
        .where((c) => c.saldoPendiente > 0)
        .fold(0.0, (sum, c) => sum + c.saldoPendiente);

    return Column(
      children: [
        // Filtros y total
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filtroEstadoCreditos,
                  items: [
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
              SizedBox(width: 8),
              Chip(
                label: Text(
                  'Total: \$${totalPendiente.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.blue,
              ),
            ],
          ),
        ),
        Divider(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarDatos,
            child: _creditosFiltrados.isEmpty
                ? Center(child: Text('No hay créditos registrados'))
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
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            if (estaPagado) Text('PAGADO COMPLETO', style: TextStyle(color: Colors.green)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!estaPagado)
              IconButton(
                icon: Icon(Icons.payment, color: Colors.blue),
                onPressed: () => _mostrarDialogoAbono(credito),
                tooltip: 'Registrar abono',
              ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmarEliminarCredito(credito),
              tooltip: 'Eliminar crédito',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvasesTab() {
    final pendientesCount = _envasesFiltrados.where((e) => e.fechaDevolucion == null).length;

    return Column(
      children: [
        // Filtros y contador
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filtroEstadoEnvases,
                  items: [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(value: 'pendientes', child: Text('Pendientes')),
                    DropdownMenuItem(value: 'devueltos', child: Text('Devueltos')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filtroEstadoEnvases = value!;
                      _aplicarFiltros();
                    });
                  },
                ),
              ),
              SizedBox(width: 8),
              Chip(
                label: Text('$pendientesCount pendientes'),
                backgroundColor: Colors.orange,
              ),
            ],
          ),
        ),
        Divider(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarDatos,
            child: _envasesFiltrados.isEmpty
                ? Center(child: Text('No hay envases registrados'))
                : ListView.builder(
                    itemCount: _envasesFiltrados.length,
                    itemBuilder: (context, index) {
                      final envase = _envasesFiltrados[index];
                      return _buildEnvaseCard(envase);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnvaseCard(Envase envase) {
    final bool estaDevuelto = envase.fechaDevolucion != null;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: estaDevuelto ? Colors.green[50] : null,
      child: ListTile(
        leading: Icon(
          estaDevuelto ? Icons.check_circle : Icons.pending,
          color: estaDevuelto ? Colors.green : Colors.orange,
        ),
        title: Text(
          envase.clienteNombre ?? 'Cliente desconocido',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: estaDevuelto ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Producto: ${envase.productoNombre}'),
            Text('Cantidad: ${envase.cantidad}'),
            Text('Préstamo: ${DateFormat('dd/MM/yyyy').format(envase.fechaPrestamo)}'),
            if (estaDevuelto)
              Text('Devolución: ${DateFormat('dd/MM/yyyy').format(envase.fechaDevolucion!)}'),
            if (!estaDevuelto)
              Text('PENDIENTE', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: !estaDevuelto
            ? IconButton(
                icon: Icon(Icons.check, color: Colors.green),
                onPressed: () => _registrarDevolucion(envase.id!),
                tooltip: 'Marcar como devuelto',
              )
            : IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmarEliminarEnvase(envase),
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

  void _mostrarDialogoEnvase() {
    showDialog(
      context: context,
      builder: (context) => EnvaseDialog(),
    ).then((_) => _cargarDatos());
  }

  void _mostrarDialogoAbono(Credito credito) {
    final _abonoController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Registrar Abono'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${credito.clienteNombre}'),
            Text('Saldo actual: \$${credito.saldoPendiente.toStringAsFixed(2)}'),
            SizedBox(height: 16),
            TextFormField(
              controller: _abonoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
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
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_abonoController.text.isNotEmpty) {
                final abono = double.parse(_abonoController.text);
                final nuevoSaldo = credito.saldoPendiente - abono;
                final dbHelper = DatabaseHelper();
                await dbHelper.updateSaldoCredito(credito.id!, nuevoSaldo);
                
                Navigator.of(context).pop();
                _cargarDatos();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Abono de \$${abono.toStringAsFixed(2)} registrado')),
                );
              }
            },
            child: Text('Registrar Abono'),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarDevolucion(int envaseId) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.updateDevolucionEnvase(envaseId, DateTime.now());
    _cargarDatos();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Envase marcado como devuelto')),
    );
  }

  void _confirmarEliminarCredito(Credito credito) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Crédito'),
        content: Text('¿Estás seguro de eliminar este crédito? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final dbHelper = DatabaseHelper();
              // Necesitarías agregar un método deleteCredito en DatabaseHelper
              await dbHelper.deleteCredito(credito.id!);
              Navigator.of(context).pop();
              _cargarDatos();
            },
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarEnvase(Envase envase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Registro de Envase'),
        content: Text('¿Estás seguro de eliminar este registro de envase?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final dbHelper = DatabaseHelper();
              // Necesitarías agregar un método deleteEnvase en DatabaseHelper
              await dbHelper.deleteEnvase(envase.id!);
              Navigator.of(context).pop();
              _cargarDatos();
            },
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
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
  int? _selectedClienteId;
  final _montoController = TextEditingController();

  Future<void> _guardarCredito() async {
    if (_formKey.currentState!.validate() && _selectedClienteId != null) {
      final dbHelper = DatabaseHelper();
      final credito = Credito(
        clienteId: _selectedClienteId!,
        monto: double.parse(_montoController.text),
        saldoPendiente: double.parse(_montoController.text),
        fecha: DateTime.now(),
      );
      await dbHelper.insertCredito(credito);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nuevo Crédito'),
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
              decoration: InputDecoration(labelText: 'Monto'),
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
          child: Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardarCredito,
          child: Text('Guardar'),
        ),
      ],
    );
  }
}

class EnvaseDialog extends StatefulWidget {
  @override
  _EnvaseDialogState createState() => _EnvaseDialogState();
}

class _EnvaseDialogState extends State<EnvaseDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedClienteId;
  int? _selectedProductoId;
  final _cantidadController = TextEditingController();
  List<Producto> _productos = [];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    final dbHelper = DatabaseHelper();
    final productos = await dbHelper.getProductos();
    setState(() {
      _productos = productos;
    });
  }

  Future<void> _guardarEnvase() async {
    if (_formKey.currentState!.validate() && 
        _selectedClienteId != null && 
        _selectedProductoId != null) {
      final dbHelper = DatabaseHelper();
      final envase = Envase(
        clienteId: _selectedClienteId!,
        productoId: _selectedProductoId!,
        cantidad: int.parse(_cantidadController.text),
        fechaPrestamo: DateTime.now(),
      );
      await dbHelper.insertEnvase(envase);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nuevo Envase Prestado'),
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
            DropdownButtonFormField<int>(
              value: _selectedProductoId,
              decoration: InputDecoration(labelText: 'Producto'),
              items: _productos.map((Producto producto) {
                return DropdownMenuItem<int>(
                  value: producto.id,
                  child: Text(producto.nombre),
                );
              }).toList(),
              onChanged: (value) => setState(() {
                _selectedProductoId = value;
              }),
              validator: (value) {
                if (value == null) return 'Selecciona un producto';
                return null;
              },
            ),
            TextFormField(
              controller: _cantidadController,
              decoration: InputDecoration(labelText: 'Cantidad'),
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
          child: Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardarEnvase,
          child: Text('Guardar'),
        ),
      ],
    );
  }
}


  