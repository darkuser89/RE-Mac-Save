import Foundation

/// Rewrites serializer alignment after a variable-length document array changes.
/// The untouched serializer is required to reproduce the input byte for byte.
enum SaveRebuilder {
    static func replaceArray(in payload:Data,array:SaveArray,elements:[Data]) throws -> Data {
        guard array.offsetTable==nil,elements.count<=10000,
              elements.allSatisfy({!$0.isEmpty && $0.count<65536}) else {
            throw SaveError.invalid("Diese Dokumentliste kann nicht strukturell bearbeitet werden.")
        }
        let writer=Writer(payload:payload,target:array,replacements:elements)
        let rebuilt=try writer.run()
        guard try ParsedSave(payload:rebuilt).consumed==rebuilt.count else {
            throw SaveError.invalid("Die neu aufgebaute Save-Struktur ist unvollständig.")
        }
        return rebuilt
    }

    private final class Writer {
        let input:Data
        let target:SaveArray
        let replacements:[Data]
        var position=0
        var output=Data()
        var replaced=false

        init(payload:Data,target:SaveArray,replacements:[Data]) {
            input=payload;self.target=target;self.replacements=replacements
            output.reserveCapacity(payload.count+replacements.reduce(0){$0+$1.count})
        }
        func aligned(_ offset:Int,_ width:Int) -> Int {((offset+32+width-1) & ~(width-1))-32}
        func require(_ size:Int) throws {
            guard size>=0,position>=0,position<=input.count-size else {throw SaveError.invalid("Save-Struktur ist abgeschnitten.")}
        }
        func align(_ width:Int) throws {
            guard width>0,width<=4096 else {throw SaveError.invalid("Ungültige Ausrichtung.")}
            let next=aligned(position,width);try require(next-position)
            let original=Data(input[position..<next]);position=next
            let padding=aligned(output.count,width)-output.count
            if padding==original.count {output.append(original)}
            else {output.append(Data(repeating:0,count:padding))}
        }
        func copy(_ size:Int) throws -> Data {
            try require(size)
            let bytes=Data(input[position..<(position+size)])
            output.append(bytes);position+=size
            return bytes
        }
        func u32() throws -> UInt32 {UInt32(try copy(4).uint(0,4))}
        func object(depth:Int) throws {
            guard depth<128 else {throw SaveError.invalid("Save-Verschachtelung ist zu tief.")}
            let count=Int(try u32());_=try u32()
            guard count<=10000 else {throw SaveError.invalid("Ungültige Objektfelder.")}
            for _ in 0..<count {
                _=try u32();let type=Int32(bitPattern:try u32())
                try value(type:type,depth:depth+1)
                try align(4)
            }
        }
        func value(type:Int32,depth:Int) throws {
            switch type {
            case -1:try array(depth:depth)
            case 17:try object(depth:depth)
            case 15:try string()
            default:
                try align(4);let size=Int(try u32())
                try scalar(type:type,size:size,depth:depth)
            }
        }
        func array(depth:Int) throws {
            try align(4)
            let start=position
            let elementType=Int32(bitPattern:try u32()),elementSize=Int(try u32())
            let countOffset=output.count
            let count=Int(try u32()),kind=Int32(bitPattern:try u32())
            guard count>=0,count<=input.count,(kind==0 || kind==1) else {throw SaveError.invalid("Unbekanntes Save-Array bei Offset \(start): Typ \(elementType), Größe \(elementSize), Anzahl \(count), Art \(kind).")}
            if start==target.headerOffset {
                guard !replaced,elementType==target.elementType,elementSize==target.elementSize,
                      count==target.count,kind==target.kind,target.offsetTable==nil else {
                    throw SaveError.invalid("Die Dokumentliste passt nicht zum gelesenen Save.")
                }
                replaced=true
                try output.put(UInt64(replacements.count),at:countOffset,width:4)
                position=target.endOffset
                if kind==0 && elementType==16 && elementSize==16 {
                    guard replacements.allSatisfy({$0.count==16}) else {throw SaveError.invalid("Ungültige Länge einer Figurenkennung.")}
                    for element in replacements {
                        let padding=aligned(output.count,16)-output.count
                        output.append(Data(repeating:0,count:padding))
                        output.append(element)
                    }
                } else {
                    for element in replacements {output.append(element)}
                }
                let padding=aligned(output.count,4)-output.count
                output.append(Data(repeating:0,count:padding))
                return
            }
            if kind==0,elementType==4,elementSize==1,count>100000 {
                _=try copy(count);try align(4);return
            }
            guard count<=1000000 else {throw SaveError.invalid("Zu viele Array-Elemente im Neuaufbau.")}
            if kind==1 {
                let marker=try u32()
                if marker==0xffeeffee {_=try copy(count*4)}
                else {position-=4;output.removeLast(4)}
            }
            for _ in 0..<count {
                if kind==1 {try object(depth:depth+1)}
                else if elementType==15 {try string()}
                else {try scalar(type:elementType,size:elementSize,depth:depth+1)}
            }
            try align(4)
        }
        func string() throws {
            try align(4);let count=Int(try u32())
            guard count<=input.count/2 else {throw SaveError.invalid("Ungültige Textlänge.")}
            _=try copy(count*2)
        }
        func scalar(type:Int32,size:Int,depth:Int) throws {
            if size != 1 {try align(size)}
            if type == -1 {try array(depth:depth);return}
            guard size>=0,size<=input.count else {throw SaveError.invalid("Ungültige Feldgröße.")}
            _=try copy(size)
        }
        func run() throws -> Data {
            while position<input.count-7 {_=try u32();try object(depth:0)}
            if position<input.count {_=try copy(input.count-position)}
            guard replaced else {throw SaveError.invalid("Dokumentliste im Save nicht gefunden.")}
            return output
        }
    }
}
