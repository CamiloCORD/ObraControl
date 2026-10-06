import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:control_gas_app/firebase_options.dart';
import 'package:control_gas_app/providers/auth_provider.dart';
import 'package:control_gas_app/providers/proyecto_provider.dart';
import 'package:control_gas_app/screens/login_screen.dart';
import 'package:control_gas_app/screens/home_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO', null);
  await initializeDateFormatting('es', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProyectoProvider()),
      ],
      child: const ControlGasApp(),
    ),
  );
}

class ControlGasApp extends StatelessWidget {
  const ControlGasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control Proyecto Gas Natural',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF0500D0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0500D0),
          primary: const Color(0xFF0500D0),
          secondary: const Color(0xFFFF6F00),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0500D0),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.cargando) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.usuario != null) {
            return const HomeDashboardScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}