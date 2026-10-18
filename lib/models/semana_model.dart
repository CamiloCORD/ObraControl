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
      'id': id,
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
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      trabajadorId: map['trabajadorId'] ?? '',
      trabajadorNombre: map['trabajadorNombre'] ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      concepto: map['concepto'] ?? 'Préstamo / Vale',
      semanaId: map['semanaId'] ?? '',
    );
  }

  PrestamoModel copyWith({
    String? id,
    String? trabajadorId,
    String? trabajadorNombre,
    double? monto,
    DateTime? fecha,
    String? concepto,
    String? semanaId,
  }) {
    return PrestamoModel(
      id: id ?? this.id,
      trabajadorId: trabajadorId ?? this.trabajadorId,
      trabajadorNombre: trabajadorNombre ?? this.trabajadorNombre,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      concepto: concepto ?? this.concepto,
      semanaId: semanaId ?? this.semanaId,
    );
  }
}

class AsistenciaModel {
  final String id;
  final String ayudanteId;
  final String nombre;
  final DateTime fecha;
  final double valorJornada; // 1.0 = Día completo, 0.5 = Medio día, 0.0 = Ausente
  final String semanaId;

  AsistenciaModel({
    required this.id,
    required this.ayudanteId,
    required this.nombre,
    required this.fecha,
    double? valorJornada,
    bool? asistio,
    required this.semanaId,
  }) : valorJornada = valorJornada ?? ((asistio ?? true) ? 1.0 : 0.0);

  bool get asistio => valorJornada > 0;
  bool get esMedioDia => valorJornada == 0.5;
  bool get esDiaCompleto => valorJornada >= 1.0;

  Map<String, dynamic> toMap() {
    return {
      'ayudanteId': ayudanteId,
      'nombre': nombre,
      'fecha': fecha.toIso8601String(),
      'fechaString':
          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
      'asistio': asistio,
      'valorJornada': valorJornada,
      'semanaId': semanaId,
    };
  }

  factory AsistenciaModel.fromMap(String id, Map<String, dynamic> map) {
    double valor = 0.0;
    if (map['valorJornada'] is num) {
      valor = (map['valorJornada'] as num).toDouble();
    } else if (map['asistio'] == true) {
      valor = 1.0;
    }

    return AsistenciaModel(
      id: id,
      ayudanteId: map['ayudanteId'] ?? '',
      nombre: map['nombre'] ?? '',
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      valorJornada: valor,
      semanaId: map['semanaId'] ?? '',
    );
  }
}

class PagoItemModel {
  final String id;
  final String trabajadorId;
  final String trabajadorNombre;
  final double monto;
  final DateTime fecha;
  final String observacion;
  final String metodoPago;
  final String semanaId;

  PagoItemModel({
    required this.id,
    required this.trabajadorId,
    this.trabajadorNombre = '',
    required this.monto,
    required this.fecha,
    this.observacion = '',
    this.metodoPago = 'Efectivo',
    this.semanaId = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trabajadorId': trabajadorId,
      'trabajadorNombre': trabajadorNombre,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'observacion': observacion,
      'metodoPago': metodoPago,
      'semanaId': semanaId,
    };
  }

  factory PagoItemModel.fromMap(String id, Map<String, dynamic> map) {
    return PagoItemModel(
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      trabajadorId: map['trabajadorId'] ?? '',
      trabajadorNombre: map['trabajadorNombre'] ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      observacion: map['observacion'] ?? map['concepto'] ?? '',
      metodoPago: map['metodoPago'] ?? 'Efectivo',
      semanaId: map['semanaId'] ?? '',
    );
  }

  PagoItemModel copyWith({
    String? id,
    String? trabajadorId,
    String? trabajadorNombre,
    double? monto,
    DateTime? fecha,
    String? observacion,
    String? metodoPago,
    String? semanaId,
  }) {
    return PagoItemModel(
      id: id ?? this.id,
      trabajadorId: trabajadorId ?? this.trabajadorId,
      trabajadorNombre: trabajadorNombre ?? this.trabajadorNombre,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      observacion: observacion ?? this.observacion,
      metodoPago: metodoPago ?? this.metodoPago,
      semanaId: semanaId ?? this.semanaId,
    );
  }
}

class BonoItemModel {
  final String id;
  final String trabajadorId;
  final String trabajadorNombre;
  final double monto;
  final String concepto;
  final DateTime fechaRegistro;
  final String semanaId;

