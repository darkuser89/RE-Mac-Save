import Foundation

struct RE2ItemBoxBonus: Identifiable {
    let id:String
    let label:String
    let extraValid:[Bool]
    let extraNotice:[Bool]
    let bonusValid:[Bool]
    let bonusNotice:[Bool]
    let extraNoticeAdded:Bool
}

enum RE2ItemBoxBonusCatalog {
    // The five field hashes and their layout are present in the native RE2 build.
    // The owner type name is still unknown; keep its observed hash explicit.
    private static let owner:UInt32=0xc0d6d676
    private static let names=["_isValidExItems","_isNoticeExItems",
                              "_isValidOmakeItems","_isNoticeOmakeItems",
                              "_isAddExItemNotice"]
    private static let fieldNames=Dictionary(uniqueKeysWithValues:names.map{(SaveCrypto.murmur(Data($0.utf8)),$0)})
    private static let globalPattern:NSRegularExpression? = {
        let root=SaveCrypto.murmur(Data("app.ropeway.gamemastering.SaveDataManager.GameSaveData".utf8))
        let rootList=SaveCrypto.murmur(Data("GameSaveDataList".utf8))
        let manager=SaveCrypto.murmur(Data("app.ropeway.gamemastering.ItemLockerManager.GameSaveData".utf8))
        let saveData=SaveCrypto.murmur(Data("SaveData".utf8))
        let pattern=String(format:"^/%08x\\.%08x\\[[0-9]+\\]/%08x\\.%08x/%08x\\.[0-9a-f]{8}(?:\\[[0-9]+\\])?$",
                           root,rootList,manager,saveData,owner)
        return try? NSRegularExpression(pattern:pattern)
    }()
    private static let gimmickPattern:NSRegularExpression? = {
        let root=SaveCrypto.murmur(Data("app.ropeway.gamemastering.SaveDataManager.GameSaveData".utf8))
        let rootList=SaveCrypto.murmur(Data("GameSaveDataList".utf8))
        let manager=SaveCrypto.murmur(Data("app.ropeway.gimmick.GimmickSetManager.GameSaveData".utf8))
        let controlList=SaveCrypto.murmur(Data("GimmickControlDataListValue".utf8))
        let saveData=SaveCrypto.murmur(Data("SaveData".utf8))
        let pattern=String(format:"^/%08x\\.%08x\\[[0-9]+\\]/%08x\\.%08x\\[([0-9]+)\\]/3a989d33\\.%08x/%08x\\.[0-9a-f]{8}(?:\\[[0-9]+\\])?$",
                           root,rootList,manager,controlList,saveData,owner)
        return try? NSRegularExpression(pattern:pattern)
    }()

    static func groups(game:GameProfile,source:SaveFile,character:String?,fields:[SaveScalar]) -> [RE2ItemBoxBonus] {
        guard RE2CampaignSavePolicy.matches(game:game,source:source,character:character),
              let globalPattern,let gimmickPattern else {return []}
        var members:[String:[String:[Int:SaveScalar]]]=[:]
        var labels:[String:String]=[:]
        var invalid=Set<String>()
        for field in fields where field.owner==owner {
            guard let name=fieldNames[field.field],field.type==2,field.size==1,
                  field.text=="true" || field.text=="false" else {continue}
            let path=field.path as NSString
            let range=NSRange(location:0,length:path.length)
            let global=globalPattern.firstMatch(in:field.path,range:range)
            let gimmick=gimmickPattern.firstMatch(in:field.path,range:range)
            guard global != nil || gimmick != nil else {continue}
            let parent=path.deletingLastPathComponent
            if global != nil {labels[parent]="Globale Itembox-Daten"}
            else if let gimmick,let index=Int(path.substring(with:gimmick.range(at:1))) {
                labels[parent]="Mechanik-Eintrag \(index)"
            } else {continue}
            let suffix=String(field.path.dropFirst(parent.count+1))
            let index:Int
            if let start=suffix.firstIndex(of:"["),suffix.hasSuffix("]"),
               let parsed=Int(suffix[suffix.index(after:start)..<suffix.index(before:suffix.endIndex)]) {
                index=parsed
            } else {index=0}
            let expected=name=="_isAddExItemNotice" ? 1 : name.contains("Omake") ? 5 : 3
            guard (0..<expected).contains(index),name != "_isAddExItemNotice" || !suffix.contains("[") else {
                invalid.insert(parent);continue
            }
            if members[parent,default:[:]][name,default:[:]].updateValue(field,forKey:index) != nil {
                invalid.insert(parent)
            }
        }
        return members.compactMap {parent,values -> RE2ItemBoxBonus? in
            guard !invalid.contains(parent),let label=labels[parent] else {return nil}
            func list(_ name:String,_ count:Int) -> [Bool]? {
                guard let entries=values[name],entries.count==count else {return nil}
                let ordered=(0..<count).compactMap{entries[$0]?.text}
                guard ordered.count==count else {return nil}
                return ordered.map{$0=="true"}
            }
            guard let extraValid=list("_isValidExItems",3),
                  let extraNotice=list("_isNoticeExItems",3),
                  let bonusValid=list("_isValidOmakeItems",5),
                  let bonusNotice=list("_isNoticeOmakeItems",5),
                  let added=list("_isAddExItemNotice",1)?.first else {return nil}
            return RE2ItemBoxBonus(id:parent,label:label,extraValid:extraValid,
                                   extraNotice:extraNotice,bonusValid:bonusValid,
                                   bonusNotice:bonusNotice,extraNoticeAdded:added)
        }.sorted {$0.label==$1.label ? $0.id<$1.id : $0.label<$1.label}
    }
}
