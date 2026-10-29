import Foundation

enum RE2CampaignSavePolicy {
    static func matches(game:GameProfile,source:SaveFile,character:String?) -> Bool {
        guard game.id=="re2",source.kind=="DSSS",
              character=="Leon" || character=="Claire" else {return false}
        let name=source.url.lastPathComponent
        if name=="data000.bin" {return true}
        guard name.hasPrefix("data"),name.hasSuffix("Slot.bin"),name.count==15,
              let slot=Int(name.dropFirst(4).prefix(3)),slot>0,slot != 21 else {return false}
        return name==String(format:"data%03dSlot.bin",slot)
    }
}
