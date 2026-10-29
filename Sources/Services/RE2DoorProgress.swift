import Foundation

struct RE2DoorProgress: Identifiable {
    let id: Int
    let doorHash: UInt32
    let mapID: Int
    let stateCode: Int
}

enum RE2DoorProgressCatalog {
    private static let owner = SaveCrypto.murmur(Data("app.ropeway.gamemastering.UIMapManager.DoorInfo".utf8))
    private static let state = SaveCrypto.murmur(Data("_State".utf8))
    private static let hash = SaveCrypto.murmur(Data("_Hash".utf8))
    private static let mapID = SaveCrypto.murmur(Data("_MapId".utf8))
    private static let listPrefix = "/7f9decbe.8aab887b[8]/090ff53c.cb78b1f4/b15a035f.695a3627["

    static func entries(game: GameProfile, source: SaveFile, fields: [SaveScalar], character: String?) -> [RE2DoorProgress] {
        guard RE2CampaignSavePolicy.matches(game:game,source:source,character:character) else {return []}
        let selected = fields.filter {$0.owner == owner && [state, hash, mapID].contains($0.field)}
        guard !selected.isEmpty, selected.count <= 3_072, selected.count.isMultiple(of: 3) else {return []}
        let grouped = Dictionary(grouping: selected) {field -> String in
            guard let slash = field.path.lastIndex(of: "/") else {return ""}
            return String(field.path[..<slash])
        }
        guard grouped.count * 3 == selected.count else {return []}
        var rows: [RE2DoorProgress] = []
        for (parent, siblings) in grouped {
            guard parent.hasPrefix(listPrefix), parent.hasSuffix("]"), siblings.count == 3,
                  let index = Int(parent.dropFirst(listPrefix.count).dropLast()),
                  (0..<1_024).contains(index),
                  let stateField = one(state, type: 1, siblings: siblings, parent: parent),
                  let hashField = one(hash, type: 8, siblings: siblings, parent: parent),
                  let mapField = one(mapID, type: 1, siblings: siblings, parent: parent),
                  let stateCode = Int(stateField.text),
                  let doorHash = UInt32(hashField.text),
                  let mapNumber = Int(mapField.text) else {return []}
            rows.append(.init(id: index, doorHash: doorHash, mapID: mapNumber, stateCode: stateCode))
        }
        rows.sort {$0.id < $1.id}
        guard rows.count == grouped.count, rows.enumerated().allSatisfy({$0.offset == $0.element.id}),
              Set(rows.map(\.doorHash)).count == rows.count else {return []}
        return rows
    }

    private static func one(_ fieldHash: UInt32, type: Int32, siblings: [SaveScalar], parent: String) -> SaveScalar? {
        let matches = siblings.filter {$0.field == fieldHash}
        guard matches.count == 1, let field = matches.first,
              field.type == type, field.size == 4,
              field.path == parent + String(format: "/%08x.%08x", owner, fieldHash) else {return nil}
        return field
    }
}
