import AppKit
import Carbon.HIToolbox
import LanzaderaSystem
import SwiftUI

/// Muestra y oculta el panel lateral y traduce el teclado en acciones.
///
/// Receta de Baúl (ver docs/HALLAZGOS.md de Baúl):
/// - `.nonactivatingPanel` + `canBecomeKey`: recibe teclado sin activar Lanzadera.
/// - `isFloatingPanel` se asigna antes que `level` (si no, el nivel vuelve a `.floating`).
/// - Flechas, Enter y Esc se interceptan con un monitor local, porque el campo de búsqueda se las come.
public final class PanelController {
    public let model: PanelViewModel
    private var panel: FloatingPanel?
    private var monitors: [Any] = []
    private var resignObserver: (any NSObjectProtocol)?
    /// Cambia en cada mostrar/ocultar: una animación de salida vieja no oculta un panel recién abierto.
    private var transitionID = 0

    static let width: CGFloat = 360
    static let margin: CGFloat = 8
    /// Cuánto se desplaza el panel desde el costado al entrar y salir.
    static let slide: CGFloat = 28

    public init(model: PanelViewModel) {
        self.model = model
    }

    /// Visible y no saliendo: durante la animación de salida, el atajo vuelve a abrirlo.
    public var isVisible: Bool { (panel?.isVisible ?? false) && !isHiding }
    private var isHiding = false

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        transitionID += 1
        isHiding = false
        model.prepareForPresentation(mouseLocation: NSEvent.mouseLocation)

        let edge = Preferences.panelEdge
        let target = frameOnScreenWithMouse(edge: edge)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // Entra desde el costado: empieza corrido hacia fuera y transparente.
        panel.setFrame(reduceMotion ? target : offset(target, edge: edge), display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.12 : 0.24
            // Sale rápido y frena suave, como un resorte sin rebote.
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
        // La consulta corre fuera del hilo principal: puede empezar ya, sin trabar la animación.
        Task { [model] in await model.refreshOpenStates() }
    }

    /// - Parameter animated: `false` al abrir un proyecto, para que Ghostty pase al frente sin esperar.
    public func hide(animated: Bool = true) {
        guard let panel, panel.isVisible, !isHiding else {
            if !animated, isHiding { finishHiding() }
            return
        }
        model.isOptionHeld = false
        guard animated else {
            finishHiding()
            return
        }
        isHiding = true
        transitionID += 1
        let id = transitionID
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            if !reduceMotion {
                panel.animator().setFrame(offset(panel.frame, edge: Preferences.panelEdge), display: true)
            }
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.transitionID == id else { return }
                self.finishHiding()
            }
        }
    }

    private func finishHiding() {
        isHiding = false
        panel?.orderOut(nil)
        panel?.alphaValue = 1
    }

    // MARK: - Ventana

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(rootView: PanelView(model: model))
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Los monitores locales corren en el hilo principal.
            let consumed = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return consumed ? nil : event
        } as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                self?.model.isOptionHeld = event.modifierFlags.contains(.option)
            }
            return event
        } as Any)
        // Clic fuera del panel → se cierra.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
        return panel
    }

    /// Pegado al costado elegido de la pantalla donde está el cursor, con el alto del área visible.
    private func frameOnScreenWithMouse(edge: PanelEdge) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return .zero }
        let x = edge == .right ? visible.maxX - Self.width - Self.margin : visible.minX + Self.margin
        return NSRect(x: x, y: visible.minY + Self.margin, width: Self.width, height: visible.height - Self.margin * 2)
    }

    private func offset(_ frame: NSRect, edge: PanelEdge) -> NSRect {
        frame.offsetBy(dx: edge == .right ? Self.slide : -Self.slide, dy: 0)
    }

    // MARK: - Teclado

    /// Devuelve `true` si la tecla se consumió.
    private func handle(_ event: NSEvent) -> Bool {
        guard let panel, event.window === panel, !isHiding else { return false }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = Int(event.keyCode)
        if modifiers.contains(.command) {
            return handleCommand(keyCode, option: modifiers.contains(.option))
        }
        switch keyCode {
        case kVK_Escape:
            // Primero borra la búsqueda; con la búsqueda vacía, cierra.
            if model.query.isEmpty { hide() } else { model.query = "" }
        case kVK_UpArrow: model.moveSelection(by: -1)
        case kVK_DownArrow: model.moveSelection(by: 1)
        case kVK_Home: model.selection = 0
        case kVK_End: model.selection = max(model.items.count - 1, 0)
        case kVK_Return, kVK_ANSI_KeypadEnter: model.openSelected(forceNew: modifiers.contains(.option))
        default: return false
        }
        return true
    }

    /// Atajos con ⌘: ⌘1…⌘9 abren por posición, ⌘, abre Preferencias.
    private func handleCommand(_ keyCode: Int, option: Bool) -> Bool {
        if keyCode == kVK_ANSI_Comma {
            hide(animated: false)
            model.onOpenSettings()
            return true
        }
        guard let digit = Self.digits[keyCode] else { return false }
        model.open(position: digit, forceNew: option)
        return true
    }

    private static let digits = [
        kVK_ANSI_1: 1, kVK_ANSI_2: 2, kVK_ANSI_3: 3, kVK_ANSI_4: 4, kVK_ANSI_5: 5,
        kVK_ANSI_6: 6, kVK_ANSI_7: 7, kVK_ANSI_8: 8, kVK_ANSI_9: 9,
    ]
}

/// Panel sin bordes que flota sobre todo, incluso apps en pantalla completa.
final class FloatingPanel: NSPanel {
    init(rootView: some View) {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true // ⚠️ antes de `level`: reinicia el nivel a .floating
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovable = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .none
        contentView = NSHostingView(rootView: rootView)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
