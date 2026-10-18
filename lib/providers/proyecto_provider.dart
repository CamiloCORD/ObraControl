import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/configuracion_model.dart';
import '../models/etapa_model.dart';
import '../models/gasto_model.dart';
import '../models/ingreso_model.dart';
import '../models/lote_model.dart';
import '../models/semana_model.dart';
import '../models/trabajador_model.dart';
import '../models/vivienda_model.dart';
import '../models/prestamo_tercero_model.dart';
import '../services/firestore_service.dart';

class ProyectoProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<User?>? _subAuth;
  StreamSubscription<ConfiguracionModel>? _subConfig;
  StreamSubscription<List<LoteModel>>? _subLotes;
  StreamSubscription<List<EtapaModel>>? _subEtapas;
  StreamSubscription<List<ViviendaModel>>? _subViviendas;
  StreamSubscription<List<TrabajadorModel>>? _subTrabajadores;
  StreamSubscription<List<SemanaModel>>? _subSemanas;
  StreamSubscription<List<GastoModel>>? _subGastos;
  StreamSubscription<List<IngresoModel>>? _subIngresos;
  StreamSubscription<List<PrestamoTerceroModel>>? _subPrestamosTerceros;

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
  List<GastoModel> _gastos = [];
  List<GastoModel> _gastosSemana = [];
  List<IngresoModel> _ingresos = [];
  List<PrestamoTerceroModel> _prestamosTerceros = [];
  SemanaModel? _semanaActiva;

  ConfiguracionModel get configuracion => _configuracion;
  List<LoteModel> get lotes => _lotes;
  List<EtapaModel> get etapas => _etapas;
  List<ViviendaModel> get viviendas => _viviendas;
  List<TrabajadorModel> get trabajadores => _trabajadores;
  List<SemanaModel> get semanas => _semanas;
  List<GastoModel> get gastos => _gastos;
  List<GastoModel> get gastosSemana => _gastosSemana;
  List<IngresoModel> get ingresos => _ingresos;
  List<PrestamoTerceroModel> get prestamosTerceros => _prestamosTerceros;
  SemanaModel? get semanaActiva => _semanaActiva;

  double get totalPrestadoTerceros =>
      _prestamosTerceros.fold(0.0, (acc, p) => acc + p.montoPrestado);

  double get totalRecuperadoTerceros =>
      _prestamosTerceros.fold(0.0, (acc, p) => acc + p.totalAbonado);

  double get saldoPendienteTerceros =>
      _prestamosTerceros.fold(0.0, (acc, p) => acc + p.saldoPendiente);

  ProyectoProvider() {
    _escucharEstadoAutenticacion();
  }

  void _escucharEstadoAutenticacion() {
    _subAuth?.cancel();
    _subAuth = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        debugPrint('[ProyectoProvider] Sesión activa confirmada para UID: ${user.uid}. Inicializando suscripciones reactivas...');
        _iniciarSuscripciones();
      } else {
        debugPrint('[ProyectoProvider] No hay sesión activa. Cancelando suscripciones y limpiando estado...');
        _cancelarSuscripciones();
        _limpiarEstado();
      }
    }, onError: (Object e) {
      debugPrint('[ProyectoProvider] Error en authStateChanges: $e');
    });
  }

  void _cancelarSuscripciones() {
    _subConfig?.cancel();
    _subLotes?.cancel();
    _subEtapas?.cancel();
    _subViviendas?.cancel();
    _subTrabajadores?.cancel();
    _subSemanas?.cancel();
    _subGastos?.cancel();
    _subIngresos?.cancel();
    _subPrestamosTerceros?.cancel();

    _subConfig = null;
    _subLotes = null;
    _subEtapas = null;
    _subViviendas = null;
    _subTrabajadores = null;
    _subSemanas = null;
    _subGastos = null;
    _subIngresos = null;
    _subPrestamosTerceros = null;
  }

  void _limpiarEstado() {
    _lotes = [];
    _etapas = [];
    _viviendas = [];
    _trabajadores = [];
    _semanas = [];
    _gastos = [];
    _gastosSemana = [];
    _ingresos = [];
    _prestamosTerceros = [];
    _semanaActiva = null;
    notifyListeners();
  }

  void _iniciarSuscripciones() {
    _cancelarSuscripciones();

    _subConfig = _firestoreService.streamConfiguracion().listen(
      (cfg) {
        _configuracion = cfg;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[ProyectoProvider] Error en streamConfiguracion: $e');
      },
    );

    _subLotes = _firestoreService.streamLotes().listen(
      (lotes) {
        _lotes = lotes;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[ProyectoProvider] Error en streamLotes: $e');
      },
    );

    _subEtapas = _firestoreService.streamEtapas().listen(
      (etapas) {
        _etapas = etapas;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[ProyectoProvider] Error en streamEtapas: $e');
      },
    );

    _subViviendas = _firestoreService.streamViviendas().listen(
      (viviendas) {
        _viviendas = viviendas;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[ProyectoProvider] Error en streamViviendas: $e');
      },
    );

    _subTrabajadores = _firestoreService.streamTrabajadores().listen(
      (trabajadores) {
        _trabajadores = trabajadores;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[ProyectoProvider] Error en streamTrabajadores: $e');
      },
    );

    _subGastos = _firestoreService.streamTodosLosGastos().listen(
      (gastos) {
        _gastos = gastos;
        _actualizarGastosSemana();
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[ProyectoProvider] Error en streamTodosLosGastos: $e');
      },
    );

    _subIngresos = _firestoreService.streamIngresos().listen(
      (ingresos) {
        _ingresos = ingresos;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[ProyectoProvider] Error en streamIngresos: $e');
      },
    );

    _subPrestamosTerceros = _firestoreService.streamPrestamosTerceros().listen(
      (prestamos) {
        debugPrint('[ProyectoProvider] prestamos_terceros recibidos en stream: ${prestamos.length} registros.');
        _prestamosTerceros = prestamos;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[ProyectoProvider] Error en streamPrestamosTerceros: $e');
      },
    );

    _subSemanas = _firestoreService.streamSemanas().listen(
      (semanas) {
        _semanas = semanas;
        if (_semanas.isNotEmpty) {
          if (_semanaActiva != null) {
            final existente = _semanas.where((s) => s.id == _semanaActiva!.id).firstOrNull;
            if (existente != null) {
              _semanaActiva = existente;
            } else {
              final sinCerrar = _semanas.where((s) => !s.cerrada).toList();
              _semanaActiva = sinCerrar.isNotEmpty ? sinCerrar.first : _semanas.first;
            }
          } else {
            final sinCerrar = _semanas.where((s) => !s.cerrada).toList();
            _semanaActiva = sinCerrar.isNotEmpty ? sinCerrar.first : _semanas.first;
          }
          _actualizarGastosSemana();
        } else {
          _semanaActiva = null;
          _gastosSemana = [];
        }
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[ProyectoProvider] Error en streamSemanas: $e');
      },
    );
  }

  /// Permite forzar una recarga manual o reinicialización de los streams reactivos
  Future<void> recargarDatos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _iniciarSuscripciones();
    }
  }

  void seleccionarSemana(SemanaModel semana) {
    _semanaActiva = semana;
    _actualizarGastosSemana();
    notifyListeners();
  }

  void _actualizarGastosSemana() {
    if (_semanaActiva != null) {
      final iniSem = DateTime(
        _semanaActiva!.fechaInicio.year,
        _semanaActiva!.fechaInicio.month,
        _semanaActiva!.fechaInicio.day,
        0,
        0,
        0,
      );
      final finSem = DateTime(
        _semanaActiva!.fechaFin.year,
        _semanaActiva!.fechaFin.month,
        _semanaActiva!.fechaFin.day,
        23,
        59,
        59,
        999,
      );

      final Set<String> abonosVistos = {};
      final Set<String> gastosIdsVistos = {};
      final List<GastoModel> filtrados = [];

      for (final g in _gastos) {
        // Filtrado estricto por semana: id coincidente o fecha dentro del rango si no tiene semanaId
        final coincideSemana = g.semanaId == _semanaActiva!.id ||
            (g.semanaId.isEmpty &&
                !g.fecha.isBefore(iniSem) &&
                !g.fecha.isAfter(finSem));

        if (!coincideSemana) continue;

        // Evitar duplicados por id del documento
        if (gastosIdsVistos.contains(g.id)) continue;

        // Prevención estricta de duplicados en abonos de nómina (por abonoId o clave compuesta)
        final esNomina = g.esAutomaticoNomina ||
            g.categoria == 'Pagos a Trabajadores' ||
            (g.abonoId != null && g.abonoId!.isNotEmpty);

        if (esNomina) {
          final claveAbono = (g.abonoId != null && g.abonoId!.isNotEmpty)
              ? g.abonoId!
              : '${g.descripcion.trim().toLowerCase()}_${g.monto}';
          if (abonosVistos.contains(claveAbono)) continue;
          abonosVistos.add(claveAbono);
        }

        gastosIdsVistos.add(g.id);
        filtrados.add(g);
      }

      _gastosSemana = filtrados;
    } else {
      _gastosSemana = [];
    }
  }

  // ================= DISCRIMINACIÓN DE GASTOS SEMANA =================
  List<GastoModel> get gastosSemanaOperativos => _gastosSemana
      .where((g) =>
          !g.esAutomaticoNomina &&
          g.categoria != 'Pagos a Trabajadores' &&
          (g.abonoId == null || g.abonoId!.isEmpty))
      .toList();

  List<GastoModel> get gastosSemanaNomina => _gastosSemana
      .where((g) =>
          g.esAutomaticoNomina ||
          g.categoria == 'Pagos a Trabajadores' ||
          (g.abonoId != null && g.abonoId!.isNotEmpty))
      .toList();

  double get totalGastosOperativosSemanaActual =>
      gastosSemanaOperativos.fold(0.0, (prev, gasto) => prev + gasto.monto);

  /// ÚNICA FUENTE DE LA VERDAD para Abonos de Nómina:
  /// Se calcula a partir de la planilla activa (SemanaModel.registros.totalPagado).
  double get totalGastosNominaSemanaActual {
    if (_semanaActiva != null && _semanaActiva!.registros.isNotEmpty) {
      return _semanaActiva!.registros.fold<double>(
        0.0,
        (acc, reg) => acc + reg.totalPagado,
      );
    }
    return gastosSemanaNomina.fold(0.0, (prev, gasto) => prev + gasto.monto);
  }

  int get cantidadPagosNominaSemanaActual {
    if (_semanaActiva != null && _semanaActiva!.registros.isNotEmpty) {
      return _semanaActiva!.registros.fold<int>(
        0,
        (acc, reg) => acc + (reg.pagos.isNotEmpty ? reg.pagos.length : (reg.totalPagado > 0 ? 1 : 0)),
      );
    }
    return gastosSemanaNomina.length;
  }

  double get totalEgresosSemanaActual =>
      totalGastosOperativosSemanaActual + totalGastosNominaSemanaActual;

  // ================= MÉTRICAS DE VIVIENDAS =================
  int get totalViviendas => _viviendas.length;

  int get totalViviendasTerminadas =>
      _viviendas.where((v) => v.estaTerminada).length;

  int get metaGlobalViviendas => totalViviendas;

  double get porcentajeAvanceGlobal {
    if (totalViviendas == 0) return 0.0;
    return (totalViviendasTerminadas / totalViviendas) * 100;
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

  double get totalGastosSemanaActual => totalEgresosSemanaActual;

  double get gananciaBruta => ingresosTotales - totalGastosSemanaActual;

  double get montoAhorro =>
      gananciaBruta > 0
          ? gananciaBruta * (_configuracion.porcentajeAhorro / 100)
          : 0.0;

  double get utilidadNeta => gananciaBruta - montoAhorro;

  /// Filtra gastos históricos según fechas o semana con deduplicación por abonoId
  List<GastoModel> filtrarGastos({DateTime? inicio, DateTime? fin, String? semanaId}) {
    final DateTime? ini = inicio != null
        ? DateTime(inicio.year, inicio.month, inicio.day, 0, 0, 0)
        : null;
    final DateTime? fn = fin != null
        ? DateTime(fin.year, fin.month, fin.day, 23, 59, 59, 999)
        : null;

    final Set<String> abonosVistos = {};
    final Set<String> gastosIdsVistos = {};
    final List<GastoModel> resultado = [];

    for (final g in _gastos) {
      if (semanaId != null && semanaId.isNotEmpty && g.semanaId != semanaId) {
        continue;
      }
      if (ini != null && g.fecha.isBefore(ini)) continue;
      if (fn != null && g.fecha.isAfter(fn)) continue;

      if (gastosIdsVistos.contains(g.id)) continue;
      if (g.abonoId != null && g.abonoId!.isNotEmpty) {
        if (abonosVistos.contains(g.abonoId!)) continue;
        abonosVistos.add(g.abonoId!);
      }
      gastosIdsVistos.add(g.id);
      resultado.add(g);
    }
    return resultado;
  }

  /// Ingresos según viviendas terminadas en el rango o histórico
  double calcularIngresos({DateTime? inicio, DateTime? fin, String? semanaId}) {
    final DateTime? ini = inicio != null
        ? DateTime(inicio.year, inicio.month, inicio.day, 0, 0, 0)
        : null;
    final DateTime? fn = fin != null
        ? DateTime(fin.year, fin.month, fin.day, 23, 59, 59, 999)
        : null;

    final viviendasEnRango = _viviendas.where((v) {
      if (!v.estaTerminada) return false;
      if (semanaId != null && semanaId.isNotEmpty) {
        if (v.semanaId == semanaId) return true;
      }
      if (ini == null && fn == null && (semanaId == null || semanaId.isEmpty)) {
        return true;
      }
      final f = v.fechaTerminacion ?? v.fechaRegistro;
      if (ini != null && f.isBefore(ini)) return false;
      if (fn != null && f.isAfter(fn)) return false;
      return true;
    }).toList();
    return viviendasEnRango.length * _configuracion.tarifaCliente;
  }

  /// Total de gastos (operativos + nóminas) en el rango o histórico
  double calcularGastosTotales({DateTime? inicio, DateTime? fin, String? semanaId}) {
    return filtrarGastos(inicio: inicio, fin: fin, semanaId: semanaId)
        .fold(0.0, (acc, g) => acc + g.monto);
  }

  /// Gastos exclusivamente operativos (sin nómina ni abonos a trabajadores)
  double calcularGastosOperativos({DateTime? inicio, DateTime? fin, String? semanaId}) {
    return filtrarGastos(inicio: inicio, fin: fin, semanaId: semanaId)
        .where((g) =>
            !g.esAutomaticoNomina &&
            g.categoria != 'Pagos a Trabajadores' &&
            (g.abonoId == null || g.abonoId!.isEmpty))
        .fold(0.0, (acc, g) => acc + g.monto);
  }

  /// Retorna la lista de semanas válidas con registros en el rango especificado
  List<SemanaModel> obtenerSemanasValidas({DateTime? inicio, DateTime? fin, String? semanaId}) {
    final DateTime? ini = inicio != null
        ? DateTime(inicio.year, inicio.month, inicio.day, 0, 0, 0)
        : null;
    final DateTime? fn = fin != null
        ? DateTime(fin.year, fin.month, fin.day, 23, 59, 59, 999)
        : null;

    return _semanas.where((s) {
      if (s.registros.isEmpty) return false;
      if (semanaId != null && semanaId.isNotEmpty) {
        return s.id == semanaId;
      }
      if (ini != null && s.fechaFin.isBefore(ini)) return false;
      if (fn != null && s.fechaInicio.isAfter(fn)) return false;
      return true;
    }).toList();
  }

  /// Total devengado / causado de mano de obra en las semanas válidas (sin dobles imputaciones)
  double calcularNominaTotal({DateTime? inicio, DateTime? fin, String? semanaId}) {
    final semanasValidas = obtenerSemanasValidas(inicio: inicio, fin: fin, semanaId: semanaId);
    return semanasValidas.fold(
      0.0,
      (acc, s) => acc + s.registros.fold(0.0, (a, r) => a + r.totalGenerado),
    );
  }

  /// Total efectivamente desembolsado/pagado en nómina (pagos + adelantos) en las semanas válidas
  double calcularNominaPagada({DateTime? inicio, DateTime? fin, String? semanaId}) {
    final semanasValidas = obtenerSemanasValidas(inicio: inicio, fin: fin, semanaId: semanaId);
    return semanasValidas.fold(
      0.0,
      (acc, s) => acc + s.registros.fold(0.0, (a, r) => a + r.totalPagado + r.totalAdelantos),
    );
  }

  /// Total saldo pendiente por pagar de nómina en las semanas válidas
  double calcularNominaSaldoPendiente({DateTime? inicio, DateTime? fin, String? semanaId}) {
    final semanasValidas = obtenerSemanasValidas(inicio: inicio, fin: fin, semanaId: semanaId);
    return semanasValidas.fold(
      0.0,
      (acc, s) => acc + s.registros.fold(0.0, (a, r) => a + r.saldoPendiente),
    );
  }

  /// Total compras o gastos a crédito pendientes de pago con proveedores
  double calcularPasivoProveedores({DateTime? inicio, DateTime? fin, String? semanaId}) {
    final DateTime? ini = inicio != null
        ? DateTime(inicio.year, inicio.month, inicio.day, 0, 0, 0)
        : null;
    final DateTime? fn = fin != null
        ? DateTime(fin.year, fin.month, fin.day, 23, 59, 59, 999)
        : null;

    return _gastos.where((g) {
      if (!g.esCreditoPendiente) return false;
      if (semanaId != null && semanaId.isNotEmpty && g.semanaId != semanaId) return false;
      if (ini != null && g.fecha.isBefore(ini)) return false;
      if (fn != null && g.fecha.isAfter(fn)) return false;
      return true;
    }).fold(0.0, (acc, g) => acc + g.monto);
  }

  double get totalPasivoProveedores => calcularPasivoProveedores();

  /// Total Pasivos Exigibles (CxP Total = Nómina Pendiente + Proveedores Pendientes)
  double calcularTotalPasivosExigibles({DateTime? inicio, DateTime? fin, String? semanaId}) {
    return calcularNominaSaldoPendiente(inicio: inicio, fin: fin, semanaId: semanaId) +
        calcularPasivoProveedores(inicio: inicio, fin: fin, semanaId: semanaId);
  }

  double get totalPasivosExigibles => calcularTotalPasivosExigibles();


  // ================= MÉTRICAS Y FILTROS DE INGRESOS =================
  List<IngresoModel> filtrarIngresos({DateTime? inicio, DateTime? fin, String? loteId}) {
    final DateTime? ini = inicio != null
        ? DateTime(inicio.year, inicio.month, inicio.day, 0, 0, 0)
        : null;
    final DateTime? fn = fin != null
        ? DateTime(fin.year, fin.month, fin.day, 23, 59, 59, 999)
        : null;

    return _ingresos.where((ing) {
      if (loteId != null && loteId.isNotEmpty && ing.loteId != loteId) {
        return false;
      }
      if (ini == null && fn == null) return true;
      if (ini != null && ing.fecha.isBefore(ini)) return false;
      if (fn != null && ing.fecha.isAfter(fn)) return false;
      return true;
    }).toList();
  }

  double calcularTotalIngresos({DateTime? inicio, DateTime? fin, String? loteId}) {
    return filtrarIngresos(inicio: inicio, fin: fin, loteId: loteId)
        .fold(0.0, (acc, ing) => acc + ing.monto);
  }

  // ================= MÉTRICAS DE CARTERA (CxC) Y POSICIÓN FINANCIERA =================
  double get tarifaCobroPorCasa =>
      _configuracion.tarifaCliente > 0 ? _configuracion.tarifaCliente.toDouble() : 100000.0;

  /// Cantidad de casas terminadas global o por lote
  int contarCasasTerminadas({String? loteId}) {
    return _viviendas.where((v) {
      if (!v.estaTerminada) return false;
      if (loteId != null && loteId.isNotEmpty && v.loteId != loteId) return false;
      return true;
    }).length;
  }

  /// Valor ejecutado sobre viviendas terminadas: Casas Terminadas * Tarifa por Casa ($100.000 COP)
  double calcularValorEjecutadoObra({String? loteId}) {
    return contarCasasTerminadas(loteId: loteId) * tarifaCobroPorCasa;
  }

  /// 1) Cartera de Obra Exigible = (Casas Terminadas * $100.000) - Total Ingresos/Abonos de Obra
  double calcularCarteraObraExigible({String? loteId}) {
    final double ejecutado = calcularValorEjecutadoObra(loteId: loteId);
    final double recaudado = calcularTotalIngresos(loteId: loteId);
    final double saldo = ejecutado - recaudado;
    return saldo > 0 ? saldo : 0.0;
  }

  /// 2) Cartera de Préstamos a Terceros = Total Prestado a Terceros - Total Devuelto
  double get carteraPrestamosTerceros => saldoPendienteTerceros;

  /// 3) Cartera Total por Cobrar (Activo Exigible) = Cartera de Obra Exigible + Cartera Préstamos a Terceros
  double calcularCarteraTotalPorCobrar({String? loteId}) {
    return calcularCarteraObraExigible(loteId: loteId) + carteraPrestamosTerceros;
  }

  double get carteraObraExigible => calcularCarteraObraExigible();
  double get carteraTotalPorCobrar => calcularCarteraTotalPorCobrar();

  /// 4) Posición Financiera Proyectada = Utilidad Real en Caja + Cartera Total por Cobrar - Cuentas por Pagar (Nómina pendiente)
  double calcularPosicionFinancieraProyectada({
    DateTime? inicio,
    DateTime? fin,
    String? semanaId,
    String? loteId,
  }) {
    final double ingresos = calcularTotalIngresos(inicio: inicio, fin: fin, loteId: loteId);
    final double gastosOperativos = calcularGastosOperativos(inicio: inicio, fin: fin, semanaId: semanaId);
    final double nominaPagada = calcularNominaPagada(inicio: inicio, fin: fin, semanaId: semanaId);
    final double utilidadRealEnCaja = ingresos - (gastosOperativos + nominaPagada);

    final double cxcTotal = calcularCarteraTotalPorCobrar(loteId: loteId);
    final double cxpNomina = calcularNominaSaldoPendiente(inicio: inicio, fin: fin, semanaId: semanaId);

    return utilidadRealEnCaja + cxcTotal - cxpNomina;
  }

  double get posicionFinancieraProyectada => calcularPosicionFinancieraProyectada();

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

  Future<void> editarSemana({
    required String semanaId,
    required DateTime nuevaFechaInicio,
    required DateTime nuevaFechaFin,
    required int nuevoNumero,
    String? nuevoNombre,
  }) async {
    await _firestoreService.editarSemana(
      semanaId: semanaId,
      nuevaFechaInicio: nuevaFechaInicio,
      nuevaFechaFin: nuevaFechaFin,
      nuevoNumero: nuevoNumero,
      nuevoNombre: nuevoNombre,
    );
  }

  Future<void> eliminarSemana(String semanaId) async {
    await _firestoreService.eliminarSemana(semanaId);
  }

  Future<Map<String, dynamic>> reconciliarCasasTerminadasConSemana({
    required String semanaId,
    required DateTime fechaInicioSemana,
    required DateTime fechaFinSemana,
  }) async {
    final res = await _firestoreService.reconciliarCasasTerminadasConSemana(
      semanaId: semanaId,
      fechaInicioSemana: fechaInicioSemana,
      fechaFinSemana: fechaFinSemana,
    );
    notifyListeners();
    return res;
  }

  /// Reconcilia y limpia los gastos automáticos de nómina de la semana activa o especificada,
  /// eliminando duplicados/huérfanos y garantizando IDs deterministas.
  Future<Map<String, dynamic>> limpiarYReconciliarGastosNomina({String? semanaId}) async {
    final targetSemanaId = semanaId ?? _semanaActiva?.id;
    if (targetSemanaId == null || targetSemanaId.isEmpty) {
      return {'eliminados': 0, 'sincronizados': 0, 'totalNominaPagada': 0.0};
    }
    final res = await _firestoreService.limpiarYReconciliarGastosNomina(semanaId: targetSemanaId);
    _actualizarGastosSemana();
    notifyListeners();
    return res;
  }

  // ================= CONFIGURACIÓN Y MARCA =================
  Future<void> guardarConfiguracion(ConfiguracionModel config) async {
    await _firestoreService.guardarConfiguracion(config);
    _configuracion = config;
    notifyListeners();
  }

  // ================= PRÉSTAMOS A TERCEROS / CARTERA CXC =================
  Future<String> registrarPrestamoTercero(PrestamoTerceroModel prestamo) async {
    final id = await _firestoreService.registrarPrestamoTercero(prestamo);
    final prestamoConId = prestamo.copyWith(id: id);
    final idx = _prestamosTerceros.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _prestamosTerceros[idx] = prestamoConId;
    } else {
      _prestamosTerceros.insert(0, prestamoConId);
    }
    notifyListeners();
    return id;
  }

  Future<void> editarPrestamoTercero(PrestamoTerceroModel prestamo) async {
    await _firestoreService.editarPrestamoTercero(prestamo);
    final idx = _prestamosTerceros.indexWhere((p) => p.id == prestamo.id);
    if (idx != -1) {
      _prestamosTerceros[idx] = prestamo;
      notifyListeners();
    }
  }

  Future<void> eliminarPrestamoTercero(String prestamoId) async {
    await _firestoreService.eliminarPrestamoTercero(prestamoId);
    _prestamosTerceros.removeWhere((p) => p.id == prestamoId);
    notifyListeners();
  }

  Future<void> registrarAbonoPrestamoTercero({
    required String prestamoId,
    required double monto,
    required String metodoPago,
    String? observacion,
  }) async {
    await _firestoreService.registrarAbonoPrestamoTercero(
      prestamoId: prestamoId,
      monto: monto,
      metodoPago: metodoPago,
      observacion: observacion,
    );
    final idx = _prestamosTerceros.indexWhere((p) => p.id == prestamoId);
    if (idx != -1) {
      final actual = _prestamosTerceros[idx];
      final nuevoAbono = AbonoPrestamoModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        monto: monto,
        fecha: DateTime.now(),
        metodoPago: metodoPago,
        observacion: observacion,
      );
      final nuevosAbonos = List<AbonoPrestamoModel>.from(actual.historialAbonos)..add(nuevoAbono);
      final nuevoTotal = actual.totalAbonado + monto;
      final nuevoEstado = (actual.montoPrestado - nuevoTotal <= 0) ? 'Saldado' : actual.estado;
      _prestamosTerceros[idx] = actual.copyWith(
        historialAbonos: nuevosAbonos,
        totalAbonado: nuevoTotal,
        estado: nuevoEstado,
      );
      notifyListeners();
    }
  }

  // ================= INGRESOS =================
  Future<String> registrarIngreso(IngresoModel ingreso) async {
    final id = await _firestoreService.registrarIngreso(ingreso);
    final ingresoConId = IngresoModel(
      id: id,
      concepto: ingreso.concepto,
      monto: ingreso.monto,
      fecha: ingreso.fecha,
      loteId: ingreso.loteId,
      loteNombre: ingreso.loteNombre,
      cliente: ingreso.cliente,
      metodoPago: ingreso.metodoPago,
      observaciones: ingreso.observaciones,
    );
    final idx = _ingresos.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _ingresos[idx] = ingresoConId;
    } else {
      _ingresos.insert(0, ingresoConId);
    }
    notifyListeners();
    return id;
  }

  Future<void> actualizarIngreso(IngresoModel ingreso) async {
    await _firestoreService.actualizarIngreso(ingreso);
    final idx = _ingresos.indexWhere((i) => i.id == ingreso.id);
    if (idx != -1) {
      _ingresos[idx] = ingreso;
      notifyListeners();
    }
  }

  Future<void> eliminarIngreso(String ingresoId) async {
    await _firestoreService.eliminarIngreso(ingresoId);
    _ingresos.removeWhere((i) => i.id == ingresoId);
    notifyListeners();
  }

  @override
  void dispose() {
    _subAuth?.cancel();
    _cancelarSuscripciones();
    super.dispose();
  }
}