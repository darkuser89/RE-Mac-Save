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
    struct PlugFirst: Identifiable {
        let id: Int
        let flags: [Bool]
    }
    struct ClockGear {
        let topCode: Int
        let bottomCode: Int
        let initialized: Bool
        let firstFlags: [Bool]
    }
    struct AutoDoor: Identifiable {
        let id: Int
        let opened: Bool
    }
    struct WiringNode: Identifiable {
        let id: Int
        let motorBroken: Bool
        let switchedIndex: Int
    }
    struct Elevator: Identifiable {
        let id: Int
        let currentIndex: Int
    }
    struct BookShelf: Identifiable {
        let id: Int
        let initialized: Bool
        let positions: [Int]
        let locked: [Bool]
    }
    struct Movable: Identifiable {
        let id: Int
        let moved: Bool
    }
    struct Fan: Identifiable {
        let id: Int
        let broken: Bool
    }
    struct ObjectFlag: Identifiable {
        let id: Int
        let value: Bool
    }
    struct ObjectCode: Identifiable {
        let id: Int
        let code: Int
    }
    struct PlugGate: Identifiable {
        let id: Int
        let inserted: Int
        let ejected: Int
    }
    let switches: [Switch]
    let plugs: [Plug]
    let clockGear: ClockGear?
    let autoDoors: [AutoDoor]
    let wiringNodes: [WiringNode]
    let elevators: [Elevator]
    let bookShelves: [BookShelf]
    let movables: [Movable]
    let fans: [Fan]
    let plugFirstFlags: [PlugFirst]
    let rigidBodies: [ObjectCode]
    let plugGates: [PlugGate]
    let laboratoryBulkheads: [ObjectFlag]
    let g2Shutters: [ObjectFlag]
    let topboards: [ObjectFlag]
}

