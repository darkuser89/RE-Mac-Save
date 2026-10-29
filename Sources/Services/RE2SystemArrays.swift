import Foundation

struct RE2SystemOption: Identifiable {
    let id: Int
    let stored: UInt32
    let defaultValue: UInt32
    var differs: Bool {stored != defaultValue}
}

struct RE2TofuClearTime: Identifiable {
    let id: Int
    let rawValue: UInt64
}

enum RE2SystemArrayCatalog {
    private static let root = SaveCrypto.murmur(Data("app.ropeway.gamemastering.SaveDataManager.SystemSaveData".utf8))
    private static let list = SaveCrypto.murmur(Data("SystemSaveDataList".utf8))
    private static let optionOwner = SaveCrypto.murmur(Data("app.ropeway.OptionManager.SystemSaveData".utf8))
    private static let recordOwner = SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8))

    private static func indexed(_ fields:[SaveScalar],owner:UInt32,name:String,
                                listIndex:Int,count:Int,type:Int32,size:Int) -> [SaveScalar]? {
        let fieldHash=SaveCrypto.murmur(Data(name.utf8))
        let prefix=String(format:"/%08x.%08x[%d]/%08x.%08x[",root,list,listIndex,owner,fieldHash)
        let matches=fields.filter {$0.owner==owner && $0.field==fieldHash}
        guard matches.count==count else {return nil}
        var values=[SaveScalar?](repeating:nil,count:count)
        for field in matches {
            guard field.type==type,field.size==size,
                  field.path.hasPrefix(prefix),field.path.hasSuffix("]"),
                  let index=Int(field.path.dropFirst(prefix.count).dropLast()),
                  (0..<count).contains(index),values[index]==nil else {return nil}
            values[index]=field
        }
        guard values.allSatisfy({$0 != nil}) else {return nil}
        return values.compactMap {$0}
    }

    static func options(game:GameProfile,source:SaveFile,fields:[SaveScalar]) -> [RE2SystemOption] {
        guard game.id=="re2",source.kind=="DSSS",source.url.lastPathComponent=="data00-1.bin",
              let stored=indexed(fields,owner:optionOwner,name:"optionData",listIndex:8,count:134,type:8,size:4),
              let defaults=indexed(fields,owner:optionOwner,name:"defaultData",listIndex:8,count:134,type:8,size:4) else {return []}
        var result:[RE2SystemOption]=[]
        for index in 0..<134 {
            guard let value=UInt32(stored[index].text),let defaultValue=UInt32(defaults[index].text) else {return []}
            result.append(.init(id:index,stored:value,defaultValue:defaultValue))
        }
        return result
    }

    static func tofuTimes(game:GameProfile,source:SaveFile,fields:[SaveScalar]) -> [RE2TofuClearTime] {
        guard game.id=="re2",source.kind=="DSSS",source.url.lastPathComponent=="data00-1.bin",
              let times=indexed(fields,owner:recordOwner,name:"TofuClearPlayTime",listIndex:7,count:5,type:10,size:8) else {return []}
        var result:[RE2TofuClearTime]=[]
        for index in 0..<5 {
            guard let value=UInt64(times[index].text) else {return []}
            result.append(.init(id:index,rawValue:value))
        }
        return result
    }
}
