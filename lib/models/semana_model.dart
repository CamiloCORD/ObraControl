class PrestamoModel {
  final String id;
  final String trabajadorId;
  final String trabajadorNombre;
  final double monto;
  final DateTime fecha;
  final String concepto;
  final String semanaId;

  PrestamoModel({
    required this.id,
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.monto,
    required this.fecha,
    required this.concepto,
    required this.semanaId,
  });

  Map<String, dynamic> toMap() {
    return {
      'trabajadorId': trabajadorId,
      'trabajadorNombre': trabajadorNombre,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'concepto': concepto,
      'semanaId': semanaId,
    };
  }

  factory PrestamoModel.fromMap(String id, Map<String, dynamic> map) {
    return PrestamoModel(
      id: id,
      trabajadorId: map['trabajadorId'] ?? '',
      trabajadorNombre: map['trabajadorNombre'] ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      concepto: map['concepto'] ?? 'Préstamo / Vale',
      semanaId: map['semanaId'] ?? '',
    );
  }
}

class AsistenciaModel {
  final String id;
  final String ayudanteId;
  final String nombre;
  final DateTime fecha;
  final bool asistio;
  final String semanaId;

  AsistenciaModel({
    required this.id,
    required this.ayudanteId,
    required this.nombre,
    required this.fecha,
    required this.asistio,
    required this.semanaId,
  });

  Map<String, dynamic> toMap() {
    return {
      'ayudanteId': ayudanteId,
      'nombre': nombre,
      'fecha': fecha.toIso8601String(),
      'fechaString': '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
      'asistio': asistio,
      'semanaId': semanaId,
    };
  }

  factory AsistenciaModel.fromMap(String id, Map<String, dynamic> map) {
    return AsistenciaModel(
      id: id,
      ayudanteId: map['ayudanteId'] ?? '',
      nombre: map['nombre'] ?? '',
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      asistio: map['asistio'] ?? false,
      semanaId: map['semanaId'] ?? '',
    );
  }
}

class RegistroNominaItem {
  final String trabajadorId;
  final String trabajadorNombre;
  final String rol;
  int diasOcasas; // Días para ayudantes, Viviendas terminadas para técnicos
  double tarifaUnitaria;
  double totalAdelantos; // Préstamos / Vales acumulados
  double totalPagado;
  List<PrestamoModel> prestamos;

  RegistroNominaItem({
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.rol,
    this.diasOcasas = 0,
    required this.tarifaUnitaria,
    this.totalAdelantos = 0.0,
    this.totalPagado = 0.0,
    this.prestamos = const [],
  });

  double get totalGenerado => diasOcasas * tarifaUnitaria;
  double get saldoPendiente => totalGenerado - (totalAdelantos + totalPagado);

  bool get esAyudante {
    final r = rol.trim().toLowerCase();
    return r == 'ayudante de obra' || r == 'ayudante';
  }

  bool get esTecnico => !esAyudante;

  Map<String, dynamic> toMap() {
    return {
      'trabajadorId': trabajadorId,
      'trabajadorNombre': trabajadorNombre,
      'rol': rol,
      'diasOcasas': diasOcasas,
      'tarifaUnitaria': tarifaUnitaria,
      'totalAdelantos': totalAdelantos,
      'totalPagado': totalPagado,
      'prestamos': prestamos.map((p) => p.toMap()).toList(),
    };
  }

  factory RegistroNominaItem.fromMap(Map<String, dynamic> map) {
    final rawPrestamos = map['prestamos'] as List<dynamic>? ?? [];
    final prestamosList = rawPrestamos
        .map((p) => PrestamoModel.fromMap('', Map<String, dynamic>.from(p)))
        .toList();

    return RegistroNominaItem(
      trabajadorId: map['trabajadorId'] ?? '',
      trabajadorNombre: map['trabajadorNombre'] ?? '',
      rol: map['rol'] ?? 'Ayudante de Obra',
      diasOcasas: (map['diasOcasas'] as num?)?.toInt() ?? 0,
      tarifaUnitaria: (map['tarifaUnitaria'] as num?)?.toDouble() ?? 50000.0,
      totalAdelantos: (map['totalAdelantos'] as num?)?.toDouble() ?? 0.0,
      totalPagado: (map['totalPagado'] as num?)?.toDouble() ?? 0.0,
      prestamos: prestamosList,
    );
  }

  RegistroNominaItem copyWith({
    String? trabajadorId,
    String? trabajadorNombre,
    String? rol,
    int? diasOcasas,
    double? tarifaUnitaria,
    double? totalAdelantos,
    double? totalPagado,
    List<PrestamoModel>? prestamos,
  }) {
    return RegistroNominaItem(
      trabajadorId: trabajadorId ?? this.trabajadorId,
      trabajadorNombre: trabajadorNombre ?? this.trabajadorNombre,
      rol: rol ?? this.rol,
      diasOcasas: diasOcasas ?? this.diasOcasas,
      tarifaUnitaria: tarifaUnitaria ?? this.tarifaUnitaria,
      totalAdelantos: totalAdelantos ?? this.totalAdelantos,
      totalPagado: totalPagado ?? this.totalPagado,
      prestamos: prestamos ?? this.prestamos,
    );
  }
}

class SemanaModel {
  final String id;
  final String numeroSemana; // Ej: "Semana 12 - Marzo 2026"
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final bool cerrada;
  final List<RegistroNominaItem> registros;
  final List<PrestamoModel> prestamos;

  SemanaModel({
    required this.id,
    required this.numeroSemana,
    required this.fechaInicio,
    required this.fechaFin,
    required this.cerrada,
    required this.registros,
    this.prestamos = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'numeroSemana': numeroSemana,
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaFin': fechaFin.toIso8601String(),
      'cerrada': cerrada,
      'registros': registros.map((x) => x.toMap()).toList(),
      'prestamos': prestamos.map((p) => p.toMap()).toList(),
    };
  }

  factory SemanaModel.fromMap(String id, Map<String, dynamic> map) {
    final rawRegistros = map['registros'] as List<dynamic>? ?? [];
    final registrosList = rawRegistros
        .map((item) => RegistroNominaItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    final rawPrestamos = map['prestamos'] as List<dynamic>? ?? [];
    final prestamosList = rawPrestamos
        .map((item) => PrestamoModel.fromMap('', Map<String, dynamic>.from(item)))
        .toList();

    return SemanaModel(
      id: id,
      numeroSemana: map['numeroSemana'] ?? '',
      fechaInicio: DateTime.tryParse(map['fechaInicio'] ?? '') ?? DateTime.now(),
      fechaFin: DateTime.tryParse(map['fechaFin'] ?? '') ?? DateTime.now(),
      cerrada: map['cerrada'] ?? false,
      registros: registrosList,
      prestamos: prestamosList,
    );
  }

  SemanaModel copyWith({
    String? id,
    String? numeroSemana,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool? cerrada,
    List<RegistroNominaItem>? registros,
    List<PrestamoModel>? prestamos,
  }) {
    return SemanaModel(
      id: id ?? this.id,
      numeroSemana: numeroSemana ?? this.numeroSemana,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      cerrada: cerrada ?? this.cerrada,
      registros: registros ?? this.registros,
      prestamos: prestamos ?? this.prestamos,
    );
  }
}