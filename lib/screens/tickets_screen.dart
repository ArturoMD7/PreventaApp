import 'package:flutter/material.dart';
import 'package:refrescos_app/services/data_service.dart';
import 'package:refrescos_app/models/venta.dart';
import 'package:refrescos_app/widgets/venta_item.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TicketsScreen extends StatefulWidget {
  @override
  _TicketsScreenState createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {

  BlueThermalPrinter printer = BlueThermalPrinter.instance;
  final DataService _dbService = DataService();
  bool _isLoading = true;

  List<Venta> _ventas = [];
  List<Venta> _ventasFiltradas = [];
  List<Venta> _ventasPendientes = [];
  List<Venta> _ventasEntregadas = [];
  
  // Filtros
  String _filtroEstado = 'todos';
  String _filtroBusqueda = '';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  
  final TextEditingController _busquedaController = TextEditingController();
  bool _mostrarFiltros = false;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
    _busquedaController.addListener(_aplicarFiltroBusqueda);
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _reimprimirTicket(Venta venta) async {
    try {
      final detalles = await _dbService.getDetallesVenta(venta.id!);
      
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString("printer_address");

      if (address == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No hay impresora configurada"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!(await printer.isConnected)!) {
        final devices = await printer.getBondedDevices();
        final device = devices.firstWhere(
          (d) => d.address == address,
          orElse: () => throw "Dispositivo no encontrado",
        );
        await printer.connect(device);
      }

      String fechaFormateada = DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha);
      final negocio = await _dbService.getNegocio();

      printer.printCustom(negocio?.ticketHeader ?? "TICKET DE VENTA", 2, 1);
      printer.printCustom(negocio?.nombreNegocio ?? "MI NEGOCIO", 2, 1);
      printer.printNewLine();
      printer.printCustom("Cliente: ${venta.clienteNombre}", 1, 0);
      printer.printCustom("Fecha pedido: $fechaFormateada", 1, 0);
      printer.printCustom("Ticket #${venta.id?.substring(0,8)}", 1, 0);
      printer.printNewLine();
      
      for (var detalle in detalles) {
        printer.printCustom(
          "${detalle.productoNombre} ${detalle.cantidad}  \$${detalle.subtotal.toStringAsFixed(2)}",
          1,
          0,
        );
      }

      printer.printNewLine();
      printer.printCustom("TOTAL: \$${venta.total.toStringAsFixed(2)}", 2, 2);
      printer.printNewLine();
      if (negocio?.ticketFooter != null && negocio!.ticketFooter!.isNotEmpty) {
        printer.printCustom(negocio.ticketFooter!, 1, 1);
      }
      printer.printNewLine();
      printer.printNewLine();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ticket reimpreso correctamente"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al reimprimir: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cargarVentas() async {
    setState(() => _isLoading = true);
    try {
      final ventas = await _dbService.getVentas();
      setState(() {
        _ventas = ventas;
        _organizarVentas();
        _aplicarFiltros();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _organizarVentas() {
    _ventasPendientes = _ventas.where((venta) => venta.estado == 'pendiente').toList();
    _ventasEntregadas = _ventas.where((venta) => venta.estado == 'entregado').toList();
    _ventasPendientes.sort((a, b) => b.fecha.compareTo(a.fecha));
    _ventasEntregadas.sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  void _aplicarFiltroBusqueda() {
    setState(() {
      _filtroBusqueda = _busquedaController.text.toLowerCase();
      _aplicarFiltros();
    });
  }

  void _aplicarFiltros() {
    List<Venta> ventasFiltradas = List.from(_ventas);
    
    if (_filtroEstado != 'todos') {
      ventasFiltradas = ventasFiltradas.where((venta) => 
        venta.estado == _filtroEstado
      ).toList();
    } else {
      ventasFiltradas = ventasFiltradas.where((venta) => 
        venta.estado != 'descartado'
      ).toList();
    }
    
    if (_filtroBusqueda.isNotEmpty) {
      ventasFiltradas = ventasFiltradas.where((venta) {
        final clienteNombre = venta.clienteNombre.toLowerCase();
        return clienteNombre.contains(_filtroBusqueda) ||
               (venta.id?.contains(_filtroBusqueda) ?? false);
      }).toList();
    }
    
    if (_fechaInicio != null) {
      ventasFiltradas = ventasFiltradas.where((venta) => 
        venta.fecha.isAfter(_fechaInicio!.subtract(const Duration(days: 1))) || 
        _esMismoDia(venta.fecha, _fechaInicio!)
      ).toList();
    }
    
    if (_fechaFin != null) {
      final fechaFinAjustada = DateTime(_fechaFin!.year, _fechaFin!.month, _fechaFin!.day, 23, 59, 59);
      ventasFiltradas = ventasFiltradas.where((venta) => 
        venta.fecha.isBefore(fechaFinAjustada) || 
        _esMismoDia(venta.fecha, _fechaFin!)
      ).toList();
    }
    
    ventasFiltradas.sort((a, b) => b.fecha.compareTo(a.fecha));
    
    setState(() {
      _ventasFiltradas = ventasFiltradas;
    });
  }

  bool _esMismoDia(DateTime fecha1, DateTime fecha2) {
    return fecha1.year == fecha2.year &&
           fecha1.month == fecha2.month &&
           fecha1.day == fecha2.day;
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroEstado = 'todos';
      _filtroBusqueda = '';
      _fechaInicio = null;
      _fechaFin = null;
      _busquedaController.clear();
      _aplicarFiltros();
    });
  }

  Future<void> _cambiarEstadoVenta(String id, String estadoActual, String clienteNombre) async {
    final confirmado = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(estadoActual == 'pendiente' ? 'Marcar como entregado' : 'Marcar como pendiente'),
        content: Text('¿Estás seguro de que deseas cambiar el estado del ticket de ${clienteNombre.isNotEmpty ? clienteNombre : "cliente"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
    
    if (confirmado == true) {
      setState(() => _isLoading = true);
      String nuevoEstado;
      
      if (estadoActual == 'pendiente') {
        nuevoEstado = 'entregado';
      } else if (estadoActual == 'entregado') {
        nuevoEstado = 'pendiente';
      } else {
        nuevoEstado = 'pendiente';
      }
      
      try {
        await _dbService.updateEstadoVenta(id, nuevoEstado);
        await _cargarVentas();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estado del ticket actualizado correctamente'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _descartarVenta(String id, String clienteNombre) async {
    final ventaOpt = _ventas.where((v) => v.id == id);
    if (ventaOpt.isEmpty || ventaOpt.first.estado != 'entregado') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo se pueden descartar ventas entregadas'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    final confirmado = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar ticket'),
        content: Text('¿Estás seguro de que deseas descartar el ticket de ${clienteNombre.isNotEmpty ? clienteNombre : "cliente"}? Seguirá apareciendo en el corte de su fecha.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    
    if (confirmado == true) {
      try {
        await _dbService.updateEstadoVenta(id, 'descartado');
        await _cargarVentas();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket descartado correctamente'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _mostrarDetallesVenta(Venta venta) async {
    try {
      final detalles = await _dbService.getDetallesVenta(venta.id!);
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Detalles de Venta #${venta.id?.substring(0,8)}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cliente: ${venta.clienteNombre}'),
                Text('Fecha: ${venta.fecha.toString().substring(0, 16)}'),
                Text('Estado: ${venta.estado}'),
                Text('Total: \$${venta.total.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                const Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...detalles.map((detalle) => ListTile(
                  title: Text(detalle.productoNombre ?? 'Producto desconocido'),
                  subtitle: Text('Cantidad: ${detalle.cantidad}'),
                  trailing: Text('\$${detalle.subtotal.toStringAsFixed(2)}'),
                )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _reimprimirTicket(venta);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print, size: 18),
                  SizedBox(width: 4),
                  Text('Reimprimir'),
                ],
              ),
            ),
            if (venta.estado == 'descartado')
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _cambiarEstadoVenta(venta.id!, venta.estado, venta.clienteNombre);
                },
                child: const Text('Reactivar ticket'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
    } catch(e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _seleccionarFecha(BuildContext context, bool esInicio) async {
    final DateTime? seleccionada = await showDatePicker(
      context: context,
      initialDate: esInicio ? _fechaInicio ?? DateTime.now() : _fechaFin ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (seleccionada != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = seleccionada;
        } else {
          _fechaFin = seleccionada;
        }
        _aplicarFiltros();
      });
    }
  }

  Widget _buildFiltrosPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _mostrarFiltros ? 200 : 0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Estado:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _filtroEstado,
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'todos',
                        child: Text('Todos (excepto descartados)'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'pendiente',
                        child: Text('Pendientes'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'entregado',
                        child: Text('Entregados'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'descartado',
                        child: Text('Descartados'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filtroEstado = value!;
                        _aplicarFiltros();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Fecha:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _seleccionarFecha(context, true),
                    child: Text(
                      _fechaInicio == null 
                        ? 'Desde' 
                        : '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('a'),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _seleccionarFecha(context, false),
                    child: Text(
                      _fechaFin == null 
                        ? 'Hasta' 
                        : '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _limpiarFiltros,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Limpiar filtros'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaVentas() {
    if (_ventasFiltradas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron tickets',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (_filtroEstado != 'todos' || _filtroBusqueda.isNotEmpty || _fechaInicio != null || _fechaFin != null)
              TextButton(
                onPressed: _limpiarFiltros,
                child: const Text('Limpiar filtros'),
              ),
          ],
        ),
      );
    }

    if (_filtroEstado == 'todos' && _filtroBusqueda.isEmpty && _fechaInicio == null && _fechaFin == null) {
      return ListView(
        children: [
          if (_ventasPendientes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Pendientes de entrega',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800]),
              ),
            ),
            ..._ventasPendientes.map((venta) => VentaItem(
              venta: venta,
              onCambiarEstado: () => _cambiarEstadoVenta(venta.id!, venta.estado, venta.clienteNombre),
              onVerDetalles: () => _mostrarDetallesVenta(venta),
              onDescartar: venta.estado != 'descartado' 
                ? () => _descartarVenta(venta.id!, venta.clienteNombre)
                : null,
            )).toList(),
            const Divider(thickness: 2),
          ],
          if (_ventasEntregadas.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Entregados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800]),
              ),
            ),
            ..._ventasEntregadas.map((venta) => VentaItem(
              venta: venta,
              onCambiarEstado: () => _cambiarEstadoVenta(venta.id!, venta.estado, venta.clienteNombre),
              onVerDetalles: () => _mostrarDetallesVenta(venta),
              onDescartar: venta.estado != 'descartado' 
                ? () => _descartarVenta(venta.id!, venta.clienteNombre)
                : null,
            )).toList(),
          ],
        ],
      );
    } else {
      return ListView.builder(
        itemCount: _ventasFiltradas.length,
        itemBuilder: (context, index) {
          final venta = _ventasFiltradas[index];
          return VentaItem(
            venta: venta,
            onCambiarEstado: () => _cambiarEstadoVenta(venta.id!, venta.estado, venta.clienteNombre),
            onVerDetalles: () => _mostrarDetallesVenta(venta),
            onDescartar: venta.estado != 'descartado' 
              ? () => _descartarVenta(venta.id!, venta.clienteNombre)
              : null,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets de Ventas'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_mostrarFiltros ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () {
              setState(() {
                _mostrarFiltros = !_mostrarFiltros;
              });
            },
            tooltip: _mostrarFiltros ? 'Ocultar filtros' : 'Mostrar filtros',
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o ID...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                suffixIcon: _filtroBusqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          
          _buildFiltrosPanel(),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_ventasFiltradas.length} tickets',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (_filtroEstado != 'todos' || _filtroBusqueda.isNotEmpty || _fechaInicio != null || _fechaFin != null)
                  Chip(
                    label: const Text('Filtros activos'),
                    backgroundColor: Colors.blue[100],
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargarVentas,
              child: _buildListaVentas(),
            ),
          ),
        ],
      ),
    );
  }
}
