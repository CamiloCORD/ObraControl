import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/configuracion_model.dart';
import '../models/lote_model.dart';
import '../models/semana_model.dart';
import '../models/trabajador_model.dart';
import '../models/vivienda_model.dart';
import '../utils/download_helper.dart';

class ExcelService {
  // =========================================================================
  // 1. REPORTE DE CASAS POR LOTE
  // =========================================================================
  static Future<void> exportarLoteAExcel(
    LoteModel lote,
    List<ViviendaModel> casas,
  ) async {
    final excel = Excel.createExcel();

    final rawSheetName =
        lote.nombre.trim().isEmpty ? 'Lote' : lote.nombre.trim();
    final sheetName = rawSheetName.replaceAll(RegExp(r'[:\\/?*\[\]]'), '_');
    final safeSheetName =
        sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName;

    final Sheet sheet = excel[safeSheetName];
    if (excel.sheets.containsKey('Sheet1') && safeSheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final headerStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#0500D0'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = [
      'Código Casa',
      'Estado',
      'Técnico Encargado',
      'Cédula Propietario',
      'Teléfono Propietario',
      'Dirección',
      'Fecha Instalación',
      'Observaciones',
      'Evidencias (Cant. Fotos)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // Ordenar casas por número
    final casasOrdenadas = List<ViviendaModel>.from(casas)
      ..sort((a, b) => a.numeroCasa.compareTo(b.numeroCasa));

    final dateFmt = DateFormat('dd/MM/yyyy');

    for (int i = 0; i < casasOrdenadas.length; i++) {
      final v = casasOrdenadas[i];
      final rowIndex = i + 1;

      void setCell(int col, CellValue val) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex))
            .value = val;
      }

