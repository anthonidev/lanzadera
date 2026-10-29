# Lanzadera: fases

Cómo se construye: [`PLAN.md`](PLAN.md). Qué hace: [`../IDEA.md`](../IDEA.md). Lo aprendido en cada fase va a [`HALLAZGOS.md`](HALLAZGOS.md).

Cada fase termina con algo que funciona y se puede probar. No se empieza una fase sin cerrar el "listo cuando" de la anterior.

| # | Fase | Resultado | Estado |
|---|---|---|---|
| 0 | Prueba de concepto | Los riesgos pendientes confirmados o descartados | 🟡 6 de 10 (29-oct); el resto necesita reiniciar Ghostty o aceptar permisos |
| 1 | Base del proyecto | Esqueleto que compila, con pruebas, lint e ícono en la barra | ✅ 29-oct |
| 2 | Archivo de configuración | `proyectos.yaml` se lee, valida y recarga solo, con errores por línea | ✅ 29-oct |
| 3 | Abrir en Ghostty | **MVP usable**: abrir un proyecto desde el menú de la barra | 🟡 código y scripts probados en Ghostty; falta probarlo desde la app con el permiso |
| 4 | Panel lateral | ⌥Espacio, búsqueda, teclado, clic | 🟡 hecho; falta probarlo a mano |
| 5 | "Ya abierto" | Llevarme a la ventana, indicador y forzar nueva | 🟡 hecho; falta reiniciar Ghostty para probar la huella |
| 6 | Importar Warp, menú y primer uso | Instalable desde cero siguiendo la bienvenida | 🟡 hecho; falta recorrer la bienvenida |
| 7 | Pulido y cambio definitivo | Warp desinstalado | 🟡 ícono y VoiceOver hechos; falta `make install` y la semana de uso |

> **29-oct:** se construyeron las fases 1 a 6 de corrido (sin esperar los puntos manuales de la fase 0). 57 pruebas, lint limpio. Lo pendiente de cada fase es verificación a mano: ver la lista "Para probar" en `HALLAZGOS.md`.

---

## Fase 0: Prueba de concepto

**Objetivo:** cerrar los riesgos que la PoC del 28-oct no cubrió. App desechable en `PoC/` (no se reutiliza su código, igual que en Baúl y Destello).

Ya hecho (28-oct): ventana nueva, pestañas con nombre, divisiones y carpetas por panel desde AppleScript, replicando Nexus (3 pestañas, 6 paneles).

- [ ] **Desde una app firmada:** ejecutar el script de Nexus con `NSAppleScript` desde una app con Hardened Runtime y el permiso de Automatización. Anotar el texto de la alerta, que el permiso se mantiene al recompilar y **cuánto tarda** (bloquea el hilo principal).
- [ ] **Estado del permiso:** `AEDeterminePermissionToAutomateTarget` sin preguntar: valores antes de conceder, concedido y denegado.
- [ ] **Ghostty cerrado:** abrir Nexus con Ghostty cerrado, con y sin ventanas para restaurar (`window-save-state = always`). ¿Queda una ventana de más? ¿Hay que esperar a que Ghostty termine de arrancar?
- [ ] **Reinicio de Ghostty:** abrir Nexus, salir de Ghostty y volver a abrirlo. ¿Se conservan el `id` de la ventana y el `name override` de las pestañas? ¿Y la carpeta de cada terminal?
- [ ] **Paneles iguales:** `perform action "equalize_splits"` con 3 paneles. Si no existe, probar dividir siempre el panel más grande.
- [ ] **Dirección de Warp:** abrir Smart en Warp (sigue instalado) y confirmar que `split_direction: horizontal` = paneles de lado a lado.
- [ ] **Llevarme a la ventana:** `activate window` + `select tab` con la ventana en otro escritorio (Space), minimizada y en pantalla completa. ¿Ghostty pasa al frente?
- [ ] **Consulta rápida:** tiempo de pedir `id` + nombres de pestaña + carpetas de todas las ventanas con 5 ventanas abiertas.
- [ ] **Vigilar el archivo:** editar y guardar `proyectos.yaml` en Zed (guardado atómico) y con el archivo como enlace simbólico a `zed-config`. Debe llegar un aviso por cada guardado.
- [ ] **Atajo:** ⌥Espacio con KeyboardShortcuts con Raycast, Zed y Ghostty abiertos; que ninguno reaccione además de Lanzadera.

**Listo cuando:** los 10 puntos tienen resultado en `HALLAZGOS.md` y quedan decididos: la huella de "ya abierto" (nombres o carpetas) y qué hacer con Ghostty cerrado.

## Fase 1: Base del proyecto

**Objetivo:** el esqueleto, copiado de la estructura de Baúl.

