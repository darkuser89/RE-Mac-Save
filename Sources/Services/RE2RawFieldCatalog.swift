import Foundation

struct RE2RawFieldRow:Identifiable {
    let id:Int
    let fieldLabel:String
    let ownerLabel:String
    let value:String
    let type:Int32
    let size:Int
    let namedPath:String
    let rawPath:String
}

struct RE2RawFieldSearch {
    let matches:Int
    let rows:[RE2RawFieldRow]
}

enum RE2RawFieldCatalog {
    // String fields may contain account data. They are intentionally absent
    // from this read-only explorer and are never included in search results.
    static func numericCount(_ fields:[SaveScalar]) -> Int {
        fields.reduce(0) {$0 + ($1.type == 15 ? 0 : 1)}
    }

    static func search(_ fields:[SaveScalar],query:String,limit:Int=80,
                       fieldNames:[String:[String]]=RE2FieldNameCatalog.bundled,
                       ownerNames:[String:[String]]=RE2OwnerNameCatalog.bundled) -> RE2RawFieldSearch {
        let term=query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !term.isEmpty else {return RE2RawFieldSearch(matches:0,rows:[])}
        var matches=0,rows:[RE2RawFieldRow]=[]
        var hashCache:[UInt32:String]=[:]
        for field in fields where field.type != 15 {
            let fieldHash=hashCache[field.field] ?? String(format:"%08x",field.field)
            let ownerHash=hashCache[field.owner] ?? String(format:"%08x",field.owner)
            hashCache[field.field]=fieldHash
            hashCache[field.owner]=ownerHash
            let fieldCandidates=fieldNames[fieldHash] ?? []
            let ownerCandidates=ownerNames[ownerHash] ?? []
            guard field.path.localizedCaseInsensitiveContains(term) ||
                  field.text.localizedCaseInsensitiveContains(term) ||
                  fieldCandidates.contains(where:{$0.localizedCaseInsensitiveContains(term)}) ||
                  ownerCandidates.contains(where:{$0.localizedCaseInsensitiveContains(term)}) else {continue}
            matches+=1
            if rows.count < max(0,limit) {
                let fieldLabel=fieldCandidates.isEmpty ? "Feldhash \(fieldHash)" :
                    fieldCandidates.count==1 ? fieldCandidates[0] : "Namenskandidaten: \(fieldCandidates.joined(separator:" / "))"
                let ownerLabel=ownerCandidates.isEmpty ? "Besitzerhash \(ownerHash)" :
                    ownerCandidates.count==1 ? ownerCandidates[0] : "Besitzerkandidaten: \(ownerCandidates.joined(separator:" / "))"
                let namedPath=RE2FieldNameCatalog.labeledPath(field.path,fieldNames:fieldNames,ownerNames:ownerNames)
                rows.append(RE2RawFieldRow(id:field.id,fieldLabel:fieldLabel,ownerLabel:ownerLabel,
                                           value:field.text,type:field.type,size:field.size,
                                           namedPath:namedPath,rawPath:field.path))
            }
        }
        return RE2RawFieldSearch(matches:matches,rows:rows)
    }
}
