# 📘 APP_CONTEXT — Control Gas App

## 1. 🌟 Visión General
- **Estado Actual:** 🟢 **PRODUCCIÓN ACTIVA / DESPLEGADO (v1.0.0)**
- **Acceso Web Oficial:** [https://control-gas-natural.web.app](https://control-gas-natural.web.app)
- **Instalador Android (APK):** `build/app/outputs/flutter-apk/app-release.apk` (62.8 MB)

**Control Gas App** es una aplicación multiplataforma construida con **Flutter** y **Firebase** (Firestore, Auth, Storage, Hosting) diseñada para la administración integral de obras civiles de instalación de gas domiciliario. Permite controlar en tiempo real el avance de obras por etapas/lotes, la asistencia diaria de personal, el cálculo y liquidación de nómina de ayudantes y técnicos, y la gestión de gastos operacionales e ingresos del contratista.

---

## 2. 🏛️ Arquitectura del Proyecto

El proyecto sigue una arquitectura limpia orientada a componentes, servicios y proveedores de estado:

```text
lib/
├── models/         # Modelos puros de datos con serialización toMap() y fromMap()
│   ├── configuracion_model.dart
│   ├── etapa_model.dart
│   ├── gasto_model.dart
│   ├── lote_model.dart
│   ├── semana_model.dart
│   ├── trabajador_model.dart
│   ├── usuario_model.dart
│   └── vivienda_model.dart
├── providers/      # Manejo de estado reactivo global con Provider
│   ├── auth_provider.dart       # Sesión, rol del usuario (Dueño/Técnico) y PIN
│   └── proyecto_provider.dart   # Datos consolidados del proyecto, configuración y semana activa
├── screens/        # Vistas y pantallas principales de la aplicación
│   ├── configuracion_screen.dart # Tarifas globales, etapas, lotes y PIN de seguridad
│   ├── gastos_screen.dart        # Registro y visualización de gastos de obra
│   ├── home_dashboard_screen.dart# Métricas de avance, checklist de asistencia, Drawer y AppBar corporativo
│   ├── lote_detail_screen.dart   # Grilla de viviendas, visor de fotos y asignación técnica
│   ├── login_screen.dart         # Autenticación con logo corporativo ELECTRO - GAS (Acceso real)
│   ├── nomina_screen.dart        # Planilla, Ayudantes (con detalle de fechas y Excel), Técnicos y Personal
│   └── viviendas_screen.dart     # Vista global consolidada de viviendas por lote
├── services/       # Capa de infraestructura y servicios externos
│   ├── auth_service.dart         # Integración con Firebase Authentication (Sin mocks)
│   ├── excel_service.dart        # Exportación de reportes de obra y planillas de asistencia
│   ├── firestore_service.dart    # Operaciones CRUD, Streams y función de reset total de datos
│   ├── pdf_service.dart          # Comprobantes de pago con membrete ELECTRO - GAS
│   └── storage_service.dart      # Carga de fotos de evidencia técnica a Firebase Storage
├── utils/          # Utilidades transversales multiplataforma
│   ├── download_helper.dart      # Abstracción condicional de descarga web / móvil
│   ├── download_helper_web.dart  # Descarga en web vía Blob y AnchorElement
│   ├── download_helper_io.dart   # Guardado local y compartición en Android/iOS/Desktop
│   └── download_helper_stub.dart # Stub de soporte multiplataforma
└── widgets/        # Componentes reutilizables y modales
    ├── custom_card_widget.dart   # Tarjetas métricas visuales
    ├── foto_lightbox_dialog.dart # Visor Lightbox pantalla completa con zoom y descarga
    └── pin_modal_widget.dart     # Modal con teclado numérico para validación de PIN
```

---

## 3. 📊 Modelos de Datos Principales

### `TrabajadorModel`
- **Campos:** `id`, `nombre`, `cedula`, `telefono`, `rol` (`'Ayudante'`, `'Técnico'`, `'Dueño con labor de Técnico'`), `activo`.
- **Propiedades computadas:** `esAyudante`, `esTecnico`.

### `ViviendaModel`
- **Campos:** `id` (Código manzana/lote ej: "M1-L05"), `loteId`, `loteNombre`, `estado` (`'Pendiente'`, `'En Proceso'`, `'Terminada'`), `tecnicoId`, `tecnicoNombre`, `observaciones`, `fotos`, `propietarioCedula`, `propietarioTelefono`, `direccion`, `fechaRegistro`, `fechaInstalacion`, `fechaTerminacion`, `semanaId`.

### `SemanaModel` y Submodelos
- **`SemanaModel`:** `id`, `numeroSemana`, `fechaInicio`, `fechaFin`, `cerrada`, `registros` (`List<RegistroNominaItem>`), `prestamos` (`List<PrestamoModel>`).
- **`RegistroNominaItem`:** `trabajadorId`, `trabajadorNombre`, `rol`, `diasOcasas`, `tarifaUnitaria`, `totalAdelantos`, `totalPagado`, `prestamos`.
- **`AsistenciaModel`:** `id` (compuesto: `ayudanteId_YYYY_MM_DD`), `ayudanteId`, `nombre`, `fecha`, `asistio`, `semanaId`.
- **`PrestamoModel`:** `id`, `trabajadorId`, `trabajadorNombre`, `monto`, `fecha`, `concepto`, `semanaId`.

---

## 4. ⚙️ Reglas de Negocio y Lógica de Nómina

### 👷 1. Liquidación de Ayudantes de Obra
* **Métrica Base:** Días efectivamente laborados en la semana activa.
* **Cálculo Bruto:** $\text{Total Devengado} = \text{Días Asistidos} \times \text{Tarifa Diaria de Ayudante}$.
* **Descuentos:** Vales/Adelantos de nómina registrados en la semana + Pagos parciales.
* **Saldo Neto a Pagar:** $\text{Neto} = \text{Total Devengado} - \text{Total Vales} - \text{Total Pagado}$.
* **Sincronización:** Cada vez que se marca la asistencia en el Dashboard o en la pantalla de Nómina, el conteo de días asistidos se recalcula y sincroniza automáticamente en Firestore.
* **Comprobante PDF:** Genera plantilla especializada con detalle de jornadas, lista discriminada de vales con fecha/concepto, resumen financiero y firmas de empleado y administración.

### 🔧 2. Liquidación de Técnicos e Instaladores
* **Métrica Base:** Cantidad de casas en estado `"Terminada"` ejecutadas por el técnico durante la semana activa.
* **Cálculo Bruto:** $\text{Total Bruto} = \text{Casas Terminadas} \times \text{Tarifa por Casa de Técnico}$.
* **Descuentos:** Vales/Adelantos de nómina registrados en la semana + Pagos parciales.
* **Saldo Neto a Pagar:** $\text{Neto} = \text{Total Bruto} - \text{Total Vales} - \text{Total Pagado}$.
* **Sincronización:** Al marcar una vivienda como `"Terminada"` en `LoteDetailScreen`, se sella automáticamente la `fechaTerminacion` y se vincula al `semanaId` activo, reflejando el incremento inmediatamente en la tarjeta del técnico en Nómina.
* **Comprobante PDF:** Genera plantilla técnica con tabla detallada enumerando cada casa terminada (`#`, `Código`, `Lote/Ubicación`, `Fecha`, `Tarifa`, `Subtotal`), totalizador de casas, vales descontados, saldo neto y firma de recepción conforme.

### 🛡️ 3. Manejo de Técnicos Eliminados e Inactivos (Trazabilidad Histórica)
* **Principio de Trazabilidad:** Al eliminar un trabajador de la colección `trabajadores`, su `id` y nombre permanecen registrados en las viviendas que haya ejecutado previamente para salvaguardar la auditoría de la obra.
* **Prevención de `Assertion failed`:**
  - En `LoteDetailScreen`, las búsquedas por `tecnicoId` usan métodos seguros con fallback (`firstOrNull`).
  - Los dropdowns (`DropdownButtonFormField`) incluyen dinámicamente un `DropdownMenuItem` para el técnico eliminado o inactivo (`"Técnico no disponible / Eliminado"`), garantizando que el valor inicial exista siempre en la lista y evitando excepciones de aserción.

---

## 5. 🔄 Flujos de Reactividad en Tiempo Real

1. **Dashboard ↔ Asistencia ↔ Nómina:**
   - La asistencia se consulta mediante `streamAsistenciasPorFecha(DateTime fecha)`.
   - Al conmutar el switch, `registrarAsistencia(...)` persiste el estado y ejecuta `sincronizarDiasAsistidosAyudante(...)`.
   - Si el ayudante aún no figuraba en `semana.registros`, el servicio lo incorpora automáticamente con su tarifa configurada.
   - `ProyectoProvider` detecta la actualización del documento de la semana y refresca la UI sin recargar.

2. **Detalle de Lote ↔ Casas Terminadas ↔ Nómina de Técnicos:**
   - En `LoteDetailScreen`, al cambiar el estado a `"Terminada"`, se auto-asigna la fecha de terminación y el ID de la semana activa.
   - La pestaña de Técnicos en `NominaScreen` se alimenta de `streamCasasTerminadasTecnicoEnSemana(...)`, escuchando en tiempo real las viviendas del técnico y calculando al vuelo su saldo acumulado y la lista de casas completadas.

3. **Gestión de Personal:**
   - La colección `trabajadores` se consume mediante `streamTrabajadoresActivos()` (para nómina) y `streamTrabajadores()` (para administración).
   - Crear, editar o activar/desactivar un trabajador actualiza de inmediato todas las pantallas dependientes.

---

## 6. 🔐 Control de Acceso (RBAC) y Seguridad
- **Dueño:** Acceso total a finanzas (ingresos totales, gastos acumulados, balance neto), configuración de tarifas y PIN de seguridad.
- **Técnico:** Acceso a operación de campo, checklist de viviendas y evidencias fotográficas.
- **PIN de Seguridad:** Validación requerida para reapertura de semanas cerradas, reseteo de datos o cambios sensibles.

---

## 7. 🎨 Identidad Visual Corporativa ("ELECTRO - GAS")
- **Paleta de Color Primario:** Azul corporativo `#0500D0` (`Color(0xFF0500D0)`), configurado globalmente en `ThemeData` (`primaryColor`, `colorScheme`, `appBarTheme`).
- **Assets de Logo:** Registrados en `pubspec.yaml` (`assets/images/logo.png` y `lib/img/logo.jpeg`).
- **Íconos de Lanzador:** Generados automáticamente mediante `flutter_launcher_icons` para Android, iOS, Web y Windows.
- **Branding en UI:**
  - `LoginScreen`: Logo destacado centrado (220 px) con borde suave y sombra leve.
  - `HomeDashboardScreen`: Logo en `AppBar` y encabezado institucional en el `Drawer` lateral con rol y correo del usuario.
  - `PdfService`: Membrete institucional con logotipo en comprobantes de ayudantes y técnicos.

---

## 8. 📷 Evidencias Fotográficas y Reportes de Asistencia
- **Visor Lightbox (`FotoLightboxDialog`):**
  - Despliegue en pantalla completa con fondo oscuro y zoom interactivo (0.8x a 4.5x) mediante `InteractiveViewer`.
  - Navegación táctil y por flechas entre múltiples fotos de la vivienda.
  - Botón de descarga directa multiplataforma (`download_helper.dart`).
- **Planilla de Asistencia en Excel (`ExcelService.exportarPlanillaAsistenciaAExcel`):**
  - Generación de hojas `.xlsx` con encabezado institucional estilizado en azul corporativo `#0500D0`.
  - Tabla consolidada con ayudantes, conteo de días asistidos, fechas exactas (`[✓ Lun 02/Oct]`, etc.), tarifa, devengados, vales descontados y neto a pagar, con fila de totales generales.
  - Descarga directa en navegador Web y guardado/compartición nativa en dispositivos móviles.

---

## 9. 🚀 Preparación para Producción y Limpieza de Base de Datos
- **Entorno Limpio y Sin Atajos:**
  - Se eliminaron por completo todos los accesos rápidos de prueba ("Entrar Dueño", "Entrar Admin") y las credenciales simuladas en `LoginScreen`.
  - El sistema exige autenticación real y directa contra **Firebase Authentication** bajo el modelo de roles RBAC (`dueño` / `admin`).
- **Mecanismo de Reset Total de Datos (`FirestoreService.limpiarTodosLosDatos`):**
  - Permite vaciar por lotes (`WriteBatch`, chunks de 450 docs) las colecciones operativas: `viviendas`, `lotes`, `etapas`, `asistencias`, `trabajadores`, `gastos`, `semanas` y `prestamos`.
  - Protegido en la interfaz (`ConfiguracionScreen`) dentro de la "Zona de Mantenimiento de Producción" accesible exclusivamente por el Dueño y sujeta a confirmación estricta con el PIN de seguridad de 4 dígitos.
  - La aplicación se encuentra en estado inicial lista para el registro de lotes de obra y personal real.

---

## 10. 📦 Distribución y Despliegue en Producción
- **Plataforma Web (Firebase Hosting):**
  - URL de Producción: [https://control-gas-natural.web.app](https://control-gas-natural.web.app)
  - URL Alternativa: [https://control-gas-natural.firebaseapp.com](https://control-gas-natural.firebaseapp.com)
  - Configuración: `firebase.json` con `rewrites` para Single Page Application (SPA).
- **Plataforma Android (Instalador APK):**
  - Ubicación del Binario: `build/app/outputs/flutter-apk/app-release.apk`
  - Tamaño: 62.8 MB
  - Arquitectura: Universal (todas las arquitecturas ARMv7, ARM64, x86_64 soportadas en un solo paquete).
  - Ícono Corporativo: "ELECTRO - GAS" adaptativo generado en todas las densidades de pantalla.


