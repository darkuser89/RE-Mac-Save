import Foundation

struct RE2MapProgress: Identifiable {
    let id: String
    let title: String
    let total: Int
    let distribution: [(code: Int, count: Int)]
}

enum RE2MapProgressCatalog {
    private struct Spec {
        let owner: String
        let field: String
        let title: String
        let type: Int32
        let size: Int
        let expectedCount: Int?
    }

    private static let specs = [
        Spec(owner: "app.ropeway.gamemastering.UIMapManager.SaveData", field: "openedFloor", title: "Etagen-Markierungen", type: 2, size: 1, expectedCount: 33),
        Spec(owner: "app.ropeway.gamemastering.UIMapManager.SaveData", field: "mapDispState", title: "Karten-Anzeigecodes", type: 1, size: 4, expectedCount: 563),
        Spec(owner: "app.ropeway.gui.MapClearingResultManager.MapData", field: "Arrived", title: "Bereichs-Markierungen", type: 2, size: 1, expectedCount: nil),
        Spec(owner: "app.ropeway.gui.MapClearingResultManager.UnitData", field: "HasCleared", title: "Abschnitts-Markierungen", type: 2, size: 1, expectedCount: nil),
        Spec(owner: "app.ropeway.gamemastering.UIMapManager.MapPartsChangeInfo", field: "Done", title: "Kartenänderungs-Markierungen", type: 2, size: 1, expectedCount: 64)
    ]

    static func summaries(game: GameProfile, fields: [SaveScalar], character: String?) -> [RE2MapProgress] {
        guard game.id == "re2", character != nil else {return []}
        return specs.compactMap { spec in
            let owner = SaveCrypto.murmur(Data(spec.owner.utf8))
            let name = SaveCrypto.murmur(Data(spec.field.utf8))
            let matches = fields.filter {$0.owner == owner && $0.field == name}
            guard !matches.isEmpty, matches.count <= 1024,
                  spec.expectedCount == nil || matches.count == spec.expectedCount,
                  Set(matches.map(\.path)).count == matches.count,
                  matches.allSatisfy({$0.type == spec.type && $0.size == spec.size}) else {return nil}
            var counts: [Int:Int] = [:]
            for field in matches {
                let value: Int?
                if spec.type == 2 {value = field.text == "true" ? 1 : field.text == "false" ? 0 : nil}
                else {value = Int(field.text).flatMap {(0...255).contains($0) ? $0 : nil}}
                guard let value else {return nil}
                counts[value, default: 0] += 1
            }
            return RE2MapProgress(id: spec.field, title: spec.title, total: matches.count,
                                  distribution: counts.keys.sorted().map {($0, counts[$0]!)})
        }
    }
}
