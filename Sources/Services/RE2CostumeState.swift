import Foundation

struct RE2CostumeState: Identifiable {
    struct Entry: Identifiable {
        let id: Int
        let path: String
        let value: String
        let survivorTypeCode: Int?
    }

    let id: String
    let title: String
    let entries: [Entry]
    var distinctValues: [String] {Array(Set(entries.map(\.value))).sorted()}
}

enum RE2CostumeStateCatalog {
    private static let sources: [(String, String)] = [
        ("UserCostumeDataList", "Benutzer-Kostümdaten"),
        ("CheckedCostumeDataList", "Geprüfte Kostümdaten"),
        ("ScenarioCostumeDataList", "Szenario-Kostümdaten"),
        ("ActorContextList", "Figurenkontext"),
        ("", "Weitere Kostümdaten")
    ]
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
        let costumeDataOwner = SaveCrypto.murmur(Data("app.ropeway.CostumeManager.CostumeData".utf8))
        let survivorTypeField = SaveCrypto.murmur(Data("SurvivorType".utf8))
        let survivorTypes = Dictionary(grouping: saveFields.filter {
            $0.owner == costumeDataOwner && $0.field == survivorTypeField && $0.type == 1 && $0.size == 4
        }, by: { parentPath(of: $0.path) })
        return fields.flatMap {name, title -> [RE2CostumeState] in
            let hash = SaveCrypto.murmur(Data(name.utf8))
            let matches = saveFields.filter {
                $0.field == hash && $0.type != 15 && (1...8).contains($0.size)
            }
            return sources.compactMap {source, sourceTitle in
                let group = matches.filter {field in sourceName(for: field.path) == source}
                guard !group.isEmpty else {return nil}
                return RE2CostumeState(id: name + "." + source,
                                      title: source.isEmpty ? title : "\(sourceTitle): \(title)",
                                      entries: group.enumerated().map {index, field in
                    let pair = survivorTypes[parentPath(of: field.path)]
                    let typeCode = name == "CostumeID" && field.owner == costumeDataOwner && pair?.count == 1
                        ? pair.flatMap { Int($0[0].text) } : nil
                    return RE2CostumeState.Entry(id: index, path: field.path, value: field.text,
                                                  survivorTypeCode: typeCode)
                })
            }
        }
    }

    private static func parentPath(of path: String) -> String {
        guard let separator = path.lastIndex(of: "/") else {return ""}
        return String(path[..<separator])
    }

    private static func sourceName(for path: String) -> String {
        for (name, _) in sources where !name.isEmpty {
            let hash = SaveCrypto.murmur(Data(name.utf8))
            if path.contains(String(format: ".%08x[", hash)) {return name}
        }
        return ""
    }
}