- [ ] `project.yml` (XcodeGen), `Makefile` (`run`, `test`, `lint`, `install`), `.swiftlint.yml`, `CLAUDE.md` del proyecto.
- [ ] `Packages/LanzaderaKit` con `LanzaderaCore`, `LanzaderaConfig`, `LanzaderaSystem`, `LanzaderaUI` y sus pruebas; dependencias KeyboardShortcuts y Yams.
- [ ] `Info.plist`: `LSUIElement` (sin Dock), `NSAppleEventsUsageDescription`. Entitlement `com.apple.security.automation.apple-events`. Firma con el equipo RS79YL6DLM.
- [ ] `MenuBarExtra` con ícono 🚀 provisional y **Salir**.

**Pruebas:** una prueba trivial por módulo para que `make test` corra todo.

**Listo cuando:** `make run` abre la app en la barra de menú, y `make test` y `make lint` pasan sin advertencias.

## Fase 2: Archivo de configuración

**Objetivo:** el modelo y `proyectos.yaml`, sin tocar Ghostty todavía.

- [ ] Modelo en Core (`Project`, `ProjectWindow`, `ProjectTab`, `Pane`) ya resuelto: `~` expandido, rutas relativas a `root`, pestaña principal.
- [ ] `ConfigLoader`: formato de [`PLAN.md`](PLAN.md#el-archivo-de-configuración) (`panes` número o lista, `tabs` sin `windows`, `emoji`/`color`).
- [ ] Errores de sintaxis con línea y columna; errores de contenido por proyecto (`ProjectValidator`).
- [ ] `ProjectSummary` ("3 pestañas · 6 paneles") y `ProjectFilter` (sin tildes ni mayúsculas).
- [ ] Crear `~/.config/lanzadera/proyectos.yaml` con un ejemplo comentado si no existe.
- [ ] `ConfigFileWatcher` + `ProjectStore`: recarga al guardar y conserva la última versión válida.
- [ ] El menú de la barra lista los proyectos (solo texto) y muestra el error si lo hay.

**Pruebas:** archivo válido completo, `panes` en sus dos formas, rutas con `~` y relativas, YAML roto (línea correcta), dos pestañas principales, proyecto con error junto a uno válido, nombres repetidos, filtro ("nex", "CLINI", "clínic").

**Listo cuando:** escribo mis 4 proyectos a mano en Zed, guardo y el menú se actualiza solo; si rompo el YAML, el menú sigue mostrando la versión anterior y el error con su línea.

## Fase 3: Abrir en Ghostty

**Objetivo:** el **MVP**: elegir un proyecto en el menú de la barra y que Ghostty quede igual que con Warp.

- [ ] `LaunchPlan` y `GhosttyScriptBuilder` (con escapado).
- [ ] `ScriptRunner` (`NSAppleScript`) y `GhosttyController`.
- [ ] Comprobar carpetas antes de abrir: si falta alguna, alerta con la ruta y no se abre nada.
- [ ] Varias ventanas por proyecto; pestaña principal seleccionada y su panel enfocado.
- [ ] Paneles del mismo tamaño (lo decidido en la fase 0).
- [ ] Ghostty cerrado: se abre y se comporta según lo decidido en la fase 0.
- [ ] Permiso denegado: mensaje claro con botón a *Ajustes → Privacidad y seguridad → Automatización*.

**Pruebas:** el script generado para Nexus y para Clinicsay coincide con el texto esperado; escapado de comillas, `\` y emojis; carpeta inexistente no llama al runner; error del runner se informa y no deja estado a medias.

**Listo cuando:** abro los 4 proyectos desde el menú y quedan como en Warp (pestañas, nombres, paneles, carpetas, pestaña principal). Desde aquí ya no hace falta abrir Warp.

## Fase 4: Panel lateral

**Objetivo:** la forma principal de usar la app.

- [ ] `NSPanel` con la receta de Baúl (nivel, `isFloatingPanel` antes del nivel, `canBecomeKey`), pegado al costado derecho de la pantalla del cursor, alto completo del área visible, encima de apps en pantalla completa.
- [ ] Atajo global ⌥Espacio (KeyboardShortcuts) y clic en el ícono de la barra.
- [ ] Lista: emoji o punto de color, nombre, resumen, aviso de carpeta faltante, proyectos con error en gris.
- [ ] Búsqueda escribiendo, ↑ ↓, Enter, clic. Monitor local de teclado (trampa de Baúl) y foco en el campo en **cada** apertura.
- [ ] Cerrar con Esc, el mismo atajo o clic fuera; se cierra solo al abrir un proyecto.
- [ ] Botón **⚙️ Configurar** (abre `proyectos.yaml` en Zed) y banner del error de sintaxis.
- [ ] Animación de entrada desde el costado.

**Pruebas:** modelo del panel sin vistas: filtro + selección (la selección vuelve al primero al filtrar, no se sale de la lista), Enter con lista vacía no hace nada, proyecto con error no se abre.

**Listo cuando:** ⌥Espacio → "sma" → Enter abre Smart sin tocar el mouse, en cualquiera de los dos monitores.

## Fase 5: "Ya abierto"

**Objetivo:** que Lanzadera me lleve a lo que ya está abierto en vez de duplicarlo.

- [ ] `WindowRegistry` persistido; se limpia de ventanas que ya no existen.
- [ ] `WindowFingerprint` como respaldo tras reiniciar Ghostty (según la fase 0).
- [ ] Elegir un proyecto abierto activa sus ventanas y selecciona la pestaña principal.
- [ ] Indicador en el panel (consulta al abrirlo, sin lanzar Ghostty si está cerrado, sin bloquear la lista).
- [ ] ⌥ + Enter / ⌥ + clic fuerza una ventana nueva; el panel muestra la pista al mantener ⌥.

**Pruebas:** con un `GhosttyControlling` falso: `id` registrado vivo → activa; `id` muerto + huella que coincide → adopta y activa; nada → abre; ⌥ → abre aunque exista; huellas parecidas pero en distinto orden no coinciden.

**Listo cuando:** abro Nexus, cambio de app, ⌥Espacio → Nexus me lleva a la misma ventana; cierro la ventana y vuelve a abrirse desde cero; reinicio Ghostty y sigue reconociéndola.

## Fase 6: Importar Warp, menú y primer uso

**Objetivo:** que una instalación limpia quede lista sin ayuda.

- [ ] `WarpConfigReader` + `WarpImporter` con los avisos de [`PLAN.md`](PLAN.md#importar-desde-warp).
- [ ] `ImportReviewView`: proyectos y ventanas con casillas, avisos visibles, botón Importar; copia `.bak`; al terminar ofrece abrir el archivo en Zed.
- [ ] Menú completo: Abrir el panel, Configurar, Importar desde Warp, Iniciar al encender la Mac, Salir.
- [ ] Configuración: atajo (`KeyboardShortcuts.Recorder`), costado del panel (izquierda/derecha), estado del permiso de Automatización.
- [ ] Bienvenida: ícono en la barra → permiso para controlar Ghostty (dispararlo con una consulta inofensiva) → ofrecer importar Warp → "⌥Espacio y elige un proyecto".

**Pruebas:** importar las 4 configuraciones reales (copiadas como fixtures): Nexus avisa de `~/Desktop/data/fotos`, Smart y Chaskybet avisan de la ventana repetida, Clinicsay entra sin avisos; colores → emoji; `horizontal` → `right`; carpeta común → `root`; división anidada se aplana con aviso; nombre ya existente pregunta.

**Listo cuando:** en otra cuenta de usuario de la Mac, se instala, se sigue la bienvenida y los 4 proyectos abren bien.

## Fase 7: Pulido y cambio definitivo

- [ ] Ícono de la app y de la barra de menú.
- [ ] Accesibilidad: etiquetas de VoiceOver en la lista y botones.
- [ ] Rendimiento: el panel aparece al instante aunque Ghostty tarde en responder (consulta en segundo plano con tiempo límite).
- [ ] `make install` a `/Applications/Lanzadera.app`.
- [ ] Guardar `proyectos.yaml` en `zed-config` con enlace simbólico (opcional).
- [ ] **Cambio definitivo:** desinstalar Warp y sus restos (`~/.warp`, guardando antes una copia de las launch configurations).
- [ ] Actualizar `../CLAUDE.md`: Lanzadera pasa a "Proyectos terminados".

**Listo cuando:** una semana de uso diario sin abrir Warp.

---

## Segunda etapa (fuera de este plan)

Todo está soportado por el AppleScript de Ghostty 1.4, así que solo agrega campos a `panes` en el formato:

1. **Comandos al abrir** por panel (`command: npm run dev`), con `initial input` para que la shell siga viva al terminar el proceso. Importar los `commands` de Warp.
2. **Variables de entorno** por panel (`env:`), con `environment variables`.
3. **Cerrar un proyecto** completo desde el panel (`close window` de sus ventanas registradas).
4. **Abrir también en Zed** (`zed: true` o `zed: ~/nexus`).

## Ideas para después

Las de `IDEA.md`, más:

- Agrupar por cliente o categoría; recientes primero.
- Cuadrículas de paneles (2×2, uno arriba y dos abajo) con divisiones anidadas en el formato.
- Abrir un proyecto desde el bot de **Vigilia** (necesita una forma de comunicar las dos apps, la misma que pide Destello → Baúl).
