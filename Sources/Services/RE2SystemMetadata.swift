import Foundation

struct RE2SystemMetadata: Identifiable {
    let id: String
    let title: String
    let value: String
    let path: String
}

enum RE2SystemMetadataCatalog {
    private struct Spec {
        let owner: UInt32
        let name: String
        let title: String
        let type: Int32
        let size: Int
    }

    private static let systemRoot = "/9e0932a9.9074a186"
    private static let recordOwner = SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8))
    private static let clockOwner = SaveCrypto.murmur(Data("app.ropeway.GameClock.SystemSaveData".utf8))
    private static let specs = [
        Spec(owner:0x4683bfe1,name:"LastSaveSlotId",title:"Zuletzt gespeicherte Slot-ID",type:7,size:4),
        Spec(owner:0x4683bfe1,name:"LastSavedTimeTicks",title:"Letzter Speicherzeitwert (roh)",type:9,size:8),
        Spec(owner:recordOwner,name:"LatestGameId",title:"Interne letzte Spiel-ID",type:8,size:4),
        Spec(owner:recordOwner,name:"IsFirstPlayLeon",title:"Leon-Erstspiel-Flag (roh)",type:2,size:1),
        Spec(owner:recordOwner,name:"IsClearedGameImmediately",title:"Sofortabschluss-Flag (roh)",type:2,size:1),
        Spec(owner:clockOwner,name:"_SystemElapsedTime",title:"System-Spielzeitwert (roh)",type:10,size:8),
        Spec(owner:recordOwner,name:"IsCheckedNewMark_NewGamePlus",title:"Neumarkierung Neues Spiel+ geprüft (roh)",type:2,size:1),
        Spec(owner:recordOwner,name:"IsOpenedPopUp_ExtraContentsNotice",title:"Hinweis zu Extra-Inhalten geöffnet (roh)",type:2,size:1),
        Spec(owner:recordOwner,name:"IsOpenedPopUp_TofuCharacter",title:"Tofu-Figurenhinweis geöffnet (roh)",type:2,size:1),
        Spec(owner:recordOwner,name:"IsOpenedPopUp_Weapon",title:"Waffenhinweis geöffnet (roh)",type:2,size:1),
        Spec(owner:recordOwner,name:"The4thClearPlayTime",title:"Vierter-Überlebender-Abschlusszeitwert (roh)",type:10,size:8),
        Spec(owner:recordOwner,name:"IsCheckedNewMark_ClearState",title:"Neumarkierung Abschlüsse geprüft (roh)",type:2,size:1),
        Spec(owner:recordOwner,name:"IsCheckedNewMark_Extra",title:"Neumarkierung Extras geprüft (roh)",type:2,size:1),
        Spec(owner:recordOwner,name:"HuntedTreasureOfRecord059",title:"Interner Rekord-059-Wert (roh)",type:8,size:4),
        Spec(owner:recordOwner,name:"IsOpenedPopUp_NewGamePlus",title:"Neues-Spiel+-Hinweis geöffnet (roh)",type:2,size:1)
    ]

    static func entries(game:GameProfile,source:SaveFile,fields:[SaveScalar]) -> [RE2SystemMetadata] {
        guard game.id=="re2",source.url.lastPathComponent=="data00-1.bin" else {return []}
        return specs.compactMap {spec in
            let hash=SaveCrypto.murmur(Data(spec.name.utf8))
            let matches=fields.filter {$0.owner==spec.owner && $0.field==hash}
            let rootIndex=spec.owner==0x4683bfe1 ? 2 : (spec.owner==recordOwner ? 7 : 0)
            let expectedPath=String(format:"%@[%d]/%08x.%08x",systemRoot,rootIndex,spec.owner,hash)
            guard matches.count==1,let field=matches.first,
                  field.type==spec.type,field.size==spec.size,
                  field.path==expectedPath else {return nil}
            if spec.type==2 {
                guard field.text=="true" || field.text=="false" else {return nil}
            } else {
                guard UInt64(field.text) != nil else {return nil}
            }
            return RE2SystemMetadata(id:spec.name,title:spec.title,value:field.text,path:field.path)
        }
    }
}
