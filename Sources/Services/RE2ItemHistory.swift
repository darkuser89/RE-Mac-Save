import Foundation

struct RE2ItemHistory: Identifiable {
    struct Entry: Identifiable {
        let id:Int
        let name:String
    }
    let id:String
    let title:String
    let total:Int
    let recorded:[Entry]
}

enum RE2ItemHistoryCatalog {
    private struct Spec {
        let owner:String
        let field:String
        let count:Int
        let title:String
        let isWeapon:Bool
    }
    private static let systemSpecs=[
        Spec(owner:"app.ropeway.gamemastering.ItemManager.SystemSaveData",field:"GetItemList",count:297,title:"Als erhalten markierte Gegenstände",isWeapon:false),
        Spec(owner:"app.ropeway.gamemastering.ItemManager.SystemSaveData",field:"GetWeaponList",count:383,title:"Als erhalten markierte Waffen",isWeapon:true)
    ]
    private static let campaignSpecs=[
        Spec(owner:"app.ropeway.gamemastering.ItemManager.SaveData",field:"IsSearchedItem",count:297,title:"Als untersucht markierte Gegenstände",isWeapon:false),
        Spec(owner:"app.ropeway.gamemastering.InventoryManager.SaveData",field:"GetKeyItemEffect",count:297,title:"Gesetzte Gegenstands-Effektflags (GetKeyItemEffect)",isWeapon:false),
        Spec(owner:"app.ropeway.gamemastering.InventoryManager.SaveData",field:"GetKeyWeaponEffect",count:383,title:"Gesetzte Waffen-Effektflags (GetKeyWeaponEffect)",isWeapon:true),
        Spec(owner:"app.ropeway.gamemastering.InventoryManager.SaveData",field:"IsCustomWeaponEffect",count:383,title:"Waffen mit IsCustomWeaponEffect-Flag",isWeapon:true),
        Spec(owner:"app.ropeway.gamemastering.InventoryManager.SaveData",field:"IsAddRankItem",count:297,title:"Gegenstände mit IsAddRankItem-Flag",isWeapon:false)
    ]

    static func lists(game:GameProfile,source:SaveFile,fields:[SaveScalar],names:ItemNameCatalog?=ItemNameCatalog.bundled) -> [RE2ItemHistory] {
        guard game.id=="re2" else {return []}
        let specs=source.url.lastPathComponent=="data00-1.bin" ? systemSpecs:campaignSpecs
        return specs.compactMap {spec in
            let owner=SaveCrypto.murmur(Data(spec.owner.utf8))
            let field=SaveCrypto.murmur(Data(spec.field.utf8))
            let matches=fields.filter{$0.owner==owner && $0.field==field}
            guard matches.count==spec.count else {return nil}
            var indexed:[Int:SaveScalar]=[:]
            for scalar in matches {
                guard scalar.type==2,scalar.size==1,
                      scalar.text=="true" || scalar.text=="false",
                      let open=scalar.path.lastIndex(of:"["),scalar.path.last=="]",
                      let index=Int(scalar.path[scalar.path.index(after:open)..<scalar.path.index(before:scalar.path.endIndex)]),
                      (0..<spec.count).contains(index),indexed[index]==nil else {return nil}
                indexed[index]=scalar
            }
            guard indexed.count==spec.count else {return nil}
            let recorded=indexed.keys.sorted().compactMap {index -> RE2ItemHistory.Entry? in
                guard indexed[index]?.text=="true" else {return nil}
                let id=spec.isWeapon ? "Waffe \(index)":String(index)
                let name=names?.entry(gameID:"re2",itemID:id)?.name ?? "Unbekannte Kennung"
                return RE2ItemHistory.Entry(id:index,name:name)
            }
            return RE2ItemHistory(id:spec.field,title:spec.title,total:spec.count,recorded:recorded)
        }
    }
}
