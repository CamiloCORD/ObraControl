import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/semana_model.dart';
import '../providers/auth_provider.dart';
import '../providers/proyecto_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_card_widget.dart';
import 'configuracion_screen.dart';
import 'contabilidad_screen.dart';
import 'nomina_screen.dart';
import 'viviendas_screen.dart';

enum FiltroPeriodoFinanciero {
  general,
  semanaActual,
  personalizado,
}

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _indiceActual = 0;
  DateTime _fechaAsistencia = DateTime.now();
  final NumberFormat _cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final FirestoreService _firestoreService = FirestoreService();

  FiltroPeriodoFinanciero _filtroPeriodo = FiltroPeriodoFinanciero.general;
  DateTimeRange? _rangoPersonalizado;

  Future<void> _seleccionarRangoFechas() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _rangoPersonalizado ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Seleccionar Periodo de Análisis',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0500D0),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _rangoPersonalizado = picked;
        _filtroPeriodo = FiltroPeriodoFinanciero.personalizado;
      });
    }
  }

  String _formatearFecha(DateTime fecha) {
    try {
      return DateFormat('EEEE, d MMMM yyyy', 'es').format(fecha);
    } catch (_) {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final proyecto = Provider.of<ProyectoProvider>(context);

    final List<Widget> pantallas = [
      _construirDashboard(auth, proyecto),
      const ViviendasScreen(),
      const NominaScreen(),
      const ContabilidadScreen(),
      const ConfiguracionScreen(),
    ];

    final int indiceSeguro = _indiceActual >= pantallas.length ? 0 : _indiceActual;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: (proyecto.configuracion.logoUrl != null && proyecto.configuracion.logoUrl!.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        proyecto.configuracion.logoUrl!,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.apartment_rounded,
                          size: 20,
                          color: Color(proyecto.configuracion.colorPrimario),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.apartment_rounded,
                      size: 20,
                      color: Color(proyecto.configuracion.colorPrimario),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    proyecto.configuracion.nombreEmpresa.trim().isNotEmpty
                        ? proyecto.configuracion.nombreEmpresa.trim()
                        : 'ObraControl',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                  Text(
                    auth.esDueno ? 'Modo Gerencial / Dueño' : 'Control Operativo / Admin',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => auth.cerrarSesion(),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: BoxDecoration(
                color: Color(proyecto.configuracion.colorPrimario),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: (proyecto.configuracion.logoUrl != null && proyecto.configuracion.logoUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              proyecto.configuracion.logoUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.engineering_rounded,
                                size: 32,
                                color: Color(proyecto.configuracion.colorPrimario),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.engineering_rounded,
                            size: 32,
                            color: Color(proyecto.configuracion.colorPrimario),
                          ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    proyecto.configuracion.nombreEmpresa.trim().isNotEmpty
                        ? proyecto.configuracion.nombreEmpresa.trim()
                        : 'ObraControl',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.usuario?.email ?? 'Sesión activa',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      auth.esDueno ? 'ROL: DUEÑO DE PROYECTO' : 'ROL: ADMINISTRADOR',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.dashboard_outlined, color: Color(0xFF0500D0)),
                    title: const Text('Inicio / Tablero'),
                    selected: indiceSeguro == 0,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _indiceActual = 0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.house_outlined, color: Color(0xFF0500D0)),
                    title: const Text('Viviendas por Lotes'),
                    selected: indiceSeguro == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _indiceActual = 1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline, color: Color(0xFF0500D0)),
                    title: const Text('Nómina Semanal'),
                    selected: indiceSeguro == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _indiceActual = 2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0500D0)),
                    title: const Text('Finanzas y Contabilidad'),
                    subtitle: const Text('P&L, Cartera CxC y Gastos', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    selected: indiceSeguro == 3,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _indiceActual = 3);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: Color(0xFF0500D0)),
                    title: const Text('Configuración General'),
                    selected: indiceSeguro == 4,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _indiceActual = 4);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      auth.cerrarSesion();
                    },
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'ObraControl v1.0.0\nPlataforma de Control de Obras e Ingeniería',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      body: pantallas[indiceSeguro],
      bottomNavigationBar: NavigationBar(
        selectedIndex: indiceSeguro,
        onDestinationSelected: (index) => setState(() => _indiceActual = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.house_outlined),
            selectedIcon: Icon(Icons.house),
            label: 'Viviendas',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Nómina',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Finanzas',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  Widget _construirDashboard(AuthProvider auth, ProyectoProvider proyecto) {
    final ayudantes = proyecto.trabajadores.where((t) => t.esAyudante && t.activo).toList();

    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AVANCE GLOBAL DEL PROYECTO (DESACOPLADO CON DESPLEGABLE POR LOTES)
            _buildCardAvanceFisico(proyecto),
            const SizedBox(height: 16),

            // TARJETAS DE OPERACIÓN
            Row(
              children: [
                Expanded(
                  child: CustomCardWidget(
                    titulo: 'Viviendas Listas',
                    valor: '${proyecto.totalViviendasTerminadas}',
                    icono: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomCardWidget(
                    titulo: 'Semana Actual',
                    valor: proyecto.semanaActiva?.numeroSemana ?? 'Sin Semana Activa',
                    icono: Icons.calendar_today_outlined,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // =========================================================================
            // MÓDULO: CONTROL DIARIO DE ASISTENCIA PARA AYUDANTES
            // =========================================================================
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.how_to_reg, color: Color(0xFF0D47A1), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Asistencia Diaria Ayudantes',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_calendar, color: Color(0xFF0D47A1)),
                          tooltip: 'Cambiar Fecha',
                          onPressed: () async {
                            final elegida = await showDatePicker(
                              context: context,
                              initialDate: _fechaAsistencia,
                              firstDate: DateTime(2025, 1, 1),
                              lastDate: DateTime(2030, 12, 31),
                            );
                            if (elegida != null && mounted) {
                              setState(() {
                                _fechaAsistencia = elegida;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final elegida = await showDatePicker(
                          context: context,
                          initialDate: _fechaAsistencia,
                          firstDate: DateTime(2025, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (elegida != null && mounted) {
                          setState(() {
                            _fechaAsistencia = elegida;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D47A1).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0D47A1).withAlpha(50)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.today, size: 16, color: Color(0xFF0D47A1)),
                            const SizedBox(width: 6),
                            Text(
                              _formatearFecha(_fechaAsistencia),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    if (ayudantes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'No hay ayudantes registrados aún.\nRegístralos en la pestaña de Nómina.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      StreamBuilder<List<AsistenciaModel>>(
                        stream: _firestoreService.streamAsistenciasPorFecha(_fechaAsistencia),
                        builder: (context, snapshot) {
                          final listaAsistencias = snapshot.data ?? [];
                          final mapaAsistencias = {
                            for (var a in listaAsistencias) a.ayudanteId: a.valorJornada
                          };

                          final double totalJornadas = ayudantes.fold(
                            0.0,
                            (acc, ay) => acc + (mapaAsistencias[ay.id] ?? 0.0),
                          );
                          final totalPresentes = ayudantes.where((ay) => (mapaAsistencias[ay.id] ?? 0.0) > 0).length;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Jornadas: ${totalJornadas % 1 == 0 ? totalJornadas.toInt() : totalJornadas} días ($totalPresentes de ${ayudantes.length} asistieron)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: totalJornadas > 0 ? const Color(0xFF047857) : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    proyecto.semanaActiva != null
                                        ? 'Semana: ${proyecto.semanaActiva!.numeroSemana}'
                                        : 'Sin semana activa',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: ayudantes.length,
                                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final ayudante = ayudantes[index];
                                  final double valor = mapaAsistencias[ayudante.id] ?? 0.0;

                                  Color avatarBg;
                                  Color avatarIconColor;
                                  IconData avatarIcon;
                                  if (valor >= 1.0) {
                                    avatarBg = const Color(0xFFDCFCE7);
                                    avatarIconColor = const Color(0xFF047857);
                                    avatarIcon = Icons.check_circle_rounded;
                                  } else if (valor == 0.5) {
                                    avatarBg = const Color(0xFFFEF3C7);
                                    avatarIconColor = Colors.amber.shade900;
                                    avatarIcon = Icons.timelapse_rounded;
                                  } else {
                                    avatarBg = Colors.grey.shade100;
                                    avatarIconColor = Colors.grey.shade500;
                                    avatarIcon = Icons.person_outline;
                                  }

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: avatarBg,
                                      child: Icon(avatarIcon, color: avatarIconColor, size: 20),
                                    ),
                                    title: Text(
                                      ayudante.nombre,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: valor > 0 ? const Color(0xFF0F172A) : Colors.grey.shade700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      ayudante.cedula.isNotEmpty
                                          ? 'C.C: ${ayudante.cedula} | ${ayudante.telefono}'
                                          : ayudante.telefono,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildBotonJornada(
                                          label: '1.0',
                                          sublabel: 'Día',
                                          selected: valor >= 1.0,
                                          color: const Color(0xFF047857),
                                          bg: const Color(0xFFDCFCE7),
                                          onTap: () async {
                                            final semanaId = proyecto.semanaActiva?.id ?? '';
                                            await _firestoreService.registrarAsistencia(
                                              ayudanteId: ayudante.id,
                                              nombre: ayudante.nombre,
                                              fecha: _fechaAsistencia,
                                              valorJornada: 1.0,
                                              semanaId: semanaId,
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        _buildBotonJornada(
                                          label: '0.5',
                                          sublabel: 'Medio',
                                          selected: valor == 0.5,
                                          color: Colors.amber.shade900,
                                          bg: const Color(0xFFFEF3C7),
                                          onTap: () async {
                                            final semanaId = proyecto.semanaActiva?.id ?? '';
                                            await _firestoreService.registrarAsistencia(
                                              ayudanteId: ayudante.id,
                                              nombre: ayudante.nombre,
                                              fecha: _fechaAsistencia,
                                              valorJornada: 0.5,
                                              semanaId: semanaId,
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        _buildBotonJornada(
                                          label: '0.0',
                                          sublabel: 'Falta',
                                          selected: valor <= 0.0,
                                          color: Colors.grey.shade600,
                                          bg: const Color(0xFFF1F5F9),
                                          onTap: () async {
                                            final semanaId = proyecto.semanaActiva?.id ?? '';
                                            await _firestoreService.registrarAsistencia(
                                              ayudanteId: ayudante.id,
                                              nombre: ayudante.nombre,
                                              fecha: _fechaAsistencia,
                                              valorJornada: 0.0,
                                              semanaId: semanaId,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECCIÓN FINANCIERA (RBAC: Solo para el Dueño con filtros por periodo)
            if (auth.esDueno) ...[
              _buildSeccionFinanciera(proyecto),
            ] else ...[
              // MENSAJE DE RESTRICCIÓN PARA ADMINISTRADORA
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.amber, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Las métricas de Ganancia Líquida y Utilidad Neta son de acceso exclusivo para la gerencia del proyecto.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBotonJornada({
    required String label,
    required String sublabel,
    required bool selected,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? bg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? color : Colors.grey.shade700,
              ),
            ),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? color : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAvanceFisico(ProyectoProvider proyecto) {
    final totalViviendas = proyecto.totalViviendas;
    final totalTerminadas = proyecto.totalViviendasTerminadas;
    final porcentajeGlobal = proyecto.porcentajeAvanceGlobal;
    final lotes = proyecto.lotes;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_rounded, color: Color(0xFF0500D0), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Avance Físico de Obra',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x1A0500D0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${porcentajeGlobal.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0500D0),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: totalViviendas > 0 ? (totalTerminadas / totalViviendas).clamp(0.0, 1.0) : 0.0,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0500D0)),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$totalTerminadas de $totalViviendas casas terminadas',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                    const Text(
                      'Ver lotes ▼',
                      style: TextStyle(fontSize: 11, color: Color(0xFF0500D0), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 20),
            if (lotes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No hay lotes registrados.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              )
            else
              ...lotes.map((lote) {
                final casasDelLote = proyecto.viviendas.where((v) =>
                    v.loteId == lote.id ||
                    (v.loteNombre.isNotEmpty && v.loteNombre.toLowerCase() == lote.nombre.toLowerCase())).toList();

                final totalCasasLote = casasDelLote.length > lote.cantidadCasas
                    ? casasDelLote.length
                    : (lote.cantidadCasas > 0 ? lote.cantidadCasas : casasDelLote.length);
                final terminadasLote = casasDelLote.where((v) => v.estaTerminada).length;
                final pctLote = totalCasasLote > 0 ? (terminadasLote / totalCasasLote) * 100 : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.holiday_village_outlined, size: 16, color: Color(0xFF0500D0)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    lote.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$terminadasLote/$totalCasasLote casas (${pctLote.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: pctLote >= 100 ? Colors.green.shade700 : const Color(0xFF0500D0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: totalCasasLote > 0 ? (terminadasLote / totalCasasLote).clamp(0.0, 1.0) : 0.0,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pctLote >= 100 ? Colors.green : const Color(0xFF0500D0),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionFinanciera(ProyectoProvider proyecto) {
    DateTime? fechaInicio;
    DateTime? fechaFin;
    String? semanaId;

    switch (_filtroPeriodo) {
      case FiltroPeriodoFinanciero.general:
        fechaInicio = null;
        fechaFin = null;
        semanaId = null;
        break;
      case FiltroPeriodoFinanciero.semanaActual:
        if (proyecto.semanaActiva != null) {
          semanaId = proyecto.semanaActiva!.id;
          fechaInicio = proyecto.semanaActiva!.fechaInicio;
          fechaFin = proyecto.semanaActiva!.fechaFin;
        } else {
          semanaId = '__sin_semana__';
        }
        break;
      case FiltroPeriodoFinanciero.personalizado:
        if (_rangoPersonalizado != null) {
          fechaInicio = _rangoPersonalizado!.start;
          fechaFin = _rangoPersonalizado!.end;
        }
        semanaId = null;
        break;
    }

    final double ingresos = proyecto.calcularIngresos(
      inicio: fechaInicio,
      fin: fechaFin,
      semanaId: semanaId,
    );
    final double gastosOperativos = proyecto.calcularGastosOperativos(
      inicio: fechaInicio,
      fin: fechaFin,
      semanaId: semanaId,
    );
    final double nominaPagada = proyecto.calcularNominaPagada(
      inicio: fechaInicio,
      fin: fechaFin,
      semanaId: semanaId,
    );
    final double gastosTotales = gastosOperativos + nominaPagada;
    final double gananciaBruta = ingresos - gastosTotales;
    final double montoAhorro = gananciaBruta > 0
        ? gananciaBruta * (proyecto.configuracion.porcentajeAhorro / 100)
        : 0.0;
    final double balanceNeto = gananciaBruta - montoAhorro;

    String descripcionPeriodo = '';
    switch (_filtroPeriodo) {
      case FiltroPeriodoFinanciero.general:
        descripcionPeriodo = 'Acumulado histórico general de la obra';
        break;
      case FiltroPeriodoFinanciero.semanaActual:
        if (proyecto.semanaActiva != null) {
          final s = proyecto.semanaActiva!;
          final fIni = DateFormat('d MMM', 'es').format(s.fechaInicio);
          final fFin = DateFormat('d MMM yyyy', 'es').format(s.fechaFin);
          descripcionPeriodo = '${s.numeroSemana} ($fIni - $fFin)';
        } else {
          descripcionPeriodo = 'No hay semana activa registrada';
        }
        break;
      case FiltroPeriodoFinanciero.personalizado:
        if (_rangoPersonalizado != null) {
          final fIni = DateFormat('d/MM/yyyy').format(_rangoPersonalizado!.start);
          final fFin = DateFormat('d/MM/yyyy').format(_rangoPersonalizado!.end);
          descripcionPeriodo = 'Del $fIni al $fFin';
        } else {
          descripcionPeriodo = 'Selecciona un rango de fechas';
        }
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Balances Financieros (Modo Gerencial)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                setState(() => _indiceActual = 3);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ingresos y Rendimiento',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0500D0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF0500D0)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // SELECTOR DE PERIODO
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 16, color: Color(0xFF0500D0)),
                    const SizedBox(width: 6),
                    const Text(
                      'Filtrar periodo:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        descripcionPeriodo,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('General (Histórico)'),
                        selected: _filtroPeriodo == FiltroPeriodoFinanciero.general,
                        selectedColor: const Color(0xFF0500D0),
                        labelStyle: TextStyle(
                          color: _filtroPeriodo == FiltroPeriodoFinanciero.general ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _filtroPeriodo = FiltroPeriodoFinanciero.general);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Semana Actual'),
                        selected: _filtroPeriodo == FiltroPeriodoFinanciero.semanaActual,
                        selectedColor: const Color(0xFF0500D0),
                        labelStyle: TextStyle(
                          color: _filtroPeriodo == FiltroPeriodoFinanciero.semanaActual ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _filtroPeriodo = FiltroPeriodoFinanciero.semanaActual);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: Icon(
                          Icons.date_range,
                          size: 15,
                          color: _filtroPeriodo == FiltroPeriodoFinanciero.personalizado ? Colors.white : const Color(0xFF0500D0),
                        ),
                        label: Text(
                          _filtroPeriodo == FiltroPeriodoFinanciero.personalizado && _rangoPersonalizado != null
                              ? '${DateFormat('d/MM').format(_rangoPersonalizado!.start)} - ${DateFormat('d/MM').format(_rangoPersonalizado!.end)}'
                              : 'Personalizado',
                        ),
                        selected: _filtroPeriodo == FiltroPeriodoFinanciero.personalizado,
                        selectedColor: const Color(0xFF0500D0),
                        labelStyle: TextStyle(
                          color: _filtroPeriodo == FiltroPeriodoFinanciero.personalizado ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (selected) async {
                          await _seleccionarRangoFechas();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // TARJETAS MÉTRICAS FINANCIERAS
        CustomCardWidget(
          titulo: 'Ingresos Totales (Cliente)',
          valor: _cop.format(ingresos),
          icono: Icons.trending_up,
          color: Colors.blue,
          subtitulo: 'Según tarifa cliente y viviendas en el periodo',
        ),
        CustomCardWidget(
          titulo: 'Gastos Operativos',
          valor: _cop.format(gastosOperativos),
          icono: Icons.shopping_cart_outlined,
          color: Colors.orange.shade800,
          subtitulo: 'Materiales, combustible y provisiones operativas',
        ),
        CustomCardWidget(
          titulo: 'Nómina Pagada (Mano de Obra)',
          valor: _cop.format(nominaPagada),
          icono: Icons.people_outline,
          color: Colors.deepPurple,
          subtitulo: 'Liquidaciones de técnicos, ayudantes y adelantos',
        ),
        CustomCardWidget(
          titulo: 'Gastos Totales (Operativos + Nómina)',
          valor: _cop.format(gastosTotales),
          icono: Icons.trending_down,
          color: Colors.red,
        ),
        CustomCardWidget(
          titulo: 'Ganancia Bruta',
          valor: _cop.format(gananciaBruta),
          icono: Icons.account_balance_wallet_outlined,
          color: Colors.indigo,
          subtitulo: 'Ingresos menos gastos totales',
        ),
        CustomCardWidget(
          titulo: 'Fondo de Ahorro Proyectado (${proyecto.configuracion.porcentajeAhorro}%)',
          valor: _cop.format(montoAhorro),
          icono: Icons.savings_outlined,
          color: Colors.teal,
        ),
        CustomCardWidget(
          titulo: 'Balance Neto / Utilidad Disponible',
          valor: _cop.format(balanceNeto),
          icono: Icons.monetization_on,
          color: Colors.green.shade800,
          subtitulo: 'Ganancia bruta descontando fondo de ahorro',
        ),
      ],
    );
  }
}