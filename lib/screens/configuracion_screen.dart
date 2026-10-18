import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../models/configuracion_model.dart';
import '../providers/auth_provider.dart';
import '../providers/proyecto_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  // Controladores de Identidad de Marca
  final _nombreEmpresaCtrl = TextEditingController();
  String? _logoUrl;
  Uint8List? _logoBytesPreview;
  bool _subiendoLogo = false;
  int _colorPrimarioSeleccionado = 0xFF0500D0;

  // Controladores Operativos y Financieros
  final _tarifaClienteCtrl = TextEditingController();
  final _tarifaTecnicoCtrl = TextEditingController();
  final _tarifaAyudanteCtrl = TextEditingController();
  final _ahorroCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  final _tipoCuentaCtrl = TextEditingController();
  final _numeroCuentaCtrl = TextEditingController();
  final _titularCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();

  static const List<Map<String, dynamic>> _paletaIngenieria = [
    {'nombre': 'Azul Obra', 'hex': 0xFF0500D0},
    {'nombre': 'Azul Marino', 'hex': 0xFF0D47A1},
    {'nombre': 'Naranja Obra', 'hex': 0xFFE65100},
    {'nombre': 'Verde Industrial', 'hex': 0xFF1B5E20},
    {'nombre': 'Rojo Carmesí', 'hex': 0xFFB71C1C},
    {'nombre': 'Gris Grafito', 'hex': 0xFF37474F},
  ];

  @override
  void initState() {
    super.initState();
    final cfg = Provider.of<ProyectoProvider>(context, listen: false).configuracion;
    _nombreEmpresaCtrl.text = cfg.nombreEmpresa;
    _logoUrl = cfg.logoUrl;
    _colorPrimarioSeleccionado = cfg.colorPrimario;

    _tarifaClienteCtrl.text = cfg.tarifaCliente.toStringAsFixed(0);
    _tarifaTecnicoCtrl.text = cfg.tarifaTecnico.toStringAsFixed(0);
    _tarifaAyudanteCtrl.text = cfg.tarifaAyudante.toStringAsFixed(0);
    _ahorroCtrl.text = cfg.porcentajeAhorro.toStringAsFixed(0);
    _pinCtrl.text = cfg.pinSeguridad;
    _bancoCtrl.text = cfg.bancoNombre ?? 'Bancolombia';
    _tipoCuentaCtrl.text = cfg.tipoCuenta ?? 'Cuenta de Ahorros';
    _numeroCuentaCtrl.text = cfg.numeroCuenta ?? '000-000000-00';
    _titularCtrl.text = cfg.titularCuenta ?? 'ObraControl Ingeniería S.A.S.';
    _nitCtrl.text = cfg.nitOIdentificacion ?? '900.000.000-1';
  }

  @override
  void dispose() {
    _nombreEmpresaCtrl.dispose();
    _tarifaClienteCtrl.dispose();
    _tarifaTecnicoCtrl.dispose();
    _tarifaAyudanteCtrl.dispose();
    _ahorroCtrl.dispose();
    _pinCtrl.dispose();
    _bancoCtrl.dispose();
    _tipoCuentaCtrl.dispose();
    _numeroCuentaCtrl.dispose();
    _titularCtrl.dispose();
    _nitCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarYSubirLogo() async {
    try {
      final List<PlatformFile> archivos = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (archivos.isEmpty) return;

      final file = archivos.first;
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron leer los datos del archivo seleccionado.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _subiendoLogo = true;
      });

      final extension = file.extension ?? 'png';
      final url = await StorageService().subirLogoEmpresa(bytes, extension);

      if (!mounted) return;
      setState(() {
        _logoUrl = url;
        _logoBytesPreview = bytes;
        _subiendoLogo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo de empresa subido correctamente a Firebase Storage.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _subiendoLogo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir el logo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _mostrarDialogoColorPersonalizado() async {
    final hexController = TextEditingController(
      text: '#${_colorPrimarioSeleccionado.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );
    String? errorTexto;

    final colorElegido = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.palette_outlined, color: Color(0xFF0500D0)),
              SizedBox(width: 8),
              Text('Color Primario Personalizado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa el código Hexadecimal del color deseado para la interfaz:',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hexController,
                decoration: InputDecoration(
                  labelText: 'Código Hex (#RRGGBB)',
                  hintText: '#0500D0',
                  errorText: errorTexto,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.colorize),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                String hex = hexController.text.trim().replaceAll('#', '').replaceAll('0x', '');
                if (hex.length == 6) {
                  hex = 'FF$hex';
                }
                final parsed = int.tryParse(hex, radix: 16);
                if (parsed != null && (hex.length == 8)) {
                  Navigator.pop(ctx, parsed);
                } else {
                  setDialogState(() {
                    errorTexto = 'Formato inválido. Ejemplo: #0500D0';
                  });
                }
              },
              child: const Text('APLICAR'),
            ),
          ],
        ),
      ),
    );

    if (colorElegido != null && mounted) {
      setState(() {
        _colorPrimarioSeleccionado = colorElegido;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final colorTema = Color(_colorPrimarioSeleccionado);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================================
            // 1. TARJETA DESTACADA: IDENTIDAD DE EMPRESA Y MARCA (MARCA BLANCA)
            // =================================================================
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorTema.withValues(alpha: 0.35), width: 1.8),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorTema.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.branding_watermark_rounded, color: colorTema, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Identidad de Empresa y Marca',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorTema,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Personaliza el nombre, logotipo institucional y apariencia de ObraControl.',
                                style: TextStyle(fontSize: 11.5, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Campo Nombre de Empresa
                    TextField(
                      controller: _nombreEmpresaCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la Empresa / Proyecto',
                        hintText: 'Ej. ObraControl, Constructora Andina S.A.S.',
                        prefixIcon: Icon(Icons.business_rounded, color: colorTema),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Selector y Visor de Logotipo
                    const Text(
                      'Logotipo Oficial de la Empresa',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _subiendoLogo
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                : _logoBytesPreview != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(_logoBytesPreview!, fit: BoxFit.contain),
                                      )
                                    : (_logoUrl != null && _logoUrl!.isNotEmpty)
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.network(
                                              _logoUrl!,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, _, _) => const Icon(
                                                Icons.broken_image_outlined,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.apartment_rounded,
                                              size: 38,
                                              color: colorTema.withValues(alpha: 0.6),
                                            ),
                                          ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _logoUrl != null ? 'Logo configurado y activo' : 'Sin logo cargado (usando ícono base)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _logoUrl != null ? Colors.green.shade700 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Formato PNG, JPG o WebP recomendado. Se incluirá en comprobantes y PDFs.',
                                  style: TextStyle(fontSize: 10.5, color: Colors.black54),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: colorTema,
                                        side: BorderSide(color: colorTema),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                                      label: Text(
                                        _logoUrl != null ? 'Cambiar Logo' : 'Subir Logo',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: _subiendoLogo ? null : _seleccionarYSubirLogo,
                                    ),
                                    if (_logoUrl != null || _logoBytesPreview != null)
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.delete_outline, size: 16),
                                        label: const Text('Quitar', style: TextStyle(fontSize: 11.5)),
                                        onPressed: () {
                                          setState(() {
                                            _logoUrl = null;
                                            _logoBytesPreview = null;
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Selector de Colores Primarios
                    const Text(
                      'Color Corporativo / Primario de la Aplicación',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Define el tono visual de las barras de navegación, botones y acentos de ObraControl.',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ..._paletaIngenieria.map((colorItem) {
                          final int hex = colorItem['hex'] as int;
                          final String nombre = colorItem['nombre'] as String;
                          final bool seleccionado = _colorPrimarioSeleccionado == hex;
                          final Color c = Color(hex);

                          return Tooltip(
                            message: nombre,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                setState(() {
                                  _colorPrimarioSeleccionado = hex;
                                });
                              },
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: seleccionado ? Colors.black87 : Colors.white,
                                    width: seleccionado ? 3 : 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: c.withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: seleccionado
                                    ? const Icon(Icons.check, color: Colors.white, size: 22)
                                    : null,
                              ),
                            ),
                          );
                        }),
                        // Botón de Color Personalizado
                        ActionChip(
                          avatar: Icon(Icons.colorize, size: 16, color: colorTema),
                          label: const Text('Personalizado', style: TextStyle(fontSize: 12)),
                          onPressed: _mostrarDialogoColorPersonalizado,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // =================================================================
            // 2. TARIFAS DINÁMICAS DEL PROYECTO
            // =================================================================
            Text(
              'Tarifas Dinámicas del Proyecto',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorTema),
            ),
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

            // =================================================================
            // 3. DATOS BANCARIOS OFICIALES (CUENTAS DE COBRO)
            // =================================================================
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorTema.withValues(alpha: 0.2), width: 1.5),
              ),
              color: const Color(0xFFF8F9FE),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorTema.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.account_balance, color: colorTema, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Datos Bancarios Oficiales (Cuentas de Cobro)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colorTema,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Aparecerán automáticamente en el pie de página de los PDFs para recibir transferencias.',
                                style: TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titularCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Titular de la Cuenta (Nombre de la Razón Social / Persona)',
                        hintText: 'Ej. ObraControl Ingeniería S.A.S.',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nitCtrl,
                            decoration: const InputDecoration(
                              labelText: 'NIT / C.C. Titular',
                              hintText: '900.000.000-1',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _bancoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Entidad Bancaria',
                              hintText: 'Bancolombia',
                              prefixIcon: Icon(Icons.storefront_outlined),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _tipoCuentaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Cuenta',
                              hintText: 'Ahorros / Corriente',
                              prefixIcon: Icon(Icons.credit_card_outlined),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _numeroCuentaCtrl,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Número de Cuenta',
                              hintText: '000-000000-00',
                              prefixIcon: Icon(Icons.tag),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // =================================================================
            // 4. AJUSTES EXCLUSIVOS DEL DUEÑO
            // =================================================================
            if (auth.esDueno) ...[
              Text(
                'Ajustes Exclusivos del Dueño',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorTema),
              ),
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

            // =================================================================
            // 5. BOTÓN GUARDAR AJUSTES
            // =================================================================
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTema,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  'GUARDAR CONFIGURACIÓN',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () async {
                  final nuevaConfig = ConfiguracionModel(
                    nombreEmpresa: _nombreEmpresaCtrl.text.trim().isNotEmpty
                        ? _nombreEmpresaCtrl.text.trim()
                        : 'ObraControl',
                    logoUrl: _logoUrl,
                    colorPrimario: _colorPrimarioSeleccionado,
                    tarifaCliente: double.tryParse(_tarifaClienteCtrl.text) ?? 120000,
                    tarifaTecnico: double.tryParse(_tarifaTecnicoCtrl.text) ?? 50000,
                    tarifaAyudante: double.tryParse(_tarifaAyudanteCtrl.text) ?? 50000,
                    porcentajeAhorro: double.tryParse(_ahorroCtrl.text) ?? 10,
                    pinSeguridad: _pinCtrl.text.isEmpty ? '1234' : _pinCtrl.text,
                    bancoNombre: _bancoCtrl.text.trim().isNotEmpty ? _bancoCtrl.text.trim() : 'Bancolombia',
                    tipoCuenta: _tipoCuentaCtrl.text.trim().isNotEmpty ? _tipoCuentaCtrl.text.trim() : 'Cuenta de Ahorros',
                    numeroCuenta: _numeroCuentaCtrl.text.trim().isNotEmpty ? _numeroCuentaCtrl.text.trim() : '000-000000-00',
                    titularCuenta: _titularCtrl.text.trim().isNotEmpty ? _titularCtrl.text.trim() : 'ObraControl Ingeniería S.A.S.',
                    nitOIdentificacion: _nitCtrl.text.trim().isNotEmpty ? _nitCtrl.text.trim() : '900.000.000-1',
                  );

                  await Provider.of<ProyectoProvider>(context, listen: false).guardarConfiguracion(nuevaConfig);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Configuración de marca y tarifas guardada correctamente.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
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