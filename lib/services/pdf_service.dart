import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/gasto_model.dart';
import '../models/ingreso_model.dart';
import '../models/semana_model.dart';
import '../models/trabajador_model.dart';
import '../models/vivienda_model.dart';
import '../models/configuracion_model.dart';
import '../utils/download_helper.dart';

class PdfService {
  static final NumberFormat _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  static final DateFormat _formatoFecha = DateFormat('dd/MM/yyyy');
  static final DateFormat _formatoFechaHora = DateFormat('dd/MM/yyyy HH:mm');

  // =========================================================================
  // 1. COMPROBANTE DE PAGO PARA AYUDANTE DE OBRA
  // =========================================================================
  static Future<void> generarYCompartirComprobanteAyudante({
    required TrabajadorModel trabajador,
    required RegistroNominaItem registro,
    required String nombreSemana,
    String? periodoSemana,
    List<PrestamoModel> vales = const [],
    ConfiguracionModel? configuracion,
  }) async {
    final logoImage = await _cargarLogoEmpresa(configuracion?.logoUrl);
    final String nombreEmpresa = (configuracion?.nombreEmpresa.trim().isNotEmpty ?? false)
        ? configuracion!.nombreEmpresa.trim()
        : 'ObraControl';
    final pdf = pw.Document();

    final diasTrabajados = registro.diasOcasas;
    final diasStr = diasTrabajados % 1 == 0
        ? '${diasTrabajados.toInt()}'
        : diasTrabajados.toStringAsFixed(1);
    final tarifaDiaria = registro.tarifaUnitaria;
    final totalBase = diasTrabajados * tarifaDiaria;
    final bonificaciones = registro.bonificaciones;
    final totalDevengado = registro.totalGenerado;
    final totalVales = registro.totalAdelantos;
    final totalPagado = registro.totalPagado;
    final netoAPagar = registro.saldoPendiente;

    final listaVales = vales.isNotEmpty ? vales : registro.prestamos;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // CABECERA EMPRESARIAL
            _construirEncabezado(
              titulo: 'COMPROBANTE DE PAGO SEMANAL - AYUDANTE DE OBRA',
              colorPrincipal: PdfColors.teal800,
              logo: logoImage,
              nombreEmpresa: nombreEmpresa,
            ),
            pw.SizedBox(height: 14),

            // FICHA DE DATOS DEL TRABAJADOR Y PERÍODO
            _construirFichaInformativa(
              nombre: trabajador.nombre,
              cedula: trabajador.cedula,
              telefono: trabajador.telefono,
              rol: 'Ayudante de Obra',
              nombreSemana: nombreSemana,
              periodoSemana: periodoSemana,
              colorBorde: PdfColors.teal700,
            ),
            pw.SizedBox(height: 18),

            // TABLA 1: DEVENGADOS (DÍAS TRABAJADOS)
            _construirTituloSeccion(
              '1. LIQUIDACIÓN DE DEVENGADOS (ASISTENCIA E INCENTIVOS)',
              PdfColors.teal800,
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                  children: [
                    _celdaHeader('Concepto', align: pw.TextAlign.left),
                    _celdaHeader('Días Asistidos', align: pw.TextAlign.center),
                    _celdaHeader('Tarifa Diaria', align: pw.TextAlign.right),
                    _celdaHeader('Total', align: pw.TextAlign.right),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _celda('Jornales de Obra - Asistencia Registrada'),
                    _celda(
                      '$diasStr día(s)',
                      align: pw.TextAlign.center,
                      bold: true,
                    ),
                    _celda(
                      _cop.format(tarifaDiaria),
                      align: pw.TextAlign.right,
                    ),
                    _celda(
                      _cop.format(totalBase),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                ),
                if (registro.bonos.isNotEmpty)
                  ...registro.bonos.map(
                    (b) => pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.amber50,
                      ),
                      children: [
                        _celda(
                          'Incentivo: ${b.concepto} (${_formatoFecha.format(b.fechaRegistro)})',
                          bold: true,
                        ),
                        _celda('-', align: pw.TextAlign.center),
                        _celda('-', align: pw.TextAlign.right),
                        _celda(
                          _cop.format(b.monto),
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    ),
                  )
                else if (bonificaciones > 0)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.amber50,
                    ),
                    children: [
                      _celda('Incentivo / Bonificación Especial', bold: true),
                      _celda('-', align: pw.TextAlign.center),
                      _celda('-', align: pw.TextAlign.right),
                      _celda(
                        _cop.format(bonificaciones),
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                    ],
                  ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _celda('TOTAL DEVENGADO:', bold: true),
                    _celda(''),
                    _celda(''),
                    _celda(
                      _cop.format(totalDevengado),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // TABLA 2: DESCUENTOS Y VALES
            _construirTituloSeccion(
              '2. DESCUENTOS / VALES Y ADELANTOS',
              PdfColors.amber900,
            ),
            pw.SizedBox(height: 6),
            if (listaVales.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.amber50,
                    ),
                    children: [
                      _celdaHeader('#', align: pw.TextAlign.center),
                      _celdaHeader('Fecha', align: pw.TextAlign.center),
                      _celdaHeader(
                        'Concepto / Observación',
                        align: pw.TextAlign.left,
                      ),
                      _celdaHeader('Monto Vale', align: pw.TextAlign.right),
                    ],
                  ),
                  ...listaVales.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final vale = entry.value;
                    return pw.TableRow(
                      decoration: idx % 2 == 0
                          ? const pw.BoxDecoration(color: PdfColors.grey100)
                          : null,
                      children: [
                        _celda('$idx', align: pw.TextAlign.center),
                        _celda(
                          _formatoFecha.format(vale.fecha),
                          align: pw.TextAlign.center,
                        ),
                        _celda(
                          vale.concepto.isNotEmpty
                              ? vale.concepto
                              : 'Adelanto de nómina',
                        ),
                        _celda(
                          _cop.format(vale.monto),
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _celda(''),
                      _celda(''),
                      _celda(
                        'TOTAL VALES DESCONTADOS:',
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                      _celda(
                        _cop.format(totalVales),
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                    ],
                  ),
                ],
              )
            else
              _cajaMensajeVacia(
                'No se registraron vales ni adelantos descontados en este período.',
              ),
            pw.SizedBox(height: 18),

            // RESUMEN FINANCIERO
            _construirCajaResumenFinanciero(
              filas: [
                _ParResumen(
                  '(+) Jornales Laborados ($diasStr días):',
                  _cop.format(totalBase),
                ),
                if (bonificaciones > 0)
                  _ParResumen(
                    '(+) Incentivo / Bonificación Especial:',
                    _cop.format(bonificaciones),
                  ),
                _ParResumen(
                  '(-) Vales / Adelantos Descontados:',
                  _cop.format(totalVales),
                  esResta: true,
                ),
                if (totalPagado > 0)
                  _ParResumen(
                    '(-) Pagos Parciales Efectuados:',
                    _cop.format(totalPagado),
                    esResta: true,
                  ),
              ],
              etiquetaNeto: 'NETO A PAGAR (SALDO):',
              valorNeto: _cop.format(netoAPagar),
              colorNeto: PdfColors.teal900,
            ),
            pw.SizedBox(height: 36),

            // PIE DE PÁGINA CON FIRMAS
            _construirSeccionFirmas(
              tituloIzquierda: 'Firma Empleado / Ayudante',
              subtituloIzquierda: trabajador.cedula.isNotEmpty
                  ? 'C.C. ${trabajador.cedula}'
                  : trabajador.nombre,
              tituloDerecha: 'Autorizado por Administración',
              subtituloDerecha: '$nombreEmpresa - Gestión de Obra',
            ),
          ];
        },
      ),
    );

