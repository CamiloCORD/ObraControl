import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> descargarArchivo(List<int> bytes, String nombreArchivo) async {
  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {}
  dir ??= await getApplicationDocumentsDirectory();

  final file = File('${dir.path}/$nombreArchivo');
  await file.writeAsBytes(bytes);

  // Compartir o abrir archivo en dispositivo móvil
  // ignore: deprecated_member_use
  await Share.shareXFiles([XFile(file.path)], text: 'Evidencia fotográfica: $nombreArchivo');
}

Future<void> descargarDeUrl(String url, String nombreArchivo) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    await descargarArchivo(response.bodyBytes, nombreArchivo);
  } else {
    throw Exception('Error al descargar imagen: HTTP ${response.statusCode}');
  }
}
