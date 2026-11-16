import XCTest
import PencilKit
@testable import CreativeMoments

final class PlannerCalendarTests: XCTestCase {
    func testEighteenConsecutiveMonths() {
        XCTAssertEqual(PlannerMonth.all.count, 18)
        XCTAssertEqual(PlannerMonth.all.first?.id, "2026-12")
        XCTAssertEqual(PlannerMonth.all.last?.id, "2028-05")
        for pair in zip(PlannerMonth.all, PlannerMonth.all.dropFirst()) {
            XCTAssertEqual(pair.1.year * 12 + pair.1.month - pair.0.year * 12 - pair.0.month, 1)
        }
    }
    func testMondayStartAndLeapDay() {
        XCTAssertEqual(PlannerMonth(year: 2026, month: 12).leadingBlanks, 1)
        XCTAssertEqual(PlannerMonth(year: 2028, month: 2).dayCount, 29)
        XCTAssertEqual(PlannerMonth(year: 2027, month: 2).dayCount, 28)
        XCTAssertEqual(PlannerMonth(year: 2027, month: 2).leadingBlanks, 0)
    }
    func testJSONRoundTrip() throws {
        var doc = PlannerDocument()
        doc.months["2026-12"] = MonthRecord(focus: "Create", days: ["31":"Reflect"], tasks: [PlannerTask(title: "Sketch", completed: true)], notes: "A long note", joy: "Color", carryForward: "Make time")
        let result = try JSONDecoder().decode(PlannerDocument.self, from: JSONEncoder().encode(doc))
        XCTAssertEqual(result.months["2026-12"], doc.months["2026-12"])
    }
}

@MainActor
final class PlannerStorageTests: XCTestCase {
    func testPersistenceAcrossStoreInstances() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let month = PlannerMonth(year: 2026, month: 12)
        let store = PlannerStore(root: root)
        store.update(month) { $0.notes = "Saved note"; $0.tasks = [PlannerTask(title: "A task")] }
        store.setCoverName("My book"); store.flush()
        let reopened = PlannerStore(root: root)
        XCTAssertEqual(reopened.record(month).notes, "Saved note")
        XCTAssertEqual(reopened.record(month).tasks.count, 1)
        XCTAssertEqual(reopened.document.coverName, "My book")
        XCTAssertNil(reopened.errorMessage)
    }
    func testCorruptFileIsNotOverwritten() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("planner.json")
        let bad = Data("not json".utf8); try bad.write(to: file)
        let store = PlannerStore(root: root)
        store.update(PlannerMonth.all[0]) { $0.notes = "Do not overwrite" }; store.flush()
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: file), bad)
    }
    func testDrawingFilesAreIsolatedByMonthAndSection() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlannerStore(root: root)
        store.saveDrawing(PKDrawing(), month: PlannerMonth.all[0], section: .sketch)
        store.saveDrawing(PKDrawing(), month: PlannerMonth.all[1], section: .season)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("2026-12-1.drawing").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("2027-01-0.drawing").path))
    }
}


final class PlannerTaskCompatibilityTests: XCTestCase {
    func testOldTaskWithoutDueDateStillDecodes() throws {
        let id = UUID()
        let json = Data("""
            {"id":"\(id.uuidString)","title":"An old task","completed":false}
            """.utf8)
        let task = try JSONDecoder().decode(PlannerTask.self, from: json)
        XCTAssertEqual(task.id, id)
        XCTAssertNil(task.dueDateKey)
    }

    func testPlannerDayRejectsInvalidDates() {
        XCTAssertNotNil(PlannerDay(key: "2028-02-29"))
        XCTAssertNil(PlannerDay(key: "2027-02-29"))
        XCTAssertNil(PlannerDay(key: "2027-13-01"))
        XCTAssertNil(PlannerDay(key: "2027-01-00"))
    }
}

