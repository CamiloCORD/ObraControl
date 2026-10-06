import 'package:flutter/material.dart';

class PinModalWidget extends StatefulWidget {
  final Function(String pin) onPinConfirmado;

  const PinModalWidget({super.key, required this.onPinConfirmado});

  @override
  State<PinModalWidget> createState() => _PinModalWidgetState();
}

class _PinModalWidgetState extends State<PinModalWidget> {
  final TextEditingController _pinController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock, color: Color(0xFF0D47A1)),
          SizedBox(width: 8),
          Text('Seguridad del Dueño', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ingresa tu PIN de 4 dígitos para autorizar la reapertura de la semana:'),
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