# Lanzadera: hallazgos

Bitácora de lo que se descubre en cada fase: trampas, mediciones y decisiones que cambiaron. Lo más reciente arriba dentro de cada sección.

## Fase 0: Prueba de concepto

| # | Punto | Resultado | Cómo se comprobó |
|---|---|---|---|
| — | Ventana, pestañas con nombre, divisiones y carpetas desde AppleScript | ✅ Funciona (28-oct) | Nexus replicado: 3 pestañas, 6 paneles, carpetas correctas |
| 1 | Desde una app firmada con `NSAppleScript` | ⏳ App firmada con Hardened Runtime + `com.apple.security.automation.apple-events` (verificado con `codesign`). Falta aceptar la alerta y medir | Necesita tu clic en la alerta |
| 2 | Estado del permiso sin preguntar | 🟡 Implementado con `AEDeterminePermissionToAutomateTarget` (`noErr` / `-1743` / `-1744` / otro = Ghostty cerrado). Falta ver los valores reales | Preferencias muestra el estado |
| 3 | Ghostty cerrado | ⏳ No se pudo probar: Claude trabaja dentro de Ghostty. Hoy `tell application` lo lanza y espera; no se cierra ninguna ventana sobrante | Probar a mano. Si sobra una ventana vacía, mirar la opción `initial-window = false` de Ghostty |
| 4 | Reinicio de Ghostty (`id`, nombres, carpetas) | ⏳ Mismo motivo. La huella por nombres de pestaña ya está implementada y probada con dobles | Probar a mano |
| 5 | Paneles iguales (`equalize_splits`) | ✅ `perform action "equalize_splits"` devuelve `true` con 3 paneles. Solo se usa con más de 2 | osascript (29-oct). Confirmar a ojo |
| 6 | Dirección de Warp (`horizontal`) | 🟡 Se tomó `horizontal` = lado a lado (`right`) | Las 4 configs usan `horizontal` y en Warp se ven lado a lado |
| 7 | Llevarme a la ventana | 🟡 `select tab (tab id …)` + `activate window` + `activate` funciona en el mismo escritorio. Falta otro Space, minimizada y pantalla completa | osascript (29-oct) |
| 8 | Tiempo de la consulta de estado | ✅ ~140 ms con `osascript` (incluye lanzar el proceso); dentro de la app debería ser menos. Tiene `with timeout of 3 seconds` | `time osascript` (29-oct) |
| 9 | Vigilar el archivo | ✅ Llega un aviso con reemplazo atómico (`mv`), escritura al final y copia encima. Falta probar con Zed y con enlace simbólico | `log stream` de la app (29-oct) |
| 10 | ⌥Espacio | ⏳ Registrado con KeyboardShortcuts. Simular la tecla con System Events pide otro permiso: probar a mano | |

## Íconos de proyecto (29-oct-2026)

- Búsqueda por calidad, no por carpeta: un `apple-touch-icon.png` (180 px) en cualquier carpeta del proyecto gana a un `favicon.ico` (16–48 px) en la primera. Si no hay nada, se mira un nivel más abajo con las carpetas de interfaz primero (`front`, `web`, `app`…), sin `node_modules`, `dist`, etc.
- 🐞 **`src/app/favicon.ico` de 25 931 bytes es el triángulo de Vercel** que trae `create-next-app`, no el ícono del proyecto (aparecía en Clinicsay, Smart y Nexus). Se descarta por tamaño.
- `public/logo.png` no se usa: suelen ser logos apaisados con el nombre escrito.
- `NSImage` lee `.ico` (elige la mejor resolución), `.png` y `.svg`. Se dibuja a 128 px fuera del hilo principal; si las 4 esquinas son opacas, el ícono tiene fondo propio y ocupa todo el cuadro, si no va con margen sobre el color del emoji. Se reutiliza mientras no cambie la fecha del archivo.
- Resultado con mis proyectos: Nexus y Smart `public/…/apple-touch-icon.png`, Clinicsay `clinicsay-frontend/public/favicon.svg`, Chaskybet `frontend/public/icons/apple-touch-icon.png` (encontrado un nivel más abajo).

## Auditoría de rendimiento y UI (29-oct-2026)

Medido dentro del proceso con `NSAppleScript` (no con `osascript`, que suma ~60 ms de arrancar el proceso).

