class Cliente {
  final String? id;
  final String userId;
  final String nombre;
  final String? telefono;
  final String? direccion;
  final double? latitud;
  final double? longitud;

  Cliente({
    this.id,
    required this.userId,
    required this.nombre,
    this.telefono,
    this.direccion,
    this.latitud,
    this.longitud,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'nombre': nombre,
      'telefono': telefono,
      'direccion': direccion,
      'latitud': latitud,
      'longitud': longitud,
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      userId: map['user_id'],
      nombre: map['nombre'],
      telefono: map['telefono'],
      direccion: map['direccion'],
      latitud: map['latitud']?.toDouble(),
      longitud: map['longitud']?.toDouble(),
    );
  }
}