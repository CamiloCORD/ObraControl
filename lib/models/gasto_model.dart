class GastoModel {
  final String id;
  final String semanaId;
  final String categoria; // Comida, Arriendo, Transporte, Materiales, Pagos a Trabajadores, Otros
  final String descripcion;
  final double monto;
  final DateTime fecha;
  final bool esAutomaticoNomina;

  GastoModel({
    required this.id,
    required this.semanaId,
    required this.categoria,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    this.esAutomaticoNomina = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'semanaId': semanaId,
      'categoria': categoria,
      'descripcion': descripcion,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'esAutomaticoNomina': esAutomaticoNomina,
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
    );
  }
}