import Foundation

struct DocumentFlag: Identifiable {
    let number: Int
    let title: String
    let field: EditableField
    var id: Int { number }
}

enum DocumentFlagCatalog {
    static let owners=[
        "re2":SaveCrypto.murmur(Data("app.ropeway.gamemastering.UIFileManager.SystemSaveData".utf8)),
        "re3":SaveCrypto.murmur(Data("offline.gamemastering.UIFileManager.SystemSaveData".utf8))
    ]
    static let name = SaveCrypto.murmur(Data("GetFileList".utf8))

    static let bundled: [String:[Int:String]] = {
        var result:[String:[Int:String]]=[:]
        for gameID in ["re2","re3"] {
            guard let url=Bundle.main.url(forResource:"\(gameID.uppercased())FileNames",withExtension:"json") else {continue}
            result[gameID]=try? load(from:url)
        }
        return result
    }()

    static func load(from url:URL) throws -> [Int:String] {
        let decoded=try JSONDecoder().decode([String:String].self,from:Data(contentsOf:url))
        return Dictionary(uniqueKeysWithValues:decoded.compactMap{key,value in Int(key).map{($0,value)}})
    }

    static func flags(game:GameProfile,source:SaveFile,parsed:ParsedSave,titles suppliedTitles:[Int:String]?=nil) -> [DocumentFlag] {
        guard let owner=owners[game.id],source.url.lastPathComponent=="data00-1.bin" else {return []}
        let titles=suppliedTitles ?? bundled[game.id] ?? [:]
        guard !titles.isEmpty else {return []}
        let candidates=parsed.fields.filter{$0.owner==owner && $0.field==name}
        guard candidates.count==90 else {return []}
        var byNumber:[Int:SaveScalar]=[:]
        for scalar in candidates {
            guard scalar.type==2,scalar.size==1,
                  let open=scalar.path.lastIndex(of:"["),scalar.path.last=="]",
                  let number=Int(scalar.path[scalar.path.index(after:open)..<scalar.path.index(before:scalar.path.endIndex)]),
                  (0..<90).contains(number),byNumber[number]==nil,
                  scalar.text=="true" || scalar.text=="false" else {return []}
            byNumber[number]=scalar
        }
        guard byNumber.count==90,byNumber[0]?.text=="false" else {return []}
        return titles.keys.sorted().compactMap {number in
            guard (1..<90).contains(number),let title=titles[number],!title.isEmpty,let scalar=byNumber[number] else {return nil}
            let field=EditableField(id:scalar.id,title:title,description:"\(game.name)-Dokument \(number). Der Fundstatus ist in den lokalen Systemdaten gespeichert.",scalar:scalar,maximum:1,factor:1)
            return DocumentFlag(number:number,title:title,field:field)
        }
    }
}

struct RaccoonFlag: Identifiable {
    let number:Int
    let field:EditableField
    var id:Int {number}
}

enum RaccoonFlagCatalog {
    static let owner=SaveCrypto.murmur(Data("app.ropeway.GimmickRaccoonFigureManager.SystemSaveData".utf8))
    static let name=SaveCrypto.murmur(Data("RaccoonFigureDataList".utf8))
    static func flags(game:GameProfile,source:SaveFile,parsed:ParsedSave) -> [RaccoonFlag] {
        guard game.id=="re2",source.url.lastPathComponent=="data00-1.bin" else {return []}
        let matches=parsed.fields.filter{$0.owner==owner && $0.field==name}
        guard matches.count==20 else {return []}
        var byNumber:[Int:SaveScalar]=[:]
        for scalar in matches {
            guard scalar.type==2,scalar.size==1,scalar.text=="true" || scalar.text=="false",
                  let open=scalar.path.lastIndex(of:"["),scalar.path.last=="]",
                  let number=Int(scalar.path[scalar.path.index(after:open)..<scalar.path.index(before:scalar.path.endIndex)]),
                  (0..<20).contains(number),byNumber[number]==nil else {return []}
            byNumber[number]=scalar
        }
        guard byNumber.count==20 else {return []}
        return (0..<15).compactMap {index in
            guard let scalar=byNumber[index] else {return nil}
            let title="Mr. Raccoon " + String(format:"%02d",index+1)
            return RaccoonFlag(number:index+1,field:EditableField(id:scalar.id,title:title,description:"Figur-ID \(index) in den lokalen RE2-Systemdaten. Der Status gilt spielstandübergreifend.",scalar:scalar,maximum:1,factor:1))
        }
    }
}

struct CharlieFlag: Identifiable {
    let number:Int
    let field:EditableField
    var id:Int {number}
}

struct CastellanFlag: Identifiable {
    let number:Int
    let chapter:Int
    let field:EditableField
    var id:Int {number}
}

enum CastellanFlagCatalog {
    static let owner=SaveCrypto.murmur(Data("chainsaw.GameStatsManager.SystemSaveData".utf8))
    static let name=SaveCrypto.murmur(Data("_ChapterFigures".utf8))
    static let entryOwner=SaveCrypto.murmur(Data("chainsaw.ChapterFigureInfoSave".utf8))
    static let chapterName=SaveCrypto.murmur(Data("_Chapter".utf8))
    static let brokenName=SaveCrypto.murmur(Data("_HasBrokenFigure".utf8))
    static let chapters=[21100,21200,21300,22100,22200,22300,23100,23200,23300,24100,24200,24300,25100,25200,25300,25400]

