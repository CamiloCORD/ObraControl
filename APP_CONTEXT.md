# 📘 APP_CONTEXT — ObraControl

## 1. 🌟 Visión General
- **Nombre de la Aplicación:** **ObraControl**
- **Propósito:** Plataforma multiplataforma de alta fidelidad para la **gestión integral, control físico, trazabilidad operativa y liquidación financiera en proyectos de construcción, obras civiles e instalaciones técnicas**.
- **Entorno Firebase Independiente:** `obracontrol-f5bdf` (Número de Proyecto: `637695930390`)
- **Plataformas Soportadas:** 
  - **Android:** Package / Application ID: `com.tuempresa.obracontrol` (Binario verificado: `build/app/outputs/flutter-apk/app-debug.apk`)
  - **Web:** Single Page Application optimizada (Build verificado: `build/web`)
- **Almacenamiento y Hosting:**
  - Storage Bucket: `obracontrol-f5bdf.firebasestorage.app`
  - Auth Domain: `obracontrol-f5bdf.firebaseapp.com`

**ObraControl** permite administrar frentes de obra (lotes/sectores), el avance constructivo de unidades habitacionales o técnicas, la asistencia diaria del personal operativo, el cálculo automático y pago de nóminas (por destajo y por jornal), la conciliación de egresos y gastos de obra, y la emisión de estados financieros consolidados (P&L, Cuentas por Cobrar con cuentas de cobro formales y Cuentas por Pagar a proveedores y trabajadores).

---

## 2. 🏛️ Arquitectura del Proyecto

El sistema está desarrollado en **Flutter (v3.47.4 / Dart v3.13.3)** siguiendo una arquitectura limpia y reactiva desacoplada en capas:

```text
lib/
├── models/         # Modelos puros con serialización toMap() y fromMap()
│   ├── configuracion_model.dart  # Tarifas dinámicas, ahorro, PIN y datos bancarios oficiales
│   ├── etapa_model.dart          # Fases y estados de ejecución técnica
│   ├── gasto_model.dart          # Egresos operacionales, compras y abonos de nómina
│   ├── ingreso_model.dart        # Recaudos de obra y entradas de capital
│   ├── lote_model.dart           # Frentes de obra, manzanas o sectores constructivos
│   ├── prestamo_tercero_model.dart # Cartera exigible de préstamos a terceros
│   ├── semana_model.dart         # Periodos semanales de liquidación y auditoría
│   ├── trabajador_model.dart     # Personal técnico (instaladores) y ayudantes
│   └── vivienda_model.dart       # Unidades constructivas con código, estado y fotos
├── providers/      # Gestión de estado global reactivo con Provider
│   ├── auth_provider.dart        # Autenticación, control de roles (RBAC: Dueño / Admin)
│   └── proyecto_provider.dart    # Estado centralizado: cálculo de nómina, P&L, CxC, CxP y Streams
├── screens/        # Vistas de usuario (Navegación unificada con barra de 5 destinos)
│   ├── home_dashboard_screen.dart # Métricas clave de avance, asistencia rápida y Drawer
│   ├── viviendas_screen.dart      # Vista consolidada de unidades por frente de obra
│   ├── lote_detail_screen.dart    # Grilla de unidades, visor de fotos y asignación técnica
│   ├── nomina_screen.dart         # Planilla semanal, liquidación de técnicos/ayudantes y personal
│   ├── contabilidad_screen.dart   # Finanzas (4 pestañas: Rendimiento/P&L, CxC, CxP, Gastos)
│   ├── gastos_screen.dart         # Gestión detallada de egresos y multiselección
│   ├── login_screen.dart          # Acceso institucional con panel de inicio rápido para pruebas y demo académica
│   └── configuracion_screen.dart  # Tarifas maestras, datos bancarios y zona de mantenimiento
├── services/       # Integración con infraestructura, servicios en la nube y utilidades
│   ├── auth_service.dart          # Firebase Authentication y roles en Firestore
│   ├── firestore_service.dart     # Operaciones CRUD, Streams reactivos y WriteBatch atómicos
│   ├── storage_service.dart       # Carga de fotos de evidencia técnica y logotipos en Firebase Storage
│   ├── excel_service.dart         # Planillas de asistencia en .xlsx e importación masiva web-safe
│   └── pdf_service.dart           # Motor de reportes marca blanca: nómina, gastos, P&L y cuentas de cobro con logo dinámico y fallback autónomo
├── utils/          # Helpers multiplataforma
│   ├── download_helper.dart       # Abstracción unificada de descargas Web / Móvil
│   ├── download_helper_web.dart   # Descarga vía Blob en Web
│   └── download_helper_io.dart    # Guardado y compartición local en dispositivos móviles
└── widgets/        # Componentes UI reutilizables
    ├── custom_card_widget.dart    # Tarjetas métricas estandarizadas
    ├── foto_lightbox_dialog.dart  # Visor de fotos pantalla completa con zoom interactivo
    └── pin_modal_widget.dart      # Modal de verificación de PIN de seguridad
```

