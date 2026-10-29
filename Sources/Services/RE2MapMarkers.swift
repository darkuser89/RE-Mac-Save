import Foundation

struct RE2MapMarkerGroup: Identifiable {
    struct Marker: Identifiable {
        let id: Int
        let objectHash: UInt32
        let mapID: Int
        let slotNumber: UInt32?
    }
    let id: String
    let title: String
    let markers: [Marker]
}

enum RE2MapMarkerCatalog {
    private struct Spec {
        let id: String
        let title: String
        let owner: UInt32
        let prefix: String
        let hasSlot: Bool
    }
    private static let specs = [
        Spec(id:"itemLockerData",title:"Itemschränke auf der Karte",
             owner:SaveCrypto.murmur(Data("app.ropeway.gamemastering.UIMapManager.ItemLockerInfo".utf8)),
             prefix:"/7f9decbe.8aab887b[8]/090ff53c.00c7b7b6/b2f815e5.695a3627[",hasSlot:true),
        Spec(id:"gimmickData",title:"Mechanikobjekte auf der Karte",
             owner:SaveCrypto.murmur(Data("app.ropeway.gamemastering.UIMapManager.GimmickInfo".utf8)),
             prefix:"/7f9decbe.8aab887b[8]/090ff53c.0031712c/f4f012fc.695a3627[",hasSlot:false),
        Spec(id:"typewriterData",title:"Schreibmaschinen auf der Karte",
             owner:SaveCrypto.murmur(Data("app.ropeway.gamemastering.UIMapManager.TypewriterInfo".utf8)),
             prefix:"/7f9decbe.8aab887b[8]/090ff53c.d1a4c8f8/dd9eb20d.695a3627[",hasSlot:false)
    ]
    private static let hashField = SaveCrypto.murmur(Data("_Hash".utf8))
    private static let mapField = SaveCrypto.murmur(Data("_MapId".utf8))
    private static let slotField = SaveCrypto.murmur(Data("_SlotNum".utf8))

    static func groups(game:GameProfile,source:SaveFile,fields:[SaveScalar],character:String?) -> [RE2MapMarkerGroup] {
        guard game.id=="re2",character != nil,
              ["data000.bin","data001Slot.bin","data002Slot.bin"].contains(source.url.lastPathComponent) else {return []}
        return specs.compactMap {spec in
            let required=spec.hasSlot ? Set([hashField,mapField,slotField]) : Set([hashField,mapField])
            let selected=fields.filter {$0.owner==spec.owner && required.contains($0.field) && $0.path.hasPrefix(spec.prefix)}
            guard !selected.isEmpty,selected.count<=384,selected.count.isMultiple(of:required.count) else {return nil}
            let byParent=Dictionary(grouping:selected) {field -> String in
                guard let slash=field.path.lastIndex(of:"/") else {return ""}
                return String(field.path[..<slash])
            }
            guard byParent.count*required.count==selected.count else {return nil}
            var markers:[RE2MapMarkerGroup.Marker]=[]
            for (parent,siblings) in byParent {
                guard parent.hasPrefix(spec.prefix),parent.hasSuffix("]"),siblings.count==required.count,
                      let index=Int(parent.dropFirst(spec.prefix.count).dropLast()),(0..<128).contains(index),
                      let hash=one(hashField,type:8,owner:spec.owner,siblings:siblings,parent:parent).flatMap({UInt32($0.text)}),
                      let map=one(mapField,type:1,owner:spec.owner,siblings:siblings,parent:parent).flatMap({Int($0.text)}),
                      (0...10_000).contains(map) else {return nil}
                let slot:UInt32?
                if spec.hasSlot {
                    guard let value=one(slotField,type:8,owner:spec.owner,siblings:siblings,parent:parent).flatMap({UInt32($0.text)}) else {return nil}
                    slot=value
                } else {slot=nil}
                markers.append(.init(id:index,objectHash:hash,mapID:map,slotNumber:slot))
            }
            markers.sort {$0.id<$1.id}
            guard markers.count==byParent.count,
                  markers.enumerated().allSatisfy({$0.offset==$0.element.id}),
                  Set(markers.map(\.objectHash)).count==markers.count else {return nil}
            return RE2MapMarkerGroup(id:spec.id,title:spec.title,markers:markers)
        }
    }

    private static func one(_ hash:UInt32,type:Int32,owner:UInt32,siblings:[SaveScalar],parent:String) -> SaveScalar? {
        let matches=siblings.filter {$0.field==hash}
        guard matches.count==1,let field=matches.first,field.type==type,field.size==4,
              field.path==parent+String(format:"/%08x.%08x",owner,hash) else {return nil}
        return field
    }
}
