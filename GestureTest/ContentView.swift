import SwiftUI

// --- The Final, Correct, and Verified Test Lab (COMPILES) ---

struct ContentView: View {
    // Canvas state is the single source of truth for position and scale
    @State private var translation: CGPoint = .zero
    @State private var scale: CGFloat = 1.0
    
    // State for the mouse's current position, needed for pivot zooming
    @State private var interactionPoint: CGPoint = .zero
    
    // State for the draggable node
    @State private var nodePosition: CGPoint = CGPoint(x: 300, y: 200)

    // State for node interactions
    @State private var nodeColor = Color.orange
    @State private var showingDoubleClickAlert = false
    @State private var showingSpacebarAlert = false
    @State private var selectedNodeID: UUID?
    
    // The node's unique ID
    private let nodeID = UUID()

    var body: some View {
        ZStack {
            // --- LAYER 1: The Static Background & Its Drag/Tap Gestures ---
            // This layer never moves. Its gestures control the content.
            CanvasBackgroundView(translation: $translation)
                .onTapGesture {
                    selectedNodeID = nil
                    nodeColor = .orange // Reset color on deselect
                }

            // --- LAYER 2: The Movable Content ---
            // This ZStack contains everything that pans and zooms.
            ZStack {
                DraggableNodeView(
                    id: nodeID,
                    position: $nodePosition,
                    color: $nodeColor,
                    canvasScale: self.scale,
                    isSelected: self.selectedNodeID == nodeID,
                    onSelect: {
                        self.selectedNodeID = nodeID
                    },
                    onDoubleClick: {
                        self.showingDoubleClickAlert = true
                    }
                )
            }
            .scaleEffect(self.scale, anchor: .topLeading)
            .offset(x: self.translation.x, y: self.translation.y)
            
            // --- LAYER 3: The AppKit Event Overlay ---
            // The "Gatekeeper" for scroll, magnify, and keyboard events.
            GestureCaptureView(
                translation: $translation,
                scale: $scale,
                interactionPoint: $interactionPoint,
                isNodeSelected: self.selectedNodeID != nil,
                onSpacebar: {
                    self.showingSpacebarAlert = true
                }
            )
            
            // --- LAYER 4: DEBUG INFO ---
            VStack {
                Text("Correct Gatekeeper Architecture")
                    .font(.largeTitle).padding().background(Material.thin).cornerRadius(10)
                Spacer()
                VStack(alignment: .leading) {
                    Text(String(format: "Translation: (%.1f, %.1f)", translation.x, translation.y))
                    Text(String(format: "Scale: %.2f", scale))
                    Text(String(format: "Node Position: (%.1f, %.1f)", nodePosition.x, nodePosition.y))
                    Text(selectedNodeID != nil ? "Node: Selected" : "Node: Not Selected")
                }
                .padding().background(Material.regular).cornerRadius(10).padding()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .coordinateSpace(name: "CanvasCoordinateSpace")
        .alert("Node Double Clicked!", isPresented: $showingDoubleClickAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("Spacebar Pressed on Selected Node!", isPresented: $showingSpacebarAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}


// MARK: - SwiftUI Views with Corrected Gestures

struct CanvasBackgroundView: View {
    @Binding var translation: CGPoint
    // This state MUST be inside the view that owns the gesture
    @State private var lastDragTranslation: CGSize? = nil

    var body: some View {
        Color(nsColor: .windowBackgroundColor)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // This is the correct incremental logic for smooth dragging.
                        let deltaX = value.translation.width - (lastDragTranslation?.width ?? 0)
                        let deltaY = value.translation.height - (lastDragTranslation?.height ?? 0)
                        
                        self.translation.x += deltaX
                        self.translation.y += deltaY
                        
                        lastDragTranslation = value.translation
                    }
                    .onEnded { _ in
                        lastDragTranslation = nil
                    }
            )
    }
}

struct DraggableNodeView: View {
    let id: UUID
    @Binding var position: CGPoint
    @Binding var color: Color
    let canvasScale: CGFloat
    let isSelected: Bool
    
    var onSelect: () -> Void
    var onDoubleClick: () -> Void
    
    @State private var lastDragTranslation: CGSize? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(color)
            .frame(width: 150, height: 80)
            .overlay(
                Text(isSelected ? "Selected" : "Drag or Click Me")
                    .foregroundColor(.white)
            )
            .shadow(color: .black.opacity(isSelected ? 0.4 : 0), radius: isSelected ? 8 : 0)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .position(position)
            .gesture(
                TapGesture(count: 2)
                    .onEnded { onDoubleClick() }
            )
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded {
                        onSelect()
                        color = .blue
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        onSelect()
                        let deltaX = value.translation.width - (lastDragTranslation?.width ?? 0)
                        let deltaY = value.translation.height - (lastDragTranslation?.height ?? 0)
                        
                        self.position.x += deltaX / canvasScale
                        self.position.y += deltaY / canvasScale
                        
                        lastDragTranslation = value.translation
                    }
                    .onEnded { _ in lastDragTranslation = nil }
            )
    }
}


// MARK: - AppKit Layer (The Gatekeeper - UNCHANGED from previous attempt)

struct GestureCaptureView: NSViewRepresentable {
    @Binding var translation: CGPoint
    @Binding var scale: CGFloat
    @Binding var interactionPoint: CGPoint
    
