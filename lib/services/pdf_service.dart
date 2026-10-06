import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/semana_model.dart';
import '../models/trabajador_model.dart';
import '../models/vivienda_model.dart';

class PdfService {
  static final NumberFormat _cop =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
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
  }) async {
    final logoImage = await _cargarLogoEmpresa();
    final pdf = pw.Document();

    final diasTrabajados = registro.diasOcasas;
    final tarifaDiaria = registro.tarifaUnitaria;
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
            _construirTituloSeccion('1. LIQUIDACIÓN DE DEVENGADOS (ASISTENCIA)', PdfColors.teal800),
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
                    _celdaHeader('Total Devengado', align: pw.TextAlign.right),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _celda('Jornales de Obra - Asistencia Registrada'),
                    _celda('$diasTrabajados día(s)', align: pw.TextAlign.center, bold: true),
                    _celda(_cop.format(tarifaDiaria), align: pw.TextAlign.right),
                    _celda(_cop.format(totalDevengado), align: pw.TextAlign.right, bold: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // TABLA 2: DESCUENTOS Y VALES
            _construirTituloSeccion('2. DESCUENTOS / VALES Y ADELANTOS', PdfColors.amber900),
            pw.SizedBox(height: 6),
            if (listaVales.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.amber50),
                    children: [
                      _celdaHeader('#', align: pw.TextAlign.center),
                      _celdaHeader('Fecha', align: pw.TextAlign.center),
                      _celdaHeader('Concepto / Observación', align: pw.TextAlign.left),
                      _celdaHeader('Monto Vale', align: pw.TextAlign.right),
                    ],
                  ),
                  ...listaVales.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final vale = entry.value;
                    return pw.TableRow(
                      decoration: idx % 2 == 0 ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
                      children: [
                        _celda('$idx', align: pw.TextAlign.center),
                        _celda(_formatoFecha.format(vale.fecha), align: pw.TextAlign.center),
                        _celda(vale.concepto.isNotEmpty ? vale.concepto : 'Adelanto de nómina'),
                        _celda(_cop.format(vale.monto), align: pw.TextAlign.right, bold: true),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _celda(''),
                      _celda(''),
                      _celda('TOTAL VALES DESCONTADOS:', align: pw.TextAlign.right, bold: true),
                      _celda(_cop.format(totalVales), align: pw.TextAlign.right, bold: true),
                    ],
                  ),
                ],
              )
            else
              _cajaMensajeVacia('No se registraron vales ni adelantos descontados en este período.'),
            pw.SizedBox(height: 18),

            // RESUMEN FINANCIERO
            _construirCajaResumenFinanciero(
              filas: [
                _ParResumen('(+) Total Ganado por Días Laborados:', _cop.format(totalDevengado)),
                _ParResumen('(-) Vales / Adelantos Descontados:', _cop.format(totalVales), esResta: true),
                if (totalPagado > 0)
                  _ParResumen('(-) Pagos Parciales Efectuados:', _cop.format(totalPagado), esResta: true),
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
              subtituloDerecha: 'Control Gas App - Obra',
            ),
          ];
        },
      ),
    );

    await _guardarYCompartir(
      pdf: pdf,
      nombreArchivo: 'Comprobante_Ayudante_${trabajador.nombre}',
      mensajeTexto: 'Hola ${trabajador.nombre}, adjunto tu comprobante de nómina correspondiente a la $nombreSemana.',
    );
  }

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
  }) async {
    final logoImage = await _cargarLogoEmpresa();
    final pdf = pw.Document();

    final tarifaPorCasa = registro.tarifaUnitaria;
    final cantidadCasas = viviendasCompletadas.isNotEmpty ? viviendasCompletadas.length : registro.diasOcasas;
    final totalBruto = cantidadCasas * tarifaPorCasa;
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
            _construirTituloSeccion('1. DETALLE DE CASAS TERMINADAS Y LIQUIDADAS', PdfColors.blue900),
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
                      _celdaHeader('Lote / Ubicación', align: pw.TextAlign.left),
                      _celdaHeader('Fecha Terminación', align: pw.TextAlign.center),
                      _celdaHeader('Tarifa Unit.', align: pw.TextAlign.right),
                      _celdaHeader('Subtotal', align: pw.TextAlign.right),
                    ],
                  ),
                  ...viviendasCompletadas.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final casa = entry.value;
                    final fechaT = casa.fechaTerminacion ?? casa.fechaInstalacion ?? casa.fechaRegistro;
                    return pw.TableRow(
                      decoration: idx % 2 == 0 ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
                      children: [
                        _celda('$idx', align: pw.TextAlign.center),
                        _celda(casa.id, bold: true),
                        _celda(casa.loteNombre.isNotEmpty ? casa.loteNombre : (casa.direccion.isNotEmpty ? casa.direccion : 'Principal')),
                        _celda(_formatoFecha.format(fechaT), align: pw.TextAlign.center),
                        _celda(_cop.format(tarifaPorCasa), align: pw.TextAlign.right),
                        _celda(_cop.format(tarifaPorCasa), align: pw.TextAlign.right, bold: true),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                    children: [
                      _celda(''),
                      _celda('TOTAL CASAS: $cantidadCasas', bold: true),
                      _celda(''),
                      _celda(''),
                      _celda('TOTAL BRUTO:', align: pw.TextAlign.right, bold: true),
                      _celda(_cop.format(totalBruto), align: pw.TextAlign.right, bold: true),
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
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Casas Terminadas Liquidadas (según registro semanal): $cantidadCasas casa(s)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('Total Bruto: ${_cop.format(totalBruto)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900)),
                  ],
                ),
              ),
            pw.SizedBox(height: 18),

            // TABLA 2: DESCUENTOS Y VALES
            _construirTituloSeccion('2. DESCUENTOS / VALES Y ADELANTOS', PdfColors.amber900),
            pw.SizedBox(height: 6),
            if (listaVales.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.amber50),
                    children: [
                      _celdaHeader('#', align: pw.TextAlign.center),
                      _celdaHeader('Fecha', align: pw.TextAlign.center),
                      _celdaHeader('Concepto / Observación', align: pw.TextAlign.left),
                      _celdaHeader('Monto Vale', align: pw.TextAlign.right),
                    ],
                  ),
                  ...listaVales.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final vale = entry.value;
                    return pw.TableRow(
                      decoration: idx % 2 == 0 ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
                      children: [
                        _celda('$idx', align: pw.TextAlign.center),
                        _celda(_formatoFecha.format(vale.fecha), align: pw.TextAlign.center),
                        _celda(vale.concepto.isNotEmpty ? vale.concepto : 'Vale / Anticipo'),
                        _celda(_cop.format(vale.monto), align: pw.TextAlign.right, bold: true),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _celda(''),
                      _celda(''),
                      _celda('TOTAL VALES DESCONTADOS:', align: pw.TextAlign.right, bold: true),
                      _celda(_cop.format(totalVales), align: pw.TextAlign.right, bold: true),
                    ],
                  ),
                ],
              )
            else
              _cajaMensajeVacia('No se registran vales ni adelantos descontados en este período.'),
            pw.SizedBox(height: 18),

            // RESUMEN FINANCIERO
            _construirCajaResumenFinanciero(
              filas: [
                _ParResumen('(+) Total Generado en Casas ($cantidadCasas casas x ${_cop.format(tarifaPorCasa)}):', _cop.format(totalBruto)),
                _ParResumen('(-) Vales / Adelantos Descontados:', _cop.format(totalVales), esResta: true),
                if (totalPagado > 0)
                  _ParResumen('(-) Pagos Efectuados:', _cop.format(totalPagado), esResta: true),
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
              subtituloDerecha: 'Control Gas App - Obra',
            ),
          ];
        },
      ),
    );

    await _guardarYCompartir(
      pdf: pdf,
      nombreArchivo: 'Comprobante_Tecnico_${trabajador.nombre}',
      mensajeTexto: 'Hola ${trabajador.nombre}, adjunto tu liquidación de casas de la $nombreSemana ($cantidadCasas casas terminadas).',
    );
  }

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
  }) async {
    if (trabajador.esTecnico) {
      await generarYCompartirComprobanteTecnico(
        trabajador: trabajador,
        registro: registro,
        nombreSemana: nombreSemana,
        periodoSemana: periodoSemana,
        viviendasCompletadas: viviendasCompletadas,
        vales: vales,
      );
    } else {
      await generarYCompartirComprobanteAyudante(
        trabajador: trabajador,
        registro: registro,
        nombreSemana: nombreSemana,
        periodoSemana: periodoSemana,
        vales: vales,
      );
    }
  }

  // =========================================================================
  // 4. REPORTE GENERAL CONSOLIDADO DE NÓMINA (TODA LA SEMANA)
  // =========================================================================
  static Future<void> exportarReporteConsolidadoGeneral({
    required SemanaModel semana,
    required List<RegistroNominaItem> registros,
  }) async {
    final pdf = pw.Document();

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
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CONTROL PROYECTO GAS NATURAL',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                    pw.Text('INFORME CONSOLIDADO DE NÓMINA',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Período: ${semana.numeroSemana} ($periodoTexto)'),
                  ],
                ),
                pw.Text('Emisión: ${_formatoFecha.format(DateTime.now())}',
                    style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            pw.Text('1. AYUDANTES DE OBRA (DÍAS TRABAJADOS)',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
            pw.SizedBox(height: 5),
            _construirTablaNomina(ayudantes, esAyudante: true),
            pw.SizedBox(height: 15),

            pw.Text('2. TÉCNICOS E INSTALADORES (CASAS TERMINADAS)',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
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
                    pw.Text('RESUMEN GENERAL SEMANAL',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    _filaResumenItem('Total Generado:', _cop.format(totalGenerado)),
                    _filaResumenItem('Total Pagado / Vales:', _cop.format(totalPagado)),
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
      name: 'Consolidado_Nomina_${semana.numeroSemana.replaceAll(' ', '_')}.pdf',
    );
  }

  // =========================================================================
  // COMPONENTES Y HELPERS VISUALES
  // =========================================================================

  static Future<pw.MemoryImage?> _cargarLogoEmpresa() async {
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      try {
        final bytes = await rootBundle.load('lib/img/logo.jpeg');
        return pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }
  }

  static pw.Widget _construirEncabezado({
    required String titulo,
    required PdfColor colorPrincipal,
    pw.MemoryImage? logo,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: colorPrincipal, width: 2)),
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
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ELECTRO - GAS',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: colorPrincipal,
                    ),
                  ),
                  pw.Text(
                    'Control de Obras & Gas Natural',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    titulo,
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('DOCUMENTO OFICIAL', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                'Emisión: ${_formatoFechaHora.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
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
              pw.Row(children: [
                pw.Text('Trabajador: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text(nombre, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              ]),
              if (cedula.isNotEmpty)
                pw.Row(children: [
                  pw.Text('Cédula: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text(cedula, style: const pw.TextStyle(fontSize: 9)),
                ]),
              pw.Row(children: [
                pw.Text('Rol de Obra: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text(rol, style: const pw.TextStyle(fontSize: 9)),
              ]),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Row(children: [
                pw.Text('Semana: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text(nombreSemana, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ]),
              if (periodoSemana != null && periodoSemana.isNotEmpty)
                pw.Row(children: [
                  pw.Text('Período: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text(periodoSemana, style: const pw.TextStyle(fontSize: 9)),
                ]),
              if (telefono.isNotEmpty)
                pw.Row(children: [
                  pw.Text('Teléfono: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text(telefono, style: const pw.TextStyle(fontSize: 9)),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirTituloSeccion(String titulo, PdfColor color) {
    return pw.Text(
      titulo,
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
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
        mensaje,
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
          ...filas.map((f) => pw.Padding(
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
              )),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(etiquetaNeto,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: colorNeto)),
              pw.Text(valorNeto,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: colorNeto)),
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
            pw.Text(tituloIzquierda, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text(subtituloIzquierda, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(width: 170, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(tituloDerecha, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text(subtituloDerecha, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _construirTablaNomina(List<RegistroNominaItem> lista,
      {required bool esAyudante}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _celdaHeader('Trabajador', align: pw.TextAlign.left),
            _celdaHeader(esAyudante ? 'Días' : 'Casas', align: pw.TextAlign.center),
            _celdaHeader('Generado', align: pw.TextAlign.right),
            _celdaHeader('Vales', align: pw.TextAlign.right),
            _celdaHeader('Pagado', align: pw.TextAlign.right),
            _celdaHeader('Pendiente', align: pw.TextAlign.right),
          ],
        ),
        ...lista.map((item) {
          return pw.TableRow(
            children: [
              _celda(item.trabajadorNombre),
              _celda('${item.diasOcasas}', align: pw.TextAlign.center),
              _celda(_cop.format(item.totalGenerado), align: pw.TextAlign.right),
              _celda(_cop.format(item.totalAdelantos), align: pw.TextAlign.right),
              _celda(_cop.format(item.totalPagado), align: pw.TextAlign.right),
              _celda(_cop.format(item.saldoPendiente), align: pw.TextAlign.right, bold: true),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _celdaHeader(String texto, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Text(
        texto,
        textAlign: align,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
      ),
    );
  }

  static pw.Widget _celda(String texto,
      {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        texto,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _filaResumenItem(String label, String valor, {bool destacado = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: destacado ? 9.5 : 8.5,
                  fontWeight: destacado ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(valor,
              style: pw.TextStyle(
                  fontSize: destacado ? 9.5 : 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: destacado ? PdfColors.blue900 : PdfColors.black)),
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
}

class _ParResumen {
  final String label;
  final String valor;
  final bool esResta;

  _ParResumen(this.label, this.valor, {this.esResta = false});
}