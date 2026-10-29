import Foundation

struct RE2SaveHeader {
    let title:String?
    let subtitle:String?
    let scenarioCode:Int
    let areaID:Int
    let locationID:Int
    let gameID:UInt32?
}

enum RE2SaveHeaderCatalog {
    private static let headerOwner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.MainFlowManager.GameHeaderSaveData".utf8))
    private static let detailOwner=SaveCrypto.murmur(Data("via.storage.saveService.SaveFileDetail".utf8))

    static func details(game:GameProfile,fields:[SaveScalar],character:String?) -> RE2SaveHeader? {
        guard game.id=="re2",character != nil else {return nil}
        func one(_ owner:UInt32,_ name:String,_ type:Int32,_ size:Int?=nil) -> SaveScalar? {
            let hash=SaveCrypto.murmur(Data(name.utf8))
            let matches=fields.filter{$0.owner==owner && $0.field==hash && $0.type==type && (size==nil || $0.size==size)}
            return matches.count==1 ? matches[0]:nil
        }
        guard let scenario=one(headerOwner,"ScenarioTypeValue",1,4).flatMap({Int($0.text)}),
              let area=one(headerOwner,"AreaId",1,4).flatMap({Int($0.text)}),
              let location=one(headerOwner,"LocationId",1,4).flatMap({Int($0.text)}),
              scenario>=0,area>=0,location>=0 else {return nil}
        let gameID=one(headerOwner,"GameId",8,4).flatMap({UInt32($0.text)})
        return RE2SaveHeader(title:displayText(one(detailOwner,"Title",15)?.text),
                             subtitle:displayText(one(detailOwner,"SubTitle",15)?.text),
                             scenarioCode:scenario,areaID:area,locationID:location,gameID:gameID)
    }

    private static func displayText(_ text:String?) -> String? {
        guard let text, !text.isEmpty, text.utf16.count<=120,
              !text.unicodeScalars.contains(where:{$0.properties.generalCategory == .control}) else {return nil}
        return text
    }
}
