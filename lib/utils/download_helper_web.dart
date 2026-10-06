// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:http/http.dart' as http;

Future<void> descargarArchivo(List<int> bytes, String nombreArchivo) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', nombreArchivo)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<void> descargarDeUrl(String url, String nombreArchivo) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await descargarArchivo(response.bodyBytes, nombreArchivo);
      return;
    }
  } catch (_) {}

  // Fallback directo por enlace de descarga en navegador
  html.AnchorElement(href: url)
    ..setAttribute('download', nombreArchivo)
    ..target = '_blank'
    ..click();
}
