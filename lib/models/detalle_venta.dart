class DetalleVenta {
  final int? id;
  final int ventaId;
  final int productoId;
  final String? productoNombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  DetalleVenta({
    this.id,
    required this.ventaId,
    required this.productoId,
    this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venta_id': ventaId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
    };
  }

  factory DetalleVenta.fromMap(Map<String, dynamic> map) {
    return DetalleVenta(
      id: map['id'],
      ventaId: map['venta_id'],
      productoId: map['producto_id'],
      productoNombre: map['producto_nombre'],
      cantidad: map['cantidad'],
      precioUnitario: map['precio_unitario']?.toDouble() ?? 0.0,
      subtotal: map['subtotal']?.toDouble() ?? 0.0,
    );
  }
}