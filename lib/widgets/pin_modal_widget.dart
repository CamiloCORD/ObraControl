import 'package:flutter/material.dart';

class PinModalWidget extends StatefulWidget {
  final Function(String pin) onPinConfirmado;
  final String titulo;
  final String mensaje;

  const PinModalWidget({
    super.key,
    required this.onPinConfirmado,
    this.titulo = 'Seguridad del Dueño',
    this.mensaje = 'Ingresa tu PIN de 4 dígitos para autorizar la acción:',
  });

  @override
  State<PinModalWidget> createState() => _PinModalWidgetState();
}

class _PinModalWidgetState extends State<PinModalWidget> {
  final TextEditingController _pinController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock, color: Color(0xFF0D47A1)),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.titulo, style: const TextStyle(fontSize: 16))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.mensaje),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              counterText: '',
              border: OutlineInputBorder(),
              hintText: '••••',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
          onPressed: () {
            if (_pinController.text.length == 4) {
              Navigator.pop(context);
              widget.onPinConfirmado(_pinController.text);
            }
          },
          child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}