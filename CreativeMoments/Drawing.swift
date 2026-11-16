import SwiftUI
import PencilKit

@MainActor
final class DrawingSession: NSObject, ObservableObject, PKCanvasViewDelegate {
    let canvas = PKCanvasView()
    var save: ((PKDrawing) -> Void)?
    private var pending: Task<Void, Never>?
    override init() {
        super.init()
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        canvas.drawingPolicy = .anyInput
        canvas.isScrollEnabled = false
        canvas.delegate = self
    }
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { changed() }
    func changed() {
        pending?.cancel()
        pending = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
            self?.flush()
        }
    }
    func flush() { pending?.cancel(); save?(canvas.drawing) }
}

struct DoodleEditor: View {
    let month: PlannerMonth
    let section: DoodleSection
    @EnvironmentObject var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @StateObject private var session = DrawingSession()
    @State private var color: Color = .purple
    @State private var width = 8.0
    @State private var tool = 0
    @State private var clear = false
    @State private var loaded = false
    @State private var shared: ShareFile?
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Picker("Drawing tool", selection: $tool) {
                        Text("Pen").tag(0); Text("Marker").tag(1); Text("Eraser").tag(2)
                    }.pickerStyle(.segmented)
                    ColorPicker("Ink", selection: $color, supportsOpacity: false).labelsHidden().accessibilityLabel("Ink color")
                }.padding(.horizontal)
                HStack {
                    Text("Size").font(.caption)
                    Slider(value: $width, in: 2...32).accessibilityLabel("Stroke width")
                    Button { session.canvas.undoManager?.undo(); session.changed() } label: { Image(systemName: "arrow.uturn.backward") }.accessibilityLabel("Undo")
                    Button { session.canvas.undoManager?.redo(); session.changed() } label: { Image(systemName: "arrow.uturn.forward") }.accessibilityLabel("Redo")
                }.padding(.horizontal)
                ZoomDrawingView(canvas: session.canvas, background: section == .season ? store.scene(month) : nil)
                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
                    .accessibilityLabel("Drawing canvas. Use a finger or Apple Pencil to draw. Pinch to zoom.")
                Text("Pinch to zoom · Two fingers to move · Automatically saved").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Clear drawing", role: .destructive) { clear = true }
                    Spacer()
                    Button("Share image") {
                        session.flush()
                        do {
                            let file = FileManager.default.temporaryDirectory.appendingPathComponent("CreativeMoments-\(month.id)-\(section.rawValue).png")
                            guard let data = store.artwork(month, section, size: 1600).pngData() else { throw CocoaError(.fileWriteUnknown) }
                            try data.write(to: file, options: .atomic); shared = ShareFile(url: file)
                        } catch { store.errorMessage = "Could not export this drawing. \(error.localizedDescription)" }
                    }
                }.font(.subheadline).padding()
            }.navigationTitle(section.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { session.flush(); dismiss() } }
                .onAppear {
                    if !loaded {
                        session.canvas.drawing = store.drawing(month, section)
                        session.save = { store.saveDrawing($0, month: month, section: section) }
                        loaded = true
                    }
                    updateTool()
                }
                .onDisappear { session.flush() }
                .onChange(of: phase) { _, value in if value != .active { session.flush() } }
                .onChange(of: color) { _, _ in updateTool() }
                .onChange(of: width) { _, _ in updateTool() }
                .onChange(of: tool) { _, _ in updateTool() }
                .confirmationDialog("Clear this drawing? The seasonal illustration will remain.", isPresented: $clear, titleVisibility: .visible) {
                    Button("Clear drawing", role: .destructive) { session.canvas.drawing = PKDrawing(); session.canvas.undoManager?.removeAllActions(); session.flush() }
                    Button("Cancel", role: .cancel) {}
                }
                .sheet(item: $shared) { file in ActivityView(items: [file.url]) }
        }
    }
    private func updateTool() {
        if tool == 2 { session.canvas.tool = PKEraserTool(.vector) }
        else {
            let ink = UIColor(color).withAlphaComponent(tool == 1 ? 0.35 : 1)
            session.canvas.tool = PKInkingTool(tool == 1 ? .marker : .pen, color: ink, width: CGFloat(width))
        }
    }
}

// Every canvas uses 1000x1000 drawing coordinates. The outer scroll view zooms
// the artwork and ink together; saved strokes do not move on device rotation.
struct ZoomDrawingView: UIViewRepresentable {
    let canvas: PKCanvasView
    let background: UIImage?
    func makeUIView(context: Context) -> DrawingScrollView { DrawingScrollView(canvas: canvas, image: background) }
    func updateUIView(_ view: DrawingScrollView, context: Context) {}
}
final class DrawingScrollView: UIScrollView, UIScrollViewDelegate {
    private let surface = UIView(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
    private var previousSize = CGSize.zero
    init(canvas: PKCanvasView, image: UIImage?) {
        super.init(frame: .zero)
        backgroundColor = .systemGray6
        delegate = self
        bouncesZoom = true
        panGestureRecognizer.minimumNumberOfTouches = 2
        surface.backgroundColor = .white
        let picture = UIImageView(frame: surface.bounds)
        picture.image = image; picture.contentMode = .scaleAspectFit
        surface.addSubview(picture)
        canvas.frame = surface.bounds
        surface.addSubview(canvas)
        addSubview(surface)
        contentSize = surface.bounds.size
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { surface }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if previousSize != bounds.size {
            let fit = min(bounds.width, bounds.height) / 1000
            let relative = previousSize == .zero ? 1 : max(1, zoomScale / max(minimumZoomScale, 0.001))
            maximumZoomScale = fit * 5
            minimumZoomScale = fit
            setZoomScale(min(maximumZoomScale, fit * relative), animated: false)
            previousSize = bounds.size
        }
        contentInset = UIEdgeInsets(top: max(0, (bounds.height - contentSize.height) / 2), left: max(0, (bounds.width - contentSize.width) / 2), bottom: 0, right: 0)
    }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { setNeedsLayout() }
}
