import Foundation

struct RE2EnvironmentProgress {
    struct Window: Identifiable {
        let id: Int
        let objectHash: UInt32
        let mapID: Int
        let barricaded: Bool
    }

    let displayedTutorials: [Bool]?
    let windows: [Window]
}

enum RE2EnvironmentProgressCatalog {
    private static let tutorialOwner = SaveCrypto.murmur(Data("app.ropeway.gamemastering.TutorialManager.GameSaveData".utf8))
    private static let tutorialField = SaveCrypto.murmur(Data("IsDispTutorial".utf8))
    private static let tutorialPrefix = "/7f9decbe.8aab887b[12]/91bb4685.bfb6252d["
    private static let windowOwner = SaveCrypto.murmur(Data("app.ropeway.gamemastering.UIMapManager.WindowInfo".utf8))
    private static let windowHash = SaveCrypto.murmur(Data("_Hash".utf8))
    private static let windowMap = SaveCrypto.murmur(Data("_MapId".utf8))
    private static let windowBarricade = SaveCrypto.murmur(Data("_IsBarricade".utf8))
    private static let windowPrefix = "/7f9decbe.8aab887b[8]/090ff53c.c07d05d1/934e2e6b.695a3627["

    static func details(game: GameProfile, source: SaveFile, fields: [SaveScalar], character: String?) -> RE2EnvironmentProgress? {
        guard game.id == "re2", character != nil,
              ["data000.bin", "data001Slot.bin", "data002Slot.bin"].contains(source.url.lastPathComponent) else {return nil}
        let tutorials = tutorialFlags(fields)
        let windows = windowRows(fields)
        guard tutorials != nil || !windows.isEmpty else {return nil}
        return .init(displayedTutorials:tutorials,windows:windows)
    }

    private static func tutorialFlags(_ fields: [SaveScalar]) -> [Bool]? {
        let selected = fields.filter {$0.owner == tutorialOwner && $0.field == tutorialField}
        guard selected.count == 63 else {return nil}
        var values = [Bool?](repeating:nil,count:63)
        for field in selected {
            guard field.type == 2, field.size == 1,
                  field.path.hasPrefix(tutorialPrefix), field.path.hasSuffix("]"),
                  let index = Int(field.path.dropFirst(tutorialPrefix.count).dropLast()),
                  values.indices.contains(index), values[index] == nil,
                  let value = boolean(field) else {return nil}
            values[index] = value
        }
        guard values.allSatisfy({$0 != nil}) else {return nil}
        return values.compactMap {$0}
    }

    private static func windowRows(_ fields: [SaveScalar]) -> [RE2EnvironmentProgress.Window] {
        let hashes = [windowHash,windowMap,windowBarricade]
        let selected = fields.filter {$0.owner == windowOwner && hashes.contains($0.field)}
        guard !selected.isEmpty, selected.count <= 3_072, selected.count.isMultiple(of:3) else {return []}
        let groups = Dictionary(grouping:selected) {field -> String in
            guard let slash = field.path.lastIndex(of:"/") else {return ""}
            return String(field.path[..<slash])
        }
        guard groups.count * 3 == selected.count else {return []}
        var rows: [RE2EnvironmentProgress.Window] = []
        for (parent,siblings) in groups {
            guard parent.hasPrefix(windowPrefix), parent.hasSuffix("]"), siblings.count == 3,
                  let index = Int(parent.dropFirst(windowPrefix.count).dropLast()),
                  (0..<1_024).contains(index),
                  let hashField = one(windowHash,type:8,size:4,parent:parent,fields:siblings),
                  let mapField = one(windowMap,type:1,size:4,parent:parent,fields:siblings),
                  let barricadeField = one(windowBarricade,type:2,size:1,parent:parent,fields:siblings),
                  let objectHash = UInt32(hashField.text), let mapID = Int(mapField.text),
                  let barricaded = boolean(barricadeField) else {return []}
            rows.append(.init(id:index,objectHash:objectHash,mapID:mapID,barricaded:barricaded))
        }
        rows.sort {$0.id < $1.id}
        guard rows.enumerated().allSatisfy({$0.offset == $0.element.id}),
              Set(rows.map(\.objectHash)).count == rows.count else {return []}
        return rows
    }

    private static func one(_ hash: UInt32, type: Int32, size: Int, parent: String, fields: [SaveScalar]) -> SaveScalar? {
        let matches = fields.filter {$0.field == hash}
        guard matches.count == 1, let field = matches.first, field.type == type, field.size == size,
              field.path == parent + String(format:"/%08x.%08x",windowOwner,hash) else {return nil}
        return field
    }

    private static func boolean(_ field: SaveScalar) -> Bool? {
        switch field.text {case "true":return true;case "false":return false;default:return nil}
    }
}
