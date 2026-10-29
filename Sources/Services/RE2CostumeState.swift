import Foundation

struct RE2CostumeState: Identifiable {
    struct Entry: Identifiable {
        let id: Int
        let path: String
        let value: String
    }

    let id: String
    let title: String
    let entries: [Entry]
    var distinctValues: [String] {Array(Set(entries.map(\.value))).sorted()}
}

enum RE2CostumeStateCatalog {
    private static let fields: [(String, String)] = [
        ("CostumeID", "Gespeicherte Kostüm-IDs"),
        ("CostumeType", "Gespeicherte Kostümtypen"),
        ("RequestChangeUserCostumeID", "Angeforderte Kostüm-ID"),
        ("IsOpenedPopUp_Costume_Scenario", "Kostümhinweis im Szenario geöffnet"),
        ("IsCheckedNewMark_Costume_Scenario", "Neue Kostüme im Szenario angesehen"),
        ("IsOpenedPopUp_Costume_Pause", "Kostümhinweis im Pausenmenü geöffnet"),
        ("IsCheckedNewMark_Costume_Pause", "Neue Kostüme im Pausenmenü angesehen")
    ]

    static func states(game: GameProfile, fields saveFields: [SaveScalar]) -> [RE2CostumeState] {
        guard game.id == "re2" else {return []}
        return fields.compactMap {name, title in
            let hash = SaveCrypto.murmur(Data(name.utf8))
            let matches = saveFields.filter {
                $0.field == hash && $0.type != 15 && (1...8).contains($0.size)
            }
            guard !matches.isEmpty else {return nil}
            return RE2CostumeState(id: name, title: title, entries: matches.enumerated().map {index, field in
                RE2CostumeState.Entry(id: index, path: field.path, value: field.text)
            })
        }
    }
}
