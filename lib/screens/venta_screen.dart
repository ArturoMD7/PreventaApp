import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:refrescos_app/services/data_service.dart';
import 'package:refrescos_app/models/detalle_venta.dart';
import 'package:refrescos_app/models/producto.dart';
import 'package:refrescos_app/models/venta.dart';
import 'package:refrescos_app/models/negocio.dart';
import 'package:refrescos_app/widgets/cliente_dropdown.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class VentaScreen extends StatefulWidget {
  @override
  _VentaScreenState createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  BlueThermalPrinter printer = BlueThermalPrinter.instance;
  String? _selectedClienteId;
  String? _nombreCliente;
  final List<Map<String, dynamic>> _productosSeleccionados = [];
  double _total = 0.0;
  final DataService _dbService = DataService();
  bool _isProcessing = false;

  void _agregarProducto(Producto producto, int cantidad) {
    final subtotal = producto.precio * cantidad;

    setState(() {
      final index = _productosSeleccionados.indexWhere(
        (item) => item['producto'].id == producto.id,
      );

      if (index >= 0) {
        _productosSeleccionados[index]['cantidad'] += cantidad;
        _productosSeleccionados[index]['subtotal'] += subtotal;
      } else {
        _productosSeleccionados.add({
          'producto': producto,
          'cantidad': cantidad,
          'subtotal': subtotal,
        });
      }

      _total += subtotal;
    });
  }

  void _eliminarProducto(int index) {
    setState(() {
      _total -= _productosSeleccionados[index]['subtotal'];
      _productosSeleccionados.removeAt(index);
    });
  }

  void _modificarCantidad(int index, int nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      _eliminarProducto(index);
      return;
    }

    setState(() {
      final producto = _productosSeleccionados[index]['producto'];
      final diferencia = nuevaCantidad - _productosSeleccionados[index]['cantidad'];
      _productosSeleccionados[index]['cantidad'] = nuevaCantidad;
      _productosSeleccionados[index]['subtotal'] = producto.precio * nuevaCantidad;
      _total += producto.precio * diferencia;
    });
  }

  Future<void> _finalizarVenta() async {
    if (_selectedClienteId == null || _productosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un cliente y agrega productos')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;
      final venta = Venta(
        userId: currentUserId,
        clienteId: _selectedClienteId,
        clienteNombre: _nombreCliente ?? 'Cliente no especificado',
        fecha: DateTime.now(),
        total: _total,
        estado: 'pendiente',
      );

      List<DetalleVenta> detalles = [];
      for (var item in _productosSeleccionados) {
        detalles.add(DetalleVenta(
          ventaId: '', // Lo asignará el servicio
          productoId: item['producto'].id!,
          cantidad: item['cantidad'],
          precioUnitario: item['producto'].precio,
          subtotal: item['subtotal'],
        ));
      }

      await _dbService.insertVenta(venta, detalles);

      // Actualizar stock de productos
      for (var item in _productosSeleccionados) {
        final producto = item['producto'] as Producto;
        final nuevoStock = producto.stock - (item['cantidad'] as int);
        await _dbService.updateProducto(
          Producto(
            id: producto.id,
            userId: producto.userId,
            nombre: producto.nombre,
            categoriaId: producto.categoriaId,
            costo: producto.costo,
            precio: producto.precio,
            stock: nuevoStock,
          ),
        );
      }

      await _imprimirTicket(venta, _productosSeleccionados);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Venta Registrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('La venta se ha registrado exitosamente.'),
              const SizedBox(height: 8),
              Text(
                'Total: \$${_total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _limpiarFormulario();
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar la venta: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _limpiarFormulario() {
    setState(() {
      _productosSeleccionados.clear();
      _total = 0.0;
      _selectedClienteId = null;
      _nombreCliente = null;
    });
  }

  void _mostrarSeleccionProductos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SeleccionProductosScreen(
        onProductoAgregado: _agregarProducto,
        productosExistentes: _productosSeleccionados,
      ),
    );
  }

  void _mostrarEditarCantidad(int index) {
    final producto = _productosSeleccionados[index]['producto'];
    final cantidadActual = _productosSeleccionados[index]['cantidad'];
    
    final controller = TextEditingController(text: cantidadActual.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificar cantidad'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Cantidad de ${producto.nombre}',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final nuevaCantidad = int.tryParse(controller.text) ?? 0;
              _modificarCantidad(index, nuevaCantidad);
              Navigator.of(context).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _imprimirTicket(Venta venta, List<Map<String, dynamic>> productos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString("printer_address");

      if (address == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No hay impresora guardada")),
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

      // Obtener datos del negocio para personalizar el ticket
      final negocio = await _dbService.getNegocio();

      // Encabezado
      printer.printCustom(negocio?.ticketHeader ?? "TICKET DE VENTA", 2, 1);
      printer.printCustom(negocio?.nombreNegocio ?? "MI NEGOCIO", 2, 1);
      printer.printNewLine();
      printer.printCustom("Cliente: ${venta.clienteNombre}", 1, 0);
      printer.printCustom("Fecha: $fechaFormateada", 1, 0);
      printer.printNewLine();
      
      // Productos
      for (var item in productos) {
        final p = item['producto'];
        final cant = item['cantidad'];
        final subtotal = item['subtotal'];
        printer.printCustom(
          "${p.nombre} $cant  \$${subtotal.toStringAsFixed(2)}",
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
      printer.printNewLine();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al imprimir: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Venta'),
        actions: [
          if (_productosSeleccionados.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _limpiarFormulario,
              tooltip: 'Limpiar todo',
            ),
        ],
      ),
      body: Column(
        children: [
          // Selector de cliente
          ClienteDropdown(
            key: ValueKey(_selectedClienteId), // Forzar reconstrucción si se limpia
            selectedClienteId: _selectedClienteId,
            onClienteSelected: (clienteId, nombreCliente) {
              setState(() {
                _selectedClienteId = clienteId;
                _nombreCliente = nombreCliente;
              });
            },
          ),

          // Info del cliente seleccionado
          if (_nombreCliente != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Cliente: $_nombreCliente',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // Resumen de productos
          Expanded(
            child: _productosSeleccionados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay productos agregados',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Presiona el botón para agregar productos',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Productos (${_productosSeleccionados.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Total: \$${_total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _productosSeleccionados.length,
                          itemBuilder: (context, index) {
                            final item = _productosSeleccionados[index];
                            final producto = item['producto'];
                            
                            return Dismissible(
                              key: Key('${producto.id}-$index'),
                              background: Container(color: Colors.red),
                              onDismissed: (direction) => _eliminarProducto(index),
                              child: ListTile(
                                title: Text(producto.nombre),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Precio: \$${producto.precio.toStringAsFixed(2)}'),
                                    Text('Categoría: ${producto.categoriaNombre ?? 'N/A'}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${item['cantidad']} uds',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '\$${item['subtotal'].toStringAsFixed(2)}',
                                          style: TextStyle(color: Colors.green[700]),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _mostrarEditarCantidad(index),
                                      tooltip: 'Modificar cantidad',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),

          // Botones de acción
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_productosSeleccionados.isNotEmpty)
                  Text(
                    'Total: \$${_total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart),
                        onPressed: _mostrarSeleccionProductos,
                        label: Text(_productosSeleccionados.isEmpty ? 'Agregar Productos' : 'Agregar Más'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _isProcessing 
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        onPressed: _finalizarVenta,
                        label: const Text('Finalizar Venta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------ Selección de productos mejorada ------------------------

class SeleccionProductosScreen extends StatefulWidget {
  final Function(Producto, int) onProductoAgregado;
  final List<Map<String, dynamic>> productosExistentes;

  const SeleccionProductosScreen({
    Key? key,
    required this.onProductoAgregado,
    required this.productosExistentes,
  }) : super(key: key);

  @override
  _SeleccionProductosScreenState createState() => _SeleccionProductosScreenState();
}

class _SeleccionProductosScreenState extends State<SeleccionProductosScreen> {
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  final Map<String, int> _cantidades = {};
  final TextEditingController _searchController = TextEditingController();
  final DataService _dbService = DataService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _searchController.addListener(_filtrarProductos);
    _inicializarCantidades();
  }

  void _inicializarCantidades() {
    for (var item in widget.productosExistentes) {
      _cantidades[item['producto'].id!] = item['cantidad'];
    }
  }

  Future<void> _cargarProductos() async {
    try {
      final productos = await _dbService.getProductos();
      setState(() {
        _productos = productos.where((p) => p.stock > 0).toList();
        _productosFiltrados = List.from(_productos);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filtrarProductos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _productosFiltrados = _productos.where((p) {
        final nombre = p.nombre.toLowerCase();
        final categoria = p.categoriaNombre?.toLowerCase() ?? '';
        return nombre.contains(query) || categoria.contains(query);
      }).toList();
    });
  }

  void _incrementarCantidad(String productoId, int stockDisponible) {
    setState(() {
      final cantidadActual = _cantidades[productoId] ?? 0;
      if (cantidadActual < stockDisponible) {
        _cantidades[productoId] = cantidadActual + 1;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay suficiente stock disponible')),
        );
      }
    });
  }

  void _decrementarCantidad(String productoId) {
    setState(() {
      if (_cantidades[productoId] != null && _cantidades[productoId]! > 0) {
        _cantidades[productoId] = _cantidades[productoId]! - 1;
      }
    });
  }

  void _agregarProductos() {
    for (var producto in _productosFiltrados) {
      final cantidad = _cantidades[producto.id] ?? 0;
      if (cantidad > 0) {
        widget.onProductoAgregado(producto, cantidad);
      }
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          const Text('Seleccionar Productos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar por nombre o categoría',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _productosFiltrados.isEmpty
                ? const Center(child: Text('No se encontraron productos'))
                : ListView.builder(
                    itemCount: _productosFiltrados.length,
                    itemBuilder: (context, index) {
                      final producto = _productosFiltrados[index];
                      final cantidad = _cantidades[producto.id] ?? 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                        child: ListTile(
                          title: Text(producto.nombre),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Precio: \$${producto.precio.toStringAsFixed(2)}'),
                              Text('Categoría: ${producto.categoriaNombre ?? 'N/A'}'),
                              Text('Stock: ${producto.stock} disponibles',
                                  style: TextStyle(
                                    color: producto.stock > 0 ? Colors.green : Colors.red,
                                  )),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => _decrementarCantidad(producto.id!),
                                color: cantidad > 0 ? Colors.red : Colors.grey,
                              ),
                              Container(
                                width: 30,
                                alignment: Alignment.center,
                                child: Text('$cantidad',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => _incrementarCantidad(producto.id!, producto.stock),
                                color: cantidad < producto.stock ? Colors.green : Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _agregarProductos,
                  child: const Text('Agregar Selección'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
