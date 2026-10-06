import 'package:flutter/material.dart';
import 'lotes_list_screen.dart';

export 'lotes_list_screen.dart';
export 'lote_detail_screen.dart';

class ViviendasScreen extends StatelessWidget {
  const ViviendasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LotesListScreen();
  }
}