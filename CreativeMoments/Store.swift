import SwiftUI
import PencilKit

/// The only owner of editable planner state and disk files. SwiftUI views call store
/// methods/bindings; they must not write planner.json or .drawing files directly.
@MainActor
final class PlannerStore: ObservableObject {
    @Published private(set) var document = PlannerDocument()
    @Published private(set) var coverImage: UIImage?
    @Published private(set) var revision = 0
    @Published var errorMessage: String?
    private let root: URL
    private var writable = true
    private var pendingSave: Task<Void, Never>?
    private var drawingCache: [String: PKDrawing] = [:]

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CreativeMoments", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            let file = self.root.appendingPathComponent("planner.json")
            if FileManager.default.fileExists(atPath: file.path) {
                let loaded = try JSONDecoder().decode(PlannerDocument.self, from: Data(contentsOf: file))
                guard loaded.schemaVersion == 1 else { throw CocoaError(.fileReadCorruptFile) }
                document = loaded
            }
            let photo = self.root.appendingPathComponent("cover.jpg")
            if FileManager.default.fileExists(atPath: photo.path) {
                guard let image = UIImage(data: try Data(contentsOf: photo)) else { throw CocoaError(.fileReadCorruptFile) }
                coverImage = image
            }
        } catch {
            writable = false
            errorMessage = "Your saved planner could not be opened. Existing files have been preserved. Close the app and contact support before making changes. \(error.localizedDescription)"
        }
    }
    func record(_ month: PlannerMonth) -> MonthRecord { document.months[month.id] ?? MonthRecord() }
    func binding(_ month: PlannerMonth, _ key: WritableKeyPath<MonthRecord, String>) -> Binding<String> {
        Binding(get: { self.record(month)[keyPath: key] }, set: { value in self.update(month) { $0[keyPath: key] = value } })
    }
    func dayBinding(_ month: PlannerMonth, day: Int) -> Binding<String> {
        Binding(get: { self.record(month).days[String(day)] ?? "" }, set: { value in self.update(month) { $0.days[String(day)] = value } })
    }
    func update(_ month: PlannerMonth, edit: (inout MonthRecord) -> Void) {
        guard writable else { return }
        var record = record(month)
        edit(&record)
        document.months[month.id] = record
        scheduleSave()
    }
    // Task dates are optional so existing undated monthly checklist items still work.
    func addTask(_ title: String, in month: PlannerMonth, dueDate: Date? = nil) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let key = dueDate.map { PlannerDay(date: $0).key }
        update(month) { $0.tasks.append(PlannerTask(title: clean, dueDateKey: key)) }
    }
    func setTaskCompleted(_ id: UUID, in month: PlannerMonth, completed: Bool) {
        update(month) { record in
            if let i = record.tasks.firstIndex(where: { $0.id == id }) { record.tasks[i].completed = completed }
        }
    }
    func setTaskDueDate(_ id: UUID, in month: PlannerMonth, date: Date?) {
        update(month) { record in
            if let i = record.tasks.firstIndex(where: { $0.id == id }) {
                record.tasks[i].dueDateKey = date.map { PlannerDay(date: $0).key }
            }
        }
    }
    /// Query all owning months; tasks may be due in a different month than their checklist.
    func openTasks(dueOnOrBefore date: Date) -> [PlannerTaskItem] {
        let today = PlannerDay(date: date)
        return document.months.flatMap { key, record -> [PlannerTaskItem] in
            let parts = key.split(separator: "-")
            guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]),
                  (1...12).contains(month) else { return [] }
            return record.tasks.compactMap { task in
                guard !task.completed, let key = task.dueDateKey,
                      let due = PlannerDay(key: key), due <= today else { return nil }
                return PlannerTaskItem(month: PlannerMonth(year: year, month: month), task: task)
            }
        }.sorted {
            ($0.task.dueDateKey ?? "") == ($1.task.dueDateKey ?? "")
                ? $0.task.title < $1.task.title
                : ($0.task.dueDateKey ?? "") < ($1.task.dueDateKey ?? "")
        }
    }
    func unfinishedCount(in previous: PlannerMonth) -> Int {
        record(previous).tasks.filter { !$0.completed }.count
    }
    /// Explicit move, not a silent copy. Repeated taps cannot create duplicates.
    @discardableResult
    func carryForwardUnfinished(into month: PlannerMonth) -> Int {
        guard writable else { return 0 }
        let previous = month.previous
        var from = record(previous)
        let tasks = from.tasks.filter { !$0.completed }
        guard !tasks.isEmpty else { return 0 }
        from.tasks.removeAll { !$0.completed }
        var to = record(month)
        let existing = Set(to.tasks.map(\.id))
        let startOfMonth = String(format: "%04d-%02d-01", month.year, month.month)
        let moved = tasks.filter { !existing.contains($0.id) }.map { task -> PlannerTask in
            var result = task
            if let deadline = result.dueDateKey, deadline < startOfMonth {
                result.dueDateKey = startOfMonth
            }
            return result
        }
        to.tasks.append(contentsOf: moved)
        document.months[previous.id] = from
        document.months[month.id] = to
        scheduleSave()
        return moved.count
    }
    func setCoverName(_ name: String) { guard writable else { return }; document.coverName = name; scheduleSave() }
    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            _ = self?.flush()
        }
    }
    /// Returns false if the latest planner edits could not be persisted.
    /// Exports and restores must not proceed after a failed save.
    @discardableResult
    func flush() -> Bool {
        pendingSave?.cancel()
        guard writable else { return false }
        do {
            try JSONEncoder().encode(document).write(to: root.appendingPathComponent("planner.json"), options: .atomic)
            return true
        } catch {
            errorMessage = "Could not save your changes. Please free some storage and try again. \(error.localizedDescription)"
            return false
        }
    }
    func setCover(_ image: UIImage?) {
        guard writable else { return }
        do {
            let url = root.appendingPathComponent("cover.jpg")
            if let image {
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let scale = min(1, 1600 / max(image.size.width, image.size.height))
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                guard let data = resized.jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileWriteUnknown) }
                try data.write(to: url, options: .atomic)
                coverImage = resized
            } else {
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                coverImage = nil
            }
        } catch { errorMessage = "Could not save your cover photo. \(error.localizedDescription)" }
    }
    private func drawingKey(_ month: PlannerMonth, _ section: DoodleSection) -> String { "\(month.id)-\(section.rawValue)" }
    func drawing(_ month: PlannerMonth, _ section: DoodleSection) -> PKDrawing {
        let key = drawingKey(month, section)
        if let cached = drawingCache[key] { return cached }
        let url = root.appendingPathComponent(key + ".drawing")
        guard FileManager.default.fileExists(atPath: url.path) else { return PKDrawing() }
        do {
            let drawing = try PKDrawing(data: Data(contentsOf: url)); drawingCache[key] = drawing; return drawing
        } catch {
            errorMessage = "A drawing could not be opened. Its file has been preserved. \(error.localizedDescription)"
            writable = false
            return PKDrawing()
        }
    }
    func saveDrawing(_ drawing: PKDrawing, month: PlannerMonth, section: DoodleSection) {
        guard writable else { return }
        let key = drawingKey(month, section)
        do {
            try drawing.dataRepresentation().write(to: root.appendingPathComponent(key + ".drawing"), options: .atomic)
            drawingCache[key] = drawing
            revision += 1
        } catch { errorMessage = "Could not save this drawing. \(error.localizedDescription)" }
    }
    private struct EditableBackup: Codable {
        let formatVersion: Int
        let planner: PlannerDocument
        let coverJPEG: Data?
        let drawings: [String: Data]
    }

    /// Includes editable tasks, notes, cover image and every saved PencilKit drawing.
    /// PDF exports are separate, non-editable snapshots.
    func exportEditableBackup() throws -> URL {
        guard writable else { throw CocoaError(.fileReadNoPermission) }
        guard flush() else { throw CocoaError(.fileWriteUnknown) }
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        var drawings: [String: Data] = [:]
        for name in names where name.hasSuffix(".drawing") {
            let data = try Data(contentsOf: root.appendingPathComponent(name))
            _ = try PKDrawing(data: data)
            drawings[name] = data
        }
        let coverURL = root.appendingPathComponent("cover.jpg")
        let cover = FileManager.default.fileExists(atPath: coverURL.path) ? try Data(contentsOf: coverURL) : nil
        let archive = EditableBackup(formatVersion: 1, planner: document, coverJPEG: cover, drawings: drawings)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("CreativeMoments-EditableBackup-\(UUID().uuidString).json")
        try JSONEncoder().encode(archive).write(to: destination, options: .atomic)
        return destination
    }

    /// Stage and verify a complete backup before touching the current planner directory.
    /// The prior directory remains in a sibling recovery folder after a successful restore.
    func restoreEditableBackup(from source: URL) throws {
        guard writable else { throw CocoaError(.fileReadNoPermission) }
        let data = try Data(contentsOf: source)
        let archive = try JSONDecoder().decode(EditableBackup.self, from: data)
        guard archive.formatVersion == 1, archive.planner.schemaVersion == 1 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if let cover = archive.coverJPEG, UIImage(data: cover) == nil {
            throw CocoaError(.fileReadCorruptFile)
        }
        for (name, bytes) in archive.drawings {
            guard name.range(of: #"^\d{4}-\d{2}-[0-3]\.drawing$"#, options: .regularExpression) != nil else {
                throw CocoaError(.fileReadCorruptFile)
            }
            _ = try PKDrawing(data: bytes)
        }
        // Capture unsaved edits in the recovery directory before replacing the planner.
        guard flush() else { throw CocoaError(.fileWriteUnknown) }
        let manager = FileManager.default
        let parent = root.deletingLastPathComponent()
        let staging = parent.appendingPathComponent("CreativeMoments-incoming-\(UUID().uuidString)", isDirectory: true)
        let recovery = parent.appendingPathComponent("CreativeMoments-recovery-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            try JSONEncoder().encode(archive.planner).write(to: staging.appendingPathComponent("planner.json"), options: .atomic)
            if let cover = archive.coverJPEG { try cover.write(to: staging.appendingPathComponent("cover.jpg"), options: .atomic) }
            for (name, bytes) in archive.drawings { try bytes.write(to: staging.appendingPathComponent(name), options: .atomic) }
            pendingSave?.cancel()
            try manager.moveItem(at: root, to: recovery)
            do {
                try manager.moveItem(at: staging, to: root)
            } catch {
                // If replacing the staged directory fails, put the original back.
                try? manager.moveItem(at: recovery, to: root)
                throw error
            }
            document = archive.planner
            coverImage = archive.coverJPEG.flatMap { UIImage(data: $0) }
            drawingCache.removeAll()
            revision += 1
        } catch {
            try? manager.removeItem(at: staging)
            throw error
        }
    }

    /// The gallery discovers existing v1 drawing files, including months with no planner notes.
    func savedDrawings() -> [SavedDrawing] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: root.path).compactMap { name -> SavedDrawing? in
                guard name.hasSuffix(".drawing") else { return nil }
                let stem = String(name.dropLast(".drawing".count))
                let parts = stem.split(separator: "-", omittingEmptySubsequences: false)
                guard parts.count == 3, parts[0].count == 4, parts[1].count == 2,
                      let year = Int(parts[0]), (1...9999).contains(year),
                      let month = Int(parts[1]), (1...12).contains(month),
                      let number = Int(parts[2]), let section = DoodleSection(rawValue: number) else { return nil }
                let drawing = SavedDrawing(month: PlannerMonth(year: year, month: month), section: section)
                guard drawing.id == stem else { return nil }
                return drawing
            }.sorted {
                if $0.month.id != $1.month.id { return $0.month.id > $1.month.id }
                return $0.section.rawValue < $1.section.rawValue
            }
        } catch {
            errorMessage = "Could not find your saved drawings. Your files have not been changed. \(error.localizedDescription)"
            return []
        }
    }

    func scene(_ month: PlannerMonth) -> UIImage? {
        guard let url = Bundle.main.url(forResource: String(format: "scene-%02d", month.month), withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    func artwork(_ month: PlannerMonth, _ section: DoodleSection, size: CGFloat = 600) -> UIImage {
        let d = drawing(month, section)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            if section == .season { scene(month)?.draw(in: CGRect(x: 0, y: 0, width: size, height: size)) }
            d.image(from: CGRect(x: 0, y: 0, width: 1000, height: 1000), scale: size / 1000).draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
    }
}
