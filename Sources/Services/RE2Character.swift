import Foundation

enum RE2Character {
    private static let headerOwner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.MainFlowManager.GameHeaderSaveData".utf8))
    private static let headerName=SaveCrypto.murmur(Data("SurvivorTypeValue".utf8))
    private static let playerOwner=SaveCrypto.murmur(Data("app.ropeway.PlayerManager.GameSaveData".utf8))
    private static let playerName=SaveCrypto.murmur(Data("PlayerType".utf8))
    private static let detailOwner=SaveCrypto.murmur(Data("via.storage.saveService.SaveFileDetail".utf8))
    private static let subtitleName=SaveCrypto.murmur(Data("SubTitle".utf8))

    static func name(fields:[SaveScalar]) -> String? {
        func one(_ owner:UInt32,_ name:UInt32,_ type:Int32,_ size:Int?=nil) -> SaveScalar? {
            let matches=fields.filter{$0.owner==owner && $0.field==name && $0.type==type && (size==nil || $0.size==size)}
            return matches.count==1 ? matches[0]:nil
        }
        guard let header=one(headerOwner,headerName,1,4),
              let player=one(playerOwner,playerName,1,4) else {return nil}
        let character:String
        switch (header.text,player.text) {
        case ("0","0"):character="Leon"
        case ("1","1000"):character="Claire"
        default:return nil
        }
        if let subtitle=one(detailOwner,subtitleName,15),
           !subtitle.text.localizedCaseInsensitiveContains(character) {return nil}
        return character
    }

    static func read(file:SaveFile,game:GameProfile) -> String? {
        guard game.id=="re2",file.kind=="DSSS",LocalSavePolicy.permitsFile(file.url,game:game) else {return nil}
        guard let data=try? Data(contentsOf:file.url),
              let key=try? SaveKeys.key(for:game),
              let container=try? SaveContainer(data:data,key:key),
              let parsed=try? ParsedSave(payload:container.payload),
              parsed.consumed==container.payload.count else {return nil}
        return name(fields:parsed.fields)
    }
}