  BonoItemModel({
    required this.id,
    required this.trabajadorId,
    this.trabajadorNombre = '',
    required this.monto,
    required this.concepto,
    required this.fechaRegistro,
    this.semanaId = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trabajadorId': trabajadorId,
      'trabajadorNombre': trabajadorNombre,
      'monto': monto,
      'concepto': concepto,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'fecha': fechaRegistro.toIso8601String(),
      'semanaId': semanaId,
    };
  }

  factory BonoItemModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime fecha;
    final rawFecha = map['fechaRegistro'] ?? map['fecha'];
    if (rawFecha is String) {
      fecha = DateTime.tryParse(rawFecha) ?? DateTime.now();
    } else {
      fecha = DateTime.now();
    }

    return BonoItemModel(
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      trabajadorId: map['trabajadorId'] ?? '',
      trabajadorNombre: map['trabajadorNombre'] ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      concepto: map['concepto'] ?? 'Incentivo / Bonificación Especial',
      fechaRegistro: fecha,
      semanaId: map['semanaId'] ?? '',
    );
  }

  BonoItemModel copyWith({
    String? id,
    String? trabajadorId,
    String? trabajadorNombre,
    double? monto,
    String? concepto,
    DateTime? fechaRegistro,
    String? semanaId,
  }) {
    return BonoItemModel(
      id: id ?? this.id,
      trabajadorId: trabajadorId ?? this.trabajadorId,
      trabajadorNombre: trabajadorNombre ?? this.trabajadorNombre,
      monto: monto ?? this.monto,
      concepto: concepto ?? this.concepto,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      semanaId: semanaId ?? this.semanaId,
    );
  }
}

class RegistroNominaItem {
  final String trabajadorId;
  final String trabajadorNombre;
  final String rol;
  double diasOcasas; // Días para ayudantes (admite 0.5), Viviendas terminadas para técnicos
  double tarifaUnitaria;
  double bonificaciones; // Bonos e incentivos monetarios acumulados
  double totalAdelantos; // Préstamos / Vales acumulados
  double totalPagado;
  List<PrestamoModel> prestamos;
  List<PagoItemModel> pagos;
  List<BonoItemModel> bonos;

  RegistroNominaItem({
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.rol,
    this.diasOcasas = 0.0,
    required this.tarifaUnitaria,
    this.bonificaciones = 0.0,
    this.totalAdelantos = 0.0,
    this.totalPagado = 0.0,
    this.prestamos = const [],
    this.pagos = const [],
    this.bonos = const [],
  });

