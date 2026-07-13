import Foundation

enum CSVExporter {
    static func sessionHistoryCSV(for group: GameGroup) -> String {
        var lines = ["Date,Location,Player,Buy-in,Cash-out,Net"]
        let sessions = group.sessions.sorted { $0.date < $1.date }
        for session in sessions {
            let dateString = session.date.formatted(date: .numeric, time: .omitted)
            let location = session.location ?? ""
            let entries = session.entries.sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
            for entry in entries {
                let name = entry.player?.name ?? "Unknown"
                let fields = [
                    dateString,
                    location,
                    name,
                    "\(entry.totalBuyIn)",
                    "\(entry.cashOut ?? 0)",
                    "\(entry.net)"
                ]
                lines.append(fields.map(csvField).joined(separator: ","))
            }
        }
        return lines.joined(separator: "\r\n")
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
