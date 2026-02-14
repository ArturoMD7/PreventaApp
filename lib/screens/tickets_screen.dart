import 'package:flutter/material.dart';
import 'package:refrescos_app/database/database_helper.dart';
import 'package:refrescos_app/models/detalle_venta.dart';
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

  List<Venta> _ventas = [];
  List<Venta> _ventasFiltradas = [];
  List<Venta> _ventasPendientes = [];
  List<Venta> _ventasEntregadas = [];
  
  // Filtros
  String _filtroEstado = 'todos';
  String _filtroBusqueda = '';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  
  // Controladores
  final TextEditingController _busquedaController = TextEditingController();
  
  // Estado del panel de filtros
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
      final dbHelper = DatabaseHelper();
      final detalles = await dbHelper.getDetallesVenta(venta.id!);
      
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString("printer_address");

      if (address == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No hay impresora configurada"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Verificar conexión con la impresora
      if (!(await printer.isConnected)!) {
        final devices = await printer.getBondedDevices();
        final device = devices.firstWhere(
          (d) => d.address == address,
          orElse: () => throw "Dispositivo no encontrado",
        );
        await printer.connect(device);
      }

      String fechaFormateada = DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha);

      // Encabezado
      printer.printCustom("DEPOSITO", 2, 1);
      printer.printCustom("EL JAROCHO", 2, 1);
      printer.printNewLine();
      printer.printCustom("Cliente: ${venta.clienteNombre}", 1, 0);
      printer.printCustom("Fecha pedido: $fechaFormateada", 1, 0);
      printer.printCustom("Ticket #${venta.id}", 1, 0);
      printer.printNewLine();
      
      // Productos
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
      printer.printNewLine();
      printer.printNewLine();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
    final dbHelper = DatabaseHelper();
    final ventas = await dbHelper.getVentas();
    setState(() {
      _ventas = ventas;
      _organizarVentas();
      _aplicarFiltros();
    });
  }

  void _organizarVentas() {
    // Separar ventas pendientes y entregadas
    _ventasPendientes = _ventas.where((venta) => venta.estado == 'pendiente').toList();
    _ventasEntregadas = _ventas.where((venta) => venta.estado == 'entregado').toList();
    
    // Ordenar por fecha (más recientes primero)
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
    
    // Aplicar filtro por estado
    if (_filtroEstado != 'todos') {
      ventasFiltradas = ventasFiltradas.where((venta) => 
        venta.estado == _filtroEstado
      ).toList();
    } else {
      // Por defecto, excluir SOLO tickets descartados (no entregados)
      ventasFiltradas = ventasFiltradas.where((venta) => 
        venta.estado != 'descartado'
      ).toList();
    }
    
    // Aplicar filtro de búsqueda (con verificación de null)
    if (_filtroBusqueda.isNotEmpty) {
      ventasFiltradas = ventasFiltradas.where((venta) {
        final clienteNombre = venta.clienteNombre ?? '';
        return clienteNombre.toLowerCase().contains(_filtroBusqueda) ||
               venta.id.toString().contains(_filtroBusqueda);
      }).toList();
    }
    
    // Aplicar filtro por fecha
    if (_fechaInicio != null) {
      ventasFiltradas = ventasFiltradas.where((venta) => 
        venta.fecha.isAfter(_fechaInicio!.subtract(Duration(days: 1))) || 
        _esMismoDia(venta.fecha, _fechaInicio!)
      ).toList();
    }
    
    if (_fechaFin != null) {
      // Ajustar fecha fin para incluir todo el día
      final fechaFinAjustada = DateTime(_fechaFin!.year, _fechaFin!.month, _fechaFin!.day, 23, 59, 59);
      ventasFiltradas = ventasFiltradas.where((venta) => 
        venta.fecha.isBefore(fechaFinAjustada) || 
        _esMismoDia(venta.fecha, _fechaFin!)
      ).toList();
    }
    
    // Ordenar por fecha (más recientes primero)
    ventasFiltradas.sort((a, b) => b.fecha.compareTo(a.fecha));
    
    setState(() {
      _ventasFiltradas = ventasFiltradas;
    });
  }

  // Función auxiliar para comparar si dos fechas son el mismo día
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

  Future<void> _cambiarEstadoVenta(int id, String estadoActual, String clienteNombre) async {
    final confirmado = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(estadoActual == 'pendiente' ? 'Marcar como entregado' : 'Marcar como pendiente'),
        content: Text('¿Estás seguro de que deseas cambiar el estado del ticket #$id de ${clienteNombre.isNotEmpty ? clienteNombre : "cliente"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirmar', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
    
    if (confirmado == true) {
      final dbHelper = DatabaseHelper();
      String nuevoEstado;
      
      if (estadoActual == 'pendiente') {
        nuevoEstado = 'entregado';
      } else if (estadoActual == 'entregado') {
        nuevoEstado = 'pendiente';
      } else {
        // Para tickets descartados, permitir reactivarlos
        nuevoEstado = 'pendiente';
      }
      
      await dbHelper.updateEstadoVenta(id, nuevoEstado);
      _cargarVentas();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado del ticket actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _descartarVenta(int id, String clienteNombre) async {
    final dbHelper = DatabaseHelper();
    
    // Primero verificar que la venta esté entregada
    final ventas = await dbHelper.database.then((db) => db.query(
      'ventas',
      where: 'id = ?',
      whereArgs: [id],
    ));
    
    if (ventas.isEmpty || ventas.first['estado'] != 'entregado') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solo se pueden descartar ventas entregadas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final confirmado = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Descartar ticket'),
        content: Text('¿Estás seguro de que deseas descartar el ticket #$id de ${clienteNombre.isNotEmpty ? clienteNombre : "cliente"}? Seguirá apareciendo en el corte de su fecha.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Descartar', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    
    if (confirmado == true) {
      await dbHelper.updateEstadoVenta(id, 'descartado');
      _cargarVentas();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket descartado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _descartarTicketsAntiguos() async {
    final fechaLimite = DateTime.now().subtract(Duration(days: 0)); 
    
    final confirmado = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Descartar tickets antiguos'),
        content: Text('¿Estás seguro de que deseas descartar todos los tickets entregados anteriores al ${fechaLimite.day}/${fechaLimite.month}/${fechaLimite.year}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Descartar', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    
    if (confirmado == true) {
      final dbHelper = DatabaseHelper();
      
      // Solo descartar ventas que fueron entregadas antes de la fecha límite
      final resultado = await dbHelper.database.then((db) => db.rawUpdate('''
        UPDATE ventas 
        SET estado = 'descartado' 
        WHERE fecha_entrega < ? AND estado = 'entregado'
      ''', [fechaLimite.toIso8601String()]));
      
      _cargarVentas();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$resultado tickets marcados como descartados'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _mostrarDetallesVenta(Venta venta) async {
    final dbHelper = DatabaseHelper();
    final detalles = await dbHelper.getDetallesVenta(venta.id!);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles de Venta #${venta.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cliente: ${venta.clienteNombre ?? "No especificado"}'),
              Text('Fecha: ${venta.fecha.toString().substring(0, 16)}'),
              Text('Estado: ${venta.estado}'),
              Text('Total: \$${venta.total.toStringAsFixed(2)}'),
              SizedBox(height: 16),
              Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...detalles.map((detalle) => ListTile(
                title: Text(detalle.productoNombre ?? 'Producto desconocido'),
                subtitle: Text('Cantidad: ${detalle.cantidad}'),
                trailing: Text('\$${detalle.subtotal.toStringAsFixed(2)}'),
              )).toList(),
            ],
          ),
        ),
        actions: [
        // Botón de reimpresión
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _reimprimirTicket(venta);
          },
          child: Row(
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
              _cambiarEstadoVenta(venta.id!, venta.estado, venta.clienteNombre ?? '');
            },
            child: Text('Reactivar ticket'),
          ),
          
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cerrar', style: TextStyle(color: Colors.blue)),
        ),
      ],
    ),
  );
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
      duration: Duration(milliseconds: 300),
      height: _mostrarFiltros ? 250 : 0,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Filtro por estado
            Row(
              children: [
                Text('Estado:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _filtroEstado,
                    items: [
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
            SizedBox(height: 10),
            
            // Filtro por fecha
            Row(
              children: [
                Text('Fecha:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
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
                SizedBox(width: 10),
                Text('a'),
                SizedBox(width: 10),
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
            SizedBox(height: 10),
            
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _limpiarFiltros,
                    icon: Icon(Icons.clear_all),
                    label: Text('Limpiar filtros'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _descartarTicketsAntiguos,
                    icon: Icon(Icons.archive),
                    label: Text('Descartar antiguos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.orange[800],
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
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No se encontraron tickets',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (_filtroEstado != 'todos' || _filtroBusqueda.isNotEmpty || _fechaInicio != null || _fechaFin != null)
              TextButton(
                onPressed: _limpiarFiltros,
                child: Text('Limpiar filtros'),
              ),
          ],
        ),
      );
    }

    // Si no hay filtros activos, mostrar por secciones
    if (_filtroEstado == 'todos' && _filtroBusqueda.isEmpty && _fechaInicio == null && _fechaFin == null) {
      return ListView(
        children: [
          // Sección de pendientes
          if (_ventasPendientes.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Pendientes de entrega',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800]),
              ),
            ),
            ..._ventasPendientes.map((venta) => VentaItem(
              venta: venta,
              onCambiarEstado: () => _cambiarEstadoVenta(venta.id!, venta.estado, venta.clienteNombre ?? ''),
              onVerDetalles: () => _mostrarDetallesVenta(venta),
              onDescartar: venta.estado != 'descartado' 
                ? () => _descartarVenta(venta.id!, venta.clienteNombre ?? '')
                : null,
            )).toList(),
            
            Divider(thickness: 2),
          ],
          
          // Sección de entregados
          if (_ventasEntregadas.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Entregados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800]),
              ),
            ),
            ..._ventasEntregadas.map((venta) => VentaItem(
              venta: venta,
              onCambiarEstado: () => _cambiarEstadoVenta(venta.id!, venta.estado, venta.clienteNombre ?? ''),
              onVerDetalles: () => _mostrarDetallesVenta(venta),
              onDescartar: venta.estado != 'descartado' 
                ? () => _descartarVenta(venta.id!, venta.clienteNombre ?? '')
                : null,
            )).toList(),
          ],
        ],
      );
    } else {
      // Si hay filtros activos, mostrar lista plana
      return ListView.builder(
        itemCount: _ventasFiltradas.length,
        itemBuilder: (context, index) {
          final venta = _ventasFiltradas[index];
          return VentaItem(
            venta: venta,
            onCambiarEstado: () => _cambiarEstadoVenta(venta.id!, venta.estado, venta.clienteNombre ?? ''),
            onVerDetalles: () => _mostrarDetallesVenta(venta),
            onDescartar: venta.estado != 'descartado' 
              ? () => _descartarVenta(venta.id!, venta.clienteNombre ?? '')
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
        title: Text('Tickets de Ventas'),
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
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                suffixIcon: _filtroBusqueda.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _busquedaController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          
          // Panel de filtros
          _buildFiltrosPanel(),
          
          // Contador de resultados
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
                    label: Text('Filtros activos'),
                    backgroundColor: Colors.blue[100],
                  ),
              ],
            ),
          ),
          
          // Lista de ventas
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