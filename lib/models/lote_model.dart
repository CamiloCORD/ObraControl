class LoteModel {
  final String id;
  final String nombre;
  final String prefijo;
  final int cantidadCasas;
  final DateTime fechaCreacion;
  final String descripcion;

  LoteModel({
    required this.id,
    required this.nombre,
    this.prefijo = '',
    this.cantidadCasas = 0,
    DateTime? fechaCreacion,
    this.descripcion = '',
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'prefijo': prefijo,
      'cantidadCasas': cantidadCasas,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'descripcion': descripcion,
    };
  }

  factory LoteModel.fromMap(String id, Map<String, dynamic> map) {
    return LoteModel(
      id: id,
      nombre: map['nombre'] ?? '',
      prefijo: map['prefijo'] ?? '',
      cantidadCasas: (map['cantidadCasas'] is num)
          ? (map['cantidadCasas'] as num).toInt()
          : 0,
      fechaCreacion:
          DateTime.tryParse(map['fechaCreacion'] ?? '') ?? DateTime.now(),
      descripcion: map['descripcion'] ?? '',
    );
  }

  LoteModel copyWith({
    String? id,
    String? nombre,
    String? prefijo,
    int? cantidadCasas,
    DateTime? fechaCreacion,
    String? descripcion,
  }) {
    return LoteModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      prefijo: prefijo ?? this.prefijo,
      cantidadCasas: cantidadCasas ?? this.cantidadCasas,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      descripcion: descripcion ?? this.descripcion,
    );
  }
}
