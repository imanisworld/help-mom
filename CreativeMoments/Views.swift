import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

private let plum = Color(red: 0.32, green: 0.22, blue: 0.34)

struct HomeView: View {
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var showHelp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Creative Moments")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                            .foregroundStyle(plum)
                            .accessibilityAddTraits(.isHeader)
                        Text("Your space to plan, create, and reflect.")
                            .font(.title3).foregroundStyle(.secondary)
                    }.padding(.vertical, 12)
                    LazyVGrid(columns: textSize.isAccessibilitySize
                              ? [GridItem(.flexible())]
                              : [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                        NavigationLink { PlannerView() } label: {
                            HomeCard(title: "My Planner", subtitle: "View and edit plans", symbol: "calendar", color: plum)
                        }
                        NavigationLink { ColorDrawView() } label: {
                            HomeCard(title: "Color & Draw", subtitle: "Make something", symbol: "paintpalette", color: Color(red: 0.28, green: 0.43, blue: 0.35))
                        }
                        NavigationLink { JournalView() } label: {
                            HomeCard(title: "My Journal", subtitle: "Write or reflect", symbol: "book.closed", color: Color(red: 0.48, green: 0.32, blue: 0.23))
                        }
                        NavigationLink { CreationsView() } label: {
                            HomeCard(title: "My Creations", subtitle: "See saved work", symbol: "photo.on.rectangle.angled", color: Color(red: 0.29, green: 0.37, blue: 0.53))
                        }
                    }.buttonStyle(.plain)
                    NavigationLink { BackupView() } label: {
                        Label("Back up your work", systemImage: "externaldrive")
                            .padding(.vertical, 12)
                    }
                    Text("A little space for you, every day.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: 850)
                    .frame(maxWidth: .infinity)
            }.background(Color(red: 0.97, green: 0.95, blue: 0.96))
                .navigationTitle("Home").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Help", systemImage: "questionmark.circle") { showHelp = true } }
                .sheet(isPresented: $showHelp) { AboutView() }
        }
    }
}

private struct HomeCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(color)
                .accessibilityHidden(true)
            Text(title).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(color)
            Text(subtitle).font(.body).foregroundStyle(.secondary)
        }.padding(24).frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(color.opacity(0.16)))
            .contentShape(RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)
    }
}

private struct YearNavigation: View {
    @Binding var year: Int
    var body: some View {
        HStack {
            Button { year -= 1 } label: {
                Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
            }.accessibilityLabel("Previous year").disabled(year <= 1)
            Spacer()
            Text(String(year)).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { year += 1 } label: {
                Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
            }.accessibilityLabel("Next year").disabled(year >= 9999)
        }
    }
}

struct ColorDrawView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var selection: SavedDrawing?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Choose a picture and make it your own.").font(.title3)
                Text("Drawings stay with their month. Tap a picture again to keep drawing.")
                    .foregroundStyle(.secondary)
                YearNavigation(year: $year)
                Text("Start creating this month").font(.headline)
                LazyVGrid(columns: textSize.isAccessibilitySize
                          ? [GridItem(.flexible())]
                          : [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(DoodleSection.allCases) { section in
                        Button {
                            selection = SavedDrawing(month: PlannerMonth.forDate(Date()), section: section)
                        } label: {
                            Text(section.title)
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Text("Or choose a month below to color its seasonal picture.")
                    .font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: textSize.isAccessibilitySize
                          ? [GridItem(.flexible())]
                          : [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                    ForEach(1...12, id: \.self) { number in
                        let month = PlannerMonth(year: year, month: number)
                        Button { selection = SavedDrawing(month: month, section: .season) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                if let picture = store.scene(month) {
                                    Image(uiImage: picture).resizable().scaledToFit().accessibilityHidden(true)
                                }
                                Text(month.theme).font(.headline)
                                Text(month.title).font(.subheadline).foregroundStyle(.secondary)
                            }.padding().frame(maxWidth: .infinity, alignment: .leading)
                                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                            .accessibilityLabel("\(month.theme), \(month.title), open drawing")
                    }
                }
            }.padding().frame(maxWidth: 850).frame(maxWidth: .infinity)
        }.background(Color(.systemGroupedBackground))
            .navigationTitle("Color & Draw")
            .fullScreenCover(item: $selection) { drawing in
                DoodleEditor(month: drawing.month, section: drawing.section)
            }
    }
}

