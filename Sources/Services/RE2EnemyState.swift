import Foundation

struct RE2EnemyState {
    struct Record: Identifiable {
        let id: Int
        let sceneID: Int
        let areaID: Int
        let kindID: Int
        let inheritID: Int
        let flagBits: UInt32
        let dataVersion: UInt32
        let birthedTime: Double
        let unloadedTime: Double
        let hitPointData: [Int]
        let transformData: [Double]
    }
    let records: [Record]
}

enum RE2EnemyStateCatalog {
    private static let owner=SaveCrypto.murmur(Data("app.ropeway.enemy.savedata.EmSaveData".utf8))
    private static let scene=SaveCrypto.murmur(Data("SceneID".utf8))
    private static let area=SaveCrypto.murmur(Data("AreaID".utf8))
    private static let kind=SaveCrypto.murmur(Data("KindID".utf8))
    private static let inherit=SaveCrypto.murmur(Data("InheritID".utf8))
    private static let flags=SaveCrypto.murmur(Data("FlagData".utf8))
    private static let version=SaveCrypto.murmur(Data("DataVersion".utf8))
    private static let birthed=SaveCrypto.murmur(Data("BirthedTime".utf8))
    private static let unloaded=SaveCrypto.murmur(Data("UnloadedTime".utf8))
    private static let hitPoints=SaveCrypto.murmur(Data("HitPointData".utf8))
    private static let transform=SaveCrypto.murmur(Data("TransformData".utf8))
    private static let fieldHashes:Set<UInt32>=[scene,area,kind,inherit,flags,version,birthed,unloaded,hitPoints,transform]
    private static let listPrefix="/7f9decbe.8aab887b[29]/44ccdde9.1d563f16["

    static func details(game:GameProfile,source:SaveFile,fields:[SaveScalar],character:String?) -> RE2EnemyState? {
        guard RE2CampaignSavePolicy.matches(game:game,source:source,character:character) else {return nil}
        let selected=fields.filter {$0.owner==owner && fieldHashes.contains($0.field)}
        guard !selected.isEmpty,selected.count<=21_504,selected.count.isMultiple(of:21) else {return nil}
        let groups=Dictionary(grouping:selected) {field -> String in
            guard let slash=field.path.lastIndex(of:"/") else {return ""}
            return String(field.path[..<slash])
        }
        guard groups.count*21==selected.count else {return nil}
        var records:[RE2EnemyState.Record]=[]
        for (parent,siblings) in groups {
            guard parent.hasPrefix(listPrefix),parent.hasSuffix("]"),siblings.count==21,
                  let index=Int(parent.dropFirst(listPrefix.count).dropLast()),
                  (0..<1_024).contains(index),
                  let sceneID=integer(one(scene,type:1,parent:parent,fields:siblings)),
                  let areaID=integer(one(area,type:1,parent:parent,fields:siblings)),
                  let kindID=integer(one(kind,type:1,parent:parent,fields:siblings)),
                  let inheritID=integer(one(inherit,type:7,parent:parent,fields:siblings)),
                  let flagBits=unsigned(one(flags,type:8,parent:parent,fields:siblings)),
                  let dataVersion=unsigned(one(version,type:8,parent:parent,fields:siblings)),
                  let birthedTime=floating(one(birthed,type:11,parent:parent,fields:siblings)),
                  let unloadedTime=floating(one(unloaded,type:11,parent:parent,fields:siblings)),
                  let hitPointData=integerArray(hitPoints,type:7,count:3,parent:parent,fields:siblings),
                  let transformData=floatingArray(transform,type:11,count:10,parent:parent,fields:siblings)
            else {return nil}
            records.append(.init(id:index,sceneID:sceneID,areaID:areaID,kindID:kindID,
                                 inheritID:inheritID,flagBits:flagBits,dataVersion:dataVersion,
                                 birthedTime:birthedTime,unloadedTime:unloadedTime,
                                 hitPointData:hitPointData,transformData:transformData))
        }
        records.sort {$0.id<$1.id}
        guard records.enumerated().allSatisfy({$0.offset==$0.element.id}) else {return nil}
        return .init(records:records)
    }

    private static func one(_ hash:UInt32,type:Int32,parent:String,fields:[SaveScalar],index:Int?=nil) -> SaveScalar? {
        let path=parent+String(format:"/%08x.%08x",owner,hash)+(index.map{"[\($0)]"} ?? "")
        let matches=fields.filter {$0.field==hash && $0.path==path}
        guard matches.count==1,matches[0].type==type,matches[0].size==4 else {return nil}
        return matches[0]
    }
    private static func integer(_ field:SaveScalar?) -> Int? {field.flatMap {Int($0.text)}}
    private static func unsigned(_ field:SaveScalar?) -> UInt32? {field.flatMap {UInt32($0.text)}}
    private static func floating(_ field:SaveScalar?) -> Double? {
        guard let field,let value=Double(field.text),value.isFinite else {return nil}
        return value
    }
    private static func integerArray(_ hash:UInt32,type:Int32,count:Int,parent:String,fields:[SaveScalar]) -> [Int]? {
        guard fields.filter({$0.field==hash}).count==count else {return nil}
        let values=(0..<count).compactMap {integer(one(hash,type:type,parent:parent,fields:fields,index:$0))}
        return values.count==count ? values:nil
    }
    private static func floatingArray(_ hash:UInt32,type:Int32,count:Int,parent:String,fields:[SaveScalar]) -> [Double]? {
        guard fields.filter({$0.field==hash}).count==count else {return nil}
        let values=(0..<count).compactMap {floating(one(hash,type:type,parent:parent,fields:fields,index:$0))}
        return values.count==count ? values:nil
    }
}
