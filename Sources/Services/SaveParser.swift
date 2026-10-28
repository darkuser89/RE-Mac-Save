// Serializer format adapted from gdragotto/re4-mac-save-editor (MIT).
import Foundation
struct SaveScalar: Identifiable {
    let id:Int
    let owner:UInt32
    let field:UInt32
    let type:Int32
    let offset:Int
    let size:Int
    let path:String
    let text:String
}
struct SaveArray {
    let owner:UInt32
    let field:UInt32
    let path:String
    let headerOffset:Int
    let elementType:Int32
    let elementSize:Int
    let count:Int
    let kind:Int32
    let offsetTable:Int?
    let elements:[Range<Int>]
    let endOffset:Int
}
struct ParsedSave {
    let fields:[SaveScalar]
    let arrays:[SaveArray]
    let objects:Int
    let consumed:Int
    init(payload:Data) throws {
        let reader=SaveReader(payload)
        while reader.position < payload.count-7 {
            _=try reader.u32();try reader.object(path:"",depth:0)
        }
        guard reader.position <= payload.count,payload.count-reader.position < 8 else { throw SaveError.invalid("Unvollständige Save-Struktur.") }
        fields=reader.fields;arrays=reader.arrays;objects=reader.objects;consumed=reader.position
    }
}
private final class SaveReader {
    private static let hexDigits=Array("0123456789abcdef".utf8)
    let bytes:Data
    var position=0
    var fields:[SaveScalar]=[]
    var arrays:[SaveArray]=[]
    var objects=0
    init(_ bytes:Data) {self.bytes=bytes}
    func require(_ size:Int) throws {
        guard size>=0,position>=0,position<=bytes.count-size else {throw SaveError.invalid("Ungültige oder abgeschnittene Save-Struktur.")}
    }
    func align(_ by:Int) throws {
        guard by>0,by<=4096 else {throw SaveError.invalid("Unbekannte Feld-Ausrichtung.")}
        position=((position+32+by-1) & ~(by-1))-32;try require(0)
    }
    func u32() throws -> UInt32 {try require(4);defer{position+=4};return UInt32(try bytes.uint(position,4))}
    func i32() throws -> Int32 {Int32(bitPattern:try u32())}
    func hex8(_ value:UInt32) -> String {
        var bytes=[UInt8](repeating:48,count:8)
        for index in 0..<8 {bytes[7-index]=Self.hexDigits[Int((value >> (index*4)) & 15)]}
        return String(decoding:bytes,as:UTF8.self)
    }
    func object(path:String,depth:Int) throws {
        guard depth<128,objects<200000 else {throw SaveError.invalid("Save-Struktur überschreitet die unterstützte Größe.")}
        let start=position
        let count=Int(try u32()),owner=try u32();guard count<=10000 else {throw SaveError.invalid("Ungültige Feldanzahl bei Offset \(start).")};objects+=1
        let prefix=path+"/"+hex8(owner)+"."
        for _ in 0..<count {
            let name=try u32(),type=try i32();let fieldPath=prefix+hex8(name)
            try value(type:type,owner:owner,name:name,path:fieldPath,depth:depth+1);try align(4)
        }
    }
    func value(type:Int32,owner:UInt32,name:UInt32,path:String,depth:Int) throws {
        switch type {
        case -1:try array(owner:owner,name:name,path:path,depth:depth)
        case 17:try object(path:path,depth:depth)
        case 15:try string(owner:owner,name:name,path:path)
        default:try align(4);let size=Int(try u32());try scalar(type:type,size:size,owner:owner,name:name,path:path,depth:depth)
        }
    }
    func array(owner:UInt32,name:UInt32,path:String,depth:Int) throws {
        guard depth<128 else {throw SaveError.invalid("Zu tief verschachtelte Save-Struktur.")}
        try align(4);let headerOffset=position,type=try i32(),size=Int(try u32()),count=Int(try u32()),kind=try i32()
        guard count<=bytes.count,kind==0 || kind==1 else {throw SaveError.invalid("Unbekannter Array-Typ bei Offset \(position-16): Typ \(type), Größe \(size), Anzahl \(count), Art \(kind).")}
        // RE7 main saves contain a serialized UInt8 binary buffer larger than
        // one million bytes. It has no editable scalar fields; retain it as an
        // opaque, bounds-checked range instead of allocating a field per byte.
        if kind==0,type==4,size==1,count>100000 {
            try require(count);position+=count;try align(4);return
        }
        guard count<=1000000 else {throw SaveError.invalid("Zu viele Array-Elemente.")}
        let raccoonFigures=owner==SaveCrypto.murmur(Data("app.ropeway.GimmickRaccoonFigureManager.SystemSaveData".utf8)) && name==SaveCrypto.murmur(Data("RaccoonFigureDataList".utf8))
        if raccoonFigures {guard type==16,size==1,count==20,kind==0 else {throw SaveError.invalid("Unbekanntes Mr.-Raccoon-Format.")}}
        let dialLockRecords=owner==SaveCrypto.murmur(Data("offline.GimmickDialLockManager.SystemSaveData".utf8)) && name==SaveCrypto.murmur(Data("LockRecordList".utf8))
        if dialLockRecords {guard type==16,size==1,count==20,kind==0 else {throw SaveError.invalid("Unbekanntes RE3-Schlossstatus-Format.")}}
        let charlieHeads=owner==SaveCrypto.murmur(Data("offline.EsGimmickBobbingHeadManager.SystemSaveData".utf8)) && name==SaveCrypto.murmur(Data("BobbingHeadDataList".utf8))
        if charlieHeads {guard type==2,size==1,count==20,kind==0 else {throw SaveError.invalid("Unbekanntes RE3-Charlie-Format.")}}
        let castellans=owner==SaveCrypto.murmur(Data("chainsaw.GameStatsManager.SystemSaveData".utf8)) && name==SaveCrypto.murmur(Data("_ChapterFigures".utf8))
        if castellans {guard type==17,size==8,count==16,kind==1 else {throw SaveError.invalid("Unbekanntes RE4-Kastellanen-Format.")}}
        let re7EasterEggs=owner==SaveCrypto.murmur(Data("app.SystemData".utf8)) && name==SaveCrypto.murmur(Data("EasterEggSaveDataList".utf8))
        let interesting=raccoonFigures || dialLockRecords || charlieHeads || castellans || re7EasterEggs ||
            (owner==SaveCrypto.murmur(Data("chainsaw.FileManager.SystemSaveData".utf8)) && name==SaveCrypto.murmur(Data("_EverReadIDs".utf8))) ||
            (owner==SaveCrypto.murmur(Data("app.FileSaveData".utf8)) && name==SaveCrypto.murmur(Data("ReleaseFileIds".utf8))) ||
            (owner==SaveCrypto.murmur(Data("app.FileManager.SaveData".utf8)) && name==SaveCrypto.murmur(Data("Files".utf8)))
        var offsetTable:Int?=nil
        if kind==1 {if try u32()==0xffeeffee {offsetTable=position;try require(count*4);position+=count*4} else {position-=4}}
        var elements:[Range<Int>]=[]
        for i in 0..<count {
            let start=position
            let element=path+"[\(i)]"
            if kind==1 {try object(path:element,depth:depth+1)}
            else if type==15 {try string(owner:owner,name:name,path:element)}
            else if raccoonFigures || dialLockRecords || charlieHeads {
                try require(1)
                let value=bytes[position]
                guard value<=1 else {throw SaveError.invalid("Ungültiger Sammelstatus.")}
                try append(owner:owner,name:name,type:2,offset:position,size:1,path:element,text:value==0 ? "false":"true")
                position+=1
            }
            else {try scalar(type:type,size:size,owner:owner,name:name,path:element,depth:depth+1)}
            if interesting {elements.append(start..<position)}
        }
        try align(4)
        if interesting {arrays.append(SaveArray(owner:owner,field:name,path:path,headerOffset:headerOffset,elementType:type,elementSize:size,count:count,kind:kind,offsetTable:offsetTable,elements:elements,endOffset:position))}
    }
    func string(owner:UInt32,name:UInt32,path:String) throws {
        try align(4);let count=Int(try u32());guard count<=bytes.count/2 else {throw SaveError.invalid("Ungültige Textlänge.")};try require(count*2)
        let text=String(data:Data(bytes[position..<(position+count*2)]),encoding:.utf16LittleEndian) ?? ""
        try append(owner:owner,name:name,type:15,offset:position,size:count*2,path:path,text:text);position+=count*2
    }
    func append(owner:UInt32,name:UInt32,type:Int32,offset:Int,size:Int,path:String,text:String) throws {
        guard fields.count<1500000 else {throw SaveError.invalid("Zu viele Save-Felder.")}
        fields.append(SaveScalar(id:fields.count,owner:owner,field:name,type:type,offset:offset,size:size,path:path,text:text))
    }
    func scalar(type:Int32,size:Int,owner:UInt32,name:UInt32,path:String,depth:Int) throws {
        if size != 1 {try align(size)}
        if type == -1 {try array(owner:owner,name:name,path:path,depth:depth);return}
        if type==16 {try require(size);position+=size;return}
        let widths:[Int32:Int]=[2:1,3:1,4:1,5:2,6:2,7:4,8:4,9:8,10:8,11:4,12:8,13:1,14:2]
        let n=type==1 ? size : widths[type] ?? 0
        guard [1,2,4,8].contains(n),n==size else {throw SaveError.invalid("Unbekannter skalierter Feldtyp \(type), Größe \(size).")}
        try require(n);let raw=try bytes.uint(position,n);let text:String
        if owner==SaveCrypto.murmur(Data("chainsaw.ChapterFigureInfoSave".utf8)) && name==SaveCrypto.murmur(Data("_HasBrokenFigure".utf8)) && raw>1 {throw SaveError.invalid("Ungültiger Aufzieh-Kastellanen-Status.")}
        if type==11 {let v=Float(bitPattern:UInt32(raw));text=String(v)}
        else if type==12 {text=String(Double(bitPattern:raw))}
        else if type==2 {text=raw==0 ? "false":"true"}
        else if [1,3,5,7,9].contains(type) {let signed=Int64(bitPattern:raw << (64-n*8)) >> (64-n*8);text=String(signed)}
        else {text=String(raw)}
        try append(owner:owner,name:name,type:type,offset:position,size:n,path:path,text:text);position+=n
    }
}
