class EtapaModel {
  final String id;
  final String nombre;
  final int metaViviendas;
  final bool activa;

  EtapaModel({
    required this.id,
    required this.nombre,
    required this.metaViviendas,
    required this.activa,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'metaViviendas': metaViviendas,
      'activa': activa,
    };
  }

  factory EtapaModel.fromMap(String id, Map<String, dynamic> map) {
    return EtapaModel(
      id: id,
      nombre: map['nombre'] ?? '',
      metaViviendas: (map['metaViviendas'] as num?)?.toInt() ?? 0,
      activa: map['activa'] ?? true,
    );
  }
}