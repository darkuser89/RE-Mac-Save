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

    static func labeledPath(_ path:String,
                            fieldNames:[String:[String]]=bundled,
                            ownerNames:[String:[String]]=RE2OwnerNameCatalog.bundled) -> String {
        let segments=path.split(separator:"/",omittingEmptySubsequences:true).map {raw -> String in
            let parts=raw.split(separator:".",maxSplits:1,omittingEmptySubsequences:false)
            guard parts.count==2,parts[0].count==8,parts[1].count>=8 else {return String(raw)}
            let ownerHash=String(parts[0]),fieldHash=String(parts[1].prefix(8))
            let suffix=String(parts[1].dropFirst(8))
            let owner=ownerNames[ownerHash]?.count==1 ? ownerNames[ownerHash]![0]:ownerHash
            let field=fieldNames[fieldHash]?.count==1 ? fieldNames[fieldHash]![0]:fieldHash
            return "\(owner).\(field)\(suffix)"
        }
        return "/"+segments.joined(separator:"/")
    }
}
