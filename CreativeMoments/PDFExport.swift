import UIKit

@MainActor
enum PlannerPDF {
    static func export(month: PlannerMonth, store: PlannerStore) throws -> URL {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let record = store.record(month)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("CreativeMoments-\(month.id).pdf")
        try renderer.writePDF(to: file) { context in
            var page = 0
            func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 504, _ size: CGFloat = 11, _ bold: Bool = false) {
                (value as NSString).draw(in: CGRect(x: x, y: y, width: width, height: 100), withAttributes: [.font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size), .foregroundColor: UIColor.black])
            }
            func start(_ title: String) {
                context.beginPage(); page += 1
                text("BRIDGING THE GAP / CREATIVE MOMENTS",54,28,504,9,true)
                text(title,54,58,504,22,true)
                text("© 2026 T. Crumble · Bridging the Gap",54,754,470,8)
                text("\(page)",540,754,30,8)
            }
            start(month.title)
            text(month.theme,54,94,504,12,true)
            text("Focus: " + String(record.focus.prefix(70)) + (record.focus.count > 70 ? "… (continued in notes)" : ""),54,118,504,10)
            let top: CGFloat = 170
            let labels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
            for col in 0..<7 { text(labels[col],54+CGFloat(col)*72,top-22,68,10,true) }
            for index in 0..<42 {
                let col = index % 7, row = index / 7
                let rect = CGRect(x: 54+CGFloat(col)*72,y:top+CGFloat(row)*80,width:72,height:80)
                UIColor.lightGray.setStroke(); UIBezierPath(rect: rect).stroke()
                let day = index - month.leadingBlanks + 1
                if day > 0 && day <= month.dayCount {
                    text("\(day)",rect.minX+5,rect.minY+5,60,10,true)
                    if let note = record.days[String(day)], !note.isEmpty { text("• Note",rect.minX+5,rect.minY+30,60,9) }
                }
            }
            text("Day notes appear in full on the following pages.",54,680,504,10)
            start(month.title + " | Checklist & notes")
            var y: CGFloat = 108
            func line(_ value: String, bold: Bool = false) {
                if y > 710 { start(month.title + " | Notes continued"); y = 108 }
                text(value,54,y,504,11,bold); y += 18
            }
            func paragraph(_ value: String) {
                // Character-aware wrapping preserves long unbroken text too.
                for source in value.components(separatedBy: .newlines) {
                    var buffer = ""
                    for character in source {
                        let candidate = buffer + String(character)
                        if (candidate as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 11)]).width > 500, !buffer.isEmpty {
                            line(buffer); buffer = String(character)
                        } else { buffer = candidate }
                    }
                    line(buffer)
                }
                y += 8
            }
            line("MONTHLY FOCUS", bold: true); paragraph(record.focus)
            line("CHECKLIST", bold: true)
            if record.tasks.isEmpty { paragraph("No tasks added.") }
            for task in record.tasks { paragraph((task.completed ? "[x] " : "[ ] ") + task.title) }
            line("DAY NOTES", bold: true)
            for day in 1...month.dayCount {
                if let note = record.days[String(day)], !note.isEmpty { line("\(month.title) · \(day)",bold:true); paragraph(note) }
            }
            for (heading,body) in [("NOTES & INSPIRATION",record.notes),("SOMETHING I ENJOYED CREATING",record.joy),("CARRY FORWARD",record.carryForward)] { line(heading,bold:true); paragraph(body) }
            start(month.title + " | Doodle studio")
            text(month.theme,54,94,504,12,true)
            for section in DoodleSection.allCases {
                let col = section.rawValue % 2, row = section.rawValue / 2
                let x = 54 + CGFloat(col)*258, y = 130 + CGFloat(row)*290
                let box = CGRect(x: x,y:y,width:246,height:272)
                UIColor.lightGray.setStroke(); UIBezierPath(roundedRect: box,cornerRadius:8).stroke()
                text(section.title,x+12,y+12,222,12,true)
                store.artwork(month,section,size:1000).draw(in:CGRect(x:x+13,y:y+40,width:220,height:220))
            }
        }
        return file
    }
}
