class ConfiguracionModel {
  final double tarifaCliente;
  final double tarifaTecnico;
  final double tarifaAyudante;
  final double porcentajeAhorro;
  final String pinSeguridad;
  final String? bancoNombre;
  final String? tipoCuenta;
  final String? numeroCuenta;
  final String? titularCuenta;
  final String? nitOIdentificacion;
  final String nombreEmpresa;
  final String? logoUrl;
  final int colorPrimario;

  ConfiguracionModel({
    required this.tarifaCliente,
    required this.tarifaTecnico,
    required this.tarifaAyudante,
    required this.porcentajeAhorro,
    required this.pinSeguridad,
    this.bancoNombre = 'Bancolombia',
    this.tipoCuenta = 'Cuenta de Ahorros',
    this.numeroCuenta = '000-000000-00',
    this.titularCuenta = 'ObraControl Ingeniería S.A.S.',
    this.nitOIdentificacion = '900.000.000-1',
    this.nombreEmpresa = 'ObraControl',
    this.logoUrl,
    this.colorPrimario = 0xFF0500D0,
  });

  ConfiguracionModel copyWith({
    double? tarifaCliente,
    double? tarifaTecnico,
    double? tarifaAyudante,
    double? porcentajeAhorro,
    String? pinSeguridad,
    String? bancoNombre,
    String? tipoCuenta,
    String? numeroCuenta,
    String? titularCuenta,
    String? nitOIdentificacion,
    String? nombreEmpresa,
    String? logoUrl,
    int? colorPrimario,
  }) {
    return ConfiguracionModel(
      tarifaCliente: tarifaCliente ?? this.tarifaCliente,
      tarifaTecnico: tarifaTecnico ?? this.tarifaTecnico,
      tarifaAyudante: tarifaAyudante ?? this.tarifaAyudante,
      porcentajeAhorro: porcentajeAhorro ?? this.porcentajeAhorro,
      pinSeguridad: pinSeguridad ?? this.pinSeguridad,
      bancoNombre: bancoNombre ?? this.bancoNombre,
      tipoCuenta: tipoCuenta ?? this.tipoCuenta,
      numeroCuenta: numeroCuenta ?? this.numeroCuenta,
      titularCuenta: titularCuenta ?? this.titularCuenta,
      nitOIdentificacion: nitOIdentificacion ?? this.nitOIdentificacion,
      nombreEmpresa: nombreEmpresa ?? this.nombreEmpresa,
      logoUrl: logoUrl ?? this.logoUrl,
      colorPrimario: colorPrimario ?? this.colorPrimario,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tarifaCliente': tarifaCliente,
      'tarifaTecnico': tarifaTecnico,
      'tarifaAyudante': tarifaAyudante,
      'porcentajeAhorro': porcentajeAhorro,
      'pinSeguridad': pinSeguridad,
      'bancoNombre': bancoNombre,
      'tipoCuenta': tipoCuenta,
      'numeroCuenta': numeroCuenta,
      'titularCuenta': titularCuenta,
      'nitOIdentificacion': nitOIdentificacion,
      'nombreEmpresa': nombreEmpresa,
      'logoUrl': logoUrl,
      'colorPrimario': colorPrimario,
    };
  }

  factory ConfiguracionModel.fromMap(Map<String, dynamic> map) {
    return ConfiguracionModel(
      tarifaCliente: (map['tarifaCliente'] as num?)?.toDouble() ?? 120000.0,
      tarifaTecnico: (map['tarifaTecnico'] as num?)?.toDouble() ?? 50000.0,
      tarifaAyudante: (map['tarifaAyudante'] as num?)?.toDouble() ?? 50000.0,
      porcentajeAhorro: (map['porcentajeAhorro'] as num?)?.toDouble() ?? 10.0,
      pinSeguridad: map['pinSeguridad'] ?? '1234',
      bancoNombre: map['bancoNombre'] as String? ?? 'Bancolombia',
      tipoCuenta: map['tipoCuenta'] as String? ?? 'Cuenta de Ahorros',
      numeroCuenta: map['numeroCuenta'] as String? ?? '000-000000-00',
      titularCuenta: map['titularCuenta'] as String? ?? 'ObraControl Ingeniería S.A.S.',
      nitOIdentificacion: map['nitOIdentificacion'] as String? ?? '900.000.000-1',
      nombreEmpresa: map['nombreEmpresa'] as String? ?? 'ObraControl',
      logoUrl: map['logoUrl'] as String?,
      colorPrimario: (map['colorPrimario'] as num?)?.toInt() ?? 0xFF0500D0,
    );
  }
}