enum RE2MechanismProgressCatalog {
    private static let switchOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickToggleSwitch.SaveData".utf8))
    private static let plugOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickPlugPlaceControl.SaveData".utf8))
    private static let clockOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickClockGearControl.SaveData".utf8))
    private static let autoDoorOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickAutoDoor.SaveData".utf8))
    private static let wiringOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickWiringNodeBase.SaveData".utf8))
    private static let elevatorOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickElevator.SaveData".utf8))
    private static let bookShelfOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickMobileBookShelf.SaveData".utf8))
    private static let movableOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickRigidBodySavable.SaveData".utf8))
    private static let fanOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickFanForOvercurrent.SaveData".utf8))
    private static let rigidBodyOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickRigidbody.SaveData".utf8))
    private static let plugGateOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickPlugGateControl.SaveData".utf8))
    private static let bulkheadOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickLaboratoryBulkhead.SaveData".utf8))
    private static let g2ShutterOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickShutterG2Break.SaveData".utf8))
    private static let topboardOwner = SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickTopboard.SaveData".utf8))
    private static let bodyPrefix = "/7f9decbe.8aab887b[23]/8413308a.34be46bd["
    private static let controlPrefix = "/7f9decbe.8aab887b[23]/8413308a.c81a3eff["
    private static let movablePrefix = "/7f9decbe.8aab887b[23]/8413308a.59a3dafc["

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
        let plugFirstFlags = indexedFlags(fields,owner:plugOwner,name:"isFirst",count:6,
                                          listPrefix:controlPrefix,objectTail:"/29a21e52.1bd539fc") ?? []
        let autoDoors = grouped(fields, owner: autoDoorOwner,
                                names: ["HasOpened"],
                                listPrefix: bodyPrefix, objectTail: "/80e2f7c5.1bd539fc") {id, values -> RE2MechanismProgress.AutoDoor? in
            guard let opened = boolean(values[0]) else {return nil}
            return .init(id:id,opened:opened)
        } ?? []
        let wiringNodes = grouped(fields, owner: wiringOwner,
                                  names: ["HasBrokenMotor", "SwitchedIndex"],
                                  listPrefix: bodyPrefix, objectTail: "/9847e6b3.1bd539fc") {id, values -> RE2MechanismProgress.WiringNode? in
            guard let broken = boolean(values[0]), let index = integer(values[1],type:7) else {return nil}
            return .init(id:id,motorBroken:broken,switchedIndex:index)
        } ?? []
        let elevators = grouped(fields, owner: elevatorOwner,
                                names: ["CurIndex"],
                                listPrefix: bodyPrefix, objectTail: "/73c3755b.1bd539fc") {id, values -> RE2MechanismProgress.Elevator? in
            guard let index = integer(values[0],type:7) else {return nil}
            return .init(id:id,currentIndex:index)
        } ?? []
        let bookShelves = shelves(fields) ?? []
        let movables = grouped(fields, owner: movableOwner,
                               names: ["HasMoved"],
                               listPrefix: movablePrefix, objectTail: "/fa8abf85.1bd539fc") {id, values -> RE2MechanismProgress.Movable? in
            guard let moved = boolean(values[0]) else {return nil}
            return .init(id:id,moved:moved)
        } ?? []
        let fans = grouped(fields, owner: fanOwner,
                           names: ["HasBroken"],
                           listPrefix: bodyPrefix, objectTail: "/b843da90.1bd539fc") {id, values -> RE2MechanismProgress.Fan? in
            guard let broken = boolean(values[0]) else {return nil}
            return .init(id:id,broken:broken)
        } ?? []
        let rigidBodies = grouped(fields,owner:rigidBodyOwner,names:["Status"],
                                  listPrefix:bodyPrefix,objectTail:"/22a089f8.1bd539fc") {id,values -> RE2MechanismProgress.ObjectCode? in
            guard let code=integer(values[0],type:7) else {return nil}
            return .init(id:id,code:code)
        } ?? []
        let plugGates = grouped(fields,owner:plugGateOwner,names:["InsertCount","EjectCount"],
                                listPrefix:controlPrefix,objectTail:"/1e149e87.1bd539fc") {id,values -> RE2MechanismProgress.PlugGate? in
            guard let inserted=integer(values[0],type:7),let ejected=integer(values[1],type:7) else {return nil}
            return .init(id:id,inserted:inserted,ejected:ejected)
        } ?? []
        let laboratoryBulkheads = grouped(fields,owner:bulkheadOwner,names:["HasOpened"],
                                          listPrefix:bodyPrefix,objectTail:"/f57f51a6.1bd539fc") {id,values -> RE2MechanismProgress.ObjectFlag? in
            guard let value=boolean(values[0]) else {return nil}
            return .init(id:id,value:value)
        } ?? []
        let g2Shutters = grouped(fields,owner:g2ShutterOwner,names:["IsBreak"],
                                 listPrefix:movablePrefix,objectTail:"/6f269a41.1bd539fc") {id,values -> RE2MechanismProgress.ObjectFlag? in
            guard let value=boolean(values[0]) else {return nil}
            return .init(id:id,value:value)
        } ?? []
        let topboards = grouped(fields,owner:topboardOwner,names:["IsFall"],
                                listPrefix:movablePrefix,objectTail:"/3cdf6985.1bd539fc") {id,values -> RE2MechanismProgress.ObjectFlag? in
            guard let value=boolean(values[0]) else {return nil}
            return .init(id:id,value:value)
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
        guard !switches.isEmpty || !plugs.isEmpty || clockGear != nil ||
              !autoDoors.isEmpty || !wiringNodes.isEmpty || !elevators.isEmpty ||
              !bookShelves.isEmpty || !movables.isEmpty || !fans.isEmpty ||
              !plugFirstFlags.isEmpty || !rigidBodies.isEmpty || !plugGates.isEmpty ||
              !laboratoryBulkheads.isEmpty || !g2Shutters.isEmpty || !topboards.isEmpty else {return nil}
        return .init(switches:switches,plugs:plugs,clockGear:clockGear,
                     autoDoors:autoDoors,wiringNodes:wiringNodes,elevators:elevators,
                     bookShelves:bookShelves,movables:movables,fans:fans,
                     plugFirstFlags:plugFirstFlags,rigidBodies:rigidBodies,plugGates:plugGates,
                     laboratoryBulkheads:laboratoryBulkheads,g2Shutters:g2Shutters,topboards:topboards)
    }

