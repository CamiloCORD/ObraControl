import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/gasto_model.dart';
import '../providers/proyecto_provider.dart';
import '../services/firestore_service.dart';

class GastosScreen extends StatelessWidget {
  const GastosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final proyecto = Provider.of<ProyectoProvider>(context);
    final gastos = proyecto.gastosSemana;
    final fCop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Gastos de la Semana:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(fCop.format(proyecto.totalGastosSemanaActual),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
              ],
            ),
          ),
          Expanded(
            child: gastos.isEmpty
                ? const Center(child: Text('No hay gastos registrados en esta semana.'))
                : ListView.builder(
                    itemCount: gastos.length,
                    itemBuilder: (context, index) {
                      final g = gastos[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: g.esAutomaticoNomina ? Colors.green.shade100 : Colors.blue.shade100,
                          child: Icon(
                            g.esAutomaticoNomina ? Icons.people : Icons.receipt_long,
                            color: g.esAutomaticoNomina ? Colors.green : Colors.blue,
                          ),
                        ),
                        title: Text('${g.categoria} - ${fCop.format(g.monto)}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(g.descripcion),
                        trailing: g.esAutomaticoNomina
                            ? const Tooltip(
                                message: 'Sincronizado de nómina',
                                child: Icon(Icons.sync, color: Colors.grey),
                              )
                            : IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => FirestoreService().eliminarGasto(g.id),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0D47A1),
        onPressed: () => _mostrarModalNuevoGasto(context, proyecto),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _mostrarModalNuevoGasto(BuildContext context, ProyectoProvider proyecto) {
    final descCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String categoria = 'Materiales';
    final categorias = ['Comida', 'Arriendo', 'Transporte', 'Materiales', 'Otros'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text('Registrar Gasto'),
          content: Column(
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
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
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