  double get totalBase => diasOcasas * tarifaUnitaria;
  double get totalGenerado => (diasOcasas * tarifaUnitaria) + bonificaciones;
  double get subtotal => totalGenerado;
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
      'bonificaciones': bonificaciones,
      'totalAdelantos': totalAdelantos,
      'totalPagado': totalPagado,
      'prestamos': prestamos.map((p) => p.toMap()).toList(),
      'pagos': pagos.map((p) => p.toMap()).toList(),
      'bonos': bonos.map((b) => b.toMap()).toList(),
    };
  }

  factory RegistroNominaItem.fromMap(Map<String, dynamic> map) {
    final rawPrestamos = map['prestamos'] as List<dynamic>? ?? [];
    final prestamosList = rawPrestamos
        .map((p) => PrestamoModel.fromMap('', Map<String, dynamic>.from(p)))
        .toList();

    final rawPagos = map['pagos'] as List<dynamic>? ?? [];
    final pagosList = rawPagos
        .map((p) => PagoItemModel.fromMap('', Map<String, dynamic>.from(p)))
        .toList();

    final rawBonos = map['bonos'] as List<dynamic>? ?? [];
    final bonosList = rawBonos
        .map((b) => BonoItemModel.fromMap('', Map<String, dynamic>.from(b)))
        .toList();

    final totalPagadoCalculado = pagosList.isNotEmpty
        ? pagosList.fold<double>(0.0, (acc, p) => acc + p.monto)
        : ((map['totalPagado'] as num?)?.toDouble() ?? 0.0);

    // Compatibilidad retroactiva: si hay lista de bonos, sumar sus montos; si viene número legacy, respetarlo
    final totalBonosCalculado = bonosList.isNotEmpty
        ? bonosList.fold<double>(0.0, (acc, b) => acc + b.monto)
        : ((map['bonificaciones'] as num?)?.toDouble() ?? 0.0);

    return RegistroNominaItem(
      trabajadorId: map['trabajadorId'] ?? '',
      trabajadorNombre: map['trabajadorNombre'] ?? '',
      rol: map['rol'] ?? 'Ayudante de Obra',
      diasOcasas: (map['diasOcasas'] as num?)?.toDouble() ?? 0.0,
      tarifaUnitaria: (map['tarifaUnitaria'] as num?)?.toDouble() ?? 50000.0,
      bonificaciones: totalBonosCalculado,
      totalAdelantos: (map['totalAdelantos'] as num?)?.toDouble() ?? 0.0,
      totalPagado: totalPagadoCalculado,
      prestamos: prestamosList,
      pagos: pagosList,
      bonos: bonosList,
    );
  }

  RegistroNominaItem copyWith({
    String? trabajadorId,
    String? trabajadorNombre,
    String? rol,
    double? diasOcasas,
    double? tarifaUnitaria,
    double? bonificaciones,
    double? totalAdelantos,
    double? totalPagado,
    List<PrestamoModel>? prestamos,
    List<PagoItemModel>? pagos,
    List<BonoItemModel>? bonos,
  }) {
    return RegistroNominaItem(
      trabajadorId: trabajadorId ?? this.trabajadorId,
      trabajadorNombre: trabajadorNombre ?? this.trabajadorNombre,
      rol: rol ?? this.rol,
      diasOcasas: diasOcasas ?? this.diasOcasas,
      tarifaUnitaria: tarifaUnitaria ?? this.tarifaUnitaria,
      bonificaciones: bonificaciones ?? this.bonificaciones,
      totalAdelantos: totalAdelantos ?? this.totalAdelantos,
      totalPagado: totalPagado ?? this.totalPagado,
      prestamos: prestamos ?? this.prestamos,
      pagos: pagos ?? this.pagos,
      bonos: bonos ?? this.bonos,
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
  final List<PagoItemModel> pagos;
  final List<BonoItemModel> bonos;

  SemanaModel({
    required this.id,
    required this.numeroSemana,
    required this.fechaInicio,
    required this.fechaFin,
    required this.cerrada,
    required this.registros,
    this.prestamos = const [],
    this.pagos = const [],
    this.bonos = const [],
  });

  String get nombre => numeroSemana;

  Map<String, dynamic> toMap() {
    return {
      'numeroSemana': numeroSemana,
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaFin': fechaFin.toIso8601String(),
      'cerrada': cerrada,
      'registros': registros.map((x) => x.toMap()).toList(),
      'prestamos': prestamos.map((p) => p.toMap()).toList(),
      'pagos': pagos.map((p) => p.toMap()).toList(),
      'bonos': bonos.map((b) => b.toMap()).toList(),
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

    final rawPagos = map['pagos'] as List<dynamic>? ?? [];
    final pagosList = rawPagos
        .map((item) => PagoItemModel.fromMap('', Map<String, dynamic>.from(item)))
        .toList();

    final rawBonos = map['bonos'] as List<dynamic>? ?? [];
    final bonosList = rawBonos
        .map((item) => BonoItemModel.fromMap('', Map<String, dynamic>.from(item)))
        .toList();

    // Sincronizar bonos de nivel semana en cada registro si el registro no los tenía mapeados
    if (bonosList.isNotEmpty) {
      for (var i = 0; i < registrosList.length; i++) {
        final reg = registrosList[i];
        if (reg.bonos.isEmpty) {
          final bonosTrabajador = bonosList.where((b) => b.trabajadorId == reg.trabajadorId).toList();
          if (bonosTrabajador.isNotEmpty) {
            final totalBono = bonosTrabajador.fold<double>(0.0, (acc, b) => acc + b.monto);
            registrosList[i] = reg.copyWith(
              bonos: bonosTrabajador,
              bonificaciones: totalBono,
            );
          }
        }
      }
    }

    return SemanaModel(
      id: id,
      numeroSemana: map['numeroSemana'] ?? '',
      fechaInicio: DateTime.tryParse(map['fechaInicio'] ?? '') ?? DateTime.now(),
      fechaFin: DateTime.tryParse(map['fechaFin'] ?? '') ?? DateTime.now(),
      cerrada: map['cerrada'] ?? false,
      registros: registrosList,
      prestamos: prestamosList,
      pagos: pagosList,
      bonos: bonosList,
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
    List<PagoItemModel>? pagos,
    List<BonoItemModel>? bonos,
  }) {
    return SemanaModel(
      id: id ?? this.id,
      numeroSemana: numeroSemana ?? this.numeroSemana,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      cerrada: cerrada ?? this.cerrada,
      registros: registros ?? this.registros,
      prestamos: prestamos ?? this.prestamos,
      pagos: pagos ?? this.pagos,
      bonos: bonos ?? this.bonos,
    );
  }
}