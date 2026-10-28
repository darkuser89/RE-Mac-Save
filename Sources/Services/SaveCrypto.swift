// Format reference: gdragotto/re4-mac-save-editor (MIT), see ThirdParty/RE4MacFormat-LICENSE.
import Foundation
import CommonCrypto

enum SaveError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}
extension Data {
    func uint(_ offset: Int, _ width: Int) throws -> UInt64 {
        guard offset >= 0, width > 0, width <= 8, offset <= count-width else { throw SaveError.invalid("Datei ist abgeschnitten oder enthält ungültige Längen.") }
        return (0..<width).reduce(UInt64(0)) { $0 | UInt64(self[offset+$1]) << ($1*8) }
    }
    mutating func put(_ value: UInt64, at offset: Int, width: Int) throws {
        guard offset >= 0, offset <= count-width, width > 0, width <= 8 else { throw SaveError.invalid("Ungültiger Schreibbereich.") }
        for i in 0..<width { self[offset+i] = UInt8(truncatingIfNeeded:value >> (i*8)) }
    }
}
enum SaveCrypto {
    static let re4Key = Data("wa9Ui_tFKa_6E_D5gVChjM69xMKDX8QxEykYKhzb4cRNLknpCZUra".utf8)
    static func rot(_ n: UInt32,_ by: UInt32) -> UInt32 { (n << by) | (n >> (32-by)) }
    static func murmur(_ bytes: Data, seed: UInt32 = 0xffffffff) -> UInt32 {
        var h=seed; let blocks=bytes.count/4
        for i in 0..<blocks {
            var k=UInt32(bytes[i*4]) | UInt32(bytes[i*4+1])<<8 | UInt32(bytes[i*4+2])<<16 | UInt32(bytes[i*4+3])<<24
            k=k &* 0xcc9e2d51; k=rot(k,15); k=k &* 0x1b873593
            h ^= k; h=rot(h,13); h=h &* 5 &+ 0xe6546b64
        }
        if bytes.count%4 != 0 {
            var k:UInt32=0
            for i in 0..<(bytes.count%4) { k |= UInt32(bytes[blocks*4+i]) << (8*i) }
            k=k &* 0xcc9e2d51; k=rot(k,15); k=k &* 0x1b873593; h ^= k
        }
        h ^= UInt32(bytes.count); h ^= h>>16; h=h &* 0x85ebca6b; h ^= h>>13; h=h &* 0xc2b2ae35; h ^= h>>16; return h
    }
    static func swapped(_ data: Data) -> Data {
        var result=Data(count:data.count)
        result.withUnsafeMutableBytes { (output:UnsafeMutableRawBufferPointer) in
            data.withUnsafeBytes { (input:UnsafeRawBufferPointer) in
                for i in stride(from:0,to:data.count,by:4) {
                    output[i]=input[i+3];output[i+1]=input[i+2]
                    output[i+2]=input[i+1];output[i+3]=input[i]
                }
            }
        }
        return result
    }
    static func crypt(_ data:Data,key:Data,encrypt:Bool,ecb:Bool) throws -> Data {
        guard data.count%8==0, (4...56).contains(key.count) else { throw SaveError.invalid("Ungültige Blowfish-Daten.") }
        if data.isEmpty { return data }
        let input=swapped(data); var output=Data(count:data.count+8); var moved=0
        let capacity=output.count
        let status=output.withUnsafeMutableBytes { out in input.withUnsafeBytes { src in key.withUnsafeBytes { k in
            CCCrypt(CCOperation(encrypt ? kCCEncrypt:kCCDecrypt),CCAlgorithm(kCCAlgorithmBlowfish),CCOptions(ecb ? kCCOptionECBMode:0),k.baseAddress,key.count,nil,src.baseAddress,input.count,out.baseAddress,capacity,&moved)
        } } }
        guard status==kCCSuccess,moved==data.count else { throw SaveError.invalid("Verschlüsselung konnte nicht bestätigt werden (\(status)).") }
        return swapped(Data(output.prefix(moved)))
    }
}
struct SaveContainer {
    let original: Data
    let header: Data
    let encryptedIdentity: Data
    let key: Data
    let packedPlaintext:Bool
    var payload: Data
    init(data:Data,key:Data=SaveCrypto.re4Key) throws {
        guard data.count >= 44,data.count <= 64*1024*1024,Data(data.prefix(4))==Data("DSSS".utf8),try data.uint(4,4)==2,try data.uint(8,4)==3,try data.uint(12,4)==3 else { throw SaveError.invalid("Dieses Save-Containerformat wird noch nicht unterstützt.") }
        guard try data.uint(data.count-4,4)==UInt64(SaveCrypto.murmur(Data(data.dropLast(4)))) else { throw SaveError.invalid("Die Prüfsumme stimmt nicht. Datei wurde nicht geöffnet.") }
        guard try SaveCrypto.crypt(Data(data[16..<24]),key:key,encrypt:false,ecb:true)==Data("DSSSDSSS".utf8) else { throw SaveError.invalid("Für dieses Spiel ist noch kein passender macOS-Save-Schlüssel bestätigt.") }
        self.original=data;self.header=Data(data.prefix(16));self.encryptedIdentity=Data(data[16..<32]);self.key=key;self.packedPlaintext=false
        let raw=Data(data[32..<(data.count-4)]);let n=raw.count/8*8
        self.payload=try SaveCrypto.crypt(Data(raw.prefix(n)),key:key,encrypt:false,ecb:false)+Data(raw.dropFirst(n))
    }
    // Only called for an entry of a SHA-256-validated PACK. The document must
    // additionally validate the entire serializer and the known field schema.
    init(packedPlaintext data:Data) throws {
        guard (12...64*1024*1024).contains(data.count) else {throw SaveError.invalid("Nicht unterstützte Größe des Paket-Eintrags.")}
        original=data;header=Data();encryptedIdentity=Data();key=Data();payload=data;packedPlaintext=true
    }
    func encode(allowSizeChange:Bool=false) throws -> Data {
        if packedPlaintext {
            guard !allowSizeChange,payload.count==original.count else {throw SaveError.invalid("Die Paket-Struktur wurde unerwartet verändert.")}
            return payload
        }
        guard payload.count<=64*1024*1024,(allowSizeChange || payload.count==original.count-36) else { throw SaveError.invalid("Die Save-Struktur wurde unerwartet verändert.") }
        let n=payload.count/8*8
        var result=try header+encryptedIdentity+SaveCrypto.crypt(Data(payload.prefix(n)),key:key,encrypt:true,ecb:false)+Data(payload.dropFirst(n))
        let checksum=SaveCrypto.murmur(result);var tail=Data(count:4);try tail.put(UInt64(checksum),at:0,width:4);result+=tail
        guard try SaveContainer(data:result,key:key).payload==payload else { throw SaveError.invalid("Export-Rückprüfung fehlgeschlagen.") }
        return result
    }
}
