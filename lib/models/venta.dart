class Venta {
  final String? id;
  final String userId;
  final String? clienteId;
  final String clienteNombre;
  final DateTime fecha; 
  final DateTime? fechaEntrega; 
  final double total;
  final String estado;

  Venta({
    this.id,
    required this.userId,
    this.clienteId,
    required this.clienteNombre,
    required this.fecha,
    this.fechaEntrega, 
    required this.total,
    required this.estado,
  });

  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      id: map['id'],
      userId: map['user_id'],
      clienteId: map['cliente_id'],
      clienteNombre: map['cliente_nombre'] ?? map['clientes']?['nombre'] ?? '',
      fecha: DateTime.parse(map['fecha']),
      fechaEntrega: map['fecha_entrega'] != null ? DateTime.parse(map['fecha_entrega']) : null,
      total: map['total']?.toDouble() ?? 0.0,
      estado: map['estado'] ?? 'pendiente',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'cliente_id': clienteId,
      'fecha': fecha.toIso8601String(),
      'fecha_entrega': fechaEntrega?.toIso8601String(), 
      'total': total,
      'estado': estado,
    };
  }
}