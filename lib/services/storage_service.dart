import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  /// Selecciona fotos de la galería, las comprime, las sube a Firebase Storage
  /// y actualiza el documento de la vivienda en Firestore con arrayUnion.
  Future<List<String>> seleccionarComprimirYSubir(String viviendaId) async {
    final List<String> urlsDescarga = [];

    try {
      final List<XFile> imagenes = await _picker.pickMultiImage(imageQuality: 80);
      if (imagenes.isEmpty) return urlsDescarga;

      for (final imagen in imagenes) {
        final Uint8List bytesOriginales = await imagen.readAsBytes();

        // Compresión agresiva manteniendo calidad técnica
        final Uint8List bytesComprimidos =
            await FlutterImageCompress.compressWithList(
          bytesOriginales,
          minWidth: 1024,
          minHeight: 1024,
          quality: 60,
          format: CompressFormat.jpeg,
        );

        final String ts = DateTime.now().millisecondsSinceEpoch.toString();
        final String nombreArchivo = '${ts}_${viviendaId.replaceAll('-', '_')}.jpg';
        final Reference ref = _storage
            .ref()
            .child('viviendas')
            .child(viviendaId)
            .child(nombreArchivo);

        final TaskSnapshot snapshot = await ref.putData(
          bytesComprimidos,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        final String url = await snapshot.ref.getDownloadURL();
        urlsDescarga.add(url);
      }

      // Persistir las URLs en Firestore usando arrayUnion
      if (urlsDescarga.isNotEmpty) {
        await _db.collection('viviendas').doc(viviendaId).update({
          'fotos': FieldValue.arrayUnion(urlsDescarga),
          'fotosUrls': FieldValue.arrayUnion(urlsDescarga),
        });
      }
    } catch (e) {
      debugPrint('[StorageService] Error al subir fotos: $e');
      rethrow;
    }

    return urlsDescarga;
  }

  /// Sube el logo institucional de la empresa a Firebase Storage en la ruta
  /// `configuracion/logo_empresa.{ext}` y retorna su URL de descarga pública.
  Future<String> subirLogoEmpresa(Uint8List bytes, String extension) async {
    try {
      final cleanExt = extension.replaceAll('.', '').toLowerCase().trim();
      String contentType = 'image/jpeg';
      if (cleanExt == 'png') {
        contentType = 'image/png';
      } else if (cleanExt == 'webp') {
        contentType = 'image/webp';
      } else if (cleanExt == 'svg') {
        contentType = 'image/svg+xml';
      } else if (cleanExt == 'gif') {
        contentType = 'image/gif';
      }

      final String nombreArchivo = 'logo_empresa.$cleanExt';
      final Reference ref = _storage.ref().child('configuracion').child(nombreArchivo);

      final TaskSnapshot snapshot = await ref.putData(
        bytes,
        SettableMetadata(
          contentType: contentType,
          cacheControl: 'no-cache, max-age=0',
        ),
      );

      final String url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('[StorageService] Error al subir logo de empresa: $e');
      rethrow;
    }
  }
}