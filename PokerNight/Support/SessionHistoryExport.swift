import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct SessionHistoryExport: Transferable {
    let group: GameGroup

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            Data(CSVExporter.sessionHistoryCSV(for: export.group).utf8)
        }
        .suggestedFileName("session-history.csv")
    }
}
