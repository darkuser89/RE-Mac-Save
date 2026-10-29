import Foundation

// The installed Mac game's record catalog links each saved record ID directly
// to the GUIDs of its German title and objective in mes_sys_bonus.msg.23.
enum RE2RecordTextCatalog {
    struct Entry: Decodable {
        let title: String
        let objective: String
        let catalogValue: Int
    }

    static let bundled: [Int:Entry] = {
        guard let url=Bundle.main.url(forResource:"RE2RecordDetails",withExtension:"json") else {return [:]}
        return (try? load(from:url)) ?? [:]
    }()

    static func load(from url:URL) throws -> [Int:Entry] {
        let raw=try JSONDecoder().decode([String:Entry].self,from:Data(contentsOf:url))
        var result:[Int:Entry]=[:]
        for (key,entry) in raw {
            guard let id=Int(key),String(id)==key,(0...90).contains(id),
                  !entry.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
                  !entry.objective.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
                  entry.catalogValue >= 0,result[id]==nil else {
                throw SaveError.invalid("Ungültige RE2-Rekordliste.")
            }
            result[id]=entry
        }
        guard result.count==87,Set(0...90).subtracting(result.keys)==Set([86,87,89,90]),
              result[58]?.title=="Schatzjäger",
              result[58]?.objective=="Finden Sie mithilfe der Fotohinweise zwei versteckte Objekte.",
              result[19]?.catalogValue==10,
              result[75]?.catalogValue==14000 else {
            throw SaveError.invalid("Unvollständige RE2-Rekordliste.")
        }
        return result
    }

    static func entry(for id:Int) -> Entry? {bundled[id]}
    static func title(for id:Int) -> String? {entry(for:id)?.title}
    static func objective(for id:Int) -> String? {entry(for:id)?.objective}
}
