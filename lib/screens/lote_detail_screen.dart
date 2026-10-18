import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lote_model.dart';
import '../models/vivienda_model.dart';
import '../models/trabajador_model.dart';
import '../providers/proyecto_provider.dart';
import '../services/excel_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../widgets/foto_lightbox_dialog.dart';

class LoteDetailScreen extends StatefulWidget {
  final LoteModel lote;

  const LoteDetailScreen({super.key, required this.lote});

  @override
  State<LoteDetailScreen> createState() => _LoteDetailScreenState();
}

class _LoteDetailScreenState extends State<LoteDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  String _filtroEstado = 'TODOS';
  String _busqueda = '';
  bool _exportandoExcel = false;
  bool _agregandoCasa = false;

  @override
  Widget build(BuildContext context) {
    final proyecto = Provider.of<ProyectoProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lote.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (widget.lote.prefijo.isNotEmpty)
              Text(
                'Prefijo: ${widget.lote.prefijo}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          StreamBuilder<List<ViviendaModel>>(
            stream: _firestoreService.obtenerCasasPorLote(widget.lote.id),
            builder: (context, snapshot) {
              final casas = snapshot.data ?? [];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: _exportandoExcel
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.table_chart_rounded, size: 18),
                  label: const Text(
                    'Exportar Excel',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _exportandoExcel || casas.isEmpty
                      ? null
                      : () => _exportarAExcel(casas),
                ),
              );
            },
          ),
          IconButton(
            icon: _agregandoCasa
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_circle_outline),
            tooltip: 'Agregar siguiente casa',
            onPressed: _agregandoCasa ? null : _agregarSiguienteCasa,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregandoCasa ? null : _agregarSiguienteCasa,
        icon: _agregandoCasa
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add),
        label: const Text('Agregar Casa'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ViviendaModel>>(
        stream: _firestoreService.obtenerCasasPorLote(widget.lote.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Error al cargar las casas:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }

          final casas = snapshot.data ?? [];

          final terminadas = casas.where((c) => c.estaTerminada).length;
          final enProceso = casas.where((c) => c.estado.trim().toLowerCase() == 'en proceso').length;
          final pendientes = casas.where((c) => c.estado.trim().toLowerCase() == 'pendiente').length;
          final total = casas.length;
          final porcentaje = total > 0 ? (terminadas / total) : 0.0;

          final casasFiltradas = casas.where((c) {
            if (_filtroEstado != 'TODOS') {
              if (c.estado.trim().toLowerCase() != _filtroEstado.toLowerCase()) {
                return false;
              }
            }
            if (_busqueda.isNotEmpty) {
              final query = _busqueda.toLowerCase();
              return c.codigoVisual.toLowerCase().contains(query) ||
                  c.id.toLowerCase().contains(query) ||
                  c.tecnicoNombre.toLowerCase().contains(query) ||
                  c.nombrePropietario.toLowerCase().contains(query) ||
                  c.propietarioCedula.toLowerCase().contains(query);
            }
            return true;
          }).toList();

          return Column(
            children: [
              // PANEL DE RESUMEN Y AVANCE
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$terminadas de $total casas terminadas',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: porcentaje,
                                  minHeight: 10,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    porcentaje == 1.0
                                        ? Colors.green.shade600
                                        : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            '${(porcentaje * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatusBadge('Pendiente', pendientes, Colors.grey.shade600, Colors.grey.shade100),
                        const SizedBox(width: 8),
                        _buildStatusBadge('En Proceso', enProceso, Colors.amber.shade800, Colors.amber.shade50),
                        const SizedBox(width: 8),
                        _buildStatusBadge('Terminada', terminadas, Colors.green.shade700, Colors.green.shade50),
                      ],
                    ),
                  ],
                ),
              ),

              // BARRA DE FILTROS Y BÚSQUEDA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar casa o propietario...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _busqueda.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() => _busqueda = ''),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (val) => setState(() => _busqueda = val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filtroEstado,
                          icon: const Icon(Icons.filter_list, size: 20),
                          items: const [
                            DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                            DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
                            DropdownMenuItem(value: 'En Proceso', child: Text('En Proceso')),
                            DropdownMenuItem(value: 'Terminada', child: Text('Terminada')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _filtroEstado = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // GRID VIEW DE CASAS
              Expanded(
                child: casasFiltradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.home_work_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              casas.isEmpty
                                  ? 'No hay casas creadas en este lote.'
                                  : 'Sin resultados para el filtro actual.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisExtent: 165,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: casasFiltradas.length,
                        itemBuilder: (context, index) {
                          final casa = casasFiltradas[index];
                          return _buildCasaCard(casa, proyecto);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String label, int count, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label: $count',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCasaCard(ViviendaModel casa, ProyectoProvider proyecto) {
    Color estadoColor;
    Color estadoBg;
    Color estadoBorder;
    IconData estadoIcon;

    final estadoNorm = casa.estado.trim().toLowerCase();
    if (estadoNorm == 'terminada') {
      estadoColor = Colors.green.shade800;
      estadoBg = const Color(0xFFDCFCE7);
      estadoBorder = Colors.green.shade300;
      estadoIcon = Icons.check_circle_rounded;
    } else if (estadoNorm == 'en proceso') {
      estadoColor = Colors.amber.shade900;
      estadoBg = const Color(0xFFFEF3C7);
      estadoBorder = Colors.amber.shade400;
      estadoIcon = Icons.timelapse_rounded;
    } else {
      estadoColor = Colors.blueGrey.shade700;
      estadoBg = const Color(0xFFF1F5F9);
      estadoBorder = Colors.blueGrey.shade200;
      estadoIcon = Icons.hourglass_empty_rounded;
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: estadoBorder, width: 1.2),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirModalDetalleCasa(casa, proyecto),
        onLongPress: () => _confirmarEliminarCasa(casa),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      casa.codigoVisual,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _confirmarEliminarCasa(casa),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: estadoBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(estadoIcon, size: 12, color: estadoColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        casa.estado,
                        style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // PROPIETARIO VISIBLE EN TARJETA
              Row(
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    size: 13,
                    color: casa.nombrePropietario.trim().isNotEmpty
                        ? const Color(0xFF1E3A8A)
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      casa.nombrePropietario.trim().isNotEmpty
                          ? casa.nombrePropietario.trim()
                          : 'Sin propietario',
                      style: TextStyle(
                        fontSize: 11,
                        color: casa.nombrePropietario.trim().isNotEmpty
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade500,
                        fontWeight: casa.nombrePropietario.trim().isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  String nombreTecnico;
                  Color colorTecnico;
                  if (casa.tecnicoId.isNotEmpty) {
                    final tec = proyecto.trabajadores.where((t) => t.id == casa.tecnicoId).firstOrNull;
                    if (tec != null && tec.activo) {
                      nombreTecnico = tec.nombre;
                      colorTecnico = const Color(0xFF334155);
                    } else if (tec != null && !tec.activo) {
                      nombreTecnico = '${tec.nombre} (Inactivo)';
                      colorTecnico = Colors.orange.shade800;
                    } else {
                      nombreTecnico = casa.tecnicoNombre.isNotEmpty
                          ? '${casa.tecnicoNombre} (Eliminado)'
                          : 'Técnico no disponible / Eliminado';
                      colorTecnico = Colors.orange.shade800;
                    }
                  } else {
                    nombreTecnico = casa.tecnicoNombre.isNotEmpty ? casa.tecnicoNombre : 'Sin técnico';
                    colorTecnico = Colors.grey.shade500;
                  }

                  return Row(
                    children: [
                      Icon(Icons.person_outline, size: 13, color: colorTecnico),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          nombreTecnico,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorTecnico,
                            fontWeight: casa.tecnicoId.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: casa.fotos.isEmpty
                        ? null
                        : () => FotoLightboxDialog.mostrar(
                              context,
                              fotos: casa.fotos,
                              casaId: casa.codigoVisual,
                            ),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      child: Row(
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 13,
                            color: casa.fotos.isNotEmpty ? const Color(0xFF2563EB) : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${casa.fotos.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: casa.fotos.isNotEmpty ? const Color(0xFF2563EB) : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (casa.observaciones.trim().isNotEmpty)
                    Icon(Icons.comment_outlined, size: 13, color: Colors.amber.shade800),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // EXPORTAR A EXCEL
  // =========================================================================
  Future<void> _exportarAExcel(List<ViviendaModel> casas) async {
    setState(() => _exportandoExcel = true);
    try {
      await ExcelService.exportarLoteAExcel(widget.lote, casas);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel de ${widget.lote.nombre} generado correctamente.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar Excel: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _exportandoExcel = false);
    }
  }

  // =========================================================================
  // AGREGAR SIGUIENTE CASA
  // =========================================================================
  Future<void> _agregarSiguienteCasa() async {
    setState(() => _agregandoCasa = true);
    try {
      final nueva = await _firestoreService.agregarCasaALote(
        loteId: widget.lote.id,
        prefijo: widget.lote.prefijo,
        loteNombre: widget.lote.nombre,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Casa ${nueva.codigoVisual} agregada exitosamente.'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al agregar casa: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _agregandoCasa = false);
    }
  }

  // =========================================================================
  // ELIMINAR CASA PREVIA CONFIRMACIÓN
  // =========================================================================
  void _confirmarEliminarCasa(ViviendaModel casa) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Confirmar Eliminación'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar la casa "${casa.codigoVisual}" del ${widget.lote.nombre}?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await _firestoreService.eliminarVivienda(
                  casa.id,
                  semanaId: casa.semanaId,
                  tecnicoId: casa.tecnicoId,
                  loteId: widget.lote.id,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Casa ${casa.codigoVisual} eliminada.'),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar casa: $e'), backgroundColor: Colors.red),
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

  // =========================================================================
  // MODAL DETALLE / EDICIÓN DE CASA
  // =========================================================================
  void _abrirModalDetalleCasa(ViviendaModel casa, ProyectoProvider proyecto) {
    String estadoSeleccionado = casa.estado;
    // Lista de técnicos activos y disponibles (evitando IDs duplicados)
    final tecnicosDisponibles = <TrabajadorModel>[];
    final Set<String> idsVistos = <String>{};
    for (final t in proyecto.trabajadores) {
      if (t.esTecnico && t.activo && idsVistos.add(t.id)) {
        tecnicosDisponibles.add(t);
      }
    }

    // 1. Validación segura: verificar si el técnico asignado existe en la lista de activos disponibles
    final bool tecnicoExisteYActivo = casa.tecnicoId.isNotEmpty &&
        tecnicosDisponibles.any((t) => t.id == casa.tecnicoId);

    final tecnicoAsignado = casa.tecnicoId.isNotEmpty
        ? proyecto.trabajadores.where((t) => t.id == casa.tecnicoId).firstOrNull
        : null;

    final bool tecnicoEliminadoOInactivo = casa.tecnicoId.isNotEmpty && !tecnicoExisteYActivo;

    // Si el técnico existe en la lista activa, asigna su ID. Si no existe (eliminado/inactivo), asigna null.
    String? tecnicoSeleccionadoId = tecnicoExisteYActivo ? casa.tecnicoId : null;
    String tecnicoSeleccionadoNombre = tecnicoExisteYActivo && tecnicoAsignado != null
        ? tecnicoAsignado.nombre
        : '';
    final obsController = TextEditingController(text: casa.observaciones);
    final propietarioController = TextEditingController(text: casa.nombrePropietario);
    final cedulaController = TextEditingController(text: casa.propietarioCedula);
    final telefonoController = TextEditingController(text: casa.propietarioTelefono);
    final direccionController = TextEditingController(text: casa.direccion);
    DateTime? fechaInstalacion = casa.fechaInstalacion;
    List<String> fotosActuales = List<String>.from(casa.fotos);

    bool subiendoFotos = false;
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CABECERA MODAL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                casa.codigoVisual,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.lote.nombre,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (casa.nombrePropietario.trim().isNotEmpty)
                                  Text(
                                    'Dueño: ${casa.nombrePropietario.trim()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomSheetCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // ── ESTADO ──
                    const Text('Estado de la Vivienda',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildEstadoChoiceChip(
                          label: 'Pendiente',
                          color: Colors.blueGrey,
                          selected: estadoSeleccionado == 'Pendiente',
                          onSelected: () => setModalState(() => estadoSeleccionado = 'Pendiente'),
                        ),
                        _buildEstadoChoiceChip(
                          label: 'En Proceso',
                          color: Colors.amber.shade800,
                          selected: estadoSeleccionado == 'En Proceso',
                          onSelected: () => setModalState(() => estadoSeleccionado = 'En Proceso'),
                        ),
                        _buildEstadoChoiceChip(
                          label: 'Terminada',
                          color: Colors.green.shade700,
                          selected: estadoSeleccionado == 'Terminada',
                          onSelected: () => setModalState(() => estadoSeleccionado = 'Terminada'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── TÉCNICO ──
                    const Text('Técnico Encargado',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        // Indicador de técnico eliminado/inactivo sin reasignar
                        final bool mostrarAdvertencia =
                            tecnicoEliminadoOInactivo && tecnicoSeleccionadoId == null;

                        // Validación segura del valor para el Dropdown (debe existir en la lista activa o ser null)
                        final String? dropdownValue = (tecnicoSeleccionadoId != null &&
                                tecnicosDisponibles.any((t) => t.id == tecnicoSeleccionadoId))
                            ? tecnicoSeleccionadoId
                            : null;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String?>(
                              key: ValueKey(dropdownValue),
                              initialValue: dropdownValue,
                              isExpanded: true,
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: Icon(
                                  Icons.engineering_outlined,
                                  color: mostrarAdvertencia ? Colors.orange.shade800 : null,
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: mostrarAdvertencia ? Colors.orange.shade400 : Colors.grey.shade400,
                                    width: mostrarAdvertencia ? 1.5 : 1.0,
                                  ),
                                ),
                                hintText: mostrarAdvertencia
                                    ? 'Técnico eliminado / No disponible - Seleccione uno nuevo'
                                    : 'Seleccionar técnico...',
                                hintStyle: TextStyle(
                                  color: mostrarAdvertencia ? Colors.orange.shade800 : Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    mostrarAdvertencia
                                        ? 'Técnico eliminado / No disponible - Seleccione uno nuevo'
                                        : 'Sin asignar',
                                    style: TextStyle(
                                      color: mostrarAdvertencia ? Colors.orange.shade900 : Colors.grey.shade700,
                                      fontStyle: mostrarAdvertencia ? FontStyle.italic : FontStyle.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                ...tecnicosDisponibles.map((t) => DropdownMenuItem<String?>(
                                      value: t.id,
                                      child: Text(
                                        '${t.nombre} (${t.rol})',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    )),
                              ],
                              onChanged: (val) {
                                setModalState(() {
                                  tecnicoSeleccionadoId = val;
                                  if (val != null) {
                                    final tec = tecnicosDisponibles
                                        .where((e) => e.id == val)
                                        .firstOrNull;
                                    tecnicoSeleccionadoNombre = tec?.nombre ?? '';
                                  } else {
                                    tecnicoSeleccionadoNombre = '';
                                  }
                                });
                              },
                            ),
                            if (mostrarAdvertencia) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade900),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        casa.tecnicoNombre.isNotEmpty
                                            ? 'El técnico asignado anteriormente ("${casa.tecnicoNombre}") fue eliminado o está inactivo. Por favor seleccione un nuevo técnico de la lista.'
                                            : 'Técnico eliminado / No disponible - Seleccione uno nuevo',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber.shade900,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── DATOS DEL PROPIETARIO ──
                    const Text('Datos del Propietario',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: propietarioController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Propietario / Dueño',
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cedulaController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Cédula Propietario',
                              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: telefonoController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Teléfono / WhatsApp',
                              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: direccionController,
                      decoration: InputDecoration(
                        labelText: 'Dirección exacta / Manzana',
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── FECHA DE INSTALACIÓN ──
                    InkWell(
                      onTap: () async {
                        final elegida = await showDatePicker(
                          context: ctx,
                          initialDate: fechaInstalacion ?? DateTime.now(),
                          firstDate: DateTime(2024, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (elegida != null) {
                          setModalState(() => fechaInstalacion = elegida);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha de Instalación',
                          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        child: Text(
                          fechaInstalacion != null
                              ? '${fechaInstalacion!.day.toString().padLeft(2, '0')}/${fechaInstalacion!.month.toString().padLeft(2, '0')}/${fechaInstalacion!.year}'
                              : 'Seleccionar fecha...',
                          style: TextStyle(
                            fontSize: 14,
                            color: fechaInstalacion != null ? Colors.black87 : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── OBSERVACIONES ──
                    const Text('Observaciones / Novedades',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: obsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Detalles técnicos, pendientes o notas...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── FOTOS DE EVIDENCIA ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fotos de Evidencia (${fotosActuales.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        TextButton.icon(
                          onPressed: subiendoFotos
                              ? null
                              : () async {
                                  setModalState(() => subiendoFotos = true);
                                  try {
                                    // El StorageService ahora sube y persiste en Firestore
                                    final nuevasUrls = await _storageService
                                        .seleccionarComprimirYSubir(casa.id);
                                    if (nuevasUrls.isNotEmpty) {
                                      setModalState(() {
                                        fotosActuales.addAll(nuevasUrls);
                                      });
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error al subir fotos: $e')),
                                      );
                                    }
                                  } finally {
                                    setModalState(() => subiendoFotos = false);
                                  }
                                },
                          icon: subiendoFotos
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_a_photo_outlined, size: 18),
                          label: const Text('Adjuntar'),
                        ),
                      ],
                    ),

                    if (fotosActuales.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: fotosActuales.length,
                          separatorBuilder: (context, _) => const SizedBox(width: 8),
                          itemBuilder: (ctx, idx) {
                            final url = fotosActuales[idx];
                            return Stack(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    FotoLightboxDialog.mostrar(
                                      context,
                                      fotos: fotosActuales,
                                      initialIndex: idx,
                                      casaId: casa.id,
                                    );
                                  },
                                  child: Tooltip(
                                    message: 'Toca para ampliar y descargar',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        url,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (c, child, progress) {
                                          if (progress == null) return child;
                                          return Container(
                                            width: 90,
                                            height: 90,
                                            color: Colors.grey.shade200,
                                            child: const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 90,
                                          height: 90,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.broken_image_outlined),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 3,
                                  left: 3,
                                  child: IgnorePointer(
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.zoom_in, size: 13, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: InkWell(
                                    onTap: () => setModalState(() => fotosActuales.removeAt(idx)),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── BOTÓN GUARDAR ──
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: guardando
                            ? null
                            : () async {
                                setModalState(() => guardando = true);
                                try {
                                  final esTerminada = estadoSeleccionado == 'Terminada';
                                  final semanaActivaId = proyecto.semanaActiva?.id ?? '';

                                  final casaActualizada = casa.copyWith(
                                    estado: estadoSeleccionado,
                                    tecnicoId: tecnicoSeleccionadoId ?? '',
                                    tecnicoNombre: tecnicoSeleccionadoNombre,
                                    observaciones: obsController.text.trim(),
                                    fotos: fotosActuales,
                                    nombrePropietario: propietarioController.text.trim(),
                                    propietarioCedula: cedulaController.text.trim(),
                                    propietarioTelefono: telefonoController.text.trim(),
                                    direccion: direccionController.text.trim(),
                                    fechaInstalacion: fechaInstalacion,
                                    fechaTerminacion: esTerminada
                                        ? (casa.fechaTerminacion ?? DateTime.now())
                                        : null,
                                    clearFechaTerminacion: !esTerminada,
                                    semanaId: esTerminada
                                        ? (casa.semanaId.isNotEmpty ? casa.semanaId : semanaActivaId)
                                        : '',
                                  );

                                  await _firestoreService.guardarVivienda(
                                    casaActualizada,
                                    semanaActivaId: semanaActivaId,
                                  );
                                  if (bottomSheetCtx.mounted) Navigator.pop(bottomSheetCtx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Casa ${casa.codigoVisual} actualizada correctamente.'),
                                        backgroundColor: Colors.green.shade700,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error al guardar cambios: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (bottomSheetCtx.mounted) {
                                    setModalState(() => guardando = false);
                                  }
                                }
                              },
                        child: guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Guardar Cambios',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEstadoChoiceChip({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.12),
      onSelected: (_) => onSelected(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
    );
  }
}
