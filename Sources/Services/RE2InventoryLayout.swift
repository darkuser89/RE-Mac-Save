import Foundation

struct RE2InventoryLayout: Identifiable {
    struct Slot {
        let index: Int
        let lastWeaponCode: Int
    }
    struct Shortcut: Identifiable {
        let id: Int
        let kindCode: Int
        let slotIndex: Int?
        let lastWeaponCode: Int?
    }
    let id: Int
    let survivorCode: Int
    let slotSize: Int
    let storedSlotSize: Int
    let mainSlot: Slot
    let savedMainSlot: Slot
    let subWeaponCode: Int
    let savedSubWeaponCode: Int
    let shortcuts: [Shortcut]
    let subShortcuts: [Shortcut]
    let storedShortcuts: [Shortcut]
    let storedSubShortcuts: [Shortcut]
}

enum RE2InventoryLayoutCatalog {
    private static let dataOwner = SaveCrypto.murmur(Data("app.ropeway.inventory.Data".utf8))
    private static let mainOwner = SaveCrypto.murmur(Data("app.ropeway.inventory.MainSlotData".utf8))
    private static let subOwner = SaveCrypto.murmur(Data("app.ropeway.inventory.SubSlotData".utf8))
    private static let shortcutOwner = SaveCrypto.murmur(Data("app.ropeway.inventory.ShortcutSlotData".utf8))
    private static let rootPrefix = "/7f9decbe.8aab887b[15]/41f30892.cbe14e81["

    static func profiles(game: GameProfile, source: SaveFile, fields: [SaveScalar], character: String?) -> [RE2InventoryLayout] {
        guard RE2CampaignSavePolicy.matches(game:game,source:source,character:character) else {return []}
        let typeHash = hash("_SurvivorType")
        let types = fields.filter {$0.owner == dataOwner && $0.field == typeHash}
        guard (1...4).contains(types.count) else {return []}
        let chosenOwners = Set([dataOwner,mainOwner,subOwner,shortcutOwner])
        let relevant = Dictionary(grouping:fields.filter {chosenOwners.contains($0.owner)},by:\.path)
        var result:[RE2InventoryLayout] = []
        for profile in 0..<types.count {
            let root = rootPrefix + "\(profile)]"
            func value(_ tail:String, owner:UInt32, field:String, type:Int32, size:Int) -> Int? {
                let path = root + tail + String(format:"/%08x.%08x",owner,hash(field))
                guard let matches = relevant[path], matches.count == 1,
                      let scalar = matches.first, scalar.owner == owner,
                      scalar.field == hash(field), scalar.type == type,
                      scalar.size == size else {return nil}
                return Int(scalar.text)
            }
            func main(_ name:String) -> RE2InventoryLayout.Slot? {
                let tail = String(format:"/%08x.%08x",dataOwner,hash(name))
                guard let index = value(tail,owner:mainOwner,field:"_Index",type:7,size:4),
                      let weapon = value(tail,owner:mainOwner,field:"_LastWeaponType",type:1,size:4) else {return nil}
                return .init(index:index,lastWeaponCode:weapon)
            }
            func sub(_ name:String) -> Int? {
                let tail = String(format:"/%08x.%08x",dataOwner,hash(name))
                return value(tail,owner:subOwner,field:"_LastWeaponType",type:1,size:4)
            }
            func shortcutList(_ name:String) -> [RE2InventoryLayout.Shortcut]? {
                var shortcuts:[RE2InventoryLayout.Shortcut] = []
                for index in 0..<32 {
                    let tail = String(format:"/%08x.%08x[%d]",dataOwner,hash(name),index)
                    let kindPath = root + tail + String(format:"/%08x.%08x",shortcutOwner,hash("_ShortcutKind"))
                    let slotPath = root + tail + String(format:"/%08x.%08x",shortcutOwner,hash("_Index"))
                    let weaponPath = root + tail + String(format:"/%08x.%08x",shortcutOwner,hash("_LastWeaponType"))
                    if relevant[kindPath] == nil && relevant[slotPath] == nil && relevant[weaponPath] == nil {break}
                    let kindValue = value(tail,owner:shortcutOwner,field:"_ShortcutKind",type:1,size:4)
                    let slotValue = value(tail,owner:shortcutOwner,field:"_Index",type:7,size:4)
                    let weaponValue = value(tail,owner:shortcutOwner,field:"_LastWeaponType",type:1,size:4)
                    guard let kind = kindValue, (0...31).contains(kind),
                          relevant[slotPath] == nil || slotValue != nil,
                          relevant[weaponPath] == nil || weaponValue != nil,
                          slotValue.map({(-1...42).contains($0)}) ?? true,
                          weaponValue.map({(-1...382).contains($0)}) ?? true else {return nil}
                    shortcuts.append(.init(id:index,kindCode:kind,slotIndex:slotValue,lastWeaponCode:weaponValue))
                }
                return shortcuts.isEmpty ? nil : shortcuts
            }
            guard let survivor = value("",owner:dataOwner,field:"_SurvivorType",type:1,size:4),
                  let size = value("",owner:dataOwner,field:"CurrentSlotSize",type:7,size:4),
                  let storedSize = value("",owner:dataOwner,field:"_CurrentSlotSize",type:7,size:4),
                  let mainSlot = main("MainData"), let savedMainSlot = main("_MainData"),
                  let subWeapon = sub("SubData"), let savedSubWeapon = sub("_SubData"),
                  let shortcuts = shortcutList("ShortcutDataList"),
                  let subShortcuts = shortcutList("SubShortcutDataList"),
                  let storedShortcuts = shortcutList("_ShortcutDataList"),
                  let storedSubShortcuts = shortcutList("_SubShortcutDataList"),
                  (0...3).contains(survivor), (0...42).contains(size), (0...42).contains(storedSize) else {return []}
            result.append(.init(id:profile,survivorCode:survivor,slotSize:size,storedSlotSize:storedSize,
                                mainSlot:mainSlot,savedMainSlot:savedMainSlot,
                                subWeaponCode:subWeapon,savedSubWeaponCode:savedSubWeapon,
                                shortcuts:shortcuts,subShortcuts:subShortcuts,
                                storedShortcuts:storedShortcuts,storedSubShortcuts:storedSubShortcuts))
        }
        guard Set(result.map(\.survivorCode)).count == result.count else {return []}
        return result
    }

    private static func hash(_ text:String) -> UInt32 {SaveCrypto.murmur(Data(text.utf8))}
}
