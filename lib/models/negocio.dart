class Negocio {
  final String id;
  final String nombreNegocio;
  final String? ticketHeader;
  final String? ticketFooter;
  final String? logoUrl;

  Negocio({
    required this.id,
    required this.nombreNegocio,
    this.ticketHeader,
    this.ticketFooter,
    this.logoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre_negocio': nombreNegocio,
      'ticket_header': ticketHeader,
      'ticket_footer': ticketFooter,
      'logo_url': logoUrl,
    };
  }

  factory Negocio.fromMap(Map<String, dynamic> map) {
    return Negocio(
      id: map['id'],
      nombreNegocio: map['nombre_negocio'],
      ticketHeader: map['ticket_header'],
      ticketFooter: map['ticket_footer'],
      logoUrl: map['logo_url'],
    );
  }
}
