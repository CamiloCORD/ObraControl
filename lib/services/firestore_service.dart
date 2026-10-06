import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/configuracion_model.dart';
import '../models/etapa_model.dart';
import '../models/gasto_model.dart';
import '../models/lote_model.dart';
import '../models/semana_model.dart';
import '../models/trabajador_model.dart';
import '../models/vivienda_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================= CONFIGURACIÓN =================
  Stream<ConfiguracionModel> streamConfiguracion() {
    return _db.collection('configuracion').doc('general').snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return ConfiguracionModel.fromMap(snapshot.data()!);
      }
      return ConfiguracionModel(
        tarifaCliente: 120000,
        tarifaTecnico: 50000,
        tarifaAyudante: 50000,
        porcentajeAhorro: 10,
        pinSeguridad: '1234',
      );
    });
  }

  Future<void> guardarConfiguracion(ConfiguracionModel config) async {
    await _db
        .collection('configuracion')
        .doc('general')
        .set(config.toMap(), SetOptions(merge: true));
  }

  // ================= LOTES =================
  Stream<List<LoteModel>> streamLotes() {
    return _db
        .collection('lotes')
        .orderBy('nombre')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => LoteModel.fromMap(doc.id, doc.data())).toList())
        .handleError((Object e) {
          debugPrint('[FirestoreService] streamLotes error: $e');
        });
  }

  Future<String> guardarLote(LoteModel lote) async {
    if (lote.id.isEmpty) {
      final docRef = await _db.collection('lotes').add(lote.toMap());
      return docRef.id;
    } else {
      await _db.collection('lotes').doc(lote.id).set(lote.toMap(), SetOptions(merge: true));
      return lote.id;
    }
  }

  Future<void> eliminarLote(String loteId) async {
    // Eliminar también las viviendas asociadas a este lote
    final snapshot = await _db
        .collection('viviendas')
        .where('loteId', isEqualTo: loteId)
        .get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('lotes').doc(loteId));
    await batch.commit();
  }

  /// Crea un lote con sus casas iniciales usando WriteBatch
  Future<String> crearLoteConCasas({
    required String nombre,
    required String prefijo,
    required int cantidadCasas,
    String descripcion = '',
  }) async {
    final loteRef = _db.collection('lotes').doc();
    final String loteId = loteRef.id;
    final prefijoLimpio = prefijo.trim().toUpperCase();

    final nuevoLote = LoteModel(
      id: loteId,
      nombre: nombre.trim(),
      prefijo: prefijoLimpio,
      cantidadCasas: cantidadCasas,
      fechaCreacion: DateTime.now(),
      descripcion: descripcion.trim(),
    );

    WriteBatch batch = _db.batch();
    batch.set(loteRef, nuevoLote.toMap());
    int opsCount = 1;

    for (int i = 1; i <= cantidadCasas; i++) {
      final codigoCasa = '$prefijoLimpio-${i.toString().padLeft(2, '0')}';
      final casaRef = _db.collection('viviendas').doc(codigoCasa);

      final vivienda = ViviendaModel(
        id: codigoCasa,
        loteId: loteId,
        loteNombre: nombre.trim(),
        numeroCasa: i,
        estado: 'Pendiente',
        tecnicoId: '',
        tecnicoNombre: '',
        observaciones: '',
        fotos: const [],
        fechaRegistro: DateTime.now(),
      );

      batch.set(casaRef, vivienda.toMap());
      opsCount++;

      if (opsCount >= 450) {
        await batch.commit();
        batch = _db.batch();
        opsCount = 0;
      }
    }

    if (opsCount > 0) {
      await batch.commit();
    }

    return loteId;
  }

  // ================= ETAPAS =================
  Stream<List<EtapaModel>> streamEtapas() {
    return _db.collection('etapas').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => EtapaModel.fromMap(doc.id, doc.data())).toList();
    });
  }

  Future<void> guardarEtapa(EtapaModel etapa) async {
    if (etapa.id.isEmpty) {
      await _db.collection('etapas').add(etapa.toMap());
    } else {
      await _db.collection('etapas').doc(etapa.id).set(etapa.toMap(), SetOptions(merge: true));
    }
  }

  // ================= VIVIENDAS =================
  Stream<List<ViviendaModel>> streamViviendas() {
    return _db.collection('viviendas').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ViviendaModel.fromMap(doc.id, doc.data())).toList();
    });
  }

  /// Obtiene un stream en tiempo real de las casas de un lote ordenadas por número
  Stream<List<ViviendaModel>> obtenerCasasPorLote(String loteId) {
    return _db
        .collection('viviendas')
        .where('loteId', isEqualTo: loteId)
        .snapshots()
        .map((snapshot) {
          final casas = snapshot.docs
              .map((doc) => ViviendaModel.fromMap(doc.id, doc.data()))
              .toList();
          casas.sort((a, b) => a.numeroCasa.compareTo(b.numeroCasa));
          return casas;
        });
  }

  /// Agrega automáticamente la siguiente casa consecutiva a un lote
  Future<ViviendaModel> agregarCasaALote({
    required String loteId,
    required String prefijo,
    String loteNombre = '',
  }) async {
    final snapshot = await _db
        .collection('viviendas')
        .where('loteId', isEqualTo: loteId)
        .get();

    int maxNum = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      int numCasa = 0;
      if (data['numeroCasa'] is num) {
        numCasa = (data['numeroCasa'] as num).toInt();
      } else {
        final parsed = int.tryParse(doc.id.replaceAll(RegExp(r'^[A-Za-z0-9]+-'), ''));
        if (parsed != null) numCasa = parsed;
      }
      if (numCasa > maxNum) {
        maxNum = numCasa;
      }
    }

    final siguienteNum = maxNum + 1;
    final prefijoLimpio = prefijo.trim().toUpperCase();
    final nuevoId = '$prefijoLimpio-${siguienteNum.toString().padLeft(2, '0')}';

    final nuevaCasa = ViviendaModel(
      id: nuevoId,
      loteId: loteId,
      loteNombre: loteNombre,
      numeroCasa: siguienteNum,
      estado: 'Pendiente',
      tecnicoId: '',
      tecnicoNombre: '',
      observaciones: '',
      fotos: const [],
      fechaRegistro: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(_db.collection('viviendas').doc(nuevoId), nuevaCasa.toMap());
    batch.update(_db.collection('lotes').doc(loteId), {
      'cantidadCasas': FieldValue.increment(1),
    });
    await batch.commit();

    return nuevaCasa;
  }

  /// Borra la casa seleccionada de Firestore previa confirmación
  Future<void> eliminarCasa(String viviendaId, {String? loteId}) async {
    final batch = _db.batch();
    batch.delete(_db.collection('viviendas').doc(viviendaId));
    if (loteId != null && loteId.isNotEmpty) {
      batch.update(_db.collection('lotes').doc(loteId), {
        'cantidadCasas': FieldValue.increment(-1),
      });
    }
    await batch.commit();
  }

  Future<void> guardarVivienda(ViviendaModel vivienda) async {
    // Auto-registrar fechaTerminacion cuando el estado cambia a 'Terminada'
    ViviendaModel viviendaFinal = vivienda;
    if (vivienda.estado.trim().toLowerCase() == 'terminada' &&
        vivienda.fechaTerminacion == null) {
      viviendaFinal = vivienda.copyWith(fechaTerminacion: DateTime.now());
    } else if (vivienda.estado.trim().toLowerCase() != 'terminada') {
      // Si el estado deja de ser Terminada, limpiar la fecha
      viviendaFinal = vivienda.copyWith(clearFechaTerminacion: true);
    }

    String viviendaId = viviendaFinal.id;
    if (viviendaId.isEmpty) {
      final docRef = await _db.collection('viviendas').add(viviendaFinal.toMap());
      viviendaId = docRef.id;
    } else {
      await _db.collection('viviendas').doc(viviendaId).set(viviendaFinal.toMap(), SetOptions(merge: true));
    }

    // Regla de nómina automática para técnicos:
    // Si la vivienda tiene un técnico asignado y pertenece a una semana, sincronizar contador
    if (viviendaFinal.tecnicoId.isNotEmpty && viviendaFinal.semanaId.isNotEmpty) {
      await sincronizarCasasTerminadasTecnico(
        semanaId: viviendaFinal.semanaId,
        tecnicoId: viviendaFinal.tecnicoId,
      );
    }
  }

  Future<void> eliminarVivienda(String viviendaId, {String? semanaId, String? tecnicoId, String? loteId}) async {
    await eliminarCasa(viviendaId, loteId: loteId);
    if (semanaId != null && semanaId.isNotEmpty && tecnicoId != null && tecnicoId.isNotEmpty) {
      await sincronizarCasasTerminadasTecnico(semanaId: semanaId, tecnicoId: tecnicoId);
    }
  }

  /// Sincroniza el contador de casas terminadas de un técnico en una semana específica
  Future<void> sincronizarCasasTerminadasTecnico({
    required String semanaId,
    required String tecnicoId,
  }) async {
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) return;

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);

      final querySnapshot = await _db
          .collection('viviendas')
          .where('tecnicoId', isEqualTo: tecnicoId)
          .where('estado', isEqualTo: 'Terminada')
          .get();

      final inicio = DateTime(semana.fechaInicio.year, semana.fechaInicio.month, semana.fechaInicio.day);
      final fin = DateTime(semana.fechaFin.year, semana.fechaFin.month, semana.fechaFin.day, 23, 59, 59);

      final int casasTerminadas = querySnapshot.docs.where((doc) {
        final data = doc.data();
        if ((data['semanaId'] ?? '') == semanaId) return true;
        final rawTerminacion = data['fechaTerminacion'];
        final rawRegistro = data['fechaRegistro'];
        DateTime? fecha;
        if (rawTerminacion is Timestamp) {
          fecha = rawTerminacion.toDate();
        } else if (rawRegistro is Timestamp) {
          fecha = rawRegistro.toDate();
        }
        if (fecha != null) {
          return !fecha.isBefore(inicio) && !fecha.isAfter(fin);
        }
        return false;
      }).length;

      final existe = semana.registros.any((item) => item.trabajadorId == tecnicoId && item.esTecnico);
      List<RegistroNominaItem> registrosActualizados;
      if (existe) {
        registrosActualizados = semana.registros.map((item) {
          if (item.trabajadorId == tecnicoId && item.esTecnico) {
            return item.copyWith(diasOcasas: casasTerminadas);
          }
          return item;
        }).toList();
      } else {
        final trabDoc = await _db.collection('trabajadores').doc(tecnicoId).get();
        final nombre = trabDoc.data()?['nombre'] ?? '';
        final rol = trabDoc.data()?['rol'] ?? 'Técnico';
        final configDoc = await _db.collection('configuracion').doc('general').get();
        final tarifa = (configDoc.data()?['tarifaTecnico'] ?? 0.0).toDouble();
        registrosActualizados = List<RegistroNominaItem>.from(semana.registros)
          ..add(RegistroNominaItem(
            trabajadorId: tecnicoId,
            trabajadorNombre: nombre,
            rol: rol,
            diasOcasas: casasTerminadas,
            tarifaUnitaria: tarifa,
          ));
      }

      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('[FirestoreService] Error al sincronizar casas del técnico: $e');
    }
  }

  /// Stream reactivo: casas terminadas de un técnico en el rango de fechas de una semana.
  /// Útil para calcular dinámicamente en la tarjeta del técnico en Nómina sin depender de semanaId.
  Stream<List<ViviendaModel>> streamCasasTerminadasTecnicoEnSemana({
    required String tecnicoId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) {
    return _db
        .collection('viviendas')
        .where('tecnicoId', isEqualTo: tecnicoId)
        .where('estado', isEqualTo: 'Terminada')
        .snapshots()
        .map((snapshot) {
          final inicio = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
          final fin = DateTime(fechaFin.year, fechaFin.month, fechaFin.day, 23, 59, 59);
          return snapshot.docs
              .map((doc) => ViviendaModel.fromMap(doc.id, doc.data()))
              .where((v) {
                // Primero intentar con fechaTerminacion (preciso), luego fechaRegistro como fallback
                final fecha = v.fechaTerminacion ?? v.fechaRegistro;
                return !fecha.isBefore(inicio) && !fecha.isAfter(fin);
              })
              .toList();
        })
        .handleError((Object e) {
          debugPrint('[FirestoreService] streamCasasTerminadasTecnicoEnSemana error: $e');
        });
  }

  // ================= TRABAJADORES =================
  Stream<List<TrabajadorModel>> streamTrabajadores() {
    return _db.collection('trabajadores').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TrabajadorModel.fromMap(doc.id, doc.data())).toList();
    });
  }

  /// Stream filtrado solo de trabajadores ACTIVOS — ideal para StreamBuilder reactivo en Nómina
  Stream<List<TrabajadorModel>> streamTrabajadoresActivos() {
    return _db
        .collection('trabajadores')
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TrabajadorModel.fromMap(doc.id, doc.data())).toList())
        .handleError((Object e) {
          debugPrint('[FirestoreService] streamTrabajadoresActivos error: $e');
        });
  }

  Future<void> guardarTrabajador(TrabajadorModel trabajador) async {
    if (trabajador.id.isEmpty) {
      await _db.collection('trabajadores').add(trabajador.toMap());
    } else {
      await _db.collection('trabajadores').doc(trabajador.id).set(trabajador.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> eliminarTrabajador(String trabajadorId) async {
    await _db.collection('trabajadores').doc(trabajadorId).delete();
  }

  // ================= ASISTENCIA DIARIA DE AYUDANTES =================
  String generarAsistenciaDocId(String ayudanteId, DateTime fecha) {
    final y = fecha.year.toString();
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    return '${ayudanteId}_$y-$m-$d';
  }

  Stream<List<AsistenciaModel>> streamAsistenciasPorFecha(DateTime fecha) {
    final y = fecha.year.toString();
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    final fechaStr = '$y-$m-$d';

    return _db
        .collection('asistencias')
        .where('fechaString', isEqualTo: fechaStr)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AsistenciaModel.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<AsistenciaModel>> streamAsistenciasPorSemana(String semanaId) {
    return _db
        .collection('asistencias')
        .where('semanaId', isEqualTo: semanaId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AsistenciaModel.fromMap(doc.id, doc.data())).toList());
  }

  /// Registra o actualiza la asistencia de un ayudante y recalcula sus días en la semana activa
  Future<void> registrarAsistencia({
    required String ayudanteId,
    required String nombre,
    required DateTime fecha,
    required bool asistio,
    required String semanaId,
  }) async {
    final docId = generarAsistenciaDocId(ayudanteId, fecha);
    final asistencia = AsistenciaModel(
      id: docId,
      ayudanteId: ayudanteId,
      nombre: nombre,
      fecha: fecha,
      asistio: asistio,
      semanaId: semanaId,
    );

    await _db.collection('asistencias').doc(docId).set(asistencia.toMap(), SetOptions(merge: true));

    // Si hay una semana activa asociada, sincronizar sumatoria de días asistidos
    if (semanaId.isNotEmpty) {
      await sincronizarDiasAsistidosAyudante(semanaId: semanaId, ayudanteId: ayudanteId);
    }
  }

  Future<void> sincronizarDiasAsistidosAyudante({
    required String semanaId,
    required String ayudanteId,
  }) async {
    try {
      final query = await _db
          .collection('asistencias')
          .where('semanaId', isEqualTo: semanaId)
          .where('ayudanteId', isEqualTo: ayudanteId)
          .where('asistio', isEqualTo: true)
          .get();

      final int diasTrabajados = query.docs.length;

      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) return;

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
      final existe = semana.registros.any((item) => item.trabajadorId == ayudanteId && item.esAyudante);
      List<RegistroNominaItem> registrosActualizados;
      if (existe) {
        registrosActualizados = semana.registros.map((item) {
          if (item.trabajadorId == ayudanteId && item.esAyudante) {
            return item.copyWith(diasOcasas: diasTrabajados);
          }
          return item;
        }).toList();
      } else {
        final trabDoc = await _db.collection('trabajadores').doc(ayudanteId).get();
        final nombre = trabDoc.data()?['nombre'] ?? '';
        final configDoc = await _db.collection('configuracion').doc('general').get();
        final tarifa = (configDoc.data()?['tarifaAyudante'] ?? 0.0).toDouble();
        registrosActualizados = List<RegistroNominaItem>.from(semana.registros)
          ..add(RegistroNominaItem(
            trabajadorId: ayudanteId,
            trabajadorNombre: nombre,
            rol: 'Ayudante',
            diasOcasas: diasTrabajados,
            tarifaUnitaria: tarifa,
          ));
      }

      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('[FirestoreService] Error al sincronizar días del ayudante: $e');
    }
  }

  // ================= SEMANAS Y NÓMINA =================
  Stream<List<SemanaModel>> streamSemanas() {
    return _db
        .collection('semanas')
        .orderBy('fechaInicio', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SemanaModel.fromMap(doc.id, doc.data())).toList())
        .handleError((Object e) {
          debugPrint('[FirestoreService] streamSemanas error: $e');
        });
  }

  Future<String> crearOActualizarSemana(SemanaModel semana) async {
    if (semana.id.isEmpty) {
      final docRef = await _db.collection('semanas').add(semana.toMap());
      return docRef.id;
    } else {
      await _db.collection('semanas').doc(semana.id).set(semana.toMap(), SetOptions(merge: true));
      return semana.id;
    }
  }

  /// Permite corregir manualmente los días u obras de un trabajador en la nómina
  Future<void> actualizarDiasObrasManual({
    required String semanaId,
    required String trabajadorId,
    required int nuevosDiasObras,
  }) async {
    final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
    if (!semanaDoc.exists || semanaDoc.data() == null) return;

    final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
    final registrosActualizados = semana.registros.map((item) {
      if (item.trabajadorId == trabajadorId) {
        return item.copyWith(diasOcasas: nuevosDiasObras);
      }
      return item;
    }).toList();

    await _db.collection('semanas').doc(semanaId).update({
      'registros': registrosActualizados.map((x) => x.toMap()).toList(),
    });
  }

  /// Registra un abono de pago a un trabajador y sincroniza automáticamente con Gastos
  Future<void> registrarAbonoPago({
    required String semanaId,
    required String trabajadorId,
    required double montoAbono,
  }) async {
    final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
    if (!semanaDoc.exists || semanaDoc.data() == null) return;

    final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
    String nombreTrabajador = 'Trabajador';
    final registrosActualizados = semana.registros.map((item) {
      if (item.trabajadorId == trabajadorId) {
        nombreTrabajador = item.trabajadorNombre;
        return item.copyWith(totalPagado: item.totalPagado + montoAbono);
      }
      return item;
    }).toList();

    await _db.collection('semanas').doc(semanaId).update({
      'registros': registrosActualizados.map((x) => x.toMap()).toList(),
    });

    // Auto-sincronización con Gastos bajo "Pagos a Trabajadores"
    await _db.collection('gastos').add({
      'semanaId': semanaId,
      'categoria': 'Pagos a Trabajadores',
      'descripcion': 'Abono de Nómina: $nombreTrabajador',
      'monto': montoAbono,
      'fecha': DateTime.now().toIso8601String(),
      'esAutomaticoNomina': false,
    });
  }

  // ================= PRÉSTAMOS / VALES =================
  /// Registra un préstamo / vale, actualiza el saldo de nómina y auto-sincroniza en Gastos
  Future<void> registrarPrestamo({
    required String semanaId,
    required PrestamoModel prestamo,
  }) async {
    // 1. Guardar en colección de préstamos para auditoría
    await _db.collection('prestamos').add(prestamo.toMap());

    // 2. Descontar en la semana activa sumando al totalAdelantos del trabajador
    final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
    if (semanaDoc.exists && semanaDoc.data() != null) {
      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
      final prestamosActualizados = List<PrestamoModel>.from(semana.prestamos)..add(prestamo);

      final registrosActualizados = semana.registros.map((item) {
        if (item.trabajadorId == prestamo.trabajadorId) {
          final prestamosDelItem = List<PrestamoModel>.from(item.prestamos)..add(prestamo);
          return item.copyWith(
            totalAdelantos: item.totalAdelantos + prestamo.monto,
            prestamos: prestamosDelItem,
          );
        }
        return item;
      }).toList();

      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
        'prestamos': prestamosActualizados.map((x) => x.toMap()).toList(),
      });
    }

    // 3. Auto-sincronización inmediata con Gastos bajo "Pagos a Trabajadores"
    await _db.collection('gastos').add({
      'semanaId': semanaId,
      'categoria': 'Pagos a Trabajadores',
      'descripcion': 'Préstamo / Vale: ${prestamo.trabajadorNombre} (${prestamo.concepto})',
      'monto': prestamo.monto,
      'fecha': prestamo.fecha.toIso8601String(),
      'esAutomaticoNomina': false,
    });
  }

  // ================= GASTOS =================
  Stream<List<GastoModel>> streamGastosPorSemana(String semanaId) {
    return _db
        .collection('gastos')
        .where('semanaId', isEqualTo: semanaId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GastoModel.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> guardarGasto(GastoModel gasto) async {
    if (gasto.id.isEmpty) {
      await _db.collection('gastos').add(gasto.toMap());
    } else {
      await _db.collection('gastos').doc(gasto.id).set(gasto.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> eliminarGasto(String gastoId) async {
    await _db.collection('gastos').doc(gastoId).delete();
  }

  /// Sincronización automática de consolidado de nómina
  Future<void> sincronizarGastoNomina({
    required String semanaId,
    required double totalPagadoNomina,
  }) async {
    final query = await _db
        .collection('gastos')
        .where('semanaId', isEqualTo: semanaId)
        .where('esAutomaticoNomina', isEqualTo: true)
        .get();

    if (query.docs.isNotEmpty) {
      final docId = query.docs.first.id;
      await _db.collection('gastos').doc(docId).update({
        'monto': totalPagadoNomina,
        'fecha': DateTime.now().toIso8601String(),
      });
    } else {
      await _db.collection('gastos').add({
        'semanaId': semanaId,
        'categoria': 'Pagos a Trabajadores',
        'descripcion': 'Nómina Pagada (Auto-sincronizada)',
        'monto': totalPagadoNomina,
        'fecha': DateTime.now().toIso8601String(),
        'esAutomaticoNomina': true,
      });
    }
  }

  // ================= MANTENIMIENTO Y RESET DE PRODUCCIÓN =================
  /// Vacía por completo las colecciones de datos operativos para dejar la
  /// aplicación completamente limpia y lista para datos reales de producción.
  /// Colecciones vaciadas: lotes, viviendas, etapas, trabajadores, asistencias,
  /// semanas/nóminas, gastos y préstamos.
  /// No elimina la configuración base de tarifas ni las cuentas de usuarios.
  Future<Map<String, int>> limpiarTodosLosDatos() async {
    final colecciones = [
      'viviendas',
      'lotes',
      'etapas',
      'asistencias',
      'trabajadores',
      'gastos',
      'semanas',
      'prestamos',
    ];

    final Map<String, int> conteos = {};

    for (final col in colecciones) {
      try {
        final snapshot = await _db.collection(col).get();
        conteos[col] = snapshot.docs.length;
        if (snapshot.docs.isEmpty) continue;

        WriteBatch batch = _db.batch();
        int contador = 0;

        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
          contador++;

          if (contador >= 450) {
            await batch.commit();
            batch = _db.batch();
            contador = 0;
          }
        }

        if (contador > 0) {
          await batch.commit();
        }
      } catch (e) {
        debugPrint('[FirestoreService] Error al limpiar colección $col: $e');
        conteos[col] = 0;
      }
    }

    return conteos;
  }
}