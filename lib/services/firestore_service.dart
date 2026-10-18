import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/configuracion_model.dart';
import '../models/etapa_model.dart';
import '../models/gasto_model.dart';
import '../models/lote_model.dart';
import '../models/semana_model.dart';
import '../models/ingreso_model.dart';
import '../models/trabajador_model.dart';
import '../models/vivienda_model.dart';
import '../models/prestamo_tercero_model.dart';

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
      // ID compuesto normalizado para prevenir colisiones entre lotes
      final docId = ViviendaModel.generarIdCompuesto(loteId, codigoCasa);
      final casaRef = _db.collection('viviendas').doc(docId);

      final vivienda = ViviendaModel(
        id: docId,
        codigo: codigoCasa,
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

      if (opsCount >= 400) {
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
    final codigoCasa = '$prefijoLimpio-${siguienteNum.toString().padLeft(2, '0')}';
    // ID compuesto normalizado para prevenir colisiones entre lotes
    final docId = ViviendaModel.generarIdCompuesto(loteId, codigoCasa);

    final nuevaCasa = ViviendaModel(
      id: docId,
      codigo: codigoCasa,
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
    batch.set(_db.collection('viviendas').doc(docId), nuevaCasa.toMap());
    batch.update(_db.collection('lotes').doc(loteId), {
      'cantidadCasas': FieldValue.increment(1),
    });
    await batch.commit();

    // Retornamos la casa con el docId compuesto como referencia
    return nuevaCasa.copyWith(id: docId);
  }

  /// Borra la casa seleccionada de Firestore usando su ID de documento compuesto.
  /// El [viviendaDocId] debe ser el ID del documento Firestore (compuesto: loteId_CODIGO).
  /// Esto previene eliminaciones accidentales de viviendas homónimas en otros lotes.
  Future<void> eliminarCasa(String viviendaDocId, {String? loteId}) async {
    final batch = _db.batch();
    batch.delete(_db.collection('viviendas').doc(viviendaDocId));
    if (loteId != null && loteId.isNotEmpty) {
      batch.update(_db.collection('lotes').doc(loteId), {
        'cantidadCasas': FieldValue.increment(-1),
      });
    }
    await batch.commit();
  }

  /// Verifica si ya existe una vivienda con ese código dentro de un mismo lote.
  /// Retorna true si hay colisión (ya existe), false si es seguro insertar.
  Future<bool> existeViviendaEnLote(String loteId, String codigoCasa) async {
    final docId = ViviendaModel.generarIdCompuesto(loteId, codigoCasa);
    final doc = await _db.collection('viviendas').doc(docId).get();
    return doc.exists;
  }

  Future<void> guardarVivienda(ViviendaModel vivienda, {String? semanaActivaId}) async {
    // 1. Obtener estado previo de la vivienda si ya existe
    ViviendaModel? viviendaAnterior;
    if (vivienda.id.isNotEmpty) {
      final prevSnap = await _db.collection('viviendas').doc(vivienda.id).get();
      if (prevSnap.exists && prevSnap.data() != null) {
        viviendaAnterior = ViviendaModel.fromMap(prevSnap.id, prevSnap.data()!);
      }
    }

    final String estadoAnterior = (viviendaAnterior?.estado ?? '').trim().toLowerCase();
    final String tecnicoAnterior = viviendaAnterior?.tecnicoId ?? '';
    final String semanaAnterior = viviendaAnterior?.semanaId ?? '';

    // 2. Preparar el modelo definitivo de la vivienda
    ViviendaModel viviendaFinal = vivienda;
    final bool pasaATerminada = viviendaFinal.estado.trim().toLowerCase() == 'terminada';

    if (pasaATerminada) {
      DateTime fTerm = viviendaFinal.fechaTerminacion ?? DateTime.now();
      String sId = viviendaFinal.semanaId;
      if (sId.isEmpty) {
        sId = (semanaActivaId != null && semanaActivaId.isNotEmpty) ? semanaActivaId : '';
        if (sId.isEmpty) {
          try {
            final openWeeks = await _db
                .collection('semanas')
                .where('cerrada', isEqualTo: false)
                .limit(1)
                .get();
            if (openWeeks.docs.isNotEmpty) {
              sId = openWeeks.docs.first.id;
            }
          } catch (_) {}
        }
      }

      viviendaFinal = viviendaFinal.copyWith(
        fechaTerminacion: fTerm,
        semanaId: sId,
      );
    } else {
      // Si el estado no es Terminada (ej. 'Pendiente' o 'En Proceso'), limpiar fecha y semana
      viviendaFinal = viviendaFinal.copyWith(
        clearFechaTerminacion: true,
        semanaId: '',
      );
    }

    // 3. Persistir en Firestore
    String viviendaId = viviendaFinal.id;
    if (viviendaId.isEmpty) {
      final docRef = await _db.collection('viviendas').add(viviendaFinal.toMap());
      viviendaId = docRef.id;
      viviendaFinal = viviendaFinal.copyWith(id: docRef.id);
    } else {
      await _db.collection('viviendas').doc(viviendaId).set(viviendaFinal.toMap(), SetOptions(merge: true));
    }

    // 4. Sincronización atómica reactiva con la semana de nómina:
    // Caso A: Si ahora está Terminada, con técnico y semana asociada -> recalcular contador del técnico
    if (viviendaFinal.estaTerminada &&
        viviendaFinal.tecnicoId.isNotEmpty &&
        viviendaFinal.semanaId.isNotEmpty) {
      await sincronizarCasasTerminadasTecnico(
        semanaId: viviendaFinal.semanaId,
        tecnicoId: viviendaFinal.tecnicoId,
      );
    }

    // Caso B: Si anteriormente estaba Terminada y ahora ya no lo está (o cambió de técnico / semana):
    if (estadoAnterior == 'terminada') {
      final semanaAfectada = semanaAnterior.isNotEmpty ? semanaAnterior : (semanaActivaId ?? '');
      if (semanaAfectada.isNotEmpty && tecnicoAnterior.isNotEmpty) {
        final cambioTecnico = tecnicoAnterior != viviendaFinal.tecnicoId;
        final cambioSemana = semanaAnterior != viviendaFinal.semanaId;
        final dejoDeEstarTerminada = !viviendaFinal.estaTerminada;

        if (dejoDeEstarTerminada || cambioTecnico || cambioSemana) {
          await sincronizarCasasTerminadasTecnico(
            semanaId: semanaAfectada,
            tecnicoId: tecnicoAnterior,
          );
        }
      }
    }
  }

  /// Cambia de forma atómica el estado de una vivienda y sincroniza la nómina del técnico en la semana activa
  Future<void> cambiarEstadoVivienda({
    required String viviendaId,
    required String nuevoEstado,
    String? tecnicoId,
    String? tecnicoNombre,
    String? semanaIdActiva,
  }) async {
    final docRef = _db.collection('viviendas').doc(viviendaId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return;

    final viviendaActual = ViviendaModel.fromMap(snap.id, snap.data()!);
    final esTerminada = nuevoEstado.trim().toLowerCase() == 'terminada';
    final viviendaActualizada = viviendaActual.copyWith(
      estado: nuevoEstado,
      tecnicoId: tecnicoId ?? viviendaActual.tecnicoId,
      tecnicoNombre: tecnicoNombre ?? viviendaActual.tecnicoNombre,
      semanaId: esTerminada
          ? (viviendaActual.semanaId.isNotEmpty ? viviendaActual.semanaId : (semanaIdActiva ?? ''))
          : '',
      clearFechaTerminacion: !esTerminada,
      fechaTerminacion: esTerminada
          ? (viviendaActual.fechaTerminacion ?? DateTime.now())
          : null,
    );

    await guardarVivienda(viviendaActualizada, semanaActivaId: semanaIdActiva);
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
    if (semanaId.isEmpty || tecnicoId.isEmpty) return;
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) return;

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);

      final querySnapshot = await _db
          .collection('viviendas')
          .where('tecnicoId', isEqualTo: tecnicoId)
          .get();

      final inicio = DateTime(semana.fechaInicio.year, semana.fechaInicio.month, semana.fechaInicio.day);
      final fin = DateTime(semana.fechaFin.year, semana.fechaFin.month, semana.fechaFin.day, 23, 59, 59);

      DateTime? parsearFecha(dynamic val) {
        if (val == null) return null;
        if (val is Timestamp) return val.toDate();
        if (val is DateTime) return val;
        try {
          return (val as dynamic).toDate() as DateTime;
        } catch (_) {
          return DateTime.tryParse(val.toString());
        }
      }

      final int casasTerminadas = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final est = (data['estado'] ?? '').toString().trim().toLowerCase();
        if (est != 'terminada') return false;

        if ((data['semanaId'] ?? '') == semanaId) return true;
        if ((data['semanaId'] ?? '').toString().trim().isEmpty) return true;

        final fecha = parsearFecha(data['fechaTerminacion']) ?? parsearFecha(data['fechaRegistro']);
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
            return item.copyWith(diasOcasas: casasTerminadas.toDouble());
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
            diasOcasas: casasTerminadas.toDouble(),
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
    String? semanaId,
  }) {
    return _db
        .collection('viviendas')
        .where('tecnicoId', isEqualTo: tecnicoId)
        .snapshots()
        .map((snapshot) {
          final inicio = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
          final fin = DateTime(fechaFin.year, fechaFin.month, fechaFin.day, 23, 59, 59);
          return snapshot.docs
              .map((doc) => ViviendaModel.fromMap(doc.id, doc.data()))
              .where((v) {
                if (!v.estaTerminada) return false;
                if (semanaId != null && semanaId.isNotEmpty && v.semanaId == semanaId) {
                  return true;
                }
                if (v.semanaId.isEmpty) {
                  return true;
                }
                final fecha = v.fechaTerminacion ?? v.fechaRegistro;
                return !fecha.isBefore(inicio) && !fecha.isAfter(fin);
              })
              .toList();
        })
        .handleError((Object e) {
          debugPrint('[FirestoreService] streamCasasTerminadasTecnicoEnSemana error: $e');
        });
  }

  // ================= RECONCILIACIÓN Y AUDITORÍA DE VIVIENDAS TERMINADAS =================
  /// Realiza una auditoría y reconciliación forzada de viviendas terminadas con la semana activa.
  /// Identifica viviendas huérfanas (sin semanaId o con semanaId erróneo), las vincula a la semana,
  /// agrupa el conteo por técnico y actualiza el documento de la semana en Firestore.
  Future<Map<String, dynamic>> reconciliarCasasTerminadasConSemana({
    required String semanaId,
    required DateTime fechaInicioSemana,
    required DateTime fechaFinSemana,
  }) async {
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) {
        throw Exception('La semana especificada ($semanaId) no existe.');
      }
      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);

      // Identificar semanas cerradas para no alterar viviendas de semanas ya clausuradas
      final semanasSnap = await _db.collection('semanas').get();
      final Set<String> semanasCerradasIds = semanasSnap.docs
          .where((doc) => doc.id != semanaId && (doc.data()['cerrada'] == true))
          .map((doc) => doc.id)
          .toSet();

      // Consultar tarifa configurada de técnico
      final configDoc = await _db.collection('configuracion').doc('general').get();
      final double tarifaTecnicoConfig = (configDoc.data()?['tarifaTecnico'] as num?)?.toDouble() ?? 50000.0;

      // Consultar todas las viviendas
      final viviendasSnap = await _db.collection('viviendas').get();

      final inicioRango = DateTime(
        fechaInicioSemana.year,
        fechaInicioSemana.month,
        fechaInicioSemana.day,
        0,
        0,
        0,
      );
      final finRango = DateTime(
        fechaFinSemana.year,
        fechaFinSemana.month,
        fechaFinSemana.day,
        23,
        59,
        59,
        999,
      );

      DateTime? parsearFecha(dynamic val) {
        if (val == null) return null;
        if (val is Timestamp) return val.toDate();
        if (val is DateTime) return val;
        try {
          return (val as dynamic).toDate() as DateTime;
        } catch (_) {
          return DateTime.tryParse(val.toString());
        }
      }

      int casasRevinculadas = 0;
      final List<DocumentSnapshot<Map<String, dynamic>>> huerfanasParaVincular = [];
      final Map<String, List<ViviendaModel>> casasPorTecnico = {};
      final Set<String> casasProcesadasIds = {};

      for (final doc in viviendasSnap.docs) {
        final data = doc.data();
        final estado = (data['estado'] ?? '').toString().trim().toLowerCase();
        final tecnicoId = (data['tecnicoId'] ?? '').toString().trim();

        // 1. Debe estar terminada y tener técnico asignado
        if (estado != 'terminada' || tecnicoId.isEmpty) {
          continue;
        }

        final docSemanaId = (data['semanaId'] ?? '').toString().trim();

        // 2. Si pertenece a otra semana cerrada, salvaguardar
        if (docSemanaId.isNotEmpty && docSemanaId != semanaId && semanasCerradasIds.contains(docSemanaId)) {
          continue;
        }

        bool perteneceAEstaSemana = false;
        bool esHuerfana = false;

        // Criterio A: Ya tiene semanaId asignado a esta semana activa
        if (docSemanaId == semanaId) {
          perteneceAEstaSemana = true;
        } else {
          // Criterio B: Reparación de huérfanas
          final fTerm = parsearFecha(data['fechaTerminacion']);
          final fInst = parsearFecha(data['fechaInstalacion']);
          final fReg = parsearFecha(data['fechaRegistro']);
          final fechaRef = fTerm ?? fInst ?? fReg;

          if (fechaRef != null) {
            final enRango = !fechaRef.isBefore(inicioRango) && !fechaRef.isAfter(finRango);
            // Si está dentro del rango de la semana o no tiene semanaId asignado
            if (enRango || docSemanaId.isEmpty) {
              perteneceAEstaSemana = true;
              esHuerfana = true;
            }
          } else if (docSemanaId.isEmpty) {
            perteneceAEstaSemana = true;
            esHuerfana = true;
          }
        }

        if (perteneceAEstaSemana) {
          casasProcesadasIds.add(doc.id);
          final vivienda = ViviendaModel.fromMap(doc.id, data);
          casasPorTecnico.putIfAbsent(tecnicoId, () => []).add(vivienda);

          if (esHuerfana || docSemanaId != semanaId) {
            huerfanasParaVincular.add(doc);
            casasRevinculadas++;
          }
        }
      }

      // 3. Vincular huérfanas en Firestore con WriteBatch
      if (huerfanasParaVincular.isNotEmpty) {
        for (var i = 0; i < huerfanasParaVincular.length; i += 400) {
          final batch = _db.batch();
          final end = (i + 400 < huerfanasParaVincular.length) ? i + 400 : huerfanasParaVincular.length;
          final chunk = huerfanasParaVincular.sublist(i, end);

          for (final docSnap in chunk) {
            final data = docSnap.data()!;
            final fechaTermExistente = parsearFecha(data['fechaTerminacion']);
            final fTermFinal = fechaTermExistente ?? DateTime.now();

            batch.update(docSnap.reference, {
              'semanaId': semanaId,
              'fechaTerminacion': fTermFinal.toIso8601String(),
            });
          }
          await batch.commit();
        }
      }

      // 4. Cargar información de técnicos si no estaban en semana.registros
      final Set<String> tecnicosEnSemana = semana.registros
          .where((r) => r.esTecnico)
          .map((r) => r.trabajadorId)
          .toSet();

      final Map<String, TrabajadorModel> infoTecnicos = {};
      for (final tid in casasPorTecnico.keys) {
        if (!tecnicosEnSemana.contains(tid)) {
          final trabSnap = await _db.collection('trabajadores').doc(tid).get();
          if (trabSnap.exists && trabSnap.data() != null) {
            infoTecnicos[tid] = TrabajadorModel.fromMap(trabSnap.id, trabSnap.data()!);
          }
        }
      }

      // 5. Actualizar registros de la semana
      final Map<String, int> detallesPorTecnico = {};
      final List<RegistroNominaItem> registrosActualizados = [];
      final Set<String> tecnicosProcesados = {};

      for (final item in semana.registros) {
        if (item.esTecnico) {
          final totalCasas = casasPorTecnico[item.trabajadorId]?.length ?? 0;
          detallesPorTecnico[item.trabajadorId] = totalCasas;
          tecnicosProcesados.add(item.trabajadorId);

          registrosActualizados.add(item.copyWith(
            diasOcasas: totalCasas.toDouble(),
            tarifaUnitaria: item.tarifaUnitaria > 0 ? item.tarifaUnitaria : tarifaTecnicoConfig,
          ));
        } else {
          registrosActualizados.add(item);
        }
      }

      for (final entry in casasPorTecnico.entries) {
        final tid = entry.key;
        final totalCasas = entry.value.length;
        detallesPorTecnico[tid] = totalCasas;

        if (!tecnicosProcesados.contains(tid)) {
          final trab = infoTecnicos[tid];
          final nombre = trab?.nombre.isNotEmpty == true
              ? trab!.nombre
              : (entry.value.firstOrNull?.tecnicoNombre.isNotEmpty == true
                  ? entry.value.first.tecnicoNombre
                  : 'Técnico');
          final rol = trab?.rol ?? 'Técnico';

          registrosActualizados.add(RegistroNominaItem(
            trabajadorId: tid,
            trabajadorNombre: nombre,
            rol: rol,
            diasOcasas: totalCasas.toDouble(),
            tarifaUnitaria: tarifaTecnicoConfig,
          ));
        }
      }

      // 6. Guardar la semana en Firestore
      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
      });

      return {
        'totalCasasTerminadas': casasProcesadasIds.length,
        'casasRevinculadas': casasRevinculadas,
        'detallesPorTecnico': detallesPorTecnico,
      };
    } catch (e) {
      debugPrint('[FirestoreService] Error en reconciliarCasasTerminadasConSemana: $e');
      rethrow;
    }
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

  /// Registra o actualiza la asistencia de un ayudante (admite 1.0 = completo, 0.5 = medio día, 0.0 = ausente)
  /// y recalcula sus días en la semana activa
  Future<void> registrarAsistencia({
    required String ayudanteId,
    required String nombre,
    required DateTime fecha,
    double valorJornada = 1.0,
    bool? asistio,
    required String semanaId,
  }) async {
    final double finalValor = valorJornada != 1.0
        ? valorJornada
        : ((asistio ?? true) ? 1.0 : 0.0);

    final docId = generarAsistenciaDocId(ayudanteId, fecha);
    final asistencia = AsistenciaModel(
      id: docId,
      ayudanteId: ayudanteId,
      nombre: nombre,
      fecha: fecha,
      valorJornada: finalValor,
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
          .get();

      double diasTrabajados = 0.0;
      for (final doc in query.docs) {
        final data = doc.data();
        if (data['valorJornada'] is num) {
          diasTrabajados += (data['valorJornada'] as num).toDouble();
        } else if (data['asistio'] == true) {
          diasTrabajados += 1.0;
        }
      }

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

  /// Cuenta los registros operativos vinculados a una semana
  Future<Map<String, int>> contarVinculosSemana(String semanaId) async {
    final vivSnap = await _db.collection('viviendas').where('semanaId', isEqualTo: semanaId).get();
    final asisSnap = await _db.collection('asistencias').where('semanaId', isEqualTo: semanaId).get();
    final gasSnap = await _db.collection('gastos').where('semanaId', isEqualTo: semanaId).get();
    final presSnap = await _db.collection('prestamos').where('semanaId', isEqualTo: semanaId).get();

    return {
      'viviendas': vivSnap.docs.length,
      'asistencias': asisSnap.docs.length,
      'gastos': gasSnap.docs.length,
      'prestamos': presSnap.docs.length,
      'total': vivSnap.docs.length + asisSnap.docs.length + gasSnap.docs.length + presSnap.docs.length,
    };
  }

  /// Modifica los metadatos de una semana (fechas y número de semana)
  Future<void> editarSemana({
    required String semanaId,
    required DateTime nuevaFechaInicio,
    required DateTime nuevaFechaFin,
    required int nuevoNumero,
    String? nuevoNombre,
  }) async {
    final docRef = _db.collection('semanas').doc(semanaId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    final nombreFinal = (nuevoNombre != null && nuevoNombre.trim().isNotEmpty)
        ? nuevoNombre.trim()
        : 'Semana $nuevoNumero';

    await docRef.update({
      'numeroSemana': nombreFinal,
      'fechaInicio': nuevaFechaInicio.toIso8601String(),
      'fechaFin': nuevaFechaFin.toIso8601String(),
    });
  }

  /// Elimina una semana errónea o vacía desvinculando de forma segura sus datos asociados
  Future<void> eliminarSemana(String semanaId, {bool desvincularAsociados = true}) async {
    if (desvincularAsociados) {
      // 1. Desvincular viviendas (remover semanaId para no dejar referencias rotas)
      final vivSnap = await _db.collection('viviendas').where('semanaId', isEqualTo: semanaId).get();
      if (vivSnap.docs.isNotEmpty) {
        WriteBatch vivBatch = _db.batch();
        int vCount = 0;
        for (final doc in vivSnap.docs) {
          vivBatch.update(doc.reference, {'semanaId': ''});
          vCount++;
          if (vCount >= 400) {
            await vivBatch.commit();
            vivBatch = _db.batch();
            vCount = 0;
          }
        }
        if (vCount > 0) await vivBatch.commit();
      }

      // 2. Eliminar asistencias vinculadas a esta semana específica
      final asisSnap = await _db.collection('asistencias').where('semanaId', isEqualTo: semanaId).get();
      if (asisSnap.docs.isNotEmpty) {
        WriteBatch asisBatch = _db.batch();
        int aCount = 0;
        for (final doc in asisSnap.docs) {
          asisBatch.delete(doc.reference);
          aCount++;
          if (aCount >= 400) {
            await asisBatch.commit();
            asisBatch = _db.batch();
            aCount = 0;
          }
        }
        if (aCount > 0) await asisBatch.commit();
      }

      // 3. Eliminar gastos sincronizados con esta semana
      final gasSnap = await _db.collection('gastos').where('semanaId', isEqualTo: semanaId).get();
      if (gasSnap.docs.isNotEmpty) {
        WriteBatch gasBatch = _db.batch();
        int gCount = 0;
        for (final doc in gasSnap.docs) {
          gasBatch.delete(doc.reference);
          gCount++;
          if (gCount >= 400) {
            await gasBatch.commit();
            gasBatch = _db.batch();
            gCount = 0;
          }
        }
        if (gCount > 0) await gasBatch.commit();
      }

      // 4. Eliminar préstamos vinculados con esta semana
      final presSnap = await _db.collection('prestamos').where('semanaId', isEqualTo: semanaId).get();
      if (presSnap.docs.isNotEmpty) {
        WriteBatch presBatch = _db.batch();
        int pCount = 0;
        for (final doc in presSnap.docs) {
          presBatch.delete(doc.reference);
          pCount++;
          if (pCount >= 400) {
            await presBatch.commit();
            presBatch = _db.batch();
            pCount = 0;
          }
        }
        if (pCount > 0) await presBatch.commit();
      }
    }

    // 5. Eliminar el documento de la semana
    await _db.collection('semanas').doc(semanaId).delete();
  }

  /// Registra un bono discriminado para un trabajador en la semana activa (genera obligación/devengado, no pago)
  Future<void> registrarBonoTrabajador({
    required String semanaId,
    required BonoItemModel bono,
  }) async {
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) return;

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
      final bonoId = bono.id.isNotEmpty ? bono.id : _db.collection('semanas').doc().id;
      final bonoConId = bono.copyWith(id: bonoId, semanaId: semanaId);

      final List<BonoItemModel> bonosSemana = List<BonoItemModel>.from(semana.bonos)..add(bonoConId);

      final registrosActualizados = semana.registros.map((item) {
        if (item.trabajadorId == bonoConId.trabajadorId) {
          final List<BonoItemModel> bonosItem = List<BonoItemModel>.from(item.bonos)..add(bonoConId);
          final nuevoTotal = bonosItem.fold<double>(0.0, (acc, b) => acc + b.monto);
          return item.copyWith(
            bonos: bonosItem,
            bonificaciones: nuevoTotal,
          );
        }
        return item;
      }).toList();

      final existe = semana.registros.any((item) => item.trabajadorId == bonoConId.trabajadorId);
      if (!existe) {
        final trabDoc = await _db.collection('trabajadores').doc(bonoConId.trabajadorId).get();
        final trabData = trabDoc.data() ?? {};
        final nombre = trabData['nombre'] ?? bonoConId.trabajadorNombre;
        final rol = trabData['rol'] ?? 'Ayudante';
        final esTec = (trabData['esTecnico'] == true) ||
            rol.toString().toLowerCase().contains('técnico') ||
            rol.toString().toLowerCase().contains('tecnico');

        final configDoc = await _db.collection('configuracion').doc('general').get();
        final configData = configDoc.data() ?? {};
        final tarifa = esTec
            ? (configData['tarifaTecnico'] ?? configData['tarifaPorCasa'] ?? 0.0).toDouble()
            : (configData['tarifaAyudante'] ?? 0.0).toDouble();

        registrosActualizados.add(RegistroNominaItem(
          trabajadorId: bonoConId.trabajadorId,
          trabajadorNombre: nombre,
          rol: rol,
          diasOcasas: 0.0,
          tarifaUnitaria: tarifa,
          bonificaciones: bonoConId.monto,
          bonos: [bonoConId],
        ));
      }

      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
        'bonos': bonosSemana.map((x) => x.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('[FirestoreService] Error al registrar bono a trabajador: $e');
      rethrow;
    }
  }

  /// Edita un bono previamente generado a un trabajador
  Future<void> editarBonoTrabajador({
    required String semanaId,
    required BonoItemModel bonoModificado,
  }) async {
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) return;

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);

      final bonosSemana = semana.bonos.map((b) {
        return b.id == bonoModificado.id ? bonoModificado : b;
      }).toList();

      final registrosActualizados = semana.registros.map((item) {
        if (item.trabajadorId == bonoModificado.trabajadorId ||
            item.bonos.any((b) => b.id == bonoModificado.id)) {
          final nuevosBonos = item.bonos.map((b) {
            return b.id == bonoModificado.id ? bonoModificado : b;
          }).toList();
          final nuevoTotal = nuevosBonos.fold<double>(0.0, (acc, b) => acc + b.monto);
          return item.copyWith(
            bonos: nuevosBonos,
            bonificaciones: nuevoTotal,
          );
        }
        return item;
      }).toList();

      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
        'bonos': bonosSemana.map((x) => x.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('[FirestoreService] Error al editar bono de trabajador: $e');
      rethrow;
    }
  }

  /// Elimina un bono discriminado y recalcula el total devengado
  Future<void> eliminarBonoTrabajador({
    required String semanaId,
    required String bonoId,
    required String trabajadorId,
  }) async {
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) return;

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);

      final bonosSemana = semana.bonos.where((b) => b.id != bonoId).toList();

      final registrosActualizados = semana.registros.map((item) {
        if (item.trabajadorId == trabajadorId || item.bonos.any((b) => b.id == bonoId)) {
          final nuevosBonos = item.bonos.where((b) => b.id != bonoId).toList();
          final nuevoTotal = nuevosBonos.fold<double>(0.0, (acc, b) => acc + b.monto);
          return item.copyWith(
            bonos: nuevosBonos,
            bonificaciones: nuevoTotal,
          );
        }
        return item;
      }).toList();

      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
        'bonos': bonosSemana.map((x) => x.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('[FirestoreService] Error al eliminar bono de trabajador: $e');
      rethrow;
    }
  }

  /// Permite corregir manualmente los días u obras de un trabajador en la nómina (admite decimales)
  Future<void> actualizarDiasObrasManual({
    required String semanaId,
    required String trabajadorId,
    required double nuevosDiasObras,
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

  /// Actualiza la bonificación o incentivo monetario de un trabajador en la semana indicada
  Future<void> actualizarBonificacionTrabajador({
    required String semanaId,
    required String trabajadorId,
    required double monto,
  }) async {
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) return;

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
      final existe = semana.registros.any((item) => item.trabajadorId == trabajadorId);

      List<RegistroNominaItem> registrosActualizados;
      if (existe) {
        registrosActualizados = semana.registros.map((item) {
          if (item.trabajadorId == trabajadorId) {
            return item.copyWith(bonificaciones: monto);
          }
          return item;
        }).toList();
      } else {
        final trabDoc = await _db.collection('trabajadores').doc(trabajadorId).get();
        final trabData = trabDoc.data() ?? {};
        final nombre = trabData['nombre'] ?? '';
        final rol = trabData['rol'] ?? 'Ayudante';
        final esTec = (trabData['esTecnico'] == true) ||
            rol.toString().toLowerCase().contains('técnico') ||
            rol.toString().toLowerCase().contains('tecnico');

        final configDoc = await _db.collection('configuracion').doc('general').get();
        final configData = configDoc.data() ?? {};
        final tarifa = esTec
            ? (configData['tarifaTecnico'] ?? configData['tarifaPorCasa'] ?? 0.0).toDouble()
            : (configData['tarifaAyudante'] ?? 0.0).toDouble();

        registrosActualizados = List<RegistroNominaItem>.from(semana.registros)
          ..add(RegistroNominaItem(
            trabajadorId: trabajadorId,
            trabajadorNombre: nombre,
            rol: rol,
            diasOcasas: 0.0,
            tarifaUnitaria: tarifa,
            bonificaciones: monto,
          ));
      }

      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('[FirestoreService] Error al actualizar bonificación: $e');
      rethrow;
    }
  }

  // ================= ABONOS Y PAGOS PARCIALES A NÓMINA =================

  /// Registra un abono/pago parcial a un trabajador, actualiza totalPagado y auto-sincroniza con Gastos
  Future<void> registrarAbonoTrabajador({
    required String semanaId,
    required String trabajadorId,
    required double monto,
    String? concepto,
    String? metodoPago,
  }) async {
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) return;

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
      String nombreTrabajador = 'Trabajador';
      final abonoId = _db.collection('semanas').doc().id;

      final conceptoFinal = (concepto != null && concepto.trim().isNotEmpty)
          ? concepto.trim()
          : 'Abono / Pago parcial';

      final nuevoAbono = PagoItemModel(
        id: abonoId,
        trabajadorId: trabajadorId,
        trabajadorNombre: '',
        monto: monto,
        fecha: DateTime.now(),
        observacion: conceptoFinal,
        metodoPago: metodoPago ?? 'Efectivo',
        semanaId: semanaId,
      );

      final registrosActualizados = semana.registros.map((item) {
        if (item.trabajadorId == trabajadorId) {
          nombreTrabajador = item.trabajadorNombre;
          final abonoConNombre = nuevoAbono.copyWith(trabajadorNombre: item.trabajadorNombre);

          // Si el trabajador ya tenía totalPagado legacy pero la lista de pagos estaba vacía,
          // creamos un abono inicial para no perder ese registro previo en el historial.
          final List<PagoItemModel> listaPagos = List<PagoItemModel>.from(item.pagos);
          if (listaPagos.isEmpty && item.totalPagado > 0) {
            listaPagos.add(PagoItemModel(
              id: 'legacy_${item.trabajadorId}',
              trabajadorId: item.trabajadorId,
              trabajadorNombre: item.trabajadorNombre,
              monto: item.totalPagado,
              fecha: semana.fechaInicio,
              observacion: 'Abono acumulado inicial',
              metodoPago: 'Efectivo',
              semanaId: semanaId,
            ));
          }

          listaPagos.add(abonoConNombre);
          final nuevoTotalPagado = listaPagos.fold<double>(0.0, (acc, p) => acc + p.monto);

          return item.copyWith(
            totalPagado: nuevoTotalPagado,
            pagos: listaPagos,
          );
        }
        return item;
      }).toList();

      final abonoConNombreSemana = nuevoAbono.copyWith(trabajadorNombre: nombreTrabajador);
      final pagosSemanaActualizados = List<PagoItemModel>.from(semana.pagos)..add(abonoConNombreSemana);

      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
        'pagos': pagosSemanaActualizados.map((x) => x.toMap()).toList(),
      });

      // Auto-sincronización con Gastos bajo ID determinista único 'abono_$abonoId'
      final descConcepto = (concepto != null && concepto.trim().isNotEmpty) ? ' ($concepto)' : '';
      final docGastoId = 'abono_$abonoId';
      await _db.collection('gastos').doc(docGastoId).set({
        'id': docGastoId,
        'semanaId': semanaId,
        'categoria': 'Pagos a Trabajadores',
        'descripcion': 'Abono de Nómina: $nombreTrabajador$descConcepto',
        'monto': monto,
        'fecha': DateTime.now().toIso8601String(),
        'esAutomaticoNomina': true,
        'abonoId': abonoId,
        'trabajadorId': trabajadorId,
        'responsable': nombreTrabajador,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error al registrar abono a trabajador: $e');
      rethrow;
    }
  }

  /// Modifica un abono de pago existente, recalculando totalPagado y actualizando el gasto asociado con ID determinista
  Future<void> editarAbonoTrabajador({
    required String semanaId,
    required String abonoId,
    required String trabajadorId,
    required double nuevoMonto,
    String? nuevoConcepto,
  }) async {
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) return;

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
      String nombreTrabajador = '';

      final registrosActualizados = semana.registros.map((item) {
        if (item.trabajadorId == trabajadorId || item.pagos.any((p) => p.id == abonoId)) {
          nombreTrabajador = item.trabajadorNombre;
          final nuevosPagos = item.pagos.map((p) {
            if (p.id == abonoId) {
              return p.copyWith(
                monto: nuevoMonto,
                observacion: (nuevoConcepto != null && nuevoConcepto.trim().isNotEmpty)
                    ? nuevoConcepto.trim()
                    : p.observacion,
              );
            }
            return p;
          }).toList();

          final nuevoTotalPagado = nuevosPagos.fold<double>(0.0, (acc, p) => acc + p.monto);
          return item.copyWith(
            totalPagado: nuevoTotalPagado,
            pagos: nuevosPagos,
          );
        }
        return item;
      }).toList();

      final pagosSemanaActualizados = semana.pagos.map((p) {
        if (p.id == abonoId) {
          return p.copyWith(
            monto: nuevoMonto,
            observacion: (nuevoConcepto != null && nuevoConcepto.trim().isNotEmpty)
                ? nuevoConcepto.trim()
                : p.observacion,
          );
        }
        return p;
      }).toList();

      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
        'pagos': pagosSemanaActualizados.map((x) => x.toMap()).toList(),
      });

      // Actualizar gasto asociado con ID determinista 'abono_$abonoId'
      final docGastoId = 'abono_$abonoId';
      final descConcepto = (nuevoConcepto != null && nuevoConcepto.trim().isNotEmpty)
          ? ' ($nuevoConcepto)'
          : '';

      await _db.collection('gastos').doc(docGastoId).set({
        'id': docGastoId,
        'semanaId': semanaId,
        'categoria': 'Pagos a Trabajadores',
        'descripcion': 'Abono de Nómina: $nombreTrabajador$descConcepto',
        'monto': nuevoMonto,
        'esAutomaticoNomina': true,
        'abonoId': abonoId,
        'trabajadorId': trabajadorId,
        'responsable': nombreTrabajador,
      }, SetOptions(merge: true));

      // Limpiar duplicados legacy si existieran
      try {
        final legacyQuery = await _db
            .collection('gastos')
            .where('semanaId', isEqualTo: semanaId)
            .where('abonoId', isEqualTo: abonoId)
            .get();
        for (final doc in legacyQuery.docs) {
          if (doc.id != docGastoId) {
            await doc.reference.delete();
          }
        }
      } catch (e) {
        debugPrint('[FirestoreService] Advertencia al depurar legacy en editar: $e');
      }
    } catch (e) {
      debugPrint('[FirestoreService] Error al editar abono de trabajador: $e');
      rethrow;
    }
  }

  /// Elimina un abono de pago, recalculando totalPagado y removiendo el gasto determinista y huérfanos
  Future<void> eliminarAbonoTrabajador({
    required String semanaId,
    required String abonoId,
    required String trabajadorId,
  }) async {
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) return;

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
      String nombreTrabajador = '';

      final registrosActualizados = semana.registros.map((item) {
        if (item.trabajadorId == trabajadorId || item.pagos.any((p) => p.id == abonoId)) {
          nombreTrabajador = item.trabajadorNombre;
          final nuevosPagos = item.pagos.where((p) => p.id != abonoId).toList();
          final nuevoTotalPagado = nuevosPagos.fold<double>(0.0, (acc, p) => acc + p.monto);
          return item.copyWith(
            totalPagado: nuevoTotalPagado,
            pagos: nuevosPagos,
          );
        }
        return item;
      }).toList();

      final pagosSemanaActualizados = semana.pagos.where((p) => p.id != abonoId).toList();

      await _db.collection('semanas').doc(semanaId).update({
        'registros': registrosActualizados.map((x) => x.toMap()).toList(),
        'pagos': pagosSemanaActualizados.map((x) => x.toMap()).toList(),
      });

      // Eliminar gasto determinista
      final docGastoId = 'abono_$abonoId';
      await _db.collection('gastos').doc(docGastoId).delete();

      // Eliminar cualquier gasto legacy residual asociado a este abonoId o nombre
      try {
        final gastosQuery = await _db
            .collection('gastos')
            .where('semanaId', isEqualTo: semanaId)
            .where('categoria', isEqualTo: 'Pagos a Trabajadores')
            .get();

        for (final doc in gastosQuery.docs) {
          final data = doc.data();
          final docAbonoId = data['abonoId']?.toString();
          final desc = data['descripcion']?.toString() ?? '';

          if (docAbonoId == abonoId ||
              (docAbonoId == null && desc.contains('Abono de Nómina: $nombreTrabajador'))) {
            await _db.collection('gastos').doc(doc.id).delete();
          }
        }
      } catch (e) {
        debugPrint('[FirestoreService] Advertencia al eliminar gasto de abono: $e');
      }
    } catch (e) {
      debugPrint('[FirestoreService] Error al eliminar abono de trabajador: $e');
      rethrow;
    }
  }

  /// Reconcilia y limpia exhaustivamente los gastos de nómina de una semana en Firestore,
  /// eliminando documentos huérfanos, duplicados o legacy, y asegurando IDs deterministas ('abono_${pago.id}').
  Future<Map<String, dynamic>> limpiarYReconciliarGastosNomina({required String semanaId}) async {
    try {
      final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
      if (!semanaDoc.exists || semanaDoc.data() == null) {
        return {'eliminados': 0, 'sincronizados': 0, 'totalNominaPagada': 0.0};
      }

      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);

      // 1. Extraer los pagos canónicos oficiales de la planilla de nómina
      final Map<String, PagoItemModel> pagosOficiales = {};

      for (final reg in semana.registros) {
        if (reg.pagos.isNotEmpty) {
          for (final p in reg.pagos) {
            if (p.monto > 0) {
              pagosOficiales[p.id] = p.trabajadorNombre.isNotEmpty
                  ? p
                  : p.copyWith(trabajadorNombre: reg.trabajadorNombre);
            }
          }
        } else if (reg.totalPagado > 0) {
          final pId = 'pago_base_${reg.trabajadorId}';
          pagosOficiales[pId] = PagoItemModel(
            id: pId,
            trabajadorId: reg.trabajadorId,
            trabajadorNombre: reg.trabajadorNombre,
            monto: reg.totalPagado,
            fecha: semana.fechaInicio,
            observacion: 'Abono registrado en planilla',
            metodoPago: 'Efectivo',
            semanaId: semanaId,
          );
        }
      }

      // Complementar con pagos registrados a nivel de semana si tienen ID único no presente
      for (final p in semana.pagos) {
        if (p.monto > 0 && !pagosOficiales.containsKey(p.id)) {
          pagosOficiales[p.id] = p;
        }
      }

      final double totalNominaPagadaOficial = semana.registros.fold<double>(
        0.0,
        (acc, r) => acc + r.totalPagado,
      );

      // 2. Consultar todos los gastos de la semana que sean de nómina
      final gastosSnapshot = await _db
          .collection('gastos')
          .where('semanaId', isEqualTo: semanaId)
          .get();

      final List<DocumentSnapshot> gastosNominaAEliminar = [];

      for (final doc in gastosSnapshot.docs) {
        final data = doc.data();
        final esAutoNomina = data['esAutomaticoNomina'] == true;
        final categoria = data['categoria']?.toString() ?? '';
        final desc = data['descripcion']?.toString().toLowerCase() ?? '';
        final docId = doc.id;

        final esDeNomina = esAutoNomina ||
            categoria == 'Pagos a Trabajadores' ||
            desc.contains('abono de nómina') ||
            desc.contains('abono de nomina') ||
            docId.startsWith('abono_') ||
            docId.startsWith('gasto_abono_') ||
            (data['abonoId'] != null && data['abonoId'].toString().isNotEmpty);

        if (esDeNomina) {
          gastosNominaAEliminar.add(doc);
        }
      }

      // 3. Ejecutar WriteBatch para eliminar los gastos de nómina viejos o duplicados
      var batch = _db.batch();
      int batchCount = 0;
      int eliminados = 0;

      for (final doc in gastosNominaAEliminar) {
        batch.delete(doc.reference);
        eliminados++;
        batchCount++;
        if (batchCount >= 400) {
          await batch.commit();
          batch = _db.batch();
          batchCount = 0;
        }
      }

      // 4. Crear exactamente un gasto por cada pago oficial con ID determinista 'abono_${p.id}'
      int sincronizados = 0;
      for (final p in pagosOficiales.values) {
        final deterministicId = 'abono_${p.id}';
        final docRef = _db.collection('gastos').doc(deterministicId);

        final descConcepto = (p.observacion.isNotEmpty && !p.observacion.toLowerCase().contains('abono'))
            ? ' (${p.observacion})'
            : '';

        batch.set(docRef, {
          'id': deterministicId,
          'semanaId': semanaId,
          'categoria': 'Pagos a Trabajadores',
          'descripcion': 'Abono de Nómina: ${p.trabajadorNombre}$descConcepto',
          'monto': p.monto,
          'fecha': p.fecha.toIso8601String(),
          'esAutomaticoNomina': true,
          'abonoId': p.id,
          'trabajadorId': p.trabajadorId,
          'responsable': p.trabajadorNombre,
        }, SetOptions(merge: true));

        sincronizados++;
        batchCount++;
        if (batchCount >= 400) {
          await batch.commit();
          batch = _db.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      return {
        'eliminados': eliminados,
        'sincronizados': sincronizados,
        'totalNominaPagada': totalNominaPagadaOficial,
      };
    } catch (e) {
      debugPrint('[FirestoreService] Error al limpiar y reconciliar gastos de nómina: $e');
      rethrow;
    }
  }

  /// Depura y elimina documentos duplicados de abonos en la colección de gastos
  Future<int> depurarGastosDuplicadosSemana(String semanaId) async {
    final res = await limpiarYReconciliarGastosNomina(semanaId: semanaId);
    return (res['eliminados'] as int?) ?? 0;
  }

  /// Método de compatibilidad anterior para registrar abono
  Future<void> registrarAbonoPago({
    required String semanaId,
    required String trabajadorId,
    required double montoAbono,
  }) async {
    await registrarAbonoTrabajador(
      semanaId: semanaId,
      trabajadorId: trabajadorId,
      monto: montoAbono,
    );
  }

  // ================= PRÉSTAMOS / VALES =================
  /// Registra un préstamo / vale, actualiza el saldo de nómina y auto-sincroniza en Gastos
  Future<void> registrarPrestamo({
    required String semanaId,
    required PrestamoModel prestamo,
  }) async {
    // 1. Asignar ID si viene vacío y guardar en colección prestamos para auditoría
    final docRef = prestamo.id.isNotEmpty
        ? _db.collection('prestamos').doc(prestamo.id)
        : _db.collection('prestamos').doc();

    final prestamoConId = prestamo.copyWith(id: docRef.id);
    await docRef.set(prestamoConId.toMap());

    // 2. Descontar en la semana activa sumando al totalAdelantos del trabajador
    final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
    if (semanaDoc.exists && semanaDoc.data() != null) {
      final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
      final prestamosActualizados = List<PrestamoModel>.from(semana.prestamos)..add(prestamoConId);

      final registrosActualizados = semana.registros.map((item) {
        if (item.trabajadorId == prestamo.trabajadorId) {
          final prestamosDelItem = List<PrestamoModel>.from(item.prestamos)..add(prestamoConId);
          final totalAdelantosRecalculado = prestamosDelItem.fold<double>(
            0.0,
            (acc, p) => acc + p.monto,
          );
          return item.copyWith(
            totalAdelantos: totalAdelantosRecalculado,
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
      'descripcion': 'Préstamo / Vale: ${prestamoConId.trabajadorNombre} (${prestamoConId.concepto})',
      'monto': prestamoConId.monto,
      'fecha': prestamoConId.fecha.toIso8601String(),
      'esAutomaticoNomina': false,
    });
  }

  /// Modifica un préstamo / vale existente, actualiza el saldo de nómina y ajusta el gasto correspondiente
  Future<void> editarPrestamo({
    required String semanaId,
    required String prestamoId,
    required double nuevoMonto,
    required String nuevoConcepto,
  }) async {
    // 1. Actualizar documento en colección prestamos si existe
    if (prestamoId.isNotEmpty) {
      await _db.collection('prestamos').doc(prestamoId).update({
        'monto': nuevoMonto,
        'concepto': nuevoConcepto,
      }).catchError((_) {});
    }

    // 2. Actualizar en el documento de semana
    final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
    if (!semanaDoc.exists || semanaDoc.data() == null) return;

    final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
    String trabajadorIdAfectado = '';
    String trabajadorNombreAfectado = '';

    final prestamosActualizados = semana.prestamos.map((p) {
      if (p.id == prestamoId) {
        trabajadorIdAfectado = p.trabajadorId;
        trabajadorNombreAfectado = p.trabajadorNombre;
        return p.copyWith(monto: nuevoMonto, concepto: nuevoConcepto);
      }
      return p;
    }).toList();

    final registrosActualizados = semana.registros.map((item) {
      if (item.trabajadorId == trabajadorIdAfectado ||
          item.prestamos.any((p) => p.id == prestamoId)) {
        final nuevosPrestamosItem = item.prestamos.map((p) {
          if (p.id == prestamoId) {
            return p.copyWith(monto: nuevoMonto, concepto: nuevoConcepto);
          }
          return p;
        }).toList();

        final totalAdelantosRecalculado = nuevosPrestamosItem.fold<double>(
          0.0,
          (acc, p) => acc + p.monto,
        );

        return item.copyWith(
          totalAdelantos: totalAdelantosRecalculado,
          prestamos: nuevosPrestamosItem,
        );
      }
      return item;
    }).toList();

    await _db.collection('semanas').doc(semanaId).update({
      'registros': registrosActualizados.map((x) => x.toMap()).toList(),
      'prestamos': prestamosActualizados.map((x) => x.toMap()).toList(),
    });

    // 3. Actualizar gasto relacionado si existe
    try {
      final gastosQuery = await _db
          .collection('gastos')
          .where('semanaId', isEqualTo: semanaId)
          .where('categoria', isEqualTo: 'Pagos a Trabajadores')
          .get();

      for (final doc in gastosQuery.docs) {
        final desc = doc.data()['descripcion']?.toString() ?? '';
        if (desc.contains('Préstamo / Vale:') &&
            (desc.contains(trabajadorNombreAfectado) || desc.contains(nuevoConcepto))) {
          await _db.collection('gastos').doc(doc.id).update({
            'monto': nuevoMonto,
            'descripcion': 'Préstamo / Vale: $trabajadorNombreAfectado ($nuevoConcepto)',
          });
          break;
        }
      }
    } catch (_) {}
  }

  /// Elimina un préstamo / vale, recalcula el saldo de nómina y remueve el gasto asociado
  Future<void> eliminarPrestamo({
    required String semanaId,
    required String prestamoId,
  }) async {
    // 1. Eliminar documento de la colección prestamos si existe
    if (prestamoId.isNotEmpty) {
      await _db.collection('prestamos').doc(prestamoId).delete().catchError((_) {});
    }

    // 2. Actualizar en el documento de semana
    final semanaDoc = await _db.collection('semanas').doc(semanaId).get();
    if (!semanaDoc.exists || semanaDoc.data() == null) return;

    final semana = SemanaModel.fromMap(semanaDoc.id, semanaDoc.data()!);
    PrestamoModel? prestamoEliminado;

    final prestamosActualizados = <PrestamoModel>[];
    for (final p in semana.prestamos) {
      if (p.id == prestamoId) {
        prestamoEliminado = p;
      } else {
        prestamosActualizados.add(p);
      }
    }

    final trabajadorIdAfectado = prestamoEliminado?.trabajadorId ?? '';
    final trabajadorNombreAfectado = prestamoEliminado?.trabajadorNombre ?? '';
    final conceptoEliminado = prestamoEliminado?.concepto ?? '';

    final registrosActualizados = semana.registros.map((item) {
      if (item.trabajadorId == trabajadorIdAfectado ||
          item.prestamos.any((p) => p.id == prestamoId)) {
        final nuevosPrestamosItem = item.prestamos.where((p) => p.id != prestamoId).toList();
        final totalAdelantosRecalculado = nuevosPrestamosItem.fold<double>(
          0.0,
          (acc, p) => acc + p.monto,
        );
        return item.copyWith(
          totalAdelantos: totalAdelantosRecalculado,
          prestamos: nuevosPrestamosItem,
        );
      }
      return item;
    }).toList();

    await _db.collection('semanas').doc(semanaId).update({
      'registros': registrosActualizados.map((x) => x.toMap()).toList(),
      'prestamos': prestamosActualizados.map((x) => x.toMap()).toList(),
    });

    // 3. Eliminar gasto asociado si existe
    try {
      final gastosQuery = await _db
          .collection('gastos')
          .where('semanaId', isEqualTo: semanaId)
          .where('categoria', isEqualTo: 'Pagos a Trabajadores')
          .get();

      for (final doc in gastosQuery.docs) {
        final desc = doc.data()['descripcion']?.toString() ?? '';
        if (desc.contains('Préstamo / Vale:') &&
            (desc.contains(trabajadorNombreAfectado) || desc.contains(conceptoEliminado))) {
          await _db.collection('gastos').doc(doc.id).delete();
          break;
        }
      }
    } catch (_) {}
  }

  // ================= GASTOS =================
  /// Stream en tiempo real de todos los gastos de obra históricos
  Stream<List<GastoModel>> streamTodosLosGastos() {
    return _db
        .collection('gastos')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GastoModel.fromMap(doc.id, doc.data())).toList());
  }

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

  // ================= INGRESOS =================
  /// Stream en tiempo real de todos los ingresos de obra
  Stream<List<IngresoModel>> streamIngresos() {
    return _db
        .collection('ingresos')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => IngresoModel.fromMap(doc.id, doc.data())).toList())
        .handleError((Object e) {
          debugPrint('[FirestoreService] streamIngresos error: $e');
        });
  }

  /// Stream de ingresos en un rango de fechas específico
  Stream<List<IngresoModel>> streamIngresosPorRango(DateTime inicio, DateTime fin) {
    final iniStr = DateTime(inicio.year, inicio.month, inicio.day, 0, 0, 0).toIso8601String();
    final finStr = DateTime(fin.year, fin.month, fin.day, 23, 59, 59, 999).toIso8601String();
    return _db
        .collection('ingresos')
        .where('fecha', isGreaterThanOrEqualTo: iniStr)
        .where('fecha', isLessThanOrEqualTo: finStr)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => IngresoModel.fromMap(doc.id, doc.data())).toList())
        .handleError((Object e) {
          debugPrint('[FirestoreService] streamIngresosPorRango error: $e');
        });
  }

  Future<String> registrarIngreso(IngresoModel ingreso) async {
    if (ingreso.id.isEmpty) {
      final docRef = await _db.collection('ingresos').add(ingreso.toMap());
      return docRef.id;
    } else {
      await _db.collection('ingresos').doc(ingreso.id).set(ingreso.toMap(), SetOptions(merge: true));
      return ingreso.id;
    }
  }

  Future<void> actualizarIngreso(IngresoModel ingreso) async {
    await _db.collection('ingresos').doc(ingreso.id).set(ingreso.toMap(), SetOptions(merge: true));
  }

  Future<void> eliminarIngreso(String ingresoId) async {
    await _db.collection('ingresos').doc(ingresoId).delete();
  }

  // ================= PRÉSTAMOS A TERCEROS / CARTERA =================
  Stream<List<PrestamoTerceroModel>> streamPrestamosTerceros() {
    return _db
        .collection('prestamos_terceros')
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => PrestamoTerceroModel.fromMap(doc.id, doc.data()))
              .toList();
          items.sort((a, b) => b.fechaRegistro.compareTo(a.fechaRegistro));
          return items;
        });
  }

  Future<String> registrarPrestamoTercero(PrestamoTerceroModel prestamo) async {
    if (prestamo.id.isEmpty) {
      final docRef = await _db.collection('prestamos_terceros').add(prestamo.toMap());
      return docRef.id;
    } else {
      await _db
          .collection('prestamos_terceros')
          .doc(prestamo.id)
          .set(prestamo.toMap(), SetOptions(merge: true));
      return prestamo.id;
    }
  }

  Future<void> editarPrestamoTercero(PrestamoTerceroModel prestamo) async {
    await _db
        .collection('prestamos_terceros')
        .doc(prestamo.id)
        .set(prestamo.toMap(), SetOptions(merge: true));
  }

  Future<void> eliminarPrestamoTercero(String prestamoId) async {
    await _db.collection('prestamos_terceros').doc(prestamoId).delete();
  }

  Future<void> registrarAbonoPrestamoTercero({
    required String prestamoId,
    required double monto,
    required String metodoPago,
    String? observacion,
  }) async {
    final docRef = _db.collection('prestamos_terceros').doc(prestamoId);
    final docSnap = await docRef.get();
    if (!docSnap.exists || docSnap.data() == null) {
      throw Exception('El préstamo $prestamoId no existe.');
    }

    final prestamo = PrestamoTerceroModel.fromMap(docSnap.id, docSnap.data()!);
    final nuevoAbono = AbonoPrestamoModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      monto: monto,
      fecha: DateTime.now(),
      metodoPago: metodoPago,
      observacion: observacion,
    );

    final listaAbonos = [...prestamo.historialAbonos, nuevoAbono];
    final nuevoTotalAbonado = prestamo.totalAbonado + monto;
    final nuevoEstado = (prestamo.montoPrestado - nuevoTotalAbonado <= 0) ? 'Saldado' : 'Pendiente';

    await docRef.update({
      'totalAbonado': nuevoTotalAbonado,
      'estado': nuevoEstado,
      'historialAbonos': listaAbonos.map((a) => a.toMap()).toList(),
    });
  }

  // ================= IMPORTACIÓN MASIVA DE VIVIENDAS DESDE EXCEL =================

  /// Representa el resultado de la previsualización antes de importar.
  /// [filas] contiene todas las filas parseadas.
  /// [duplicados] contiene los códigos que ya existen en Firestore.
  /// [filasVacias] es la cantidad de filas omitidas por estar vacías.

  /// Importa masivamente viviendas desde filas ya parseadas del Excel.
  /// Crea lotes automáticamente si no existen. Usa WriteBatch en bloques de 400.
  /// Retorna un mapa con conteos: {'insertadas', 'omitidas', 'lotes_creados'}.
  Future<Map<String, int>> importarViviendasDesdeExcel({
    required List<Map<String, String>> filas,
    required Map<String, LoteModel> lotesExistentes,
  }) async {
    int insertadas = 0;
    int omitidas = 0;
    int lotesCreados = 0;

    // Cache local de loteId por nombre para evitar consultas repetidas
    final Map<String, String> cacheNombreLoteId = {};
    for (final lote in lotesExistentes.values) {
      cacheNombreLoteId[lote.nombre.trim().toLowerCase()] = lote.id;
    }

    WriteBatch batch = _db.batch();
    int opsCount = 0;

    for (final fila in filas) {
      final nombreLote = (fila['lote'] ?? '').trim();
      final manzana = (fila['manzana'] ?? '').trim().toUpperCase();
      final numeroCasaStr = (fila['numeroCasa'] ?? '').trim();
      final nombrePropietario = (fila['nombrePropietario'] ?? '').trim();
      final cedula = (fila['cedula'] ?? '').trim();
      final telefono = (fila['telefono'] ?? '').trim();
      final direccion = (fila['direccion'] ?? '').trim();

      if (nombreLote.isEmpty || manzana.isEmpty || numeroCasaStr.isEmpty) {
        omitidas++;
        continue;
      }

      // Obtener o crear el lote
      String loteId;
      final cacheKey = nombreLote.toLowerCase();
      if (cacheNombreLoteId.containsKey(cacheKey)) {
        loteId = cacheNombreLoteId[cacheKey]!;
      } else {
        // Crear lote automáticamente
        final loteRef = _db.collection('lotes').doc();
        loteId = loteRef.id;
        final prefijoAuto = manzana.length <= 4 ? manzana : manzana.substring(0, 4);
        final nuevoLote = LoteModel(
          id: loteId,
          nombre: nombreLote,
          prefijo: prefijoAuto,
          cantidadCasas: 0,
          fechaCreacion: DateTime.now(),
        );
        batch.set(loteRef, nuevoLote.toMap());
        opsCount++;
        cacheNombreLoteId[cacheKey] = loteId;
        lotesCreados++;
      }

      // Construir el código de casa y el docId compuesto
      final codigoCasa = '${manzana}_${numeroCasaStr.padLeft(2, '0')}';
      final docId = ViviendaModel.generarIdCompuesto(loteId, codigoCasa);

      // Verificar colisión: si ya existe en Firestore, omitir
      final docSnap = await _db.collection('viviendas').doc(docId).get();
      if (docSnap.exists) {
        omitidas++;
        continue;
      }

      final numCasa = int.tryParse(numeroCasaStr) ?? 0;
      final vivienda = ViviendaModel(
        id: docId,
        codigo: codigoCasa,
        loteId: loteId,
        loteNombre: nombreLote,
        numeroCasa: numCasa,
        estado: 'Pendiente',
        nombrePropietario: nombrePropietario,
        propietarioCedula: cedula,
        propietarioTelefono: telefono,
        direccion: direccion,
        fechaRegistro: DateTime.now(),
      );

      batch.set(_db.collection('viviendas').doc(docId), vivienda.toMap());
      // Actualizar contador de casas del lote
      batch.update(_db.collection('lotes').doc(loteId), {
        'cantidadCasas': FieldValue.increment(1),
      });
      opsCount += 2;
      insertadas++;

      if (opsCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        opsCount = 0;
      }
    }

    if (opsCount > 0) {
      await batch.commit();
    }

    return {
      'insertadas': insertadas,
      'omitidas': omitidas,
      'lotes_creados': lotesCreados,
    };
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
      'ingresos',
      'prestamos_terceros',
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