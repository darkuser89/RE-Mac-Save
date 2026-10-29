import Foundation

struct RE2RunFlag: Identifiable {
    let id: String
    let title: String
    let isSet: Bool
}

enum RE2RunFlagCatalog {
    private static let owner = SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.GameSaveData".utf8))
    private static let names = [
        ("UseSpecialWeapon", "Spezialwaffe verwendet"),
        ("UseAimAssist", "Zielhilfe verwendet")
    ]

    static func flags(game: GameProfile, fields: [SaveScalar], character: String?) -> [RE2RunFlag] {
        guard game.id == "re2", character != nil else {return []}
        return names.compactMap {name, title in
            let hash = SaveCrypto.murmur(Data(name.utf8))
            let matches = fields.filter {$0.owner == owner && $0.field == hash}
            guard matches.count == 1, matches[0].type == 2, matches[0].size == 1 else {return nil}
            switch matches[0].text {
            case "true": return RE2RunFlag(id: name, title: title, isSet: true)
            case "false": return RE2RunFlag(id: name, title: title, isSet: false)
            default: return nil
            }
        }
    }
}
