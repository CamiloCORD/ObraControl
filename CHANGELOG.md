# 📋 CHANGELOG — Control Gas App

Todos los cambios notables, auditorías y correcciones de sincronización en tiempo real están documentados en este archivo.

---

## [1.0.0] - 2026-10-05 — Lanzamiento Oficial a Producción 🚀

### 🌐 Despliegue Web (Firebase Hosting)
- Compilación final optimizada para Web (`flutter build web --release`).
- Configuración de `firebase.json` y `.firebaserc` con enrutamiento SPA y hosting apuntando a `build/web`.
- Despliegue completado a Firebase Hosting en: **https://control-gas-natural.web.app**.

### 📱 Compilación Android (APK Oficial de Producción)
- Compilación de paquete instalable Android (`flutter build apk --release`).
- Binario ejecutable generado exitosamente: `build/app/outputs/flutter-apk/app-release.apk` (62.8 MB).
- Generación y estandarización de iconos corporativos para todas las plataformas (`flutter_launcher_icons`).

---

## [2.4.0] - 2026-10-05

### 🚀 Preparación para Producción & Reset de Datos
- **Eliminación de Accesos Rápidos de Prueba ([login_screen.dart](file:///c:/VSCODE/control_gas_app/lib/screens/login_screen.dart)):**
  - Removidos los botones de bypass "Entrar Dueño", "Entrar Admin" y credenciales simuladas.
  - El formulario de inicio de sesión ahora exige autenticación formal y exclusiva contra Firebase Auth.
  - Eliminados métodos obsoletos de prueba en [auth_provider.dart](file:///c:/VSCODE/control_gas_app/lib/providers/auth_provider.dart) y [auth_service.dart](file:///c:/VSCODE/control_gas_app/lib/services/auth_service.dart).
- **Módulo de Mantenimiento y Reset Total de Firestore ([firestore_service.dart](file:///c:/VSCODE/control_gas_app/lib/services/firestore_service.dart)):**
  - Implementado `limpiarTodosLosDatos()` para purgar en lotes (`WriteBatch`) las colecciones operativas: `lotes`, `viviendas`, `etapas`, `trabajadores`, `asistencias`, `semanas`, `gastos` y `prestamos`.
  - Preserva intactos los registros de autenticación (`usuarios`) y los parámetros base de tarifas (`configuracion`).
- **Control de Seguridad de Producción en UI ([configuracion_screen.dart](file:///c:/VSCODE/control_gas_app/lib/screens/configuracion_screen.dart)):**
  - Añadida tarjeta "Zona de Mantenimiento de Producción" accesible únicamente por el Dueño del proyecto.
  - Confirmación de doble factor mediante modal de advertencia y validación obligatoria del PIN de seguridad de 4 dígitos antes de ejecutar el vaciado.

---

## [2.3.0] - 2026-10-05

### 🎨 Identidad Visual Corporativa "ELECTRO - GAS"
- **Tema y Paleta Institucional:** Configurado el azul corporativo `#0500D0` como `primaryColor`, `colorScheme.primary` y `appBarTheme` global en [main.dart](file:///c:/VSCODE/control_gas_app/lib/main.dart).
- **Gestión de Assets de Logo:** Registrados los assets corporativos en `pubspec.yaml` (`assets/images/logo.png` y `lib/img/logo.jpeg`).
- **Íconos de Aplicación (Launcher Icons):** Configurado y ejecutado `flutter_launcher_icons` generando los íconos oficiales para Android, iOS, Web y Windows.
- **Rediseño de Login ([login_screen.dart](file:///c:/VSCODE/control_gas_app/lib/screens/login_screen.dart)):** Encabezado con tarjeta de logo destacado (ancho 220 px), borde suave, sombra sutil y tipografía corporativa.
- **Branding en Interfaz y Documentos:**
  - `AppBar` con logotipo compacto e indicador de rol en [home_dashboard_screen.dart](file:///c:/VSCODE/control_gas_app/lib/screens/home_dashboard_screen.dart).
  - Nuevo `Drawer` lateral institucional con membrete, logotipo, datos de sesión activa y navegación rápida.
  - Membrete con logo de "ELECTRO - GAS" en encabezados de comprobantes PDF generados en [pdf_service.dart](file:///c:/VSCODE/control_gas_app/lib/services/pdf_service.dart).

### 📷 Visor y Descarga de Fotos de Evidencias (Lightbox)
- **Lightbox Interactivo ([foto_lightbox_dialog.dart](file:///c:/VSCODE/control_gas_app/lib/widgets/foto_lightbox_dialog.dart)):**
  - Despliegue en pantalla completa con zoom interactivo (pinch-to-zoom de 0.8x a 4.5x) y deslizamiento horizontal entre fotos con `PageView` e `InteractiveViewer`.
  - Contador de evidencias e indicador de casa.
- **Descarga Directa Multiplataforma ([download_helper.dart](file:///c:/VSCODE/control_gas_app/lib/utils/download_helper.dart)):**
  - En Web: Descarga directa al navegador mediante `Blob` y `AnchorElement`.
  - En Móvil: Guardado local en almacenamiento y compartición nativa con confirmación mediante `SnackBar`.
  - Integrado tanto en las miniaturas de edición de vivienda como desde el acceso rápido en la tarjeta de la grilla en [lote_detail_screen.dart](file:///c:/VSCODE/control_gas_app/lib/screens/lote_detail_screen.dart).

### 📊 Detalle de Asistencia de Ayudantes y Exportación a Excel
- **Desglose de Fechas Trabajadas en Nómina ([nomina_screen.dart](file:///c:/VSCODE/control_gas_app/lib/screens/nomina_screen.dart)):**
  - Tarjetas de ayudantes con sección expandible (`ExpansionTile`) que lista las fechas exactas con chips de asistencia (`[✓ Lun 02/Oct]`, etc.) consultadas reactivamente desde Firestore.
- **Exportación de Planilla a Excel ([excel_service.dart](file:///c:/VSCODE/control_gas_app/lib/services/excel_service.dart)):**
  - Botón "Descargar Excel de Asistencia" en la pestaña de ayudantes.
  - Generación de libro `.xlsx` estilizado con encabezado institucional en azul `#0500D0`, columnas de ayudante, días asistidos, fechas exactas, tarifa diaria, devengado, vales descontados, saldo neto a pagar y fila de totales consolidados.

---

## [2.2.1] - 2026-10-05

### 🐛 Corrección de Aserción `DropdownButton's value` en Viviendas con Técnico Eliminado
- **Validación Segura de Valor Nulo en Dropdown:**
  - En [lote_detail_screen.dart](file:///c:/VSCODE/control_gas_app/lib/screens/lote_detail_screen.dart), antes de construir el `DropdownButtonFormField`, se valida si `vivienda.tecnicoId` pertenece a la lista de técnicos activos disponibles (`tecnicosDisponibles`).
  - Si el técnico existe y está activo, se asigna su ID como `value`.
  - Si el técnico fue eliminado o está inactivo, se asigna estrictamente `value: null`. Esto previene de raíz la aserción interna de Flutter `"There should be exactly one item with [DropdownButton]'s value"`.
- **Eliminación de Items Duplicados al Reasignar:**
  - Se eliminó la inyección condicional de ítems dinámicos con el ID del técnico seleccionado que causaba colisiones de valores duplicados al intentar elegir otro técnico.
- **Indicador Visual Amigable:**
  - Cuando el técnico anterior no está disponible o fue eliminado, el desplegable muestra el texto `"Técnico eliminado / No disponible - Seleccione uno nuevo"` junto a un banner de advertencia en color ámbar informando al usuario el nombre del técnico anterior.
- **Reasignación y Persistencia Fluida:**
  - Permite a los usuarios seleccionar un nuevo técnico activo y guardar la vivienda en Firestore con total normalidad sin romper la interfaz.

---

## [2.2.0] - 2026-10-05

### 🐛 Corrección de Excepciones y Manejo de Técnicos Eliminados
- **Corrección de `Assertion failed` al abrir viviendas con técnicos eliminados:**
  - En `LoteDetailScreen`, se reemplazó la búsqueda directa por una búsqueda segura (`firstOrNull`) en la lista de trabajadores.
  - Si una vivienda posee un `tecnicoId` de un trabajador que fue eliminado o está inactivo, el `DropdownButtonFormField` genera un `DropdownMenuItem` seguro para ese identificador, mostrando la etiqueta `"Técnico no disponible / Eliminado"` (o `"(Inactivo)"`). Esto evita la falla de aserción interna de Flutter (`items.where((item) => item.value == value).length == 1`).
  - La tarjeta visual de la vivienda en la grilla (`_buildCasaCard`) muestra claramente si el técnico fue eliminado en color de advertencia (`Técnico no disponible / Eliminado`).
  - **Trazabilidad histórica:** Se preserva el `tecnicoId` en el documento de la vivienda en Firestore al eliminar un trabajador para no alterar el historial de auditoría ni el registro de obras.

### 📊 Corrección de Viviendas Terminadas en Comprobantes PDF
- **Reparación de casas completadas en `PdfService`:**
  - Se garantiza el paso explícito de la lista filtrada de viviendas (`viviendasCompletadas`) correspondientes al técnico y a la semana activa.
  - Validación del cálculo exacto: $\text{Total Bruto} = \text{Cantidad de Casas Terminadas} \times \text{Tarifa por Casa}$.
  - Los botones de compartir PDF en la pestaña de Técnicos y en la Planilla consolidada envían ahora el detalle enriquecido de viviendas y vales correspondientes.

### 🎨 Rediseño y Separación de Plantillas PDF
- **Plantilla 1 — Comprobante para Ayudante de Obra:**
  - Encabezado institucional con datos del trabajador (Nombre, Cédula, Rol, Período de Semana).
  - Tabla de Devengados por asistencia: Jornales trabajados $\times$ Tarifa diaria $=$ Total devengado.
  - Tabla de Descuentos / Vales: Desglose numerado con fecha, concepto y valor individual de cada adelanto, con totalizador.
  - Resumen financiero: Total Ganado $-$ Total Vales $-$ Pagos Parciales $=$ **Neto a Pagar**.
  - Sección de firmas formal (Firma Empleado y Autorizado por Administración).
- **Plantilla 2 — Comprobante para Técnico e Instalador:**
  - Encabezado con datos del técnico y período liquidado.
  - Tabla detallada de obras terminadas: Columnas `#`, `Código Casa`, `Lote / Ubicación`, `Fecha Terminación`, `Tarifa Unit.`, `Subtotal`.
  - Fila resumen de **Total Casas Completadas** y **Total Bruto Generado**.
  - Tabla de Descuentos / Vales tomados en la semana.
  - Resumen financiero: Total Casas $-$ Vales Descontados $=$ **Neto a Pagar**.
  - Sección de firmas para recepción conforme y control de obra.

---

## [2.1.0] - 2026-10-05

### 🚨 Correcciones Críticas de Reactividad y Bugs Resueltos
- **Crash `setState() called after dispose()` en `LoteDetailScreen`:**
  - Se agregó verificación `if (bottomSheetCtx.mounted)` en el bloque `finally` de `_abrirModalDetalleCasa` evitando que `setModalState` sea ejecutado después de invocar `Navigator.pop`.
- **Sincronización Automática de Asistencia en Nómina:**
  - Optimizado el método `sincronizarDiasAsistidosAyudante` en `FirestoreService` para que, en caso de que un ayudante recién registrado no exista en `semana.registros`, sea insertado de forma automática con la tarifa vigente de la configuración global.
- **Sincronización de Casas Terminadas en Nómina de Técnicos:**
  - En `LoteDetailScreen`, al marcar una casa como `"Terminada"`, se auto-vincula el `semanaId` activo.
  - En `FirestoreService`, se mejoró `sincronizarCasasTerminadasTecnico` para incorporar al técnico en `semana.registros` si no figuraba previamente, y validar tanto `semanaId` como el rango de fechas de la semana activa.
- **Limpieza de Stream Redundante en Pestaña Personal:**
  - Eliminado el `StreamBuilder` anidado redundante en `_construirPestanaPersonal` de `NominaScreen`, optimizando el consumo de streams en Firestore.
- **Corrección de Lints de Dart:**
  - Corregido el lint `unnecessary_underscores` en el separador del checklist de asistencia en `HomeDashboardScreen`.
  - Agregado guard `mounted` al DatePicker de selección de fecha de asistencia.

---

### 🎨 Reestructuración de Vistas en Nómina (`NominaScreen`)
- **Implementación de Interfaz de 4 Pestañas Especializadas:**
  1. **📊 Planilla:** Consolidado general semanal con balance financiero (Total Generado, Vales, Pagado, Pendiente) y desglose por grupos.
  2. **👷 Ayudantes:** Tarjetas exclusivas para personal con rol `"Ayudante"`. Visualización de días trabajados (con controles rápidos `+`/`-`), tarifa diaria, vales descontados y saldo neto. Botones de acción: `+ Registrar Día`, `+ Adelanto`, `Compartir PDF`.
  3. **🔧 Técnicos:** Tarjetas exclusivas para personal con rol `"Técnico"` o `"Dueño con labor de Técnico"`. Contador destacado en gradiente de **Casas Terminadas esta Semana**, tarifa por casa, total generado bruto, vales descontados y total neto a pagar. Botones de acción: `Ver Casas` (con modal deslizable detallando códigos de viviendas terminadas), `+ Adelanto`, `Compartir PDF`.
  4. **👥 Personal:** Catálogo general de trabajadores con edición en línea, switches de activación/desactivación y registro de nuevo personal.

---

### 🧹 Optimización y Arquitectura de Código
- **Validación con `flutter analyze`:** Proyecto verificado con 0 advertencias y 0 errores de compilación (`No issues found!`).
- **Persistencia limpia y desacoplada:** Separación clara entre modelos puros (`/lib/models/`), capa de servicios (`/lib/services/`), proveedores de estado (`/lib/providers/`) y vistas modulares (`/lib/screens/`).

---

## [2.0.0] - Versión Base
- Funcionalidad inicial de control de viviendas, etapas, lotes, gastos y registro básico de nómina semanal.
