import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get usuarioActualStream => _auth.authStateChanges();
  User? get usuarioActual => _auth.currentUser;

  /// Inicia sesión con correo y contraseña
  Future<UserCredential> iniciarSesion(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Cierra la sesión activa
  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }

  /// Obtiene el rol del usuario desde la colección 'usuarios' ('admin' o 'dueno')
  Future<String> obtenerRolUsuario(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['rol'] ?? 'admin';
      }
    } catch (_) {}
    return 'admin'; // Rol seguro por defecto
  }


  /// Crea un perfil de usuario si es la primera vez que se loguea
  Future<void> asegurarPerfilUsuario(String uid, String email, String rolPredeterminado) async {
    final docRef = _firestore.collection('usuarios').doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'email': email,
        'rol': rolPredeterminado,
        'creadoEn': FieldValue.serverTimestamp(),
      });
    }
  }
}