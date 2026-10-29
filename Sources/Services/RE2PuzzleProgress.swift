import Foundation

struct RE2PuzzleProgress {
    struct GoddessStatue {
        let medallions: [Bool]
        let stateCode: Int
    }
    struct CircuitPuzzle {
        let panelTurns: [UInt32]
        let actionCount: UInt32
    }
    let goddessStatue: GoddessStatue?
    let circuitPuzzle: CircuitPuzzle?
}

enum RE2PuzzleProgressCatalog {
    private static let goddessOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickGoddessStatue.SaveData".utf8))
    private static let circuitOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickCircuitPuzzle.SaveData".utf8))
    private static let gameList = "/7f9decbe.8aab887b[23]/8413308a.34be46bd["

    static func details(game: GameProfile, source: SaveFile, fields: [SaveScalar], character: String?) -> RE2PuzzleProgress? {
        guard RE2CampaignSavePolicy.matches(game:game,source:source,character:character) else {return nil}

        func direct(_ name: String, owner: UInt32, type: Int32, size: Int) -> SaveScalar? {
            let hash = SaveCrypto.murmur(Data(name.utf8))
            let matches = fields.filter {$0.owner == owner && $0.field == hash}
            guard matches.count == 1, let field = matches.first,
                  field.type == type, field.size == size,
                  field.path.hasPrefix(gameList),
                  field.path.hasSuffix(String(format: "/%08x.%08x", owner, hash)) else {return nil}
            return field
        }
        func indexed(_ name: String, owner: UInt32, count: Int, type: Int32, size: Int) -> [SaveScalar]? {
            let hash = SaveCrypto.murmur(Data(name.utf8))
            let matches = fields.filter {$0.owner == owner && $0.field == hash}
            guard matches.count == count else {return nil}
            var byIndex: [Int: SaveScalar] = [:]
            var parents: Set<String> = []
            for field in matches {
                guard field.type == type, field.size == size,
                      field.path.hasPrefix(gameList),
                      let slash = field.path.lastIndex(of: "/") else {return nil}
                let parent = String(field.path[..<slash])
                let suffix = String(field.path[field.path.index(after: slash)...])
                let prefix = String(format: "%08x.%08x[", owner, hash)
                guard suffix.hasPrefix(prefix), suffix.last == "]",
                      let index = Int(suffix.dropFirst(prefix.count).dropLast()),
                      (0..<count).contains(index), byIndex[index] == nil else {return nil}
                parents.insert(parent)
                byIndex[index] = field
            }
            guard parents.count == 1, byIndex.count == count else {return nil}
            return (0..<count).compactMap {byIndex[$0]}
        }
        func parent(_ path: String) -> String? {
            path.lastIndex(of: "/").map {String(path[..<$0])}
        }

        var goddess: RE2PuzzleProgress.GoddessStatue?
        if let medals = indexed("HasMedal", owner: goddessOwner, count: 3, type: 2, size: 1),
           let state = direct("State", owner: goddessOwner, type: 1, size: 4),
           parent(medals[0].path) == parent(state.path),
           let stateCode = Int(state.text), (0...255).contains(stateCode),
           medals.allSatisfy({$0.text == "true" || $0.text == "false"}) {
            goddess = .init(medallions: medals.map {$0.text == "true"}, stateCode: stateCode)
        }

        var circuit: RE2PuzzleProgress.CircuitPuzzle?
        if let turns = indexed("PanelTurn", owner: circuitOwner, count: 16, type: 7, size: 4),
           let actions = direct("ActionCount", owner: circuitOwner, type: 7, size: 4),
           parent(turns[0].path) == parent(actions.path),
           let actionCount = UInt32(actions.text) {
            let parsed = turns.map {UInt32($0.text)}
            if parsed.allSatisfy({$0 != nil}) {
                circuit = .init(panelTurns: parsed.compactMap {$0}, actionCount: actionCount)
            }
        }
        guard goddess != nil || circuit != nil else {return nil}
        return .init(goddessStatue: goddess, circuitPuzzle: circuit)
    }
}