struct JournalView: View {
    @State private var year = Calendar.current.component(.year, from: Date())
    var body: some View {
        List {
            Section {
                Text("A quiet place for your notes and reflections.").font(.title3)
                NavigationLink("Write this month") { JournalMonthView(month: PlannerMonth.forDate(Date())) }
            }
            Section {
                YearNavigation(year: $year).buttonStyle(.borderless)
                ForEach(1...12, id: \.self) { number in
                    let month = PlannerMonth(year: year, month: number)
                    NavigationLink(month.title) { JournalMonthView(month: month) }
                        .padding(.vertical, 8)
                }
            } header: { Text("Browse your journal") }
        }.navigationTitle("My Journal")
    }
}

struct JournalMonthView: View {
    @EnvironmentObject private var store: PlannerStore
    let month: PlannerMonth
    var body: some View {
        Form {
            Section { Text("These are the same notes and reflections you’ll find in My Planner.") }
            Section("Notes & inspiration") {
                TextField("What’s on your mind?", text: store.binding(month, \.notes), axis: .vertical)
                    .lineLimit(6...20)
            }
            Section("Something I enjoyed creating") {
                TextField("A moment worth remembering", text: store.binding(month, \.joy), axis: .vertical)
                    .lineLimit(3...12)
            }
            Section("An idea to carry forward") {
                TextField("What would you like to explore next?", text: store.binding(month, \.carryForward), axis: .vertical)
                    .lineLimit(3...12)
            }
            Section { Text("Your changes save automatically.").foregroundStyle(.secondary) }
        }.navigationTitle(month.title).navigationBarTitleDisplayMode(.inline)
            .onDisappear { store.flush() }
    }
}

struct CreationsView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var drawings: [SavedDrawing] = []
    @State private var selection: SavedDrawing?
    @State private var loaded = false
    var body: some View {
        Group {
            if !loaded {
                ProgressView("Finding your creations…")
            } else if drawings.isEmpty {
                ContentUnavailableView {
                    Label("Your creative space is waiting", systemImage: "paintpalette")
                } description: {
                    Text("Drawings you save appear here, ready to open and keep creating.")
                } actions: {
                    NavigationLink("Choose a picture") { ColorDrawView() }.buttonStyle(.borderedProminent)
                }
            } else {
                List(drawings) { drawing in
                    Button { selection = drawing } label: {
                        HStack(spacing: 16) {
                            CreationThumbnail(drawing: drawing)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(drawing.section.title).font(.headline)
                                Text(drawing.month.title).foregroundStyle(.secondary)
                                Text("Open, edit or share").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 8)
                    }.buttonStyle(.plain)
                }
            }
        }.navigationTitle("My Creations")
            .task(id: store.revision) {
                drawings = store.savedDrawings()
                loaded = true
            }
            .fullScreenCover(item: $selection) { drawing in
                DoodleEditor(month: drawing.month, section: drawing.section)
            }
    }
}

private struct CreationThumbnail: View {
    @EnvironmentObject private var store: PlannerStore
    let drawing: SavedDrawing
    @State private var preview: UIImage?
    var body: some View {
        Group {
            if let preview { Image(uiImage: preview).resizable().scaledToFit() }
            else { Image(systemName: "paintpalette").font(.largeTitle).foregroundStyle(plum) }
        }.frame(width: 72, height: 72).background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
            .task(id: store.revision) {
                preview = store.artwork(drawing.month, drawing.section, size: 144)
            }
    }
}

