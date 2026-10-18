import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/semana_model.dart';
import '../models/trabajador_model.dart';
import '../models/vivienda_model.dart';
import '../providers/proyecto_provider.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import '../widgets/pin_modal_widget.dart';

class NominaScreen extends StatefulWidget {
  const NominaScreen({super.key});

  @override
  State<NominaScreen> createState() => _NominaScreenState();
}

class _NominaScreenState extends State<NominaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final DateFormat _formatoFecha = DateFormat('dd/MM/yyyy');
  final DateFormat _formatoFechaHora = DateFormat('dd/MM/yyyy HH:mm');
  final FirestoreService _firestoreService = FirestoreService();
  bool _sincronizandoCasas = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proyecto = Provider.of<ProyectoProvider>(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0D47A1),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0D47A1),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            tabs: const [
              Tab(icon: Icon(Icons.table_chart_outlined, size: 18), text: 'Planilla'),
              Tab(icon: Icon(Icons.handyman_outlined, size: 18), text: 'Ayudantes'),
              Tab(icon: Icon(Icons.engineering_outlined, size: 18), text: 'Técnicos'),
              Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Personal'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _construirPestanaNomina(context, proyecto),
          _construirPestanaAyudantes(context, proyecto),
          _construirPestanaTecnicos(context, proyecto),
          _construirPestanaPersonal(context, proyecto),
        ],
      ),
    );
  }

  // =========================================================================
  // PESTAÑA 1: PLANILLA SEMANAL CONSOLIDADA
  // =========================================================================
  Widget _construirPestanaNomina(BuildContext context, ProyectoProvider proyecto) {
    final semana = proyecto.semanaActiva;

    if (semana == null) {
      return _pantallaVaciaCrearSemana(context, proyecto);
    }

    final ayudantes = semana.registros.where((r) => r.esAyudante).toList();
    final tecnicos = semana.registros.where((r) => r.esTecnico).toList();

    double totalGenerado = semana.registros.fold(0.0, (prev, r) => prev + r.totalGenerado);
    double totalPrestamos = semana.registros.fold(0.0, (prev, r) => prev + r.totalAdelantos);
    double totalPagado = semana.registros.fold(0.0, (prev, r) => prev + r.totalPagado);
    double totalSaldoPendiente = semana.registros.fold(0.0, (prev, r) => prev + r.saldoPendiente);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _construirControlSemana(context, proyecto, semana),
          const SizedBox(height: 12),
          _construirResumenFinanciero(totalGenerado, totalPrestamos, totalPagado, totalSaldoPendiente),
          const SizedBox(height: 16),
          _construirCabeceraSeccion(
            titulo: 'AYUDANTES DE OBRA',
            subtitulo: 'Días trabajados según asistencia',
            icono: Icons.handyman_outlined,
            color: Colors.teal.shade800,
          ),
          const SizedBox(height: 8),
          if (ayudantes.isEmpty)
            _mensajeSinRegistros('No hay ayudantes en esta semana.')
          else
            ...ayudantes.map((item) => _construirTarjetaItemNomina(context, item, semana, esAyudante: true)),
          const SizedBox(height: 24),
          _construirCabeceraSeccion(
            titulo: 'TÉCNICOS E INSTALADORES',
            subtitulo: 'Casas en estado "Terminada"',
            icono: Icons.engineering_outlined,
            color: const Color(0xFF0D47A1),
          ),
          const SizedBox(height: 8),
          if (tecnicos.isEmpty)
            _mensajeSinRegistros('No hay técnicos en esta semana.')
          else
            ...tecnicos.map((item) => _construirTarjetaItemNomina(context, item, semana, esAyudante: false)),
        ],
      ),
    );
  }

  // =========================================================================
  // PESTAÑA 2: 👷 AYUDANTES — StreamBuilder Reactivo
  // =========================================================================
  Widget _construirPestanaAyudantes(BuildContext context, ProyectoProvider proyecto) {
    final semana = proyecto.semanaActiva;

    return StreamBuilder<List<TrabajadorModel>>(
      stream: _firestoreService.streamTrabajadoresActivos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final todos = snapshot.data ?? [];
        final ayudantes = todos.where((t) => t.esAyudante).toList();

        if (ayudantes.isEmpty) {
          return _pantallaVaciaPersonal(
            context,
            'No hay ayudantes registrados.',
            'Registra un ayudante en la pestaña Personal.',
            Icons.handyman_outlined,
            Colors.teal,
          );
        }

        if (semana == null) {
          return _pantallaVaciaCrearSemana(context, proyecto);
        }

        return StreamBuilder<List<AsistenciaModel>>(
          stream: _firestoreService.streamAsistenciasPorSemana(semana.id),
          builder: (context, asistenciasSnap) {
            final asistenciasSemana = asistenciasSnap.data ?? [];

            return Scaffold(
              body: Column(
                children: [
                  // BANNER CORPORATIVO CON BOTÓN DESCARGAR EXCEL DE ASISTENCIA
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0500D0),
                          Color(0xFF1E3A8A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0500D0).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.table_chart_outlined, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PLANILLA DE ASISTENCIA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '${ayudantes.length} ayudantes en nómina',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0500D0),
                            elevation: 0,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: const Text(
                            'Descargar Excel de Asistencia',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            try {
                              await ExcelService.exportarPlanillaAsistenciaAExcel(
                                semana: semana,
                                ayudantes: ayudantes,
                                asistencias: asistenciasSemana,
                                configuracion: proyecto.configuracion,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Planilla de asistencia descargada con éxito.'),
                                    backgroundColor: Color(0xFF0500D0),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al exportar Excel: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // LISTADO DE AYUDANTES
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: ayudantes.length,
                      itemBuilder: (context, index) {
                        final ayudante = ayudantes[index];
                        final registro = semana.registros.where(
                          (r) => r.trabajadorId == ayudante.id && r.esAyudante,
                        ).firstOrNull;

                        final asistenciasAyudante = asistenciasSemana
                            .where((a) => a.ayudanteId == ayudante.id && a.asistio)
                            .toList()
                          ..sort((a, b) => a.fecha.compareTo(b.fecha));

                        return _construirTarjetaAyudante(
                          context,
                          ayudante,
                          registro,
                          semana,
                          proyecto,
                          asistencias: asistenciasAyudante,
                        );
                      },
                    ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: const Color(0xFF0500D0),
                icon: const Icon(Icons.price_change_outlined, color: Colors.white),
                label: const Text('Registrar Vale', style: TextStyle(color: Colors.white)),
                onPressed: semana.cerrada
                    ? null
                    : () => _mostrarDialogoRegistrarPrestamo(context, proyecto, semana),
              ),
            );
          },
        );
      },
    );
  }

  Widget _construirTarjetaAyudante(
    BuildContext context,
    TrabajadorModel ayudante,
    RegistroNominaItem? registro,
    SemanaModel semana,
    ProyectoProvider proyecto, {
    List<AsistenciaModel> asistencias = const [],
  }) {
    final diasTrabajados = (registro?.diasOcasas ?? 0.0).toDouble();
    final diasStr = diasTrabajados % 1 == 0
        ? '${diasTrabajados.toInt()}'
        : diasTrabajados.toStringAsFixed(1);
    final tarifaDiaria = registro?.tarifaUnitaria ?? proyecto.configuracion.tarifaAyudante;
    final bonificaciones = (registro?.bonificaciones ?? 0.0).toDouble();
    final totalBase = diasTrabajados * tarifaDiaria;
    final totalGenerado = totalBase + bonificaciones;
    final totalAdelantos = (registro?.totalAdelantos ?? 0.0).toDouble();
    final totalPagado = (registro?.totalPagado ?? 0.0).toDouble();
    final saldoNeto = totalGenerado - totalAdelantos - totalPagado;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ENCABEZADO
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.teal.shade50,
                  child: Icon(Icons.handyman, color: Colors.teal.shade700, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ayudante.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        ayudante.rol,
                        style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: saldoNeto > 0 ? Colors.blue.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: saldoNeto > 0 ? const Color(0xFF0D47A1) : Colors.green,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Saldo Neto a Pagar',
                          style: TextStyle(fontSize: 9, color: Colors.grey)),
                      Text(
                        _cop.format(saldoNeto),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: saldoNeto > 0 ? const Color(0xFF0D47A1) : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // DÍAS TRABAJADOS + CONTROLES
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: Colors.teal.shade600),
                const SizedBox(width: 6),
                const Text('Días trabajados:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (registro != null && !semana.cerrada)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Restar 0.5 día',
                    onPressed: diasTrabajados > 0
                        ? () async {
                            final nuevo = (diasTrabajados - 0.5) < 0 ? 0.0 : (diasTrabajados - 0.5);
                            await _firestoreService.actualizarDiasObrasManual(
                              semanaId: semana.id,
                              trabajadorId: ayudante.id,
                              nuevosDiasObras: nuevo,
                            );
                          }
                        : null,
                  ),
                InkWell(
                  onTap: semana.cerrada
                      ? null
                      : () => _mostrarDialogoEditarNumeroManual(
                            context,
                            semana.id,
                            registro ??
                                RegistroNominaItem(
                                  trabajadorId: ayudante.id,
                                  trabajadorNombre: ayudante.nombre,
                                  rol: ayudante.rol,
                                  tarifaUnitaria: tarifaDiaria,
                                ),
                            true,
                          ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      diasStr,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade800),
                    ),
                  ),
                ),
                if (registro != null && !semana.cerrada)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: Colors.teal.shade700, size: 20),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Sumar 0.5 día',
                    onPressed: () async {
                      await _firestoreService.actualizarDiasObrasManual(
                        semanaId: semana.id,
                        trabajadorId: ayudante.id,
                        nuevosDiasObras: diasTrabajados + 0.5,
                      );
                    },
                  ),
                const Spacer(),
                Text(
                  'Tarifa: ${_cop.format(tarifaDiaria)}/día',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // DESGLOSE FINANCIERO
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniMetrica('Base ($diasStr d)', _cop.format(totalBase), Colors.black87),
                  if (bonificaciones > 0)
                    _miniMetrica('(+) Bono', _cop.format(bonificaciones), Colors.purple.shade700),
                  _miniMetrica('Generado', _cop.format(totalGenerado), Colors.teal.shade900),
                  _miniMetrica('(-) Vales', _cop.format(totalAdelantos), Colors.amber.shade800),
                  _miniMetrica('(-) Pagado', _cop.format(totalPagado), Colors.green.shade700),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // BOTONES DE ACCIÓN
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!semana.cerrada) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.purple.shade700,
                      side: BorderSide(color: Colors.purple.shade300),
                    ),
                    icon: const Icon(Icons.card_giftcard_outlined, size: 16),
                    label: Text(bonificaciones > 0 ? 'Bonos: ${_cop.format(bonificaciones)}' : '+ Bono'),
                    onPressed: () => _mostrarModalGestionBonos(
                      context: context,
                      semanaId: semana.id,
                      trabajadorId: ayudante.id,
                      trabajadorNombre: ayudante.nombre,
                      semanaCerrada: semana.cerrada,
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.teal.shade700,
                      side: BorderSide(color: Colors.teal.shade300),
                    ),
                    icon: const Icon(Icons.today_outlined, size: 16),
                    label: const Text('+ 1 Día'),
                    onPressed: () async {
                      await _firestoreService.actualizarDiasObrasManual(
                        semanaId: semana.id,
                        trabajadorId: ayudante.id,
                        nuevosDiasObras: diasTrabajados + 1.0,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Día registrado para ${ayudante.nombre}'),
                          backgroundColor: Colors.teal.shade700,
                          duration: const Duration(seconds: 2),
                        ));
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.amber.shade800,
                      side: BorderSide(color: Colors.amber.shade300),
                    ),
                    icon: const Icon(Icons.price_change_outlined, size: 16),
                    label: const Text('+ Adelanto'),
                    onPressed: () => _mostrarDialogoRegistrarPrestamo(context, proyecto, semana,
                        preseleccionId: ayudante.id),
                  ),
                  if (registro != null) ...[
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF0D47A1),
                        side: const BorderSide(color: Color(0xFF0D47A1)),
                      ),
                      icon: const Icon(Icons.attach_money, size: 16),
                      label: const Text('Abonar'),
                      onPressed: semana.cerrada
                          ? null
                          : () => _mostrarDialogoAbonarPago(context, semana.id, registro, semana: semana),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.green.shade800,
                        side: BorderSide(color: Colors.green.shade300),
                      ),
                      icon: const Icon(Icons.history, size: 16),
                      label: Text(
                        registro.pagos.isNotEmpty
                            ? 'Abonos (${registro.pagos.length})'
                            : (registro.totalPagado > 0 ? 'Abonos (1)' : 'Abonos (0)'),
                      ),
                      onPressed: () => _mostrarModalHistorialAbonos(context, semana, registro),
                    ),
                  ],
                  const SizedBox(width: 6),
                ],
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.green, size: 22),
                  tooltip: 'Comprobante PDF (WhatsApp)',
                  onPressed: registro == null
                      ? null
                      : () {
                          final periodo =
                              '${_formatoFecha.format(semana.fechaInicio)} – ${_formatoFecha.format(semana.fechaFin)}';
                          final vales = registro.prestamos.isNotEmpty
                              ? registro.prestamos
                              : semana.prestamos.where((p) => p.trabajadorId == ayudante.id).toList();

                          PdfService.generarYCompartirComprobanteAyudante(
                            trabajador: ayudante,
                            registro: registro,
                            nombreSemana: semana.numeroSemana,
                            periodoSemana: periodo,
                            vales: vales,
                            configuracion: Provider.of<ProyectoProvider>(context, listen: false).configuracion,
                          );
                        },
                ),
              ],
            ),

            // DESGLOSE EXPANDIBLE: FECHAS DE ASISTENCIA
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
                collapsedIconColor: Colors.teal.shade700,
                iconColor: const Color(0xFF0500D0),
                leading: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: asistencias.isNotEmpty ? Colors.teal.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.event_available_outlined,
                    size: 16,
                    color: asistencias.isNotEmpty ? Colors.teal.shade700 : Colors.grey.shade500,
                  ),
                ),
                title: Text(
                  'Fechas de Asistencia (${asistencias.length} día${asistencias.length == 1 ? "" : "s"})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: asistencias.isNotEmpty ? Colors.teal.shade900 : Colors.grey.shade700,
                  ),
                ),
                children: [
                  if (asistencias.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: asistencias.map((asist) {
                          String etiqueta;
                          try {
                            final fmt = DateFormat('EEE dd/MMM', 'es_CO');
                            etiqueta = asist.esMedioDia
                                ? '½ ${fmt.format(asist.fecha)}'
                                : '✓ ${fmt.format(asist.fecha)}';
                          } catch (_) {
                            etiqueta = asist.esMedioDia
                                ? '½ ${asist.fecha.day}/${asist.fecha.month}'
                                : '✓ ${asist.fecha.day}/${asist.fecha.month}';
                          }
                          final bool esMedio = asist.esMedioDia;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: esMedio ? const Color(0xFFFEF3C7) : Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: esMedio ? Colors.amber.shade400 : Colors.teal.shade300,
                              ),
                            ),
                            child: Text(
                              etiqueta,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: esMedio ? Colors.amber.shade900 : Colors.teal.shade900,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        diasTrabajados > 0
                            ? 'Este ayudante tiene $diasTrabajados día(s) asignados de forma manual.'
                            : 'No se registran asistencias en el módulo de control diario para esta semana.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),

            // DESGLOSE EXPANDIBLE: BONOS / INCENTIVOS
            _construirSeccionBonosTrabajador(
              context: context,
              semanaId: semana.id,
              semanaCerrada: semana.cerrada,
              bonos: registro?.bonos.isNotEmpty == true
                  ? registro!.bonos
                  : semana.bonos.where((b) => b.trabajadorId == ayudante.id).toList(),
              trabajadorId: ayudante.id,
              trabajadorNombre: ayudante.nombre,
            ),

            // DESGLOSE EXPANDIBLE: VALES / ADELANTOS
            const SizedBox(height: 4),
            _construirSeccionValesTrabajador(
              context: context,
              semanaId: semana.id,
              semanaCerrada: semana.cerrada,
              vales: registro?.prestamos.isNotEmpty == true
                  ? registro!.prestamos
                  : semana.prestamos.where((p) => p.trabajadorId == ayudante.id).toList(),
              trabajadorId: ayudante.id,
              trabajadorNombre: ayudante.nombre,
              colorTema: Colors.teal.shade800,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PESTAÑA 3: 🔧 TÉCNICOS — StreamBuilder Reactivo con Casas Terminadas en tiempo real
  // =========================================================================
  Widget _construirPestanaTecnicos(BuildContext context, ProyectoProvider proyecto) {
    final semana = proyecto.semanaActiva;

    return StreamBuilder<List<TrabajadorModel>>(
      stream: _firestoreService.streamTrabajadoresActivos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final todos = snapshot.data ?? [];
        final tecnicos = todos.where((t) => t.esTecnico).toList();

        if (tecnicos.isEmpty) {
          return _pantallaVaciaPersonal(
            context,
            'No hay técnicos registrados.',
            'Registra un técnico en la pestaña Personal.',
            Icons.engineering_outlined,
            const Color(0xFF0D47A1),
          );
        }

        if (semana == null) {
          return _pantallaVaciaCrearSemana(context, proyecto);
        }

        return Scaffold(
          body: Column(
            children: [
              // BANNER CORPORATIVO CON BOTÓN DE RECONCILIACIÓN Y SINCRONIZACIÓN DE CASAS
              _construirBannerSincronizacionTecnicos(context, proyecto, semana),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tecnicos.length,
                  itemBuilder: (context, index) {
                    final tecnico = tecnicos[index];
                    final registro = semana.registros.where(
                      (r) => r.trabajadorId == tecnico.id && r.esTecnico,
                    ).firstOrNull;

                    return _construirTarjetaTecnicoReactiva(context, tecnico, registro, semana, proyecto);
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0D47A1),
            icon: const Icon(Icons.price_change_outlined, color: Colors.white),
            label: const Text('Registrar Adelanto', style: TextStyle(color: Colors.white)),
            onPressed: semana.cerrada
                ? null
                : () => _mostrarDialogoRegistrarPrestamo(context, proyecto, semana),
          ),
        );
      },
    );
  }

  /// Banner institucional superior para la pestaña de técnicos con botón de reconciliación
  Widget _construirBannerSincronizacionTecnicos(
    BuildContext context,
    ProyectoProvider proyecto,
    SemanaModel semana,
  ) {
    final int totalCasasSemana = semana.registros
        .where((r) => r.esTecnico)
        .fold(0, (acc, r) => acc + r.diasOcasas.toInt());

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0500D0),
            Color(0xFF1E3A8A),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0500D0).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.engineering_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LIQUIDACIÓN DE TÉCNICOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '$totalCasasSemana casas terminadas en nómina',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0500D0),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _sincronizandoCasas
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0500D0),
                    ),
                  )
                : const Icon(Icons.published_with_changes, size: 16),
            label: Text(
              _sincronizandoCasas ? 'Sincronizando...' : 'Sincronizar Casas',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: _sincronizandoCasas
                ? null
                : () => _ejecutarSincronizacionCasas(semana),
          ),
        ],
      ),
    );
  }

  /// Ejecuta la auditoría y reconciliación forzada de viviendas terminadas con la semana activa
  Future<void> _ejecutarSincronizacionCasas(SemanaModel semana) async {
    setState(() => _sincronizandoCasas = true);
    try {
      final resultado = await _firestoreService.reconciliarCasasTerminadasConSemana(
        semanaId: semana.id,
        fechaInicioSemana: semana.fechaInicio,
        fechaFinSemana: semana.fechaFin,
      );

      final total = resultado['totalCasasTerminadas'] ?? 0;
      final revinculadas = resultado['casasRevinculadas'] ?? 0;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sincronización completa: $total casas validadas ($revinculadas viviendas huérfanas vinculadas exitosamente)',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          content: Text('Error al sincronizar casas: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sincronizandoCasas = false);
      }
    }
  }

  Widget _construirTarjetaTecnicoReactiva(
    BuildContext context,
    TrabajadorModel tecnico,
    RegistroNominaItem? registro,
    SemanaModel semana,
    ProyectoProvider proyecto,
  ) {
    final tarifaPorCasa = registro?.tarifaUnitaria ?? proyecto.configuracion.tarifaTecnico;
    final totalAdelantos = registro?.totalAdelantos ?? 0.0;
    final totalPagado = registro?.totalPagado ?? 0.0;
    final bonificaciones = registro?.bonificaciones ?? 0.0;

    return StreamBuilder<List<ViviendaModel>>(
      stream: _firestoreService.streamCasasTerminadasTecnicoEnSemana(
        tecnicoId: tecnico.id,
        fechaInicio: semana.fechaInicio,
        fechaFin: semana.fechaFin,
        semanaId: semana.id,
      ),
      builder: (context, casasSnapshot) {
        final casasTerminadas = casasSnapshot.data ?? [];
        final int conteoStream = casasTerminadas.length;
        final int conteoRegistro = registro?.diasOcasas.toInt() ?? 0;
        final int cantidadCasas = casasSnapshot.hasData
            ? (conteoStream > 0 ? conteoStream : conteoRegistro)
            : conteoRegistro;
        final baseGenerada = cantidadCasas * tarifaPorCasa;
        final totalGeneradoBruto = baseGenerada + bonificaciones;
        final totalAPagar = totalGeneradoBruto - totalAdelantos - totalPagado;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ENCABEZADO CON CONTADOR DE CASAS DESTACADO
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: tecnico.rol == 'Dueño con labor de Técnico'
                          ? Colors.purple.shade50
                          : const Color(0xFFE3F2FD),
                      child: Icon(
                        Icons.engineering,
                        color: tecnico.rol == 'Dueño con labor de Técnico'
                            ? Colors.purple.shade700
                            : const Color(0xFF0D47A1),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tecnico.nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            tecnico.rol,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    // CONTADOR DESTACADO DE CASAS
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF0D47A1), Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$cantidadCasas',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'casas',
                            style: TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Semana: ${_formatoFecha.format(semana.fechaInicio)} – ${_formatoFecha.format(semana.fechaFin)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ),
                const Divider(height: 16),

                // TARIFA Y GENERADO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.home_outlined, size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Tarifa: ${_cop.format(tarifaPorCasa)}/casa',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (casasSnapshot.connectionState == ConnectionState.waiting)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total Devengado: ${_cop.format(totalGeneradoBruto)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          if (bonificaciones > 0)
                            Text(
                              '(${_cop.format(baseGenerada)} + Bono ${_cop.format(bonificaciones)})',
                              style: TextStyle(fontSize: 10, color: Colors.purple.shade700, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // DESGLOSE FINANCIERO
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _miniMetrica('Base ($cantidadCasas c)', _cop.format(baseGenerada), Colors.blue.shade800),
                      if (bonificaciones > 0)
                        _miniMetrica('(+) Bono', _cop.format(bonificaciones), Colors.purple.shade700),
                      _miniMetrica('(-) Vales', _cop.format(totalAdelantos), Colors.amber.shade800),
                      _miniMetrica('(-) Pagado', _cop.format(totalPagado), Colors.green.shade700),
                      _miniMetrica(
                        'A Pagar',
                        _cop.format(totalAPagar),
                        totalAPagar > 0 ? const Color(0xFF0D47A1) : Colors.green.shade800,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // BOTONES DE ACCIÓN
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF0D47A1),
                      ),
                      icon: const Icon(Icons.home_work_outlined, size: 16),
                      label: const Text('Ver Casas'),
                      onPressed: casasTerminadas.isEmpty
                          ? null
                          : () => _mostrarModalCasasCompletadas(context, tecnico.nombre, casasTerminadas),
                    ),
                    if (!semana.cerrada)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Colors.purple.shade800,
                          side: BorderSide(color: Colors.purple.shade300),
                        ),
                        icon: const Icon(Icons.card_giftcard, size: 16),
                        label: Text(bonificaciones > 0 ? 'Bonos: ${_cop.format(bonificaciones)}' : '+ Bono'),
                        onPressed: () => _mostrarModalGestionBonos(
                          context: context,
                          semanaId: semana.id,
                          trabajadorId: tecnico.id,
                          trabajadorNombre: tecnico.nombre,
                          semanaCerrada: semana.cerrada,
                        ),
                      ),
                    if (!semana.cerrada)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Colors.amber.shade800,
                          side: BorderSide(color: Colors.amber.shade300),
                        ),
                        icon: const Icon(Icons.price_change_outlined, size: 16),
                        label: const Text('+ Adelanto'),
                        onPressed: () => _mostrarDialogoRegistrarPrestamo(context, proyecto, semana,
                            preseleccionId: tecnico.id),
                      ),
                    if (registro != null) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFF0D47A1),
                          side: const BorderSide(color: Color(0xFF0D47A1)),
                        ),
                        icon: const Icon(Icons.attach_money, size: 16),
                        label: const Text('Abonar'),
                        onPressed: semana.cerrada
                            ? null
                            : () => _mostrarDialogoAbonarPago(context, semana.id, registro, semana: semana),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Colors.green.shade800,
                          side: BorderSide(color: Colors.green.shade300),
                        ),
                        icon: const Icon(Icons.history, size: 16),
                        label: Text(
                          registro.pagos.isNotEmpty
                              ? 'Abonos (${registro.pagos.length})'
                              : (registro.totalPagado > 0 ? 'Abonos (1)' : 'Abonos (0)'),
                        ),
                        onPressed: () => _mostrarModalHistorialAbonos(context, semana, registro),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.green, size: 22),
                      tooltip: 'Comprobante PDF',
                      onPressed: () {
                        final regConCasas = (registro ?? RegistroNominaItem(
                          trabajadorId: tecnico.id,
                          trabajadorNombre: tecnico.nombre,
                          rol: tecnico.rol,
                          diasOcasas: cantidadCasas.toDouble(),
                          tarifaUnitaria: tarifaPorCasa,
                          totalAdelantos: totalAdelantos,
                          totalPagado: totalPagado,
                          bonificaciones: bonificaciones,
                        )).copyWith(
                          diasOcasas: cantidadCasas.toDouble(),
                          bonificaciones: bonificaciones,
                        );
                        final periodo =
                            '${_formatoFecha.format(semana.fechaInicio)} – ${_formatoFecha.format(semana.fechaFin)}';
                        final vales = registro?.prestamos.isNotEmpty == true
                            ? registro!.prestamos
                            : semana.prestamos.where((p) => p.trabajadorId == tecnico.id).toList();

                        PdfService.generarYCompartirComprobanteTecnico(
                          trabajador: tecnico,
                          registro: regConCasas,
                          nombreSemana: semana.numeroSemana,
                          periodoSemana: periodo,
                          viviendasCompletadas: casasTerminadas,
                          vales: vales,
                          configuracion: Provider.of<ProyectoProvider>(context, listen: false).configuracion,
                        );
                      },
                    ),
                  ],
                ),

                // DESGLOSE EXPANDIBLE: BONOS / INCENTIVOS
                _construirSeccionBonosTrabajador(
                  context: context,
                  semanaId: semana.id,
                  semanaCerrada: semana.cerrada,
                  bonos: registro?.bonos.isNotEmpty == true
                      ? registro!.bonos
                      : semana.bonos.where((b) => b.trabajadorId == tecnico.id).toList(),
                  trabajadorId: tecnico.id,
                  trabajadorNombre: tecnico.nombre,
                ),

                // DESGLOSE EXPANDIBLE: VALES / ADELANTOS
                const SizedBox(height: 4),
                _construirSeccionValesTrabajador(
                  context: context,
                  semanaId: semana.id,
                  semanaCerrada: semana.cerrada,
                  vales: registro?.prestamos.isNotEmpty == true
                      ? registro!.prestamos
                      : semana.prestamos.where((p) => p.trabajadorId == tecnico.id).toList(),
                  trabajadorId: tecnico.id,
                  trabajadorNombre: tecnico.nombre,
                  colorTema: const Color(0xFF0D47A1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // MODAL: CASAS COMPLETADAS POR TÉCNICO
  // =========================================================================
  void _mostrarModalCasasCompletadas(
      BuildContext context, String nombreTecnico, List<ViviendaModel> casas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.home_work_outlined, color: Color(0xFF0D47A1), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Casas Completadas — $nombreTecnico',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${casas.length} casa(s) terminada(s) esta semana',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: casas.length,
                  separatorBuilder: (_, idx) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final casa = casas[index];
                    return ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          casa.codigoVisual,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(
                        casa.loteNombre.isNotEmpty ? casa.loteNombre : 'Sin lote',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        casa.fechaTerminacion != null
                            ? 'Terminada: ${_formatoFecha.format(casa.fechaTerminacion!)}'
                            : casa.direccion.isNotEmpty
                                ? casa.direccion
                                : 'Sin fecha registrada',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: Colors.green.shade700, size: 16),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // PESTAÑA 4: GESTIÓN DE PERSONAL
  // =========================================================================
  Widget _construirPestanaPersonal(BuildContext context, ProyectoProvider proyecto) {
    return StreamBuilder<List<TrabajadorModel>>(
      stream: _firestoreService.streamTrabajadores(),
      builder: (context, snapshotTodos) {
        if (snapshotTodos.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

            final trabajadores = snapshotTodos.data ?? [];

            return Scaffold(
              body: trabajadores.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No hay trabajadores registrados.',
                            style: TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1)),
                            icon: const Icon(Icons.person_add, color: Colors.white),
                            label: const Text('Registrar Primer Trabajador',
                                style: TextStyle(color: Colors.white)),
                            onPressed: () =>
                                _mostrarDialogoRegistrarEditarTrabajador(context),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: trabajadores.length,
                      itemBuilder: (context, index) {
                        final t = trabajadores[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: t.esAyudante
                                  ? Colors.teal.shade100
                                  : (t.rol == 'Dueño con labor de Técnico'
                                      ? Colors.purple.shade100
                                      : const Color(0xFF0D47A1).withAlpha(30)),
                              child: Icon(
                                t.esAyudante ? Icons.handyman : Icons.engineering,
                                color: t.esAyudante
                                    ? Colors.teal.shade800
                                    : (t.rol == 'Dueño con labor de Técnico'
                                        ? Colors.purple.shade800
                                        : const Color(0xFF0D47A1)),
                              ),
                            ),
                            title: Text(t.nombre,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Rol: ${t.rol}\n${t.cedula.isNotEmpty ? "C.C: ${t.cedula} | " : ""}Tel: ${t.telefono}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color(0xFF0D47A1)),
                                  tooltip: 'Editar',
                                  onPressed: () =>
                                      _mostrarDialogoRegistrarEditarTrabajador(context,
                                          trabajadorAEditar: t),
                                ),
                                Switch.adaptive(
                                  value: t.activo,
                                  activeTrackColor: Colors.green,
                                  onChanged: (activo) async {
                                    final actualizado = t.copyWith(activo: activo);
                                    await _firestoreService.guardarTrabajador(actualizado);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Eliminar',
                                  onPressed: () =>
                                      _confirmarEliminarTrabajador(context, t),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: const Color(0xFF0D47A1),
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text('Nuevo Trabajador', style: TextStyle(color: Colors.white)),
                onPressed: () => _mostrarDialogoRegistrarEditarTrabajador(context),
              ),
            );
          },
        );
  }

  // =========================================================================
  // HELPERS DE UI
  // =========================================================================
  Widget _pantallaVaciaCrearSemana(BuildContext context, ProyectoProvider proyecto) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No hay semana de nómina activa.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Crear Nueva Semana', style: TextStyle(color: Colors.white)),
            onPressed: () => _mostrarDialogoCrearSemana(context, proyecto),
          ),
        ],
      ),
    );
  }

  Widget _pantallaVaciaPersonal(BuildContext context, String titulo, String subtitulo,
      IconData icono, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(titulo, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(subtitulo, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('Registrar Trabajador', style: TextStyle(color: Colors.white)),
            onPressed: () => _mostrarDialogoRegistrarEditarTrabajador(context),
          ),
        ],
      ),
    );
  }

  Widget _miniMetrica(String label, String valor, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(valor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _bloqueMetrica(String label, String valor, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _construirCabeceraSeccion({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 11, color: color.withAlpha(200)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensajeSinRegistros(String mensaje) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(mensaje, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _construirControlSemana(
      BuildContext context, ProyectoProvider proyecto, SemanaModel semana) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: semana.id,
                      isExpanded: true,
                      items: proyecto.semanas.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.numeroSemana}${s.cerrada ? " (CERRADA)" : " (ACTIVA)"}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: s.cerrada ? Colors.grey : const Color(0xFF0D47A1),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (semanaId) {
                        if (semanaId != null) {
                          final sel = proyecto.semanas.firstWhere((s) => s.id == semanaId);
                          proyecto.seleccionarSemana(sel);
                        }
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: _sincronizandoCasas
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D47A1)),
                        )
                      : const Icon(Icons.published_with_changes, color: Color(0xFF0D47A1), size: 20),
                  tooltip: 'Reconciliar y sincronizar viviendas terminadas',
                  visualDensity: VisualDensity.compact,
                  onPressed: _sincronizandoCasas ? null : () => _ejecutarSincronizacionCasas(semana),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_calendar_outlined, color: Color(0xFF0D47A1), size: 20),
                  tooltip: 'Editar Semana (Fechas y Número)',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _mostrarDialogoEditarSemana(context, proyecto, semana),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'Eliminar Semana con PIN',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmarEliminarSemana(context, proyecto, semana),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: semana.cerrada ? Colors.grey.shade200 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: semana.cerrada ? Colors.grey : Colors.green,
                    ),
                  ),
                  child: Text(
                    semana.cerrada ? 'CERRADA' : 'ABIERTA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: semana.cerrada ? Colors.grey.shade700 : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.price_change_outlined, size: 16),
                  label: const Text('Registrar Préstamo / Vale'),
                  onPressed: semana.cerrada
                      ? null
                      : () => _mostrarDialogoRegistrarPrestamo(context, proyecto, semana),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nueva Semana'),
                  onPressed: () => _mostrarDialogoCrearSemana(context, proyecto),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0D47A1),
                  ),
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Exportar Consolidado'),
                  onPressed: () => PdfService.exportarReporteConsolidadoGeneral(
                    semana: semana,
                    registros: semana.registros,
                    configuracion: proyecto.configuracion,
                  ),
                ),
                if (!semana.cerrada)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.lock_outline, size: 16),
                    label: const Text('Cerrar Semana'),
                    onPressed: () => _confirmarCierreSemana(context, proyecto),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.teal,
                    ),
                    icon: const Icon(Icons.lock_open, size: 16),
                    label: const Text('Reabrir con PIN'),
                    onPressed: () =>
                        _mostrarModalReabrirSemana(context, proyecto, semana.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirResumenFinanciero(
      double totalGenerado, double totalPrestamos, double totalPagado, double totalSaldo) {
    return Card(
      elevation: 1,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bloqueMetrica('Total Generado', _cop.format(totalGenerado), Colors.black87),
            _bloqueMetrica('Vales/Préstamos', _cop.format(totalPrestamos), Colors.amber.shade900),
            _bloqueMetrica('Total Pagado', _cop.format(totalPagado), Colors.green.shade800),
            _bloqueMetrica('Saldo Pendiente', _cop.format(totalSaldo), const Color(0xFF0D47A1)),
          ],
        ),
      ),
    );
  }

  Widget _construirTarjetaItemNomina(
    BuildContext context,
    RegistroNominaItem item,
    SemanaModel semana, {
    required bool esAyudante,
  }) {
    final diasStr = item.diasOcasas % 1 == 0
        ? item.diasOcasas.toInt().toString()
        : item.diasOcasas.toStringAsFixed(1);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.trabajadorNombre,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        item.rol,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.saldoPendiente > 0 ? Colors.blue.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: item.saldoPendiente > 0 ? const Color(0xFF0D47A1) : Colors.green,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Saldo Pendiente', style: TextStyle(fontSize: 9, color: Colors.grey)),
                      Text(
                        _cop.format(item.saldoPendiente),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: item.saldoPendiente > 0 ? const Color(0xFF0D47A1) : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      esAyudante ? 'Días Asistidos: ' : 'Casas Terminadas: ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (!semana.cerrada)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                        visualDensity: VisualDensity.compact,
                        tooltip: esAyudante ? 'Restar 0.5 días' : 'Restar 1 casa',
                        onPressed: item.diasOcasas > 0
                            ? () async {
                                final paso = esAyudante ? 0.5 : 1.0;
                                final nuevo = (item.diasOcasas - paso).clamp(0.0, 999.0);
                                await _firestoreService.actualizarDiasObrasManual(
                                  semanaId: semana.id,
                                  trabajadorId: item.trabajadorId,
                                  nuevosDiasObras: nuevo,
                                );
                              }
                            : null,
                      ),
                    InkWell(
                      onTap: semana.cerrada
                          ? null
                          : () => _mostrarDialogoEditarNumeroManual(
                              context, semana.id, item, esAyudante),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          diasStr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    if (!semana.cerrada)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
                        visualDensity: VisualDensity.compact,
                        tooltip: esAyudante ? 'Sumar 0.5 días' : 'Sumar 1 casa',
                        onPressed: () async {
                          final paso = esAyudante ? 0.5 : 1.0;
                          await _firestoreService.actualizarDiasObrasManual(
                            semanaId: semana.id,
                            trabajadorId: item.trabajadorId,
                            nuevosDiasObras: item.diasOcasas + paso,
                          );
                        },
                      ),
                  ],
                ),
                Text(
                  'Tarifa: ${_cop.format(item.tarifaUnitaria)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('Devengado: ${_cop.format(item.totalGenerado)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  if (item.bonificaciones > 0)
                    Text('(+) Bono: ${_cop.format(item.bonificaciones)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple.shade700)),
                  Text('(-) Vales: ${_cop.format(item.totalAdelantos)}',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900)),
                  Text('(-) Pagado: ${_cop.format(item.totalPagado)}',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade800)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!semana.cerrada)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.purple.shade800,
                      side: BorderSide(color: Colors.purple.shade300),
                    ),
                    icon: const Icon(Icons.card_giftcard, size: 16),
                    label: Text(item.bonificaciones > 0 ? 'Bonos: ${_cop.format(item.bonificaciones)}' : '+ Bono'),
                    onPressed: () => _mostrarModalGestionBonos(
                      context: context,
                      semanaId: semana.id,
                      trabajadorId: item.trabajadorId,
                      trabajadorNombre: item.trabajadorNombre,
                      semanaCerrada: semana.cerrada,
                    ),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0D47A1),
                  ),
                  icon: const Icon(Icons.attach_money, size: 16),
                  label: const Text('Abonar'),
                  onPressed: semana.cerrada
                      ? null
                      : () => _mostrarDialogoAbonarPago(context, semana.id, item, semana: semana),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.green.shade800,
                    side: BorderSide(color: Colors.green.shade300),
                  ),
                  icon: const Icon(Icons.history, size: 16),
                  label: Text(
                    item.pagos.isNotEmpty
                        ? 'Abonos (${item.pagos.length})'
                        : (item.totalPagado > 0 ? 'Abonos (1)' : 'Abonos (0)'),
                  ),
                  onPressed: () => _mostrarModalHistorialAbonos(context, semana, item),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.green, size: 20),
                  tooltip: 'Comprobante PDF (WhatsApp)',
                  onPressed: () {
                    final proyecto = Provider.of<ProyectoProvider>(context, listen: false);
                    final trabajador = proyecto.trabajadores
                            .where((t) => t.id == item.trabajadorId)
                            .firstOrNull ??
                        TrabajadorModel(
                          id: item.trabajadorId,
                          nombre: item.trabajadorNombre,
                          rol: item.rol,
                          telefono: '',
                        );

                    final periodo =
                        '${_formatoFecha.format(semana.fechaInicio)} – ${_formatoFecha.format(semana.fechaFin)}';
                    final vales = item.prestamos.isNotEmpty
                        ? item.prestamos
                        : semana.prestamos.where((p) => p.trabajadorId == item.trabajadorId).toList();

                    if (item.esTecnico) {
                      final inicio = DateTime(
                          semana.fechaInicio.year, semana.fechaInicio.month, semana.fechaInicio.day);
                      final fin = DateTime(
                          semana.fechaFin.year, semana.fechaFin.month, semana.fechaFin.day, 23, 59, 59);

                      final casasTecnico = proyecto.viviendas.where((v) {
                        if (v.tecnicoId != item.trabajadorId ||
                            v.estado.trim().toLowerCase() != 'terminada') {
                          return false;
                        }
                        if (v.semanaId == semana.id) return true;
                        final f = v.fechaTerminacion ?? v.fechaRegistro;
                        return !f.isBefore(inicio) && !f.isAfter(fin);
                      }).toList();

                      final regConCasas = item.copyWith(
                        diasOcasas:
                            casasTecnico.isNotEmpty ? casasTecnico.length.toDouble() : item.diasOcasas,
                      );

                      PdfService.generarYCompartirComprobanteTecnico(
                        trabajador: trabajador,
                        registro: regConCasas,
                        nombreSemana: semana.numeroSemana,
                        periodoSemana: periodo,
                        viviendasCompletadas: casasTecnico,
                        vales: vales,
                        configuracion: Provider.of<ProyectoProvider>(context, listen: false).configuracion,
                      );
                    } else {
                      PdfService.generarYCompartirComprobanteAyudante(
                        trabajador: trabajador,
                        registro: item,
                        nombreSemana: semana.numeroSemana,
                        periodoSemana: periodo,
                        vales: vales,
                        configuracion: Provider.of<ProyectoProvider>(context, listen: false).configuracion,
                      );
                    }
                  },
                ),
              ],
            ),

            // DESGLOSE EXPANDIBLE: BONOS / INCENTIVOS
            _construirSeccionBonosTrabajador(
              context: context,
              semanaId: semana.id,
              semanaCerrada: semana.cerrada,
              bonos: item.bonos.isNotEmpty
                  ? item.bonos
                  : semana.bonos.where((b) => b.trabajadorId == item.trabajadorId).toList(),
              trabajadorId: item.trabajadorId,
              trabajadorNombre: item.trabajadorNombre,
            ),

            // DESGLOSE EXPANDIBLE: VALES / ADELANTOS
            const SizedBox(height: 4),
            _construirSeccionValesTrabajador(
              context: context,
              semanaId: semana.id,
              semanaCerrada: semana.cerrada,
              vales: item.prestamos.isNotEmpty
                  ? item.prestamos
                  : semana.prestamos.where((p) => p.trabajadorId == item.trabajadorId).toList(),
              trabajadorId: item.trabajadorId,
              trabajadorNombre: item.trabajadorNombre,
              colorTema: const Color(0xFF0D47A1),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // MODAL REGISTRAR / EDITAR TRABAJADOR
  // =========================================================================
  void _mostrarDialogoRegistrarEditarTrabajador(BuildContext context,
      {TrabajadorModel? trabajadorAEditar}) {
    final esEdicion = trabajadorAEditar != null;
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: trabajadorAEditar?.nombre ?? '');
    final cedulaCtrl = TextEditingController(text: trabajadorAEditar?.cedula ?? '');
    final telCtrl = TextEditingController(text: trabajadorAEditar?.telefono ?? '');

    String rolSeleccionado = trabajadorAEditar?.rol ?? 'Ayudante de Obra';
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esEdicion ? 'Editar Trabajador' : 'Registrar Nuevo Trabajador',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre y Apellidos Completos *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Ingresa el nombre completo' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cedulaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número de Cédula *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Ingresa el número de cédula' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono / WhatsApp *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Ingresa el teléfono' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: rolSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Rol en el Proyecto *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Ayudante de Obra',
                        child: Text('Ayudante de Obra'),
                      ),
                      DropdownMenuItem(
                        value: 'Técnico Instalador',
                        child: Text('Técnico Instalador'),
                      ),
                      DropdownMenuItem(
                        value: 'Dueño con labor de Técnico',
                        child: Text('Dueño con labor de Técnico'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => rolSeleccionado = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: guardando
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => guardando = true);
                              try {
                                final trabajador = TrabajadorModel(
                                  id: esEdicion ? trabajadorAEditar.id : '',
                                  nombre: nombreCtrl.text.trim(),
                                  cedula: cedulaCtrl.text.trim(),
                                  telefono: telCtrl.text.trim(),
                                  rol: rolSeleccionado,
                                  activo: esEdicion ? trabajadorAEditar.activo : true,
                                );
                                await _firestoreService.guardarTrabajador(trabajador);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        esEdicion
                                            ? 'Trabajador actualizado exitosamente'
                                            : 'Trabajador registrado exitosamente',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => guardando = false);
                              }
                            },
                      child: guardando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              esEdicion ? 'Actualizar Trabajador' : 'Guardar Trabajador',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // CONFIRMAR ELIMINACIÓN DE TRABAJADOR
  // =========================================================================
  void _confirmarEliminarTrabajador(BuildContext context, TrabajadorModel trabajador) {
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
          '¿Deseas eliminar al trabajador "${trabajador.nombre}" (${trabajador.rol})?\n\n'
          'Esta acción es irreversible.',
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
                await _firestoreService.eliminarTrabajador(trabajador.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Trabajador "${trabajador.nombre}" eliminado.'),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e'),
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

  // =========================================================================
  // MODAL REGISTRAR PRÉSTAMO / VALE
  // =========================================================================
  void _mostrarDialogoRegistrarPrestamo(
      BuildContext context, ProyectoProvider proyecto, SemanaModel semana,
      {String? preseleccionId}) {
    final formKey = GlobalKey<FormState>();
    final montoCtrl = TextEditingController();
    final conceptoCtrl = TextEditingController(text: 'Vale / Adelanto semanal');
    String? trabajadorSeleccionadoId =
        preseleccionId ?? (semana.registros.isNotEmpty ? semana.registros.first.trabajadorId : null);
    DateTime fechaPrestamo = DateTime.now();
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Registrar Préstamo / Vale',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Este valor se descuenta automáticamente del saldo y se registra en Gastos.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: trabajadorSeleccionadoId,
                    decoration: const InputDecoration(
                      labelText: 'Trabajador Beneficiario *',
                      border: OutlineInputBorder(),
                    ),
                    items: semana.registros.map((r) {
                      return DropdownMenuItem(
                        value: r.trabajadorId,
                        child: Text('${r.trabajadorNombre} (${r.rol})'),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => trabajadorSeleccionadoId = val),
                    validator: (val) => val == null ? 'Selecciona un trabajador' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto del Préstamo / Vale (\$) *',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Ingresa el monto';
                      final num? m = num.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                      if (m == null || m <= 0) return 'Monto inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: conceptoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Concepto / Motivo *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Ingresa el concepto' : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final elegida = await showDatePicker(
                        context: context,
                        initialDate: fechaPrestamo,
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: DateTime(2030, 12, 31),
                      );
                      if (elegida != null) {
                        setModalState(() => fechaPrestamo = elegida);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha del Préstamo',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatoFecha.format(fechaPrestamo)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: guardando
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => guardando = true);

                              try {
                                final monto = double.parse(
                                  montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                                );
                                final reg = semana.registros.firstWhere(
                                  (r) => r.trabajadorId == trabajadorSeleccionadoId,
                                );

                                final prestamo = PrestamoModel(
                                  id: '',
                                  trabajadorId: reg.trabajadorId,
                                  trabajadorNombre: reg.trabajadorNombre,
                                  monto: monto,
                                  fecha: fechaPrestamo,
                                  concepto: conceptoCtrl.text.trim(),
                                  semanaId: semana.id,
                                );

                                await _firestoreService.registrarPrestamo(
                                  semanaId: semana.id,
                                  prestamo: prestamo,
                                );

                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Préstamo de ${_cop.format(monto)} registrado a ${reg.trabajadorNombre}.',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => guardando = false);
                              }
                            },
                      child: guardando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Guardar y Descontar Vale',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SECCIÓN EXPANDIBLE DE VALES / ADELANTOS POR TRABAJADOR
  // =========================================================================
  Widget _construirSeccionValesTrabajador({
    required BuildContext context,
    required String semanaId,
    required bool semanaCerrada,
    required List<PrestamoModel> vales,
    required String trabajadorId,
    required String trabajadorNombre,
    required Color colorTema,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
        collapsedIconColor: Colors.amber.shade800,
        iconColor: Colors.amber.shade900,
        leading: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: vales.isNotEmpty ? Colors.amber.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.price_change_outlined,
            size: 16,
            color: vales.isNotEmpty ? Colors.amber.shade800 : Colors.grey.shade500,
          ),
        ),
        title: Text(
          'Vales / Adelantos (${vales.length} registrado${vales.length == 1 ? "" : "s"})',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: vales.isNotEmpty ? Colors.amber.shade900 : Colors.grey.shade700,
          ),
        ),
        children: [
          if (vales.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vales.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (ctx, idx) {
                final vale = vales[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.attach_money, size: 14, color: Colors.amber.shade900),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vale.concepto.isNotEmpty ? vale.concepto : 'Vale / Adelanto',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            Text(
                              _formatoFecha.format(vale.fecha),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _cop.format(vale.monto),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      if (!semanaCerrada) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0D47A1)),
                          tooltip: 'Editar Vale',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _mostrarDialogoEditarPrestamo(context, semanaId, vale),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          tooltip: 'Eliminar Vale',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _confirmarEliminarPrestamo(context, semanaId, vale),
                        ),
                      ],
                    ],
                  ),
                );
              },
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'No hay vales o adelantos registrados para este trabajador en la semana.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECCIÓN EXPANDIBLE DE BONIFICACIONES / INCENTIVOS POR TRABAJADOR
  // =========================================================================
  Widget _construirSeccionBonosTrabajador({
    required BuildContext context,
    required String semanaId,
    required bool semanaCerrada,
    required List<BonoItemModel> bonos,
    required String trabajadorId,
    required String trabajadorNombre,
  }) {
    if (bonos.isEmpty) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
        collapsedIconColor: Colors.purple.shade700,
        iconColor: Colors.purple.shade900,
        leading: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.card_giftcard,
            size: 16,
            color: Colors.purple.shade800,
          ),
        ),
        title: Text(
          'Bonos e Incentivos (${bonos.length} registrado${bonos.length == 1 ? "" : "s"})',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.purple.shade900,
          ),
        ),
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bonos.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (ctx, idx) {
              final bono = bonos[idx];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.stars, size: 14, color: Colors.purple.shade900),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bono.concepto.isNotEmpty ? bono.concepto : 'Bono / Incentivo',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          Text(
                            _formatoFecha.format(bono.fechaRegistro),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _cop.format(bono.monto),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.purple.shade900,
                      ),
                    ),
                    if (!semanaCerrada) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0D47A1)),
                        tooltip: 'Editar Bono',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _mostrarDialogoCrearEditarBono(
                          context: context,
                          semanaId: semanaId,
                          trabajadorId: trabajadorId,
                          trabajadorNombre: trabajadorNombre,
                          bonoAEditar: bono,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: 'Eliminar Bono',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmarEliminarBono(
                          context: context,
                          semanaId: semanaId,
                          bono: bono,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MODAL EDITAR PRÉSTAMO / VALE
  // =========================================================================
  void _mostrarDialogoEditarPrestamo(
    BuildContext context,
    String semanaId,
    PrestamoModel prestamo,
  ) {
    final formKey = GlobalKey<FormState>();
    final montoCtrl = TextEditingController(
      text: prestamo.monto % 1 == 0
          ? prestamo.monto.toInt().toString()
          : prestamo.monto.toString(),
    );
    final conceptoCtrl = TextEditingController(text: prestamo.concepto);
    bool guardando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit_note, color: Colors.amber.shade900, size: 26),
              const SizedBox(width: 8),
              const Expanded(child: Text('Editar Vale / Préstamo')),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Beneficiario: ${prestamo.trabajadorNombre}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Monto del Vale (\$) *',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Ingresa el monto';
                      final num? m = num.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                      if (m == null || m <= 0) return 'Monto inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: conceptoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Concepto / Motivo *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Ingresa el concepto' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900),
              onPressed: guardando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => guardando = true);
                      try {
                        final nuevoMonto = double.parse(
                          montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                        );
                        await _firestoreService.editarPrestamo(
                          semanaId: semanaId,
                          prestamoId: prestamo.id,
                          nuevoMonto: nuevoMonto,
                          nuevoConcepto: conceptoCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Vale de ${prestamo.trabajadorNombre} actualizado a ${_cop.format(nuevoMonto)}.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => guardando = false);
                      }
                    },
              child: guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Guardar Cambios', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // CONFIRMAR ELIMINACIÓN DE PRÉSTAMO / VALE
  // =========================================================================
  void _confirmarEliminarPrestamo(
    BuildContext context,
    String semanaId,
    PrestamoModel prestamo,
  ) {
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
          '¿Deseas eliminar el vale de ${_cop.format(prestamo.monto)} registrado por "${prestamo.concepto}" a ${prestamo.trabajadorNombre}?\n\n'
          'El saldo a pagar del trabajador y los gastos se recalcularán automáticamente.',
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
                await _firestoreService.eliminarPrestamo(
                  semanaId: semanaId,
                  prestamoId: prestamo.id,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Vale de ${_cop.format(prestamo.monto)} eliminado y saldo recalculado.',
                      ),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar vale: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar Vale'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // GESTIÓN DE BONIFICACIONES E INCENTIVOS DISCRIMINADOS
  // =========================================================================
  void _mostrarModalGestionBonos({
    required BuildContext context,
    required String semanaId,
    required String trabajadorId,
    required String trabajadorNombre,
    required bool semanaCerrada,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return Consumer<ProyectoProvider>(
          builder: (context, proyecto, _) {
            final semana = proyecto.semanas.firstWhere(
              (s) => s.id == semanaId,
              orElse: () => proyecto.semanaActiva ?? SemanaModel(
                id: '',
                numeroSemana: '',
                fechaInicio: DateTime.now(),
                fechaFin: DateTime.now(),
                cerrada: false,
                registros: [],
              ),
            );

            // Obtener bonos del trabajador desde registros o semana
            final registro = semana.registros.where((r) => r.trabajadorId == trabajadorId).firstOrNull;
            final List<BonoItemModel> bonos = registro?.bonos.isNotEmpty == true
                ? registro!.bonos
                : semana.bonos.where((b) => b.trabajadorId == trabajadorId).toList();

            final totalBonos = bonos.isNotEmpty
                ? bonos.fold<double>(0.0, (acc, b) => acc + b.monto)
                : (registro?.bonificaciones ?? 0.0);

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // ENCABEZADO
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border(bottom: BorderSide(color: Colors.purple.shade100)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.purple.shade100,
                          child: Icon(Icons.card_giftcard, color: Colors.purple.shade800),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BONIFICACIONES E INCENTIVOS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                trabajadorNombre,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomSheetCtx),
                        ),
                      ],
                    ),
                  ),

                  // AVISO DE REGLA DE NEGOCIO (OBLIGACIÓN / DEVENGADO)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Este registro representa la generación de la obligación/incentivo (incrementa el total devengado en nómina), NO un pago en efectivo directo. Se liquida formalmente en el pago de nómina o mediante abonos.',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // RESUMEN ACUMULADO
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${bonos.length} bono${bonos.length == 1 ? '' : 's'} discriminado${bonos.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Text(
                            'Total: ${_cop.format(totalBonos)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // LISTA DISCRIMINADA DE BONOS
                  Expanded(
                    child: bonos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.card_giftcard, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                const Text(
                                  'No hay bonos registrados para este trabajador.',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                if (totalBonos > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Existe un saldo legacy no discriminado de ${_cop.format(totalBonos)}',
                                    style: TextStyle(fontSize: 12, color: Colors.purple.shade700),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: bonos.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final bono = bonos[idx];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.purple.shade100),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.stars, size: 18, color: Colors.purple.shade800),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bono.concepto,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatoFecha.format(bono.fechaRegistro),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _cop.format(bono.monto),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.purple.shade800,
                                      ),
                                    ),
                                    if (!semanaCerrada) ...[
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0D47A1)),
                                        tooltip: 'Editar Bono',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _mostrarDialogoCrearEditarBono(
                                          context: context,
                                          semanaId: semanaId,
                                          trabajadorId: trabajadorId,
                                          trabajadorNombre: trabajadorNombre,
                                          bonoAEditar: bono,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        tooltip: 'Eliminar Bono',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _confirmarEliminarBono(
                                          context: context,
                                          semanaId: semanaId,
                                          bono: bono,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // BOTÓN GENERAR NUEVO BONO
                  if (!semanaCerrada)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          label: const Text(
                            'Generar Nuevo Bono / Incentivo',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _mostrarDialogoCrearEditarBono(
                            context: context,
                            semanaId: semanaId,
                            trabajadorId: trabajadorId,
                            trabajadorNombre: trabajadorNombre,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoCrearEditarBono({
    required BuildContext context,
    required String semanaId,
    required String trabajadorId,
    required String trabajadorNombre,
    BonoItemModel? bonoAEditar,
  }) {
    final montoCtrl = TextEditingController(
      text: bonoAEditar != null ? bonoAEditar.monto.toInt().toString() : '',
    );
    final conceptoCtrl = TextEditingController(
      text: bonoAEditar != null ? bonoAEditar.concepto : '',
    );
    DateTime fechaBono = bonoAEditar != null ? bonoAEditar.fechaRegistro : DateTime.now();

    final sugerencias = [
      'Rendimiento extra en obra',
      'Apoyo fin de semana',
      'Calidad en empalmes y montajes',
      'Cumplimiento de meta semanal',
      'Puntualidad y compromiso',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.purple.shade700, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bonoAEditar != null ? 'Editar Bono' : 'Generar Nuevo Bono',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beneficiario: $trabajadorNombre',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: bonoAEditar == null,
                  decoration: const InputDecoration(
                    labelText: 'Monto del Bono (\$)',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: conceptoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Concepto o Motivo del Bono',
                    border: OutlineInputBorder(),
                    hintText: 'Ej. Rendimiento extra en Lote 2',
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Sugerencias rápidas:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: sugerencias.map((sug) {
                    return ActionChip(
                      label: Text(sug, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      onPressed: () => setDialogState(() => conceptoCtrl.text = sug),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fechaBono,
                      firstDate: DateTime(2025, 1, 1),
                      lastDate: DateTime(2030, 12, 31),
                    );
                    if (picked != null) {
                      setDialogState(() => fechaBono = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.purple),
                            const SizedBox(width: 8),
                            Text('Fecha: ${_formatoFecha.format(fechaBono)}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const Icon(Icons.edit, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
              onPressed: () async {
                final monto = double.tryParse(montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
                if (monto <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor ingresa un monto válido mayor a 0.')),
                  );
                  return;
                }
                final concepto = conceptoCtrl.text.trim().isNotEmpty
                    ? conceptoCtrl.text.trim()
                    : 'Incentivo / Bonificación Especial';

                if (bonoAEditar != null) {
                  final bonoModificado = bonoAEditar.copyWith(
                    monto: monto,
                    concepto: concepto,
                    fechaRegistro: fechaBono,
                  );
                  await _firestoreService.editarBonoTrabajador(
                    semanaId: semanaId,
                    bonoModificado: bonoModificado,
                  );
                } else {
                  final nuevoBono = BonoItemModel(
                    id: '',
                    trabajadorId: trabajadorId,
                    trabajadorNombre: trabajadorNombre,
                    monto: monto,
                    concepto: concepto,
                    fechaRegistro: fechaBono,
                    semanaId: semanaId,
                  );
                  await _firestoreService.registrarBonoTrabajador(
                    semanaId: semanaId,
                    bono: nuevoBono,
                  );
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        bonoAEditar != null
                            ? 'Bono actualizado correctamente.'
                            : 'Bono de ${_cop.format(monto)} generado a $trabajadorNombre.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Guardar Bono', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarBono({
    required BuildContext context,
    required String semanaId,
    required BonoItemModel bono,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Bono'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el bono de ${_cop.format(bono.monto)} (${bono.concepto})?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.eliminarBonoTrabajador(
                semanaId: semanaId,
                bonoId: bono.id,
                trabajadorId: bono.trabajadorId,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bono eliminado.'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // EDICIÓN Y ELIMINACIÓN DE SEMANAS
  // =========================================================================
  void _mostrarDialogoEditarSemana(
    BuildContext context,
    ProyectoProvider proyecto,
    SemanaModel semana,
  ) {
    int numSemana = 1;
    final match = RegExp(r'\d+').firstMatch(semana.numeroSemana);
    if (match != null) {
      numSemana = int.tryParse(match.group(0) ?? '1') ?? 1;
    }

    final numeroCtrl = TextEditingController(text: numSemana.toString());
    final nombreCtrl = TextEditingController(text: semana.numeroSemana);
    DateTime fechaInicio = semana.fechaInicio;
    DateTime fechaFin = semana.fechaFin;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_calendar_outlined, color: Color(0xFF0D47A1)),
              SizedBox(width: 8),
              Expanded(child: Text('Editar Semana de Nómina', style: TextStyle(fontSize: 16))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Corrige las fechas de inicio, fin y el identificador de la semana.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: numeroCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de Semana',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                  onChanged: (val) {
                    final n = int.tryParse(val) ?? numSemana;
                    setDialogState(() {
                      numSemana = n;
                      nombreCtrl.text =
                          'Semana $n - ${DateFormat('MMMM yyyy', 'es').format(fechaInicio)}';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Identificador / Título de la Semana',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Rango de Fechas:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final rango = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024, 1, 1),
                      lastDate: DateTime(2030, 12, 31),
                      initialDateRange: DateTimeRange(start: fechaInicio, end: fechaFin),
                    );
                    if (rango != null) {
                      setDialogState(() {
                        fechaInicio = rango.start;
                        fechaFin = rango.end;
                        nombreCtrl.text =
                            'Semana $numSemana - ${DateFormat('MMMM yyyy', 'es').format(fechaInicio)}';
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.date_range, color: Color(0xFF0D47A1), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatoFecha.format(fechaInicio)} — ${_formatoFecha.format(fechaFin)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
              onPressed: () async {
                final n = int.tryParse(numeroCtrl.text.trim()) ?? numSemana;
                await _firestoreService.editarSemana(
                  semanaId: semana.id,
                  nuevaFechaInicio: fechaInicio,
                  nuevaFechaFin: fechaFin,
                  nuevoNumero: n,
                  nuevoNombre: nombreCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Semana modificada con éxito.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Guardar Cambios', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarSemana(
    BuildContext context,
    ProyectoProvider proyecto,
    SemanaModel semana,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => PinModalWidget(
        titulo: 'Eliminar Semana con PIN',
        mensaje:
            'Ingresa el PIN de seguridad de 4 dígitos para autorizar la eliminación definitiva de "${semana.numeroSemana}":',
        onPinConfirmado: (pinIngresado) async {
          if (pinIngresado != proyecto.configuracion.pinSeguridad) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PIN de seguridad incorrecto.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          // Consultar datos vinculados
          final vinculos = await _firestoreService.contarVinculosSemana(semana.id);
          final int totalVinculos = vinculos['total'] ?? 0;

          if (!context.mounted) return;

          showDialog(
            context: context,
            builder: (confirmCtx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Confirmar Eliminación'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Estás seguro de que deseas eliminar permanentemente la "${semana.numeroSemana}"?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (totalVinculos > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Esta semana tiene registros vinculados:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange),
                          ),
                          const SizedBox(height: 4),
                          Text('• ${vinculos['viviendas']} viviendas selladas', style: const TextStyle(fontSize: 12)),
                          Text('• ${vinculos['asistencias']} asistencias de ayudantes', style: const TextStyle(fontSize: 12)),
                          Text('• ${vinculos['gastos']} gastos/abonos registrados', style: const TextStyle(fontSize: 12)),
                          Text('• ${vinculos['prestamos']} vales/adelantos', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 6),
                          const Text(
                            'Al proceder, las viviendas serán desvinculadas automáticamente (quedarán disponibles para otra semana) y los datos huérfanos se limpiarán.',
                            style: TextStyle(fontSize: 11, color: Colors.brown),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Esta semana está vacía y no tiene registros vinculados. La eliminación es segura.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(confirmCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    Navigator.pop(confirmCtx);
                    try {
                      await _firestoreService.eliminarSemana(semana.id, desvincularAsociados: true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Semana "${semana.numeroSemana}" eliminada con éxito.'),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al eliminar la semana: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Eliminar Definitivamente', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // MODAL ABONAR PAGO
  // =========================================================================
  void _mostrarDialogoAbonarPago(
      BuildContext context, String semanaId, RegistroNominaItem item,
      {SemanaModel? semana}) {
    final montoCtrl = TextEditingController(
      text: item.saldoPendiente > 0 ? item.saldoPendiente.toInt().toString() : '',
    );
    final conceptoCtrl = TextEditingController(text: 'Abono de nómina');
    String metodoPago = 'Efectivo';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateModal) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.attach_money, color: Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Abonar Pago: ${item.trabajadorNombre}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Saldo pendiente actual:', style: TextStyle(fontSize: 12)),
                      Text(
                        _cop.format(item.saldoPendiente),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Monto a pagar (\$) *',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: conceptoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observación / Justificación',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: metodoPago,
                  decoration: const InputDecoration(
                    labelText: 'Método de Pago',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'Nequi / Daviplata', child: Text('Nequi / Daviplata')),
                    DropdownMenuItem(value: 'Bancolombia', child: Text('Bancolombia')),
                    DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')),
                    DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                  ],
                  onChanged: (val) {
                    if (val != null) setStateModal(() => metodoPago = val);
                  },
                ),
                if (semana != null && (item.pagos.isNotEmpty || item.totalPagado > 0)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.history, size: 16, color: Colors.green),
                      label: Text(
                        'Ver historial de abonos (${item.pagos.isNotEmpty ? item.pagos.length : 1})',
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _mostrarModalHistorialAbonos(context, semana, item);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
              onPressed: () async {
                final monto = double.tryParse(montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                if (monto != null && monto > 0) {
                  await _firestoreService.registrarAbonoTrabajador(
                    semanaId: semanaId,
                    trabajadorId: item.trabajadorId,
                    monto: monto,
                    concepto: conceptoCtrl.text.trim().isNotEmpty ? conceptoCtrl.text.trim() : null,
                    metodoPago: metodoPago,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Pago de ${_cop.format(monto)} registrado y saldo actualizado.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Registrar Pago', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HISTORIAL Y GESTIÓN DE ABONOS / PAGOS PARCIALES
  // =========================================================================
  void _mostrarModalHistorialAbonos(
    BuildContext context,
    SemanaModel semana,
    RegistroNominaItem item,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<ProyectoProvider>(
          builder: (ctxConsumer, prov, _) {
            final semFresco =
                prov.semanas.firstWhere((s) => s.id == semana.id, orElse: () => semana);
            final itemFresco = semFresco.registros.firstWhere(
              (r) => r.trabajadorId == item.trabajadorId,
              orElse: () => item,
            );

            final List<PagoItemModel> abonos = itemFresco.pagos.isNotEmpty
                ? itemFresco.pagos
                : (itemFresco.totalPagado > 0
                    ? [
                        PagoItemModel(
                          id: 'legacy_${itemFresco.trabajadorId}',
                          trabajadorId: itemFresco.trabajadorId,
                          trabajadorNombre: itemFresco.trabajadorNombre,
                          monto: itemFresco.totalPagado,
                          fecha: semFresco.fechaInicio,
                          observacion: 'Abono acumulado previo',
                          metodoPago: 'Efectivo',
                          semanaId: semFresco.id,
                        )
                      ]
                    : []);

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctxScroll, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.history, color: Color(0xFF0D47A1), size: 20),
                                    SizedBox(width: 6),
                                    Text(
                                      'Historial de Abonos / Pagos',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                                Text(
                                  itemFresco.trabajadorNombre,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _miniMetricaModal(
                                'Devengado', _cop.format(itemFresco.totalGenerado), Colors.black87),
                            _miniMetricaModal(
                                'Total Pagado', _cop.format(itemFresco.totalPagado), Colors.green.shade800),
                            _miniMetricaModal(
                              'Saldo Pendiente',
                              _cop.format(itemFresco.saldoPendiente),
                              itemFresco.saldoPendiente > 0
                                  ? const Color(0xFF0D47A1)
                                  : Colors.green.shade700,
                            ),
                          ],
                        ),
                      ),
                      if (semFresco.cerrada) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline, size: 16, color: Colors.amber),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Semana cerrada. Se solicitará PIN de seguridad para editar o eliminar abonos.',
                                  style: TextStyle(fontSize: 11, color: Colors.brown),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Expanded(
                        child: abonos.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.receipt_outlined, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    const Text('No hay abonos registrados para este trabajador.'),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: abonos.length,
                                itemBuilder: (ctxList, idx) {
                                  final abono = abonos[idx];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.green.shade50,
                                        child: Text(
                                          '#${idx + 1}',
                                          style: TextStyle(
                                            color: Colors.green.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _cop.format(abono.monto),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.green.shade900,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              abono.metodoPago,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          Text(
                                            abono.observacion.isNotEmpty
                                                ? abono.observacion
                                                : 'Abono / Pago parcial',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          Text(
                                            _formatoFechaHora.format(abono.fecha),
                                            style: TextStyle(
                                                fontSize: 10, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined,
                                                size: 20, color: Color(0xFF0D47A1)),
                                            tooltip: 'Editar abono',
                                            onPressed: () async {
                                              final autorizado =
                                                  await _validarPermisoModificacion(
                                                context,
                                                semFresco,
                                                prov,
                                              );
                                              if (autorizado && context.mounted) {
                                                _mostrarDialogoEditarAbono(
                                                  context,
                                                  semFresco,
                                                  itemFresco,
                                                  abono,
                                                );
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline,
                                                size: 20, color: Colors.red),
                                            tooltip: 'Eliminar abono',
                                            onPressed: () async {
                                              final autorizado =
                                                  await _validarPermisoModificacion(
                                                context,
                                                semFresco,
                                                prov,
                                              );
                                              if (autorizado && context.mounted) {
                                                await _confirmarEliminarAbono(
                                                  context,
                                                  semFresco,
                                                  itemFresco,
                                                  abono,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Registrar Nuevo Abono',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: semFresco.cerrada
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _mostrarDialogoAbonarPago(
                                      context, semFresco.id, itemFresco,
                                      semana: semFresco);
                                },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoEditarAbono(
    BuildContext context,
    SemanaModel semana,
    RegistroNominaItem item,
    PagoItemModel abono,
  ) {
    final montoCtrl = TextEditingController(text: abono.monto.toInt().toString());
    final conceptoCtrl = TextEditingController(text: abono.observacion);
    String metodo = abono.metodoPago;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateModal) => AlertDialog(
          title: Text('Editar Abono: ${item.trabajadorNombre}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto corregido (\$) *',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: conceptoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Concepto / Observación',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: metodo,
                  decoration: const InputDecoration(
                    labelText: 'Método de Pago',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'Nequi / Daviplata', child: Text('Nequi / Daviplata')),
                    DropdownMenuItem(value: 'Bancolombia', child: Text('Bancolombia')),
                    DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')),
                    DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                  ],
                  onChanged: (val) {
                    if (val != null) setStateModal(() => metodo = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
              onPressed: () async {
                final nuevoMonto =
                    double.tryParse(montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                if (nuevoMonto != null && nuevoMonto > 0) {
                  await _firestoreService.editarAbonoTrabajador(
                    semanaId: semana.id,
                    abonoId: abono.id,
                    trabajadorId: item.trabajadorId,
                    nuevoMonto: nuevoMonto,
                    nuevoConcepto:
                        conceptoCtrl.text.trim().isNotEmpty ? conceptoCtrl.text.trim() : null,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Abono corregido a ${_cop.format(nuevoMonto)}. Saldo recalculado.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Guardar Cambios', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminarAbono(
    BuildContext context,
    SemanaModel semana,
    RegistroNominaItem item,
    PagoItemModel abono,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Abono'),
        content: Text(
          '¿Estás seguro de eliminar este abono de ${_cop.format(abono.monto)} realizado a ${item.trabajadorNombre}?\n\nEl saldo pendiente se recalculará inmediatamente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _firestoreService.eliminarAbonoTrabajador(
        semanaId: semana.id,
        abonoId: abono.id,
        trabajadorId: item.trabajadorId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Abono de ${_cop.format(abono.monto)} eliminado y saldo actualizado.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<bool> _validarPermisoModificacion(
    BuildContext context,
    SemanaModel semana,
    ProyectoProvider proyecto,
  ) async {
    if (!semana.cerrada) return true;

    final pinValido = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinModalWidget(
        onPinConfirmado: (pinIngresado) async {
          final ok = pinIngresado == proyecto.configuracion.pinSeguridad;
          Navigator.pop(ctx, ok);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN de seguridad incorrecto. Operación bloqueada.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
    return pinValido ?? false;
  }

  Widget _miniMetricaModal(String label, String valor, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(valor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // =========================================================================
  // MODAL EDITAR NÚMERO MANUAL
  // =========================================================================
  void _mostrarDialogoEditarNumeroManual(
      BuildContext context, String semanaId, RegistroNominaItem item, bool esAyudante) {
    final diasStr = item.diasOcasas % 1 == 0
        ? item.diasOcasas.toInt().toString()
        : item.diasOcasas.toString();
    final numCtrl = TextEditingController(text: diasStr);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esAyudante ? 'Corregir Días Trabajados' : 'Corregir Casas Terminadas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trabajador: ${item.trabajadorNombre}'),
            const SizedBox(height: 12),
            TextField(
              controller: numCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: esAyudante ? 'Número de Días (ej: 3.5)' : 'Número de Casas',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final valor = double.tryParse(numCtrl.text.trim().replaceAll(',', '.'));
              if (valor != null && valor >= 0) {
                await _firestoreService.actualizarDiasObrasManual(
                  semanaId: semanaId,
                  trabajadorId: item.trabajadorId,
                  nuevosDiasObras: valor,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CREACIÓN DE NUEVA SEMANA
  // =========================================================================
  void _mostrarDialogoCrearSemana(BuildContext context, ProyectoProvider proyecto) {
    final nombreCtrl = TextEditingController(
      text:
          'Semana ${proyecto.semanas.length + 1} - ${DateFormat('MMMM yyyy', 'es').format(DateTime.now())}',
    );
    DateTime fechaInicio = DateTime.now();
    DateTime fechaFin = DateTime.now().add(const Duration(days: 6));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Crear Nueva Semana de Nómina'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre o Identificador de Semana',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final elegida = await showDatePicker(
                          context: context,
                          initialDate: fechaInicio,
                          firstDate: DateTime(2025, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (elegida != null) {
                          setDialogState(() => fechaInicio = elegida);
                        }
                      },
                      child: Text('Inicio: ${_formatoFecha.format(fechaInicio)}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final elegida = await showDatePicker(
                          context: context,
                          initialDate: fechaFin,
                          firstDate: DateTime(2025, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (elegida != null) {
                          setDialogState(() => fechaFin = elegida);
                        }
                      },
                      child: Text('Fin: ${_formatoFecha.format(fechaFin)}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Se vincularán automáticamente ${proyecto.trabajadores.where((t) => t.activo).length} trabajadores activos.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
              onPressed: () async {
                final registros =
                    proyecto.trabajadores.where((t) => t.activo).map((t) {
                  return RegistroNominaItem(
                    trabajadorId: t.id,
                    trabajadorNombre: t.nombre,
                    rol: t.rol,
                    diasOcasas: 0,
                    tarifaUnitaria: t.esAyudante
                        ? proyecto.configuracion.tarifaAyudante
                        : proyecto.configuracion.tarifaTecnico,
                    totalAdelantos: 0.0,
                    totalPagado: 0.0,
                  );
                }).toList();

                final nuevaSemana = SemanaModel(
                  id: '',
                  numeroSemana: nombreCtrl.text.trim(),
                  fechaInicio: fechaInicio,
                  fechaFin: fechaFin,
                  cerrada: false,
                  registros: registros,
                );

                final idCreado =
                    await _firestoreService.crearOActualizarSemana(nuevaSemana);
                proyecto.seleccionarSemana(nuevaSemana.copyWith(id: idCreado));

                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nueva semana creada exitosamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child:
                  const Text('Crear Semana', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // CIERRE Y REAPERTURA DE SEMANA
  // =========================================================================
  void _confirmarCierreSemana(BuildContext context, ProyectoProvider proyecto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar Semana de Nómina?'),
        content: const Text(
          'Al cerrar la semana se congelan los registros. Para reabrirla se solicitará el PIN de seguridad.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await proyecto.cerrarSemanaActual();
            },
            child:
                const Text('Confirmar Cierre', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarModalReabrirSemana(
      BuildContext context, ProyectoProvider proyecto, String semanaId) {
    showDialog(
      context: context,
      builder: (ctx) => PinModalWidget(
        onPinConfirmado: (pinIngresado) async {
          final ok = await proyecto.reabrirSemana(semanaId, pinIngresado);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(ok ? 'Semana reabierta con éxito' : 'PIN de seguridad incorrecto'),
                backgroundColor: ok ? Colors.green : Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}