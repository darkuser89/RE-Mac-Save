import Foundation

struct RE2ProgressFlags: Identifiable {
    let id: String
    let title: String
    let total: Int
    let marked: [Int]
}

enum RE2ProgressFlagCatalog {
    private static let owner: UInt32 = 0x4e4210f9 // RE2 system save, record manager
    private static let specs: [(name: String, title: String, count: Int)] = [
        ("IsClearedRecord", "Abgeschlossene Rekord-IDs", 91),
        ("IsOpenedReward", "Als geöffnet markierte Belohnungs-IDs", 133),
        ("IsClearedGame", "Gesetzte Spielabschluss-IDs", 21)
    ]

    static func lists(game: GameProfile, source: SaveFile, fields: [SaveScalar]) -> [RE2ProgressFlags] {
        guard game.id == "re2", source.url.lastPathComponent == "data00-1.bin" else {return []}
        return specs.compactMap {spec in
            let hash = SaveCrypto.murmur(Data(spec.name.utf8))
            let matches = fields.filter {$0.owner == owner && $0.field == hash}
            guard matches.count == spec.count else {return nil}
            var indexed: [Int: Bool] = [:]
            for field in matches {
                guard field.type == 2, field.size == 1,
                      field.text == "true" || field.text == "false",
                      let open = field.path.lastIndex(of: "["), field.path.last == "]",
                      let index = Int(field.path[field.path.index(after: open)..<field.path.index(before: field.path.endIndex)]),
                      (0..<spec.count).contains(index), indexed[index] == nil else {return nil}
                indexed[index] = field.text == "true"
            }
            guard indexed.count == spec.count else {return nil}
            return RE2ProgressFlags(id: spec.name,title: spec.title,total: spec.count,
                                    marked: indexed.keys.sorted().filter {indexed[$0] == true})
        }
    }
}
