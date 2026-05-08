class Producto {
  final String? id;
  final String userId;
  final String nombre;
  final String? categoriaId;
  final String? categoriaNombre;
  final double costo;
  final double precio;
  final int stock;

  Producto({
    this.id,
    required this.userId,
    required this.nombre,
    this.categoriaId,
    this.categoriaNombre,
    required this.costo,
    required this.precio,
    this.stock = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'nombre': nombre,
      'categoria_id': categoriaId,
      'costo': costo,
      'precio': precio,
      'stock': stock,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      userId: map['user_id'],
      nombre: map['nombre'],
      categoriaId: map['categoria_id'],
      categoriaNombre: map['categoria_nombre'] ?? map['categorias']?['nombre'],
      costo: map['costo']?.toDouble() ?? 0.0,
      precio: map['precio']?.toDouble() ?? 0.0,
      stock: map['stock'] ?? 0,
    );
  }
}