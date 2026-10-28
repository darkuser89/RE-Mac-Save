import Foundation

// Names are exact hash matches against strings in the installed RE2 Mac build.
// A hash collision remains a list of candidates instead of a guessed name.
enum RE2FieldNameCatalog {
    static let bundled: [String:[String]] = {
        guard let url=Bundle.main.url(forResource:"RE2FieldNames",withExtension:"json") else {return [:]}
        return (try? load(from:url)) ?? [:]
    }()

    static func load(from url:URL) throws -> [String:[String]] {
        let decoded=try JSONDecoder().decode([String:[String]].self,from:Data(contentsOf:url))
        for (hash,names) in decoded {
            guard hash.count==8,let parsedHash=UInt32(hash,radix:16),!names.isEmpty,
                  names.allSatisfy({SaveCrypto.murmur(Data($0.utf8))==parsedHash}) else {
                throw SaveError.invalid("Ungültige RE2-Feldnamendatei.")
            }
        }
        return decoded
    }

    static func names(for hash:UInt32) -> [String] {
        bundled[String(format:"%08x",hash)] ?? []
    }
}