struct PlannerView: View {
    @EnvironmentObject var store: PlannerStore
    @State private var showCover = false
    @State private var showAbout = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var today = Date()
    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BRIDGING THE GAP").font(.caption.bold()).tracking(2)
                        Text("Creative Moments").font(.system(.largeTitle, design: .serif, weight: .bold))
                        Text("Plan. Pause. Create.").font(.system(.title3, design: .serif))
                        Text("Your planner, for every year.").font(.subheadline)
                    }.foregroundStyle(plum)
                    NavigationLink {
                        TodayView()
                    } label: {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 7) {
                                Label("Your day", systemImage: "sun.max.fill").font(.headline)
                                Text(today.formatted(date: .abbreviated, time: .omitted)).font(.title3.bold())
                                let dueCount = store.openTasks(dueOnOrBefore: today).count
                                Text(dueCount == 0 ? "No tasks due or overdue" : "\(dueCount) tasks due or overdue")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill").font(.title2)
                        }.padding(20).frame(maxWidth: .infinity).background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain).accessibilityLabel("Open today’s planner")
                    Button { showCover = true } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(uiImage: store.coverImage ?? store.scene(PlannerMonth(year: 2027, month: 5)) ?? UIImage())
                                .resizable().scaledToFill().frame(height: 210).clipped().accessibilityHidden(true)
                            Text(store.document.coverName).font(.system(.title2, design: .serif, weight: .bold))
                            Label("Personalize your cover", systemImage: "photo")
                        }.padding().background(.white).clipShape(RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain).accessibilityLabel("Personalize cover, \(store.document.coverName)")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your months").font(.system(.title2, design: .serif, weight: .bold))
                        YearNavigation(year: $selectedYear)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                        ForEach(1...12, id: \.self) { number in
                            let month = PlannerMonth(year: selectedYear, month: number)
                            NavigationLink {
                                MonthView(month: month)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(month.title).font(.headline)
                                        Text(month.theme).font(.subheadline).foregroundStyle(.secondary)
                                        let tasks = store.record(month).tasks
                                        if !tasks.isEmpty {
                                            Text("\(tasks.filter(\.completed).count) of \(tasks.count) tasks complete")
                                                .font(.caption)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").accessibilityHidden(true)
                                }.padding(20).frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain)
                        }
                    }
                    NavigationLink { BackupView() } label: {
                        Label("Back up or restore your work", systemImage: "externaldrive")
                    }.font(.subheadline)
                    Text("© 2026 T. Crumble • Bridging the Gap").font(.caption).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: 1000)
            }.frame(maxWidth: .infinity).background(Color(red: 0.96, green: 0.94, blue: 0.96))
                .navigationTitle("My Planner").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button { showAbout = true } label: { Image(systemName: "info.circle") }.accessibilityLabel("Help and privacy") }
                .sheet(isPresented: $showCover) { CoverView() }
                .sheet(isPresented: $showAbout) { AboutView() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    today = Date()
                }
        }
    }
}

struct TodayView: View {
    @EnvironmentObject var store: PlannerStore
    @State private var newTask = ""
    @State private var today = Date()
    private var month: PlannerMonth { PlannerMonth.forDate(today) }
    private var day: Int { Calendar.current.component(.day, from: today) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(today.formatted(date: .complete, time: .omitted))
                    .font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(plum)
                Text("Today's plans").font(.headline)
                HStack {
                    TextField("Add a task for today", text: $newTask).textFieldStyle(.roundedBorder).onSubmit(addTask)
                    Button(action: addTask) { Image(systemName: "plus.circle.fill").font(.title2) }
                        .disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Add a task for today")
                }
                let due = store.openTasks(dueOnOrBefore: today)
                if due.isEmpty {
                    Text("Nothing due or overdue. Make space for a creative moment.")
                        .foregroundStyle(.secondary)
                }
                ForEach(due) { item in
                    HStack(alignment: .center, spacing: 12) {
                        Button { store.setTaskCompleted(item.task.id, in: item.month, completed: true) } label: {
                            Image(systemName: "circle").font(.title2)
                        }.accessibilityLabel("Complete \(item.task.title)")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.task.title)
                            if let key = item.task.dueDateKey, key < PlannerDay(date: today).key {
                                Text("Overdue · \(key)").font(.caption).foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        NavigationLink { MonthView(month: item.month) } label: {
                            Image(systemName: "arrow.up.right.square")
                        }.accessibilityLabel("Open \(item.month.title)")
                    }.padding().background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Text("Today's notes").font(.headline)
                TextEditor(text: store.dayBinding(month, day: day))
                    .frame(minHeight: 160).padding(8).background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                NavigationLink { MonthView(month: month) } label: {
                    Label("Open \(month.title) planner", systemImage: "calendar")
                }
            }.padding().frame(maxWidth: 800)
        }.background(Color(red: 0.98, green: 0.97, blue: 0.98))
            .navigationTitle("Today").navigationBarTitleDisplayMode(.inline)
            .onDisappear { store.flush() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                today = Date()
            }
    }
    private func addTask() {
        store.addTask(newTask, in: month, dueDate: today)
        newTask = ""
    }
}

