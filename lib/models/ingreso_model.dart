class IngresoModel {
  final String id;
  final String concepto;
  final double monto;
  final DateTime fecha;
  final String? loteId;
  final String? loteNombre;
  final String? cliente;
  final String metodoPago; // "Transferencia", "Efectivo", "Cheque", etc.
  final String? comprobanteUrl;
  final String? observaciones;

  IngresoModel({
    required this.id,
    required this.concepto,
    required this.monto,
    required this.fecha,
    this.loteId,
    this.loteNombre,
    this.cliente,
    this.metodoPago = 'Transferencia',
    this.comprobanteUrl,
    this.observaciones,
  });

  Map<String, dynamic> toMap() {
    return {
      'concepto': concepto,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'loteId': loteId,
      'loteNombre': loteNombre,
      'cliente': cliente,
      'metodoPago': metodoPago,
      'comprobanteUrl': comprobanteUrl,
      'observaciones': observaciones,
    };
  }

  factory IngresoModel.fromMap(String id, Map<String, dynamic> map) {
    return IngresoModel(
      id: id,
      concepto: map['concepto'] ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      loteId: map['loteId'],
      loteNombre: map['loteNombre'],
      cliente: map['cliente'],
      metodoPago: map['metodoPago'] ?? 'Transferencia',
      comprobanteUrl: map['comprobanteUrl'],
      observaciones: map['observaciones'],
    );
  }

  IngresoModel copyWith({
    String? id,
    String? concepto,
    double? monto,
    DateTime? fecha,
    String? loteId,
    String? loteNombre,
    String? cliente,
    String? metodoPago,
    String? comprobanteUrl,
    String? observaciones,
  }) {
    return IngresoModel(
      id: id ?? this.id,
      concepto: concepto ?? this.concepto,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      loteId: loteId ?? this.loteId,
      loteNombre: loteNombre ?? this.loteNombre,
      cliente: cliente ?? this.cliente,
      metodoPago: metodoPago ?? this.metodoPago,
      comprobanteUrl: comprobanteUrl ?? this.comprobanteUrl,
      observaciones: observaciones ?? this.observaciones,
    );
  }
}
