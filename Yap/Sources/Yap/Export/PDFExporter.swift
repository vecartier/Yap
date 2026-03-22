import AppKit
import Foundation
import UniformTypeIdentifiers

struct PDFExporter {

    struct Content {
        let session: SessionIndex
        let summary: SummaryEngine.PersistedSummary?
        let records: [SessionRecord]
    }

    @discardableResult @MainActor
    static func export(_ content: Content, to fileURL: URL) -> Bool {
        let attrStr = compose(content)

        let printInfo = NSPrintInfo.shared.mutableCopy() as! NSPrintInfo
        printInfo.paperSize = NSSize(width: 612, height: 792)
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.jobDisposition = .save

        let pageWidth = 612 - 72 - 72   // 468pt
        let pageHeight = 792 - 72 - 72  // 648pt
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        textView.textStorage?.setAttributedString(attrStr)

        let pdfData = NSMutableData()
        let op = NSPrintOperation.pdfOperation(
            with: textView,
            inside: textView.bounds,
            to: pdfData,
            printInfo: printInfo
        )
        op.showsPrintPanel = false
        op.showsProgressPanel = false
        guard op.run() else { return false }
        return (try? pdfData.write(to: fileURL, options: .atomic)) != nil
    }

    // MARK: - Content Composition

    private static func compose(_ content: Content) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 20)
        let title = content.session.title ?? "Meeting"
        result.append(NSAttributedString(
            string: title + "\n\n",
            attributes: [.font: titleFont, .foregroundColor: NSColor.labelColor]
        ))

        // Metadata
        let metaFont = NSFont.systemFont(ofSize: 12)
        let metaColor = NSColor.secondaryLabelColor
        var meta = formattedDate(content.session.startedAt)
        if let endedAt = content.session.endedAt {
            meta += "   " + formattedDuration(from: content.session.startedAt, to: endedAt)
        }
        meta += "   " + meetingType(for: content.session)
        result.append(NSAttributedString(
            string: meta + "\n\n",
            attributes: [.font: metaFont, .foregroundColor: metaColor]
        ))

        // Summary sections (if available)
        if let summary = content.summary {
            let sectionFont = NSFont.boldSystemFont(ofSize: 13)
            let bodyFont = NSFont.systemFont(ofSize: 13)
            for (heading, items) in [
                ("Key Decisions", summary.decisions),
                ("Action Items", summary.actionItems),
                ("Discussion Points", summary.discussionPoints),
                ("Open Questions", summary.openQuestions)
            ] {
                result.append(NSAttributedString(
                    string: heading + "\n",
                    attributes: [.font: sectionFont, .foregroundColor: NSColor.labelColor]
                ))
                if items.isEmpty {
                    result.append(NSAttributedString(
                        string: "  None recorded\n",
                        attributes: [.font: bodyFont, .foregroundColor: metaColor]
                    ))
                } else {
                    for item in items {
                        result.append(NSAttributedString(
                            string: "  \u{2022} \(item)\n",
                            attributes: [.font: bodyFont, .foregroundColor: NSColor.labelColor]
                        ))
                    }
                }
                result.append(NSAttributedString(string: "\n"))
            }
        }

        // Divider
        result.append(NSAttributedString(
            string: String(repeating: "\u{2014}", count: 40) + "\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: metaColor]
        ))

        // Transcript heading
        let transcriptTitleFont = NSFont.boldSystemFont(ofSize: 14)
        result.append(NSAttributedString(
            string: "Transcript\n\n",
            attributes: [.font: transcriptTitleFont, .foregroundColor: NSColor.labelColor]
        ))

        // Transcript lines
        let lineFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        for record in content.records {
            let speaker = speakerLabel(for: record.speaker)
            let text = record.refinedText ?? record.text
            result.append(NSAttributedString(
                string: "[\(speaker)]  \(text)\n",
                attributes: [.font: lineFont, .foregroundColor: NSColor.labelColor]
            ))
        }

        return result
    }

    // MARK: - Private Helpers

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formattedDuration(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: interval) ?? "Unknown"
    }

    private static func meetingType(for session: SessionIndex) -> String {
        if let app = session.meetingApp, !app.isEmpty { return app }
        if let template = session.templateSnapshot { return template.name }
        return "Recording"
    }

    private static func speakerLabel(for speaker: Speaker) -> String {
        switch speaker {
        case .you:   return "You"
        case .them:  return "Them"
        case .room:  return "Room"
        }
    }
}
