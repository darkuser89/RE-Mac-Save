import Foundation

struct RE2RecordStatus: Identifiable {
    let id: Int
    let cleared: Bool
    let newMark: Bool
    let progress: UInt32
}

struct RE2RewardStatus: Identifiable {
    let id: Int
    let opened: Bool
    let newMark: Bool
}

struct RE2SystemProgress {
    let records: [RE2RecordStatus]
    let rewards: [RE2RewardStatus]
}

enum RE2SystemProgressCatalog {
    private static let listOwner = SaveCrypto.murmur(Data("app.ropeway.gamemastering.SaveDataManager.SystemSaveData".utf8))
    private static let listField = SaveCrypto.murmur(Data("SystemSaveDataList".utf8))
    private static let recordOwner = SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8))

    static func details(game: GameProfile, source: SaveFile, fields: [SaveScalar]) -> RE2SystemProgress? {
        guard game.id == "re2", source.url.lastPathComponent == "data00-1.bin" else {return nil}

        func indexed(_ name: String, count: Int, type: Int32, size: Int) -> [SaveScalar]? {
            let hash = SaveCrypto.murmur(Data(name.utf8))
            let prefix = String(format: "/%08x.%08x[7]/%08x.%08x[", listOwner, listField, recordOwner, hash)
            let matches = fields.filter {$0.owner == recordOwner && $0.field == hash}
            guard matches.count == count else {return nil}
            var result: [Int: SaveScalar] = [:]
            for field in matches {
                guard field.type == type, field.size == size,
                      field.path.hasPrefix(prefix), field.path.last == "]",
                      let index = Int(field.path.dropFirst(prefix.count).dropLast()),
                      (0..<count).contains(index), result[index] == nil else {return nil}
                result[index] = field
            }
            guard result.count == count else {return nil}
            return (0..<count).compactMap {result[$0]}
        }

        guard let cleared = indexed("IsClearedRecord", count: 91, type: 2, size: 1),
              let newRecords = indexed("IsNewClearedRecord", count: 91, type: 2, size: 1),
              let progress = indexed("RecordProgressNumber", count: 91, type: 7, size: 4),
              let opened = indexed("IsOpenedReward", count: 133, type: 2, size: 1),
              let newRewards = indexed("IsNewReward", count: 133, type: 2, size: 1) else {return nil}

        func bool(_ field: SaveScalar) -> Bool? {
            switch field.text {case "true": return true; case "false": return false; default: return nil}
        }
        var records: [RE2RecordStatus] = []
        for index in 0..<91 {
            guard let clear = bool(cleared[index]), let fresh = bool(newRecords[index]),
                  let value = UInt32(progress[index].text) else {return nil}
            records.append(.init(id: index, cleared: clear, newMark: fresh, progress: value))
        }
        var rewards: [RE2RewardStatus] = []
        for index in 0..<133 {
            guard let open = bool(opened[index]), let fresh = bool(newRewards[index]) else {return nil}
            rewards.append(.init(id: index, opened: open, newMark: fresh))
        }
        return .init(records: records, rewards: rewards)
    }
}
