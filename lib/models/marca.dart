class Marca {
  final int? id;
  final String nombre;

  Marca({
    this.id,
    required this.nombre,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }

  factory Marca.fromMap(Map<String, dynamic> map) {
    return Marca(
      id: map['id'],
      nombre: map['nombre'],
    );
  }
}