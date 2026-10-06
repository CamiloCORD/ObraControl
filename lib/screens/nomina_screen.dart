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
  final FirestoreService _firestoreService = FirestoreService();

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
    final diasTrabajados = registro?.diasOcasas ?? 0;
    final tarifaDiaria = registro?.tarifaUnitaria ?? proyecto.configuracion.tarifaAyudante;
    final totalGenerado = diasTrabajados * tarifaDiaria;
    final totalAdelantos = registro?.totalAdelantos ?? 0.0;
    final totalPagado = registro?.totalPagado ?? 0.0;
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
                    onPressed: diasTrabajados > 0
                        ? () async {
                            await _firestoreService.actualizarDiasObrasManual(
                              semanaId: semana.id,
                              trabajadorId: ayudante.id,
                              nuevosDiasObras: diasTrabajados - 1,
                            );
                          }
                        : null,
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Text(
                    '$diasTrabajados',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade800),
                  ),
                ),
                if (registro != null && !semana.cerrada)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: Colors.teal.shade700, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await _firestoreService.actualizarDiasObrasManual(
                        semanaId: semana.id,
                        trabajadorId: ayudante.id,
                        nuevosDiasObras: diasTrabajados + 1,
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
                  _miniMetrica('Generado', _cop.format(totalGenerado), Colors.black87),
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
                if (registro != null && !semana.cerrada) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.teal.shade700,
                      side: BorderSide(color: Colors.teal.shade300),
                    ),
                    icon: const Icon(Icons.today_outlined, size: 16),
                    label: const Text('+ Registrar Día'),
                    onPressed: () async {
                      await _firestoreService.actualizarDiasObrasManual(
                        semanaId: semana.id,
                        trabajadorId: ayudante.id,
                        nuevosDiasObras: diasTrabajados + 1,
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
                            etiqueta = '✓ ${fmt.format(asist.fecha)}';
                          } catch (_) {
                            etiqueta = '✓ ${asist.fecha.day}/${asist.fecha.month}';
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.teal.shade300),
                            ),
                            child: Text(
                              etiqueta,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
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
          body: ListView.builder(
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

    return StreamBuilder<List<ViviendaModel>>(
      stream: _firestoreService.streamCasasTerminadasTecnicoEnSemana(
        tecnicoId: tecnico.id,
        fechaInicio: semana.fechaInicio,
        fechaFin: semana.fechaFin,
      ),
      builder: (context, casasSnapshot) {
        final casasTerminadas = casasSnapshot.data ?? [];
        final cantidadCasas = casasTerminadas.length;
        final totalGeneradoBruto = cantidadCasas * tarifaPorCasa;
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
                      Text(
                        'Total Bruto: ${_cop.format(totalGeneradoBruto)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
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
                      _miniMetrica('Bruto', _cop.format(totalGeneradoBruto), Colors.blue.shade800),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
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
                    const SizedBox(width: 6),
                    if (registro != null && !semana.cerrada)
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
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.green, size: 22),
                      tooltip: 'Comprobante PDF',
                      onPressed: registro == null
                          ? null
                          : () {
                              final regConCasas = registro.copyWith(diasOcasas: cantidadCasas);
                              final periodo =
                                  '${_formatoFecha.format(semana.fechaInicio)} – ${_formatoFecha.format(semana.fechaFin)}';
                              final vales = registro.prestamos.isNotEmpty
                                  ? registro.prestamos
                                  : semana.prestamos.where((p) => p.trabajadorId == tecnico.id).toList();

                              PdfService.generarYCompartirComprobanteTecnico(
                                trabajador: tecnico,
                                registro: regConCasas,
                                nombreSemana: semana.numeroSemana,
                                periodoSemana: periodo,
                                viviendasCompletadas: casasTerminadas,
                                vales: vales,
                              );
                            },
                    ),
                  ],
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
                          casa.id,
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
                        tooltip: 'Restar',
                        onPressed: item.diasOcasas > 0
                            ? () async {
                                await _firestoreService.actualizarDiasObrasManual(
                                  semanaId: semana.id,
                                  trabajadorId: item.trabajadorId,
                                  nuevosDiasObras: item.diasOcasas - 1,
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
                          '${item.diasOcasas}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    if (!semana.cerrada)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Sumar',
                        onPressed: () async {
                          await _firestoreService.actualizarDiasObrasManual(
                            semanaId: semana.id,
                            trabajadorId: item.trabajadorId,
                            nuevosDiasObras: item.diasOcasas + 1,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Generado: ${_cop.format(item.totalGenerado)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  Text('(-) Vales: ${_cop.format(item.totalAdelantos)}',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900)),
                  Text('(-) Pagado: ${_cop.format(item.totalPagado)}',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade800)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0D47A1),
                  ),
                  icon: const Icon(Icons.attach_money, size: 16),
                  label: const Text('Abonar'),
                  onPressed: semana.cerrada
                      ? null
                      : () => _mostrarDialogoAbonarPago(context, semana.id, item),
                ),
                const SizedBox(width: 6),
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
                            casasTecnico.isNotEmpty ? casasTecnico.length : item.diasOcasas,
                      );

                      PdfService.generarYCompartirComprobanteTecnico(
                        trabajador: trabajador,
                        registro: regConCasas,
                        nombreSemana: semana.numeroSemana,
                        periodoSemana: periodo,
                        viviendasCompletadas: casasTecnico,
                        vales: vales,
                      );
                    } else {
                      PdfService.generarYCompartirComprobanteAyudante(
                        trabajador: trabajador,
                        registro: item,
                        nombreSemana: semana.numeroSemana,
                        periodoSemana: periodo,
                        vales: vales,
                      );
                    }
                  },
                ),
              ],
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
  // MODAL ABONAR PAGO
  // =========================================================================
  void _mostrarDialogoAbonarPago(
      BuildContext context, String semanaId, RegistroNominaItem item) {
    final montoCtrl = TextEditingController(
      text: item.saldoPendiente > 0 ? item.saldoPendiente.toInt().toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Abonar Pago: ${item.trabajadorNombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo pendiente actual: ${_cop.format(item.saldoPendiente)}'),
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
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
            onPressed: () async {
              final monto = double.tryParse(
                  montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
              if (monto != null && monto > 0) {
                await _firestoreService.registrarAbonoPago(
                  semanaId: semanaId,
                  trabajadorId: item.trabajadorId,
                  montoAbono: monto,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Pago de ${_cop.format(monto)} abonado y sincronizado.'),
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
    );
  }

  // =========================================================================
  // MODAL EDITAR NÚMERO MANUAL
  // =========================================================================
  void _mostrarDialogoEditarNumeroManual(
      BuildContext context, String semanaId, RegistroNominaItem item, bool esAyudante) {
    final numCtrl = TextEditingController(text: item.diasOcasas.toString());

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
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: esAyudante ? 'Número de Días' : 'Número de Casas',
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
              final valor = int.tryParse(numCtrl.text.trim());
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