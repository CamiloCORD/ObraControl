import 'dart:async';
import 'package:flutter/material.dart';
import '../models/configuracion_model.dart';
import '../models/etapa_model.dart';
import '../models/gasto_model.dart';
import '../models/lote_model.dart';
import '../models/semana_model.dart';
import '../models/trabajador_model.dart';
import '../models/vivienda_model.dart';
import '../services/firestore_service.dart';

class ProyectoProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<ConfiguracionModel>? _subConfig;
  StreamSubscription<List<LoteModel>>? _subLotes;
  StreamSubscription<List<EtapaModel>>? _subEtapas;
  StreamSubscription<List<ViviendaModel>>? _subViviendas;
  StreamSubscription<List<TrabajadorModel>>? _subTrabajadores;
  StreamSubscription<List<SemanaModel>>? _subSemanas;
  StreamSubscription<List<GastoModel>>? _subGastos;

  ConfiguracionModel _configuracion = ConfiguracionModel(
    tarifaCliente: 120000,
    tarifaTecnico: 50000,
    tarifaAyudante: 50000,
    porcentajeAhorro: 10,
    pinSeguridad: '1234',
  );
  List<LoteModel> _lotes = [];
  List<EtapaModel> _etapas = [];
  List<ViviendaModel> _viviendas = [];
  List<TrabajadorModel> _trabajadores = [];
  List<SemanaModel> _semanas = [];
  List<GastoModel> _gastosSemana = [];
  SemanaModel? _semanaActiva;

  ConfiguracionModel get configuracion => _configuracion;
  List<LoteModel> get lotes => _lotes;
  List<EtapaModel> get etapas => _etapas;
  List<ViviendaModel> get viviendas => _viviendas;
  List<TrabajadorModel> get trabajadores => _trabajadores;
  List<SemanaModel> get semanas => _semanas;
  List<GastoModel> get gastosSemana => _gastosSemana;
  SemanaModel? get semanaActiva => _semanaActiva;

  ProyectoProvider() {
    _initListeners();
  }

  void _initListeners() {
    _subConfig = _firestoreService
        .streamConfiguracion()
        .handleError((Object e) => debugPrint('[Provider] streamConfiguracion error: $e'))
        .listen((cfg) {
          _configuracion = cfg;
          notifyListeners();
        });

    _subLotes = _firestoreService
        .streamLotes()
        .handleError((Object e) => debugPrint('[Provider] streamLotes error: $e'))
        .listen((lotes) {
          _lotes = lotes;
          notifyListeners();
        });

    _subEtapas = _firestoreService
        .streamEtapas()
        .handleError((Object e) => debugPrint('[Provider] streamEtapas error: $e'))
        .listen((etapas) {
          _etapas = etapas;
          notifyListeners();
        });

    _subViviendas = _firestoreService
        .streamViviendas()
        .handleError((Object e) => debugPrint('[Provider] streamViviendas error: $e'))
        .listen((viviendas) {
          _viviendas = viviendas;
          notifyListeners();
        });

    _subTrabajadores = _firestoreService
        .streamTrabajadores()
        .handleError((Object e) => debugPrint('[Provider] streamTrabajadores error: $e'))
        .listen((trabajadores) {
          _trabajadores = trabajadores;
          notifyListeners();
        });

    _subSemanas = _firestoreService
        .streamSemanas()
        .handleError((Object e) => debugPrint('[Provider] streamSemanas error: $e'))
        .listen((semanas) {
          _semanas = semanas;
          if (_semanas.isNotEmpty) {
            final sinCerrar = _semanas.where((s) => !s.cerrada).toList();
            final nuevaSemana = sinCerrar.isNotEmpty ? sinCerrar.first : _semanas.first;
            final anteriorId = _semanaActiva?.id;
            _semanaActiva = nuevaSemana;
            if (anteriorId != _semanaActiva!.id) {
              _escucharGastosSemana(_semanaActiva!.id);
            }
          } else {
            _semanaActiva = null;
            _gastosSemana = [];
          }
          notifyListeners();
        });
  }

  void seleccionarSemana(SemanaModel semana) {
    _semanaActiva = semana;
    _escucharGastosSemana(semana.id);
    notifyListeners();
  }

  void _escucharGastosSemana(String semanaId) {
    _subGastos?.cancel();
    _subGastos = _firestoreService
        .streamGastosPorSemana(semanaId)
        .handleError((Object e) => debugPrint('[Provider] streamGastos error: $e'))
        .listen((gastos) {
          _gastosSemana = gastos;
          notifyListeners();
        });
  }

  // ================= MÉTRICAS DE VIVIENDAS =================
  int get totalViviendasTerminadas =>
      _viviendas.where((v) => v.estaTerminada).length;

  int get metaGlobalViviendas =>
      _etapas.fold(0, (prev, etapa) => prev + etapa.metaViviendas);

  double get porcentajeAvanceGlobal {
    if (metaGlobalViviendas == 0) return 0.0;
    return (totalViviendasTerminadas / metaGlobalViviendas) * 100;
  }

  double porcentajeAvanceEtapa(String etapaId, int metaEtapa) {
    if (metaEtapa == 0) return 0.0;
    final terminadas = _viviendas
        .where((v) => v.etapaId == etapaId && v.estaTerminada)
        .length;
    return (terminadas / metaEtapa) * 100;
  }

  // ================= MÉTRICAS FINANCIERAS =================
  double get ingresosTotales =>
      totalViviendasTerminadas * _configuracion.tarifaCliente;

  double get totalGastosSemanaActual =>
      _gastosSemana.fold(0.0, (prev, gasto) => prev + gasto.monto);

  double get gananciaBruta => ingresosTotales - totalGastosSemanaActual;

  double get montoAhorro =>
      gananciaBruta > 0
          ? gananciaBruta * (_configuracion.porcentajeAhorro / 100)
          : 0.0;

  double get utilidadNeta => gananciaBruta - montoAhorro;

  // ================= ACCIONES DE SEMANA =================
  Future<void> cerrarSemanaActual() async {
    if (_semanaActiva == null) return;
    final semanaActualizada = _semanaActiva!.copyWith(cerrada: true);
    await _firestoreService.crearOActualizarSemana(semanaActualizada);
  }

  Future<bool> reabrirSemana(String semanaId, String pinIngresado) async {
    if (pinIngresado != _configuracion.pinSeguridad) return false;
    final idx = _semanas.indexWhere((s) => s.id == semanaId);
    if (idx == -1) return false;
    final semana = _semanas[idx];
    final semanaActualizada = semana.copyWith(cerrada: false);
    await _firestoreService.crearOActualizarSemana(semanaActualizada);
    return true;
  }

  @override
  void dispose() {
    _subConfig?.cancel();
    _subLotes?.cancel();
    _subEtapas?.cancel();
    _subViviendas?.cancel();
    _subTrabajadores?.cancel();
    _subSemanas?.cancel();
    _subGastos?.cancel();
    super.dispose();
  }
}