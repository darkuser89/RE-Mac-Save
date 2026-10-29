import Foundation

struct RE2MechanismProgress {
    struct Switch: Identifiable {
        let id: Int
        let toggled: Bool
        let applied: Bool
        let finalApplied: Bool
    }
    struct Plug: Identifiable {
        let id: Int
        let plugCode: Int
        let initialized: Bool
    }
    struct ClockGear {
        let topCode: Int
        let bottomCode: Int
        let initialized: Bool
        let firstFlags: [Bool]
    }
    let switches: [Switch]
    let plugs: [Plug]
    let clockGear: ClockGear?
}

enum RE2MechanismProgressCatalog {
    private static let switchOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickToggleSwitch.SaveData".utf8))
    private static let plugOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickPlugPlaceControl.SaveData".utf8))
    private static let clockOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickClockGearControl.SaveData".utf8))
    private static let bodyPrefix = "/7f9decbe.8aab887b[23]/8413308a.34be46bd["
    private static let controlPrefix = "/7f9decbe.8aab887b[23]/8413308a.c81a3eff["

    static func details(game: GameProfile, source: SaveFile, fields: [SaveScalar], character: String?) -> RE2MechanismProgress? {
        guard game.id == "re2", character != nil,
              ["data000.bin", "data001Slot.bin", "data002Slot.bin"].contains(source.url.lastPathComponent) else {return nil}
        let switches = grouped(fields, owner: switchOwner,
                               names: ["Toggle", "_isToggleApply", "_isToggleEndApply"],
                               listPrefix: bodyPrefix, objectTail: "/6fa91e18.1bd539fc") {id, values -> RE2MechanismProgress.Switch? in
            guard let toggled = boolean(values[0]), let applied = boolean(values[1]),
                  let finalApplied = boolean(values[2]) else {return nil}
            return .init(id:id,toggled:toggled,applied:applied,finalApplied:finalApplied)
        } ?? []
        let plugs = grouped(fields, owner: plugOwner,
                            names: ["nowPlug", "isInitPlug"],
                            listPrefix: controlPrefix, objectTail: "/29a21e52.1bd539fc") {id, values -> RE2MechanismProgress.Plug? in
            guard let code = integer(values[0],type:1), let initialized = boolean(values[1]) else {return nil}
            return .init(id:id,plugCode:code,initialized:initialized)
        } ?? []
        let clockFields = fields.filter {$0.owner == clockOwner}
        var clockGear: RE2MechanismProgress.ClockGear?
        if !clockFields.isEmpty {
            let parent = "/7f9decbe.8aab887b[23]/8413308a.c81a3eff[83]/a288cd46.1bd539fc"
            func one(_ name: String, type: Int32, size: Int) -> SaveScalar? {
                let hash = SaveCrypto.murmur(Data(name.utf8))
                let matches = clockFields.filter {$0.field == hash}
                guard matches.count == 1, let value = matches.first,
                      value.type == type, value.size == size,
                      value.path == parent + String(format:"/%08x.%08x",clockOwner,hash) else {return nil}
                return value
            }
            let firstHash = SaveCrypto.murmur(Data("isFirst".utf8))
            let first = clockFields.filter {$0.field == firstHash}
            if let top = one("nowTop",type:1,size:4), let bottom = one("nowBottom",type:1,size:4),
               let initField = one("isInitGear",type:2,size:1),
               let topCode = integer(top,type:1), let bottomCode = integer(bottom,type:1),
               let initialized = boolean(initField), first.count == 4 {
                let flags = (0..<4).map {index -> Bool? in
                    let path = parent + String(format:"/%08x.%08x[%d]",clockOwner,firstHash,index)
                    let matches = first.filter {$0.path == path}
                    guard matches.count == 1, let field = matches.first else {return nil}
                    return boolean(field)
                }
                if flags.allSatisfy({$0 != nil}) {
                    clockGear = .init(topCode:topCode,bottomCode:bottomCode,
                                      initialized:initialized,firstFlags:flags.compactMap {$0})
                }
            }
        }
        guard !switches.isEmpty || !plugs.isEmpty || clockGear != nil else {return nil}
        return .init(switches:switches,plugs:plugs,clockGear:clockGear)
    }

    private static func grouped<Row: Identifiable>(_ fields: [SaveScalar], owner: UInt32,
                                                   names: [String], listPrefix: String,
                                                   objectTail: String,
                                                   make: (Int,[SaveScalar]) -> Row?) -> [Row]? {
        let hashes = names.map {SaveCrypto.murmur(Data($0.utf8))}
        let selected = fields.filter {$0.owner == owner && hashes.contains($0.field)}
        guard !selected.isEmpty, selected.count <= 3_072,
              selected.count.isMultiple(of:names.count) else {return nil}
        let groups = Dictionary(grouping:selected) {field -> String in
            guard let slash = field.path.lastIndex(of:"/") else {return ""}
            return String(field.path[..<slash])
        }
        guard groups.count * names.count == selected.count else {return nil}
        var rows: [(Int,Row)] = []
        for (parent,siblings) in groups {
            let rest = parent.dropFirst(listPrefix.count)
            guard parent.hasPrefix(listPrefix), parent.hasSuffix(objectTail),
                  let end = rest.firstIndex(of:"]"),
                  String(rest[end...]) == "]" + objectTail,
                  let index = Int(rest[..<end]),
                  (0..<1_024).contains(index), siblings.count == names.count else {return nil}
            let values = hashes.compactMap {hash -> SaveScalar? in
                let matches = siblings.filter {$0.field == hash}
                guard matches.count == 1, let value = matches.first,
                      value.path == parent + String(format:"/%08x.%08x",owner,hash) else {return nil}
                return value
            }
            guard values.count == names.count, let row = make(index,values) else {return nil}
            rows.append((index,row))
        }
        rows.sort {$0.0 < $1.0}
        guard Set(rows.map(\.0)).count == rows.count else {return nil}
        return rows.map(\.1)
    }

    private static func boolean(_ field: SaveScalar) -> Bool? {
        guard field.type == 2, field.size == 1 else {return nil}
        switch field.text {case "true":return true;case "false":return false;default:return nil}
    }
    private static func integer(_ field: SaveScalar, type: Int32) -> Int? {
        guard field.type == type, field.size == 4 else {return nil}
        return Int(field.text)
    }
}
