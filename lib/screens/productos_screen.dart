import 'package:flutter/material.dart';
import 'package:refrescos_app/database/database_helper.dart';
import 'package:refrescos_app/models/marca.dart';
import 'package:refrescos_app/models/producto.dart';
import 'package:refrescos_app/widgets/producto_card.dart';

class ProductosScreen extends StatefulWidget {
  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  List<Marca> _marcas = [];
  
  // Variables para filtros
  String _filtroBusqueda = '';
  int? _filtroMarcaId;
  String _orden = 'nombre';
  bool _ordenAscendente = true;
  
  // Controladores
  final TextEditingController _busquedaController = TextEditingController();
  
  // Estado del panel de filtros
  bool _mostrarFiltros = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _busquedaController.addListener(_aplicarFiltroBusqueda);
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final dbHelper = DatabaseHelper();
    final productos = await dbHelper.getProductosConMarca();
    final marcas = await dbHelper.getMarcas();
    
    setState(() {
      _productos = productos;
      _marcas = marcas;
      _aplicarFiltros();
    });
  }

  void _aplicarFiltroBusqueda() {
    setState(() {
      _filtroBusqueda = _busquedaController.text.toLowerCase();
      _aplicarFiltros();
    });
  }

  void _aplicarFiltros() {
    List<Producto> productosFiltrados = List.from(_productos);
    
    // Aplicar filtro de búsqueda por nombre
    if (_filtroBusqueda.isNotEmpty) {
      productosFiltrados = productosFiltrados.where((producto) => 
        producto.nombre.toLowerCase().contains(_filtroBusqueda)
      ).toList();
    }
    
    // Aplicar filtro por marca
    if (_filtroMarcaId != null) {
      productosFiltrados = productosFiltrados.where((producto) => 
        producto.marcaId == _filtroMarcaId
      ).toList();
    }
    
    // Aplicar ordenamiento
    productosFiltrados.sort((a, b) {
      int resultado;
      switch (_orden) {
        case 'nombre':
          resultado = a.nombre.compareTo(b.nombre);
          break;
        case 'precio':
          resultado = a.precio.compareTo(b.precio);
          break;
        case 'stock':
          resultado = a.stock.compareTo(b.stock);
          break;
        default:
          resultado = a.nombre.compareTo(b.nombre);
      }
      return _ordenAscendente ? resultado : -resultado;
    });
    
    setState(() {
      _productosFiltrados = productosFiltrados;
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroBusqueda = '';
      _filtroMarcaId = null;
      _orden = 'nombre';
      _ordenAscendente = true;
      _busquedaController.clear();
      _aplicarFiltros();
    });
  }

  void _mostrarDialogoProducto({Producto? producto}) {
    showDialog(
      context: context,
      builder: (context) => ProductoDialog(
        producto: producto,
        marcas: _marcas,
        onGuardar: _guardarProducto,
      ),
    ).then((_) => _cargarDatos());
  }

  Future<void> _guardarProducto(Producto producto) async {
    final dbHelper = DatabaseHelper();
    if (producto.id == null) {
      await dbHelper.insertProducto(producto);
    } else {
      await dbHelper.updateProducto(producto);
    }
    _cargarDatos();
  }

  Future<void> _eliminarProducto(int id) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.deleteProducto(id);
    _cargarDatos();
  }

  Widget _buildFiltrosPanel() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height: _mostrarFiltros ? 180 : 0,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Filtro por marca
            Row(
              children: [
                Text('Marca:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _filtroMarcaId,
                    hint: Text('Todas las marcas'),
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text('Todas las marcas'),
                      ),
                      ..._marcas.map((marca) => DropdownMenuItem<int>(
                        value: marca.id,
                        child: Text(marca.nombre),
                      )).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filtroMarcaId = value;
                        _aplicarFiltros();
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            
            // Opciones de ordenamiento
            Row(
              children: [
                Text('Ordenar por:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _orden,
                    items: [
                      DropdownMenuItem<String>(
                        value: 'nombre',
                        child: Text('Nombre'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'precio',
                        child: Text('Precio'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'stock',
                        child: Text('Stock'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _orden = value!;
                        _aplicarFiltros();
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(_ordenAscendente ? Icons.arrow_upward : Icons.arrow_downward),
                  onPressed: () {
                    setState(() {
                      _ordenAscendente = !_ordenAscendente;
                      _aplicarFiltros();
                    });
                  },
                  tooltip: _ordenAscendente ? 'Ascendente' : 'Descendente',
                ),
              ],
            ),
            SizedBox(height: 10),
            
            // Botón para limpiar filtros
            ElevatedButton.icon(
              onPressed: _limpiarFiltros,
              icon: Icon(Icons.clear_all),
              label: Text('Limpiar filtros'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Productos'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoProducto(),
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
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
                  '${_productosFiltrados.length} de ${_productos.length} productos',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (_filtroMarcaId != null || _filtroBusqueda.isNotEmpty)
                  Chip(
                    label: Text('Filtros activos'),
                    backgroundColor: Colors.blue[100],
                  ),
              ],
            ),
          ),
          
          // Lista de productos
          Expanded(
            child: _productosFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No se encontraron productos',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        if (_filtroMarcaId != null || _filtroBusqueda.isNotEmpty)
                          TextButton(
                            onPressed: _limpiarFiltros,
                            child: Text('Limpiar filtros'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _productosFiltrados.length,
                    itemBuilder: (context, index) {
                      final producto = _productosFiltrados[index];
                      return ProductoCard(
                        producto: producto,
                        onEdit: () => _mostrarDialogoProducto(producto: producto),
                        onDelete: () => _eliminarProducto(producto.id!),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


class ProductoDialog extends StatefulWidget {
  final Producto? producto;
  final List<Marca> marcas;
  final Function(Producto) onGuardar;

  const ProductoDialog({
    Key? key,
    this.producto,
    required this.marcas,
    required this.onGuardar,
  }) : super(key: key);

  @override
  _ProductoDialogState createState() => _ProductoDialogState();
}

class _ProductoDialogState extends State<ProductoDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _nombre;
  late int? _marcaId;
  late double _costo;
  late double _precio;
  late int _stock;

  @override
  void initState() {
    super.initState();
    _nombre = widget.producto?.nombre ?? '';
    _marcaId = widget.producto?.marcaId;
    _costo = widget.producto?.costo ?? 0.0;
    _precio = widget.producto?.precio ?? 0.0;
    _stock = widget.producto?.stock ?? 0;
  }

  void _guardar() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final producto = Producto(
        id: widget.producto?.id,
        nombre: _nombre,
        marcaId: _marcaId,
        costo: _costo,
        precio: _precio,
        stock: _stock,
      );
      
      widget.onGuardar(producto);
      Navigator.of(context).pop();
    }
  }

  void _mostrarDialogoMarca() {
    showDialog(
      context: context,
      builder: (context) => MarcaDialog(),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.producto == null ? 'Nuevo Producto' : 'Editar Producto'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _nombre,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un nombre';
                  }
                  return null;
                },
                onSaved: (value) => _nombre = value!,
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _marcaId,
                      decoration: InputDecoration(labelText: 'Marca'),
                      items: widget.marcas.map((Marca marca) {
                        return DropdownMenuItem<int>(
                          value: marca.id,
                          child: Text(marca.nombre),
                        );
                      }).toList(),
                      onChanged: (value) => _marcaId = value,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: _mostrarDialogoMarca,
                    tooltip: 'Agregar nueva marca',
                  ),
                ],
              ),
              TextFormField(
                initialValue: _costo.toString(),
                decoration: InputDecoration(labelText: 'Costo'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null) {
                    return 'Ingresa un costo válido';
                  }
                  return null;
                },
                onSaved: (value) => _costo = double.parse(value!),
              ),
              TextFormField(
                initialValue: _precio.toString(),
                decoration: InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null) {
                    return 'Ingresa un precio válido';
                  }
                  return null;
                },
                onSaved: (value) => _precio = double.parse(value!),
              ),
              TextFormField(
                initialValue: _stock.toString(),
                decoration: InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null) {
                    return 'Ingresa un stock válido';
                  }
                  return null;
                },
                onSaved: (value) => _stock = int.parse(value!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardar,
          child: Text('Guardar'),
        ),
      ],
    );
  }
}

class MarcaDialog extends StatefulWidget {
  @override
  _MarcaDialogState createState() => _MarcaDialogState();
}

class _MarcaDialogState extends State<MarcaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();

  Future<void> _guardarMarca() async {
    if (_formKey.currentState!.validate()) {
      final dbHelper = DatabaseHelper();
      final marca = Marca(nombre: _nombreController.text);
      await dbHelper.insertMarca(marca);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nueva Marca'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nombreController,
          decoration: InputDecoration(labelText: 'Nombre de la marca'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa un nombre';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardarMarca,
          child: Text('Guardar'),
        ),
      ],
    );
  }
}