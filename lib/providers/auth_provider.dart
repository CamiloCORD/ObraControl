import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _usuario;
  String _rol = 'admin'; // 'admin' o 'dueno'
  bool _cargando = true;

  User? get usuario => _usuario;
  String get rol => _rol;
  bool get cargando => _cargando;
  bool get esDueno => _rol == 'dueno';

  AuthProvider() {
    _authService.usuarioActualStream.listen((usuario) async {
      _usuario = usuario;
      if (_usuario != null) {
        _rol = await _authService.obtenerRolUsuario(_usuario!.uid);
      } else {
        _rol = 'admin';
      }
      _cargando = false;
      notifyListeners();
    });
  }

  Future<void> iniciarSesion(String email, String password) async {
    _cargando = true;
    notifyListeners();
    try {
      final cred = await _authService.iniciarSesion(email, password);
      if (cred.user != null) {
        _rol = await _authService.obtenerRolUsuario(cred.user!.uid);
      }
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }


  Future<void> cerrarSesion() async {
    await _authService.cerrarSesion();
    _usuario = null;
    _rol = 'admin';
    notifyListeners();
  }
}