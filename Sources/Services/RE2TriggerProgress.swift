import Foundation

struct RE2TriggerProgress {
    struct Entry: Identifiable {
        let id: Int
        let key: UInt32
        let done: Bool
        let usedFlags: [Bool]
    }
    struct Group: Identifiable {
        let id: String
        let listIndex: Int
        let listKind: String
        let entries: [Entry]
        var completedCount: Int {entries.filter(\.done).count}
        var usedCount: Int {entries.reduce(0) {$0 + $1.usedFlags.filter {$0}.count}}
    }
    let triggers: [Group]
    let itemTriggers: [Group]
}

enum RE2TriggerProgressCatalog {
    private static let triggerOwner=SaveCrypto.murmur(Data("app.ropeway.gimmick.action.TriggerSaveData".utf8))
    private static let itemOwner=SaveCrypto.murmur(Data("app.ropeway.gimmick.action.TriggerSaveDataUseItem".utf8))
    private static let keyHash=SaveCrypto.murmur(Data("Key".utf8))
    private static let doneHash=SaveCrypto.murmur(Data("DoneSucceed".utf8))
    private static let usedHash=SaveCrypto.murmur(Data("HasUsed".utf8))
    private static let listPrefix="/7f9decbe.8aab887b[23]/8413308a.c81a3eff["
    private static let listKinds=["b145081f","5a30060b","1e149e87"]

    static func details(game:GameProfile,source:SaveFile,fields:[SaveScalar],character:String?) -> RE2TriggerProgress? {
        guard game.id=="re2",character != nil,
              ["data000.bin","data001Slot.bin","data002Slot.bin"].contains(source.url.lastPathComponent) else {return nil}
        let triggers=groups(fields,owner:triggerOwner) ?? []
        let itemTriggers=groups(fields,owner:itemOwner) ?? []
        guard !triggers.isEmpty || !itemTriggers.isEmpty else {return nil}
        return .init(triggers:triggers,itemTriggers:itemTriggers)
    }

    private static func groups(_ fields:[SaveScalar],owner:UInt32) -> [RE2TriggerProgress.Group]? {
        let selected=fields.filter {$0.owner==owner && [keyHash,doneHash,usedHash].contains($0.field)}
        guard !selected.isEmpty,selected.count<=16_384 else {return nil}
        let parents=Dictionary(grouping:selected) {field -> String in
            guard let slash=field.path.lastIndex(of:"/") else {return ""}
            return String(field.path[..<slash])
        }
        var result:[String:[RE2TriggerProgress.Entry]]=[:]
        var groupInfo:[String:(Int,String)]=[:]
        var seen:Set<String>=[]
        for (parent,siblings) in parents {
            guard parent.hasPrefix(listPrefix) else {return nil}
            let rest=parent.dropFirst(listPrefix.count)
            guard let outerEnd=rest.firstIndex(of:"]"),let groupID=Int(rest[..<outerEnd]),
                  (0..<10_000).contains(groupID) else {return nil}
            let tail=String(rest[rest.index(after:outerEnd)...])
            guard let listKind=listKinds.first(where:{tail.hasPrefix("/\($0).51b3dc27[")}) else {return nil}
            let entryPrefix="/\(listKind).51b3dc27["
            guard tail.hasSuffix("]"),
                  let entryID=Int(tail.dropFirst(entryPrefix.count).dropLast()),
                  (0..<10_000).contains(entryID) else {return nil}
            let identity="\(groupID):\(listKind):\(entryID)"
            guard seen.insert(identity).inserted else {return nil}
            func one(_ hash:UInt32,type:Int32,size:Int) -> SaveScalar? {
                let path=parent+String(format:"/%08x.%08x",owner,hash)
                let matches=siblings.filter {$0.field==hash && $0.path==path}
                guard matches.count==1,matches[0].type==type,matches[0].size==size else {return nil}
                return matches[0]
            }
            guard let keyField=one(keyHash,type:8,size:4),let key=UInt32(keyField.text),
                  let doneField=one(doneHash,type:2,size:1),
                  let done=boolean(doneField) else {return nil}
            let usedFields=siblings.filter {$0.field==usedHash}
            guard usedFields.count<=256 else {return nil}
            var used:[Bool]=[]
            for index in 0..<usedFields.count {
                let path=parent+String(format:"/%08x.%08x[%d]",owner,usedHash,index)
                let matches=usedFields.filter {$0.path==path}
                guard matches.count==1,let flag=boolean(matches[0]) else {return nil}
                used.append(flag)
            }
            guard siblings.count==2+used.count else {return nil}
            let groupKey="\(groupID):\(listKind)"
            groupInfo[groupKey]=(groupID,listKind)
            result[groupKey,default:[]].append(.init(id:entryID,key:key,done:done,usedFlags:used))
        }
        return result.keys.sorted(by:{a,b in
            guard let left=groupInfo[a],let right=groupInfo[b] else {return a<b}
            return left.0 == right.0 ? left.1 < right.1 : left.0 < right.0
        }).compactMap {groupKey in
            guard var entries=result[groupKey],let info=groupInfo[groupKey] else {return nil}
            entries.sort {$0.id<$1.id}
            return .init(id:groupKey,listIndex:info.0,listKind:info.1,entries:entries)
        }
    }

    private static func boolean(_ field:SaveScalar) -> Bool? {
        guard field.type==2,field.size==1 else {return nil}
        switch field.text {case "true":return true;case "false":return false;default:return nil}
    }
}
