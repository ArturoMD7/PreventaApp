class Prestamo {
  final String? id;
  final String userId;
  final String clienteId;
  final String? clienteNombre;
  final String descripcion;
  final int cantidad;
  final DateTime fechaPrestamo;
  final DateTime? fechaDevolucion;

  Prestamo({
    this.id,
    required this.userId,
    required this.clienteId,
    this.clienteNombre,
    required this.descripcion,
    required this.cantidad,
    required this.fechaPrestamo,
    this.fechaDevolucion,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'cliente_id': clienteId,
      'descripcion': descripcion,
      'cantidad': cantidad,
      'fecha_prestamo': fechaPrestamo.toIso8601String(),
      'fecha_devolucion': fechaDevolucion?.toIso8601String(),
    };
  }

  factory Prestamo.fromMap(Map<String, dynamic> map) {
    return Prestamo(
      id: map['id'],
      userId: map['user_id'],
      clienteId: map['cliente_id'],
      // clienteNombre isn't stored in this table usually, we join it when querying
      clienteNombre: map['cliente_nombre'] ?? map['clientes']?['nombre'],
      descripcion: map['descripcion'],
      cantidad: map['cantidad'],
      fechaPrestamo: DateTime.parse(map['fecha_prestamo']),
      fechaDevolucion: map['fecha_devolucion'] != null 
          ? DateTime.parse(map['fecha_devolucion']) 
          : null,
    );
  }
}
