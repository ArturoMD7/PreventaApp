class Envase {
  final int? id;
  final int clienteId;
  final String? clienteNombre;
  final int productoId;
  final String? productoNombre;
  final int cantidad;
  final DateTime fechaPrestamo;
  final DateTime? fechaDevolucion;

  Envase({
    this.id,
    required this.clienteId,
    this.clienteNombre,
    required this.productoId,
    this.productoNombre,
    required this.cantidad,
    required this.fechaPrestamo,
    this.fechaDevolucion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'fecha_prestamo': fechaPrestamo.toIso8601String(),
      'fecha_devolucion': fechaDevolucion?.toIso8601String(),
    };
  }

  factory Envase.fromMap(Map<String, dynamic> map) {
    return Envase(
      id: map['id'],
      clienteId: map['cliente_id'],
      clienteNombre: map['cliente_nombre'],
      productoId: map['producto_id'],
      productoNombre: map['producto_nombre'],
      cantidad: map['cantidad'],
      fechaPrestamo: DateTime.parse(map['fecha_prestamo']),
      fechaDevolucion: map['fecha_devolucion'] != null 
          ? DateTime.parse(map['fecha_devolucion']) 
          : null,
    );
  }
}