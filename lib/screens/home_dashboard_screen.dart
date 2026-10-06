import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/semana_model.dart';
import '../providers/auth_provider.dart';
import '../providers/proyecto_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_card_widget.dart';
import 'configuracion_screen.dart';
import 'gastos_screen.dart';
import 'nomina_screen.dart';
import 'viviendas_screen.dart';

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
      const GastosScreen(),
      const ConfiguracionScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ELECTRO - GAS',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
              decoration: const BoxDecoration(
                color: Color(0xFF0500D0),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ELECTRO - GAS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
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
                    selected: _indiceActual == 0,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _indiceActual = 0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.house_outlined, color: Color(0xFF0500D0)),
                    title: const Text('Viviendas por Lotes'),
                    selected: _indiceActual == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _indiceActual = 1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline, color: Color(0xFF0500D0)),
                    title: const Text('Nómina Semanal'),
                    selected: _indiceActual == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _indiceActual = 2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.attach_money_outlined, color: Color(0xFF0500D0)),
                    title: const Text('Control de Gastos'),
                    selected: _indiceActual == 3,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _indiceActual = 3);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: Color(0xFF0500D0)),
                    title: const Text('Configuración General'),
                    selected: _indiceActual == 4,
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
                'ELECTRO - GAS v2.3.0\nSistema de Control de Obras',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      body: pantallas[_indiceActual],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (index) => setState(() => _indiceActual = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.house_outlined), label: 'Viviendas'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Nómina'),
          NavigationDestination(icon: Icon(Icons.attach_money_outlined), label: 'Gastos'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }

  Widget _construirDashboard(AuthProvider auth, ProyectoProvider proyecto) {
    final progreso = proyecto.porcentajeAvanceGlobal;
    final ayudantes = proyecto.trabajadores.where((t) => t.esAyudante && t.activo).toList();

    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AVANCE GLOBAL DEL PROYECTO
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
                        const Text(
                          'Avance Global del Proyecto',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '${progreso.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progreso > 0 ? progreso / 100 : 0.0,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Terminadas: ${proyecto.totalViviendasTerminadas} de ${proyecto.metaGlobalViviendas} Viviendas programadas',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
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
                            for (var a in listaAsistencias) a.ayudanteId: a.asistio
                          };

                          final totalPresentes = ayudantes.where((ay) => mapaAsistencias[ay.id] == true).length;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Presentes: $totalPresentes de ${ayudantes.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: totalPresentes > 0 ? Colors.green.shade700 : Colors.grey,
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
                                  final asistio = mapaAsistencias[ayudante.id] ?? false;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: asistio ? Colors.green.shade100 : Colors.grey.shade200,
                                      child: Icon(
                                        asistio ? Icons.check : Icons.person_outline,
                                        color: asistio ? Colors.green.shade800 : Colors.grey.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      ayudante.nombre,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: asistio ? Colors.black87 : Colors.grey.shade700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      ayudante.cedula.isNotEmpty
                                          ? 'C.C: ${ayudante.cedula} | ${ayudante.telefono}'
                                          : ayudante.telefono,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    trailing: Switch.adaptive(
                                      value: asistio,
                                      activeTrackColor: Colors.green,
                                      onChanged: (nuevoValor) async {
                                        final semanaId = proyecto.semanaActiva?.id ?? '';
                                        await _firestoreService.registrarAsistencia(
                                          ayudanteId: ayudante.id,
                                          nombre: ayudante.nombre,
                                          fecha: _fechaAsistencia,
                                          asistio: nuevoValor,
                                          semanaId: semanaId,
                                        );
                                      },
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

            // SECCIÓN FINANCIERA (RBAC: Solo para el Dueño)
            if (auth.esDueno) ...[
              const Text(
                'Balance Financiero (Exclusivo Dueño)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
              ),
              const SizedBox(height: 8),
              CustomCardWidget(
                titulo: 'Ingresos Totales (Cliente)',
                valor: _cop.format(proyecto.ingresosTotales),
                icono: Icons.trending_up,
                color: Colors.blue,
              ),
              CustomCardWidget(
                titulo: 'Gastos Totales Semana',
                valor: _cop.format(proyecto.totalGastosSemanaActual),
                icono: Icons.trending_down,
                color: Colors.red,
              ),
              CustomCardWidget(
                titulo: 'Ganancia Bruta',
                valor: _cop.format(proyecto.gananciaBruta),
                icono: Icons.account_balance_wallet_outlined,
                color: Colors.indigo,
              ),
              CustomCardWidget(
                titulo: 'Fondo de Ahorro Proyectado (${proyecto.configuracion.porcentajeAhorro}%)',
                valor: _cop.format(proyecto.montoAhorro),
                icono: Icons.savings_outlined,
                color: Colors.teal,
              ),
              CustomCardWidget(
                titulo: 'Utilidad Neta Disponible',
                valor: _cop.format(proyecto.utilidadNeta),
                icono: Icons.monetization_on,
                color: Colors.green.shade800,
                subtitulo: 'Descontando gastos operativos y fondo de ahorro',
              ),
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
}