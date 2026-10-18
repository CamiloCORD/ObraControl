import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ingreso_model.dart';
import '../models/semana_model.dart';
import '../models/prestamo_tercero_model.dart';
import '../providers/proyecto_provider.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import 'gastos_screen.dart';

enum PeriodoContable {
  historicoGeneral,
  semanaActiva,
  personalizado,
}

class ContabilidadScreen extends StatefulWidget {
  const ContabilidadScreen({super.key});

  @override
  State<ContabilidadScreen> createState() => _ContabilidadScreenState();
}

class _ContabilidadScreenState extends State<ContabilidadScreen> with SingleTickerProviderStateMixin {
  final NumberFormat _cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final FirestoreService _firestoreService = FirestoreService();

  late TabController _tabController;
  String? _loteIdFiltroCxC; // null = Todos los lotes en Cartera
  String _filtroEstadoPrestamo = 'Todos'; // 'Todos', 'Pendientes', 'Saldados'

  // Selección múltiple para Cuenta de Cobro (CxC)
  bool _modoSeleccionCxC = false;
  final Set<String> _itemsCobroSeleccionados = {};

  // Filtros de Cuentas por Pagar (CxP)
  String _filtroRolCxP = 'Todos'; // 'Todos', 'Solo Técnicos', 'Solo Ayudantes'

