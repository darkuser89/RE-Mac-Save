import Foundation

// Candidate type names are assembled from namespace and class strings in the
// installed RE2 Mac binary. Hash agreement identifies a possible type name;
// it does not establish the meaning or editability of a serialized object.
enum RE2OwnerNameCatalog {
    static let bundled: [String:[String]] = {
        guard let url=Bundle.main.url(forResource:"RE2OwnerNameCandidates",withExtension:"json") else {return [:]}
        return (try? load(from:url)) ?? [:]
    }()

    static func load(from url:URL) throws -> [String:[String]] {
        let decoded=try JSONDecoder().decode([String:[String]].self,from:Data(contentsOf:url))
        for (hash,names) in decoded {
            guard hash.count==8,let parsedHash=UInt32(hash,radix:16),!names.isEmpty,
                  names.allSatisfy({SaveCrypto.murmur(Data($0.utf8))==parsedHash}) else {
                throw SaveError.invalid("Ungültige RE2-Besitzernamendatei.")
            }
        }
        return decoded
    }

    static func names(for hash:UInt32) -> [String] {
        bundled[String(format:"%08x",hash)] ?? []
    }
}