| Qué | Antes | Después | Por qué |
|---|---|---|---|
| Compilar un AppleScript | ~45 ms el primero, 2–4 ms los demás | 0 (caché) | `AppleScriptRunner` guarda los compilados y la consulta se compila al arrancar la app |
| Consulta de estado con 1 ventana | ~80 ms | ~41 ms | **Cada Apple Event a Ghostty cuesta ~14 ms.** El bucle pedía cada propiedad por separado; ahora son 3 pedidos en bloque (`id of every tab of every window`…) y sin `count windows` |
| Consulta con 3 ventanas | ~390 ms | ~45 ms | El bucle crecía con cada ventana y pestaña; en bloque no |
| Elegir un proyecto con el panel abierto | consulta + apertura | solo apertura | Se reutiliza la foto tomada al mostrar el panel (vale 5 s; si la ventana ya no existe al activarla, se abre desde cero) |
| Consulta durante la animación de entrada | bloqueaba ~80 ms en plena animación | después de la animación | Se lanza en el `completionHandler` |
| Ghostty al frente al abrir | al final (~0,5 s) | tras crear la ventana (~0,1 s) | `activate` justo después de `new window`: se ve armarse |
| Permiso en cada apertura del panel | `AEDeterminePermissionToAutomateTarget` cada vez | una vez | Se recuerda hasta que un script falle por permiso |

**Lo que no se puede acelerar desde fuera** (trabajo interno de Ghostty): ventana nueva ~95 ms, cada pestaña ~80 ms, cada división ~23 ms, cada `name override` ~23 ms, `equalize_splits` ~0. Nexus completo: ~535 ms.

UI: fondo de vidrio (`glassEffect`), selección que se desliza entre filas (`matchedGeometryEffect`), hover con el mouse (solo si el cursor se mueve: si el panel aparece bajo el cursor, la selección sigue en el primero), filas que entran escalonadas, salida animada (excepto al abrir un proyecto, que es instantánea), ⌘1–⌘9 con su tecla dibujada, Esc borra la búsqueda antes de cerrar, punto verde "Abierto", fondo del ícono teñido con el color del emoji y respeto de "Reducir movimiento".

Revisión del código: se quitó código muerto (`WindowRegistry.prune`, carpetas de la foto que nadie usaba) y la lista filtrada se calcula una vez por cambio en vez de en cada lectura de la vista.

## Construcción (29-oct-2026)

### Probado de punta a punta (sin la app)

- Las 4 configuraciones reales de Warp → importador → `proyectos.yaml` → `ConfigLoader` → `GhosttyScript` → ejecutado en Ghostty: **los 4 proyectos abren con sus pestañas, nombres, paneles, carpetas y pestaña principal**, comprobado leyendo el estado de Ghostty y cerrando luego solo esas ventanas.
- Avisos del importador con los datos reales: Nexus ventana 1 (`~/Desktop/data/fotos` no existe y está fuera de `~/nexus`), Smart ventana 2 (repite Nexus), Chaskybet ventana 2 (repite Smart, aunque tiene un panel menos). Clinicsay sin avisos. Quedan 4 proyectos de una ventana.
- La app arranca, crea `~/.config/lanzadera/proyectos.yaml` con el ejemplo comentado y recarga sola; con YAML roto conserva la versión anterior y muestra "Error en la línea N".

### Decisiones que cambiaron respecto a PLAN.md

- **Sin `LaunchPlan`:** `GhosttyScript.open(_:)` genera el script directo desde `Project`. Una capa menos y el texto esperado igual se prueba.
- **Protocolos en `LanzaderaSystem`**, no en Core (son main actor). Core solo tiene tipos puros; `ScriptValue` traduce el resultado de AppleScript sin AppKit.
- **Pestaña principal:** como mucho una `focus: true` **por ventana**; la ventana principal es la que tiene una marcada (o la primera). En el script cada carpeta distinta es una `surface configuration` (`cfg1`, `cfg2`…) y cada panel se divide del anterior; al final `focus` del primer panel de la pestaña principal + `activate`.
- **Foco de panel de Warp** (`is_focused`) no se importa: queda enfocado el primer panel.
- **En `panes:` como lista**, cada `cwd` es relativo a `root` (no a la pestaña). También se acepta `- carpeta` como atajo de `- cwd: carpeta`.
- **Claves desconocidas** (`tittle`) son error de ese proyecto con su línea: atrapa erratas.
- **Importar no pregunta por nombres repetidos:** el proyecto que ya existe se omite (se muestra "ya está en tu archivo"). Nunca se reemplaza nada; siempre `.bak` antes de escribir.
- **Ventana principal de Warp = `active_window_index`.** Con eso se decide qué ventanas están "fuera" o "repetidas".
- **Emoji del proyecto al importar:** el color de la primera pestaña de la ventana principal. Smart queda 🔴 (la idea decía 🟢): cámbialo en el archivo.
- **Ícono de la barra:** `airplane.departure` (SF Symbols no tiene cohete).
- **Indicador "abierto":** no consulta a Ghostty si el permiso no está concedido, para que la alerta no salga con el panel abierto.
- Los mensajes de error de sintaxis vienen de libyaml en inglés ("did not find expected ','"); la línea sí es correcta.