struct CoverView: View {
    @EnvironmentObject var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?
    @State private var loading = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Your cover") {
                    TextField("Cover title", text: Binding(get: { store.document.coverName }, set: { store.setCoverName($0) }))
                    Image(uiImage: store.coverImage ?? store.scene(PlannerMonth(year: 2027, month: 5)) ?? UIImage())
                        .resizable().scaledToFit().frame(maxHeight: 360).accessibilityLabel("Current cover image")
                    PhotosPicker(selection: $selection, matching: .images) { Label("Choose a photo", systemImage: "photo.on.rectangle") }.disabled(loading)
                    if loading { ProgressView("Preparing your photo…") }
                    if store.coverImage != nil { Button("Use the original garden cover") { store.setCover(nil); selection = nil } }
                }
                Section { Text("Choose an image you own or have permission to use. The selected photo is copied into this app on your device. No photo is uploaded to a server.") }
            }.navigationTitle("Make it yours").toolbar { Button("Done") { store.flush(); dismiss() } }
                .task(id: selection) {
                    guard let item = selection else { return }
                    loading = true
                    defer { loading = false }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
                        try Task.checkCancellation()
                        store.setCover(image)
                    } catch is CancellationError {} catch { store.errorMessage = "Could not open this photo. Try a JPG or PNG. \(error.localizedDescription)" }
                }
        }
    }
}

