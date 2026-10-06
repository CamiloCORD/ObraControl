class TrabajadorModel {
  final String id;
  final String nombre;
  final String cedula;
  final String telefono;
  final String rol; // 'Ayudante de Obra', 'Técnico Instalador', 'Dueño con labor de Técnico'
  final bool activo;

  TrabajadorModel({
    required this.id,
    required this.nombre,
    this.cedula = '',
    required this.telefono,
    required this.rol,
    this.activo = true,
  });

  bool get esAyudante {
    final r = rol.trim().toLowerCase();
    return r == 'ayudante de obra' || r == 'ayudante';
  }

  bool get esTecnico => !esAyudante;

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'cedula': cedula,
      'telefono': telefono,
      'rol': rol,
      'activo': activo,
    };
  }

  factory TrabajadorModel.fromMap(String id, Map<String, dynamic> map) {
    String rawRol = map['rol'] ?? 'Ayudante de Obra';
    // Normalización de roles históricos
    if (rawRol.toLowerCase() == 'ayudante') {
      rawRol = 'Ayudante de Obra';
    } else if (rawRol.toLowerCase() == 'tecnico') {
      rawRol = 'Técnico Instalador';
    } else if (rawRol.toLowerCase() == 'dueno_tecnico') {
      rawRol = 'Dueño con labor de Técnico';
    }

    return TrabajadorModel(
      id: id,
      nombre: map['nombre'] ?? '',
      cedula: map['cedula'] ?? '',
      telefono: map['telefono'] ?? '',
      rol: rawRol,
      activo: map['activo'] ?? true,
    );
  }

  TrabajadorModel copyWith({
    String? id,
    String? nombre,
    String? cedula,
    String? telefono,
    String? rol,
    bool? activo,
  }) {
    return TrabajadorModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      cedula: cedula ?? this.cedula,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
    );
  }
}