---

## 3. 🔐 Seguridad y Modelo de Roles (RBAC)

La plataforma implementa un esquema de **Control de Acceso Basado en Roles (RBAC)** almacenado en la colección `usuarios/{uid}`:

1. **Dueño de Proyecto (`rol: 'dueno'`):**
   - Acceso irrestricto a todas las métricas de rentabilidad, utilidad neta, ganancia proyectada y P&L.
   - Autorización para modificar el porcentaje del fondo de ahorro y el PIN de seguridad.
   - Acceso exclusivo a la zona de mantenimiento de base de datos y reaperturas de semanas cerradas.
2. **Administrador (`rol: 'admin'`):**
   - Control operativo total: registro de asistencias, liquidación de nóminas, gestión de unidades y lotes.
   - Registro y control de gastos operacionales.
   - Restricción visual de métricas de margen gerencial y ganancia líquida.

### Reglas de Seguridad en Cloud Firestore (`firestore.rules`)
- **Acceso No Autenticado:** Totalmente bloqueado (`request.auth != null`).
- **Colección `usuarios`:** Lectura de perfil propio o por usuarios autorizados; creación protegida.
- **Colecciones Operativas (`lotes`, `viviendas`, `etapas`, `semanas`, `trabajadores`, `asistencias`, `gastos`, `ingresos`, `prestamos`, `prestamos_terceros`):** Acceso condicionado a usuarios con rol activo `dueno` o `admin`.

### Arquitectura de Estado Reactivo y Ciclo de Vida de Streams (`ProyectoProvider`)
- **Vinculación con `FirebaseAuth.authStateChanges()`:** Las suscripciones a Firestore no se ejecutan indiscriminadamente en el constructor, sino que se inician únicamente cuando se confirma un usuario autenticado activo (`request.auth != null`), previniendo cierres prematuros de streams por excepciones de `permission-denied`.
- **Limpieza y Cancelación en Cierre de Sesión:** Al cerrar sesión (`user == null`), todos los streams activos (`_subConfig`, `_subLotes`, `_subViviendas`, `_subGastos`, `_subIngresos`, `_subPrestamosTerceros`, etc.) se cancelan limpiamente y la memoria de estado se purga (`_limpiarEstado()`).
- **Mutaciones Optimistas y Tolerancia a Latencia:** Las operaciones de registro, edición y abono de Cuentas por Cobrar (`prestamos_terceros`) e Ingresos (`ingresos`) actualizan el estado local en memoria en $0\text{ ms}$ y notifican a los listeners inmediatamente mientras Cloud Firestore consolida la persistencia en segundo plano.
- **Mecanismo de Resiliencia y Recarga:** Cada listener de stream incorpora captura `onError` con registro diagnóstico y el método `recargarDatos()` permite forzar la reconexión de streams si se detectan anomalías de conectividad.

### Reglas de Seguridad en Firebase Storage (`storage.rules`)
- Rutas protegidas bajo `viviendas/{viviendaId}/{fileName}` y `configuracion/logo_empresa.{ext}`.
- Restringidas a usuarios autenticados, tamaño máximo de 10 MB y validación estricta de MIME type (`image/*`).

### ⚡ Modo Pruebas y Demostración Académica (Inicio Rápido)
- `LoginScreen` incorpora un panel de **Acceso Rápido** (`mostrarAccesosRapidos = true`) para agilizar evaluaciones en vivo, sustentaciones de grado y pruebas de desarrollo.
- **Autenticación Real (No Mocks):** A diferencia de accesos simulados, los botones ejecutan el flujo real contra Firebase Authentication (`signInWithEmailAndPassword`), garantizando que `request.auth` y el token JWT sean emitidos y validados por las reglas de seguridad de Firestore y Storage, preservando el modelo RBAC sin excepciones de permisos.

---

## 4. 💼 Lógica de Negocio y Liquidación Financiera

### A. Liquidación de Nómina Semanal
- **Técnicos / Oficiales (Destajo):**
  - Devengan con base en unidades certificadas y finalizadas: $\text{Total Devengado} = \text{Unidades Terminadas} \times \text{Tarifa Técnico}$.
  - Tarifa contractual por defecto: `$50.000 COP` por unidad (configurable dinámicamente).
