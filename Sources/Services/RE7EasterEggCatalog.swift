import Foundation

/// The installed campaign scenes contain 20 BlueCoin objects with distinct
/// sibling app.OtherObjectSave.SaveGUID values. An additional football doll
/// has no BlueCoin component and is excluded. The installed type metadata
/// identifies EasterEggSaveDataList as List<System.Guid>; a before/after
/// collectible save is still needed to confirm the runtime relationship.
enum RE7EasterEggCatalog {
    struct Figure:Identifiable {
        let number:Int
        let location:String
        /// Serialized System.Guid bytes in the original little-endian order.
        let id:String
    }

    static let owner=SaveCrypto.murmur(Data("app.SystemData".utf8))
    static let name=SaveCrypto.murmur(Data("EasterEggSaveDataList".utf8))
    static let figures:[Figure]=[
        Figure(number:1,location:"Haupthaus West 1",id:"a1f1286eab1b0b47b1eb70321b957368"),
        Figure(number:2,location:"Haupthaus West 2",id:"56aad3dea8c12f45a4f27d78bded3036"),
        Figure(number:3,location:"Haupthaus West 3",id:"8f5e82bbf900764a9869a1cc3cb4f641"),
        Figure(number:4,location:"Haupthaus West 4",id:"2cadead5938c064d88e3f191b6eb749e"),
        Figure(number:5,location:"Haupthaus-Halle",id:"52bcf9fe0af9c14ea50b49fbadb02ad5"),
        Figure(number:6,location:"Haupthaus Ost 1",id:"f908fc66cbdabf4cb903a73181cf75d5"),
        Figure(number:7,location:"Haupthaus Ost 2",id:"b5b1bf1133e5e20b3a971637648d4cfe"),
        Figure(number:8,location:"Hof",id:"e7768f3a8d8576428faec9555c69895d"),
        Figure(number:9,location:"Altes Haus 1",id:"b7b150e4ab26bc4bbe5ddba259ee77bf"),
        Figure(number:10,location:"Altes Haus 2",id:"c1ed5aa8d0f3694f9bac5ecfb29784f0"),
        Figure(number:11,location:"Altes Haus 3",id:"442875e68f7d9a4e8d785f257e313304"),
        Figure(number:12,location:"Altes Haus 4",id:"2b9597ed2066f14ab5d4b57b9826a684"),
        Figure(number:13,location:"Lucas-Bereich",id:"f7d2b8c06e6706063b6c553ed797c962"),
        Figure(number:14,location:"Stall",id:"b7db2c60c8b5734fbcf96d3159315c62"),
        Figure(number:15,location:"Bootshaus",id:"3fea553e72c9c30233d33f4294b7cbbf"),
        Figure(number:16,location:"Schiff 4F",id:"56da35aeb6988b081b89f914f303e59f"),
        Figure(number:17,location:"Schiff 3F",id:"3a443da74db8fe4c889d16544bbf9693"),
        Figure(number:18,location:"Sumpf nach dem Schiff",id:"2d623e7605798c4f8cb6eb48d47e186c"),
        Figure(number:19,location:"Salzmine",id:"e7c55cae3878ad42b7c888317748a196"),
        Figure(number:20,location:"Gästehaus-Rückkehr",id:"bd306a8211ccca4cb7e7b96a14c257ee")
    ]

    static func array(game:GameProfile,source:SaveFile,parsed:ParsedSave) -> SaveArray? {
        guard game.id=="re7",source.url.lastPathComponent=="data00-1.bin" else {return nil}
        let matches=parsed.arrays.filter{$0.owner==owner && $0.field==name}
        guard matches.count==1,let array=matches.first,array.elementType==16,array.elementSize==16,
              array.kind==0,array.offsetTable==nil,array.count<=20,array.elements.count==array.count else {return nil}
        return array
    }

    static func storedIDs(game:GameProfile,source:SaveFile,parsed:ParsedSave,payload:Data) -> [String]? {
        guard let array=array(game:game,source:source,parsed:parsed) else {return nil}
        var ids:[String]=[]
        for range in array.elements {
            guard range.count>=16,range.upperBound<=payload.count else {return nil}
            let bytes=payload[(range.upperBound-16)..<range.upperBound]
            ids.append(bytes.map{String(format:"%02x",$0)}.joined())
        }
        guard Set(ids).count==ids.count else {return nil}
        return ids
    }

    static func rawBytes(_ id:String) throws -> Data {
        guard id.count==32 else {throw SaveError.invalid("Ungültige RE7-Figuren-ID.")}
        var bytes=[UInt8]()
        var index=id.startIndex
        for _ in 0..<16 {
            let next=id.index(index,offsetBy:2)
            guard let byte=UInt8(id[index..<next],radix:16) else {throw SaveError.invalid("Ungültige RE7-Figuren-ID.")}
            bytes.append(byte);index=next
        }
        return Data(bytes)
    }

    static func replace(game:GameProfile,source:SaveFile,payload:Data,parsed:ParsedSave,desired:[String:Bool]) throws -> Data {
        guard let array=array(game:game,source:source,parsed:parsed),
              let existing=storedIDs(game:game,source:source,parsed:parsed,payload:payload) else {
            throw SaveError.invalid("Die RE7-Figurenliste ist nicht eindeutig bearbeitbar.")
        }
        let known=Set(figures.map(\.id))
        guard Set(existing).isSubset(of:known),Set(desired.keys).isSubset(of:known),figures.count==20,known.count==20 else {
            throw SaveError.invalid("Unbekannte Figurenkennung im RE7-Systemsave.")
        }
        let kept=existing.filter{desired[$0] ?? true}
        let added=figures.map(\.id).filter{desired[$0]==true && !existing.contains($0)}
        let expected=kept+added
        let originalElements=try existing.map(rawBytes)
        guard try SaveRebuilder.replaceArray(in:payload,array:array,elements:originalElements)==payload else {
            throw SaveError.invalid("Die unveränderte RE7-Figurenliste lässt sich nicht bytegenau reproduzieren.")
        }
        let output=try SaveRebuilder.replaceArray(in:payload,array:array,elements:expected.map(rawBytes))
        let reread=try ParsedSave(payload:output)
        guard storedIDs(game:game,source:source,parsed:reread,payload:output)==expected else {
            throw SaveError.invalid("RE7-Figurenstatus nach dem Neuaufbau nicht zurückgelesen.")
        }
        let oldOther=parsed.fields.filter{!$0.path.hasPrefix(array.path)}.map{"\($0.path)|\($0.type)|\($0.text)"}
        let newOther=reread.fields.filter{!$0.path.hasPrefix(array.path)}.map{"\($0.path)|\($0.type)|\($0.text)"}
        guard oldOther==newOther else {throw SaveError.invalid("Andere RE7-Save-Werte wurden verändert.")}
        return output
    }
}
