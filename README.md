# Proyecto de Automatización de Tareas con Bash en Ubuntu Server

## Descripción
Proyecto desarrollado para automatizar tareas básicas de administración de servidores Linux mediante scripts Bash, reduciendo procesos manuales y facilitando el monitoreo, gestión de archivos y generación de reportes.

## Objetivos
- Automatizar tareas administrativas en Ubuntu Server.
- Monitorear recursos básicos del sistema.
- Gestionar archivos y permisos.
- Analizar información utilizando AWK y SED.
- Programar tareas automáticas mediante CRON.

## Módulos del proyecto

### 1. Monitoreo del sistema
Obtención de información del usuario, fecha, sistema operativo, memoria y espacio disponible en disco.

### 2. Gestión de archivos
Creación, copia, modificación de permisos y eliminación controlada de archivos.

### 3. Análisis de información
Procesamiento de datos de servidores mediante AWK y reemplazo de palabras con SED.

### 4. Automatización y reportes
Programación de tareas mediante CRON y generación de reportes en archivos de texto.

## Tecnologías utilizadas
- Ubuntu Server
- GNU Bash
- AWK
- SED
- CRON
- Git
- GitHub
- SSH

## Estructura del proyecto
- `scripts/`: scripts de automatización.
- `reportes/`: reportes generados.
- `analisis/`: inventario y datos de servidores.
- `gestor_de_archivos/`: archivos administrados.
- `temporales/`: archivos temporales de prueba.
- `logs/`: registros de ejecución.

## Ejecución
Ejemplo para ejecutar el monitoreo:

```bash
bash ~/proyecto_bash/scripts/reporte.sh
```

## Entorno
Ubuntu Server – Administración mediante terminal y conexión SSH.
