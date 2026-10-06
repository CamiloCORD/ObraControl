import 'package:flutter/material.dart';
import '../utils/download_helper.dart';

class FotoLightboxDialog extends StatefulWidget {
  final List<String> fotos;
  final int initialIndex;
  final String casaId;

  const FotoLightboxDialog({
    super.key,
    required this.fotos,
    this.initialIndex = 0,
    required this.casaId,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required List<String> fotos,
    int initialIndex = 0,
    required String casaId,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => FotoLightboxDialog(
        fotos: fotos,
        initialIndex: initialIndex,
        casaId: casaId,
      ),
    );
  }

  @override
  State<FotoLightboxDialog> createState() => _FotoLightboxDialogState();
}

class _FotoLightboxDialogState extends State<FotoLightboxDialog> {
  late PageController _pageController;
  late int _currentIndex;
  bool _descargando = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _descargarFotoActual() async {
    if (widget.fotos.isEmpty || _descargando) return;
    final url = widget.fotos[_currentIndex];
    final nombre = 'Evidencia_${widget.casaId}_foto_${_currentIndex + 1}.jpg';

    setState(() => _descargando = true);
    try {
      await descargarDeUrl(url, nombre);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Imagen guardada con éxito ($nombre)'),
              ],
            ),
            backgroundColor: const Color(0xFF0500D0),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fotos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // VISOR CON GESTOS Y PINCH-TO-ZOOM
            PageView.builder(
              controller: _pageController,
              itemCount: widget.fotos.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (ctx, idx) {
                final url = widget.fotos[idx];
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.5,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (c, child, progress) {
                        if (progress == null) return child;
                        final total = progress.expectedTotalBytes;
                        final loaded = progress.cumulativeBytesLoaded;
                        final pct = total != null && total > 0 ? (loaded / total) : null;
                        return Center(
                          child: CircularProgressIndicator(
                            value: pct,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (c, err, st) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.broken_image_outlined, size: 64, color: Colors.white54),
                          SizedBox(height: 12),
                          Text('No se pudo cargar la imagen', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // BARRA SUPERIOR DE ACCIONES Y CONTADOR
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'Casa ${widget.casaId}  •  ${_currentIndex + 1} / ${widget.fotos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // BOTÓN DESCARGA DIRECTA
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: _descargando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download, color: Colors.white, size: 22),
                          tooltip: 'Descargar imagen',
                          onPressed: _descargando ? null : _descargarFotoActual,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // BOTÓN CERRAR
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 22),
                          tooltip: 'Cerrar visor',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // FLECHAS DE NAVEGACIÓN RÁPIDA (SI HAY MÁS DE 1 FOTO)
            if (widget.fotos.length > 1) ...[
              if (_currentIndex > 0)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_currentIndex < widget.fotos.length - 1)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