    static func flags(game:GameProfile,source:SaveFile,parsed:ParsedSave) -> [CastellanFlag] {
        guard game.id=="re4",source.url.lastPathComponent=="data00-1.bin" else {return []}
        let arrays=parsed.arrays.filter{$0.owner==owner && $0.field==name}
        guard arrays.count==1,let array=arrays.first,array.elementType==17,array.elementSize==8,array.count==16,array.kind==1,array.elements.count==16 else {return []}
        let entryPrefix=String(format:"/%08x",entryOwner)
        let chapterSuffix=String(format:".%08x",chapterName)
        let brokenSuffix=String(format:".%08x",brokenName)
        var result:[CastellanFlag]=[]
        for index in 0..<16 {
            let prefix=array.path+"[\(index)]"+entryPrefix
            let chapter=parsed.fields.filter{$0.path==prefix+chapterSuffix && $0.owner==entryOwner && $0.field==chapterName && $0.type==1 && $0.size==4}
            let broken=parsed.fields.filter{$0.path==prefix+brokenSuffix && $0.owner==entryOwner && $0.field==brokenName && $0.type==2 && $0.size==1}
            guard chapter.count==1,chapter[0].text==String(chapters[index]),broken.count==1,
                  broken[0].text=="true" || broken[0].text=="false" else {return []}
            let title="Aufzieh-Kastellan " + String(format:"%02d",index+1)
            let field=EditableField(id:broken[0].id,title:title,description:"RE4-Kapitelcode \(chapters[index]) in den lokalen Systemdaten. Der Zerstörungsstatus gilt spielstandübergreifend.",scalar:broken[0],maximum:1,factor:1)
            result.append(CastellanFlag(number:index+1,chapter:chapters[index],field:field))
        }
        return result
    }
}

enum CharlieFlagCatalog {
    static let owner=SaveCrypto.murmur(Data("offline.EsGimmickBobbingHeadManager.SystemSaveData".utf8))
    static let name=SaveCrypto.murmur(Data("BobbingHeadDataList".utf8))
    static func flags(game:GameProfile,source:SaveFile,parsed:ParsedSave) -> [CharlieFlag] {
        guard game.id=="re3",source.url.lastPathComponent=="data00-1.bin" else {return []}
        let arrays=parsed.arrays.filter{$0.owner==owner && $0.field==name}
        guard arrays.count==1,arrays[0].elementType==2,arrays[0].elementSize==1,arrays[0].count==20,arrays[0].kind==0 else {return []}
        let matches=parsed.fields.filter{$0.owner==owner && $0.field==name}
        guard matches.count==20 else {return []}
        var byNumber:[Int:SaveScalar]=[:]
        for scalar in matches {
            guard scalar.type==2,scalar.size==1,scalar.text=="true" || scalar.text=="false",
                  let open=scalar.path.lastIndex(of:"["),scalar.path.last=="]",
                  let index=Int(scalar.path[scalar.path.index(after:open)..<scalar.path.index(before:scalar.path.endIndex)]),
                  (0..<20).contains(index),byNumber[index]==nil else {return []}
            byNumber[index]=scalar
        }
        guard byNumber.count==20 else {return []}
        return (0..<20).compactMap {index in
            guard let scalar=byNumber[index] else {return nil}
            let title="Charlie-Figur " + String(format:"%02d",index+1)
            return CharlieFlag(number:index+1,field:EditableField(id:scalar.id,title:title,description:"Charlie-Figur mit interner ID \(index) in den lokalen RE3-Systemdaten. Der Status gilt spielstandübergreifend.",scalar:scalar,maximum:1,factor:1))
        }
    }
}

struct DialLockFlag: Identifiable {
    let number:Int
    let field:EditableField
    var id:Int {number}
}

enum DialLockFlagCatalog {
    static let owner=SaveCrypto.murmur(Data("offline.GimmickDialLockManager.SystemSaveData".utf8))
    static let name=SaveCrypto.murmur(Data("LockRecordList".utf8))
    static func flags(game:GameProfile,source:SaveFile,parsed:ParsedSave) -> [DialLockFlag] {
        guard game.id=="re3",source.url.lastPathComponent=="data00-1.bin" else {return []}
        let matches=parsed.fields.filter{$0.owner==owner && $0.field==name}
        guard matches.count==20 else {return []}
        var byNumber:[Int:SaveScalar]=[:]
        for scalar in matches {
            guard scalar.type==2,scalar.size==1,scalar.text=="true" || scalar.text=="false",
                  let open=scalar.path.lastIndex(of:"["),scalar.path.last=="]",
                  let index=Int(scalar.path[scalar.path.index(after:open)..<scalar.path.index(before:scalar.path.endIndex)]),
                  (0..<20).contains(index),byNumber[index]==nil else {return []}
            byNumber[index]=scalar
        }
        guard byNumber.count==20 else {return []}
        return (0..<20).compactMap {index in
            guard let scalar=byNumber[index] else {return nil}
            let title="Schlossstatus " + String(format:"%02d",index+1)
            return DialLockFlag(number:index+1,field:EditableField(id:scalar.id,title:title,description:"Interne Schloss-ID \(index) in den lokalen RE3-Systemdaten. Die Zuordnung zum einzelnen Schloss ist nicht bekannt.",scalar:scalar,maximum:1,factor:1))
        }
    }
}