    await _guardarYCompartir(
      pdf: pdf,
      nombreArchivo: 'Comprobante_Ayudante_${trabajador.nombre}',
      mensajeTexto:
          'Hola ${trabajador.nombre}, adjunto tu comprobante de nómina correspondiente a la $nombreSemana.',
    );
  }

  /// Alias de compatibilidad directa para comprobante de ayudante
  static Future<void> generarComprobanteNominaAyudantePdf({
    required TrabajadorModel trabajador,
    required RegistroNominaItem registro,
    required String nombreSemana,
    String? periodoSemana,
    List<PrestamoModel> vales = const [],
    ConfiguracionModel? configuracion,
  }) => generarYCompartirComprobanteAyudante(
    trabajador: trabajador,
    registro: registro,
    nombreSemana: nombreSemana,
    periodoSemana: periodoSemana,
    vales: vales,
    configuracion: configuracion,
  );

  // =========================================================================
  // 2. COMPROBANTE DE LIQUIDACIÓN PARA TÉCNICO E INSTALADOR
  // =========================================================================
  static Future<void> generarYCompartirComprobanteTecnico({
    required TrabajadorModel trabajador,
    required RegistroNominaItem registro,
    required String nombreSemana,
    String? periodoSemana,
    List<ViviendaModel> viviendasCompletadas = const [],
    List<PrestamoModel> vales = const [],
    ConfiguracionModel? configuracion,
  }) async {
    final logoImage = await _cargarLogoEmpresa(configuracion?.logoUrl);
    final String nombreEmpresa = (configuracion?.nombreEmpresa.trim().isNotEmpty ?? false)
        ? configuracion!.nombreEmpresa.trim()
        : 'ObraControl';
    final pdf = pw.Document();

    final tarifaPorCasa = registro.tarifaUnitaria;
    final cantidadCasas = viviendasCompletadas.isNotEmpty
        ? viviendasCompletadas.length
        : registro.diasOcasas.toInt();
    final totalBaseCasas = cantidadCasas * tarifaPorCasa;
    final bonificaciones = registro.bonificaciones;
    final totalBruto = totalBaseCasas + bonificaciones;
    final totalVales = registro.totalAdelantos;
    final totalPagado = registro.totalPagado;
    final netoAPagar = totalBruto - (totalVales + totalPagado);

    final listaVales = vales.isNotEmpty ? vales : registro.prestamos;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // CABECERA EMPRESARIAL
            _construirEncabezado(
              titulo: 'COMPROBANTE DE LIQUIDACIÓN TÉCNICA - INSTALADOR',
              colorPrincipal: PdfColors.blue900,
              logo: logoImage,
              nombreEmpresa: nombreEmpresa,
            ),
            pw.SizedBox(height: 14),

            // FICHA DE DATOS DEL TRABAJADOR Y PERÍODO
            _construirFichaInformativa(
              nombre: trabajador.nombre,
              cedula: trabajador.cedula,
              telefono: trabajador.telefono,
              rol: trabajador.rol,
              nombreSemana: nombreSemana,
              periodoSemana: periodoSemana,
              colorBorde: PdfColors.blue800,
            ),
            pw.SizedBox(height: 18),

            // TABLA 1: DETALLE DE CASAS COMPLETADAS
            _construirTituloSeccion(
              '1. DETALLE DE CASAS TERMINADAS Y LIQUIDADAS',
              PdfColors.blue900,
            ),
            pw.SizedBox(height: 6),
            if (viviendasCompletadas.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _celdaHeader('#', align: pw.TextAlign.center),
                      _celdaHeader('Código Casa', align: pw.TextAlign.left),
                      _celdaHeader(
                        'Lote / Ubicación',
                        align: pw.TextAlign.left,
                      ),
                      _celdaHeader(
                        'Fecha Terminación',
                        align: pw.TextAlign.center,
                      ),
                      _celdaHeader('Tarifa Unit.', align: pw.TextAlign.right),
                      _celdaHeader('Subtotal', align: pw.TextAlign.right),
                    ],
                  ),
                  ...viviendasCompletadas.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final casa = entry.value;
                    final fechaT =
                        casa.fechaTerminacion ??
                        casa.fechaInstalacion ??
                        casa.fechaRegistro;
                    return pw.TableRow(
                      decoration: idx % 2 == 0
                          ? const pw.BoxDecoration(color: PdfColors.grey100)
                          : null,
                      children: [
                        _celda('$idx', align: pw.TextAlign.center),
                        _celda(casa.codigoVisual, bold: true),
                        _celda(
                          casa.loteNombre.isNotEmpty
                              ? casa.loteNombre
                              : (casa.direccion.isNotEmpty
                                    ? casa.direccion
                                    : 'Principal'),
                        ),
                        _celda(
                          _formatoFecha.format(fechaT),
                          align: pw.TextAlign.center,
                        ),
                        _celda(
                          _cop.format(tarifaPorCasa),
                          align: pw.TextAlign.right,
                        ),
                        _celda(
                          _cop.format(tarifaPorCasa),
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                  if (registro.bonos.isNotEmpty)
                    ...registro.bonos.map(
                      (b) => pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.amber50,
                        ),
                        children: [
                          _celda(''),
                          _celda(
                            'Incentivo: ${b.concepto} (${_formatoFecha.format(b.fechaRegistro)})',
                            bold: true,
                          ),
                          _celda(''),
                          _celda(''),
                          _celda(
                            'Bono:',
                            align: pw.TextAlign.right,
                            bold: true,
                          ),
                          _celda(
                            _cop.format(b.monto),
                            align: pw.TextAlign.right,
                            bold: true,
                          ),
                        ],
                      ),
                    )
                  else if (bonificaciones > 0)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.amber50,
                      ),
                      children: [
                        _celda(''),
                        _celda('Incentivo / Bonificación Especial', bold: true),
                        _celda(''),
                        _celda(''),
                        _celda('Bono:', align: pw.TextAlign.right, bold: true),
                        _celda(
                          _cop.format(bonificaciones),
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue100,
                    ),
                    children: [
                      _celda(''),
                      _celda('TOTAL CASAS: $cantidadCasas', bold: true),
                      _celda(''),
                      _celda(''),
                      _celda(
                        'TOTAL DEVENGADO:',
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                      _celda(
                        _cop.format(totalBruto),
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                    ],
                  ),
                ],
              )
            else
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue200),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Casas Terminadas Liquidadas: $cantidadCasas casa(s)',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          'Subtotal: ${_cop.format(totalBaseCasas)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                    if (bonificaciones > 0) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Incentivo / Bonificación Especial:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: PdfColors.amber900,
                            ),
                          ),
                          pw.Text(
                            _cop.format(bonificaciones),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: PdfColors.amber900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            pw.SizedBox(height: 18),

            // TABLA 2: DESCUENTOS Y VALES
            _construirTituloSeccion(
              '2. DESCUENTOS / VALES Y ADELANTOS',
              PdfColors.amber900,
            ),
            pw.SizedBox(height: 6),
            if (listaVales.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.amber50,
                    ),
                    children: [
                      _celdaHeader('#', align: pw.TextAlign.center),
                      _celdaHeader('Fecha', align: pw.TextAlign.center),
                      _celdaHeader(
                        'Concepto / Observación',
                        align: pw.TextAlign.left,
                      ),
                      _celdaHeader('Monto Vale', align: pw.TextAlign.right),
                    ],
                  ),
                  ...listaVales.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final vale = entry.value;
                    return pw.TableRow(
                      decoration: idx % 2 == 0
                          ? const pw.BoxDecoration(color: PdfColors.grey100)
                          : null,
                      children: [
                        _celda('$idx', align: pw.TextAlign.center),
                        _celda(
                          _formatoFecha.format(vale.fecha),
                          align: pw.TextAlign.center,
                        ),
                        _celda(
                          vale.concepto.isNotEmpty
                              ? vale.concepto
                              : 'Vale / Anticipo',
                        ),
                        _celda(
                          _cop.format(vale.monto),
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _celda(''),
                      _celda(''),
                      _celda(
                        'TOTAL VALES DESCONTADOS:',
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                      _celda(
                        _cop.format(totalVales),
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                    ],
                  ),
                ],
              )
            else
              _cajaMensajeVacia(
                'No se registran vales ni adelantos descontados en este período.',
              ),
            pw.SizedBox(height: 18),

            // RESUMEN FINANCIERO
            _construirCajaResumenFinanciero(
              filas: [
                _ParResumen(
                  '(+) Total Generado en Casas ($cantidadCasas casas x ${_cop.format(tarifaPorCasa)}):',
                  _cop.format(totalBaseCasas),
                ),
                if (bonificaciones > 0)
                  _ParResumen(
                    '(+) Incentivo / Bonificación Especial:',
                    _cop.format(bonificaciones),
                  ),
                _ParResumen(
                  '(-) Vales / Adelantos Descontados:',
                  _cop.format(totalVales),
                  esResta: true,
                ),
                if (totalPagado > 0)
                  _ParResumen(
                    '(-) Pagos Efectuados:',
                    _cop.format(totalPagado),
                    esResta: true,
                  ),
              ],
              etiquetaNeto: 'NETO A PAGAR:',
              valorNeto: _cop.format(netoAPagar),
              colorNeto: PdfColors.blue900,
            ),
            pw.SizedBox(height: 36),

            // PIE DE PÁGINA CON FIRMAS
            _construirSeccionFirmas(
              tituloIzquierda: 'Firma Técnico / Recibí Conforme',
              subtituloIzquierda: trabajador.cedula.isNotEmpty
                  ? 'C.C. ${trabajador.cedula}'
                  : trabajador.nombre,
              tituloDerecha: 'Autorizado por Administración',
              subtituloDerecha: '$nombreEmpresa - Gestión de Obra',
            ),
          ];
        },
      ),
    );

    await _guardarYCompartir(
      pdf: pdf,
      nombreArchivo: 'Comprobante_Tecnico_${trabajador.nombre}',
      mensajeTexto:
          'Hola ${trabajador.nombre}, adjunto tu liquidación de casas de la $nombreSemana ($cantidadCasas casas terminadas).',
    );
  }

  /// Alias de compatibilidad directa para comprobante de técnico
  static Future<void> generarComprobanteNominaTecnicoPdf({
    required TrabajadorModel trabajador,
    required RegistroNominaItem registro,
    required String nombreSemana,
    String? periodoSemana,
    List<ViviendaModel> viviendasCompletadas = const [],
    List<PrestamoModel> vales = const [],
    ConfiguracionModel? configuracion,
  }) => generarYCompartirComprobanteTecnico(
    trabajador: trabajador,
    registro: registro,
    nombreSemana: nombreSemana,
    periodoSemana: periodoSemana,
    viviendasCompletadas: viviendasCompletadas,
    vales: vales,
    configuracion: configuracion,
  );

  // =========================================================================
  // 3. ADAPTADOR COMPATIBLE: DESPRENDIBLE INDIVIDUAL
  // =========================================================================
  static Future<void> generarYCompartirDesprendibleIndividual({
    required TrabajadorModel trabajador,
    required RegistroNominaItem registro,
    required String nombreSemana,
    String? periodoSemana,
    List<ViviendaModel> viviendasCompletadas = const [],
    List<PrestamoModel> vales = const [],
    ConfiguracionModel? configuracion,
  }) async {
    if (trabajador.esTecnico) {
      await generarYCompartirComprobanteTecnico(
        trabajador: trabajador,
        registro: registro,
        nombreSemana: nombreSemana,
        periodoSemana: periodoSemana,
        viviendasCompletadas: viviendasCompletadas,
        vales: vales,
        configuracion: configuracion,
      );
    } else {
      await generarYCompartirComprobanteAyudante(
        trabajador: trabajador,
        registro: registro,
        nombreSemana: nombreSemana,
        periodoSemana: periodoSemana,
        vales: vales,
        configuracion: configuracion,
      );
    }
  }

  // =========================================================================
  // 4. REPORTE GENERAL CONSOLIDADO DE NÓMINA (TODA LA SEMANA)
  // =========================================================================
  static Future<void> exportarReporteConsolidadoGeneral({
    required SemanaModel semana,
    required List<RegistroNominaItem> registros,
    ConfiguracionModel? configuracion,
  }) async {
    final logoImage = await _cargarLogoEmpresa(configuracion?.logoUrl);
    final pdf = pw.Document();

    final String nombreEmpresa = (configuracion?.nombreEmpresa.trim().isNotEmpty ?? false)
        ? configuracion!.nombreEmpresa.trim()
        : 'ObraControl';
    final PdfColor colorPrincipal = configuracion != null
        ? PdfColor.fromInt(configuracion.colorPrimario)
        : PdfColors.blue900;

    final ayudantes = registros.where((r) => r.esAyudante).toList();
    final tecnicos = registros.where((r) => r.esTecnico).toList();

    double totalGenerado = 0;
    double totalPagado = 0;
    double totalPendiente = 0;

    for (var r in registros) {
      totalGenerado += r.totalGenerado;
      totalPagado += (r.totalPagado + r.totalAdelantos);
      totalPendiente += r.saldoPendiente;
    }

    final periodoTexto =
        '${_formatoFecha.format(semana.fechaInicio)} - ${_formatoFecha.format(semana.fechaFin)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            _construirEncabezado(
              titulo: 'INFORME CONSOLIDADO DE NÓMINA - ${semana.numeroSemana} ($periodoTexto)',
              colorPrincipal: colorPrincipal,
              logo: logoImage,
              nombreEmpresa: nombreEmpresa,
            ),
            pw.SizedBox(height: 12),

            pw.Text(
              '1. AYUDANTES DE OBRA (DÍAS TRABAJADOS)',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal800,
              ),
            ),
            pw.SizedBox(height: 5),
            _construirTablaNomina(ayudantes, esAyudante: true),
            pw.SizedBox(height: 15),

            pw.Text(
              '2. TÉCNICOS E INSTALADORES (CASAS TERMINADAS)',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 5),
            _construirTablaNomina(tecnicos, esAyudante: false),
            pw.SizedBox(height: 18),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 270,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RESUMEN GENERAL SEMANAL',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    _filaResumenItem(
                      'Total Generado:',
                      _cop.format(totalGenerado),
                    ),
                    _filaResumenItem(
                      'Total Pagado / Vales:',
                      _cop.format(totalPagado),
                    ),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    _filaResumenItem(
                      'TOTAL SALDO PENDIENTE:',
                      _cop.format(totalPendiente),
                      destacado: true,
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Consolidado_Nomina_${semana.numeroSemana.replaceAll(' ', '_')}.pdf',
    );
  }

  // =========================================================================
  // 5. COMPROBANTE DE EGRESO / GASTO OPERACIONAL
  // =========================================================================
  static Future<Uint8List> generarComprobanteGastoPdf(
    GastoModel gasto, {
    ConfiguracionModel? configuracion,
  }) async {
    final logoImage = await _cargarLogoEmpresa(configuracion?.logoUrl);
    final pdf = pw.Document();

    final azulInstitucional = configuracion != null
        ? PdfColor.fromInt(configuracion.colorPrimario)
        : const PdfColor.fromInt(0xFF0500D0);
    final String nombreEmpresa = (configuracion?.nombreEmpresa.trim().isNotEmpty ?? false)
        ? configuracion!.nombreEmpresa.trim()
        : 'ObraControl';
    final folio = gasto.id.isNotEmpty
        ? (gasto.id.length > 8
              ? gasto.id.substring(0, 8).toUpperCase()
              : gasto.id.toUpperCase())
        : 'EG-${gasto.fecha.millisecondsSinceEpoch.toString().substring(7)}';

    final montoEnLetras = numeroALetras(gasto.monto);
    final beneficiario =
        (gasto.proveedor != null && gasto.proveedor!.trim().isNotEmpty)
        ? gasto.proveedor!.trim()
        : (gasto.responsable != null && gasto.responsable!.trim().isNotEmpty)
        ? gasto.responsable!.trim()
        : (gasto.esAutomaticoNomina
              ? 'Nómina / Mano de Obra'
              : 'Beneficiario Operativo');
    final loteDestino =
        (gasto.loteNombre != null && gasto.loteNombre!.trim().isNotEmpty)
        ? gasto.loteNombre!.trim()
        : 'Obra General';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. ENCABEZADO INSTITUCIONAL
              _construirEncabezado(
                titulo: 'COMPROBANTE DE EGRESO / GASTO OPERACIONAL',
                colorPrincipal: azulInstitucional,
                logo: logoImage,
                nombreEmpresa: nombreEmpresa,
              ),
              pw.SizedBox(height: 14),

              // 2. DATOS DE IDENTIFICACIÓN Y REGISTRO (FICHA)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  border: pw.Border.all(color: azulInstitucional, width: 1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text(
                                'Folio / Comprobante: ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              pw.Text(
                                'EG-$folio',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: azulInstitucional,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            children: [
                              pw.Text(
                                'Beneficiario / Proveedor: ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  beneficiario,
                                  style: const pw.TextStyle(fontSize: 9),
                                  overflow: pw.TextOverflow.clip,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            children: [
                              pw.Text(
                                'Destino / Lote: ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                              pw.Text(
                                loteDestino,
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Fecha: ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              pw.Text(
                                _formatoFechaHora.format(gasto.fecha),
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Categoría: ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                              pw.Text(
                                gasto.categoria,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue800,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Tipo: ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                              pw.Text(
                                gasto.esAutomaticoNomina
                                    ? 'Nómina Automática'
                                    : 'Operativo Directo',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              // 3. TABLA DE DETALLE / CONCEPTO
              _construirTituloSeccion(
                'DETALLE DEL GASTO OPERACIONAL',
                azulInstitucional,
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8EAF6),
                    ),
                    children: [
                      _celdaHeader(
                        'Concepto / Descripción',
                        align: pw.TextAlign.left,
                      ),
                      _celdaHeader('Categoría', align: pw.TextAlign.center),
                      _celdaHeader('Imputación', align: pw.TextAlign.center),
                      _celdaHeader('Total', align: pw.TextAlign.right),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _celda(
                        gasto.descripcion.isNotEmpty
                            ? gasto.descripcion
                            : 'Gasto operativo de obra',
                      ),
                      _celda(gasto.categoria, align: pw.TextAlign.center),
                      _celda(loteDestino, align: pw.TextAlign.center),
                      _celda(
                        _cop.format(gasto.monto),
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // 4. TABLA FINANCIERA Y MONTO EN LETRAS
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL PAGADO:',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: azulInstitucional,
                          ),
                        ),
                        pw.Text(
                          _cop.format(gasto.monto),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: azulInstitucional,
                          ),
                        ),
                      ],
                    ),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SON: ',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            montoEnLetras,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 28),

              // 5. ESPACIO DE FIRMAS Y LEGALIZACIÓN
              _construirSeccionFirmas(
                tituloIzquierda: 'Autorizado por (Administración)',
                subtituloIzquierda: 'Firma / C.C. Autoriza',
                tituloDerecha: 'Recibido Conforme (Proveedor / Responsable)',
                subtituloDerecha: 'Firma / C.C. o NIT Beneficiario',
              ),
              pw.Spacer(),

              // PIE DE PÁGINA INSTITUCIONAL
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '$nombreEmpresa - Gestión de Obras e Ingeniería',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Comprobante emitido automáticamente por $nombreEmpresa',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> descargarComprobanteGastoPdf(
    GastoModel gasto, {
    ConfiguracionModel? configuracion,
  }) async {
    final bytes = await generarComprobanteGastoPdf(gasto, configuracion: configuracion);
    final folio = gasto.id.isNotEmpty
        ? (gasto.id.length > 8 ? gasto.id.substring(0, 8) : gasto.id)
        : 'EG_${gasto.fecha.millisecondsSinceEpoch}';
    final nombreArchivo = 'Comprobante_Gasto_${gasto.categoria}_$folio.pdf'
        .replaceAll(' ', '_');
    await descargarArchivo(bytes, nombreArchivo);
  }

  static Future<void> previsualizarComprobanteGastoPdf(
    GastoModel gasto, {
    ConfiguracionModel? configuracion,
  }) async {
    final bytes = await generarComprobanteGastoPdf(gasto, configuracion: configuracion);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Comprobante_Gasto_${gasto.categoria}.pdf',
    );
  }

  // =========================================================================
  // 6. COMPROBANTE DE EGRESO CONSOLIDADO (MULTISELECCIÓN DE GASTOS)
  // =========================================================================
  static Future<Uint8List> generarComprobanteGastosConsolidadoPdf(
    List<GastoModel> gastos, {
    ConfiguracionModel? configuracion,
  }) async {
    final logoImage = await _cargarLogoEmpresa(configuracion?.logoUrl);
    final pdf = pw.Document();

    final azulInstitucional = configuracion != null
        ? PdfColor.fromInt(configuracion.colorPrimario)
        : const PdfColor.fromInt(0xFF0500D0);
    final String nombreEmpresa = (configuracion?.nombreEmpresa.trim().isNotEmpty ?? false)
        ? configuracion!.nombreEmpresa.trim()
        : 'ObraControl';
    final fechaEmision = DateTime.now();
    final folio = 'EGC-${DateFormat('yyyyMMdd-HHmm').format(fechaEmision)}';
    final totalGeneral = gastos.fold<double>(0.0, (acc, g) => acc + g.monto);
    final montoEnLetras = numeroALetras(totalGeneral);

    DateTime? fechaMin;
    DateTime? fechaMax;
    for (final g in gastos) {
      if (fechaMin == null || g.fecha.isBefore(fechaMin)) fechaMin = g.fecha;
      if (fechaMax == null || g.fecha.isAfter(fechaMax)) fechaMax = g.fecha;
    }
    final periodoStr = (fechaMin != null && fechaMax != null)
        ? '${_formatoFecha.format(fechaMin)} al ${_formatoFecha.format(fechaMax)}'
        : _formatoFecha.format(fechaEmision);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              _construirEncabezado(
                titulo:
                    'COMPROBANTE DE EGRESO CONSOLIDADO / RELACIÓN DE GASTOS',
                colorPrincipal: azulInstitucional,
                logo: logoImage,
                nombreEmpresa: nombreEmpresa,
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '$nombreEmpresa - Gestión de Obras e Ingeniería',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Página ${context.pageNumber} de ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Ficha informativa de la consolidación
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: azulInstitucional, width: 1),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'Folio Consolidado: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          pw.Text(
                            folio,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: azulInstitucional,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Período de Gastos: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.Text(
                            periodoStr,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'Gastos Seleccionados: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.Text(
                            '${gastos.length} ítem(s)',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Fecha de Emisión: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.Text(
                            _formatoFechaHora.format(fechaEmision),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Tabla detallada
            _construirTituloSeccion(
              'RELACIÓN DETALLADA DE GASTOS CONSOLIDADOS',
              azulInstitucional,
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FixedColumnWidth(20),
                1: pw.FixedColumnWidth(54),
                2: pw.FixedColumnWidth(64),
                3: pw.FlexColumnWidth(3.2),
                4: pw.FlexColumnWidth(2.2),
                5: pw.FixedColumnWidth(48),
                6: pw.FixedColumnWidth(68),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE8EAF6),
                  ),
                  children: [
                    _celdaHeader('#', align: pw.TextAlign.center),
                    _celdaHeader('Fecha', align: pw.TextAlign.center),
                    _celdaHeader('Categoría', align: pw.TextAlign.center),
                    _celdaHeader(
                      'Concepto / Justificación',
                      align: pw.TextAlign.left,
                    ),
                    _celdaHeader(
                      'Proveedor / Beneficiario',
                      align: pw.TextAlign.left,
                    ),
                    _celdaHeader('Lote', align: pw.TextAlign.center),
                    _celdaHeader('Valor', align: pw.TextAlign.right),
                  ],
                ),
                ...gastos.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final g = entry.value;
                  final benef =
                      (g.proveedor != null && g.proveedor!.trim().isNotEmpty)
                      ? g.proveedor!.trim()
                      : (g.responsable != null &&
                            g.responsable!.trim().isNotEmpty)
                      ? g.responsable!.trim()
                      : (g.esAutomaticoNomina ? 'Nómina' : '-');
                  final lote =
                      (g.loteNombre != null && g.loteNombre!.trim().isNotEmpty)
                      ? g.loteNombre!.trim()
                      : 'General';

                  return pw.TableRow(
                    decoration: idx % 2 == 0
                        ? const pw.BoxDecoration(color: PdfColors.grey100)
                        : null,
                    children: [
                      _celda('$idx', align: pw.TextAlign.center),
                      _celda(
                        _formatoFecha.format(g.fecha),
                        align: pw.TextAlign.center,
                      ),
                      _celda(g.categoria, align: pw.TextAlign.center),
                      _celda(
                        g.descripcion.isNotEmpty
                            ? g.descripcion
                            : 'Gasto operativo',
                      ),
                      _celda(benef),
                      _celda(lote, align: pw.TextAlign.center),
                      _celda(
                        _cop.format(g.monto),
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _celda('', align: pw.TextAlign.center),
                    _celda('', align: pw.TextAlign.center),
                    _celda('', align: pw.TextAlign.center),
                    _celda('TOTAL GENERAL ACUMULADO:', bold: true),
                    _celda(''),
                    _celda(''),
                    _celda(
                      _cop.format(totalGeneral),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Resumen financiero y valor en letras
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL CONSOLIDADO:',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: azulInstitucional,
                        ),
                      ),
                      pw.Text(
                        _cop.format(totalGeneral),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: azulInstitucional,
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SON: ',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          montoEnLetras,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 28),

            // Firmas al pie
            _construirSeccionFirmas(
              tituloIzquierda: 'Autorizado por (Administración)',
              subtituloIzquierda: 'Firma / C.C. Autoriza',
              tituloDerecha: 'Recibido / Responsable',
              subtituloDerecha: 'Firma / C.C. o NIT Beneficiario',
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> descargarComprobanteGastosConsolidadoPdf(
    List<GastoModel> gastos, {
    ConfiguracionModel? configuracion,
  }) async {
    final bytes = await generarComprobanteGastosConsolidadoPdf(
      gastos,
      configuracion: configuracion,
    );
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final nombreArchivo = 'Comprobante_Consolidado_Gastos_$timestamp.pdf';
    await descargarArchivo(bytes, nombreArchivo);
  }

  static Future<void> previsualizarComprobanteGastosConsolidadoPdf(
    List<GastoModel> gastos, {
    ConfiguracionModel? configuracion,
  }) async {
    final bytes = await generarComprobanteGastosConsolidadoPdf(
      gastos,
      configuracion: configuracion,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Comprobante_Consolidado_Gastos.pdf',
    );
  }

  // =========================================================================
  // 7. INFORME DE ESTADO DE RESULTADOS, CARTERA (CxC) Y PASIVOS (CxP)
  // =========================================================================
  static Future<Uint8List> generarEstadoResultadosPdf({
    required DateTime? fechaInicio,
    required DateTime? fechaFin,
    required String periodoTexto,
    required String? loteFiltroNombre,
    required List<IngresoModel> ingresos,
    required List<GastoModel> gastos,
    required double totalNominaPagada,
    required double totalIngresos,
    required double totalGastos,
    required double balanceNeto,
    required double margenRendimiento,
    // Nuevos parámetros contables:
    required int totalCasasProyecto,
    required double tarifaCobroPorCasa, // Por defecto 100000
    required double totalValorContratado, // totalCasas * tarifaCobroPorCasa
    required double saldoPendientePorCobrar, // Cartera clientes (CxC)
    required double saldoPendienteNomina, // Deuda con técnicos/auxiliares (CxP)
    double? subtotalAyudantes,
    double? subtotalTecnicos,
    List<Map<String, dynamic>>?
    detalleDeudaTrabajadores, // Opcional: lista de nombres y saldo pendiente
    int? casasTerminadas,
    double? valorEjecutadoObra,
    double? saldoCarteraObraExigible,
    double? saldoPrestamosTerceros,
    ConfiguracionModel? configuracion,
  }) async {
    final logoImage = await _cargarLogoEmpresa(configuracion?.logoUrl);
    final pdf = pw.Document();

    final azulInstitucional = configuracion != null
        ? PdfColor.fromInt(configuracion.colorPrimario)
        : const PdfColor.fromInt(0xFF0500D0);
    final String nombreEmpresa = (configuracion?.nombreEmpresa.trim().isNotEmpty ?? false)
        ? configuracion!.nombreEmpresa.trim()
        : 'ObraControl';
    final fechaEmision = DateTime.now();
    final folio = 'ER-${DateFormat('yyyyMMdd-HHmm').format(fechaEmision)}';
    final totalEgresos = totalGastos + totalNominaPagada;
    final balanceEnLetras = numeroALetras(balanceNeto.abs());
    final esSuperavit = balanceNeto >= 0;

    final double balanceNetoProyectado =
        balanceNeto + saldoPendientePorCobrar - saldoPendienteNomina;
    final double margenNetoProyectado = totalValorContratado > 0
        ? (balanceNetoProyectado / totalValorContratado) * 100
        : 0.0;
    final esProyectadoPositivo = balanceNetoProyectado >= 0;

    // Filtrar gastos operativos excluyendo nómina para evitar duplicidad contable
    final gastosOperativos = gastos
        .where(
          (g) =>
              g.categoria != 'Pagos a Trabajadores' &&
              !g.esAutomaticoNomina &&
              (g.abonoId == null || g.abonoId!.isEmpty),
        )
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              _construirEncabezado(
                titulo: 'INFORME FINANCIERO, ESTADO DE RESULTADOS Y CARTERA',
                colorPrincipal: azulInstitucional,
                logo: logoImage,
                nombreEmpresa: nombreEmpresa,
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '$nombreEmpresa - Gestión de Obras e Ingeniería',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Página ${context.pageNumber} de ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // FICHA DE PARÁMETROS Y ALCANCE CONTABLE
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: azulInstitucional, width: 1),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'Periodo Evaluado: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.Text(
                            periodoTexto,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: azulInstitucional,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Alcance / Obra: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.Text(
                            loteFiltroNombre ?? 'Consolidado General de Obra',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Folio Reporte: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 8.5,
                            ),
                          ),
                          pw.Text(
                            folio,
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'Moneda: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.Text(
                            'Pesos Colombianos (COP)',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Fecha Emisión: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.Text(
                            _formatoFechaHora.format(fechaEmision),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Viviendas Frente: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 8.5,
                            ),
                          ),
                          pw.Text(
                            '$totalCasasProyecto casas',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // ================================================================
            // SECCIÓN 1: ESTADO DE RESULTADOS OPERACIONAL (P&L)
            // ================================================================
            _construirTituloSeccion(
              '1. ESTADO DE RESULTADOS OPERACIONAL (EJECUCIÓN DEL PERIODO)',
              PdfColors.green900,
            ),
            pw.SizedBox(height: 5),

            // 1.1 Ingresos Operacionales
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FixedColumnWidth(55),
                1: pw.FlexColumnWidth(3.5),
                2: pw.FixedColumnWidth(75),
                3: pw.FlexColumnWidth(3.2),
                4: pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE8F5E9),
                  ),
                  children: [
                    _celdaHeader('Fecha', align: pw.TextAlign.center),
                    _celdaHeader(
                      'Concepto / Anticipo',
                      align: pw.TextAlign.left,
                    ),
                    _celdaHeader('Método', align: pw.TextAlign.center),
                    _celdaHeader('Cliente / Frente', align: pw.TextAlign.left),
                    _celdaHeader('Valor (COP)', align: pw.TextAlign.right),
                  ],
                ),
                if (ingresos.isEmpty)
                  pw.TableRow(
                    children: [
                      _celda('-', align: pw.TextAlign.center),
                      _celda('Sin registros de ingresos en este periodo'),
                      _celda('-', align: pw.TextAlign.center),
                      _celda('-', align: pw.TextAlign.center),
                      _celda(_cop.format(0), align: pw.TextAlign.right),
                    ],
                  )
                else
                  ...ingresos.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final ing = entry.value;
                    final clienteLote = [
                      if (ing.cliente != null && ing.cliente!.isNotEmpty)
                        ing.cliente!,
                      if (ing.loteNombre != null && ing.loteNombre!.isNotEmpty)
                        ing.loteNombre!,
                    ].join(' - ');

                    return pw.TableRow(
                      decoration: idx % 2 == 0
                          ? const pw.BoxDecoration(color: PdfColors.grey50)
                          : null,
                      children: [
                        _celda(
                          _formatoFecha.format(ing.fecha),
                          align: pw.TextAlign.center,
                        ),
                        _celda(ing.concepto),
                        _celda(ing.metodoPago, align: pw.TextAlign.center),
                        _celda(
                          clienteLote.isNotEmpty ? clienteLote : 'General',
                        ),
                        _celda(
                          _cop.format(ing.monto),
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFC8E6C9),
                  ),
                  children: [
                    _celda(''),
                    _celda(
                      'TOTAL INGRESOS OPERACIONALES (RECAUDO):',
                      bold: true,
                    ),
                    _celda(''),
                    _celda(''),
                    _celda(
                      _cop.format(totalIngresos),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // 1.2 Costos Directos de Nómina
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(4),
                2: pw.FixedColumnWidth(85),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFF3E0),
                  ),
                  children: [
                    _celdaHeader(
                      'Costos Directos de Mano de Obra',
                      align: pw.TextAlign.left,
                    ),
                    _celdaHeader(
                      'Descripción / Liquidación',
                      align: pw.TextAlign.left,
                    ),
                    _celdaHeader('Costo (COP)', align: pw.TextAlign.right),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _celda('Mano de Obra Operativa (Ayudantes)'),
                    _celda('Jornales, asistencias e incentivos de obra'),
                    _celda(
                      _cop.format(
                        subtotalAyudantes ??
                            (totalNominaPagada > 0
                                ? totalNominaPagada * 0.45
                                : 0),
                      ),
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                  children: [
                    _celda('Mano de Obra Técnica (Instaladores)'),
                    _celda('Liquidación de unidades certificadas terminadas'),
                    _celda(
                      _cop.format(
                        subtotalTecnicos ??
                            (totalNominaPagada > 0
                                ? totalNominaPagada * 0.55
                                : 0),
                      ),
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFE0B2),
                  ),
                  children: [
                    _celda('TOTAL COSTOS DIRECTOS DE NÓMINA:', bold: true),
                    _celda(
                      'Personal de obra (Planilla y liquidación oficial)',
                      bold: true,
                    ),
                    _celda(
                      _cop.format(totalNominaPagada),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // 1.3 Gastos Operacionales
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FixedColumnWidth(55),
                1: pw.FixedColumnWidth(70),
                2: pw.FlexColumnWidth(3.2),
                3: pw.FlexColumnWidth(2.2),
                4: pw.FixedColumnWidth(75),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFEBEE),
                  ),
                  children: [
                    _celdaHeader('Fecha', align: pw.TextAlign.center),
                    _celdaHeader('Categoría', align: pw.TextAlign.center),
                    _celdaHeader('Concepto Gasto', align: pw.TextAlign.left),
                    _celdaHeader(
                      'Proveedor / Responsable',
                      align: pw.TextAlign.left,
                    ),
                    _celdaHeader('Valor (COP)', align: pw.TextAlign.right),
                  ],
                ),
                if (gastosOperativos.isEmpty)
                  pw.TableRow(
                    children: [
                      _celda('-', align: pw.TextAlign.center),
                      _celda('-', align: pw.TextAlign.center),
                      _celda('Sin gastos operativos en este periodo'),
                      _celda('-', align: pw.TextAlign.center),
                      _celda(_cop.format(0), align: pw.TextAlign.right),
                    ],
                  )
                else
                  ...gastosOperativos.take(15).map((g) {
                    final benef =
                        (g.proveedor != null && g.proveedor!.trim().isNotEmpty)
                        ? g.proveedor!.trim()
                        : (g.responsable != null &&
                              g.responsable!.trim().isNotEmpty)
                        ? g.responsable!.trim()
                        : '-';

                    return pw.TableRow(
                      children: [
                        _celda(
                          _formatoFecha.format(g.fecha),
                          align: pw.TextAlign.center,
                        ),
                        _celda(g.categoria, align: pw.TextAlign.center),
                        _celda(
                          g.descripcion.isNotEmpty
                              ? g.descripcion
                              : 'Gasto operativo',
                        ),
                        _celda(benef),
                        _celda(
                          _cop.format(g.monto),
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFCDD2),
                  ),
                  children: [
                    _celda(''),
                    _celda(''),
                    _celda(
                      'TOTAL GASTOS OPERACIONALES Y ADMINISTRATIVOS:',
                      bold: true,
                    ),
                    _celda(''),
                    _celda(
                      _cop.format(totalGastos),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // 1.4 Resumen de Resultados del Ejercicio
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '(+) Total Ingresos Operacionales:',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                      pw.Text(
                        _cop.format(totalIngresos),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '(-) Costos Directos de Mano de Obra Pagada:',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Text(
                        '- ${_cop.format(totalNominaPagada)}',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '(-) Gastos Operacionales y Administrativos:',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Text(
                        '- ${_cop.format(totalGastos)}',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 0.8, color: PdfColors.grey400),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '(=) TOTAL COSTOS Y GASTOS (EGRESOS):',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900,
                        ),
                      ),
                      pw.Text(
                        _cop.format(totalEgresos),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: esSuperavit
                          ? const PdfColor.fromInt(0xFFE8F5E9)
                          : const PdfColor.fromInt(0xFFFFEBEE),
                      border: pw.Border.all(
                        color: esSuperavit
                            ? PdfColors.green800
                            : PdfColors.red800,
                        width: 1,
                      ),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          esSuperavit
                              ? 'UTILIDAD NETA EN CAJA (SUPERÁVIT):'
                              : 'DÉFICIT OPERACIONAL DEL PERIODO:',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: esSuperavit
                                ? PdfColors.green900
                                : PdfColors.red900,
                          ),
                        ),
                        pw.Text(
                          '${_cop.format(balanceNeto)} (${margenRendimiento.toStringAsFixed(1)}% margen)',
                          style: pw.TextStyle(
                            fontSize: 10.5,
                            fontWeight: pw.FontWeight.bold,
                            color: esSuperavit
                                ? PdfColors.green900
                                : PdfColors.red900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      pw.Text(
                        'SON: ',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          '${!esSuperavit ? "MENOS " : ""}$balanceEnLetras',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // ================================================================
            // SECCIÓN 2: BALANCE DE CARTERA Y CUENTAS POR COBRAR (CxC)
            // ================================================================
            _construirTituloSeccion(
              '2. BALANCE DE CARTERA Y CUENTAS POR COBRAR (CxC - CLIENTES Y TERCEROS)',
              PdfColors.teal900,
            ),
            pw.SizedBox(height: 5),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(3.5),
                1: pw.FlexColumnWidth(3.5),
                2: pw.FixedColumnWidth(95),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE0F2F1),
                  ),
                  children: [
                    _celdaHeader(
                      'Concepto de Cartera',
                      align: pw.TextAlign.left,
                    ),
                    _celdaHeader(
                      'Detalle / Base de Cálculo',
                      align: pw.TextAlign.left,
                    ),
                    _celdaHeader('Monto (COP)', align: pw.TextAlign.right),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _celda('Trabajo Ejecutado (Viviendas Terminadas)'),
                    _celda(
                      '${casasTerminadas ?? totalCasasProyecto} casas terminadas x ${_cop.format(tarifaCobroPorCasa)} / vivienda',
                    ),
                    _celda(
                      _cop.format(valorEjecutadoObra ?? totalValorContratado),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                  children: [
                    _celda('(-) Total Recaudado / Abonos de Obra'),
                    _celda(
                      'Anticipos y giros de clientes recibidos a la fecha',
                    ),
                    _celda(
                      '- ${_cop.format(totalIngresos)}',
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _celda('(=) Cartera de Obra Exigible'),
                    _celda(
                      'Saldo por cobrar sobre casas efectivamente construidas',
                    ),
                    _celda(
                      _cop.format(
                        saldoCarteraObraExigible ??
                            (saldoPendientePorCobrar -
                                (saldoPrestamosTerceros ?? 0)),
                      ),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                ),
                if (saldoPrestamosTerceros != null &&
                    saldoPrestamosTerceros > 0)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                    children: [
                      _celda('(+) Cartera Préstamos a Terceros'),
                      _celda(
                        'Préstamos otorgados a pagadores/terceros pendientes de cobro',
                      ),
                      _celda(
                        '+ ${_cop.format(saldoPrestamosTerceros)}',
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFB2DFDB),
                  ),
                  children: [
                    _celda(
                      'CARTERA TOTAL POR COBRAR (ACTIVO EXIGIBLE):',
                      bold: true,
                    ),
                    _celda(
                      'Cartera Obra Exigible + Cartera Préstamos a Terceros',
                      bold: true,
                    ),
                    _celda(
                      _cop.format(saldoPendientePorCobrar),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // ================================================================
            // SECCIÓN 3: CUENTAS POR PAGAR (CxP - PASIVOS DE MANO DE OBRA)
            // ================================================================
            _construirTituloSeccion(
              '3. CUENTAS POR PAGAR (CxP - PASIVOS CORRIENTES CON TRABAJADORES)',
              PdfColors.deepOrange900,
            ),
            pw.SizedBox(height: 5),
            if (detalleDeudaTrabajadores != null &&
                detalleDeudaTrabajadores.isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.5),
                  1: pw.FixedColumnWidth(85),
                  2: pw.FixedColumnWidth(75),
                  3: pw.FixedColumnWidth(75),
                  4: pw.FixedColumnWidth(85),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFBE9E7),
                    ),
                    children: [
                      _celdaHeader('Trabajador', align: pw.TextAlign.left),
                      _celdaHeader('Rol', align: pw.TextAlign.center),
                      _celdaHeader('Devengado', align: pw.TextAlign.right),
                      _celdaHeader('Pagado/Vales', align: pw.TextAlign.right),
                      _celdaHeader('Saldo CxP', align: pw.TextAlign.right),
                    ],
                  ),
                  ...detalleDeudaTrabajadores.map((t) {
                    final nombre = t['nombre']?.toString() ?? 'Trabajador';
                    final rol = t['rol']?.toString() ?? '-';
                    final devengado =
                        (t['totalDevengado'] as num?)?.toDouble() ?? 0.0;
                    final pagado =
                        (t['totalPagado'] as num?)?.toDouble() ?? 0.0;
                    final saldo =
                        (t['saldoPendiente'] as num?)?.toDouble() ?? 0.0;

                    return pw.TableRow(
                      children: [
                        _celda(nombre),
                        _celda(rol, align: pw.TextAlign.center),
                        _celda(
                          _cop.format(devengado),
                          align: pw.TextAlign.right,
                        ),
                        _celda(_cop.format(pagado), align: pw.TextAlign.right),
                        _celda(
                          _cop.format(saldo),
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFFCCBC),
                    ),
                    children: [
                      _celda('TOTAL PASIVOS DE NÓMINA PENDIENTES:', bold: true),
                      _celda(''),
                      _celda(''),
                      _celda(''),
                      _celda(
                        _cop.format(saldoPendienteNomina),
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                    ],
                  ),
                ],
              ),
            ] else ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Al corte no se registran saldos pendientes de pago a técnicos ni ayudantes.',
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'CxP: ${_cop.format(saldoPendienteNomina)}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.deepOrange900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 14),

            // ================================================================
            // SECCIÓN 4: RESUMEN DE POSICIÓN FINANCIERA NETA PROYECTADA
            // ================================================================
            _construirTituloSeccion(
              '4. RESUMEN DE POSICIÓN FINANCIERA NETA PROYECTADA AL CIERRE',
              azulInstitucional,
            ),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: azulInstitucional, width: 1),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '(+) Liquidez / Utilidad Real en Caja (Balance Operacional Actual):',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        _cop.format(balanceNeto),
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: balanceNeto >= 0
                              ? PdfColors.green900
                              : PdfColors.red900,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '(+) Cuentas por Cobrar a Constructora/Clientes (Activo Exigible CxC):',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        '+ ${_cop.format(saldoPendientePorCobrar)}',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '(-) Cuentas por Pagar a Personal de Obra (Pasivo Corriente CxP):',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        '- ${_cop.format(saldoPendienteNomina)}',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.deepOrange900,
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 1, color: PdfColors.grey400),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: esProyectadoPositivo
                          ? const PdfColor.fromInt(0xFFE8F5E9)
                          : const PdfColor.fromInt(0xFFFFEBEE),
                      border: pw.Border.all(
                        color: esProyectadoPositivo
                            ? PdfColors.green800
                            : PdfColors.red800,
                        width: 1.2,
                      ),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              esProyectadoPositivo
                                  ? 'RESULTADO FINANCIERO NETO PROYECTADO (UTILIDAD FINAL):'
                                  : 'RESULTADO FINANCIERO NETO PROYECTADO (DÉFICIT FINAL):',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: esProyectadoPositivo
                                    ? PdfColors.green900
                                    : PdfColors.red900,
                              ),
                            ),
                            pw.Text(
                              _cop.format(balanceNetoProyectado),
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: esProyectadoPositivo
                                    ? PdfColors.green900
                                    : PdfColors.red900,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Margen Neto Proyectado sobre Contratación:',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                color: PdfColors.grey800,
                              ),
                            ),
                            pw.Text(
                              '${margenNetoProyectado.toStringAsFixed(1)}% sobre valor contratado',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: azulInstitucional,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 28),

            // FIRMAS Y LEGALIZACIÓN
            _construirSeccionFirmas(
              tituloIzquierda: 'Elaborado por: Administración',
              subtituloIzquierda: 'Firma / Contabilidad',
              tituloDerecha: 'Aprobado por: Gerencia General',
              subtituloDerecha: 'Firma / Representante Legal',
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> descargarEstadoResultadosPdf({
    required DateTime? fechaInicio,
    required DateTime? fechaFin,
    required String periodoTexto,
    required String? loteFiltroNombre,
    required List<IngresoModel> ingresos,
    required List<GastoModel> gastos,
    required double totalNominaPagada,
    required double totalIngresos,
    required double totalGastos,
    required double balanceNeto,
    required double margenRendimiento,
    // Parámetros contables de cartera y pasivos:
    required int totalCasasProyecto,
    required double tarifaCobroPorCasa,
    required double totalValorContratado,
    required double saldoPendientePorCobrar,
    required double saldoPendienteNomina,
    double? subtotalAyudantes,
    double? subtotalTecnicos,
    List<Map<String, dynamic>>? detalleDeudaTrabajadores,
    int? casasTerminadas,
    double? valorEjecutadoObra,
    double? saldoCarteraObraExigible,
    double? saldoPrestamosTerceros,
    ConfiguracionModel? configuracion,
  }) async {
    final bytes = await generarEstadoResultadosPdf(
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      periodoTexto: periodoTexto,
      loteFiltroNombre: loteFiltroNombre,
      ingresos: ingresos,
      gastos: gastos,
      totalNominaPagada: totalNominaPagada,
      totalIngresos: totalIngresos,
      totalGastos: totalGastos,
      balanceNeto: balanceNeto,
      margenRendimiento: margenRendimiento,
      totalCasasProyecto: totalCasasProyecto,
      tarifaCobroPorCasa: tarifaCobroPorCasa,
      totalValorContratado: totalValorContratado,
      saldoPendientePorCobrar: saldoPendientePorCobrar,
      saldoPendienteNomina: saldoPendienteNomina,
      subtotalAyudantes: subtotalAyudantes,
      subtotalTecnicos: subtotalTecnicos,
      detalleDeudaTrabajadores: detalleDeudaTrabajadores,
      casasTerminadas: casasTerminadas,
      valorEjecutadoObra: valorEjecutadoObra,
      saldoCarteraObraExigible: saldoCarteraObraExigible,
      saldoPrestamosTerceros: saldoPrestamosTerceros,
      configuracion: configuracion,
    );
    final sanitizePeriodo = periodoTexto.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final nombreArchivo = 'Estado_Resultados_${sanitizePeriodo}_$timestamp.pdf';
    await descargarArchivo(bytes, nombreArchivo);
  }

  static Future<void> previsualizarEstadoResultadosPdf({
    required DateTime? fechaInicio,
    required DateTime? fechaFin,
    required String periodoTexto,
    required String? loteFiltroNombre,
    required List<IngresoModel> ingresos,
    required List<GastoModel> gastos,
    required double totalNominaPagada,
    required double totalIngresos,
    required double totalGastos,
    required double balanceNeto,
    required double margenRendimiento,
    // Parámetros contables de cartera y pasivos:
    required int totalCasasProyecto,
    required double tarifaCobroPorCasa,
    required double totalValorContratado,
    required double saldoPendientePorCobrar,
    required double saldoPendienteNomina,
    double? subtotalAyudantes,
    double? subtotalTecnicos,
    List<Map<String, dynamic>>? detalleDeudaTrabajadores,
    int? casasTerminadas,
    double? valorEjecutadoObra,
    double? saldoCarteraObraExigible,
    double? saldoPrestamosTerceros,
    ConfiguracionModel? configuracion,
  }) async {
    final bytes = await generarEstadoResultadosPdf(
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      periodoTexto: periodoTexto,
      loteFiltroNombre: loteFiltroNombre,
      ingresos: ingresos,
      gastos: gastos,
      totalNominaPagada: totalNominaPagada,
      totalIngresos: totalIngresos,
      totalGastos: totalGastos,
      balanceNeto: balanceNeto,
      margenRendimiento: margenRendimiento,
      totalCasasProyecto: totalCasasProyecto,
      tarifaCobroPorCasa: tarifaCobroPorCasa,
      totalValorContratado: totalValorContratado,
      saldoPendientePorCobrar: saldoPendientePorCobrar,
      saldoPendienteNomina: saldoPendienteNomina,
      subtotalAyudantes: subtotalAyudantes,
      subtotalTecnicos: subtotalTecnicos,
      detalleDeudaTrabajadores: detalleDeudaTrabajadores,
      casasTerminadas: casasTerminadas,
      valorEjecutadoObra: valorEjecutadoObra,
      saldoCarteraObraExigible: saldoCarteraObraExigible,
      saldoPrestamosTerceros: saldoPrestamosTerceros,
      configuracion: configuracion,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Estado_Resultados.pdf',
    );
  }

  static String numeroALetras(double monto) {
    final entero = monto.floor();
    if (entero <= 0) return 'CERO PESOS M/CTE';

    String seccion(int n) {
      const unidades = [
        '',
        'UN',
        'DOS',
        'TRES',
        'CUATRO',
        'CINCO',
        'SEIS',
        'SIETE',
        'OCHO',
        'NUEVE',
        'DIEZ',
        'ONCE',
        'DOCE',
        'TRECE',
        'CATORCE',
        'QUINCE',
        'DIECISÉIS',
        'DIECISIETE',
        'DIECIOCHO',
        'DIECINUEVE',
        'VEINTE',
        'VEINTIÚN',
        'VEINTIDÓS',
        'VEINTITRÉS',
        'VEINTICUATRO',
        'VEINTICINCO',
        'VEINTISÉIS',
        'VEINTISIETE',
        'VEINTIOCHO',
        'VEINTINUEVE',
      ];
      const decenas = [
        '',
        '',
        '',
        'TREINTA',
        'CUARENTA',
        'CINCUENTA',
        'SESENTA',
        'SETENTA',
        'OCHENTA',
        'NOVENTA',
      ];
      const centenas = [
        '',
        'CIENTO',
        'DOSCIENTOS',
        'TRESCIENTOS',
        'CUATROCIENTOS',
        'QUINIENTOS',
        'SEISCIENTOS',
        'SETECIENTOS',
        'OCHOCIENTOS',
        'NOVECIENTOS',
      ];

      if (n == 0) return '';
      if (n == 100) return 'CIEN';
      String res = '';
      if (n >= 100) {
        res += '${centenas[n ~/ 100]} ';
        n %= 100;
      }
      if (n < 30) {
        res += unidades[n];
      } else {
        res += decenas[n ~/ 10];
        if (n % 10 != 0) {
          res += ' Y ${unidades[n % 10]}';
        }
      }
      return res.trim();
    }

    String resultado = '';
    final millones = entero ~/ 1000000;
    final restoMillones = entero % 1000000;
    final miles = restoMillones ~/ 1000;
    final unidades = restoMillones % 1000;

    if (millones > 0) {
      if (millones == 1) {
        resultado += 'UN MILLÓN ';
      } else {
        resultado += '${seccion(millones)} MILLONES ';
      }
    }

    if (miles > 0) {
      if (miles == 1) {
        resultado += 'MIL ';
      } else {
        resultado += '${seccion(miles)} MIL ';
      }
    }

    if (unidades > 0) {
      resultado += seccion(unidades);
    }

    return '${resultado.trim()} PESOS M/CTE';
  }

  // =========================================================================
  // MOTOR DE SANEAMIENTO TIPOGRÁFICO Y COMPONENTES VISUALES
  // =========================================================================

  /// Sanitiza cualquier cadena de texto eliminando emojis, símbolos gráficos
  /// extendidos o caracteres Unicode que no existan en el juego tipográfico estándar
  /// del generador de PDF, previniendo glifos "tofu" o corruptos.
  static String sanitizarTexto(String? texto) {
    if (texto == null || texto.isEmpty) return '';

    // 1. Reemplazos directos de símbolos conocidos por alternativas formales seguras
    var limpio = texto
        .replaceAll('✅', '[OK]')
        .replaceAll('✓', '[OK]')
        .replaceAll('✔', '[OK]')
        .replaceAll('❌', '[X]')
        .replaceAll('⚠️', '[!]')
        .replaceAll('🏦', '')
        .replaceAll('💳', '')
        .replaceAll('👤', '')
        .replaceAll('🆔', '')
        .replaceAll('✉️', '')
        .replaceAll('✉', '')
        .replaceAll('📌', '')
        .replaceAll('🔹', '-')
        .replaceAll('🔸', '-')
        .replaceAll('🟢', '[OK]')
        .replaceAll('🔴', '[!]')
        .replaceAll('🟠', '[*]')
        .replaceAll('🟡', '[*]')
        .replaceAll('💰', '')
        .replaceAll('📅', '')
        .replaceAll('🧾', '')
        .replaceAll('👷', '')
        .replaceAll('🔧', '')
        .replaceAll('📋', '')
        .replaceAll('📊', '')
        .replaceAll('📈', '')
        .replaceAll('📉', '');

    // 2. Purgar cualquier emoji Unicode suplementario o símbolo gráfico extendido
    limpio = limpio.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FFFF}' // Emojis y símbolos gráficos suplementarios
        r'\u{2600}-\u{27BF}' // Símbolos misceláneos y dingbats
        r'\u{2300}-\u{23FF}' // Símbolos técnicos
        r'\u{2B50}-\u{2B55}' // Estrellas y círculos de color
        r'\u{FE00}-\u{FE0F}' // Variaciones de presentación
        r'\u{200B}-\u{200D}' // Espacios de ancho cero / joiners
        r']',
        unicode: true,
      ),
      '',
    );

    // Limpiar espacios dobles generados por remociones
    return limpio.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Descarga asíncronamente los bytes del logo corporativo desde una URL remota
  /// (Firebase Storage) para embeberlo en el documento PDF.
  /// Si [logoUrl] es nulo, vacío o si ocurre un fallo de red/CORS/timeout, retorna null
  /// de forma segura para permitir que el encabezado dibuje su fallback tipográfico y vectorial.
  static Future<pw.MemoryImage?> _cargarLogoEmpresa(String? logoUrl) async {
    if (logoUrl == null || logoUrl.trim().isEmpty) {
      return null;
    }

    try {
      final response = await http
          .get(Uri.parse(logoUrl.trim()))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('[PdfService] No se pudo cargar el logo dinámico desde URL ($logoUrl): $e');
    }

    return null;
  }

  static pw.Widget _construirEncabezado({
    required String titulo,
    required PdfColor colorPrincipal,
    pw.MemoryImage? logo,
    String nombreEmpresa = 'ObraControl',
    String? subTitulo,
  }) {
    final empresaLimpia = nombreEmpresa.trim().isNotEmpty ? nombreEmpresa.trim() : 'ObraControl';
    final String fallbackInitials = empresaLimpia.contains(' ')
        ? '${empresaLimpia.split(' ')[0][0]}${empresaLimpia.split(' ')[1][0]}'.toUpperCase()
        : (empresaLimpia.length >= 2 ? empresaLimpia.substring(0, 2).toUpperCase() : empresaLimpia.toUpperCase());

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: colorPrincipal, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.Container(
                  width: 65,
                  height: 36,
                  margin: const pw.EdgeInsets.only(right: 10),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              ] else ...[
                pw.Container(
                  width: 36,
                  height: 36,
                  margin: const pw.EdgeInsets.only(right: 10),
                  decoration: pw.BoxDecoration(
                    color: colorPrincipal,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      fallbackInitials,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    sanitizarTexto(empresaLimpia),
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: colorPrincipal,
                    ),
                  ),
                  pw.Text(
                    sanitizarTexto(subTitulo ?? 'Gestión de Obras e Ingeniería'),
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    sanitizarTexto(titulo),
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'DOCUMENTO OFICIAL',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Emisión: ${_formatoFechaHora.format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirFichaInformativa({
    required String nombre,
    required String cedula,
    required String telefono,
    required String rol,
    required String nombreSemana,
    String? periodoSemana,
    required PdfColor colorBorde,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: colorBorde, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'Trabajador: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.Text(
                    sanitizarTexto(nombre),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
              if (cedula.isNotEmpty)
                pw.Row(
                  children: [
                    pw.Text(
                      'Cédula: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                    pw.Text(
                      sanitizarTexto(cedula),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              pw.Row(
                children: [
                  pw.Text(
                    'Rol de Obra: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  pw.Text(
                    sanitizarTexto(rol),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'Semana: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.Text(
                    sanitizarTexto(nombreSemana),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (periodoSemana != null && periodoSemana.isNotEmpty)
                pw.Row(
                  children: [
                    pw.Text(
                      'Período: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                    pw.Text(
                      sanitizarTexto(periodoSemana),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              if (telefono.isNotEmpty)
                pw.Row(
                  children: [
                    pw.Text(
                      'Teléfono: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                    pw.Text(
                      sanitizarTexto(telefono),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirTituloSeccion(String titulo, PdfColor color) {
    return pw.Text(
      sanitizarTexto(titulo),
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: color,
      ),
    );
  }

  static pw.Widget _cajaMensajeVacia(String mensaje) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Text(
        sanitizarTexto(mensaje),
        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
      ),
    );
  }

  static pw.Widget _construirCajaResumenFinanciero({
    required List<_ParResumen> filas,
    required String etiquetaNeto,
    required String valorNeto,
    required PdfColor colorNeto,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          ...filas.map(
            (f) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(f.label, style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(
                    f.valor,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: f.esResta ? PdfColors.red800 : PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                sanitizarTexto(etiquetaNeto),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: colorNeto,
                ),
              ),
              pw.Text(
                valorNeto,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: colorNeto,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirSeccionFirmas({
    required String tituloIzquierda,
    required String subtituloIzquierda,
    required String tituloDerecha,
    required String subtituloDerecha,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(width: 170, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              sanitizarTexto(tituloIzquierda),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              sanitizarTexto(subtituloIzquierda),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(width: 170, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              sanitizarTexto(tituloDerecha),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              sanitizarTexto(subtituloDerecha),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _construirTablaNomina(
    List<RegistroNominaItem> lista, {
    required bool esAyudante,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _celdaHeader('Trabajador', align: pw.TextAlign.left),
            _celdaHeader(
              esAyudante ? 'Días' : 'Casas',
              align: pw.TextAlign.center,
            ),
            _celdaHeader('Generado', align: pw.TextAlign.right),
            _celdaHeader('Vales', align: pw.TextAlign.right),
            _celdaHeader('Pagado', align: pw.TextAlign.right),
            _celdaHeader('Pendiente', align: pw.TextAlign.right),
          ],
        ),
        ...lista.map((item) {
          return pw.TableRow(
            children: [
              _celda(sanitizarTexto(item.trabajadorNombre)),
              _celda(
                item.diasOcasas % 1 == 0
                    ? '${item.diasOcasas.toInt()}'
                    : item.diasOcasas.toStringAsFixed(1),
                align: pw.TextAlign.center,
              ),
              _celda(
                _cop.format(item.totalGenerado),
                align: pw.TextAlign.right,
              ),
              _celda(
                _cop.format(item.totalAdelantos),
                align: pw.TextAlign.right,
              ),
              _celda(_cop.format(item.totalPagado), align: pw.TextAlign.right),
              _celda(
                _cop.format(item.saldoPendiente),
                align: pw.TextAlign.right,
                bold: true,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _celdaHeader(
    String texto, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Text(
        sanitizarTexto(texto),
        textAlign: align,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
      ),
    );
  }

  static pw.Widget _celda(
    String texto, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        sanitizarTexto(texto),
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _filaResumenItem(
    String label,
    String valor, {
    bool destacado = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            sanitizarTexto(label),
            style: pw.TextStyle(
              fontSize: destacado ? 9.5 : 8.5,
              fontWeight: destacado ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            sanitizarTexto(valor),
            style: pw.TextStyle(
              fontSize: destacado ? 9.5 : 8.5,
              fontWeight: pw.FontWeight.bold,
              color: destacado ? PdfColors.blue900 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _guardarYCompartir({
    required pw.Document pdf,
    required String nombreArchivo,
    required String mensajeTexto,
  }) async {
    final bytes = await pdf.save();
    final sanitizedNombre = nombreArchivo.replaceAll(' ', '_');

    if (kIsWeb) {
      final xFile = XFile.fromData(
        bytes,
        name: '$sanitizedNombre.pdf',
        mimeType: 'application/pdf',
      );
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: mensajeTexto);
    } else {
      final Directory tempDir = await getTemporaryDirectory();
      final File archivo = File('${tempDir.path}/$sanitizedNombre.pdf');
      await archivo.writeAsBytes(bytes);

      final xFile = XFile(archivo.path, mimeType: 'application/pdf');
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: mensajeTexto);
    }
  }

  // =========================================================================
  // GENERACIÓN DE CUENTA DE COBRO EN PDF (SELECCIÓN MÚLTIPLE CxC)
  // =========================================================================
  static Future<Uint8List> generarCuentaCobroPdf({
    required String numeroFolio,
    required String deudorNombre,
    required String? deudorNitOCedula,
    required String? frenteObraOLote,
    required List<Map<String, dynamic>> itemsCobro,
    required double totalCobro,
    required ConfiguracionModel configuracion,
    required String fechaEmisionTexto,
  }) async {
    final logoImage = await _cargarLogoEmpresa(configuracion.logoUrl);
    final pdf = pw.Document();

    final azulInstitucional = PdfColor.fromInt(configuracion.colorPrimario);
    const azulFondoSuave = PdfColor.fromInt(0xFFF3F5FD);
    final valorEnLetras = numeroALetras(totalCobro);
    final String nombreEmpresa = configuracion.nombreEmpresa.trim().isNotEmpty
        ? configuracion.nombreEmpresa.trim()
        : 'ObraControl';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              _construirEncabezado(
                titulo: 'CUENTA DE COBRO / ESTADO DE CARTERA EXIGIBLE',
                colorPrincipal: azulInstitucional,
                logo: logoImage,
                nombreEmpresa: nombreEmpresa,
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '$nombreEmpresa - Gestión de Obras e Ingeniería',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Página ${context.pageNumber} de ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // TÍTULO FORMAL DEL DOCUMENTO
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              decoration: pw.BoxDecoration(
                color: azulFondoSuave,
                border: pw.Border.all(color: azulInstitucional, width: 1.2),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'CUENTA DE COBRO',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: azulInstitucional,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'DEBO Y PAGARÉ A LA ORDEN DE ${(configuracion.titularCuenta?.trim().isNotEmpty ?? false) ? configuracion.titularCuenta!.trim().toUpperCase() : 'OBRACONTROL INGENIERÍA'}.',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // FICHA DEL DEUDOR Y FOLIO
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColors.white,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DEUDOR / RAZÓN SOCIAL:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          deudorNombre.trim().isNotEmpty
                              ? sanitizarTexto(deudorNombre)
                              : 'Cliente / Tercero',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: azulInstitucional,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          children: [
                            pw.Text(
                              'NIT / CÉDULA: ',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              (deudorNitOCedula != null &&
                                      deudorNitOCedula.trim().isNotEmpty)
                                  ? sanitizarTexto(deudorNitOCedula)
                                  : 'No especificado',
                              style: const pw.TextStyle(fontSize: 8.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: pw.BoxDecoration(
                          color: azulInstitucional,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'FOLIO: ${sanitizarTexto(numeroFolio)}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Fecha Emisión: ',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            sanitizarTexto(fechaEmisionTexto),
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Frente / Obra: ',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            (frenteObraOLote != null &&
                                    frenteObraOLote.trim().isNotEmpty)
                                ? sanitizarTexto(frenteObraOLote)
                                : 'Proyecto General',
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // TABLA DETALLADA DE COBROS
            _construirTituloSeccion(
              'DETALLE DE CONCEPTOS EXIGIBLES Y LIQUIDACIÓN',
              azulInstitucional,
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
              columnWidths: {
                0: const pw.FixedColumnWidth(26),
                1: const pw.FlexColumnWidth(5),
                2: const pw.FixedColumnWidth(45),
                3: const pw.FixedColumnWidth(80),
                4: const pw.FixedColumnWidth(90),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: azulFondoSuave),
                  children: [
                    _celdaHeader('#', align: pw.TextAlign.center),
                    _celdaHeader(
                      'Descripción / Concepto',
                      align: pw.TextAlign.left,
                    ),
                    _celdaHeader('Cant.', align: pw.TextAlign.center),
                    _celdaHeader('Tarifa Unit.', align: pw.TextAlign.right),
                    _celdaHeader('Total', align: pw.TextAlign.right),
                  ],
                ),
                ...itemsCobro.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  final concepto =
                      item['concepto']?.toString() ?? 'Concepto de obra';
                  final cant = item['cantidad'] ?? 1;
                  final tarifa =
                      (item['tarifa'] ?? item['valorUnitario'] as num?)
                          ?.toDouble() ??
                      0.0;
                  final subtotal =
                      (item['total'] ?? item['subtotal'] as num?)?.toDouble() ??
                      0.0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: idx.isEven ? PdfColors.grey50 : PdfColors.white,
                    ),
                    children: [
                      _celda('$idx', align: pw.TextAlign.center),
                      _celda(concepto, align: pw.TextAlign.left),
                      _celda('$cant', align: pw.TextAlign.center, bold: true),
                      _celda(_cop.format(tarifa), align: pw.TextAlign.right),
                      _celda(
                        _cop.format(subtotal),
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 8),

            // TOTALES FORMALES
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: azulFondoSuave,
                border: pw.Border.all(color: azulInstitucional, width: 1.2),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'VALOR TOTAL EXIGIBLE A PAGAR:',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: azulInstitucional,
                    ),
                  ),
                  pw.Text(
                    _cop.format(totalCobro),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: azulInstitucional,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // TOTAL EN LETRAS
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
                color: PdfColors.white,
              ),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'SON: ',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.TextSpan(
                      text: valorEnLetras,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 14),

            // BLOQUE DESTACADO DE INSTRUCCIONES DE PAGO BANCARIO
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: azulFondoSuave,
                border: pw.Border.all(color: azulInstitucional, width: 1.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 8,
                        height: 8,
                        decoration: pw.BoxDecoration(
                          color: azulInstitucional,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        'INSTRUCCIONES DE PAGO - FAVOR CONSIGNAR O TRANSFERIR A:',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: azulInstitucional,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              children: [
                                pw.Text(
                                  '- Banco: ',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  sanitizarTexto(
                                    configuracion.bancoNombre ?? 'Bancolombia',
                                  ),
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              children: [
                                pw.Text(
                                  '- Tipo de Cuenta: ',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  sanitizarTexto(
                                    configuracion.tipoCuenta ??
                                        'Cuenta de Ahorros',
                                  ),
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              children: [
                                pw.Text(
                                  ' - Número de Cuenta: ',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  sanitizarTexto(
                                    configuracion.numeroCuenta ??
                                        '000-000000-00',
                                  ),
                                  style: pw.TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: azulInstitucional,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              children: [
                                pw.Text(
                                  '- Titular: ',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  sanitizarTexto(
                                    configuracion.titularCuenta ??
                                        'ObraControl Ingeniería S.A.S.',
                                  ),
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              children: [
                                pw.Text(
                                  '- NIT / Identificación: ',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  sanitizarTexto(
                                    configuracion.nitOIdentificacion ??
                                        '900.000.000-1',
                                  ),
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              '-Enviar soporte de pago una vez realizada la transferencia.',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // BLOQUE DE FIRMAS
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 170,
                        height: 1,
                        color: azulInstitucional,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        configuracion.titularCuenta ?? 'ObraControl Ingeniería S.A.S.',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: azulInstitucional,
                        ),
                      ),
                      pw.Text(
                        'NIT: ${configuracion.nitOIdentificacion ?? '900.000.000-1'}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Firma Responsable / Cobrador',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 30),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 170,
                        height: 1,
                        color: PdfColors.grey600,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        deudorNombre.trim().isNotEmpty
                            ? sanitizarTexto(deudorNombre)
                            : 'Deudor / Pagador',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Text(
                        'NIT/CC: ${sanitizarTexto(deudorNitOCedula ?? 'Pendiente')}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Aceptado y Recibido Conforme',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> descargarCuentaCobroPdf({
    required String numeroFolio,
    required String deudorNombre,
    required String? deudorNitOCedula,
    required String? frenteObraOLote,
    required List<Map<String, dynamic>> itemsCobro,
    required double totalCobro,
    required ConfiguracionModel configuracion,
    required String fechaEmisionTexto,
  }) async {
    final bytes = await generarCuentaCobroPdf(
      numeroFolio: numeroFolio,
      deudorNombre: deudorNombre,
      deudorNitOCedula: deudorNitOCedula,
      frenteObraOLote: frenteObraOLote,
      itemsCobro: itemsCobro,
      totalCobro: totalCobro,
      configuracion: configuracion,
      fechaEmisionTexto: fechaEmisionTexto,
    );
    final safeFolio = numeroFolio.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final nombreArchivo = 'Cuenta_Cobro_$safeFolio.pdf';
    await descargarArchivo(bytes, nombreArchivo);
  }

  static Future<void> previsualizarCuentaCobroPdf({
    required String numeroFolio,
    required String deudorNombre,
    required String? deudorNitOCedula,
    required String? frenteObraOLote,
    required List<Map<String, dynamic>> itemsCobro,
    required double totalCobro,
    required ConfiguracionModel configuracion,
    required String fechaEmisionTexto,
  }) async {
    final bytes = await generarCuentaCobroPdf(
      numeroFolio: numeroFolio,
      deudorNombre: deudorNombre,
      deudorNitOCedula: deudorNitOCedula,
      frenteObraOLote: frenteObraOLote,
      itemsCobro: itemsCobro,
      totalCobro: totalCobro,
      configuracion: configuracion,
      fechaEmisionTexto: fechaEmisionTexto,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Cuenta_Cobro_$numeroFolio',
    );
  }
}

class _ParResumen {
  final String label;
  final String valor;
  final bool esResta;

  _ParResumen(String label, this.valor, {this.esResta = false})
    : label = PdfService.sanitizarTexto(label);
}