@MainActor
final class PlannerInteractionTests: XCTestCase {
    func testTodayIncludesOnlyIncompleteTasksDueOnOrBeforeToday() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlannerStore(root: root)
        let december = PlannerMonth(year: 2026, month: 12)
        let january = PlannerMonth(year: 2027, month: 1)
        store.update(december) { $0.tasks = [
            PlannerTask(title: "Overdue", dueDateKey: "2026-12-31"),
            PlannerTask(title: "Undated"),
            PlannerTask(title: "Already done", completed: true, dueDateKey: "2026-12-30")
        ] }
        store.update(january) { $0.tasks = [
            PlannerTask(title: "Due today", dueDateKey: "2027-01-02"),
            PlannerTask(title: "Not yet", dueDateKey: "2027-01-03")
        ] }
        let results = store.openTasks(dueOnOrBefore: PlannerDay(key: "2027-01-02")!.date)
        XCTAssertEqual(Set(results.map(\.task.title)), Set(["Overdue", "Due today"]))
    }

    func testCarryForwardMovesOnlyIncompleteTasksOnce() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlannerStore(root: root)
        let original = PlannerMonth(year: 2026, month: 12)
        let next = PlannerMonth(year: 2027, month: 1)
        let incomplete = PlannerTask(title: "Continue", dueDateKey: "2026-12-20")
        let completed = PlannerTask(title: "Finished", completed: true)
        store.update(original) { $0.tasks = [incomplete, completed] }
        XCTAssertEqual(store.carryForwardUnfinished(into: next), 1)
        XCTAssertEqual(store.carryForwardUnfinished(into: next), 0)
        XCTAssertEqual(store.record(original).tasks.map(\.id), [completed.id])
        XCTAssertEqual(store.record(next).tasks.count, 1)
        XCTAssertEqual(store.record(next).tasks.first?.id, incomplete.id)
        XCTAssertEqual(store.record(next).tasks.first?.dueDateKey, "2027-01-01")
    }

    func testUnsupportedBackupDoesNotReplaceCurrentData() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("CreativeMoments")
        let store = PlannerStore(root: root)
        let month = PlannerMonth(year: 2027, month: 1)
        store.update(month) { $0.notes = "Original content" }
        let backup = try store.exportEditableBackup()
        defer { try? FileManager.default.removeItem(at: backup) }
        var archive = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: backup)) as? [String: Any])
        archive["formatVersion"] = 999
        try JSONSerialization.data(withJSONObject: archive).write(to: backup, options: .atomic)
        XCTAssertThrowsError(try store.restoreEditableBackup(from: backup))
        XCTAssertEqual(store.record(month).notes, "Original content")
        XCTAssertEqual(PlannerStore(root: root).record(month).notes, "Original content")
    }

    func testEditableBackupRestorePreservesDataAndDrawings() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("CreativeMoments")
        let store = PlannerStore(root: root)
        let month = PlannerMonth(year: 2027, month: 1)
        store.update(month) { $0.notes = "Keep this" }
        store.saveDrawing(PKDrawing(), month: month, section: .sketch)
        let backup = try store.exportEditableBackup()
        defer { try? FileManager.default.removeItem(at: backup) }
        store.update(month) { $0.notes = "Replacement" }
        try store.restoreEditableBackup(from: backup)
        XCTAssertEqual(store.record(month).notes, "Keep this")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("2027-01-1.drawing").path))
        XCTAssertNil(store.errorMessage)
    }
    func testBackupRefusesExportWhenNewestPlannerEditsCannotBeSaved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlannerStore(root: root)
        let month = PlannerMonth(year: 2027, month: 1)
        let plannerFile = root.appendingPathComponent("planner.json")
        // A directory at the destination reliably prevents the atomic JSON write.
        try FileManager.default.createDirectory(at: plannerFile, withIntermediateDirectories: true)
        store.update(month) { $0.notes = "Latest edits" }
        XCTAssertThrowsError(try store.exportEditableBackup())
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.record(month).notes, "Latest edits")
        try FileManager.default.removeItem(at: plannerFile)
        let backup = try store.exportEditableBackup()
        defer { try? FileManager.default.removeItem(at: backup) }
        let reopened = PlannerStore(root: root)
        XCTAssertEqual(reopened.record(month).notes, "Latest edits")
    }

    func testRestorePreservesUnflushedEditsInRecoveryCopy() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("CreativeMoments")
        let store = PlannerStore(root: root)
        let month = PlannerMonth(year: 2027, month: 2)
        store.update(month) { $0.notes = "Older backup" }
        let backup = try store.exportEditableBackup()
        defer { try? FileManager.default.removeItem(at: backup) }
        store.update(month) { $0.notes = "Unsaved latest edits" }
        try store.restoreEditableBackup(from: backup)
        XCTAssertEqual(store.record(month).notes, "Older backup")
        let recoveryNames = try FileManager.default.contentsOfDirectory(atPath: parent.path)
            .filter { $0.hasPrefix("CreativeMoments-recovery-") }
        XCTAssertEqual(recoveryNames.count, 1)
        let recoveryURL = parent.appendingPathComponent(recoveryNames[0]).appendingPathComponent("planner.json")
        let recovered = try JSONDecoder().decode(PlannerDocument.self, from: Data(contentsOf: recoveryURL))
        XCTAssertEqual(recovered.months[month.id]?.notes, "Unsaved latest edits")
    }

    func testFailedDrawingWriteDoesNotClaimSuccessfulSave() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlannerStore(root: root)
        let month = PlannerMonth(year: 2027, month: 3)
        let drawingFile = root.appendingPathComponent("2027-03-1.drawing")
        try FileManager.default.createDirectory(at: drawingFile, withIntermediateDirectories: true)
        let originalRevision = store.revision
        store.saveDrawing(PKDrawing(), month: month, section: .sketch)
        XCTAssertEqual(store.revision, originalRevision)
        XCTAssertNotNil(store.errorMessage)
    }

}

