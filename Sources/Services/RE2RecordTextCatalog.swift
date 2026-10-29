import Foundation

// Titles come from the installed Mac game's German mes_sys_bonus.msg.23.
// Linking title suffix NN to save record index NN is an index match, not a
// gameplay verification of every challenge or its progress counter.
enum RE2RecordTextCatalog {
    static let bundled: [Int:String] = {
        guard let url=Bundle.main.url(forResource:"RE2RecordNames",withExtension:"json") else {return [:]}
        return (try? load(from:url)) ?? [:]
    }()

    static func load(from url:URL) throws -> [Int:String] {
        let raw=try JSONDecoder().decode([String:String].self,from:Data(contentsOf:url))
        var result:[Int:String]=[:]
        for (key,title) in raw {
            guard let id=Int(key),String(id)==key,(0...90).contains(id),
                  !title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
                  result[id]==nil else {throw SaveError.invalid("Ungültige RE2-Rekordtitelliste.")}
            result[id]=title
        }
        guard result.count==89,Set(0...90).subtracting(result.keys)==Set([87,88]),
              result[59]=="Schatzjäger" else {
            throw SaveError.invalid("Unvollständige RE2-Rekordtitelliste.")
        }
        return result
    }

    static func title(for id:Int) -> String? {bundled[id]}
}
