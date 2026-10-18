<p align="center">
  <img src="lib/img/logo.jpg" alt="ObraControl Logo" width="120" style="border-radius: 20px;" />
</p>

<h1 align="center">ObraControl</h1>

<p align="center">
  <strong>Plataforma Integral de Gestión Operativa, Control Físico y Liquidación Financiera en Obras Civiles e Instalaciones Técnicas</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Storage%20%7C%20Hosting-FFCA28?logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Plataforma-Android%20%7C%20Web-success" alt="Plataformas" />
  <img src="https://img.shields.io/badge/Proyecto-Grado%20Ingenier%C3%ADa-blueviolet" alt="Proyecto de Grado" />
</p>

---

## 🌐 Enlaces del Proyecto

- 🚀 **Aplicación en Producción (Firebase Hosting):** [https://obracontrol-f5bdf.web.app](https://obracontrol-f5bdf.web.app)
- 📦 **Repositorio en GitHub:** [https://github.com/CamiloCORD/ObraControl](https://github.com/CamiloCORD/ObraControl)
- ☁️ **Proyecto Firebase:** `obracontrol-f5bdf`

---

## 📖 Acerca de ObraControl

**ObraControl** es una solución multiplataforma diseñada para optimizar los procesos de supervisión técnica, conciliación de mano de obra y control de balances financieros en proyectos de ingeniería y construcción. 

El sistema reemplaza las planillas físicas y los cálculos dispersos en hojas de cálculo por una arquitectura centralizada y reactiva con sincronización en tiempo real.

---

## 🚀 Módulos Principales

| Módulo | Descripción y Capacidades |
| :--- | :--- |
| 🏗️ **Control de Unidades y Lotes** | Seguimiento porcentual de avance físico, bitácora fotográfica de evidencias técnicas y asignación de responsables por frente de obra. |
| 👥 **Liquidación de Nómina Semanal** | Liquidación mixta: **Técnicos/Oficiales** (destajo por unidades certificadas) y **Ayudantes** (jornal por días de asistencia). Manejo automático de vales, abonos y préstamos. |
| 📊 **Módulo Financiero (P&L)** | Estado de resultados operacional: cálculo de ingresos reales vs. egresos de nómina y gastos. Margen de rendimiento y balance neto. |
| 💳 **Cartera y Cuentas por Cobrar (CxC)** | Registro de cartera contractual y préstamos a terceros con amortizaciones dinámicas y generador oficial de Cuentas de Cobro en PDF. |
| 📋 **Cuentas por Pagar (CxP) y Gastos** | Pasivos laborales pendientes con personal de obra, pasivos con proveedores y categorización multiselección de egresos operacionales. |
| 📄 **Motor de Reportes Marca Blanca** | Generación en memoria de documentos PDF (comprobantes individuales, consolidados, P&L, cuentas de cobro) con membrete dinámico y exportación a Excel (`.xlsx`). |
| 🎨 **Personalización de Marca** | Configuración institucional del nombre de empresa, logotipo alojado en Firebase Storage y paleta de color primario reactiva en toda la interfaz. |
| 🔐 **Seguridad y Control de Roles (RBAC)** | Perfiles diferenciados para **Dueño de Proyecto** (acceso gerencial total) y **Administrador** (gestión operativa). |

---

## 🛠️ Requisitos Previos para Desarrolladores

Antes de comenzar, asegúrate de contar con las siguientes herramientas instaladas en tu equipo:

1. **[Git](https://git-scm.com/)** (v2.x o superior).
2. **[Flutter SDK](https://docs.flutter.dev/get-started/install)** (versión `>=3.10.0`, canal `stable`).
   - Verifica tu instalación ejecutando:
     ```bash
     flutter doctor
     ```
3. **Navegador Google Chrome** (para pruebas en Web).
4. **Android Studio** o dispositivo físico con depuración USB (si deseas probar en Android).
5. **Editor recomendado:** Visual Studio Code con las extensiones oficiales de *Flutter* y *Dart*.

---

## 💻 Guía Rápida de Instalación y Ejecución

Sigue estos pasos para clonar el proyecto y ponerlo en marcha localmente:

### 1. Clonar el Repositorio
Abre tu terminal en la carpeta donde desees ubicar el proyecto:
```bash
git clone https://github.com/CamiloCORD/ObraControl.git
cd ObraControl
```

### 2. Instalar Dependencias
Descarga todos los paquetes necesarios declarados en `pubspec.yaml`:
```bash
flutter pub get
```

### 3. Verificar Análisis Estático de Código
Confirma que el proyecto no tenga errores de compilación ni advertencias:
```bash
flutter analyze
```

### 4. Ejecutar la Aplicación en Modo Desarrollo

#### Opción A: En Google Chrome (Web)
```bash
flutter run -d chrome
```

#### Opción B: En Emulador o Dispositivo Android
```bash
flutter run
```

---

## ⚡ Acceso Rápido para Pruebas (Quick Login)

Para facilitar la evaluación de la app y las sustentaciones académicas, la pantalla de inicio ([lib/screens/login_screen.dart](lib/screens/login_screen.dart)) cuenta con botones de **Acceso Rápido** bajo autenticación real:

- **Botón Dueño / Admin:** Autentica con credenciales administrativas para acceder a todas las métricas de rentabilidad y mantenimiento.
- **Botón Técnico:** Acceso con rol operativo.

> 💡 *Nota:* Puedes configurar tus propias credenciales de prueba predeterminadas editando las constantes `_demoAdminEmail` y `_demoAdminPassword` en `lib/screens/login_screen.dart`.

---

## 🌿 Flujo de Trabajo Colaborativo (Git Workflow)

Para mantener la estabilidad de la rama principal (`main`), el equipo debe seguir las siguientes buenas prácticas:

1. **Actualizar siempre la rama principal antes de trabajar:**
   ```bash
   git checkout main
   git pull origin main
   ```

2. **Crear una rama para tu funcionalidad o mejora:**
   Utiliza nombres descriptivos con prefijo:
   ```bash
   # Para una nueva función:
   git checkout -b feature/nombre-de-la-mejora

   # Para corregir un error:
   git checkout -b fix/descripcion-del-bug
   ```

3. **Realizar commits atómicos y claros:**
   ```bash
   git add .
   git commit -m "feat(nomina): agregar cálculo automático de horas extras"
   ```

4. **Subir tu rama a GitHub:**
   ```bash
   git push -u origin feature/nombre-de-la-mejora
   ```

5. **Abrir un Pull Request (PR) en GitHub:**
   - Ingresa a [https://github.com/CamiloCORD/ObraControl/pulls](https://github.com/CamiloCORD/ObraControl/pulls).
   - Abre el Pull Request hacia `main` describiendo los cambios para que otro compañero los revise.

---

## 📂 Estructura del Código Fuente

```text
ObraControl/
├── android/            # Configuración nativa Android (Package: com.tuempresa.obracontrol)
├── web/                # Configuración Web (PWA, index.html, manifest.json)
├── assets/images/      # Íconos y logotipos generados para launcher
├── lib/
│   ├── models/         # Modelos de datos (Configuracion, Lote, Vivienda, Semana, Gasto, Ingreso, etc.)
│   ├── providers/      # Gestión de estado (AuthProvider, ProyectoProvider con Streams atados a Auth)
│   ├── screens/        # Pantallas (Dashboard, Nómina, Contabilidad, Gastos, Viviendas, Login, Config)
│   ├── services/       # Integración Cloud (FirestoreService, AuthService, StorageService, PdfService, ExcelService)
│   ├── utils/          # Helpers multiplataforma (descargas Web/Móvil, formateadores)
│   ├── widgets/        # Componentes UI reutilizables (CustomCards, PhotoLightbox, Modales)
│   ├── firebase_options.dart # Configuración oficial multiplataforma generada por FlutterFire
│   └── main.dart       # Punto de entrada de la aplicación y tema reactivo
├── firestore.rules     # Reglas de seguridad RBAC de Cloud Firestore
├── storage.rules       # Reglas de seguridad de Firebase Storage
├── firebase.json       # Configuración de Hosting y despliegue Firebase
├── APP_CONTEXT.md      # Documento técnico exhaustivo de arquitectura y contexto
└── CHANGELOG.md        # Historial de versiones y auditorías de código
```

---

## 📚 Documentación Técnica Detallada

Para una comprensión profunda de las fórmulas financieras, el esquema de colecciones de Firestore y el historial completo de cambios, consulta:

- 📘 [APP_CONTEXT.md](APP_CONTEXT.md): Guía de arquitectura, seguridad RBAC y fórmulas de liquidación.
- 📋 [CHANGELOG.md](CHANGELOG.md): Registro cronológico de hitos, versiones y refactorizaciones.

---

<p align="center">
  Desarrollado con ❤️ para la gestión de proyectos de ingeniería y construcción civil.
</p>
