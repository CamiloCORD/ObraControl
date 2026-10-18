import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/proyecto_provider.dart';

class LoginScreen extends StatefulWidget {
  /// Bandera para activar o desactivar el panel de accesos rápidos
  static const bool mostrarAccesosRapidos = true;

  // Credenciales demo para desarrollo y presentación académica
  // Ajusta estos valores con las credenciales registradas en tu Firebase Auth
  static const String _demoAdminEmail = 'admin@obracontrol.com';
  static const String _demoAdminPassword = '123456';

  static const String _demoTecnicoEmail = 'tecnico@obracontrol.com';
  static const String _demoTecnicoPassword = '123456';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _ocultarPass = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _accesoRapido({
    required BuildContext context,
    required AuthProvider auth,
    required String email,
    required String password,
  }) async {
    if (auth.cargando) return;

    _emailController.text = email.trim();
    _passwordController.text = password.trim();

    if (email.contains('TU_CORREO') ||
        password.contains('TU_CLAVE') ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Credenciales de demo pendientes de configurar en LoginScreen: ($email)',
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      await auth.iniciarSesion(email, password);
    } catch (e) {
      if (!context.mounted) return;
      final errorStr = e.toString();
      String mensaje = 'Error al ingresar con acceso rápido: $errorStr';
      if (errorStr.contains('user-not-found') ||
          errorStr.contains('invalid-credential')) {
        mensaje =
            'El usuario ($email) no existe o la clave es incorrecta en Firebase Auth.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final proyecto = Provider.of<ProyectoProvider>(context);
    final cfg = proyecto.configuracion;
    final colorPrimario = Color(cfg.colorPrimario);
    final nombreEmpresa = cfg.nombreEmpresa.trim().isNotEmpty
        ? cfg.nombreEmpresa.trim()
        : 'OBRACONTROL';
    final logoUrl = cfg.logoUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // INSIGNIA / LOGOTIPO INSTITUCIONAL DINÁMICO
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorPrimario,
                            colorPrimario.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: colorPrimario.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: (logoUrl != null && logoUrl.isNotEmpty)
                            ? Image.network(
                                logoUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(
                                    Icons.engineering_rounded,
                                    size: 44,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.engineering_rounded,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      nombreEmpresa.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: colorPrimario,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gestión Operativa y Financiera de Obras',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'Ingrese un correo válido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _ocultarPass,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _ocultarPass
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _ocultarPass = !_ocultarPass),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrimario,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: auth.cargando
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  try {
                                    await auth.iniciarSesion(
                                      _emailController.text,
                                      _passwordController.text,
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error al ingresar: ${e.toString()}',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: auth.cargando
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'INGRESAR AL SISTEMA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    // =========================================================
                    // PANEL DE ACCESO RÁPIDO (MODO PRUEBAS / DEMOSTRACIÓN)
                    // =========================================================
                    if (LoginScreen.mostrarAccesosRapidos) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade300,
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.flash_on_rounded,
                                  size: 16,
                                  color: Color(0xFFFF6F00),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Acceso Rápido (Modo Pruebas / Demo)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade300,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorPrimario,
                                side: BorderSide(
                                  color: colorPrimario.withValues(alpha: 0.45),
                                ),
                                backgroundColor: colorPrimario.withValues(
                                  alpha: 0.04,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Dueño / Admin',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: auth.cargando
                                  ? null
                                  : () => _accesoRapido(
                                      context: context,
                                      auth: auth,
                                      email: LoginScreen._demoAdminEmail,
                                      password: LoginScreen._demoAdminPassword,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE65100),
                                side: BorderSide(
                                  color: const Color(0xFFE65100)
                                      .withValues(alpha: 0.45),
                                ),
                                backgroundColor: const Color(0xFFE65100)
                                    .withValues(alpha: 0.04),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.engineering_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Técnico',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: auth.cargando
                                  ? null
                                  : () => _accesoRapido(
                                      context: context,
                                      auth: auth,
                                      email: LoginScreen._demoTecnicoEmail,
                                      password:
                                          LoginScreen._demoTecnicoPassword,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