struct MonthView: View {
    let month: PlannerMonth
    @EnvironmentObject var store: PlannerStore
    @State private var tab = 0
    @State private var day: DaySelection?
    @State private var drawing: DoodleSection?
    @State private var newTask = ""
    @State private var taskDate: TaskDueSelection?
    @State private var confirmCarry = false
    @State private var export: ShareFile?
    var body: some View {
        VStack(spacing: 0) {
            Picker("Planner section", selection: $tab) {
                Text("Calendar").tag(0); Text("Checklist").tag(1); Text("Doodle").tag(2)
            }.pickerStyle(.segmented).padding()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(month.theme).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(plum)
                    if tab == 0 { calendarContent }
                    if tab == 1 { checklistContent }
                    if tab == 2 { doodleContent }
                }.padding().frame(maxWidth: 1000, alignment: .leading)
            }.frame(maxWidth: .infinity)
        }.background(Color(red: 0.98, green: 0.97, blue: 0.98))
            .navigationTitle(month.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    store.flush()
                    do { export = ShareFile(url: try PlannerPDF.export(month: month, store: store)) }
                    catch { store.errorMessage = "Could not create the PDF. \(error.localizedDescription)" }
                } label: { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Export this month as PDF")
            }
            .sheet(item: $day) { item in
                NavigationStack {
                    TextEditor(text: store.dayBinding(month, day: item.id)).padding()
                        .navigationTitle("\(month.title) · \(item.id)")
                        .toolbar { Button("Done") { store.flush(); day = nil } }
                }.presentationDetents([.medium, .large])
            }
            .fullScreenCover(item: $drawing) { section in DoodleEditor(month: month, section: section) }
            .sheet(item: $export) { file in ActivityView(items: [file.url]) }
            .sheet(item: $taskDate) { selection in
                TaskDueDateView(month: month, taskID: selection.id)
            }
            .confirmationDialog("Carry unfinished tasks into \(month.title)?", isPresented: $confirmCarry) {
                Button("Move unfinished tasks") { store.carryForwardUnfinished(into: month) }
            } message: {
                Text("Unfinished tasks will be moved from \(month.previous.title). Existing completed tasks remain there; overdue dates move to the first day of this month.")
            }
    }
    private var calendarContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            TextField("My focus this month", text: store.binding(month, \.focus), axis: .vertical).textFieldStyle(.roundedBorder)
            Text("Tap a date to add a plan or note.").font(.subheadline).foregroundStyle(.secondary)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].enumerated()), id: \.offset) { _, weekday in
                    Text(weekday).font(.caption.bold()).minimumScaleFactor(0.7)
                }
                ForEach(0..<42, id: \.self) { index in
                    let number = index - month.leadingBlanks + 1
                    if number > 0 && number <= month.dayCount {
                        let note = store.record(month).days[String(number)] ?? ""
                        Button { day = DaySelection(id: number) } label: {
                            VStack(spacing: 6) {
                                Text("\(number)").font(.headline)
                                Circle().fill(note.isEmpty ? Color.clear : plum).frame(width: 5, height: 5)
                            }.frame(maxWidth: .infinity, minHeight: 60).background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.25)))
                        }.buttonStyle(.plain).accessibilityLabel("\(month.title) \(number)\(note.isEmpty ? ", no note" : ", has a note")")
                    } else { Color.clear.frame(height: 60).accessibilityHidden(true) }
                }
            }
            ForEach(1...month.dayCount, id: \.self) { number in
                if let note = store.record(month).days[String(number)], !note.isEmpty {
                    Button { day = DaySelection(id: number) } label: {
                        HStack(alignment: .top) { Text("\(number)").bold().frame(width: 28); Text(note).multilineTextAlignment(.leading); Spacer() }.padding().background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private var checklistContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ideas to bring to life").font(.system(.title3, design: .serif, weight: .bold))
            let pending = store.unfinishedCount(in: month.previous)
            if pending > 0 {
                Button { confirmCarry = true } label: {
                    Label("Carry forward \(pending) unfinished tasks from \(month.previous.title)", systemImage: "arrow.right")
                }.buttonStyle(.bordered)
            }
            HStack {
                TextField("Add a task", text: $newTask).textFieldStyle(.roundedBorder).onSubmit(addTask)
                Button(action: addTask) { Image(systemName: "plus.circle.fill").font(.title2) }.accessibilityLabel("Add task").disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ForEach(store.record(month).tasks) { task in
                HStack {
                    Button {
                        store.setTaskCompleted(task.id, in: month, completed: !task.completed)
                    } label: { Image(systemName: task.completed ? "checkmark.circle.fill" : "circle").font(.title2) }
                        .accessibilityLabel(task.completed ? "Mark incomplete" : "Mark complete")
                    TextField("Task", text: Binding(get: { store.record(month).tasks.first(where: { $0.id == task.id })?.title ?? "" }, set: { value in
                        store.update(month) { if let i = $0.tasks.firstIndex(where: { $0.id == task.id }) { $0.tasks[i].title = value } }
                    }), axis: .vertical).strikethrough(task.completed)
                    Button { taskDate = TaskDueSelection(id: task.id) } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "calendar.badge.clock")
                            if let key = task.dueDateKey { Text(key).font(.caption2) }
                        }
                    }.accessibilityLabel("Edit due date for \(task.title)")
                    Button(role: .destructive) { store.update(month) { $0.tasks.removeAll(where: { $0.id == task.id }) } } label: { Image(systemName: "trash") }.accessibilityLabel("Delete task \(task.title)")
                }.padding().background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            noteField("Notes & inspiration", key: \.notes)
            noteField("Something I enjoyed creating", key: \.joy)
            noteField("An idea to carry forward", key: \.carryForward)
        }
    }
    private func noteField(_ title: String, key: WritableKeyPath<MonthRecord, String>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.system(.headline, design: .serif))
            TextField(title, text: store.binding(month, key), axis: .vertical).lineLimit(3...12).textFieldStyle(.roundedBorder).accessibilityLabel(title)
        }
    }
    private func addTask() {
        let title = newTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.addTask(title, in: month); newTask = ""
    }
    private var doodleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Open a section to draw with your finger or Apple Pencil. Pinch to zoom; use two fingers to move around the canvas.").font(.subheadline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(DoodleSection.allCases) { section in
                    Button { drawing = section } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title).font(.system(.headline, design: .serif))
                            Image(uiImage: store.artwork(month, section)).resizable().scaledToFit().background(.white)
                            Text(section.subtitle).font(.caption).foregroundStyle(.secondary)
                        }.padding(12).background(.white).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).accessibilityLabel("Open \(section.title)")
                }
            }.id(store.revision)
        }
    }
}
struct TaskDueSelection: Identifiable { let id: UUID }

