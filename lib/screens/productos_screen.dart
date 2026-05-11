import 'package:flutter/material.dart';
import 'package:refrescos_app/services/data_service.dart';
import 'package:refrescos_app/services/sync_service.dart';
import 'package:refrescos_app/models/categoria.dart';
import 'package:refrescos_app/models/producto.dart';
import 'package:refrescos_app/widgets/producto_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductosScreen extends StatefulWidget {
  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  List<Categoria> _categorias = [];
  final DataService _dbService = DataService();
  
  // Variables para filtros
  String _filtroBusqueda = '';
  String? _filtroCategoriaId;
  String _orden = 'nombre';
  bool _ordenAscendente = true;
  bool _isLoading = true;
  
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
    await _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final productos = await _dbService.getProductos();
      final categorias = await _dbService.getCategorias();
      
      setState(() {
        _productos = productos;
        _categorias = categorias;
        _aplicarFiltros();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
    
    // Aplicar filtro por categoria
    if (_filtroCategoriaId != null) {
      productosFiltrados = productosFiltrados.where((producto) => 
        producto.categoriaId == _filtroCategoriaId
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
      _filtroCategoriaId = null;
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
        categorias: _categorias,
        onGuardar: _guardarProducto,
      ),
    ).then((_) => _cargarDatos());
  }

  Future<void> _guardarProducto(Producto producto) async {
    setState(() => _isLoading = true);
    try {
      if (producto.id == null) {
        await _dbService.insertProducto(producto);
      } else {
        await _dbService.updateProducto(producto);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar producto: $e'), backgroundColor: Colors.red),
      );
    }
    await _cargarDatos();
  }

  Future<void> _eliminarProducto(String id) async {
    setState(() => _isLoading = true);
    try {
      await _dbService.deleteProducto(id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar producto: $e'), backgroundColor: Colors.red),
      );
    }
    await _cargarDatos();
  }

  Widget _buildFiltrosPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _mostrarFiltros ? 180 : 0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Filtro por categoria
            Row(
              children: [
                const Text('Categoría:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _filtroCategoriaId,
                    hint: const Text('Todas las categorías'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todas las categorías'),
                      ),
                      ..._categorias.map((cat) => DropdownMenuItem<String>(
                        value: cat.id,
                        child: Text(cat.nombre),
                      )).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filtroCategoriaId = value;
                        _aplicarFiltros();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Opciones de ordenamiento
            Row(
              children: [
                const Text('Ordenar por:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _orden,
                    items: const [
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
            const SizedBox(height: 10),
            
            // Botón para limpiar filtros
            ElevatedButton.icon(
              onPressed: _limpiarFiltros,
              icon: const Icon(Icons.clear_all),
              label: const Text('Limpiar filtros'),
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
        title: const Text('Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _sincronizarYCargar,
            tooltip: 'Sincronizar y actualizar',
          ),
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
        child: const Icon(Icons.add),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                prefixIcon: const Icon(Icons.search),
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
                if (_filtroCategoriaId != null || _filtroBusqueda.isNotEmpty)
                  Chip(
                    label: const Text('Filtros activos'),
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
                        const Icon(Icons.search_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No se encontraron productos',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        if (_filtroCategoriaId != null || _filtroBusqueda.isNotEmpty)
                          TextButton(
                            onPressed: _limpiarFiltros,
                            child: const Text('Limpiar filtros'),
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
  final List<Categoria> categorias;
  final Function(Producto) onGuardar;

  const ProductoDialog({
    Key? key,
    this.producto,
    required this.categorias,
    required this.onGuardar,
  }) : super(key: key);

  @override
  _ProductoDialogState createState() => _ProductoDialogState();
}

class _ProductoDialogState extends State<ProductoDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _nombre;
  String? _categoriaId;
  late double _costo;
  late double _precio;
  late int _stock;

  @override
  void initState() {
    super.initState();
    _nombre = widget.producto?.nombre ?? '';
    _categoriaId = widget.producto?.categoriaId;
    _costo = widget.producto?.costo ?? 0.0;
    _precio = widget.producto?.precio ?? 0.0;
    _stock = widget.producto?.stock ?? 0;
  }

  void _guardar() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;
      final producto = Producto(
        id: widget.producto?.id,
        userId: widget.producto?.userId ?? currentUserId,
        nombre: _nombre,
        categoriaId: _categoriaId,
        costo: _costo,
        precio: _precio,
        stock: _stock,
      );
      
      widget.onGuardar(producto);
      Navigator.of(context).pop();
    }
  }

  void _mostrarDialogoCategoria() {
    showDialog(
      context: context,
      builder: (context) => CategoriaDialog(),
    ).then((_) {
      // Necesita refrescarse llamando al padre, que a su vez refresque las categorías.
      // O idealmente devolvemos el valor para recargar la lista de categorias en la UI padre.
      Navigator.of(context).pop(); 
    });
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
                decoration: const InputDecoration(labelText: 'Nombre'),
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
                    child: DropdownButtonFormField<String>(
                      value: _categoriaId,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: widget.categorias.map((Categoria cat) {
                        return DropdownMenuItem<String>(
                          value: cat.id,
                          child: Text(cat.nombre),
                        );
                      }).toList(),
                      onChanged: (value) => _categoriaId = value,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _mostrarDialogoCategoria,
                    tooltip: 'Agregar nueva categoría',
                  ),
                ],
              ),
              TextFormField(
                initialValue: _costo.toString(),
                decoration: const InputDecoration(labelText: 'Costo'),
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
                decoration: const InputDecoration(labelText: 'Precio'),
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
                decoration: const InputDecoration(labelText: 'Stock'),
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
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class CategoriaDialog extends StatefulWidget {
  @override
  _CategoriaDialogState createState() => _CategoriaDialogState();
}

class _CategoriaDialogState extends State<CategoriaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();

  Future<void> _guardarCategoria() async {
    if (_formKey.currentState!.validate()) {
      final dbService = DataService();
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;
      final cat = Categoria(userId: currentUserId, nombre: _nombreController.text);
      try {
        await dbService.insertCategoria(cat);
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear categoría: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Categoría'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(labelText: 'Nombre de la categoría'),
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
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardarCategoria,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