- **Ayudantes (Jornal / Asistencia):**
  - Devengan por días asistidos: $\text{Total Devengado} = \text{Días Asistidos} \times \text{Tarifa Ayudante}$.
  - Tarifa diaria por defecto: `$50.000 COP` por jornada (configurable dinámicamente).
- **Vales y Anticipos:** Se descuentan automáticamente del saldo a pagar y se concilian como abonos en los egresos de la obra.

### B. Módulo Financiero Unificado (`contabilidad_screen.dart`)
1. **Pestaña 1: Rendimiento y P&L:**
   - Estado de resultados operacional: Ingresos acumulados vs. Costos de Mano de Obra y Gastos Operativos.
   - Conciliación de Ganancia Bruta y Margen Operativo.
2. **Pestaña 2: Cuentas por Cobrar (CxC):**
   - Control de cartera contractual con constructoras y contratantes.
   - Cartera de préstamos a terceros con registro de amortizaciones.
   - **Generador de Cuenta de Cobro (PDF):** Documento oficial formal con membrete ObraControl, folio estandarizado, cláusula de pagaré dinámico asociada al titular configurado e instrucciones bancarias completas.
3. **Pestaña 3: Cuentas por Pagar (CxP):**
   - Pasivos corrientes consolidados: saldos adeudados por mano de obra a técnicos y ayudantes, y pasivos con proveedores de materiales.
4. **Pestaña 4: Gastos de Obra (`gastos_screen.dart`):**
   - Categorización de egresos (materiales, fletes, consumibles, viáticos, abonos nómina).
   - Multiselección y generación de Comprobantes de Egreso Consolidado en PDF.

---

## 5. 📄 Generación de Reportes y Documentos Oficiales (Marca Blanca Dinámica)

El motor de reportes (`pdf_service.dart` y `excel_service.dart`) opera bajo un modelo de **marca blanca dinámico y desacoplado**, libre de assets estáticos locales o dependencias propietarias:

- **Desacople Total de Assets Locales:** Eliminada cualquier lectura de archivos empaquetados (`rootBundle.load`, `assets/images/logo.png`, `lib/img/logo.jpeg`). El motor no depende de assets de imagen locales para compilar o generar documentos.
- **Carga Asíncrona de Logotipos (`_cargarLogoEmpresa`):** Descarga dinámica y en tiempo real de `configuracion.logoUrl` desde Firebase Storage mediante peticiones HTTP.
- **Tolerancia a Fallos y Timeout de Red:** La descarga remota está blindada con un timeout estricto de 5 segundos y bloque `try-catch`, asegurando que problemas de red, desconexión o restricciones de CORS no interrumpan ni bloqueen la generación de los documentos PDF.
- **Fallback Tipográfico y Vectorial Autónomo (`_construirEncabezado`):** En caso de que `logoUrl` sea nulo, vacío o falle la descarga, el encabezado renderiza nativamente un badge vectorial con las iniciales de la empresa (`fallbackInitials`), el nombre dinámico institucional (`configuracion.nombreEmpresa`) y la paleta corporativa seleccionada (`configuracion.colorPrimario`).
- **Cobertura Integral en Todos los Documentos:** Implementado homogéneamente en Comprobantes de Ayudante, Comprobantes de Técnico, Reportes Consolidados Generales, Comprobantes de Gastos Individuales y Consolidados, Estados de Resultados (P&L) y Cuentas de Cobro.
- **Saneamiento Anti-Tofu (`sanitizarTexto`):** Filtrado sistemático de caracteres Unicode y emojis para garantizar renderizado perfecto sin caracteres corruptos en fuentes base PDF.
- **Planillas Excel (`ExcelService`):**
  - Hojas `.xlsx` formateadas dinámicamente con la razón social configurada y plantilla de nómina.
  - Módulo de importación masiva de unidades desde archivos Excel en memoria (`leerViviendasDesdeExcel`), compatible con Web y dispositivos móviles sin dependencias de I/O de disco rígido.

---

## 6. 🚀 Verificación Técnica y Calidad de Código
- **Análisis Estático:** `flutter analyze` ejecutado con **0 errores y 0 advertencias**.
- **Compilación Web:** `flutter build web --release` ejecutado exitosamente.
- **Despliegue Web en Producción (Firebase Hosting):** Publicado exitosamente en [https://obracontrol-f5bdf.web.app](https://obracontrol-f5bdf.web.app) con reglas sincronizadas de Cloud Firestore y Firebase Storage.
- **Compilación Android:** `flutter build apk --debug` ensamblado con éxito bajo el paquete `com.tuempresa.obracontrol`.
- **Desacoplamiento Verificado:** No existen referencias a proyectos, credenciales o dominios externos en los archivos activos de la aplicación.
