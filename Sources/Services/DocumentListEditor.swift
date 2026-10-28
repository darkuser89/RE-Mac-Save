import Foundation

enum DocumentListEditor {
    static func array(game:GameProfile,parsed:ParsedSave) -> SaveArray? {
        let pair:(String,String)
        switch game.id {
        case "re4":pair=("chainsaw.FileManager.SystemSaveData","_EverReadIDs")
        case "re7":pair=("app.FileSaveData","ReleaseFileIds")
        case "re8":pair=("app.FileManager.SaveData","Files")
        default:return nil
        }
        let owner=SaveCrypto.murmur(Data(pair.0.utf8)),field=SaveCrypto.murmur(Data(pair.1.utf8))
        let matches=parsed.arrays.filter{$0.owner==owner && $0.field==field}
        return matches.count==1 ? matches[0]:nil
    }

    static func replace(game:GameProfile,payload:Data,parsed:ParsedSave,desired:[String:Bool],rows:[StoredDocument]) throws -> Data {
        guard let array=array(game:game,parsed:parsed),array.offsetTable==nil,array.elements.count==array.count else {
            throw SaveError.invalid("Die Dokumentliste ist in diesem Spielstand nicht eindeutig bearbeitbar.")
        }
        let permitted=Dictionary(uniqueKeysWithValues:rows.filter(\.canEdit).map{($0.id,$0.isRecorded)})
        guard desired.keys.allSatisfy({permitted[$0] != nil}) else {throw SaveError.invalid("Eine Dokument-ID ist nicht für diesen Spielstand freigegeben.")}
        let existing:[(String,Data)]
        switch game.id {
        case "re4":
            guard array.kind==0,array.elementType==1,array.elementSize==4 else {throw SaveError.invalid("Unbekanntes RE4-Leselistenformat.")}
            existing=try array.elements.map {range in
                guard range.count==4 else {throw SaveError.invalid("Ungültiger RE4-Dokumenteintrag.")}
                let value=try payload.uint(range.lowerBound,4)
                return (String(value),Data(payload[range]))
            }
        case "re7":
            guard array.kind==1,array.elementType==17 else {throw SaveError.invalid("Unbekanntes RE7-Dokumentformat.")}
            let owner=SaveCrypto.murmur(Data("app.FileSaveData.ReleaseFilePlayer".utf8))
            let field=SaveCrypto.murmur(Data("fileId".utf8))
            existing=try array.elements.enumerated().map {index,range in
                let prefix=array.path+"[\(index)]/"
                let matches=parsed.fields.filter{$0.path.hasPrefix(prefix) && $0.owner==owner && $0.field==field && $0.type==15}
                guard matches.count==1 else {throw SaveError.invalid("RE7-Dokumenteintrag ist nicht eindeutig.")}
                return (matches[0].text,Data(payload[range]))
            }
        case "re8":
            guard array.kind==1,array.elementType==17,array.elementSize==8 else {throw SaveError.invalid("Unbekanntes Village-Dokumentformat.")}
            let owner=SaveCrypto.murmur(Data("app.FileManager.SaveData.FileUnit".utf8))
            let field=SaveCrypto.murmur(Data("FileID".utf8))
            existing=try array.elements.enumerated().map {index,range in
                let prefix=array.path+"[\(index)]/"
                let matches=parsed.fields.filter{$0.path.hasPrefix(prefix) && $0.owner==owner && $0.field==field && $0.type==8 && $0.size==4}
                guard matches.count==1,range.contains(matches[0].offset) else {throw SaveError.invalid("Village-Dokumenteintrag ist nicht eindeutig.")}
                return (matches[0].text,Data(payload[range]))
            }
        default:throw SaveError.invalid("Für dieses Spiel fehlt noch eine bestätigte Dokument-ID-Liste.")
        }
        let current=existing.map(\.0)
        guard Set(current).count==current.count else {throw SaveError.invalid("Doppelte Dokument-IDs im Save.")}
        let selected=rows.filter{$0.canEdit && (desired[$0.id] ?? $0.isRecorded) && !current.contains($0.id)}.map(\.id)
        let kept=existing.filter{desired[$0.0] ?? true}.map(\.1)
        let added=try selected.map {id -> Data in
            if game.id=="re4" {
                guard let n=UInt32(id),n<=30000 else {throw SaveError.invalid("Ungültige RE4-Dokument-ID.")}
                var data=Data(count:4);try data.put(UInt64(n),at:0,width:4);return data
            }
            guard permitted[id] != nil else {throw SaveError.invalid("Dokument-ID nicht im geprüften Katalog.")}
            if game.id=="re7" {return try re7Element(id)}
            guard game.id=="re8",let template=array.elements.first else {throw SaveError.invalid("Village benötigt einen vorhandenen Dokumenteintrag als Strukturvorlage.")}
            return try re8Element(id,template:template,payload:payload,parsed:parsed,array:array)
        }
        let replacements=kept+added
        guard replacements.count<=10000 else {throw SaveError.invalid("Zu viele Dokumenteinträge.")}
        let identical=try SaveRebuilder.replaceArray(in:payload,array:array,elements:existing.map(\.1))
        guard identical==payload else {throw SaveError.invalid("Unveränderte Dokumentliste wird nicht bytegenau reproduziert.")}
        let output=try SaveRebuilder.replaceArray(in:payload,array:array,elements:replacements)
        let reread=try ParsedSave(payload:output)
        guard let newArray=self.array(game:game,parsed:reread),newArray.count==replacements.count else {
            throw SaveError.invalid("Dokumentliste wurde nicht vollständig zurückgelesen.")
        }
        let oldOther=parsed.fields.filter{!$0.path.hasPrefix(array.path)}.map{"\($0.path)|\($0.type)|\($0.text)"}
        let newOther=reread.fields.filter{!$0.path.hasPrefix(array.path)}.map{"\($0.path)|\($0.type)|\($0.text)"}
        guard oldOther==newOther else {throw SaveError.invalid("Andere Save-Werte wurden beim Neuaufbau verändert.")}
        let newIDs:[String]
        if game.id=="re4" {
            newIDs=try newArray.elements.map{String(try output.uint($0.lowerBound,4))}
        } else if game.id=="re7" {
            let owner=SaveCrypto.murmur(Data("app.FileSaveData.ReleaseFilePlayer".utf8))
            let field=SaveCrypto.murmur(Data("fileId".utf8))
            newIDs=reread.fields.filter{$0.owner==owner && $0.field==field && $0.path.hasPrefix(newArray.path)}.map(\.text)
        } else {
            let owner=SaveCrypto.murmur(Data("app.FileManager.SaveData.FileUnit".utf8))
            let field=SaveCrypto.murmur(Data("FileID".utf8))
            newIDs=reread.fields.filter{$0.owner==owner && $0.field==field && $0.path.hasPrefix(newArray.path)}.map(\.text)
        }
        guard newIDs==current.filter({desired[$0] ?? true})+selected else {
            throw SaveError.invalid("Dokument-Fundstände stimmen nach dem Neuaufbau nicht überein.")
        }
        return output
    }