      setCell(0, TextCellValue(v.id));
      setCell(1, TextCellValue(v.estado));
      setCell(
          2,
          TextCellValue(v.tecnicoNombre.isNotEmpty
              ? v.tecnicoNombre
              : (v.tecnicoId.isNotEmpty ? v.tecnicoId : 'Sin asignar')));
      setCell(3, TextCellValue(v.propietarioCedula));
      setCell(4, TextCellValue(v.propietarioTelefono));
      setCell(5, TextCellValue(v.direccion));
      setCell(
          6,
          TextCellValue(v.fechaInstalacion != null
              ? dateFmt.format(v.fechaInstalacion!)
              : ''));
      setCell(7, TextCellValue(v.observaciones));
      setCell(8, IntCellValue(v.fotos.length));
    }

    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Error al generar el archivo Excel');
    }

    final nombreSanitizado = lote.nombre
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final fileName =
        'Reporte_${nombreSanitizado.isEmpty ? "Lote" : nombreSanitizado}.xlsx';

    if (kIsWeb) {
      await descargarArchivo(fileBytes, fileName);
    } else {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      final xFile = XFile(
        file.path,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: 'Reporte Excel - ${lote.nombre}');
    }
  }

  // =========================================================================
  // 2. PLANILLA DE ASISTENCIA Y NÓMINA DE AYUDANTES
  // =========================================================================
  static Future<void> exportarPlanillaAsistenciaAExcel({
    required SemanaModel semana,
    required List<TrabajadorModel> ayudantes,
    required List<AsistenciaModel> asistencias,
    required ConfiguracionModel configuracion,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Asistencia_Ayudantes';
    final Sheet sheet = excel[sheetName];
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final dateFmt = DateFormat('dd/MM/yyyy');
    final chipDateFmt = DateFormat('EEE dd/MMM', 'es_CO');

    // Estilo Título Principal (Azul Corporativo #0500D0)
    final titleStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#0500D0'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Estilo Subtítulo Período
    final subTitleStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
      fontColorHex: ExcelColor.fromHexString('#0500D0'),
      backgroundColorHex: ExcelColor.fromHexString('#EAEBFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Estilo Cabeceras Tabla
    final headerStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#0500D0'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Fila 0: Título oficial ELECTRO - GAS
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0),
      customValue: TextCellValue('PLANILLA DE ASISTENCIA Y NÓMINA - ELECTRO - GAS'),
    );
    for (int c = 0; c <= 6; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = titleStyle;
    }

    // Fila 1: Subtítulo con semana y período
    final periodoTexto =
        'Semana: ${semana.numeroSemana}  •  Período: ${dateFmt.format(semana.fechaInicio)} al ${dateFmt.format(semana.fechaFin)}';
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1),
      customValue: TextCellValue(periodoTexto),
    );
    for (int c = 0; c <= 6; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1)).cellStyle = subTitleStyle;
    }

    // Fila 3: Columnas de la tabla
    final headers = [
      'Nombre del Ayudante',
      'Días Asistidos (Cantidad)',
      'Fechas Exactas de Asistencia',
      'Tarifa Diaria',
      'Total Ganado',
      'Vales Descontados',
      'Neto A Pagar',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // Estilos de celdas
    final dataStyleLeft = CellStyle(
      fontFamily: getFontFamily(FontFamily.Arial),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final dataStyleCenter = CellStyle(
      fontFamily: getFontFamily(FontFamily.Arial),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final dataStyleRight = CellStyle(
      fontFamily: getFontFamily(FontFamily.Arial),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );
    final totalStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
      backgroundColorHex: ExcelColor.fromHexString('#EAEBFF'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    int totalDiasGlobal = 0;
    double totalGanadoGlobal = 0.0;
    double totalValesGlobal = 0.0;
    double totalNetoGlobal = 0.0;

    int currentRow = 4;
    for (final ayudante in ayudantes) {
      final registro = semana.registros
          .where((r) => r.trabajadorId == ayudante.id && r.esAyudante)
          .firstOrNull;

      final asistenciasAyudante = asistencias
          .where((a) => a.ayudanteId == ayudante.id && a.asistio)
          .toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));

      final int diasAsistidos = registro?.diasOcasas ?? asistenciasAyudante.length;
      final double tarifa = registro?.tarifaUnitaria ?? configuracion.tarifaAyudante;
      final double totalGanado = diasAsistidos * tarifa;
      final double totalVales = registro?.totalAdelantos ?? 0.0;
      final double totalPagado = registro?.totalPagado ?? 0.0;
      final double netoAPagar = totalGanado - totalVales - totalPagado;

      String fechasTexto = '';
      if (asistenciasAyudante.isNotEmpty) {
        fechasTexto = asistenciasAyudante.map((a) {
          try {
            return chipDateFmt.format(a.fecha);
          } catch (_) {
            return '${a.fecha.day}/${a.fecha.month}';
          }
        }).join(', ');
      } else if (diasAsistidos > 0) {
        fechasTexto = '$diasAsistidos días (Registro manual)';
      } else {
        fechasTexto = 'Sin asistencia registrada';
      }

      totalDiasGlobal += diasAsistidos;
      totalGanadoGlobal += totalGanado;
      totalValesGlobal += totalVales;
      totalNetoGlobal += netoAPagar;

      // Col 0: Nombre
      final c0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      c0.value = TextCellValue(ayudante.nombre);
      c0.cellStyle = dataStyleLeft;

      // Col 1: Días Asistidos
      final c1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      c1.value = IntCellValue(diasAsistidos);
      c1.cellStyle = dataStyleCenter;

      // Col 2: Fechas
      final c2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow));
      c2.value = TextCellValue(fechasTexto);
      c2.cellStyle = dataStyleLeft;

      // Col 3: Tarifa
      final c3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));
      c3.value = DoubleCellValue(tarifa);
      c3.cellStyle = dataStyleRight;

      // Col 4: Total Ganado
      final c4 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow));
      c4.value = DoubleCellValue(totalGanado);
      c4.cellStyle = dataStyleRight;

      // Col 5: Vales
      final c5 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
      c5.value = DoubleCellValue(totalVales);
      c5.cellStyle = dataStyleRight;

      // Col 6: Neto A Pagar
      final c6 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow));
      c6.value = DoubleCellValue(netoAPagar);
      c6.cellStyle = dataStyleRight;

      currentRow++;
    }

    // Fila de Totales Generales
    final rowTot = currentRow;
    final t0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowTot));
    t0.value = TextCellValue('TOTALES GENERALES:');
    t0.cellStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
      backgroundColorHex: ExcelColor.fromHexString('#EAEBFF'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final t1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowTot));
    t1.value = IntCellValue(totalDiasGlobal);
    t1.cellStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
      backgroundColorHex: ExcelColor.fromHexString('#EAEBFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final t2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowTot));
    t2.value = TextCellValue('');
    t2.cellStyle = totalStyle;

    final t3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowTot));
    t3.value = TextCellValue('');
    t3.cellStyle = totalStyle;

    final t4 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowTot));
    t4.value = DoubleCellValue(totalGanadoGlobal);
    t4.cellStyle = totalStyle;

    final t5 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowTot));
    t5.value = DoubleCellValue(totalValesGlobal);
    t5.cellStyle = totalStyle;

    final t6 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowTot));
    t6.value = DoubleCellValue(totalNetoGlobal);
    t6.cellStyle = totalStyle;

    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Error al generar el archivo Excel');
    }

    final fileName =
        'Planilla_Asistencia_${semana.numeroSemana.replaceAll(' ', '_')}.xlsx';

    if (kIsWeb) {
      await descargarArchivo(fileBytes, fileName);
    } else {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      final xFile = XFile(
        file.path,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: 'Planilla de Asistencia - ELECTRO - GAS');
    }
  }
}
