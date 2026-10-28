import Foundation

enum SaveInventory {
    struct ItemRow:Identifiable {
        let id:String
        let section:String
        let location:String
        let itemID:String
        let storedCount:String
        let identity:EditableField?
        let quantity:EditableField?
        let order:Int
    }
    private static func hash(_ text:String) -> UInt32 {SaveCrypto.murmur(Data(text.utf8))}
    private static func parent(_ path:String) -> String {String(path[..<(path.lastIndex(of:"/") ?? path.endIndex)])}
    private static func one(_ fields:[UInt32:[SaveScalar]],_ name:String) -> SaveScalar? {
        guard let matches=fields[hash(name)],matches.count==1 else {return nil}
        return matches[0]
    }
    private static func groups(_ parsed:ParsedSave,owner:String) -> [(String,[UInt32:[SaveScalar]])] {
        var result:[String:[UInt32:[SaveScalar]]]=[:]
        let ownerHash=hash(owner)
        for field in parsed.fields where field.owner==ownerHash {result[parent(field.path),default:[:]][field.field,default:[]].append(field)}
        return result.sorted{left,right in (left.value.values.flatMap{$0}.map(\.offset).min() ?? 0)<(right.value.values.flatMap{$0}.map(\.offset).min() ?? 0)}
    }
    private static func index(_ path:String,field:String) -> Int? {
        let marker=String(format:".%08x[",hash(field))
        guard let range=path.range(of:marker),let close=path[range.upperBound...].firstIndex(of:"]") else {return nil}
        return Int(path[range.upperBound..<close])
    }
    private static func quantity(_ scalar:SaveScalar?,title:String,detail:String,mirrors:[SaveScalar]=[]) -> EditableField? {
        guard let scalar,scalar.type==7,scalar.size==4,let current=UInt64(scalar.text),current>0,current<=999999 else {return nil}
        guard mirrors.allSatisfy({$0.type==scalar.type && $0.size==scalar.size && $0.text==scalar.text && $0.offset != scalar.offset}) else {return nil}
        return EditableField(id:scalar.id,title:title,description:detail,scalar:scalar,maximum:max(999,current),factor:1,mirrors:mirrors)
    }
    static func rows(game:GameProfile,parsed:ParsedSave) -> [ItemRow] {
        switch game.id {
        case "re2","re3":return ropewayRows(game:game,parsed:parsed)
        case "re4":return chainsawRows(parsed:parsed)
        case "re7":return biohazardRows(parsed:parsed)
        case "re8":return villageRows(parsed:parsed)
        default:return []
        }
    }
    private static func ropewayRows(game:GameProfile,parsed:ParsedSave) -> [ItemRow] {
        let prefix=game.id=="re2" ? "app.ropeway":"offline"
        let owner=prefix+".gamemastering.InventoryManager.PrimitiveItem"
        let stockMarker=String(format:".%08x[",hash("_Stocks"))
        let companionMarker=".02c95821["
        let additionalMarker=String(format:".%08x",hash("AdditionalItem"))
        let allGroups=groups(parsed,owner:owner)
        let byGroup=Dictionary(uniqueKeysWithValues:allGroups)
        var rows:[ItemRow]=[]
        for (path,fields) in allGroups where path.contains(stockMarker) && path.contains(String(format:".%08x[",hash("DataLists"))) {
            guard let item=one(fields,"ItemId"),item.type==1,item.size==4,
                  let weapon=one(fields,"WeaponId"),weapon.type==1,weapon.size==4,
                  let count=one(fields,"Count"),count.type==7,count.size==4,
                  let currentAmount=Int(count.text),currentAmount>0,
                  let itemID=Int(item.text),let weaponID=Int(weapon.text),itemID>0 || weaponID>0 else {continue}
            let profile=index(path,field:"DataLists") ?? 0,slot=index(path,field:"_Stocks") ?? 0
            let location="Inventarprofil \(profile+1) · Fach \(slot+1)\(path.contains(additionalMarker) ? " · Zusatz":"")"
            let identity=itemID>0 ? String(itemID):"Waffe \(weaponID)"
            let simple=itemID>0 && weaponID<0 && one(fields,"BulletId")?.text=="0" && one(fields,"WeaponParts")?.text=="0"
            let maxID:UInt64=game.id=="re2" ? 297:321 // Native Item.ID enum of the installed Mac builds.
            let companion=byGroup[path.replacingOccurrences(of:stockMarker,with:companionMarker)]
            let names=["ItemId","WeaponId","WeaponParts","BulletId","Count"]
            let paired=companion != nil && names.allSatisfy { name in
                guard let a=one(fields,name),let b=one(companion!,name) else {return false}
                return a.type==b.type && a.size==b.size && a.text==b.text && a.offset != b.offset
            }
            let idMirror=paired ? one(companion!,"ItemId"):nil
            let countMirror=paired ? one(companion!,"Count"):nil
            let idField:EditableField?=simple && UInt64(itemID)<=maxID && idMirror != nil ? EditableField(id:item.id,title:"\(location) · Gegenstands-ID",description:"Gültige Item-ID dieses Spielbuilds. Beide gespeicherten Inventarstände werden gemeinsam geändert.",scalar:item,maximum:maxID,factor:1,mirrors:[idMirror!],minimum:1) : nil
            let amount = simple && countMirror != nil ? quantity(count,title:"\(location) · Menge",detail:"Gespeicherte Anzahl; beide Inventarstände werden gemeinsam geändert.",mirrors:[countMirror!]) : nil
            rows.append(ItemRow(id:path,section:"Inventar",location:location,itemID:identity,storedCount:count.text,identity:idField,quantity:amount,order:item.offset))
        }
        if game.id=="re2" || game.id=="re3" {
            let locker=String(format:"/%08x.",hash(prefix+".gamemastering.ItemLockerManager.GameSaveData"))
            let box=String(format:"/%08x.",hash(prefix+".gimmick.action.GimmickItemLockerControl.ItemLockerSaveData"))
            let items=String(format:".%08x[",hash("_Items"))
            for (path,fields) in allGroups where path.contains(locker) && path.contains(box) && path.contains(items) {
                guard let item=one(fields,"ItemId"),item.type==1,item.size==4,
                      let weapon=one(fields,"WeaponId"),weapon.type==1,weapon.size==4,
                      let count=one(fields,"Count"),count.type==7,count.size==4,
                      let itemID=Int(item.text),let weaponID=Int(weapon.text),itemID>0 || weaponID>0,
                      let slot=index(path,field:"_Items") else {continue}
                let location="Itembox · Fach \(slot+1)\(path.contains(additionalMarker) ? " · Zusatz":"")"
                let identity=itemID>0 ? String(itemID):"Waffe \(weaponID)"
                let simple=itemID>0 && weaponID<0 && (Int(count.text) ?? 0)>0 && one(fields,"BulletId")?.text=="0" && one(fields,"WeaponParts")?.text=="0"
                let maxID:UInt64=game.id=="re2" ? 297:321
                let idField:EditableField?=simple && UInt64(itemID)<=maxID ? EditableField(id:item.id,title:"\(location) · Gegenstands-ID",description:"ID dieses bereits belegten Itembox-Platzes.",scalar:item,maximum:maxID,factor:1,minimum:1) : nil
                let amount=simple ? quantity(count,title:"\(location) · Menge",detail:"Gespeicherte Anzahl dieses bereits belegten Itembox-Gegenstands.") : nil
                rows.append(ItemRow(id:path,section:"Itembox",location:location,itemID:identity,storedCount:count.text,identity:idField,quantity:amount,order:count.offset))
            }
        }
        return rows.sorted {a,b in a.section==b.section ? a.order<b.order : a.section=="Inventar"}
    }
    private static func chainsawRows(parsed:ParsedSave) -> [ItemRow] {
        let campaign=String(format:"/%08x.",hash("chainsaw.InventoryManager.GameSaveData"))
        let inventory=String(format:".%08x[",hash("InventoryItems"))
        var rows:[ItemRow]=[]
        for (path,fields) in groups(parsed,owner:"chainsaw.Item") where path.contains(campaign) && path.contains(inventory) {
            guard let item=one(fields,"_ItemId"),item.type==1,item.size==4,let id=UInt64(item.text),id>0,
                  let count=one(fields,"_CurrentItemCount"),let slot=index(path,field:"InventoryItems") else {continue}
            let location="Inventarplatz \(slot+1)"
            rows.append(ItemRow(id:path,section:"Inventar",location:location,itemID:String(id),storedCount:count.text,identity:nil,quantity:quantity(count,title:"\(location) · ID \(id) · Menge",detail:"Gespeicherte Menge dieses vorhandenen Inventargegenstands."),order:item.offset))
        }
        return rows.sorted{$0.order<$1.order}
    }
    private static func biohazardRows(parsed:ParsedSave) -> [ItemRow] {
        let inventory=String(format:"/%08x.",hash("app.InventorySaveData"))
        var rows:[ItemRow]=[]
        for (path,fields) in groups(parsed,owner:"app.InventoryItemInfo") where path.contains(inventory) {
            guard let item=one(fields,"ItemDataID"),item.type==15,!item.text.isEmpty,
                  let count=one(fields,"Num"),count.type==7,count.size==4 else {continue}
            let profile=index(path,field:"Table") ?? 0
            let box=index(path,field:"ItemBoxItems"),slot=box ?? index(path,field:"Items") ?? 0
            let location="Profil \(profile+1) · \(box == nil ? "Inventar":"Itembox") \(slot+1)"
            rows.append(ItemRow(id:path,section:box == nil ? "Inventar":"Itembox",location:location,itemID:item.text,storedCount:count.text,identity:nil,quantity:quantity(count,title:"\(location) · \(item.text) · Menge",detail:"Menge dieses vorhandenen Gegenstands; die Text-ID bleibt unverändert."),order:item.offset))
        }
        return rows.sorted{$0.order<$1.order}
    }
    private static func villageRows(parsed:ParsedSave) -> [ItemRow] {
        let data=String(format:"/%08x.",hash("app.InventoryManager.SaveData"))
        let unitOwner=String(format:"/%08x.",hash("app.InventoryManager.SaveData.Unit"))
        let objectField=String(format:"%08x",hash("objectID"))
        let stackable:Set<UInt64>=[1053957234,2936421236,963607484,4025304392,1585764422]
        let byPath=Dictionary(grouping:parsed.fields.filter{$0.owner==hash("app.InventoryManager.SaveData.Unit")},by:\.path)
        var rows:[ItemRow]=[]
        for (path,fields) in groups(parsed,owner:"app.ItemCore.InstanceWork") where path.contains(data) {
            guard let item=one(fields,"ItemID"),item.type==8,item.size==4,let id=UInt64(item.text),id>0,
                  let category=one(fields,"ItemCategoryHash"),let categoryID=UInt64(category.text),
                  let count=one(fields,"StackSize"),let slot=index(path,field:"datas") else {continue}
            let objectPath=parent(path)+unitOwner+objectField
            let identityValid=byPath[objectPath]?.count==1 && byPath[objectPath]![0].text==item.text
            let location="Inventarplatz \(slot+1)"
            let amount=identityValid && stackable.contains(categoryID) ? quantity(count,title:"\(location) · ID \(id) · Menge",detail:"Gespeicherte Stapelmenge dieses vorhandenen Gegenstands.") : nil
            rows.append(ItemRow(id:path,section:"Inventar",location:location,itemID:String(id),storedCount:count.text,identity:nil,quantity:amount,order:item.offset))
        }
        return rows.sorted{$0.order<$1.order}
    }
}
