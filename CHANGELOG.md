# 📋 CHANGELOG — ObraControl

Todos los cambios notables, hitos de arquitectura, auditorías y correcciones de sincronización están documentados en este archivo.

## [2.2.2] - 2026-10-18 — Despliegue Web en Producción (Firebase Hosting) 🌐🚀

### 🚀 [Deployment] Publicación Web Oficial en Firebase
- **Compilación de Producción:** Generado el bundle optimizado con `flutter build web --release` en `build/web`.
- **Despliegue Multi-Recurso (`firebase deploy`):**
  - Publicada la aplicación en **Firebase Hosting** en la URL oficial: [https://obracontrol-f5bdf.web.app](https://obracontrol-f5bdf.web.app).
  - Sincronizadas y publicadas las reglas actualizadas de **Cloud Firestore** (`firestore.rules`) con validación de existencia de documento de usuario (`userDocExists`) y soporte integral para `prestamos_terceros`.
  - Liberadas las reglas actualizadas de **Firebase Storage** (`storage.rules`) para evidencias técnicas y logotipos dinámicos de configuración.

---

## [2.2.1] - 2026-10-18 — Panel de Acceso Rápido (Quick Login) para Pruebas y Sustentación Demo ⚡🔑

### 🚀 [Feat & DevTools] Inicio Rápido con Autenticación Real en Firebase
- **Autenticación Real Integrada (`_accesoRapido`):**
  - Implementado flujo de autenticación real contra Firebase Auth mediante `auth.iniciarSesion()`, garantizando la emisión legítima de credenciales JWT para satisfacer las reglas de seguridad de Firestore (`request.auth.uid`) y Storage.
- **Interfaz Visual en `LoginScreen`:**
  - Incorporada sección discreta y estilizada titulada *"⚡ Acceso Rápido (Modo Pruebas / Demo)"* con botones para acceso con rol **Dueño / Admin** e inicio preparado para **Técnico**.
  - Control de visibilidad global mediante la constante `LoginScreen.mostrarAccesosRapidos = true` para activación o descarte inmediato.
  - Manejo preventivo de errores: alertas claras en `SnackBar` si las credenciales de demo aún tienen marcadores de posición o si el usuario no existe en Firebase Auth.

---

## [2.2.0] - 2026-10-18 — Arquitectura de Suscripción Reactiva Segura y Sincronización en Tiempo Real de Cuentas por Cobrar ⚡📡

### 🛡️ [Fix & Architecture] Ciclo de Vida de Streams y Reactividad en Cloud Firestore
- **Sincronización de Streams con `FirebaseAuth.authStateChanges()`:**
  - Resuelta la causa raíz de streams caídos/muertos: las suscripciones de Firestore en `ProyectoProvider` ya no se lanzan indiscriminadamente en el constructor antes del login, eliminando las excepciones de `permission-denied` que cerraban permanentemente los listeners al arrancar la app.
  - Al autenticar un usuario activo, se inicializan de forma reactiva y ordenada los streams de todas las colecciones (`configuracion`, `lotes`, `etapas`, `viviendas`, `trabajadores`, `gastos`, `ingresos`, `prestamos_terceros`, `semanas`).
  - Al cerrar sesión, se cancelan limpiamente todas las `StreamSubscription` y se purga el estado en memoria para evitar filtraciones entre sesiones.
- **Reglas de Seguridad para Cuentas por Cobrar (`firestore.rules`):**
  - Añadida la regla de acceso autorizada para la colección `prestamos_terceros` (`match /prestamos_terceros/{document=**}`), resolviendo el bloqueo permanente de seguridad en consultas y mutaciones de cartera.
- **Mutaciones Optimistas y Delegación a Provider (`ContabilidadScreen`):**
  - Centralizadas las operaciones de creación, edición, abonos y eliminación de Cuentas por Cobrar (`PrestamoTerceroModel`) e Ingresos (`IngresoModel`) en `ProyectoProvider`.
  - Implementada actualización optimista inmediata en memoria ($0\text{ ms}$) y llamada a `notifyListeners()`, garantizando que la lista de Cuentas por Cobrar y los saldos de cartera se reflejen de inmediato sin requerir recargar la página.
- **Resiliencia en Stream de Cartera (`FirestoreService`):**
  - `streamPrestamosTerceros()` optimizado: ordenamiento determinista en memoria para prevenir omisión de documentos con formatos de fecha mixtos o falta de índices compuestos.

---

## [2.1.1] - 2026-10-18 — Desacople Total de Assets Estáticos y Motor PDF de Marca Blanca Dinámico 📄🚀

### 🛠️ [Refactor & Fix] Desacople de Assets Locales y Reportes Dinámicos (`PdfService`)
- **Desacople de Dependencias Estáticas Locales:**
  - Eliminado por completo el uso de `rootBundle.load` y cualquier referencia fija a `assets/images/logo.png`, `lib/img/logo.jpeg` o imágenes estáticas previas en la generación de PDFs.
- **Carga Asíncrona Resiliente de Logos (`_cargarLogoEmpresa`):**
  - Implementada descarga dinámica en memoria desde la URL remota (`configuracion.logoUrl`) subida a Firebase Storage.
  - Blindada con timeout preventivo de 5 segundos y captura integral de excepciones para evitar que fallos de red o políticas de CORS interrumpan o bloqueen la exportación de documentos.
- **Encabezado Vectorial y Fallback Tipográfico Autónomo (`_construirEncabezado`):**
  - Implementado banner nativo estilizado que renderiza las iniciales de la empresa (`fallbackInitials`), el nombre dinámico institucional (`configuracion.nombreEmpresa`) y el color de acento (`configuracion.colorPrimario`) en ausencia de logotipo o ante errores de red.
- **Cobertura Homogénea en Todos los Documentos PDF:**
  - Aplicado en `generarComprobanteAyudante`, `generarComprobanteTecnico`, `exportarReporteConsolidadoGeneral`, `generarComprobanteGastoPdf`, `generarComprobanteGastosConsolidadoPdf`, `generarEstadoResultadosPdf` y `generarCuentaCobroPdf`.

---

## [2.1.0] - 2026-10-18 — Personalización de Marca y Apariencia (Marca Blanca) 🎨🏷️

### 🏢 [Feat] Identidad de Empresa y Marca Blanca
- **Modelo de Configuración Dinámico (`ConfiguracionModel`):**
  - Incorporados los campos `nombreEmpresa`, `logoUrl` y `colorPrimario` con valores por defecto seguros y retrocompatibilidad total.
  - Implementado método `copyWith()` y serialización completa en Firestore (`configuracion/general`).
- **Almacenamiento Multiplataforma en Firebase Storage (`StorageService`):**
  - Implementado método `subirLogoEmpresa(Uint8List bytes, String extension)` en la ruta `configuracion/logo_empresa.{ext}` con cabeceras `cacheControl: 'no-cache'`.
  - Habilitada regla de lectura/escritura en `storage.rules` para logos de configuración institucional.
- **Interfaz de Gestión de Marca (`ConfiguracionScreen`):**
  - Tarjeta destacada de **"Identidad de Empresa y Marca"** con selector de nombre, visor en tiempo real de logotipo y cargador multiplataforma de imágenes con `FilePicker`.
  - Paleta de selección rápida de 6 tonos estándar de ingeniería (Azul `#0500D0`, Azul Marino `#0D47A1`, Naranja `#E65100`, Verde `#1B5E20`, Rojo `#B71C1C`, Gris Grafito `#37474F`) más diálogo para código Hexadecimal personalizado.
- **Reactividad Global del Tema (`main.dart`):**
  - `MaterialApp` ahora reacciona en tiempo real a los cambios en `colorPrimario` y `nombreEmpresa` a través de `ProyectoProvider`, generando armónicamente el `ColorScheme.fromSeed` y `AppBarTheme`.
- **Reportes PDF Adaptables (`PdfService`):**
  - Los encabezados, pies de página y membretes oficiales de comprobantes de nómina, egresos, estado de resultados y cuentas de cobro adaptan automáticamente el nombre de la empresa y su color corporativo.
  - Soporte de descarga de logo desde URL remota (`logoUrl`) con fallback tipográfico institucional (`'OC'` o iniciales de la empresa).

---

## [2.0.0] - 2026-10-18 — Migración a Firebase Independiente, Neutralización Total de Marca y Generalización Funcional a ObraControl 🏗️⚡

### 🚀 [Core & Cloud] Migración e independización completa de infraestructura Firebase
- **Nuevo Entorno Firebase Dedicado:**
  - Configurado y vinculado el proyecto independiente **`obracontrol-f5bdf`** (Número de Proyecto: `637695930390`).
  - Sincronizados y actualizados los archivos `.firebaserc`, `firebase.json` y `lib/firebase_options.dart`.
  - Desacoplado definitivamente el Hosting corporativo original y eliminadas todas las credenciales de producción externa.
- **Unificación de Identificador Android:**
  - Actualizado `namespace` y `applicationId` a **`com.tuempresa.obracontrol`** en `android/app/build.gradle.kts`.
  - Reubicada la clase nativa a `android/app/src/main/kotlin/com/tuempresa/obracontrol/MainActivity.kt`.
  - Sincronizado `android/app/google-services.json` con el nuevo proyecto y paquete.
  - Verificada la compilación exitosa en modo debug (`flutter build apk --debug`).
- **Configuración Web Limpia:**
  - Plataforma Web registrada en Firebase con App ID `1:637695930390:web:551ffbbf26b91f242d4537`.
  - Verificada la compilación de producción (`flutter build web --release`).

### 🛡️ [Security] Reglas de Seguridad Estandarizadas (RBAC)
- **`firestore.rules` (Local):**
  - Implementado modelo de control de acceso basado en roles (`admin` y `dueno`) contra la colección `usuarios/{uid}`.
  - Bloqueo total de accesos no autenticados y blindaje de colecciones operativas (`lotes`, `viviendas`, `semanas`, `trabajadores`, `gastos`, `ingresos`, `prestamos`).
- **`storage.rules` (Local):**
  - Protección estricta de evidencias fotográficas en `viviendas/{viviendaId}/{fileName}` con validación de tipo de contenido (`image/*`) y límite de 10 MB.

### 🎨 [Branding & UI] Erradicación de marca corporativa anterior y adopción de ObraControl
- **Identidad Institucional en Pantallas:**
  - `MaterialApp`: Título general actualizado a `"ObraControl"`.
  - `LoginScreen`: Sustituido el logo bitmap por una insignia vectorial de ingeniería (`Icons.engineering_rounded`) con degradado institucional en azul primario y subtítulo *"Gestión Operativa y Financiera de Obras"*.
  - `HomeDashboardScreen`: Actualizados el AppBar, el Drawer y el pie de versión a `"ObraControl v1.0.0 - Plataforma de Control de Obras e Ingeniería"`.
  - `ConfiguracionScreen`: Titular predeterminado de cuentas bancarias actualizado a `"ObraControl Ingeniería S.A.S."`.
- **Motor de Reportes (PDF y Excel):**
  - `PdfService`: Membretes oficiales actualizados a `"ObraControl - Gestión de Obras e Ingeniería"`.
  - Cláusula de pagaré en Cuentas de Cobro adaptada dinámicamente al titular configurado (`DEBO Y PAGARÉ A LA ORDEN DE [TITULAR]`) con fallback a `"OBRACONTROL INGENIERÍA"`.
  - Fallback tipográfico institucional con badge `"OC"` en encabezados PDF.
  - `ExcelService`: Encabezados y textos de compartición actualizados a `"PLANILLA DE ASISTENCIA Y NÓMINA - OBRACONTROL"`.
- **Generalización de Conceptos de Obra:**
  - Sustituidas referencias específicas de gas por conceptos estándar de ingeniería civil e instalaciones técnicas: *"Ejecución de obra / instalación técnica en unidades certificadas"*.

---

## [1.6.0] - 2026-10-13 — Cuentas por Pagar (CxP), Generador de Cuentas de Cobro en PDF con Multiselección e Instrucciones Bancarias 💼🧾

### 🚀 [Feat] Expansión del módulo Financiero a 4 pestañas con Cuentas por Pagar (CxP)
- **TabBar Gerencial Estandarizado ([contabilidad_screen.dart](file:///c:/VSCODE/Proyecto_Grado/ObraControl/lib/screens/contabilidad_screen.dart)):**
  - `[1. Rendimiento y P&L | 2. Cuentas por Cobrar | 3. Cuentas por Pagar | 4. Gastos de Obra]`.
- **Módulo de Cuentas por Pagar (CxP):**
  - Consolidación reactiva de pasivos de mano de obra (técnicos y ayudantes) y compras a crédito con proveedores.
  - Acción rápida de abono directo con persistencia atómica en Firestore.

### 📄 [Feat] Generación de Cuenta de Cobro en PDF con Multiselección
- Multiselección de cartera exigible de frentes de obra y préstamos a terceros.
- Documento formal con folio estandarizado (`CC-YYYYMMDD-HHmm`), tabla detallada de conceptos, valor en letras en español ("PESOS M/CTE") e instrucciones bancarias completas.
- Rigor en liquidación contractual: cálculo de unidades equivalentes pendientes sin distorsión de tarifa unitaria.

---

## [1.5.0] - 2026-10-08 — Importación Masiva desde Excel, Motor de Saneamiento Anti-Tofu y Comprobantes Consolidados 📊📑

### 🚀 [Feat] Importador Masivo de Unidades desde Excel (`ExcelService`)
- Parseo en memoria de archivos `.xlsx` web-safe sin dependencias de sistema de archivos local (`leerViviendasDesdeExcel`).
- Creación atómica de lotes y unidades en Firestore vía `WriteBatch`.

### 🛡️ [Fix] Motor de Saneamiento Anti-Tofu (`sanitizarTexto`)
- Depuración sistemática de emojis y glifos Unicode no soportados en fuentes PDF base, garantizando documentos limpios y profesionales.

---

## [1.0.0] - 2026-09-20 — Arquitectura Base del Sistema de Control de Obras 🏗️

- Modelo relacional Firestore: frentes de obra (`lotes`), unidades habitacionales (`viviendas`), etapas constructivas (`etapas`), semanas de corte (`semanas`), personal (`trabajadores`) y asistencias (`asistencias`).
- Liquidación semanal dual: técnicos a destajo por unidad certificada y ayudantes por jornal de asistencia diaria.
- Visor Lightbox de fotos de avance técnico con zoom interactivo y compresión client-side.
- Control de acceso por roles (`dueno` y `admin`) y zona de configuración de tarifas protegida por PIN.
