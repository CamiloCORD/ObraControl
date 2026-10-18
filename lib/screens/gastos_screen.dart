import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/gasto_model.dart';
import '../providers/proyecto_provider.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  String? _descargandoGastoId;
  bool _modoSeleccion = false;
  final Set<String> _gastosSeleccionadosIds = {};
  bool _generandoConsolidadoPdf = false;
  String _filtroTipoGasto = 'Todos'; // 'Todos', 'Solo Operativos', 'Abonos Nómina'
  bool _sincronizandoNomina = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconciliarSilencioso();
    });
  }

  Future<void> _reconciliarSilencioso() async {
    final proyecto = Provider.of<ProyectoProvider>(context, listen: false);
    if (proyecto.semanaActiva != null) {
      try {
        await proyecto.limpiarYReconciliarGastosNomina();
      } catch (e) {
        debugPrint('[GastosScreen] Reconciliación automática inicial omitida: $e');
      }
    }
  }

  Future<void> _ejecutarReconciliacionManual() async {
    final proyecto = Provider.of<ProyectoProvider>(context, listen: false);
    if (proyecto.semanaActiva == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay una semana activa para reconciliar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sincronizandoNomina = true);
    try {
      final res = await proyecto.limpiarYReconciliarGastosNomina();
      if (!mounted) return;
      final int eliminados = res['eliminados'] ?? 0;
      final int sincronizados = res['sincronizados'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0500D0),
          content: Row(
            children: [
              const Icon(Icons.verified, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Saneamiento exitoso: $eliminados registros obsoletos purgados, $sincronizados abonos consolidados.',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Error al ejecutar saneamiento: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sincronizandoNomina = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final proyecto = Provider.of<ProyectoProvider>(context);
    final semanaActiva = proyecto.semanaActiva;
    final todosGastos = proyecto.gastosSemana;
    final operativos = proyecto.gastosSemanaOperativos;
    final nomina = proyecto.gastosSemanaNomina;

    // ÚNICA FUENTE DE LA VERDAD: SemanaModel.registros de la semana activa
    final double totalNominaPagadaOficial = (semanaActiva != null && semanaActiva.registros.isNotEmpty)
        ? semanaActiva.registros.fold<double>(0.0, (acc, reg) => acc + reg.totalPagado)
        : proyecto.totalGastosNominaSemanaActual;

    final int cantidadPagosOficiales = (semanaActiva != null && semanaActiva.registros.isNotEmpty)
        ? semanaActiva.registros.fold<int>(
            0,
            (acc, reg) => acc + (reg.pagos.isNotEmpty ? reg.pagos.length : (reg.totalPagado > 0 ? 1 : 0)),
          )
        : nomina.length;

    // Total Egresos Real = Gastos Operativos + Abonos Nómina Oficiales ($5.390.000 COP)
    final double totalEgresosCalculado =
        proyecto.totalGastosOperativosSemanaActual + totalNominaPagadaOficial;

    final List<GastoModel> gastos;
    if (_filtroTipoGasto == 'Solo Operativos') {
      gastos = operativos;
    } else if (_filtroTipoGasto == 'Abonos Nómina') {
      gastos = nomina;
    } else {
      gastos = todosGastos;
    }

    final fCop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    final totalSeleccionado = gastos
        .where((g) => _gastosSeleccionadosIds.contains(g.id))
        .fold<double>(0.0, (acc, g) => acc + g.monto);

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.6),
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Egresos Semana:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black54),
                        ),
                        Text(
                          fCop.format(totalEgresosCalculado),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Tooltip(
                          message: 'Sincronizar y auditar abonos con planilla de nómina',
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal.shade800,
                              side: BorderSide(color: Colors.teal.shade400),
                              backgroundColor: Colors.teal.shade50.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            ),
                            icon: _sincronizandoNomina
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                                  )
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(
                              _sincronizandoNomina ? 'Saneando...' : 'Sincronizar Nómina',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            onPressed: _sincronizandoNomina ? null : _ejecutarReconciliacionManual,
                          ),
                        ),
                        if (todosGastos.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0500D0),
                              side: const BorderSide(color: Color(0xFF0500D0)),
                              backgroundColor: _modoSeleccion
                                  ? const Color(0xFF0500D0).withValues(alpha: 0.08)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: Icon(
                              _modoSeleccion ? Icons.checklist_rtl : Icons.checklist,
                              size: 18,
                            ),
                            label: Text(
                              _modoSeleccion ? 'Cerrar Selección' : 'Seleccionar',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _modoSeleccion = !_modoSeleccion;
                                if (!_modoSeleccion) {
                                  _gastosSeleccionadosIds.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Tarjetas de Discriminación: Gastos Operativos vs Abonos de Nómina
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.construction_rounded, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Text(
                                    'Gastos Operativos',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              fCop.format(proyecto.totalGastosOperativosSemanaActual),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                            Text(
                              '${operativos.length} compras/servicios',
                              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.people_alt_outlined, size: 14, color: Colors.teal.shade700),
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Text(
                                    'Abonos Nómina',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              fCop.format(totalNominaPagadaOficial),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                            ),
                            Text(
                              '$cantidadPagosOficiales pagos en planilla',
                              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Selector de Chips rápidos para filtrar la lista
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Todos (${todosGastos.length})'),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: _filtroTipoGasto == 'Todos' ? FontWeight.bold : FontWeight.normal,
                          color: _filtroTipoGasto == 'Todos' ? Colors.white : Colors.black87,
                        ),
                        selected: _filtroTipoGasto == 'Todos',
                        selectedColor: const Color(0xFF0500D0),
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        onSelected: (val) {
                          if (val) setState(() => _filtroTipoGasto = 'Todos');
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('Solo Operativos (${operativos.length})'),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: _filtroTipoGasto == 'Solo Operativos' ? FontWeight.bold : FontWeight.normal,
                          color: _filtroTipoGasto == 'Solo Operativos' ? Colors.white : Colors.black87,
                        ),
                        selected: _filtroTipoGasto == 'Solo Operativos',
                        selectedColor: const Color(0xFF0500D0),
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        onSelected: (val) {
                          if (val) setState(() => _filtroTipoGasto = 'Solo Operativos');
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('Abonos Nómina (${nomina.length})'),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: _filtroTipoGasto == 'Abonos Nómina' ? FontWeight.bold : FontWeight.normal,
                          color: _filtroTipoGasto == 'Abonos Nómina' ? Colors.white : Colors.black87,
                        ),
                        selected: _filtroTipoGasto == 'Abonos Nómina',
                        selectedColor: const Color(0xFF0500D0),
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        onSelected: (val) {
                          if (val) setState(() => _filtroTipoGasto = 'Abonos Nómina');
                        },
                      ),
                    ],
                  ),
                ),

                if (_modoSeleccion) ...[
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_gastosSeleccionadosIds.length} de ${gastos.length} seleccionados',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () {
                              setState(() {
                                if (_gastosSeleccionadosIds.length == gastos.length) {
                                  _gastosSeleccionadosIds.clear();
                                } else {
                                  _gastosSeleccionadosIds.addAll(gastos.map((g) => g.id));
                                }
                              });
                            },
                            child: Text(
                              _gastosSeleccionadosIds.length == gastos.length
                                  ? 'Deseleccionar todos'
                                  : 'Seleccionar todos',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: gastos.isEmpty
                ? Center(
                    child: Text(
                      _filtroTipoGasto == 'Solo Operativos'
                          ? 'No hay gastos operativos registrados en esta semana.'
                          : _filtroTipoGasto == 'Abonos Nómina'
                              ? 'No hay abonos de nómina registrados en esta semana.'
                              : 'No hay gastos registrados en esta semana.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: gastos.length,
                    itemBuilder: (context, index) {
                      final g = gastos[index];
                      final isDownloading = _descargandoGastoId == g.id;
                      final isSelected = _gastosSeleccionadosIds.contains(g.id);
                      final esNomina = g.esAutomaticoNomina ||
                          g.categoria == 'Pagos a Trabajadores' ||
                          (g.abonoId != null && g.abonoId!.isNotEmpty);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        elevation: isSelected ? 2 : 1,
                        color: isSelected ? const Color(0xFF0500D0).withValues(alpha: 0.05) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF0500D0) : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            if (_modoSeleccion) {
                              setState(() {
                                if (isSelected) {
                                  _gastosSeleccionadosIds.remove(g.id);
                                } else {
                                  _gastosSeleccionadosIds.add(g.id);
                                }
                              });
                            } else {
                              _mostrarDetalleGasto(context, g, fCop);
                            }
                          },
                          onLongPress: () {
                            if (!_modoSeleccion) {
                              setState(() {
                                _modoSeleccion = true;
                                _gastosSeleccionadosIds.add(g.id);
                              });
                            }
                          },
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_modoSeleccion) ...[
                                Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFF0500D0),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _gastosSeleccionadosIds.add(g.id);
                                      } else {
                                        _gastosSeleccionadosIds.remove(g.id);
                                      }
                                    });
                                  },
                                ),
                              ],
                              CircleAvatar(
                                backgroundColor: esNomina
                                    ? Colors.teal.shade50
                                    : Colors.blue.shade50,
                                child: Icon(
                                  esNomina ? Icons.people_alt_outlined : Icons.construction_rounded,
                                  color: esNomina
                                      ? Colors.teal.shade700
                                      : const Color(0xFF0500D0),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            '${g.categoria} - ${fCop.format(g.monto)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            g.descripcion.isNotEmpty
                                ? g.descripcion
                                : (esNomina ? 'Abono / Pago de Nómina' : 'Gasto operativo'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isDownloading)
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0500D0),
                                    ),
                                  ),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF0500D0)),
                                  tooltip: 'Descargar Comprobante PDF',
                                  onPressed: () => _descargarPdfGasto(g),
                                ),
                              if (esNomina)
                                const Tooltip(
                                  message: 'Abono sincronizado desde nómina de personal',
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.sync_alt, color: Colors.teal),
                                  ),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Eliminar gasto operativo',
                                  onPressed: () => _confirmarEliminarGasto(context, g.id),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _modoSeleccion
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_gastosSeleccionadosIds.length} gastos seleccionados',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Total: ${fCop.format(totalSeleccionado)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0500D0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _modoSeleccion = false;
                              _gastosSeleccionadosIds.clear();
                            });
                          },
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0500D0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _generandoConsolidadoPdf
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text(
                            'Generar PDF Agrupado',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: _generandoConsolidadoPdf
                              ? null
                              : () => _generarComprobanteConsolidado(gastos),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: _modoSeleccion
          ? null
          : FloatingActionButton(
              backgroundColor: const Color(0xFF0500D0),
              onPressed: () => _mostrarModalNuevoGasto(context, proyecto),
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Future<void> _generarComprobanteConsolidado(List<GastoModel> todosLosGastos) async {
    final seleccionados = todosLosGastos
        .where((g) => _gastosSeleccionadosIds.contains(g.id))
        .toList();

    if (seleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona al menos un gasto para generar el comprobante consolidado.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _generandoConsolidadoPdf = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text('Generando comprobante consolidado (${seleccionados.length} gastos)...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final cfg = Provider.of<ProyectoProvider>(context, listen: false).configuracion;
      await PdfService.descargarComprobanteGastosConsolidadoPdf(seleccionados, configuracion: cfg);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comprobante consolidado de gastos generado y descargado correctamente.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF consolidado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generandoConsolidadoPdf = false);
      }
    }
  }

  Future<void> _descargarPdfGasto(GastoModel g) async {
    setState(() => _descargandoGastoId = g.id);
    try {
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
                Text('Generando comprobante de egreso PDF...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      final cfg = Provider.of<ProyectoProvider>(context, listen: false).configuracion;
      await PdfService.descargarComprobanteGastoPdf(g, configuracion: cfg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comprobante PDF generado y descargado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _descargandoGastoId = null);
      }
    }
  }

  Future<void> _confirmarEliminarGasto(BuildContext context, String gastoId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Gasto'),
        content: const Text('¿Estás seguro de que deseas eliminar este gasto operacional?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await FirestoreService().eliminarGasto(gastoId);
    }
  }

  void _mostrarDetalleGasto(BuildContext context, GastoModel g, NumberFormat fCop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF0500D0)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Comprobante de Gasto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0500D0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  g.categoria.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF0500D0),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _infoItem('Monto:', fCop.format(g.monto), destacada: true),
              _infoItem('Fecha:', DateFormat('dd/MM/yyyy HH:mm').format(g.fecha)),
              _infoItem('Descripción:', g.descripcion.isNotEmpty ? g.descripcion : 'Sin descripción'),
              if (g.proveedor != null && g.proveedor!.trim().isNotEmpty)
                _infoItem('Beneficiario / Proveedor:', g.proveedor!),
              if (g.loteNombre != null && g.loteNombre!.trim().isNotEmpty)
                _infoItem('Lote / Obra:', g.loteNombre!),
              _infoItem('Origen:', g.esAutomaticoNomina ? 'Sincronizado de Nómina' : 'Gasto Manual'),
              if (g.id.isNotEmpty) _infoItem('ID de Registro:', g.id),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Previsualizar'),
            onPressed: () {
              Navigator.pop(ctx);
              final cfg = Provider.of<ProyectoProvider>(context, listen: false).configuracion;
              PdfService.previsualizarComprobanteGastoPdf(g, configuracion: cfg);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0500D0),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Descargar PDF'),
            onPressed: () {
              Navigator.pop(ctx);
              _descargarPdfGasto(g);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String valor, {bool destacada = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: destacada ? 16 : 14,
              fontWeight: destacada ? FontWeight.bold : FontWeight.w500,
              color: destacada ? const Color(0xFF0500D0) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarModalNuevoGasto(BuildContext context, ProyectoProvider proyecto) {
    final descCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final provCtrl = TextEditingController();
    String categoria = 'Materiales';
    String? loteSeleccionado;
    final categorias = ['Comida', 'Arriendo', 'Transporte', 'Materiales', 'Herramientas', 'Otros'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text('Registrar Gasto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setStateModal(() => categoria = val);
                    }
                  },
                ),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monto (\$)'),
                ),
                TextField(
                  controller: provCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Beneficiario / Proveedor (Opcional)',
                    hintText: 'Nombre de quien recibe el pago',
                  ),
                ),
                if (proyecto.lotes.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: loteSeleccionado,
                    decoration: const InputDecoration(labelText: 'Lote / Obra (Opcional)'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Ninguno / Obra General'),
                      ),
                      ...proyecto.lotes.map(
                        (l) => DropdownMenuItem<String?>(
                          value: l.nombre,
                          child: Text(l.nombre),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setStateModal(() => loteSeleccionado = val);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0500D0),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final monto = double.tryParse(montoCtrl.text) ?? 0;
                if (monto <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa un monto válido mayor a 0.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (proyecto.semanaActiva == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No hay una semana activa. Inicia una semana en Nómina primero.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                final nuevoGasto = GastoModel(
                  id: '',
                  semanaId: proyecto.semanaActiva!.id,
                  categoria: categoria,
                  descripcion: descCtrl.text.trim(),
                  monto: monto,
                  fecha: DateTime.now(),
                  esAutomaticoNomina: false,
                  proveedor: provCtrl.text.trim().isNotEmpty ? provCtrl.text.trim() : null,
                  loteNombre: loteSeleccionado,
                );
                await FirestoreService().guardarGasto(nuevoGasto);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gasto registrado con éxito'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}