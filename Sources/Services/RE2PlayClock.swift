import Foundation

struct RE2PlayClock {
    let total:UInt64
    let inventory:UInt64
    let pause:UInt64
    let displayed:UInt64

    var displayedTime:String {
        let seconds=displayed/1_000_000
        return String(format:"%02llu:%02llu:%02llu",seconds/3_600,(seconds/60)%60,seconds%60)
    }
}

enum RE2PlayClockCatalog {
    private static let owner=SaveCrypto.murmur(Data("app.ropeway.GameClock.GameSaveData".utf8))

    static func clock(game:GameProfile,source:SaveFile,fields:[SaveScalar]) -> RE2PlayClock? {
        guard game.id=="re2",source.kind=="DSSS",source.url.lastPathComponent != "data00-1.bin" else {return nil}
        func one(_ name:String) -> UInt64? {
            let hash=SaveCrypto.murmur(Data(name.utf8))
            let matches=fields.filter{$0.owner==owner && $0.field==hash && $0.type==10 && $0.size==8}
            guard matches.count==1 else {return nil}
            return UInt64(matches[0].text)
        }
        guard let total=one("_GameElapsedTime"),
              let inventory=one("_InventorySpendingTime"),
              let pause=one("_PauseSpendingTime") else {return nil}
        let (excluded,overflow)=inventory.addingReportingOverflow(pause)
        guard !overflow,total>=excluded else {return nil}
        return RE2PlayClock(total:total,inventory:inventory,pause:pause,displayed:total-excluded)
    }
}
