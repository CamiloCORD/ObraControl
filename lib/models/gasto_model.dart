class GastoModel {
  final String id;
  final String semanaId;
  final String categoria; // Comida, Arriendo, Transporte, Materiales, Pagos a Trabajadores, Otros
  final String descripcion;
  final double monto;
  final DateTime fecha;
  final bool esAutomaticoNomina;
  final String? proveedor;
  final String? responsable;
  final String? loteNombre;
  final String? abonoId;
  final bool esCreditoPendiente;

  GastoModel({
    required this.id,
    required this.semanaId,
    required this.categoria,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    this.esAutomaticoNomina = false,
    this.proveedor,
    this.responsable,
    this.loteNombre,
    this.abonoId,
    this.esCreditoPendiente = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'semanaId': semanaId,
      'categoria': categoria,
      'descripcion': descripcion,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'esAutomaticoNomina': esAutomaticoNomina,
      if (proveedor != null) 'proveedor': proveedor,
      if (responsable != null) 'responsable': responsable,
      if (loteNombre != null) 'loteNombre': loteNombre,
      if (abonoId != null) 'abonoId': abonoId,
      if (esCreditoPendiente) 'esCreditoPendiente': true,
    };
  }

  factory GastoModel.fromMap(String id, Map<String, dynamic> map) {
    return GastoModel(
      id: id,
      semanaId: map['semanaId'] ?? '',
      categoria: map['categoria'] ?? 'Otros',
      descripcion: map['descripcion'] ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      esAutomaticoNomina: map['esAutomaticoNomina'] ?? false,
      proveedor: map['proveedor'],
      responsable: map['responsable'],
      loteNombre: map['loteNombre'],
      abonoId: map['abonoId'],
      esCreditoPendiente: map['esCreditoPendiente'] == true,
    );
  }

  GastoModel copyWith({
    String? id,
    String? semanaId,
    String? categoria,
    String? descripcion,
    double? monto,
    DateTime? fecha,
    bool? esAutomaticoNomina,
    String? proveedor,
    String? responsable,
    String? loteNombre,
    String? abonoId,
    bool? esCreditoPendiente,
  }) {
    return GastoModel(
      id: id ?? this.id,
      semanaId: semanaId ?? this.semanaId,
      categoria: categoria ?? this.categoria,
      descripcion: descripcion ?? this.descripcion,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      esAutomaticoNomina: esAutomaticoNomina ?? this.esAutomaticoNomina,
      proveedor: proveedor ?? this.proveedor,
      responsable: responsable ?? this.responsable,
      loteNombre: loteNombre ?? this.loteNombre,
      abonoId: abonoId ?? this.abonoId,
      esCreditoPendiente: esCreditoPendiente ?? this.esCreditoPendiente,
    );
  }
}