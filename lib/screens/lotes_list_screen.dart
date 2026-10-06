import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/lote_model.dart';
import '../providers/proyecto_provider.dart';
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
