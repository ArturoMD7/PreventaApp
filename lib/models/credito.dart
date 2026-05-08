class Credito {
  final String? id;
  final String userId;
  final String clienteId;
  final String? clienteNombre;
  final double monto;
  final double saldoPendiente;
  final DateTime fecha;

  Credito({
    this.id,
    required this.userId,
    required this.clienteId,
    this.clienteNombre,
    required this.monto,
    required this.saldoPendiente,
    required this.fecha,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'cliente_id': clienteId,
      'monto': monto,
      'saldo_pendiente': saldoPendiente,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Credito.fromMap(Map<String, dynamic> map) {
    return Credito(
      id: map['id'],
      userId: map['user_id'],
      clienteId: map['cliente_id'],
      clienteNombre: map['cliente_nombre'] ?? map['clientes']?['nombre'],
      monto: map['monto']?.toDouble() ?? 0.0,
      saldoPendiente: map['saldo_pendiente']?.toDouble() ?? 0.0,
      fecha: DateTime.parse(map['fecha']),
    );
  }
}