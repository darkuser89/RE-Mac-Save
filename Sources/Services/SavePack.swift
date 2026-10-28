// Format reference: gdragotto/re4-mac-save-editor (MIT).
import Foundation
import CryptoKit

struct SavePack {
    struct Entry: Identifiable {
        let id: Int32
        let bytes: Data
        var isSave:Bool {Data(bytes.prefix(4))==Data("DSSS".utf8)}
        var title: String {
            id == -1 ? "Systemdaten" : id == 0 ? "Automatischer Spielstand" : "Spielstand \(id)"
        }
    }
    let header: Data
    let entries: [Entry]

    init(data: Data) throws {
        guard data.count >= 64, data.count <= 128*1024*1024,
              Data(data.prefix(4)) == Data("PACK".utf8),
              Data(SHA256.hash(data: data.dropLast(32))) == Data(data.suffix(32)) else {
            throw SaveError.invalid("Das Savepaket ist unvollständig oder seine Prüfsumme stimmt nicht.")
        }
        let count = Int(try data.uint(6, 2))
        let start = 16 + count*16, end = data.count-32
        guard (1...1024).contains(count), start <= end else {
            throw SaveError.invalid("Ungültige Eintragstabelle im Savepaket.")
        }
        var slots = Set<Int32>(), table: [(Int32, Int)] = []
        var totalSize=0
        for index in 0..<count {
            let slot = Int32(bitPattern: UInt32(try data.uint(16+index*16, 4)))
            let size = try data.uint(24+index*16, 8)
            guard slot >= -1, slots.insert(slot).inserted,
                  size >= 44, size <= 64*1024*1024, size <= UInt64(end-start-totalSize) else {
                throw SaveError.invalid("Ungültiger oder doppelter Spielstand im Savepaket.")
            }
            table.append((slot,Int(size)));totalSize+=Int(size)
        }
        // Some writers reserve extra zero-filled header space. Derive its end
        // from the validated sizes and preserve it byte for byte on export.
        let payloadStart=end-totalSize
        guard payloadStart>=start,payloadStart-start<=65536,data[start..<payloadStart].allSatisfy({$0==0}) else {
            throw SaveError.invalid("Nicht unterstützter Paket-Vorspann. Export bleibt gesperrt.")
        }
        var cursor=payloadStart,found:[Entry]=[]
        for (slot,size) in table {
            let blob = Data(data[cursor..<(cursor+size)])
            // Opaque entries can be listed and preserved, but never edited.
            found.append(Entry(id: slot, bytes: blob)); cursor += size
        }
        guard cursor == end else { throw SaveError.invalid("Nicht zugeordnete Daten am Ende des Savepakets.") }
        header = Data(data.prefix(payloadStart)); entries = found
    }

    func encode(replacing slot: Int32? = nil, with replacement: Data? = nil) throws -> Data {
        guard (slot == nil) == (replacement == nil), slot == nil || entries.contains(where: {$0.id == slot}) else {
            throw SaveError.invalid("Der gewählte Spielstand fehlt im Savepaket.")
        }
        if let slot,let replacement,let entry=entries.first(where:{$0.id==slot}),!entry.isSave {
            // Plain serializer entries are accepted only after a full parse on
            // both sides. All-zero/unknown entries can only be preserved.
            let before=try ParsedSave(payload:entry.bytes),after=try ParsedSave(payload:replacement)
            guard before.consumed==entry.bytes.count,after.consumed==replacement.count,!before.fields.isEmpty,before.objects==after.objects,before.fields.count==after.fields.count else {
                throw SaveError.invalid("Ein unbekannter Paket-Eintrag darf nicht bearbeitet werden.")
            }
        }
        var result = header
        for (index, entry) in entries.enumerated() {
            let bytes = entry.id == slot ? replacement! : entry.bytes
            // Field editing never resizes an embedded save or changes account data.
            guard bytes.count == entry.bytes.count else { throw SaveError.invalid("Die Größe des Spielstands wurde verändert.") }
            try result.put(UInt64(bytes.count), at: 24+index*16, width: 8)
        }
        for entry in entries { result += entry.id == slot ? replacement! : entry.bytes }
        result += Data(SHA256.hash(data: result))
        let verified = try SavePack(data: result)
        guard verified.header == header, verified.entries.count == entries.count else {
            throw SaveError.invalid("Rückprüfung des Savepakets fehlgeschlagen.")
        }
        return result
    }
}
