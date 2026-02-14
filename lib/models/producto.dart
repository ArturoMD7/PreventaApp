class Producto {
  final int? id;
  final String nombre;
  final int? marcaId;
  final String? marcaNombre;
  final double costo;
  final double precio;
  final int stock;

  Producto({
    this.id,
    required this.nombre,
    this.marcaId,
    this.marcaNombre,
    required this.costo,
    required this.precio,
    this.stock = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'marca_id': marcaId,
      'costo': costo,
      'precio': precio,
      'stock': stock,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      nombre: map['nombre'],
      marcaId: map['marca_id'],
      marcaNombre: map['marca_nombre'],
      costo: map['costo']?.toDouble() ?? 0.0,
      precio: map['precio']?.toDouble() ?? 0.0,
      stock: map['stock'] ?? 0,
    );
  }
}