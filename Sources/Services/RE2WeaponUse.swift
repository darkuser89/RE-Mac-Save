import Foundation

struct RE2WeaponUse:Identifiable {
    let id:Int
    let weaponID:Int
    let name:String
}

enum RE2WeaponUseCatalog {
    private static let owner=SaveCrypto.murmur(Data("app.ropeway.PlayerManager.GameSaveData".utf8))
    private static let field=SaveCrypto.murmur(Data("UseWeapons".utf8))

    static func entries(game:GameProfile,fields:[SaveScalar],character:String?,names:ItemNameCatalog?=ItemNameCatalog.bundled) -> [RE2WeaponUse] {
        guard game.id=="re2",character != nil else {return []}
        let matches=fields.filter{$0.owner==owner && $0.field==field}
        guard (1...64).contains(matches.count) else {return []}
        var byIndex:[Int:RE2WeaponUse]=[:]
        var parent:String?=nil
        for scalar in matches {
            guard scalar.type==1,scalar.size==4,
                  let weaponID=Int(scalar.text),(1...382).contains(weaponID),
                  let left=scalar.path.lastIndex(of:"["),scalar.path.last=="]",
                  let index=Int(scalar.path[scalar.path.index(after:left)..<scalar.path.index(before:scalar.path.endIndex)]),
                  (0..<matches.count).contains(index),byIndex[index]==nil,
                  let slash=scalar.path.lastIndex(of:"/") else {return []}
            let base=String(scalar.path[..<slash])
            if let parent,base != parent {return []}
            parent=base
            let name=names?.entry(gameID:"re2",itemID:"Waffe \(weaponID)")?.name ?? "Unbekannte Waffe"
            byIndex[index]=RE2WeaponUse(id:index,weaponID:weaponID,name:name)
        }
        guard byIndex.count==matches.count else {return []}
        return (0..<matches.count).compactMap{byIndex[$0]}
    }
}
