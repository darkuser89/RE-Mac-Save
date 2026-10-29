import Foundation

struct RE2ClearRecord: Identifiable {
    let id:Int
    let clearTimeRaw:UInt64
    let rankCode:Int
    let saveCount:Int
}

enum RE2ClearRecordCatalog {
    private static let owner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8))
    private static let count=21

    static func records(game:GameProfile,source:SaveFile,fields:[SaveScalar]) -> [RE2ClearRecord] {
        guard game.id=="re2",source.url.lastPathComponent=="data00-1.bin" else {return []}
        func indexed(_ name:String,_ type:Int32,_ size:Int) -> [Int:SaveScalar]? {
            let hash=SaveCrypto.murmur(Data(name.utf8))
            let matches=fields.filter{$0.owner==owner && $0.field==hash}
            guard matches.count==count else {return nil}
            var result:[Int:SaveScalar]=[:]
            for field in matches {
                guard field.type==type,field.size==size,
                      let left=field.path.lastIndex(of:"["),field.path.last=="]",
                      let index=Int(field.path[field.path.index(after:left)..<field.path.index(before:field.path.endIndex)]),
                      (0..<count).contains(index),result[index]==nil else {return nil}
                result[index]=field
            }
            return result.count==count ? result:nil
        }
        guard let cleared=indexed("IsClearedGame",2,1),
              let times=indexed("ClearTime",10,8),
              let ranks=indexed("ClearRank",1,4),
              let saves=indexed("SaveCount",7,4) else {return []}
        let all=Array(cleared.values)+Array(times.values)+Array(ranks.values)+Array(saves.values)
        let parents=Set(all.compactMap{field in
            field.path.lastIndex(of:"/").map{String(field.path[..<$0])}
        })
        guard parents.count==1,all.allSatisfy({$0.path.contains("/")}) else {return []}
        var result:[RE2ClearRecord]=[]
        for index in 0..<count {
            guard let status=cleared[index],status.text=="true" || status.text=="false",
                  let time=times[index].flatMap({UInt64($0.text)}),
                  let rank=ranks[index].flatMap({Int($0.text)}),
                  let saveCount=saves[index].flatMap({Int($0.text)}),
                  rank>=0,saveCount>=0 else {return []}
            if status.text=="true" {result.append(RE2ClearRecord(id:index,clearTimeRaw:time,rankCode:rank,saveCount:saveCount))}
        }
        return result
    }
}
