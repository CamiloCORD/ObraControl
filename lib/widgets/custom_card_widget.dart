import 'package:flutter/material.dart';

class CustomCardWidget extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  final String? subtitulo;

  const CustomCardWidget({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(30),
              radius: 24,
              child: Icon(icono, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitulo!, style: TextStyle(fontSize: 11, color: color)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}