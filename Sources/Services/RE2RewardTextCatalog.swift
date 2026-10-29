import Foundation

// The installed Mac game's figure and concept-art order tables link saved
// reward IDs to message indices; unlinked reward IDs remain unnamed.
enum RE2RewardTextCatalog {
    struct Entry: Decodable {
        let name: String
        let kind: String
    }

    static let bundled: [Int:Entry] = {
        guard let url=Bundle.main.url(forResource:"RE2RewardDetails",withExtension:"json") else {return [:]}
        return (try? load(from:url)) ?? [:]
    }()

    static func load(from url:URL) throws -> [Int:Entry] {
        let raw=try JSONDecoder().decode([String:Entry].self,from:Data(contentsOf:url))
        var result:[Int:Entry]=[:]
        for (key,entry) in raw {
            guard let id=Int(key),String(id)==key,(25...132).contains(id),
                  !entry.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
                  ["Konzeptgrafik","Figur"].contains(entry.kind),result[id]==nil else {
                throw SaveError.invalid("Ungültige RE2-Belohnungsliste.")
            }
            result[id]=entry
        }
        let art=result.filter {$0.value.kind=="Konzeptgrafik"}
        let figures=result.filter {$0.value.kind=="Figur"}
        guard result.count==98,art.count==30,figures.count==68,
              Set(art.keys)==Set(25...54),
              figures.keys.allSatisfy({(55...132).contains($0)}),
              result[37]?.name=="Raccoon City A",
              result[55]?.name=="Leon (Freizeit)",
              result[114]?.name=="Robert und Emma Kendo" else {
            throw SaveError.invalid("Unvollständige RE2-Belohnungsliste.")
        }
        return result
    }

    static func entry(for id:Int) -> Entry? {bundled[id]}
}