    let isNodeSelected: Bool
    var onSpacebar: () -> Void

    func makeNSView(context: Context) -> GestureNSView {
        let view = GestureNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: GestureNSView, context: Context) {
        context.coordinator.isNodeSelected = isNodeSelected
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            translation: $translation,
            scale: $scale,
            interactionPoint: $interactionPoint,
            isNodeSelected: isNodeSelected,
            onSpacebar: onSpacebar
        )
    }

    class Coordinator {
        @Binding var translation: CGPoint
        @Binding var scale: CGFloat
        @Binding var interactionPoint: CGPoint
        var isNodeSelected: Bool
        var onSpacebar: () -> Void
        
        init(translation: Binding<CGPoint>, scale: Binding<CGFloat>, interactionPoint: Binding<CGPoint>, isNodeSelected: Bool, onSpacebar: @escaping () -> Void) {
            _translation = translation
            _scale = scale
            _interactionPoint = interactionPoint
            self.isNodeSelected = isNodeSelected
            self.onSpacebar = onSpacebar
        }
    }
}

class GestureNSView: NSView {
    var coordinator: GestureCaptureView.Coordinator?
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.window?.makeFirstResponder(self)
    }
    
    private var scrollEventMonitor: Any?
    private var magnifyEventMonitor: Any?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        
        if scrollEventMonitor == nil {
            scrollEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self = self, self.isEventInView(event) else { return event }
                self.scrollWheel(with: event)
                return nil
            }
        }
        
        if magnifyEventMonitor == nil {
            magnifyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
                guard let self = self, self.isEventInView(event) else { return event }
                self.magnify(with: event)
                return nil
            }
        }
    }
    
    private func isEventInView(_ event: NSEvent) -> Bool {
        guard let window = self.window else { return false }
        let locationInWindow = event.locationInWindow
        let locationInView = self.convert(locationInWindow, from: nil)
        return self.bounds.contains(locationInView)
    }

    deinit {
        if let monitor = scrollEventMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = magnifyEventMonitor { NSEvent.removeMonitor(monitor) }
    }
    
    override func updateTrackingAreas() {
        if let oldTrackingArea = self.trackingArea {
            self.removeTrackingArea(oldTrackingArea)
        }
        let newTrackingArea = NSTrackingArea(rect: self.bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        self.addTrackingArea(newTrackingArea)
        self.trackingArea = newTrackingArea
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        coordinator?.interactionPoint = self.convert(event.locationInWindow, from: nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Spacebar
            if coordinator?.isNodeSelected == true {
                coordinator?.onSpacebar()
            }
        }
    }
    
    override func magnify(with event: NSEvent) {
        guard let coordinator = coordinator else { return }
        
        let newScale = coordinator.scale * (1.0 + event.magnification)
        let clampedScale = max(0.2, min(newScale, 5.0))
        
        let oldScale = coordinator.scale
        guard oldScale > 0 else { return }
        
        let pivot = coordinator.interactionPoint
        let oldTranslation = coordinator.translation
        let scaleDelta = clampedScale / oldScale
        
        let newTx = pivot.x - (pivot.x - oldTranslation.x) * scaleDelta
        let newTy = pivot.y - (pivot.y - oldTranslation.y) * scaleDelta
        
        coordinator.scale = clampedScale
        coordinator.translation = CGPoint(x: newTx, y: newTy)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let coordinator = coordinator else { return }
        
        if event.modifierFlags.contains(.command) { // ZOOM
            let scrollDelta = event.scrollingDeltaY
            let zoomFactor = 1.0 - (scrollDelta * (event.hasPreciseScrollingDeltas ? 0.05 : 0.1))
            let oldScale = coordinator.scale
            let newScale = oldScale * zoomFactor
            let clampedScale = max(0.2, min(newScale, 5.0))
            let pivot = coordinator.interactionPoint
            let oldTranslation = coordinator.translation
            let delta = clampedScale / oldScale
            let newTx = pivot.x - (pivot.x - oldTranslation.x) * delta
            let newTy = pivot.y - (pivot.y - oldTranslation.y) * delta
            coordinator.scale = clampedScale
            coordinator.translation = CGPoint(x: newTx, y: newTy)
            
        } else { // PANNING
            if event.hasPreciseScrollingDeltas { // Trackpad
                let dx = event.scrollingDeltaX
                let dy = event.scrollingDeltaY
                if abs(dx) > abs(dy) {
                    coordinator.translation.x += dx
                } else {
                    coordinator.translation.y += dy
                }
            } else { // Mouse
                // **THE FINAL FIX: Distinguish between Shift and normal scroll**
                if event.modifierFlags.contains(.shift) {
                    // Horizontal Pan
                    coordinator.translation.x += event.scrollingDeltaX + event.scrollingDeltaY
                } else {
                    // Vertical Pan
                    coordinator.translation.y += event.scrollingDeltaY
                }
            }
        }
    }
}
