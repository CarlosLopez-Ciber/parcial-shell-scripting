# Automatización y Administración de Servidores en Shell Scripting

Solución integral desarrollada en Bash para optimizar tareas críticas de administración en servidores Linux (monitoreo de recursos, gestión de archivos y permisos, análisis de métricas con `awk` y `sed`, y automatización programada en `cron`).

## 1. Estructura del Proyecto

El código está organizado bajo una arquitectura modular y desacoplada:

```text
Ejecución/
├── bin/                              # Scripts ejecutables principales ordenados secuencialmente
│   ├── 01.sistema.sh                 # Módulo 1: Monitoreo integral (SO, Raíz, RAM, CPU)
│   ├── 02.gestor.sh                  # Módulo 2: Menú interactivo de archivos y permisos
│   ├── 03.analisis.sh                # Módulo 3: Análisis de disco con Awk y Sed
│   └── 04.automatizacion.sh          # Módulo 4: Asistente interactivo de Crontab
├── lib/                              # Biblioteca compartida
│   └── utils.sh                      # Colores ANSI, logging, traps y validaciones
├── data/                             # Dataset de métricas de servidores
│   └── servidores.txt                # Archivo de datos con estados y uso de disco
├── reports/                          # Reportes y logs generados automáticamente
│   ├── reporte_sistema.txt           # Reporte exportado por 01.sistema.sh
│   ├── servidores_alertados.txt      # Servidores > 70% filtrados con awk
│   ├── servidores_modificados.txt    # Dataset transformado con sed
│   └── qa_audit_report.txt           # Informe de resultados de la suite de pruebas
└── tests/                            # Control de calidad y pruebas automatizadas
    └── test_suite.sh                 # Suite con 25 pruebas unitarias e integrales
```

---

## 2. Requisitos y Compatibilidad

* **Sistema Operativo:** **Linux Lite 7.4**
* **Intérprete:** Bash
* **Herramientas del Sistema:** `awk`, `sed`, `grep`, `df`, `free`, `crontab`, `find`.
* **Privilegios:** Ejecutable con usuario estándar; con soporte para `sudo`.

---

## 3. Guía de Ejecución Módulo por Módulo

### Módulo 1: Monitoreo del Sistema (`bin/01.sistema.sh`)
Inspecciona parámetros clave del servidor sin volcados redundantes:
- Usuario activo (`whoami`).
- Fecha y hora sincronizada.
- Distribución Linux limpia (`PRETTY_NAME` de `/etc/os-release`).
- Espacio disponible en disco (exclusivamente partición raíz `/`, descartando sistemas de archivos volátiles).
- Memoria RAM en uso y disponible (exclusiva del SO, sin swap).
- Uso de CPU con evaluación frente a umbrales corporativos:
  - **NORMAL:** < 80%
  - **ALERTA:** 80% - 95%
  - **CRÍTICO:** >= 95%

```bash
# Ejecución estándar (muestra en consola y guarda en reports/reporte_sistema.txt)
bash bin/01.sistema.sh

# Modo silencioso (ideal para tareas desatendidas)
bash bin/01.sistema.sh --quiet

# Exportar a una ruta personalizada
bash bin/01.sistema.sh -o /tmp/mi_reporte.txt
```

---

### Módulo 2: Gestión de Archivos y Permisos (`bin/02.gestor.sh`)
Menú interactivo continuo (`while` + `case`) con validaciones preventivas:
1. **Crear archivo o directorio:** Valida colisiones de nombres y crea directorios padre.
2. **Copiar archivo:** Comprueba que el origen exista y solicita confirmación antes de sobrescribir.
3. **Cambiar permisos:** Asigna de forma rápida `644`, `755` o una máscara octal personalizada de 3 dígitos.
4. **Cambiar propietario / grupo (`chown`/`chgrp`):** Permite modificar usuario y grupo con soporte para elevación de privilegios.
5. **Eliminar archivos:** Ofrece eliminación individual con confirmación `[s/N]` y limpieza de archivos temporales por fecha/antigüedad (`find -mtime`).
6. **Salir:** Finaliza la sesión de forma limpia.

```bash
# Iniciar gestor interactivo
bash bin/02.gestor.sh
```

---

### Módulo 3: Análisis de Información con Awk y Sed (`bin/03.analisis.sh`)
Procesa el archivo de métricas de servidores corporativos:
- **`awk`:** Filtra los servidores donde el uso de disco supere el 70%, formatea la tabla alineada, calcula totales y el promedio de ocupación en alerta, guardando el resultado en `reports/servidores_alertados.txt`.
- **`sed`:** Crea una copia respaldada en `reports/servidores_modificados.txt` y normaliza los estados semánticos:
  - `normal` -> `revisado`
  - `critico` -> `alerta`

```bash
# Ejecutar análisis con umbral por defecto (70%)
bash bin/03.analisis.sh

# Ejecutar con umbral personalizado (ej. 80%)
bash bin/03.analisis.sh --threshold 80
```

---

### Módulo 4: Automatización y Asistente de Crontab (`bin/04.automatizacion.sh`)
Asiste al usuario en la administración confiable de `cron`:
- Traduce opciones intuitivas a la sintaxis de 5 campos de crontab.
- Instala la tarea de monitoreo diario de forma idempotente con etiqueta de identificación.
- Permite verificar el estado activo en cualquier momento (`crontab -l`).
- Permite **remover fácilmente** la tarea sin alterar otros trabajos cron preexistentes del usuario.
- Ofrece simulación y ejecución inmediata (`--run-now`) con log fechado y redirección de errores (`>>` y `2>&1`).

```bash
# Modo Asistente Interactivo (Menú guiado)
bash bin/04.automatizacion.sh

# Modo CLI directo:
bash bin/04.automatizacion.sh --run-now                # Ejecutar ahora (Simulación)
bash bin/04.automatizacion.sh --install-daily 08:00    # Programar a las 08:00 AM diario
bash bin/04.automatizacion.sh --status                 # Ver estado en crontab
bash bin/04.automatizacion.sh --remove                 # Desinstalar tarea de crontab
```

---

## 4. Verificación de Calidad y Pruebas Automatizadas

El proyecto incluye una suite integral de 25 pruebas unitarias y de integración que verifican la sintaxis (`bash -n`), control de errores, modularidad y códigos de salida:

```bash
# Ejecutar toda la batería de pruebas
bash tests/test_suite.sh
```

El resultado detallado de la auditoría se almacena en `reports/qa_audit_report.txt`.