### Para probar a mano

1. `make run` → Bienvenida → **Dar permiso** (abre Ghostty si hace falta) → aceptar la alerta.
2. **Importar desde Warp…** → revisar avisos → Importar → abrir en Zed y ajustar (por ejemplo, emoji de Smart).
3. ⌥Espacio → "sma" → Enter. Repetir: debe llevarte a la misma ventana (punto verde en la lista). ⌥Enter abre otra.
4. Cerrar Ghostty del todo y abrir un proyecto desde Lanzadera (punto 3 de la fase 0). ¿Sobra una ventana?
5. Abrir Nexus, salir de Ghostty, volver a abrirlo y elegir Nexus: ¿lo reconoce (huella) o abre otro? (punto 4).
6. Guardar `proyectos.yaml` en Zed y ver que el panel cambia; romper el YAML y ver el aviso naranja.
7. Panel en los dos monitores y con una app en pantalla completa.

## Antes de empezar (28-oct-2026)

### Ghostty 1.4.0: diccionario AppleScript

Revisado con `sdef /Applications/Ghostty.app`:

- **Clases:** `application` → `window` → `tab` → `terminal`. Cada una tiene un `id` descrito como "estable". Ejemplo real de `id` de ventana: `tab-group-7c187fbde0` (parece el grupo de pestañas nativo de macOS).
- **Pestaña:** `name` (solo lectura), `name override` (lectura/escritura; vacío lo borra), `index`, `selected`, `focused terminal`. Comandos `select tab`, `close tab`.
- **Terminal:** `working directory`, `pid` del proceso en primer plano, `tty`, `name override`. Comandos `split` (`right`, `left`, `down`, `up`), `focus` (trae su ventana al frente), `close`, `input text`, `send key`.
- **Surface configuration** (`new surface configuration`): `initial working directory`, `command`, `initial input`, `wait after command`, `environment variables`, `font size`. Se pasa a `new window`, `new tab` y `split`.
- **Ventana:** `activate window`, `close window`, `selected tab`.
- `perform action "<acción>" on <terminal>` ejecuta cualquier acción de Ghostty (por ejemplo `equalize_splits`; a confirmar).

### Mi configuración de Ghostty que afecta a Lanzadera

En `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` (no en `~/.config/ghostty/`):

- `window-save-state = always`: Ghostty restaura las ventanas al abrirse → importa para "ya abierto" y para abrir con Ghostty cerrado.
- `macos-titlebar-style = tabs`: pestañas en la barra de título.
- `confirm-close-surface = false`: cerrar un proyecto (etapa 2) no pedirá confirmación.

### Configuraciones de Warp

`~/.warp/launch_configurations/`: `chaskybet.yaml`, `clinicsay.yaml`, `nexus.yaml`, `smart.yaml`.

- Esquema: `name`, `active_window_index`, `windows[].active_tab_index`, `tabs[].title`, `tabs[].color`, `tabs[].layout`. El `layout` es una hoja (`cwd`, `is_focused`, `pane_mode`) o una división (`split_direction` + `panes`). Ninguna de las 4 usa divisiones anidadas ni `commands`.
- Todas las divisiones son `split_direction: horizontal`.
- Colores usados: `red`, `green`, `blue`, `magenta`.
- 🐞 **Ventanas cruzadas:** Smart tiene como 2.ª ventana la de Nexus, y Chaskybet como 2.ª ventana la de Smart. Nexus tiene como 1.ª ventana `~/Desktop/data/fotos`, que **ya no existe**. El resto de las carpetas existen.
- La pestaña de la 1.ª ventana de Nexus no tiene `title`: el importador debe tolerar pestañas sin título (usar el nombre de la carpeta).
- En Clinicsay las 3 pestañas tienen `is_focused: true` (una por pestaña, con un solo panel): el foco que importa es el de `active_tab_index`.

### Otros

- Bundle IDs: Ghostty `com.mitchellh.ghostty`, Zed `dev.zed.Zed`. El comando `zed` está en `/usr/local/bin/zed`.
- Raycast está instalado y usa ⌘Espacio; ⌥Espacio en principio está libre.
- Warp sigue instalado: sirve para comparar en la fase 0 antes de desinstalarlo.