    private static func re7Element(_ id:String) throws -> Data {
        guard !id.isEmpty,id.utf16.count<=64 else {throw SaveError.invalid("Ungültige RE7-Dokument-ID.")}
        var result=Data()
        func word(_ value:UInt32) throws {var part=Data(count:4);try part.put(UInt64(value),at:0,width:4);result.append(part)}
        try word(1)
        try word(SaveCrypto.murmur(Data("app.FileSaveData.ReleaseFilePlayer".utf8)))
        try word(SaveCrypto.murmur(Data("fileId".utf8)))
        try word(15)
        try word(UInt32(id.utf16.count))
        for code in id.utf16 {result.append(UInt8(truncatingIfNeeded:code));result.append(UInt8(truncatingIfNeeded:code>>8))}
        while result.count%4 != 0 {result.append(0)}
        return result
    }

    private static func re8Element(_ id:String,template:Range<Int>,payload:Data,parsed:ParsedSave,array:SaveArray) throws -> Data {
        guard let value=UInt32(id),template.count==80 else {throw SaveError.invalid("Ungültige Village-Dokument-ID oder Strukturvorlage.")}
        let owner=SaveCrypto.murmur(Data("app.FileManager.SaveData.FileUnit".utf8))
        let field=SaveCrypto.murmur(Data("FileID".utf8))
        let matches=parsed.fields.filter{$0.path.hasPrefix(array.path+"[0]/") && $0.owner==owner && $0.field==field && $0.type==8 && $0.size==4}
        guard matches.count==1,template.contains(matches[0].offset) else {throw SaveError.invalid("Village-Dokumentvorlage hat keine eindeutige ID.")}
        var element=Data(payload[template]);try element.put(UInt64(value),at:matches[0].offset-template.lowerBound,width:4)
        return element
    }
}
