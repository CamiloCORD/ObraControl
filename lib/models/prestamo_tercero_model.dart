class AbonoPrestamoModel {
  final String id;
  final double monto;
  final DateTime fecha;
  final String metodoPago;
  final String? observacion;

  AbonoPrestamoModel({
    required this.id,
    required this.monto,
    required this.fecha,
    this.metodoPago = 'Transferencia',
    this.observacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'metodoPago': metodoPago,
      'observacion': observacion,
    };
  }

  factory AbonoPrestamoModel.fromMap(Map<String, dynamic> map) {
    DateTime fecha = DateTime.now();
    if (map['fecha'] != null) {
      if (map['fecha'] is String) {
        fecha = DateTime.tryParse(map['fecha']) ?? DateTime.now();
      } else {
        try {
          fecha = (map['fecha'] as dynamic).toDate();
        } catch (_) {}
      }
    }

    return AbonoPrestamoModel(
      id: map['id'] ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: fecha,
      metodoPago: map['metodoPago'] ?? 'Transferencia',
      observacion: map['observacion'],
    );
  }

  AbonoPrestamoModel copyWith({
    String? id,
    double? monto,
    DateTime? fecha,
    String? metodoPago,
    String? observacion,
  }) {
    return AbonoPrestamoModel(
      id: id ?? this.id,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      metodoPago: metodoPago ?? this.metodoPago,
      observacion: observacion ?? this.observacion,
    );
  }
}

class PrestamoTerceroModel {
  final String id;
  final String destinatario;
  final String concepto;
  final double montoPrestado;
  final double totalAbonado;
  final DateTime fechaRegistro;
  final String? loteId;
  final String estado; // 'Pendiente', 'Saldado'
  final List<AbonoPrestamoModel> historialAbonos;

  PrestamoTerceroModel({
    required this.id,
    required this.destinatario,
    required this.concepto,
    required this.montoPrestado,
    this.totalAbonado = 0.0,
    required this.fechaRegistro,
    this.loteId,
    this.estado = 'Pendiente',
    this.historialAbonos = const [],
  });

  double get saldoPendiente {
    final s = montoPrestado - totalAbonado;
    return s > 0 ? s : 0.0;
  }

  bool get estaSaldado => saldoPendiente <= 0 || estado == 'Saldado';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'destinatario': destinatario,
      'concepto': concepto,
      'montoPrestado': montoPrestado,
      'totalAbonado': totalAbonado,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'loteId': loteId,
      'estado': estado,
      'historialAbonos': historialAbonos.map((a) => a.toMap()).toList(),
    };
  }

  factory PrestamoTerceroModel.fromMap(String id, Map<String, dynamic> map) {
    final rawAbonos = map['historialAbonos'] as List<dynamic>? ?? [];
    final abonos = rawAbonos
        .map((a) => AbonoPrestamoModel.fromMap(Map<String, dynamic>.from(a as Map)))
        .toList();

    DateTime fecha = DateTime.now();
    if (map['fechaRegistro'] != null) {
      if (map['fechaRegistro'] is String) {
        fecha = DateTime.tryParse(map['fechaRegistro']) ?? DateTime.now();
      } else {
        try {
          fecha = (map['fechaRegistro'] as dynamic).toDate();
        } catch (_) {}
      }
    }

    final double prestado = (map['montoPrestado'] as num?)?.toDouble() ?? 0.0;
    final double abonado = (map['totalAbonado'] as num?)?.toDouble() ??
        abonos.fold<double>(0.0, (acc, a) => acc + a.monto);

    return PrestamoTerceroModel(
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      destinatario: map['destinatario'] ?? '',
      concepto: map['concepto'] ?? '',
      montoPrestado: prestado,
      totalAbonado: abonado,
      fechaRegistro: fecha,
      loteId: map['loteId'],
      estado: map['estado'] ?? (prestado - abonado <= 0 ? 'Saldado' : 'Pendiente'),
      historialAbonos: abonos,
    );
  }

  PrestamoTerceroModel copyWith({
    String? id,
    String? destinatario,
    String? concepto,
    double? montoPrestado,
    double? totalAbonado,
    DateTime? fechaRegistro,
    String? loteId,
    String? estado,
    List<AbonoPrestamoModel>? historialAbonos,
  }) {
    return PrestamoTerceroModel(
      id: id ?? this.id,
      destinatario: destinatario ?? this.destinatario,
      concepto: concepto ?? this.concepto,
      montoPrestado: montoPrestado ?? this.montoPrestado,
      totalAbonado: totalAbonado ?? this.totalAbonado,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      loteId: loteId ?? this.loteId,
      estado: estado ?? this.estado,
      historialAbonos: historialAbonos ?? this.historialAbonos,
    );
  }
}
