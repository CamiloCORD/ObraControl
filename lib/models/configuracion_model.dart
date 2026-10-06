class ConfiguracionModel {
  final double tarifaCliente;
  final double tarifaTecnico;
  final double tarifaAyudante;
  final double porcentajeAhorro;
  final String pinSeguridad;

  ConfiguracionModel({
    required this.tarifaCliente,
    required this.tarifaTecnico,
    required this.tarifaAyudante,
    required this.porcentajeAhorro,
    required this.pinSeguridad,
  });

  Map<String, dynamic> toMap() {
    return {
      'tarifaCliente': tarifaCliente,
      'tarifaTecnico': tarifaTecnico,
      'tarifaAyudante': tarifaAyudante,
      'porcentajeAhorro': porcentajeAhorro,
      'pinSeguridad': pinSeguridad,
    };
  }

  factory ConfiguracionModel.fromMap(Map<String, dynamic> map) {
    return ConfiguracionModel(
      tarifaCliente: (map['tarifaCliente'] as num?)?.toDouble() ?? 120000.0,
      tarifaTecnico: (map['tarifaTecnico'] as num?)?.toDouble() ?? 50000.0,
      tarifaAyudante: (map['tarifaAyudante'] as num?)?.toDouble() ?? 50000.0,
      porcentajeAhorro: (map['porcentajeAhorro'] as num?)?.toDouble() ?? 10.0,
      pinSeguridad: map['pinSeguridad'] ?? '1234',
    );
  }
}