import Foundation

struct RE2PlacedItem: Identifiable {
    let id:String
    let setIndex:Int
    let entryIndex:Int
    let itemCode:Int
    let weaponCode:Int
    let count:Int
    let mapCode:Int
    let locationCode:Int
    let enabled:Bool
    let itemName:String?
    let weaponName:String?
}

enum RE2PlacedItemCatalog {
    private static let owner=SaveCrypto.murmur(Data("app.ropeway.gimmick.action.SetItem.SetItemSaveData".utf8))
    private static let fieldTypes:[String:(Int32,Int)]=[
        "Type":(1,4),"WeaponType":(1,4),"Count":(7,4),
        "Map":(1,4),"Location":(1,4),"Enable":(2,1)
    ]
    private static let pathPattern: NSRegularExpression? = {
        let root=SaveCrypto.murmur(Data("app.ropeway.gamemastering.SaveDataManager.GameSaveData".utf8))
        let rootList=SaveCrypto.murmur(Data("GameSaveDataList".utf8))
        let itemOwner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.ItemManager.SaveData".utf8))
        let setList=SaveCrypto.murmur(Data("SetItemsList".utf8))
        let setOwner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.ItemManager.SetItems".utf8))
        let items=SaveCrypto.murmur(Data("Items".utf8))
        let pattern=String(format:"^/%08x\\.%08x\\[([0-9]+)\\]/%08x\\.%08x\\[([0-9]+)\\]/%08x\\.%08x\\[([0-9]+)\\]/%08x\\.[0-9a-f]{8}$",
                           root,rootList,itemOwner,setList,setOwner,items,owner)
        return try? NSRegularExpression(pattern:pattern)
    }()

    static func entries(game:GameProfile,source:SaveFile,character:String?,fields:[SaveScalar],
                        names:ItemNameCatalog?=ItemNameCatalog.bundled) -> [RE2PlacedItem] {
        guard RE2CampaignSavePolicy.matches(game:game,source:source,character:character),
              let pathPattern else {return []}
        let hashes=Dictionary(uniqueKeysWithValues:fieldTypes.keys.map{(SaveCrypto.murmur(Data($0.utf8)),$0)})
        var groups:[String:[String:[SaveScalar]]]=[:]
        var positions:[String:(Int,Int)]=[:]
        for field in fields where field.owner==owner {
            guard let name=hashes[field.field],let expected=fieldTypes[name],
                  field.type==expected.0,field.size==expected.1 else {continue}
            let path=field.path as NSString
            let range=NSRange(location:0,length:path.length)
            guard let match=pathPattern.firstMatch(in:field.path,range:range),
                  let setIndex=Int(path.substring(with:match.range(at:2))),
                  let entryIndex=Int(path.substring(with:match.range(at:3))),
                  (0..<256).contains(setIndex),(0..<10_000).contains(entryIndex) else {continue}
            let parent=(field.path as NSString).deletingLastPathComponent
            groups[parent,default:[:]][name,default:[]].append(field)
            positions[parent]=(setIndex,entryIndex)
        }
        return groups.compactMap {parent,values -> RE2PlacedItem? in
            guard values.count==fieldTypes.count,let position=positions[parent] else {return nil}
            func value(_ name:String) -> String? {
                guard let fields=values[name],fields.count==1 else {return nil}
                return fields[0].text
            }
            guard let itemCode=value("Type").flatMap(Int.init),
                  let weaponCode=value("WeaponType").flatMap(Int.init),
                  let count=value("Count").flatMap(Int.init),count>=0,
                  let mapCode=value("Map").flatMap(Int.init),
                  let locationCode=value("Location").flatMap(Int.init),
                  let enabledText=value("Enable"),
                  enabledText=="true" || enabledText=="false" else {return nil}
            let itemName=itemCode>0 ? names?.entry(gameID:"re2",itemID:String(itemCode))?.name:nil
            let weaponName=weaponCode>=0 ? names?.entry(gameID:"re2",itemID:"Waffe \(weaponCode)")?.name:nil
            return RE2PlacedItem(id:parent,setIndex:position.0,entryIndex:position.1,
                                 itemCode:itemCode,weaponCode:weaponCode,count:count,
                                 mapCode:mapCode,locationCode:locationCode,enabled:enabledText=="true",
                                 itemName:itemName,weaponName:weaponName)
        }.sorted {($0.setIndex,$0.entryIndex)<($1.setIndex,$1.entryIndex)}
    }
}