struct TaskDueDateView: View {
    @EnvironmentObject var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    let month: PlannerMonth
    let taskID: UUID
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    var body: some View {
        NavigationStack {
            Form {
                Toggle("Set a due date", isOn: $hasDueDate)
                if hasDueDate { DatePicker("Due date", selection: $dueDate, displayedComponents: .date) }
                Text("Tasks without due dates stay in this month's checklist. Dated tasks also appear on Today when due or overdue.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.navigationTitle("Task due date")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.setTaskDueDate(taskID, in: month, date: hasDueDate ? dueDate : nil)
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    let task = store.record(month).tasks.first { $0.id == taskID }
                    if let key = task?.dueDateKey, let day = PlannerDay(key: key) {
                        hasDueDate = true; dueDate = day.date
                    }
                }
        }.presentationDetents([.medium, .large])
    }
}

struct DaySelection: Identifiable { let id: Int }
struct ShareFile: Identifiable { let id = UUID(); let url: URL }
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct BackupView: View {
    @EnvironmentObject var store: PlannerStore
    @State private var export: ShareFile?
    @State private var showImporter = false
    @State private var pendingImport: URL?
    @State private var showRestoreConfirmation = false
    var body: some View {
        Form {
            Section("Protect your work") {
                Text("Your editable backup contains all planner notes, tasks, the selected cover image, and saved drawings. Keep it somewhere safe outside this app.")
                Button { exportBackup() } label: { Label("Export editable backup", systemImage: "square.and.arrow.up") }
                Text("Monthly PDFs are useful for printing but cannot restore your editable planner.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Restore your planner") {
                Text("Restoring replaces your current planner. The app keeps the previous local data in a recovery folder before switching to the imported backup.")
                Button { showImporter = true } label: { Label("Choose backup to restore", systemImage: "square.and.arrow.down") }
            }
        }.navigationTitle("Backup & restore")
            .sheet(item: $export) { file in ActivityView(items: [file.url]) }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let local = FileManager.default.temporaryDirectory.appendingPathComponent("CreativeMoments-Import-\(UUID().uuidString).json")
                        try FileManager.default.copyItem(at: url, to: local)
                        pendingImport = local
                        showRestoreConfirmation = true
                    } catch { store.errorMessage = "Could not open the selected backup. \(error.localizedDescription)" }
                case .failure(let error):
                    store.errorMessage = "Could not choose a backup. \(error.localizedDescription)"
                }
            }
            .confirmationDialog("Replace the current planner?", isPresented: $showRestoreConfirmation, titleVisibility: .visible) {
                Button("Restore selected backup", role: .destructive) {
                    guard let url = pendingImport else { return }
                    do { try store.restoreEditableBackup(from: url) }
                    catch { store.errorMessage = "Backup could not be restored. The existing planner was preserved when possible. \(error.localizedDescription)" }
                    try? FileManager.default.removeItem(at: url)
                    pendingImport = nil
                }
                Button("Cancel", role: .cancel) {
                    if let url = pendingImport { try? FileManager.default.removeItem(at: url) }
                    pendingImport = nil
                }
            } message: {
                Text("Your current planner will be replaced with the selected backup. A recovery copy is retained locally.")
            }
    }
    private func exportBackup() {
        do { export = ShareFile(url: try store.exportEditableBackup()) }
        catch { store.errorMessage = "Could not export an editable backup. \(error.localizedDescription)" }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Thank you") { Text("Thank you for choosing Creative Moments by T. Crumble. Make room for your plans, imagination, and small everyday joys.") }
                Section("Using your planner") {
                    Text("Start from Home: My Planner for plans and tasks, Color & Draw for pictures, My Journal for reflections, and My Creations to reopen saved drawings. Changes save automatically. Open a drawing and tap Share image to share it.")
                    Text("Changes save automatically. Month PDF exports are read-only; use Back up or restore from the home screen to export a complete editable backup of notes, tasks, cover, and drawings.")
                }
                Section("Privacy") {
                    Text("This version does not use accounts, ads, analytics, tracking, or a developer-operated server. Plans, drawings, and selected cover photos are stored in the app on this device. No planner data is sent to the developer.")
                    Text("Your device backup settings may include app data. Uninstalling the app deletes its local data unless you've saved an editable backup elsewhere. When you share a file, the destination you select receives the exported data under its own privacy practices.")
                    Text("The system photo picker gives access only to an image you select. Broad photo-library access is not requested.")
                    if let url = ReleaseConfiguration.privacyPolicyURL { Link("Privacy policy", destination: url) }
                    if let url = ReleaseConfiguration.supportURL { Link("Contact support", destination: url) }
                }
                Section("About this edition") {
                    Text("The original December 2026 – May 2028 months remain available, and the year selector allows future planning. Twelve seasonal illustrations recur by month. Drawing supports freehand pen, marker, eraser, undo and redo; there is no automatic fill-bucket tool.")
                    Text("© 2026 T. Crumble · Bridging the Gap. All rights reserved.")
                }
            }.navigationTitle("Help & privacy").toolbar { Button("Done") { dismiss() } }
        }
    }
}

enum ReleaseConfiguration {
    // Before App Store submission: publish the supplied privacy/support pages,
    // then replace nil with your verified public HTTPS URLs.
    static let privacyPolicyURL: URL? = nil
    static let supportURL: URL? = nil
}
