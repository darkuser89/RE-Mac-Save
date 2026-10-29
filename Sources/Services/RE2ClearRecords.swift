import Foundation

struct RE2ClearRecord: Identifiable {
    let id:Int
    let cleared:Bool
    let clearTimeRaw:UInt64
    let rankCode:Int
    let saveCount:Int

    init(id:Int,cleared:Bool=true,clearTimeRaw:UInt64,rankCode:Int,saveCount:Int) {
        self.id=id;self.cleared=cleared;self.clearTimeRaw=clearTimeRaw
        self.rankCode=rankCode;self.saveCount=saveCount
    }

    // The observed Leon/Veteran result pairs 169007204 with 00:02:49.
    // Other IDs retain their native IDs until a corresponding game result is observed.
    var observedScenario:String? {id==2 ? "Leon · Veteran":nil}
    var observedRank:String? {id==2 && rankCode==1 ? "S+":nil}
    var displayTime:String {
        let seconds=clearTimeRaw/1_000_000
        let hours=seconds/3_600
        let minutes=(seconds/60)%60
        let remainder=seconds%60
        return String(format:"%02llu:%02llu:%02llu",hours,minutes,remainder)
    }
}

enum RE2ClearRecordCatalog {
    private static let rootOwner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.SaveDataManager.SystemSaveData".utf8))
    private static let rootList=SaveCrypto.murmur(Data("SystemSaveDataList".utf8))
    private static let owner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8))
    private static let count=21

    static func records(game:GameProfile,source:SaveFile,fields:[SaveScalar]) -> [RE2ClearRecord] {
        slots(game:game,source:source,fields:fields).filter(\.cleared)
    }

    static func slots(game:GameProfile,source:SaveFile,fields:[SaveScalar]) -> [RE2ClearRecord] {
        guard game.id=="re2",source.kind=="DSSS",source.url.lastPathComponent=="data00-1.bin" else {return []}
        func indexed(_ name:String,_ type:Int32,_ size:Int) -> [Int:SaveScalar]? {
            let hash=SaveCrypto.murmur(Data(name.utf8))
            let prefix=String(format:"/%08x.%08x[7]/%08x.%08x[",rootOwner,rootList,owner,hash)
            let matches=fields.filter{$0.owner==owner && $0.field==hash}
            guard matches.count==count else {return nil}
            var result:[Int:SaveScalar]=[:]
            for field in matches {
                guard field.type==type,field.size==size,
                      field.path.hasPrefix(prefix),field.path.hasSuffix("]"),
                      let index=Int(field.path.dropFirst(prefix.count).dropLast()),
                      (0..<count).contains(index),result[index]==nil else {return nil}
                result[index]=field
            }
            return result.count==count ? result:nil
        }
        guard let cleared=indexed("IsClearedGame",2,1),
              let times=indexed("ClearTime",10,8),
              let ranks=indexed("ClearRank",1,4),
              let saves=indexed("SaveCount",7,4) else {return []}
        var result:[RE2ClearRecord]=[]
        for index in 0..<count {
            guard let status=cleared[index],status.text=="true" || status.text=="false",
                  let time=times[index].flatMap({UInt64($0.text)}),
                  let rank=ranks[index].flatMap({Int($0.text)}),
                  let saveCount=saves[index].flatMap({Int($0.text)}),
                  rank>=0,saveCount>=0 else {return []}
            result.append(RE2ClearRecord(id:index,cleared:status.text=="true",
                                         clearTimeRaw:time,rankCode:rank,saveCount:saveCount))
        }
        return result
    }
}