@MainActor
final class PlannerNavigationDataTests: XCTestCase {
    func testGalleryFindsLegacyDrawingsWithoutPlannerRecords() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["2026-12-3.drawing", "2028-01-2.drawing", "2028-01-0.drawing"] {
            try PKDrawing().dataRepresentation().write(to: root.appendingPathComponent(name))
        }
        for name in ["2028-13-0.drawing", "0000-01-0.drawing", "2028-01-4.drawing", "2028-1-0.drawing", "2028-01-00.drawing", "export.png", "unrelated.txt"] {
            try Data().write(to: root.appendingPathComponent(name))
        }
        let store = PlannerStore(root: root)
        XCTAssertTrue(store.document.months.isEmpty)
        XCTAssertEqual(store.savedDrawings().map(\.id), ["2028-01-0", "2028-01-2", "2026-12-3"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("unrelated.txt").path))
    }

    func testJournalBindingsSharePlannerRecordsAndPersist() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let month = PlannerMonth(year: 2027, month: 3)
        let store = PlannerStore(root: root)
        store.update(month) { $0.notes = "Existing planner note"; $0.tasks = [PlannerTask(title: "Keep task")] }
        let notes = store.binding(month, \.notes)
        XCTAssertEqual(notes.wrappedValue, "Existing planner note")
        notes.wrappedValue = "Journal edit"
        store.binding(month, \.joy).wrappedValue = "A quiet moment"
        store.binding(month, \.carryForward).wrappedValue = "More sketching"
        store.flush()
        let reopened = PlannerStore(root: root)
        XCTAssertEqual(reopened.record(month).notes, "Journal edit")
        XCTAssertEqual(reopened.record(month).joy, "A quiet moment")
        XCTAssertEqual(reopened.record(month).carryForward, "More sketching")
        XCTAssertEqual(reopened.record(month).tasks.first?.title, "Keep task")
    }

    func testGalleryRefreshesAfterBackupRestore() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: parent) }
        let store = PlannerStore(root: parent.appendingPathComponent("planner"))
        let month = PlannerMonth(year: 2027, month: 3)
        XCTAssertTrue(store.savedDrawings().isEmpty)
        store.saveDrawing(PKDrawing(), month: month, section: .season)
        let backup = try store.exportEditableBackup()
        defer { try? FileManager.default.removeItem(at: backup) }
        store.saveDrawing(PKDrawing(), month: month, section: .free)
        XCTAssertEqual(store.savedDrawings().count, 2)
        try store.restoreEditableBackup(from: backup)
        XCTAssertEqual(store.savedDrawings().map(\.id), ["2027-03-0"])
    }
}
