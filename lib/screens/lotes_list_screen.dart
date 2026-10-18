import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/lote_model.dart';
import '../providers/proyecto_provider.dart';
import '../services/excel_service.dart';
import '../services/firestore_service.dart';
import 'lote_detail_screen.dart';

class LotesListScreen extends StatefulWidget {
  const LotesListScreen({super.key});

  @override
  State<LotesListScreen> createState() => _LotesListScreenState();
}

class _LotesListScreenState extends State<LotesListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  bool _importando = false;

  @override
  Widget build(BuildContext context) {
    final proyecto = Provider.of<ProyectoProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Lotes y Viviendas',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Importar viviendas desde Excel',
            onPressed: _importando ? null : _importarDesdeExcel,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Crear Nuevo Lote',
            onPressed: () => _mostrarDialogoCrearLote(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoCrearLote(context),
        icon: const Icon(Icons.add),
        label: const Text('Crear Lote'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<LoteModel>>(
        stream: _firestoreService.streamLotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error al cargar los lotes:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final lotes = snapshot.data ?? [];

          if (lotes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.holiday_village_outlined,
                      size: 72,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay lotes creados aún',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea tu primer lote con su prefijo y número inicial de casas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _mostrarDialogoCrearLote(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear Lote Ahora'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: lotes.length,
            itemBuilder: (context, index) {
              final lote = lotes[index];
              return _buildLoteCard(lote, proyecto);
            },
          );
        },
      ),
    );
  }

  Widget _buildLoteCard(LoteModel lote, ProyectoProvider proyecto) {
    // Calculamos casas del lote usando la lista en tiempo real de viviendas del proyecto
    final casasDelLote = proyecto.viviendas.where((v) => v.loteId == lote.id).toList();
    final terminadas = casasDelLote.where((v) => v.estaTerminada).length;
    // Si la lista de viviendas ya tiene elementos, usamos su longitud; de lo contrario lote.cantidadCasas
    final totalCasas = casasDelLote.isNotEmpty ? casasDelLote.length : lote.cantidadCasas;
    final porcentaje = totalCasas > 0 ? (terminadas / totalCasas) : 0.0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => LoteDetailScreen(lote: lote),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FILA TITULO Y PREFIJO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.holiday_village_rounded,
                            color: Color(0xFF1E3A8A),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lote.nombre,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (lote.prefijo.isNotEmpty)
                                Text(
                                  'Prefijo: ${lote.prefijo}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    onSelected: (val) {
                      if (val == 'eliminar') {
                        _confirmarEliminarLote(lote);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'eliminar',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Eliminar Lote', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // TEXTO DE AVANCE (ej. "Lote 1 - 20/50 casas terminadas")
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${lote.nombre} - $terminadas/$totalCasas casas terminadas',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  Text(
                    '${(porcentaje * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: porcentaje == 1.0 ? Colors.green.shade700 : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // BARRA DE PROGRESO
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: porcentaje,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    porcentaje == 1.0 ? Colors.green.shade600 : const Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // PIE DE TARJETA: FECHA Y FLECHA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Creado: ${_dateFormat.format(lote.fechaCreacion)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  Row(
                    children: [
                      Text(
                        'Ver casas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios, size: 11, color: Colors.blue.shade700),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // IMPORTADOR MASIVO DESDE EXCEL
  // =========================================================================
  Future<void> _importarDesdeExcel() async {
    // 1. Seleccionar archivo .xlsx usando la nueva API estática de file_picker v13
    final archivos = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (archivos.isEmpty) return;
    final archivo = archivos.first;

    // Obtener bytes en memoria (compatible con Web vía readAsBytes())
    final bytes = await archivo.readAsBytes();
    final nombreArchivo = archivo.name;

    // 2. Parsear el Excel en memoria
    ResultadoLecturaExcel lectura;
    try {
      lectura = ExcelService.leerViviendasDesdeExcel(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al leer el archivo: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (!mounted) return;

    // 3. Mostrar modal de previsualización
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _ModalPreviaImportacion(
        nombreArchivo: nombreArchivo,
        lectura: lectura,
      ),
    );

    if (confirmar != true || !mounted) return;

    // 4. Ejecutar la importación con barra de progreso
    setState(() => _importando = true);
    try {
      final proyecto = Provider.of<ProyectoProvider>(context, listen: false);
      final lotesMap = {for (final l in proyecto.lotes) l.id: l};

      final resultado = await _firestoreService.importarViviendasDesdeExcel(
        filas: lectura.filas,
        lotesExistentes: lotesMap,
      );

      if (!mounted) return;
      final insertadas = resultado['insertadas'] ?? 0;
      final omitidas = resultado['omitidas'] ?? 0;
      final lotesCreados = resultado['lotes_creados'] ?? 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Importación completada: $insertadas viviendas insertadas'
            '${omitidas > 0 ? ', $omitidas omitidas (ya existían o vacías)' : ''}'
            '${lotesCreados > 0 ? ', $lotesCreados lotes creados automáticamente' : ''}.',
          ),
          backgroundColor: const Color(0xFF0500D0),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  // =========================================================================
  // DIÁLOGO CREAR LOTE CON CASAS
  // =========================================================================
  void _mostrarDialogoCrearLote(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final prefijoCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: '50');
    bool creando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.add_home_work_outlined, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 8),
                  Text('Crear Nuevo Lote', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ingresa los datos del lote para generar automáticamente sus viviendas.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),

                      // NOMBRE DEL LOTE
                      TextFormField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Lote *',
                          hintText: 'ej. Lote 1',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingresa el nombre del lote';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // PREFIJO DE CASAS
                      TextFormField(
                        controller: prefijoCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Prefijo de Casas *',
                          hintText: 'ej. L1',
                          helperText: 'Generará: [Prefijo]-01, [Prefijo]-02...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingresa el prefijo (ej. L1)';
                          }
                          if (val.trim().contains(' ')) {
                            return 'El prefijo no debe contener espacios';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // CANTIDAD DE CASAS INICIAL
                      TextFormField(
                        controller: cantidadCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad Inicial de Casas *',
                          hintText: 'ej. 50',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingresa la cantidad inicial de casas';
                          }
                          final cant = int.tryParse(val.trim());
                          if (cant == null || cant <= 0) {
                            return 'Ingresa un número entero mayor a 0';
                          }
                          if (cant > 200) {
                            return 'El máximo recomendado por lote es 200';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: creando ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: creando
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => creando = true);

                          final nombre = nombreCtrl.text.trim();
                          final prefijo = prefijoCtrl.text.trim().toUpperCase();
                          final cantidad = int.parse(cantidadCtrl.text.trim());

                          try {
                            await _firestoreService.crearLoteConCasas(
                              nombre: nombre,
                              prefijo: prefijo,
                              cantidadCasas: cantidad,
                            );

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Lote "$nombre" creado exitosamente con $cantidad casas ($prefijo-01 al $prefijo-${cantidad.toString().padLeft(2, '0')}).',
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => creando = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al crear lote: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: creando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Crear Lote'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // ELIMINAR LOTE
  // =========================================================================
  void _confirmarEliminarLote(LoteModel lote) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Eliminar Lote'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar el lote "${lote.nombre}"?\n\n'
          'Esta acción eliminará permanentemente el lote y todas sus viviendas asociadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await _firestoreService.eliminarLote(lote.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lote "${lote.nombre}" eliminado.'),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar lote: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL DE PREVISUALIZACIÓN DE IMPORTACIÓN EXCEL
// =============================================================================
class _ModalPreviaImportacion extends StatelessWidget {
  final String nombreArchivo;
  final ResultadoLecturaExcel lectura;

  const _ModalPreviaImportacion({
    required this.nombreArchivo,
    required this.lectura,
  });

  @override
  Widget build(BuildContext context) {
    final hayAdvertencias = lectura.filasVacias > 0 ||
        lectura.codigosRepetidosInterno.isNotEmpty;
    final puedeImportar = lectura.filas.isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF0500D0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.table_view_rounded, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Text(
                  'Previsualización de Importación',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              nombreArchivo,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // RESUMEN DE FILAS
            _InfoRow(
              icono: Icons.home_work_outlined,
              color: const Color(0xFF0500D0),
              etiqueta: 'Viviendas listas para importar',
              valor: '${lectura.filas.length}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icono: Icons.format_list_numbered,
              color: Colors.blueGrey,
              etiqueta: 'Total filas detectadas en Excel',
              valor: '${lectura.totalFilasDetectadas}',
            ),
            if (lectura.filasVacias > 0) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icono: Icons.warning_amber_rounded,
                color: Colors.amber.shade700,
                etiqueta: 'Filas vacías omitidas',
                valor: '${lectura.filasVacias}',
              ),
            ],
            if (lectura.codigosRepetidosInterno.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icono: Icons.copy_all_rounded,
                color: Colors.orange.shade700,
                etiqueta: 'Códigos repetidos en el archivo',
                valor: '${lectura.codigosRepetidosInterno.length}',
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  lectura.codigosRepetidosInterno.take(5).join(', ') +
                      (lectura.codigosRepetidosInterno.length > 5
                          ? '... (+${lectura.codigosRepetidosInterno.length - 5} más)'
                          : ''),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
            if (hayAdvertencias) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade800, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los registros con advertencias serán omitidos. '
                        'Solo se insertarán las filas válidas y no duplicadas en Firestore.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!puedeImportar) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No se encontraron filas válidas para importar. '
                        'Verifica el formato del archivo.',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0500D0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.upload_rounded, size: 18),
          label: Text(
            'Importar ${lectura.filas.length} viviendas',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: puedeImportar
              ? () => Navigator.of(context).pop(true)
              : null,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String etiqueta;
  final String valor;

  const _InfoRow({
    required this.icono,
    required this.color,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            etiqueta,
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
