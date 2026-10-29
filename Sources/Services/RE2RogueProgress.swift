import Foundation

struct RE2RogueFieldGroup: Identifiable {
    struct Entry: Identifiable {
        let index: Int?
        let value: String
        var id: Int {index ?? -1}
    }

    let id: String
    let name: String
    let entries: [Entry]
    let isBoolean: Bool
    var markedCount: Int {entries.filter {$0.value == "true"}.count}
    var title: String {
        let labels = [
            "RoguePlayCount":"Gespielte Runden",
            "IsClearedRogueGame_Normal":"Abgeschlossene Normalrunden",
            "IsClearedRogueGame_Training":"Abgeschlossene Trainingsrunden",
            "RogueClearTime_Normal":"Gespeicherte Zeitwerte · Normal",
            "RogueClearTime_Training":"Gespeicherte Zeitwerte · Training",
            "IsClearedRogueRecord":"Abgeschlossene Rekord-IDs",
            "RecordProgressNumber":"Rekord-Fortschrittswerte",
            "IsOpenedRogueReward":"Geöffnete Belohnungs-IDs",
            "IsNewRogueReward":"Als neu markierte Belohnungs-IDs",
            "RogueRaccoonFigureCount":"Raccoon-Figurenzähler im Zusatzmodus",
            "DefeatEnemyCount_Normal":"Besiegte Gegner · Normal",
            "DefeatEnemyCount_Training":"Besiegte Gegner · Training",
            "UseHandGunBulletCount_Normal":"Pistolenmunitions-Zähler · Normal",
            "UseHandGunBulletCount_Training":"Pistolenmunitions-Zähler · Training"
        ]
        return labels[name] ?? name
    }
}

enum RE2RogueProgressCatalog {
    private static let rootOwner = SaveCrypto.murmur(Data("app.ropeway.gamemastering.SaveDataManager.RogueSystemSaveData".utf8))
    private static let rootList = SaveCrypto.murmur(Data("RogueSystemSaveDataList".utf8))
    private static let recordOwner: UInt32 = 0xb6f9870b

    static func groups(game: GameProfile, source: SaveFile, fields: [SaveScalar],
                       names: [String:[String]] = RE2FieldNameCatalog.bundled) -> [RE2RogueFieldGroup] {
        guard game.id == "re2", source.url.lastPathComponent == "data021Slot.bin" else {return []}
        let prefix = String(format: "/%08x.%08x[1]/%08x.", rootOwner, rootList, recordOwner)
        let candidates = fields.filter {$0.owner == recordOwner}
        guard !candidates.isEmpty, candidates.count <= 256,
              candidates.allSatisfy({$0.path.hasPrefix(prefix)}) else {return []}
        let result = Dictionary(grouping: candidates, by: \.field).keys.sorted().compactMap {hash -> RE2RogueFieldGroup? in
            let hex = String(format: "%08x", hash)
            guard let matchingNames = names[hex], matchingNames.count == 1 else {return nil}
            let scalars = candidates.filter {$0.field == hash}
            guard let first = scalars.first, scalars.count <= 32,
                  scalars.allSatisfy({$0.type == first.type && $0.size == first.size}) else {return nil}
            let validType: Bool
            switch (first.type, first.size) {
            case (2, 1), (1, 4), (7, 4), (8, 4), (10, 8):validType = true
            default:validType = false
            }
            guard validType else {return nil}
            var indexed: [Int:RE2RogueFieldGroup.Entry] = [:]
            var single: RE2RogueFieldGroup.Entry?
            for scalar in scalars {
                if first.type == 2 {
                    guard scalar.text == "true" || scalar.text == "false" else {return nil}
                } else if first.type == 1 {
                    guard Int32(scalar.text) != nil else {return nil}
                } else {
                    guard UInt64(scalar.text) != nil else {return nil}
                }
                let suffix = String(scalar.path.dropFirst(prefix.count))
                guard suffix.hasPrefix(hex) else {return nil}
                let tail = String(suffix.dropFirst(8))
                if tail.isEmpty {
                    guard scalars.count == 1, single == nil else {return nil}
                    single = .init(index:nil,value:scalar.text)
                } else {
                    guard tail.first == "[", tail.last == "]",
                          let index = Int(tail.dropFirst().dropLast()),
                          (0..<scalars.count).contains(index), indexed[index] == nil else {return nil}
                    indexed[index] = .init(index:index,value:scalar.text)
                }
            }
            let entries: [RE2RogueFieldGroup.Entry]
            if let single {entries = [single]}
            else {
                guard indexed.count == scalars.count else {return nil}
                entries = (0..<scalars.count).compactMap {indexed[$0]}
            }
            return RE2RogueFieldGroup(id:hex,name:matchingNames[0],entries:entries,isBoolean:first.type == 2)
        }
        return result.sorted {left, right in
            let leftTechnical = left.name == "Hash" || left.name == "Version" ? 1 : 0
            let rightTechnical = right.name == "Hash" || right.name == "Version" ? 1 : 0
            return leftTechnical == rightTechnical ? left.title.localizedStandardCompare(right.title) == .orderedAscending : leftTechnical < rightTechnical
        }
    }
}
