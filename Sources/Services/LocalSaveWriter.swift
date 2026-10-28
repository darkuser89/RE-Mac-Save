import Foundation
import CryptoKit
import Darwin
import AppKit

enum LocalSaveWriter {
    static func requireStopped(_ game:GameProfile) throws {
        guard NSRunningApplication.runningApplications(withBundleIdentifier:game.bundle).isEmpty else {
            throw SaveError.invalid("\(game.name) läuft noch. Bitte das Spiel vollständig beenden und danach erneut speichern.")
        }
    }
    static func save(document:SaveDocument,values:[Int:String],documents:[String:Bool]=[:],figures:[String:Bool]=[:]) throws -> SaveDocument {
        guard LocalSavePolicy.permitsFile(document.source.url,game:document.game) else {
            throw SaveError.invalid("Speichern ist nur in der lokalen Originaldatei dieses Spiels erlaubt.")
        }
        try requireStopped(document.game)
        let output=try document.encodedData(values,documents:documents,figures:figures)
        let listChanged=try !document.documentChanges(documents).isEmpty || !document.figureChanges(figures).isEmpty
        try replaceExisting(at:document.source.url,expected:document.fingerprint,output:output,beforeSwap:{try requireStopped(document.game)}) {written in
            let verified=try SaveContainer(data:written,key:document.container.key)
            let parsed=try ParsedSave(payload:verified.payload)
            guard parsed.consumed==verified.payload.count else {throw SaveError.invalid("Rückprüfung des gespeicherten Spielstands fehlgeschlagen.")}
            if !listChanged {
                guard parsed.objects==document.parsed.objects,parsed.fields.count==document.parsed.fields.count else {throw SaveError.invalid("Rückprüfung des gespeicherten Spielstands fehlgeschlagen.")}
            }
        }
        let attributes=try document.source.url.resourceValues(forKeys:[.fileSizeKey,.contentModificationDateKey])
        let file=SaveFile(url:document.source.url,size:attributes.fileSize ?? output.count,modified:attributes.contentModificationDate ?? Date(),kind:"DSSS")
        return try SaveDocument(file:file,game:document.game)
    }

    // Storage primitive, also tested against disposable fixtures. Production
    // callers always pass through save(document:values:) and its local policy.
    static func replaceExisting(at source:URL,expected:Data,output:Data,beforeSwap:() throws -> Void = {},verify:(Data) throws -> Void) throws {
        let original=source.standardizedFileURL
        let attributes=try original.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
        guard original.path==original.resolvingSymlinksInPath().path,attributes.isRegularFile==true,attributes.isSymbolicLink != true else {throw SaveError.invalid("Die lokale Save-Datei muss eine reguläre Datei sein.")}
        func unchanged() throws {
            guard Data(SHA256.hash(data:try Data(contentsOf:original)))==expected else {throw SaveError.invalid("Der Spielstand wurde inzwischen geändert. Bitte neu einlesen; es wurde nichts überschrieben.")}
        }
        try unchanged()
        let temporary=original.deletingLastPathComponent().appendingPathComponent(".resave-\(UUID().uuidString).tmp")
        var preserveRecovery=false
        defer {if !preserveRecovery {try? FileManager.default.removeItem(at:temporary)}}
        try output.write(to:temporary,options:.withoutOverwriting)
        // Preserve access controls and extended attributes of the actual save.
        guard copyfile(original.path,temporary.path,nil,copyfile_flags_t(COPYFILE_ACL | COPYFILE_XATTR))==0 else {throw SaveError.invalid("Dateirechte konnten nicht übernommen werden.")}
        let permissions=try FileManager.default.attributesOfItem(atPath:original.path)[.posixPermissions]
        if let permissions {try FileManager.default.setAttributes([.posixPermissions:permissions],ofItemAtPath:temporary.path)}
        guard try Data(contentsOf:temporary)==output else {throw SaveError.invalid("Schreibprüfung der vorbereiteten Datei fehlgeschlagen.")}
        let descriptor=open(temporary.path,O_RDONLY | O_NOFOLLOW)
        guard descriptor>=0 else {throw SaveError.invalid("Vorbereitete Datei konnte nicht geöffnet werden.")}
        let syncResult=fsync(descriptor);close(descriptor)
        guard syncResult==0 else {throw SaveError.invalid("Vorbereitete Datei konnte nicht vollständig gesichert werden.")}
        try verify(output)
        try beforeSwap();try unchanged()
        // Atomic exchange keeps the old file only until readback succeeds.
        guard renamex_np(temporary.path,original.path,UInt32(RENAME_SWAP))==0 else {throw SaveError.invalid("Lokaler Spielstand konnte nicht ersetzt werden: \(String(cString:strerror(errno))).")}
        do {
            guard Data(SHA256.hash(data:try Data(contentsOf:temporary)))==expected else {throw SaveError.invalid("Gleichzeitige Änderung des Spielstands erkannt.")}
            let written=try Data(contentsOf:original)
            guard written==output else {throw SaveError.invalid("Rücklesen des lokalen Spielstands fehlgeschlagen.")}
            try verify(written)
        } catch {
            // Do not overwrite a later edit made by another writer during an
            // error. Retain the sole recovery file in that exceptional case.
            if (try? Data(contentsOf:original))==output,renamex_np(temporary.path,original.path,UInt32(RENAME_SWAP))==0 {throw error}
            preserveRecovery=true
            throw SaveError.invalid("Speichern konnte nicht abgeschlossen werden. Wiederherstellungsdatei: \(temporary.path)")
        }
    }
}
