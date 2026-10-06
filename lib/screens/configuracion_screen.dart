import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/configuracion_model.dart';
import '../providers/auth_provider.dart';
import '../providers/proyecto_provider.dart';
import '../services/firestore_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _tarifaClienteCtrl = TextEditingController();
  final _tarifaTecnicoCtrl = TextEditingController();
  final _tarifaAyudanteCtrl = TextEditingController();
  final _ahorroCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cfg = Provider.of<ProyectoProvider>(context, listen: false).configuracion;
    _tarifaClienteCtrl.text = cfg.tarifaCliente.toStringAsFixed(0);
    _tarifaTecnicoCtrl.text = cfg.tarifaTecnico.toStringAsFixed(0);
    _tarifaAyudanteCtrl.text = cfg.tarifaAyudante.toStringAsFixed(0);
    _ahorroCtrl.text = cfg.porcentajeAhorro.toStringAsFixed(0);
    _pinCtrl.text = cfg.pinSeguridad;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tarifas Dinámicas del Proyecto',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            const SizedBox(height: 12),
            TextField(
              controller: _tarifaClienteCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tarifa cobrada al Cliente por vivienda (\$)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tarifaTecnicoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tarifa pagada al Técnico por vivienda (\$)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tarifaAyudanteCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tarifa pagada al Ayudante por día (\$)'),
            ),
            const SizedBox(height: 20),

            if (auth.esDueno) ...[
              const Text('Ajustes Exclusivos del Dueño',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
              const SizedBox(height: 12),
              TextField(
                controller: _ahorroCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Porcentaje Fondo de Ahorro (%)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'PIN de Seguridad para Reaperturas (4 dígitos)'),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
                onPressed: () async {
                  final nuevaConfig = ConfiguracionModel(
                    tarifaCliente: double.tryParse(_tarifaClienteCtrl.text) ?? 120000,
                    tarifaTecnico: double.tryParse(_tarifaTecnicoCtrl.text) ?? 50000,
                    tarifaAyudante: double.tryParse(_tarifaAyudanteCtrl.text) ?? 50000,
                    porcentajeAhorro: double.tryParse(_ahorroCtrl.text) ?? 10,
                    pinSeguridad: _pinCtrl.text.isEmpty ? '1234' : _pinCtrl.text,
                  );
                  await FirestoreService().guardarConfiguracion(nuevaConfig);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Configuración guardada correctamente.'), backgroundColor: Colors.green),
                    );
                  }
                },
                child: const Text('GUARDAR AJUSTES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            if (auth.esDueno) ...[
              const SizedBox(height: 36),
              const Divider(color: Colors.redAccent, thickness: 1.2),
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.shade300, width: 1.5),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Zona de Mantenimiento de Producción',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vacía por completo todas las colecciones operativas (lotes, viviendas, trabajadores, asistencias, nóminas y gastos) para dejar la base de datos totalmente limpia y lista para datos reales.',
                        style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade800,
                            side: BorderSide(color: Colors.red.shade700, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: const Text(
                            'VACIAR BASE DE DATOS (RESET TOTAL)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: () => _confirmarLimpiezaTotal(
                            _pinCtrl.text.isEmpty ? '1234' : _pinCtrl.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarLimpiezaTotal(String pinConfigurado) async {
    final pinInputCtrl = TextEditingController();
    String? errorPin;

    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirmar Reset Total',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta acción es IRREVERSIBLE. Se eliminarán permanentemente:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Todos los lotes y viviendas\n• Todo el personal de trabajadores\n• Todo el historial de asistencias\n• Todas las nóminas y semanas\n• Todos los gastos y préstamos',
                  style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ingrese el PIN de Seguridad de 4 dígitos para autorizar:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pinInputCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'PIN de Seguridad',
                    errorText: errorPin,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (pinInputCtrl.text.trim() != pinConfigurado) {
                  setDialogState(() {
                    errorPin = 'PIN incorrecto. Verifique e intente de nuevo.';
                  });
                  return;
                }
                Navigator.pop(dialogCtx, true);
              },
              child: const Text('VACIAR TODO'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Vaciando colecciones de Firestore...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Por favor espere, no cierre la app.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final resultado = await FirestoreService().limpiarTodosLosDatos();
      if (!mounted) return;
      nav.pop();
      final totalEliminados = resultado.values.fold<int>(0, (a, b) => a + b);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Base de datos reseteada con éxito ($totalEliminados documentos eliminados). Sistema listo para producción.',
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al vaciar base de datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}