  PeriodoContable _periodo = PeriodoContable.historicoGeneral;
  DateTimeRange? _rangoPersonalizado;
  String? _loteIdFiltro; // null = Todos los lotes
  bool _exportandoPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        _periodo = PeriodoContable.personalizado;
      });
    }
  }

  void _abrirModalIngreso({IngresoModel? ingresoParaEditar}) {
    final proyecto = Provider.of<ProyectoProvider>(context, listen: false);
    final esEdicion = ingresoParaEditar != null;

    final conceptoCtrl = TextEditingController(text: ingresoParaEditar?.concepto ?? '');
    final montoCtrl = TextEditingController(
      text: ingresoParaEditar != null ? ingresoParaEditar.monto.toStringAsFixed(0) : '',
    );
    final clienteCtrl = TextEditingController(text: ingresoParaEditar?.cliente ?? '');
    final obsCtrl = TextEditingController(text: ingresoParaEditar?.observaciones ?? '');
    DateTime fechaSeleccionada = ingresoParaEditar?.fecha ?? DateTime.now();
    String metodoPago = ingresoParaEditar?.metodoPago ?? 'Transferencia';
    String? loteIdSeleccionado = ingresoParaEditar?.loteId;

    final metodosPago = ['Transferencia', 'Efectivo', 'Cheque', 'Otro'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x1A0500D0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  esEdicion ? Icons.edit_note : Icons.add_card,
                  color: const Color(0xFF0500D0),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                esEdicion ? 'Editar Ingreso' : 'Registrar Ingreso',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: conceptoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Concepto *',
                      hintText: 'Ej. Anticipo obra Lote 1, Acta #2',
                      prefixIcon: Icon(Icons.description_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto (\$) *',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // SELECTOR DE FECHA
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fechaSeleccionada,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setStateModal(() => fechaSeleccionada = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha del Ingreso *',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(fechaSeleccionada)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ASOCIAR A LOTE (OPCIONAL)
                  DropdownButtonFormField<String?>(
                    initialValue: loteIdSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Lote / Frente de Obra (Opcional)',
                      prefixIcon: Icon(Icons.home_work_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('General / Sin Lote Específico'),
                      ),
                      ...proyecto.lotes.map((lote) => DropdownMenuItem<String?>(
                            value: lote.id,
                            child: Text(lote.nombre),
                          )),
                    ],
                    onChanged: (val) {
                      setStateModal(() => loteIdSeleccionado = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  // CLIENTE / CONTRATANTE
                  TextField(
                    controller: clienteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cliente / Contratante (Opcional)',
                      hintText: 'Ej. Constructora, Propietario',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // MÉTODO DE PAGO
                  DropdownButtonFormField<String>(
                    initialValue: metodoPago,
                    decoration: const InputDecoration(
                      labelText: 'Método de Pago',
                      prefixIcon: Icon(Icons.payment_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: metodosPago
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => metodoPago = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  // OBSERVACIONES
                  TextField(
                    controller: obsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (Opcional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0500D0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final concepto = conceptoCtrl.text.trim();
                final monto = double.tryParse(montoCtrl.text.trim()) ?? 0.0;

                if (concepto.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa un concepto para el ingreso.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (monto <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa un monto válido mayor a \$0.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                String? loteNombre;
                if (loteIdSeleccionado != null) {
                  final match = proyecto.lotes.where((l) => l.id == loteIdSeleccionado).firstOrNull;
                  loteNombre = match?.nombre;
                }

                final nuevoIngreso = IngresoModel(
                  id: esEdicion ? ingresoParaEditar.id : '',
                  concepto: concepto,
                  monto: monto,
                  fecha: fechaSeleccionada,
                  loteId: loteIdSeleccionado,
                  loteNombre: loteNombre,
                  cliente: clienteCtrl.text.trim().isNotEmpty ? clienteCtrl.text.trim() : null,
                  metodoPago: metodoPago,
                  observaciones: obsCtrl.text.trim().isNotEmpty ? obsCtrl.text.trim() : null,
                );

                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogCtx);

                try {
                  if (esEdicion) {
                    await proyecto.actualizarIngreso(nuevoIngreso);
                  } else {
                    await proyecto.registrarIngreso(nuevoIngreso);
                  }

                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        esEdicion ? 'Ingreso actualizado correctamente.' : 'Ingreso registrado con éxito.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(esEdicion ? 'Guardar Cambios' : 'Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarIngreso(IngresoModel ingreso) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Eliminar Ingreso'),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar el ingreso "${ingreso.concepto}" por ${_cop.format(ingreso.monto)}? Esta acción recalculará los balances contables.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final proyecto = Provider.of<ProyectoProvider>(context, listen: false);
              Navigator.pop(ctx);
              try {
                await proyecto.eliminarIngreso(ingreso.id);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Ingreso eliminado correctamente.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoDetalleCxP(List<Map<String, dynamic>> detalle, double totalDeuda) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.pending_actions_outlined, color: Colors.deepOrange.shade800),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Pasivos de Nómina (CxP)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: detalle.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No hay deudas ni saldos pendientes de pago a técnicos ni ayudantes.',
                    textAlign: TextAlign.center,
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...detalle.map((d) {
                        final nombre = d['nombre']?.toString() ?? 'Trabajador';
                        final rol = d['rol']?.toString() ?? 'Operativo';
                        final saldo = (d['saldoPendiente'] as num?)?.toDouble() ?? 0.0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepOrange.shade100,
                            child: Icon(
                              rol.toLowerCase().contains('técnico') || rol.toLowerCase().contains('tecnico')
                                  ? Icons.engineering_outlined
                                  : Icons.handyman_outlined,
                              color: Colors.deepOrange.shade900,
                              size: 18,
                            ),
                          ),
                          title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(rol, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          trailing: Text(
                            _cop.format(saldo),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.deepOrange.shade900,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Pasivo Pendiente:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _cop.format(totalDeuda),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.deepOrange.shade900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _abrirModalPrestamoTercero({PrestamoTerceroModel? prestamoParaEditar}) {
    final proyecto = Provider.of<ProyectoProvider>(context, listen: false);
    final esEdicion = prestamoParaEditar != null;

    final destCtrl = TextEditingController(text: prestamoParaEditar?.destinatario ?? '');
    final montoCtrl = TextEditingController(
      text: prestamoParaEditar != null ? prestamoParaEditar.montoPrestado.toStringAsFixed(0) : '',
    );
    final conceptoCtrl = TextEditingController(text: prestamoParaEditar?.concepto ?? '');
    DateTime fechaSeleccionada = prestamoParaEditar?.fechaRegistro ?? DateTime.now();
    String? loteIdSeleccionado = prestamoParaEditar?.loteId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x1A0500D0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  esEdicion ? Icons.edit_note : Icons.handshake_outlined,
                  color: const Color(0xFF0500D0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  esEdicion ? 'Editar Préstamo' : 'Nuevo Préstamo a Tercero',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Color(0xFF0500D0)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Este préstamo se contabiliza como Activo por Cobrar (CxC) y NO afecta los egresos de la obra.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF0500D0)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: destCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Destinatario / Pagador / Contratante *',
                      hintText: 'Ej. Juan Pérez, Constructora X',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: conceptoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Concepto / Motivo *',
                      hintText: 'Ej. Préstamo personal, Anticipo particular',
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto Prestado (COP) *',
                      prefixText: '\$ ',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fechaSeleccionada,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setStateModal(() => fechaSeleccionada = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha del Préstamo *',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(fechaSeleccionada)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: loteIdSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Frente de Obra / Lote (Opcional)',
                      prefixIcon: Icon(Icons.home_work_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('General / Sin Lote Específico'),
                      ),
                      ...proyecto.lotes.map((lote) => DropdownMenuItem<String?>(
                            value: lote.id,
                            child: Text(lote.nombre),
                          )),
                    ],
                    onChanged: (val) {
                      setStateModal(() => loteIdSeleccionado = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0500D0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final dest = destCtrl.text.trim();
                final conc = conceptoCtrl.text.trim();
                final monto = double.tryParse(montoCtrl.text.trim()) ?? 0.0;

                if (dest.isEmpty || conc.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor completa el destinatario y concepto.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (monto <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa un monto válido mayor a 0.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final proyecto = Provider.of<ProyectoProvider>(context, listen: false);
                Navigator.pop(dialogCtx);

                try {
                  if (esEdicion) {
                    final updated = prestamoParaEditar.copyWith(
                      destinatario: dest,
                      concepto: conc,
                      montoPrestado: monto,
                      fechaRegistro: fechaSeleccionada,
                      loteId: loteIdSeleccionado,
                    );
                    await proyecto.editarPrestamoTercero(updated);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Préstamo actualizado correctamente.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    final nuevo = PrestamoTerceroModel(
                      id: '',
                      destinatario: dest,
                      concepto: conc,
                      montoPrestado: monto,
                      totalAbonado: 0.0,
                      fechaRegistro: fechaSeleccionada,
                      loteId: loteIdSeleccionado,
                      estado: 'Pendiente',
                      historialAbonos: const [],
                    );
                    await proyecto.registrarPrestamoTercero(nuevo);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Préstamo registrado exitosamente en Cartera CxC.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar préstamo: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(esEdicion ? 'Guardar Cambios' : 'Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalAbonoPrestamo(PrestamoTerceroModel prestamo) {
    final montoCtrl = TextEditingController(
      text: prestamo.saldoPendiente > 0 ? prestamo.saldoPendiente.toStringAsFixed(0) : '',
    );
    final obsCtrl = TextEditingController();
    String metodoPago = 'Transferencia';
    final metodosPago = ['Transferencia', 'Efectivo', 'Cheque', 'Otro'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.payments_outlined, color: Colors.green.shade800),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Registrar Abono a Préstamo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prestamo.destinatario,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(prestamo.concepto,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Monto Original:', style: TextStyle(fontSize: 12)),
                            Text(_cop.format(prestamo.montoPrestado),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Saldo Pendiente:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(_cop.format(prestamo.saldoPendiente),
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color: Colors.orange.shade900)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto del Abono (COP) *',
                      prefixText: '\$ ',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: metodoPago,
                    decoration: const InputDecoration(
                      labelText: 'Método de Pago',
                      prefixIcon: Icon(Icons.payment_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: metodosPago
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => metodoPago = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: obsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones / N° Comprobante (Opcional)',
                      prefixIcon: Icon(Icons.description_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final monto = double.tryParse(montoCtrl.text.trim()) ?? 0.0;
                if (monto <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa un monto válido mayor a 0.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final proyecto = Provider.of<ProyectoProvider>(context, listen: false);
                Navigator.pop(dialogCtx);

                try {
                  await proyecto.registrarAbonoPrestamoTercero(
                    prestamoId: prestamo.id,
                    monto: monto,
                    metodoPago: metodoPago,
                    observacion: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Abono de ${_cop.format(monto)} registrado correctamente.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al registrar abono: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Registrar Abono'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarPrestamo(PrestamoTerceroModel prestamo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Eliminar Préstamo'),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar el préstamo a "${prestamo.destinatario}" por ${_cop.format(prestamo.montoPrestado)}? Esta acción recalculará la cartera.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final proyecto = Provider.of<ProyectoProvider>(context, listen: false);
              Navigator.pop(ctx);
              try {
                await proyecto.eliminarPrestamoTercero(prestamo.id);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Préstamo eliminado correctamente.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarModalAuditoriaNomina(BuildContext context, List<SemanaModel> semanasEvaluadas) {
    double totalDevengado = 0.0;
    double subtotalAyudantes = 0.0;
    double subtotalTecnicos = 0.0;
    double totalPagado = 0.0;
    double totalPendiente = 0.0;
    int totalAyudantes = 0;
    int totalTecnicos = 0;

    for (final sem in semanasEvaluadas) {
      for (final reg in sem.registros) {
        totalDevengado += reg.totalGenerado;
        final pagadoReg = reg.totalPagado + reg.totalAdelantos;
        totalPagado += pagadoReg;
        totalPendiente += reg.saldoPendiente;
        if (reg.esAyudante) {
          subtotalAyudantes += reg.totalGenerado;
          totalAyudantes++;
        } else {
          subtotalTecnicos += reg.totalGenerado;
          totalTecnicos++;
        }
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.fact_check_outlined, color: Colors.orange.shade900, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Auditoría de Costos de Nómina',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${semanasEvaluadas.length} semana(s) evaluada(s) · Total: ${_cop.format(totalDevengado)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TARJETA RESUMEN CONSOLIDADO
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Nómina Total Generada:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900)),
                          Text(_cop.format(totalDevengado), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.orange.shade900)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('• Subtotal Ayudantes ($totalAyudantes reg.):', style: const TextStyle(fontSize: 12)),
                          Text(_cop.format(subtotalAyudantes), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('• Subtotal Técnicos ($totalTecnicos reg.):', style: const TextStyle(fontSize: 12)),
                          Text(_cop.format(subtotalTecnicos), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0500D0))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('• Total Desembolsado / Vales:', style: TextStyle(fontSize: 12)),
                          Text(_cop.format(totalPagado), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('• Saldo Pendiente (CxP):', style: TextStyle(fontSize: 12)),
                          Text(_cop.format(totalPendiente), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Desglose por Semana',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                if (semanasEvaluadas.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: const Center(
                      child: Text('No hay semanas con registros en este periodo.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...semanasEvaluadas.map((sem) {
                    double semAyudantes = 0.0;
                    double semTecnicos = 0.0;
                    double semPagado = 0.0;
                    double semPendiente = 0.0;
                    for (final r in sem.registros) {
                      if (r.esAyudante) {
                        semAyudantes += r.totalGenerado;
                      } else {
                        semTecnicos += r.totalGenerado;
                      }
                      semPagado += (r.totalPagado + r.totalAdelantos);
                      semPendiente += r.saldoPendiente;
                    }
                    final semTotal = semAyudantes + semTecnicos;
                    final periodoStr = '${DateFormat('dd/MM').format(sem.fechaInicio)} - ${DateFormat('dd/MM/yyyy').format(sem.fechaFin)}';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      elevation: 0,
                      color: Colors.grey.shade50,
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sem.numeroSemana,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _cop.format(semTotal),
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.orange.shade900),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              periodoStr,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            Text(
                              '${sem.registros.length} trabajador(es)',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Ayudantes (Jornadas + Bonos):', style: TextStyle(fontSize: 11)),
                                    Text(_cop.format(semAyudantes), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Técnicos (Casas + Bonos):', style: TextStyle(fontSize: 11)),
                                    Text(_cop.format(semTecnicos), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0500D0))),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Pagado / Vales:', style: TextStyle(fontSize: 11)),
                                    Text(_cop.format(semPagado), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Saldo Pendiente:', style: TextStyle(fontSize: 11)),
                                    Text(_cop.format(semPendiente), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...sem.registros.map((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  r.esAyudante ? Icons.handyman_outlined : Icons.engineering_outlined,
                                  size: 14,
                                  color: r.esAyudante ? Colors.teal : const Color(0xFF0500D0),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${r.trabajadorNombre} (${r.esAyudante ? "${r.diasOcasas % 1 == 0 ? r.diasOcasas.toInt() : r.diasOcasas} d" : "${r.diasOcasas.toInt()} c"})',
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _cop.format(r.totalGenerado),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarEstadoResultados() async {
    if (_exportandoPdf) return;

    final proyecto = Provider.of<ProyectoProvider>(context, listen: false);

    DateTime? fechaInicio;
    DateTime? fechaFin;
    String? semanaId;

    switch (_periodo) {
      case PeriodoContable.historicoGeneral:
        fechaInicio = null;
        fechaFin = null;
        semanaId = null;
        break;
      case PeriodoContable.semanaActiva:
        if (proyecto.semanaActiva != null) {
          semanaId = proyecto.semanaActiva!.id;
          fechaInicio = proyecto.semanaActiva!.fechaInicio;
          fechaFin = proyecto.semanaActiva!.fechaFin;
        } else {
          semanaId = '__sin_semana__';
        }
        break;
      case PeriodoContable.personalizado:
        if (_rangoPersonalizado != null) {
          fechaInicio = _rangoPersonalizado!.start;
          fechaFin = _rangoPersonalizado!.end;
        }
        semanaId = null;
        break;
    }

    // Filtrar Ingresos exactamente como en pantalla
    final ingresosFiltrados = proyecto.filtrarIngresos(
      inicio: fechaInicio,
      fin: fechaFin,
      loteId: _loteIdFiltro,
    );
    final double totalIngresos = ingresosFiltrados.fold(0.0, (acc, ing) => acc + ing.monto);

    // Obtener semanas válidas para nómina y pasivos
    final semanasEvaluadas = proyecto.obtenerSemanasValidas(
      inicio: fechaInicio,
      fin: fechaFin,
      semanaId: semanaId,
    );

    // Gastos Operativos y Nómina en el periodo (evitando duplicidad con nómina)
    final double totalGastosOperativos = proyecto.calcularGastosOperativos(
      inicio: fechaInicio,
      fin: fechaFin,
      semanaId: semanaId,
    );
    final double totalNomina = proyecto.calcularNominaTotal(
      inicio: fechaInicio,
      fin: fechaFin,
      semanaId: semanaId,
    );
    final double totalEgresos = totalGastosOperativos + totalNomina;
    final double balanceNeto = totalIngresos - totalEgresos;
    final double margenRendimiento = totalIngresos > 0 ? (balanceNeto / totalIngresos) * 100 : 0.0;

    // Subtotales discriminados de nómina
    double subtotalAyudantes = 0.0;
    double subtotalTecnicos = 0.0;
    for (final sem in semanasEvaluadas) {
      for (final reg in sem.registros) {
        if (reg.esAyudante) {
          subtotalAyudantes += reg.totalGenerado;
        } else {
          subtotalTecnicos += reg.totalGenerado;
        }
      }
    }

    final String loteNombre = _loteIdFiltro != null
        ? (proyecto.lotes.where((l) => l.id == _loteIdFiltro).firstOrNull?.nombre ?? 'Lote Seleccionado')
        : 'Consolidado General de Obra';

    // Obtener gastos detallados
    final gastosPeriodo = proyecto.filtrarGastos(
      inicio: fechaInicio,
      fin: fechaFin,
      semanaId: semanaId,
    );
    final gastosFiltrados = _loteIdFiltro != null
        ? gastosPeriodo.where((g) => g.loteNombre == loteNombre).toList()
        : gastosPeriodo;

    // Métricas de Cuentas por Cobrar (CxC)
    final int totalCasasProyecto = _loteIdFiltro != null
        ? () {
            final casas = proyecto.viviendas.where((v) => v.loteId == _loteIdFiltro).length;
            if (casas > 0) return casas;
            final lote = proyecto.lotes.where((l) => l.id == _loteIdFiltro).firstOrNull;
            return lote?.cantidadCasas ?? 0;
          }()
        : () {
            final casas = proyecto.viviendas.length;
            if (casas > 0) return casas;
            return proyecto.lotes.fold(0, (acc, l) => acc + l.cantidadCasas);
          }();

    final double tarifaCobroPorCasa = proyecto.tarifaCobroPorCasa;
    final int casasTerminadas = proyecto.contarCasasTerminadas(loteId: _loteIdFiltro);
    final double valorEjecutadoObra = proyecto.calcularValorEjecutadoObra(loteId: _loteIdFiltro);
    final double totalValorContratado = totalCasasProyecto * tarifaCobroPorCasa;
    final double carteraObraExigible = proyecto.calcularCarteraObraExigible(loteId: _loteIdFiltro);
    final double carteraPrestamosTerceros = proyecto.carteraPrestamosTerceros;
    final double carteraTotalPorCobrar = carteraObraExigible + carteraPrestamosTerceros;

    // Métricas de Cuentas por Pagar (CxP)
    final Map<String, Map<String, dynamic>> deudasPorTrabajador = {};
    double saldoPendienteNomina = 0.0;

    for (final sem in semanasEvaluadas) {
      for (final reg in sem.registros) {
        if (reg.saldoPendiente > 0) {
          saldoPendienteNomina += reg.saldoPendiente;
          final key = reg.trabajadorId.isNotEmpty ? reg.trabajadorId : reg.trabajadorNombre;
          if (!deudasPorTrabajador.containsKey(key)) {
            deudasPorTrabajador[key] = {
              'nombre': reg.trabajadorNombre,
              'rol': reg.rol,
              'saldoPendiente': 0.0,
              'totalDevengado': 0.0,
              'totalPagado': 0.0,
            };
          }
          deudasPorTrabajador[key]!['saldoPendiente'] =
              (deudasPorTrabajador[key]!['saldoPendiente'] as double) + reg.saldoPendiente;
          deudasPorTrabajador[key]!['totalDevengado'] =
              (deudasPorTrabajador[key]!['totalDevengado'] as double) + reg.totalGenerado;
          deudasPorTrabajador[key]!['totalPagado'] =
              (deudasPorTrabajador[key]!['totalPagado'] as double) + (reg.totalPagado + reg.totalAdelantos);
        }
      }
    }
    final List<Map<String, dynamic>> detalleDeudaTrabajadores = deudasPorTrabajador.values.toList();

    String periodoTexto = '';
    switch (_periodo) {
      case PeriodoContable.historicoGeneral:
        periodoTexto = 'Histórico General Acumulado';
        break;
      case PeriodoContable.semanaActiva:
        if (proyecto.semanaActiva != null) {
          final s = proyecto.semanaActiva!;
          periodoTexto = '${s.numeroSemana} (${DateFormat('d MMM yyyy').format(s.fechaInicio)} - ${DateFormat('d MMM yyyy').format(s.fechaFin)})';
        } else {
          periodoTexto = 'Semana Activa (Sin registros)';
        }
        break;
      case PeriodoContable.personalizado:
        if (_rangoPersonalizado != null) {
          periodoTexto = '${DateFormat('dd/MM/yyyy').format(_rangoPersonalizado!.start)} - ${DateFormat('dd/MM/yyyy').format(_rangoPersonalizado!.end)}';
        } else {
          periodoTexto = 'Periodo Personalizado';
        }
        break;
    }

    setState(() => _exportandoPdf = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Generando Estado de Resultados en PDF...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final cfg = Provider.of<ProyectoProvider>(context, listen: false).configuracion;
      await PdfService.descargarEstadoResultadosPdf(
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        periodoTexto: periodoTexto,
        loteFiltroNombre: loteNombre,
        ingresos: ingresosFiltrados,
        gastos: gastosFiltrados,
        totalNominaPagada: totalNomina,
        totalIngresos: totalIngresos,
        totalGastos: totalGastosOperativos,
        balanceNeto: balanceNeto,
        margenRendimiento: margenRendimiento,
        totalCasasProyecto: totalCasasProyecto,
        tarifaCobroPorCasa: tarifaCobroPorCasa,
        totalValorContratado: totalValorContratado,
        saldoPendientePorCobrar: carteraTotalPorCobrar,
        saldoPendienteNomina: saldoPendienteNomina,
        subtotalAyudantes: subtotalAyudantes,
        subtotalTecnicos: subtotalTecnicos,
        detalleDeudaTrabajadores: detalleDeudaTrabajadores,
        casasTerminadas: casasTerminadas,
        valorEjecutadoObra: valorEjecutadoObra,
        saldoCarteraObraExigible: carteraObraExigible,
        saldoPrestamosTerceros: carteraPrestamosTerceros,
        configuracion: cfg,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado de Resultados generado y descargado correctamente.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF del Estado de Resultados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exportandoPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final proyecto = Provider.of<ProyectoProvider>(context);
    final itemsCobroSeleccionados = _obtenerItemsCobroSeleccionados(proyecto);
    final double totalCobroSeleccionado = itemsCobroSeleccionados.fold<double>(
      0.0,
      (acc, it) => acc + ((it['subtotal'] as num?)?.toDouble() ?? 0.0),
    );

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
              Tab(
                icon: Icon(Icons.trending_up_rounded, size: 18),
                text: 'Rendimiento y P&L',
              ),
              Tab(
                icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                text: 'Cuentas por Cobrar',
              ),
              Tab(
                icon: Icon(Icons.payment_outlined, size: 18),
                text: 'Cuentas por Pagar',
              ),
              Tab(
                icon: Icon(Icons.receipt_long_outlined, size: 18),
                text: 'Gastos de Obra',
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _construirTabRendimiento(context, proyecto),
          _construirTabCarteraCxC(proyecto),
          _construirTabCuentasPorPagar(proyecto),
          const GastosScreen(),
        ],
      ),
      bottomNavigationBar: (_tabController.index == 1 && _modoSeleccionCxC)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${itemsCobroSeleccionados.length} concepto(s) seleccionado(s)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Total: ${_cop.format(totalCobroSeleccionado)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0500D0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _modoSeleccionCxC = false;
                          _itemsCobroSeleccionados.clear();
                        });
                      },
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0500D0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onPressed: itemsCobroSeleccionados.isEmpty
                          ? null
                          : () => _mostrarDialogoGenerarCuentaCobro(context, proyecto),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text(
                        'Generar Cuenta de Cobro (PDF)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              heroTag: 'fab_nuevo_ingreso',
              backgroundColor: const Color(0xFF0500D0),
              foregroundColor: Colors.white,
              onPressed: () => _abrirModalIngreso(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Ingreso'),
            )
          : (_tabController.index == 1 && !_modoSeleccionCxC)
              ? FloatingActionButton.extended(
                  heroTag: 'fab_nuevo_prestamo',
                  backgroundColor: const Color(0xFF0500D0),
                  foregroundColor: Colors.white,
                  onPressed: () => _abrirModalPrestamoTercero(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo Préstamo'),
                )
              : null,
    );
  }

  Widget _construirTabRendimiento(BuildContext context, ProyectoProvider proyecto) {
    DateTime? fechaInicio;
    DateTime? fechaFin;
    String? semanaId;

    switch (_periodo) {
      case PeriodoContable.historicoGeneral:
        fechaInicio = null;
        fechaFin = null;
        semanaId = null;
        break;
      case PeriodoContable.semanaActiva:
        if (proyecto.semanaActiva != null) {
          semanaId = proyecto.semanaActiva!.id;
          fechaInicio = proyecto.semanaActiva!.fechaInicio;
          fechaFin = proyecto.semanaActiva!.fechaFin;
        } else {
          semanaId = '__sin_semana__';
        }
        break;
      case PeriodoContable.personalizado:
        if (_rangoPersonalizado != null) {
          fechaInicio = _rangoPersonalizado!.start;
          fechaFin = _rangoPersonalizado!.end;
        }
        semanaId = null;
        break;
    }

    // Filtrar Ingresos
    final ingresosFiltrados = proyecto.filtrarIngresos(
      inicio: fechaInicio,
      fin: fechaFin,
      loteId: _loteIdFiltro,
    );
    final double totalIngresos = ingresosFiltrados.fold(0.0, (acc, ing) => acc + ing.monto);

    // Obtener semanas válidas para nómina y pasivos
    final semanasEvaluadas = proyecto.obtenerSemanasValidas(
      inicio: fechaInicio,
      fin: fechaFin,
      semanaId: semanaId,
    );

    // Gastos Operativos y Nómina en el periodo (evitando duplicidad con nómina)
    final double totalGastosOperativos = proyecto.calcularGastosOperativos(
      inicio: fechaInicio,
      fin: fechaFin,
      semanaId: semanaId,
    );
    final double totalNomina = proyecto.calcularNominaTotal(
      inicio: fechaInicio,
      fin: fechaFin,
      semanaId: semanaId,
    );
    final double totalEgresos = totalGastosOperativos + totalNomina;

    // Balance Neto y Margen de Rendimiento
    final double balanceNeto = totalIngresos - totalEgresos;
    final double margenRendimiento = totalIngresos > 0 ? (balanceNeto / totalIngresos) * 100 : 0.0;

    // Métricas de Cuentas por Pagar (CxP)
    final Map<String, Map<String, dynamic>> deudasPorTrabajador = {};
    double saldoPendienteNomina = 0.0;

    for (final sem in semanasEvaluadas) {
      for (final reg in sem.registros) {
        if (reg.saldoPendiente > 0) {
          saldoPendienteNomina += reg.saldoPendiente;
          final key = reg.trabajadorId.isNotEmpty ? reg.trabajadorId : reg.trabajadorNombre;
          if (!deudasPorTrabajador.containsKey(key)) {
            deudasPorTrabajador[key] = {
              'nombre': reg.trabajadorNombre,
              'rol': reg.rol,
              'saldoPendiente': 0.0,
              'totalDevengado': 0.0,
              'totalPagado': 0.0,
            };
          }
          deudasPorTrabajador[key]!['saldoPendiente'] =
              (deudasPorTrabajador[key]!['saldoPendiente'] as double) + reg.saldoPendiente;
          deudasPorTrabajador[key]!['totalDevengado'] =
              (deudasPorTrabajador[key]!['totalDevengado'] as double) + reg.totalGenerado;
          deudasPorTrabajador[key]!['totalPagado'] =
              (deudasPorTrabajador[key]!['totalPagado'] as double) + (reg.totalPagado + reg.totalAdelantos);
        }
      }
    }
    final List<Map<String, dynamic>> detalleDeudaTrabajadores = deudasPorTrabajador.values.toList();

    // Métricas de Cuentas por Cobrar (CxC)
    final int casasTerminadas = proyecto.contarCasasTerminadas(loteId: _loteIdFiltro);
    final double carteraObraExigible = proyecto.calcularCarteraObraExigible(loteId: _loteIdFiltro);
    final double carteraPrestamosTerceros = proyecto.carteraPrestamosTerceros;
    final double carteraTotalPorCobrar = carteraObraExigible + carteraPrestamosTerceros;
    final double posicionFinancieraProyectada = balanceNeto + carteraTotalPorCobrar - saldoPendienteNomina;

    String descripcionPeriodo = '';
    switch (_periodo) {
      case PeriodoContable.historicoGeneral:
        descripcionPeriodo = 'Histórico general acumulado';
        break;
      case PeriodoContable.semanaActiva:
        if (proyecto.semanaActiva != null) {
          final s = proyecto.semanaActiva!;
          descripcionPeriodo = '${s.numeroSemana} (${DateFormat('d MMM').format(s.fechaInicio)} - ${DateFormat('d MMM').format(s.fechaFin)})';
        } else {
          descripcionPeriodo = 'Sin semana activa';
        }
        break;
      case PeriodoContable.personalizado:
        if (_rangoPersonalizado != null) {
          descripcionPeriodo = '${DateFormat('d/MM/yy').format(_rangoPersonalizado!.start)} - ${DateFormat('d/MM/yy').format(_rangoPersonalizado!.end)}';
        } else {
          descripcionPeriodo = 'Selecciona fechas';
        }
        break;
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BARRA DE FILTROS SUPERIOR
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF0500D0)),
                        const SizedBox(width: 8),
                        const Text(
                          'Filtros de Análisis',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    const SizedBox(height: 10),
                    // SELECTOR DE PERIODO
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Histórico General'),
                            selected: _periodo == PeriodoContable.historicoGeneral,
                            selectedColor: const Color(0xFF0500D0),
                            labelStyle: TextStyle(
                              color: _periodo == PeriodoContable.historicoGeneral ? Colors.white : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _periodo = PeriodoContable.historicoGeneral);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Semana Activa'),
                            selected: _periodo == PeriodoContable.semanaActiva,
                            selectedColor: const Color(0xFF0500D0),
                            labelStyle: TextStyle(
                              color: _periodo == PeriodoContable.semanaActiva ? Colors.white : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _periodo = PeriodoContable.semanaActiva);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            avatar: Icon(
                              Icons.date_range,
                              size: 15,
                              color: _periodo == PeriodoContable.personalizado ? Colors.white : const Color(0xFF0500D0),
                            ),
                            label: Text(
                              _periodo == PeriodoContable.personalizado && _rangoPersonalizado != null
                                  ? '${DateFormat('d/MM').format(_rangoPersonalizado!.start)} - ${DateFormat('d/MM').format(_rangoPersonalizado!.end)}'
                                  : 'Personalizado',
                            ),
                            selected: _periodo == PeriodoContable.personalizado,
                            selectedColor: const Color(0xFF0500D0),
                            labelStyle: TextStyle(
                              color: _periodo == PeriodoContable.personalizado ? Colors.white : Colors.black87,
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
                    const SizedBox(height: 10),
                    // FILTRO POR LOTE
                    DropdownButtonFormField<String?>(
                      initialValue: _loteIdFiltro,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por Lote / Frente',
                        prefixIcon: Icon(Icons.apartment_outlined, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos los Lotes de la Obra'),
                        ),
                        ...proyecto.lotes.map((lote) => DropdownMenuItem<String?>(
                              value: lote.id,
                              child: Text(lote.nombre),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() => _loteIdFiltro = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // BOTÓN DE ACCIÓN PARA EXPORTAR ESTADO DE RESULTADOS
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0500D0),
                  side: const BorderSide(color: Color(0xFF0500D0), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0x0A0500D0),
                ),
                icon: _exportandoPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0500D0)),
                      )
                    : const Icon(Icons.summarize_rounded, color: Color(0xFF0500D0), size: 22),
                label: Text(
                  _exportandoPdf
                      ? 'Generando Estado de Resultados...'
                      : 'Exportar Estado de Resultados (PDF)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _exportandoPdf ? null : _exportarEstadoResultados,
              ),
            ),
            const SizedBox(height: 14),

            // TARJETAS DE RESUMEN FINANCIERO
            Row(
              children: [
                Expanded(
                  child: _buildTarjetaMetrica(
                    titulo: 'Total Ingresos',
                    valor: _cop.format(totalIngresos),
                    icono: Icons.trending_up,
                    color: Colors.green.shade700,
                    subtitulo: '${ingresosFiltrados.length} registro(s)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTarjetaMetrica(
                    titulo: 'Total Gastos',
                    valor: _cop.format(totalGastosOperativos),
                    icono: Icons.shopping_cart_outlined,
                    color: Colors.red.shade700,
                    subtitulo: 'Operativos de obra',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTarjetaMetrica(
                    titulo: 'Total Nómina',
                    valor: _cop.format(totalNomina),
                    icono: Icons.people_outline,
                    color: Colors.orange.shade800,
                    subtitulo: 'Técnicos y ayudantes (Ver auditoría)',
                    onTap: () => _mostrarModalAuditoriaNomina(context, semanasEvaluadas),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTarjetaMetrica(
                    titulo: 'Rendimiento',
                    valor: '${margenRendimiento.toStringAsFixed(1)}%',
                    icono: Icons.percent_rounded,
                    color: margenRendimiento >= 0 ? const Color(0xFF0500D0) : Colors.red,
                    subtitulo: 'Margen sobre ingresos',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // BALANCE NETO DESTACADO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: balanceNeto >= 0
                      ? [const Color(0xFF0500D0), const Color(0xFF1E88E5)]
                      : [Colors.red.shade800, Colors.red.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (balanceNeto >= 0 ? const Color(0xFF0500D0) : Colors.red).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Balance Neto Consolidado',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _cop.format(balanceNeto),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Egresos: ${_cop.format(totalEgresos)} (Gastos + Nómina)',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Proyección Neta al Cierre: ${_cop.format(posicionFinancieraProyectada)} (Caja + CxC - CxP)',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      balanceNeto >= 0 ? 'SUPERÁVIT' : 'DÉFICIT',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // CARTERA Y PASIVOS DE OBRA (CxC & CxP)
            Row(
              children: [
                Expanded(
                  child: _buildTarjetaMetrica(
                    titulo: 'Cuentas por Cobrar (CxC)',
                    valor: _cop.format(carteraTotalPorCobrar),
                    icono: Icons.account_balance_wallet_rounded,
                    color: Colors.teal.shade800,
                    subtitulo: '$casasTerminadas casas term. | Obra: ${_cop.format(carteraObraExigible)} • Préstamos: ${_cop.format(carteraPrestamosTerceros)}',
                    onTap: () => _tabController.animateTo(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTarjetaMetrica(
                    titulo: 'Cuentas por Pagar (CxP)',
                    valor: _cop.format(saldoPendienteNomina),
                    icono: Icons.pending_actions_outlined,
                    color: Colors.deepOrange.shade800,
                    subtitulo: '${detalleDeudaTrabajadores.length} trabajador(es) con saldo',
                    onTap: detalleDeudaTrabajadores.isNotEmpty
                        ? () => _mostrarDialogoDetalleCxP(detalleDeudaTrabajadores, saldoPendienteNomina)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // POSICIÓN FINANCIERA NETA PROYECTADA AL CIERRE
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: posicionFinancieraProyectada >= 0
                      ? Colors.green.shade300
                      : Colors.red.shade300,
                ),
              ),
              color: posicionFinancieraProyectada >= 0
                  ? Colors.green.shade50.withValues(alpha: 0.5)
                  : Colors.red.shade50.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (posicionFinancieraProyectada >= 0 ? Colors.green : Colors.red)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        posicionFinancieraProyectada >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: posicionFinancieraProyectada >= 0
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Posición Financiera Neta Proyectada',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                          Text(
                            _cop.format(posicionFinancieraProyectada),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: posicionFinancieraProyectada >= 0
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                          Text(
                            'Liquidez (${_cop.format(balanceNeto)}) + CxC (${_cop.format(carteraTotalPorCobrar)}) - CxP (${_cop.format(saldoPendienteNomina)})',
                            style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ENCABEZADO DE LISTA DE INGRESOS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt_rounded, color: Color(0xFF0500D0), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Ingresos Registrados',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x1A0500D0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${ingresosFiltrados.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0500D0),
                        ),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0500D0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _abrirModalIngreso(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // LISTA DE INGRESOS
            if (ingresosFiltrados.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text(
                      'No hay ingresos registrados en el periodo seleccionado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0500D0),
                        side: const BorderSide(color: Color(0xFF0500D0)),
                      ),
                      onPressed: () => _abrirModalIngreso(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Registrar Primer Ingreso'),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ingresosFiltrados.length,
                itemBuilder: (context, index) {
                  final ing = ingresosFiltrados[index];
                  final fechaStr = DateFormat('dd/MM/yyyy').format(ing.fecha);

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.green.shade50,
                            child: Icon(Icons.arrow_downward_rounded, color: Colors.green.shade700, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ing.concepto,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _cop.format(ing.monto),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      fechaStr,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    if (ing.loteNombre != null && ing.loteNombre!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0x1A0500D0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          ing.loteNombre!,
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF0500D0), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    if (ing.cliente != null && ing.cliente!.isNotEmpty)
                                      Text(
                                        '• ${ing.cliente}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        ing.metodoPago,
                                        style: TextStyle(fontSize: 9, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                                if (ing.observaciones != null && ing.observaciones!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    ing.observaciones!,
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF0500D0)),
                                tooltip: 'Editar Ingreso',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _abrirModalIngreso(ingresoParaEditar: ing),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                tooltip: 'Eliminar Ingreso',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _confirmarEliminarIngreso(ing),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
  }

  void _mostrarHistorialAbonosPrestamo(PrestamoTerceroModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: Color(0xFF0500D0)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Abonos: ${p.destinatario}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Concepto: ${p.concepto}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prestado: ${_cop.format(p.montoPrestado)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(
                    'Saldo: ${_cop.format(p.saldoPendiente)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: p.estaSaldado ? Colors.green : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (p.historialAbonos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No hay abonos registrados para este préstamo.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: p.historialAbonos.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final abono = p.historialAbonos[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.green.shade50,
                          child: Icon(Icons.check, size: 14, color: Colors.green.shade700),
                        ),
                        title: Text(
                          _cop.format(abono.monto),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy hh:mm a').format(abono.fecha)} • ${abono.metodoPago}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          if (!p.estaSaldado)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0500D0),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _abrirModalAbonoPrestamo(p);
              },
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('Registrar Abono'),
            ),
        ],
      ),
    );
  }

  Widget _construirTabCarteraCxC(ProyectoProvider proyecto) {
    final double tarifaCobroPorCasa = proyecto.tarifaCobroPorCasa;
    final int casasTerminadas = proyecto.contarCasasTerminadas(loteId: _loteIdFiltroCxC);
    final double valorEjecutadoObra = proyecto.calcularValorEjecutadoObra(loteId: _loteIdFiltroCxC);
    final double abonosRecibidosObra = proyecto.calcularTotalIngresos(loteId: _loteIdFiltroCxC);
    final double saldoCarteraObra = proyecto.calcularCarteraObraExigible(loteId: _loteIdFiltroCxC);

    final int totalCasasProyecto = _loteIdFiltroCxC != null
        ? () {
            final casas = proyecto.viviendas.where((v) => v.loteId == _loteIdFiltroCxC).length;
            if (casas > 0) return casas;
            final lote = proyecto.lotes.where((l) => l.id == _loteIdFiltroCxC).firstOrNull;
            return lote?.cantidadCasas ?? 0;
          }()
        : (proyecto.viviendas.isNotEmpty
            ? proyecto.viviendas.length
            : proyecto.lotes.fold(0, (acc, l) => acc + l.cantidadCasas));

    final double valorTotalContrato = totalCasasProyecto * tarifaCobroPorCasa;
    final double saldoProyectadoTotal = (valorTotalContrato - abonosRecibidosObra) > 0
        ? (valorTotalContrato - abonosRecibidosObra)
        : 0.0;

    final double totalPrestadoTerceros = proyecto.totalPrestadoTerceros;
    final double totalRecuperadoTerceros = proyecto.totalRecuperadoTerceros;
    final double saldoPendienteTerceros = proyecto.saldoPendienteTerceros;
    final double granTotalCarteraPorCobrar = proyecto.calcularCarteraTotalPorCobrar(loteId: _loteIdFiltroCxC);

    List<PrestamoTerceroModel> prestamosMostrados = proyecto.prestamosTerceros;
    if (_filtroEstadoPrestamo == 'Pendientes') {
      prestamosMostrados = prestamosMostrados.where((p) => p.saldoPendiente > 0).toList();
    } else if (_filtroEstadoPrestamo == 'Saldados') {
      prestamosMostrados = prestamosMostrados.where((p) => p.estaSaldado).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BARRA SUPERIOR DE ACCIONES DE CARTERA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _modoSeleccionCxC
                    ? 'Selecciona ítems para la Cuenta de Cobro'
                    : 'Gestión y Cobro de Cartera Exigible',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _modoSeleccionCxC ? const Color(0xFF0500D0) : Colors.grey.shade700,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0500D0),
                  side: const BorderSide(color: Color(0xFF0500D0)),
                  backgroundColor: _modoSeleccionCxC
                      ? const Color(0xFF0500D0).withValues(alpha: 0.08)
                      : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(
                  _modoSeleccionCxC ? Icons.checklist_rtl : Icons.checklist,
                  size: 18,
                ),
                label: Text(
                  _modoSeleccionCxC ? 'Cerrar Selección' : 'Seleccionar para Cobro',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () {
                  setState(() {
                    _modoSeleccionCxC = !_modoSeleccionCxC;
                    if (!_modoSeleccionCxC) {
                      _itemsCobroSeleccionados.clear();
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // RESUMEN GLOBAL DE CARTERA
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: const Color(0xFF0500D0),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CARTERA TOTAL POR COBRAR (CxC)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Activos Exigibles en Calle',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _cop.format(granTotalCarteraPorCobrar),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cartera de Obra (Ejecutada)',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _cop.format(saldoCarteraObra),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: Colors.white24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Préstamos a Terceros',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _cop.format(saldoPendienteTerceros),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN 1: CARTERA DE OBRA POR CASAS TERMINADAS
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (_modoSeleccionCxC) ...[
                            Checkbox(
                              value: _itemsCobroSeleccionados.contains('obra_consolidada'),
                              activeColor: const Color(0xFF0500D0),
                              onChanged: saldoCarteraObra > 0
                                  ? (val) {
                                      setState(() {
                                        if (val == true) {
                                          _itemsCobroSeleccionados.add('obra_consolidada');
                                        } else {
                                          _itemsCobroSeleccionados.remove('obra_consolidada');
                                        }
                                      });
                                    }
                                  : null,
                            ),
                          ],
                          const Icon(Icons.home_work_outlined, color: Color(0xFF0500D0), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Cartera Exigible de Obra',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x1A0500D0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_cop.format(tarifaCobroPorCasa)} / casa',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0500D0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // FILTRO POR LOTE
                  if (proyecto.lotes.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text('Frente / Obra:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _loteIdFiltroCxC,
                            isDense: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos los Frentes (Consolidado)', style: TextStyle(fontSize: 12)),
                              ),
                              ...proyecto.lotes.map((l) => DropdownMenuItem<String?>(
                                    value: l.id,
                                    child: Text(l.nombre, style: const TextStyle(fontSize: 12)),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _loteIdFiltroCxC = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // MÉTRICAS DE EJECUCIÓN
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Casas Terminadas (Ejecutadas):',
                              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                            ),
                            Text(
                              '$casasTerminadas de $totalCasasProyecto casas',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalCasasProyecto > 0 ? (casasTerminadas / totalCasasProyecto).clamp(0.0, 1.0) : 0.0,
                            minHeight: 7,
                            backgroundColor: Colors.blue.shade100,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0500D0)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // DETALLE DE CARTERA EXIGIBLE
                  Row(
                    children: [
                      Expanded(
                        child: _buildTarjetaMetrica(
                          titulo: 'Valor Ejecutado',
                          valor: _cop.format(valorEjecutadoObra),
                          icono: Icons.done_all_rounded,
                          color: const Color(0xFF0500D0),
                          subtitulo: '$casasTerminadas casas × ${_cop.format(tarifaCobroPorCasa)}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTarjetaMetrica(
                          titulo: 'Abonos Recibidos',
                          valor: _cop.format(abonosRecibidosObra),
                          icono: Icons.arrow_downward_rounded,
                          color: Colors.green.shade700,
                          subtitulo: 'Ingresos pagados por clientes',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTarjetaMetrica(
                          titulo: 'Saldo Exigible Hoy',
                          valor: _cop.format(saldoCarteraObra),
                          icono: Icons.pending_actions_rounded,
                          color: saldoCarteraObra > 0 ? Colors.red.shade700 : Colors.green.shade700,
                          subtitulo: saldoCarteraObra > 0
                              ? 'Equivale a ${(tarifaCobroPorCasa > 0 ? (saldoCarteraObra / tarifaCobroPorCasa) : 0).toStringAsFixed((saldoCarteraObra / tarifaCobroPorCasa) % 1 == 0 ? 0 : 1)} casas pendientes'
                              : 'Al día con la obra',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTarjetaMetrica(
                          titulo: 'Proyección Contrato',
                          valor: _cop.format(saldoProyectadoTotal),
                          icono: Icons.real_estate_agent_outlined,
                          color: Colors.purple.shade700,
                          subtitulo: 'Contrato total ($totalCasasProyecto) - Abonos',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN 2: PRÉSTAMOS A TERCEROS / PAGADORES
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.handshake_outlined, color: Color(0xFF0500D0), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Préstamos a Terceros / Pagadores',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0500D0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _abrirModalPrestamoTercero(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Prestar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Préstamos a contratistas o pagadores. No afectan los costos operativos de la obra.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),

                  // RESUMEN MÉTRICO DE PRÉSTAMOS
                  Row(
                    children: [
                      Expanded(
                        child: _buildTarjetaMetrica(
                          titulo: 'Total Prestado',
                          valor: _cop.format(totalPrestadoTerceros),
                          icono: Icons.arrow_outward_rounded,
                          color: Colors.orange.shade800,
                          subtitulo: '${proyecto.prestamosTerceros.length} préstamos registrados',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTarjetaMetrica(
                          titulo: 'Total Recuperado',
                          valor: _cop.format(totalRecuperadoTerceros),
                          icono: Icons.price_check_rounded,
                          color: Colors.green.shade700,
                          subtitulo: 'Abonos recibidos de terceros',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTarjetaMetrica(
                    titulo: 'Saldo Pendiente por Recuperar',
                    valor: _cop.format(saldoPendienteTerceros),
                    icono: Icons.hourglass_top_rounded,
                    color: saldoPendienteTerceros > 0 ? Colors.red.shade700 : Colors.green.shade700,
                    subtitulo: 'Capital en calle pendiente de cobro',
                  ),
                  const SizedBox(height: 16),

                  // FILTRO DE PRÉSTAMOS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Historial de Préstamos',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Row(
                        children: ['Todos', 'Pendientes', 'Saldados'].map((filtro) {
                          final isSelected = _filtroEstadoPrestamo == filtro;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: ChoiceChip(
                              label: Text(filtro, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              visualDensity: VisualDensity.compact,
                              selectedColor: const Color(0x1A0500D0),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFF0500D0) : Colors.grey.shade700,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _filtroEstadoPrestamo = filtro);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // LISTA DE PRÉSTAMOS
                  if (prestamosMostrados.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.handshake_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _filtroEstadoPrestamo == 'Todos'
                                ? 'No hay préstamos registrados a terceros.'
                                : 'No hay préstamos con estado "$_filtroEstadoPrestamo".',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0500D0),
                              side: const BorderSide(color: Color(0xFF0500D0)),
                            ),
                            onPressed: () => _abrirModalPrestamoTercero(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Registrar Préstamo'),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: prestamosMostrados.length,
                      itemBuilder: (context, index) {
                        final p = prestamosMostrados[index];
                        final fechaStr = DateFormat('dd/MM/yyyy').format(p.fechaRegistro);
                        final double progreso = p.montoPrestado > 0
                            ? (p.totalAbonado / p.montoPrestado).clamp(0.0, 1.0)
                            : 0.0;

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: p.estaSaldado ? Colors.green.shade200 : Colors.grey.shade300,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (_modoSeleccionCxC) ...[
                                      Checkbox(
                                        value: _itemsCobroSeleccionados.contains('prestamo_${p.id}'),
                                        activeColor: const Color(0xFF0500D0),
                                        onChanged: p.saldoPendiente > 0
                                            ? (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _itemsCobroSeleccionados.add('prestamo_${p.id}');
                                                  } else {
                                                    _itemsCobroSeleccionados.remove('prestamo_${p.id}');
                                                  }
                                                });
                                              }
                                            : null,
                                      ),
                                    ],
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: p.estaSaldado ? Colors.green.shade50 : Colors.orange.shade50,
                                      child: Icon(
                                        p.estaSaldado ? Icons.check_circle_outline : Icons.person_outline,
                                        color: p.estaSaldado ? Colors.green.shade700 : Colors.orange.shade800,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.destinatario,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${p.concepto} • $fechaStr',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: p.estaSaldado ? Colors.green.shade100 : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        p.estado,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: p.estaSaldado ? Colors.green.shade800 : Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progreso,
                                    minHeight: 6,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      p.estaSaldado ? Colors.green : const Color(0xFF0500D0),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Prestado', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                        Text(_cop.format(p.montoPrestado), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('Abonado', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                        Text(_cop.format(p.totalAbonado), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Saldo Pendiente', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                        Text(
                                          _cop.format(p.saldoPendiente),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: p.estaSaldado ? Colors.green : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Divider(height: 1),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: Colors.grey.shade800,
                                      ),
                                      onPressed: () => _mostrarHistorialAbonosPrestamo(p),
                                      icon: const Icon(Icons.history, size: 16),
                                      label: Text('Historial (${p.historialAbonos.length})', style: const TextStyle(fontSize: 11)),
                                    ),
                                    Row(
                                      children: [
                                        if (!p.estaSaldado)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade700,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              visualDensity: VisualDensity.compact,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _abrirModalAbonoPrestamo(p),
                                            icon: const Icon(Icons.payment, size: 14),
                                            label: const Text('Abonar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0500D0)),
                                          tooltip: 'Editar Préstamo',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _abrirModalPrestamoTercero(prestamoParaEditar: p),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          tooltip: 'Eliminar Préstamo',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _confirmarEliminarPrestamo(p),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTarjetaMetrica({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
    required String subtitulo,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icono, color: color, size: 16),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                valor,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // MÉTODOS DE SELECCIÓN MÚLTIPLE Y EMISIÓN DE CUENTA DE COBRO (CxC)
  // =========================================================================
  List<Map<String, dynamic>> _obtenerItemsCobroSeleccionados(ProyectoProvider proyecto) {
    final List<Map<String, dynamic>> items = [];
    final double saldoCarteraObra = proyecto.calcularCarteraObraExigible(loteId: _loteIdFiltroCxC);
    final int casasTerminadas = proyecto.contarCasasTerminadas(loteId: _loteIdFiltroCxC);
    final double tarifaPorCasa = proyecto.tarifaCobroPorCasa > 0 ? proyecto.tarifaCobroPorCasa : 100000.0;

    if (_itemsCobroSeleccionados.contains('obra_consolidada') && saldoCarteraObra > 0) {
      final loteNombre = _loteIdFiltroCxC != null
          ? (proyecto.lotes.where((l) => l.id == _loteIdFiltroCxC).firstOrNull?.nombre ?? 'Lote')
          : 'Obra General';

      final double casasPendientesCobro = tarifaPorCasa > 0
          ? (saldoCarteraObra / tarifaPorCasa)
          : 0.0;
      final String cantStr = casasPendientesCobro % 1 == 0
          ? '${casasPendientesCobro.toInt()}'
          : casasPendientesCobro.toStringAsFixed(1);
      final num cantidadFinal = casasPendientesCobro % 1 == 0
          ? casasPendientesCobro.toInt()
          : casasPendientesCobro;

      items.add({
        'id': 'obra_consolidada',
        'tipo': 'obra',
        'deudor': 'Constructora / Cliente de Obra',
        'frente': loteNombre,
        'concepto': 'Ejecución de obra / instalación técnica en unidades certificadas - $loteNombre (Saldo de $cantStr unidades de $casasTerminadas ejecutadas tras abonos previos)',
        'cantidad': cantidadFinal,
        'tarifa': tarifaPorCasa,
        'valorUnitario': tarifaPorCasa,
        'total': saldoCarteraObra,
        'subtotal': saldoCarteraObra,
      });
    }

    for (final p in proyecto.prestamosTerceros) {
      if (_itemsCobroSeleccionados.contains('prestamo_${p.id}') && p.saldoPendiente > 0) {
        items.add({
          'id': 'prestamo_${p.id}',
          'tipo': 'prestamo',
          'deudor': p.destinatario,
          'frente': 'Préstamo a Tercero',
          'concepto': 'Préstamo / Anticipo a cobrar - ${p.concepto}',
          'cantidad': 1,
          'tarifa': p.saldoPendiente,
          'valorUnitario': p.saldoPendiente,
          'total': p.saldoPendiente,
          'subtotal': p.saldoPendiente,
        });
      }
    }

    return items;
  }

  void _mostrarDialogoGenerarCuentaCobro(BuildContext context, ProyectoProvider proyecto) {
    final items = _obtenerItemsCobroSeleccionados(proyecto);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona al menos un concepto para generar la Cuenta de Cobro.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final double totalCobro = items.fold<double>(0.0, (acc, it) => acc + ((it['subtotal'] as num?)?.toDouble() ?? 0.0));
    final String timestampFolio = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final String folioSugerido = 'CC-$timestampFolio';
    final String deudorSugerido = items.first['deudor']?.toString() ?? 'Constructora / Cliente';
    final String frenteSugerido = items.first['frente']?.toString() ?? 'Proyecto General';

    final folioCtrl = TextEditingController(text: folioSugerido);
    final deudorCtrl = TextEditingController(text: deudorSugerido);
    final nitCtrl = TextEditingController();
    final frenteCtrl = TextEditingController(text: frenteSugerido);
    final fechaCtrl = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cfg = proyecto.configuracion;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x1A0500D0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Color(0xFF0500D0), size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generar Cuenta de Cobro (PDF)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0500D0)),
                      ),
                      Text(
                        'Documento oficial ObraControl con datos bancarios',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: folioCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Número de Folio *',
                              prefixIcon: Icon(Icons.tag, size: 20),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: fechaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Fecha de Emisión *',
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: deudorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Deudor / Razón Social *',
                        prefixIcon: Icon(Icons.business_outlined, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nitCtrl,
                            decoration: const InputDecoration(
                              labelText: 'NIT / Cédula del Deudor',
                              prefixIcon: Icon(Icons.fingerprint, size: 20),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: frenteCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Frente de Obra / Lote',
                              prefixIcon: Icon(Icons.home_work_outlined, size: 20),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // LISTA RESUMEN DE CONCEPTOS
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Conceptos Incluidos (${items.length}):',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0500D0)),
                              ),
                              Text(
                                'Total: ${_cop.format(totalCobro)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0500D0)),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          ...items.map((it) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        it['concepto']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _cop.format(it['subtotal'] ?? 0),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // AVISO DE DATOS BANCARIOS PRECONFIGURADOS
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF0500D0).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance, color: Color(0xFF0500D0), size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Datos Bancarios para Pago (Incluidos en el PDF):',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0500D0)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${cfg.bancoNombre ?? 'Bancolombia'} • ${cfg.tipoCuenta ?? 'Ahorros'} No. ${cfg.numeroCuenta ?? '000-000000-00'}\nTitular: ${cfg.titularCuenta ?? 'ObraControl Ingeniería S.A.S.'} (NIT: ${cfg.nitOIdentificacion ?? '900.000.000-1'})',
                                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('CANCELAR'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0500D0),
                  side: const BorderSide(color: Color(0xFF0500D0)),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('PREVISUALIZAR'),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  await PdfService.previsualizarCuentaCobroPdf(
                    numeroFolio: folioCtrl.text.trim().isNotEmpty ? folioCtrl.text.trim() : folioSugerido,
                    deudorNombre: deudorCtrl.text.trim().isNotEmpty ? deudorCtrl.text.trim() : deudorSugerido,
                    deudorNitOCedula: nitCtrl.text.trim().isNotEmpty ? nitCtrl.text.trim() : null,
                    frenteObraOLote: frenteCtrl.text.trim().isNotEmpty ? frenteCtrl.text.trim() : frenteSugerido,
                    itemsCobro: items,
                    totalCobro: totalCobro,
                    configuracion: cfg,
                    fechaEmisionTexto: fechaCtrl.text.trim().isNotEmpty ? fechaCtrl.text.trim() : DateFormat('dd/MM/yyyy').format(DateTime.now()),
                  );
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0500D0),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('DESCARGAR PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogCtx);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Generando y descargando Cuenta de Cobro en PDF...'),
                        ],
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  await PdfService.descargarCuentaCobroPdf(
                    numeroFolio: folioCtrl.text.trim().isNotEmpty ? folioCtrl.text.trim() : folioSugerido,
                    deudorNombre: deudorCtrl.text.trim().isNotEmpty ? deudorCtrl.text.trim() : deudorSugerido,
                    deudorNitOCedula: nitCtrl.text.trim().isNotEmpty ? nitCtrl.text.trim() : null,
                    frenteObraOLote: frenteCtrl.text.trim().isNotEmpty ? frenteCtrl.text.trim() : frenteSugerido,
                    itemsCobro: items,
                    totalCobro: totalCobro,
                    configuracion: cfg,
                    fechaEmisionTexto: fechaCtrl.text.trim().isNotEmpty ? fechaCtrl.text.trim() : DateFormat('dd/MM/yyyy').format(DateTime.now()),
                  );
                  if (mounted) {
                    setState(() {
                      _modoSeleccionCxC = false;
                      _itemsCobroSeleccionados.clear();
                    });
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Cuenta de cobro oficial generada y descargada con éxito.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // MÓDULO DE CUENTAS POR PAGAR (CxP - PESTAÑA 3)
  // =========================================================================
  void _mostrarDialogoAbonarTrabajadorCxP({
    required String semanaId,
    required String semanaNombre,
    required RegistroNominaItem registro,
  }) {
    final montoCtrl = TextEditingController(
      text: registro.saldoPendiente > 0 ? registro.saldoPendiente.toInt().toString() : '',
    );
    final conceptoCtrl = TextEditingController(text: 'Abono de nómina - $semanaNombre');
    String metodoPago = 'Efectivo';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x1A0500D0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.attach_money, color: Color(0xFF0500D0), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Abonar a ${registro.trabajadorNombre}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(semanaNombre, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Saldo pendiente actual:', style: TextStyle(fontSize: 12)),
                      Text(
                        _cop.format(registro.saldoPendiente),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0500D0)),
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
                    if (val != null) setDialogState(() => metodoPago = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0500D0),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final monto = double.tryParse(montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                if (monto != null && monto > 0) {
                  final messenger = ScaffoldMessenger.of(context);
                  await _firestoreService.registrarAbonoTrabajador(
                    semanaId: semanaId,
                    trabajadorId: registro.trabajadorId,
                    monto: monto,
                    concepto: conceptoCtrl.text.trim().isNotEmpty ? conceptoCtrl.text.trim() : null,
                    metodoPago: metodoPago,
                  );
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Pago de ${_cop.format(monto)} registrado a ${registro.trabajadorNombre}.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('CONFIRMAR PAGO'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirTabCuentasPorPagar(ProyectoProvider proyecto) {
    final double pasivoManoObra = proyecto.calcularNominaSaldoPendiente();
    final double pasivoProveedores = proyecto.totalPasivoProveedores;
    final double totalPasivos = proyecto.totalPasivosExigibles;

    // Recolectar todos los trabajadores con saldo pendiente en las semanas
    final List<Map<String, dynamic>> deudasNomina = [];
    for (final semana in proyecto.semanas) {
      for (final reg in semana.registros) {
        if (reg.saldoPendiente > 0) {
          deudasNomina.add({
            'semanaId': semana.id,
            'semanaNombre': semana.nombre,
            'registro': reg,
          });
        }
      }
    }

    // Filtrar según _filtroRolCxP
    final deudasFiltradas = deudasNomina.where((item) {
      final reg = item['registro'] as RegistroNominaItem;
      if (_filtroRolCxP == 'Solo Técnicos') {
        return !reg.esAyudante;
      } else if (_filtroRolCxP == 'Solo Ayudantes') {
        return reg.esAyudante;
      }
      return true;
    }).toList();

    // Gastos a crédito con proveedores
    final gastosCredito = proyecto.gastos.where((g) => g.esCreditoPendiente).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TARJETA MÉTRICA CONSOLIDADA SUPERIOR
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: const Color(0xFF7F1D1D),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.pending_actions_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL CUENTAS POR PAGAR (CxP)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Pasivos Exigibles Pendientes de Desembolso',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _cop.format(totalPasivos),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pasivo de Mano de Obra',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _cop.format(pasivoManoObra),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: Colors.white24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pasivo con Proveedores',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _cop.format(pasivoProveedores),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN 1: PASIVOS DE MANO DE OBRA (PERSONAL DE OBRA)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.engineering_outlined, color: Color(0xFF0500D0), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Pasivos de Nómina (Personal de Obra)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          '${deudasNomina.length} trabajador(es) con saldo',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Saldo pendiente consolidado acumulado con técnicos y ayudantes (Devengado - Vales - Pagos).',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),

                  // FILTROS RÁPIDOS POR ROL
                  Row(
                    children: ['Todos', 'Solo Técnicos', 'Solo Ayudantes'].map((filtro) {
                      final isSelected = _filtroRolCxP == filtro;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            filtro,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0x1A0500D0),
                          visualDensity: VisualDensity.compact,
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF0500D0) : Colors.grey.shade700,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _filtroRolCxP = filtro);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // LISTADO DISCRIMINADO DE TRABAJADORES CON DEUDA ACTIVA
                  if (deudasFiltradas.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 36),
                          const SizedBox(height: 6),
                          Text(
                            deudasNomina.isEmpty
                                ? '¡Al día! No hay nómina pendiente por pagar en el proyecto.'
                                : 'No hay trabajadores con saldo pendiente para el filtro seleccionado.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade900),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: deudasFiltradas.length,
                      itemBuilder: (context, index) {
                        final item = deudasFiltradas[index];
                        final semanaId = item['semanaId'] as String;
                        final semanaNombre = item['semanaNombre'] as String;
                        final reg = item['registro'] as RegistroNominaItem;
                        final double abonosVales = reg.totalPagado + reg.totalAdelantos;

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.red.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: reg.esAyudante ? Colors.teal.shade50 : const Color(0x1A0500D0),
                                      child: Icon(
                                        reg.esAyudante ? Icons.handyman_outlined : Icons.engineering_outlined,
                                        color: reg.esAyudante ? Colors.teal.shade700 : const Color(0xFF0500D0),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reg.trabajadorNombre,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${reg.rol} • $semanaNombre',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Text(
                                        'Deuda Activa',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Devengado', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                          Text(_cop.format(reg.totalGenerado), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text('Abonos / Vales', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                          Text(_cop.format(abonosVales), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('Saldo Pendiente', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                          Text(
                                            _cop.format(reg.saldoPendiente),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.red.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0500D0),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.payment, size: 16),
                                      label: const Text('Abonar / Liquidar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => _mostrarDialogoAbonarTrabajadorCxP(
                                        semanaId: semanaId,
                                        semanaNombre: semanaNombre,
                                        registro: reg,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN 2: PASIVO CON PROVEEDORES / GASTOS A CRÉDITO
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storefront_outlined, color: Color(0xFF0500D0), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Pasivos con Proveedores / Gastos a Crédito',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x1A0500D0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _cop.format(pasivoProveedores),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0500D0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compras de materiales o insumos registradas a crédito pendientes de pago a proveedores.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),

                  if (gastosCredito.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: Colors.grey.shade400, size: 32),
                          const SizedBox(height: 6),
                          Text(
                            'No hay compras o gastos a crédito pendientes con proveedores.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: gastosCredito.length,
                      itemBuilder: (context, index) {
                        final g = gastosCredito[index];
                        final prov = (g.proveedor != null && g.proveedor!.trim().isNotEmpty)
                            ? g.proveedor!.trim()
                            : 'Proveedor de Obra';
                        final fechaStr = DateFormat('dd/MM/yyyy').format(g.fecha);

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.amber.shade50,
                              child: Icon(Icons.receipt_outlined, color: Colors.amber.shade900, size: 20),
                            ),
                            title: Text(prov, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('${g.categoria} - ${g.descripcion} • $fechaStr', style: const TextStyle(fontSize: 11)),
                            trailing: Text(
                              _cop.format(g.monto),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7F1D1D)),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
