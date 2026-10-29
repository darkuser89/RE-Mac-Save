import Foundation

struct RE2MapPart: Identifiable {
    let id: Int
    let stateCode: Int
    let done: Bool
}

enum RE2MapPartCatalog {
    private static let owner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.UIMapManager.MapPartsChangeInfo".utf8))
    private static let state=SaveCrypto.murmur(Data("State".utf8))
    private static let done=SaveCrypto.murmur(Data("Done".utf8))
    private static let prefix="/7f9decbe.8aab887b[8]/090ff53c.d584af3a/0e13127e.ef5095c4["

    static func entries(game:GameProfile,source:SaveFile,fields:[SaveScalar],character:String?) -> [RE2MapPart] {
        guard game.id=="re2",character != nil,
              ["data000.bin","data001Slot.bin","data002Slot.bin"].contains(source.url.lastPathComponent) else {return []}
        let selected=fields.filter {$0.owner==owner && ($0.field==state || $0.field==done)}
        guard selected.count==128 else {return []}
        let grouped=Dictionary(grouping:selected) {field -> String in
            guard let slash=field.path.lastIndex(of:"/") else {return ""}
            return String(field.path[..<slash])
        }
        guard grouped.count==64 else {return []}
        var rows:[RE2MapPart]=[]
        for (parent,siblings) in grouped {
            guard parent.hasPrefix(prefix),parent.hasSuffix("]"),siblings.count==2,
                  let index=Int(parent.dropFirst(prefix.count).dropLast()),(0..<64).contains(index),
                  let stateField=one(state,type:1,size:4,siblings:siblings,parent:parent),
                  let doneField=one(done,type:2,size:1,siblings:siblings,parent:parent),
                  let stateCode=Int(stateField.text),(0...255).contains(stateCode),
                  doneField.text=="true" || doneField.text=="false" else {return []}
            rows.append(.init(id:index,stateCode:stateCode,done:doneField.text=="true"))
        }
        rows.sort {$0.id<$1.id}
        guard rows.enumerated().allSatisfy({$0.offset==$0.element.id}) else {return []}
        return rows
    }

    private static func one(_ fieldHash:UInt32,type:Int32,size:Int,siblings:[SaveScalar],parent:String) -> SaveScalar? {
        let matches=siblings.filter {$0.field==fieldHash}
        guard matches.count==1,let field=matches.first,field.type==type,field.size==size,
              field.path==parent+String(format:"/%08x.%08x",owner,fieldHash) else {return nil}
        return field
    }
}
