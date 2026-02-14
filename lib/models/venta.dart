// En models/venta.dart
class Venta {
  final int? id;
  final int? clienteId;
  final String clienteNombre;
  final DateTime fecha; // Fecha de creación del pedido
  final DateTime? fechaEntrega; // NUEVO: Fecha cuando se marcó como entregado
  final double total;
  final String estado;

  Venta({
    this.id,
    this.clienteId,
    required this.clienteNombre,
    required this.fecha,
    this.fechaEntrega, // NUEVO
    required this.total,
    required this.estado,
  });

  // En el método fromMap, agrega:
  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      id: map['id'],
      clienteId: map['cliente_id'],
      clienteNombre: map['cliente_nombre'] ?? '',
      fecha: DateTime.parse(map['fecha']),
      fechaEntrega: map['fecha_entrega'] != null ? DateTime.parse(map['fecha_entrega']) : null, // NUEVO
      total: map['total']?.toDouble() ?? 0.0,
      estado: map['estado'] ?? 'pendiente',
    );
  }

  // En el método toMap, agrega:
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'fecha': fecha.toIso8601String(),
      'fecha_entrega': fechaEntrega?.toIso8601String(), // NUEVO
      'total': total,
      'estado': estado,
    };
  }
}