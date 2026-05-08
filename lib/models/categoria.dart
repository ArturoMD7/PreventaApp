class Categoria {
  final String? id;
  final String userId;
  final String nombre;

  Categoria({
    this.id,
    required this.userId,
    required this.nombre,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'nombre': nombre,
    };
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'],
      userId: map['user_id'],
      nombre: map['nombre'],
    );
  }
}
