class ViviendaModel {
  final String id; // ej. "L1-01"
  final String loteId;
  final int numeroCasa;
  final String estado; // 'Pendiente', 'En Proceso', 'Terminada'
  final String tecnicoId;
  final String tecnicoNombre;
  final String observaciones;
  final List<String> fotos;
  final String loteNombre;
  final String etapaId;
  final String direccion;
  final String propietarioNombre;
  final String propietarioCedula;
  final String propietarioTelefono;
  final DateTime fechaRegistro;
  final DateTime? fechaInstalacion;
  final DateTime? fechaTerminacion; // Se registra automáticamente al marcar como 'Terminada'
  final String semanaId;

  ViviendaModel({
    required this.id,
    required this.loteId,
    required this.numeroCasa,
    this.estado = 'Pendiente',
    this.tecnicoId = '',
    this.tecnicoNombre = '',
    this.observaciones = '',
    this.fotos = const [],
    this.loteNombre = '',
    this.etapaId = '',
    this.direccion = '',
    this.propietarioNombre = '',
    this.propietarioCedula = '',
    this.propietarioTelefono = '',
    DateTime? fechaRegistro,
    this.fechaInstalacion,
    this.fechaTerminacion,
    this.semanaId = '',
    List<String>? fotosUrls,
    String? numero,
  })  : fechaRegistro = fechaRegistro ?? DateTime.now();

  bool get estaTerminada => estado.trim().toLowerCase() == 'terminada';
  List<String> get fotosUrls => fotos;
  String get numero => id.isNotEmpty ? id : '$numeroCasa';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loteId': loteId,
      'numeroCasa': numeroCasa,
      'estado': estado,
      'tecnicoId': tecnicoId,
      'tecnicoNombre': tecnicoNombre,
      'observaciones': observaciones,
      'fotos': fotos,
      'fotosUrls': fotos,
      'loteNombre': loteNombre,
      'etapaId': etapaId,
      'direccion': direccion,
      'propietarioNombre': propietarioNombre,
      'propietarioCedula': propietarioCedula,
      'propietarioTelefono': propietarioTelefono,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'fechaInstalacion': fechaInstalacion?.toIso8601String(),
      'fechaTerminacion': fechaTerminacion?.toIso8601String(),
      'semanaId': semanaId,
    };
  }

  factory ViviendaModel.fromMap(String id, Map<String, dynamic> map) {
    final fotosList =
        List<String>.from(map['fotos'] ?? map['fotosUrls'] ?? []);
    int numCasa = 0;
    if (map['numeroCasa'] is num) {
      numCasa = (map['numeroCasa'] as num).toInt();
    } else if (map['numero'] != null) {
      final parsed = int.tryParse(map['numero']
          .toString()
          .replaceAll(RegExp(r'^[A-Za-z0-9]+-'), ''));
      if (parsed != null) numCasa = parsed;
    }
    if (numCasa == 0 && id.contains('-')) {
      numCasa = int.tryParse(id.split('-').last) ?? 0;
    }

    return ViviendaModel(
      id: id,
      loteId: map['loteId'] ?? '',
      numeroCasa: numCasa,
      estado: map['estado'] ?? 'Pendiente',
      tecnicoId: map['tecnicoId'] ?? '',
      tecnicoNombre: map['tecnicoNombre'] ?? '',
      observaciones: map['observaciones'] ?? '',
      fotos: fotosList,
      loteNombre: map['loteNombre'] ?? '',
      etapaId: map['etapaId'] ?? '',
      direccion: map['direccion'] ?? '',
      propietarioNombre: map['propietarioNombre'] ?? '',
      propietarioCedula: map['propietarioCedula'] ?? '',
      propietarioTelefono: map['propietarioTelefono'] ?? '',
      fechaRegistro:
          DateTime.tryParse(map['fechaRegistro'] ?? '') ?? DateTime.now(),
      fechaInstalacion: map['fechaInstalacion'] != null
          ? DateTime.tryParse(map['fechaInstalacion'])
          : null,
      fechaTerminacion: map['fechaTerminacion'] != null
          ? DateTime.tryParse(map['fechaTerminacion'])
          : null,
      semanaId: map['semanaId'] ?? '',
    );
  }

  ViviendaModel copyWith({
    String? id,
    String? loteId,
    int? numeroCasa,
    String? estado,
    String? tecnicoId,
    String? tecnicoNombre,
    String? observaciones,
    List<String>? fotos,
    String? loteNombre,
    String? etapaId,
    String? direccion,
    String? propietarioNombre,
    String? propietarioCedula,
    String? propietarioTelefono,
    DateTime? fechaRegistro,
    DateTime? fechaInstalacion,
    DateTime? fechaTerminacion,
    bool clearFechaTerminacion = false,
    String? semanaId,
  }) {
    return ViviendaModel(
      id: id ?? this.id,
      loteId: loteId ?? this.loteId,
      numeroCasa: numeroCasa ?? this.numeroCasa,
      estado: estado ?? this.estado,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      tecnicoNombre: tecnicoNombre ?? this.tecnicoNombre,
      observaciones: observaciones ?? this.observaciones,
      fotos: fotos ?? this.fotos,
      loteNombre: loteNombre ?? this.loteNombre,
      etapaId: etapaId ?? this.etapaId,
      direccion: direccion ?? this.direccion,
      propietarioNombre: propietarioNombre ?? this.propietarioNombre,
      propietarioCedula: propietarioCedula ?? this.propietarioCedula,
      propietarioTelefono: propietarioTelefono ?? this.propietarioTelefono,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      fechaInstalacion: fechaInstalacion ?? this.fechaInstalacion,
      fechaTerminacion: clearFechaTerminacion ? null : (fechaTerminacion ?? this.fechaTerminacion),
      semanaId: semanaId ?? this.semanaId,
    );
  }
}