class ViviendaModel {
  /// Genera un ID compuesto y normalizado para evitar colisiones entre lotes.
  /// Formato: "${loteId}_${codigoCasa}".toUpperCase(), sin espacios.
  /// Ejemplo: "ABC123_M1-L05"
  static String generarIdCompuesto(String loteId, String codigoCasa) {
    final loteNorm = loteId.trim().replaceAll(' ', '').toUpperCase();
    final codigoNorm = codigoCasa.trim().replaceAll(' ', '').toUpperCase();
    return '${loteNorm}_$codigoNorm';
  }

  final String id; // ID del documento Firestore (compuesto o simple)
  final String? codigo; // Código legible directo de la vivienda (ej. "M1-L05", "L1-01")
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
  final String nombrePropietario;
  final String propietarioCedula;
  final String propietarioTelefono;
  final DateTime fechaRegistro;
  final DateTime? fechaInstalacion;
  final DateTime? fechaTerminacion; // Se registra automáticamente al marcar como 'Terminada'
  final String semanaId;

  ViviendaModel({
    required this.id,
    this.codigo,
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
    String nombrePropietario = '',
    String? propietarioNombre,
    this.propietarioCedula = '',
    this.propietarioTelefono = '',
    DateTime? fechaRegistro,
    this.fechaInstalacion,
    this.fechaTerminacion,
    this.semanaId = '',
    List<String>? fotosUrls,
    String? numero,
  })  : nombrePropietario = nombrePropietario.isNotEmpty
            ? nombrePropietario
            : (propietarioNombre ?? ''),
        fechaRegistro = fechaRegistro ?? DateTime.now();

  bool get estaTerminada => estado.trim().toLowerCase() == 'terminada';
  List<String> get fotosUrls => fotos;

  /// Retorna el código visual legible para tarjetas, encabezados y reportes (ej. "M1-L05", "L1-01").
  /// Si [codigo] está definido y no vacío, lo retorna.
  /// Si el [id] compuesto tiene la estructura "${loteId}_${codigo}", extrae la parte posterior al primer '_'.
  /// En caso contrario, retorna el [id] o el [numeroCasa].
  String get codigoVisual {
    if (codigo != null && codigo!.trim().isNotEmpty) {
      return codigo!.trim();
    }
    if (id.contains('_')) {
      final partes = id.split('_');
      if (partes.length > 1) {
        final sub = partes.sublist(1).join('_').trim();
        if (sub.isNotEmpty) return sub;
      }
    }
    if (numeroCasa > 0) {
      return '$numeroCasa';
    }
    return id;
  }

  String get numero => codigoVisual;
  String get propietarioNombre => nombrePropietario;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigoVisual,
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
      'nombrePropietario': nombrePropietario,
      'propietarioNombre': nombrePropietario,
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

    final rawNombreProp = map['nombrePropietario'] ?? map['propietarioNombre'] ?? '';
    final nombreProp = rawNombreProp is String ? rawNombreProp : rawNombreProp.toString();

    final rawCodigo = map['codigo'] ?? map['codigoCasa'] ?? map['codigoVivienda'] ?? (map['id'] != null && map['id'] != id ? map['id'] : null);
    final String? codigoStr = rawCodigo is String ? rawCodigo : rawCodigo?.toString();

    return ViviendaModel(
      id: id,
      codigo: codigoStr,
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
      nombrePropietario: nombreProp,
      propietarioCedula: map['propietarioCedula'] ?? '',
      propietarioTelefono: map['propietarioTelefono'] ?? '',
      fechaRegistro:
          _parseFecha(map['fechaRegistro']) ?? DateTime.now(),
      fechaInstalacion: _parseFecha(map['fechaInstalacion']),
      fechaTerminacion: _parseFecha(map['fechaTerminacion']),
      semanaId: map['semanaId'] ?? '',
    );
  }

  static DateTime? _parseFecha(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    try {
      return (val as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(val.toString());
    }
  }

  ViviendaModel copyWith({
    String? id,
    String? codigo,
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
    String? nombrePropietario,
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
      codigo: codigo ?? this.codigo,
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
      nombrePropietario: nombrePropietario ?? propietarioNombre ?? this.nombrePropietario,
      propietarioCedula: propietarioCedula ?? this.propietarioCedula,
      propietarioTelefono: propietarioTelefono ?? this.propietarioTelefono,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      fechaInstalacion: fechaInstalacion ?? this.fechaInstalacion,
      fechaTerminacion: clearFechaTerminacion ? null : (fechaTerminacion ?? this.fechaTerminacion),
      semanaId: semanaId ?? this.semanaId,
    );
  }
}