    private static func indexedFlags(_ fields:[SaveScalar],owner:UInt32,name:String,count:Int,
                                     listPrefix:String,objectTail:String) -> [RE2MechanismProgress.PlugFirst]? {
        let hash=SaveCrypto.murmur(Data(name.utf8))
        let selected=fields.filter {$0.owner==owner && $0.field==hash}
        guard !selected.isEmpty,selected.count<=6_144,selected.count.isMultiple(of:count) else {return nil}
        let groups=Dictionary(grouping:selected) {field -> String in
            guard let slash=field.path.lastIndex(of:"/") else {return ""}
            return String(field.path[..<slash])
        }
        guard groups.count*count==selected.count else {return nil}
        var rows:[RE2MechanismProgress.PlugFirst]=[]
        for (parent,siblings) in groups {
            guard parent.hasPrefix(listPrefix),parent.hasSuffix(objectTail),siblings.count==count else {return nil}
            let rest=parent.dropFirst(listPrefix.count)
            guard let end=rest.firstIndex(of:"]"),String(rest[end...])=="]"+objectTail,
                  let id=Int(rest[..<end]),(0..<1_024).contains(id) else {return nil}
            var flags:[Bool]=[]
            for index in 0..<count {
                let path=parent+String(format:"/%08x.%08x[%d]",owner,hash,index)
                let matches=siblings.filter {$0.path==path}
                guard matches.count==1,let value=boolean(matches[0]) else {return nil}
                flags.append(value)
            }
            rows.append(.init(id:id,flags:flags))
        }
        rows.sort {$0.id<$1.id}
        guard Set(rows.map(\.id)).count==rows.count else {return nil}
        return rows
    }

    private static func shelves(_ fields: [SaveScalar]) -> [RE2MechanismProgress.BookShelf]? {
        let initHash = SaveCrypto.murmur(Data("isInit".utf8))
        let positionHash = SaveCrypto.murmur(Data("PosNum".utf8))
        let lockHash = SaveCrypto.murmur(Data("isLock".utf8))
        let selected = fields.filter {$0.owner == bookShelfOwner &&
            [initHash,positionHash,lockHash].contains($0.field)}
        guard !selected.isEmpty, selected.count <= 9_216 else {return nil}
        let groups = Dictionary(grouping:selected) {field -> String in
            guard let slash = field.path.lastIndex(of:"/") else {return ""}
            return String(field.path[..<slash])
        }
        guard groups.count * 9 == selected.count else {return nil}
        var rows: [RE2MechanismProgress.BookShelf] = []
        for (parent,siblings) in groups {
            let tail = "/9aa81c3c.1bd539fc"
            guard parent.hasPrefix(bodyPrefix), parent.hasSuffix(tail), siblings.count == 9 else {return nil}
            let rest = parent.dropFirst(bodyPrefix.count)
            guard let end = rest.firstIndex(of:"]"), String(rest[end...]) == "]"+tail,
                  let id = Int(rest[..<end]), (0..<1_024).contains(id) else {return nil}
            func one(_ hash: UInt32,_ index: Int? = nil) -> SaveScalar? {
                let suffix = String(format:"/%08x.%08x",bookShelfOwner,hash) +
                    (index.map {"[\($0)]"} ?? "")
                let matches = siblings.filter {$0.field == hash && $0.path == parent+suffix}
                return matches.count == 1 ? matches[0]:nil
            }
            guard let initField = one(initHash), let initialized = boolean(initField) else {return nil}
            let positions = (0..<4).map {index -> Int? in
                guard let field = one(positionHash,index) else {return nil}
                return integer(field,type:7)
            }
            let locks = (0..<4).map {index -> Bool? in
                guard let field = one(lockHash,index) else {return nil}
                return boolean(field)
            }
            guard positions.allSatisfy({$0 != nil}), locks.allSatisfy({$0 != nil}) else {return nil}
            rows.append(.init(id:id,initialized:initialized,
                              positions:positions.compactMap {$0},locked:locks.compactMap {$0}))
        }
        rows.sort {$0.id < $1.id}
        guard Set(rows.map(\.id)).count == rows.count else {return nil}
        return rows
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
