class Credito {
  final int? id;
  final int clienteId;
  final String? clienteNombre;
  final double monto;
  final double saldoPendiente;
  final DateTime fecha;

  Credito({
    this.id,
    required this.clienteId,
    this.clienteNombre,
    required this.monto,
    required this.saldoPendiente,
    required this.fecha,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'monto': monto,
      'saldo_pendiente': saldoPendiente,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Credito.fromMap(Map<String, dynamic> map) {
    return Credito(
      id: map['id'],
      clienteId: map['cliente_id'],
      clienteNombre: map['cliente_nombre'],
      monto: map['monto']?.toDouble() ?? 0.0,
      saldoPendiente: map['saldo_pendiente']?.toDouble() ?? 0.0,
      fecha: DateTime.parse(map['fecha']),
    );
  }
}