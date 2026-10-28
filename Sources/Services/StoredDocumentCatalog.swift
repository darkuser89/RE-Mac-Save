import Foundation

struct StoredDocument: Identifiable {
    let id: String
    let title: String
    let status: String
    let isRecorded: Bool
    let canEdit: Bool
}

enum StoredDocumentCatalog {
    static func load(from url: URL) throws -> [String:String] {
        try JSONDecoder().decode([String:String].self, from:Data(contentsOf:url))
    }

    static let bundled: [String:[String:String]] = {
        var result:[String:[String:String]]=[:]
        for (game,resource) in [("re4","RE4DocumentNames"),("re7","RE7DocumentNames")] {
            if let url=Bundle.main.url(forResource:resource,withExtension:"json") {
                result[game]=try? load(from:url)
            }
        }
        return result
    }()
    static let village:[String:[String:String]] = {
        guard let url=Bundle.main.url(forResource:"RE8DocumentNames",withExtension:"json"),
              let data=try? Data(contentsOf:url),
              let decoded=try? JSONDecoder().decode([String:[String:String]].self,from:data) else {return [:]}
        return decoded
    }()

    static func rows(game:GameProfile,source:SaveFile,parsed:ParsedSave,names suppliedNames:[String:String]?=nil) -> [StoredDocument] {
        func hash(_ value:String) -> UInt32 {SaveCrypto.murmur(Data(value.utf8))}
        let names=suppliedNames ?? bundled[game.id] ?? [:]
        switch game.id {
        case "re4":
            guard source.url.lastPathComponent=="data00-1.bin" else {return []}
            let stored=parsed.fields.filter{$0.owner==hash("chainsaw.FileManager.SystemSaveData") && $0.field==hash("_EverReadIDs") && $0.type==1 && $0.size==4}
            guard DocumentListEditor.array(game:game,parsed:parsed) != nil else {return []}
            let read=Set(stored.compactMap{Int($0.text)})
            let known=names.keys.compactMap(Int.init).sorted().map {number in
                StoredDocument(id:String(number),title:names[String(number)]!,status:read.contains(number) ? "Gelesen":"Kein Lesestatus",isRecorded:read.contains(number),canEdit:true)
            }
            let unknown=read.filter{names[String($0)]==nil}.sorted().map {number in
                StoredDocument(id:String(number),title:"Titel im installierten Textarchiv nicht zugeordnet",status:"Gelesen",isRecorded:true,canEdit:false)
            }
            return known+unknown
        case "re7":
            guard source.url.lastPathComponent != "data00-1.bin" else {return []}
            guard let array=DocumentListEditor.array(game:game,parsed:parsed) else {return []}
            let stored=parsed.fields.filter{$0.owner==hash("app.FileSaveData.ReleaseFilePlayer") && $0.field==hash("fileId") && $0.type==15 && $0.path.hasPrefix(array.path)}
            let found=Set(stored.map(\.text))
            let prefixes=["File_Title_c71_","File_Title_c74_","File_Title_ch8_","CH9_File_Title_","ch07_File_Title_"]
            let activePrefix=prefixes.first{prefix in found.contains(where:{$0.hasPrefix(prefix)})} ?? "File_Title_"
            let known=names.keys.filter{key in
                key.hasPrefix(activePrefix) && (activePrefix != "File_Title_" || !prefixes.contains(where:key.hasPrefix))
            }.sorted().map {key in
                StoredDocument(id:key,title:names[key]!,status:found.contains(key) ? "Im Spielstand gefunden":"Nicht im Spielstand eingetragen",isRecorded:found.contains(key),canEdit:true)
            }
            let unknown=found.filter{names[$0]==nil}.sorted().map {key in
                StoredDocument(id:key,title:"Titel im installierten Textarchiv nicht zugeordnet",status:"Im Spielstand gefunden",isRecorded:true,canEdit:false)
            }
            return known+unknown
        case "re8":
            guard source.url.lastPathComponent != "data00-1.bin" else {return []}
            guard let array=DocumentListEditor.array(game:game,parsed:parsed) else {return []}
            let ids=parsed.fields.filter{$0.owner==hash("app.FileManager.SaveData.FileUnit") && $0.field==hash("FileID") && $0.type==8 && $0.size==4 && $0.path.hasPrefix(array.path)}
            let present=Set(ids.map(\.text))
            let base=village["base"] ?? [:],rose=village["rose"] ?? [:]
            let baseMatches=present.filter{base[$0] != nil}.count,roseMatches=present.filter{rose[$0] != nil}.count
            let selected=roseMatches>baseMatches ? rose:base
            let editable=array.elements.count>0 && array.kind==1 && array.elementType==17 && array.elementSize==8 && array.offsetTable==nil
            let known=selected.keys.sorted{(UInt32($0) ?? 0)<(UInt32($1) ?? 0)}.map {id in
                StoredDocument(id:id,title:selected[id]!,status:present.contains(id) ? "Im Spielstand gefunden":"Nicht im Spielstand eingetragen",isRecorded:present.contains(id),canEdit:editable)
            }
            let unknown=present.filter{selected[$0]==nil}.sorted{(UInt32($0) ?? 0)<(UInt32($1) ?? 0)}.map {id in
                StoredDocument(id:id,title:"Dokument-ID \(id)",status:"Im Spielstand eingetragen",isRecorded:true,canEdit:false)
            }
            return known+unknown
        default:return []
        }
    }
}
