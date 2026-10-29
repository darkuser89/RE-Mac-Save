import Foundation
import CryptoKit
struct GameProfile:Identifiable,Hashable {
    let id:String;let name:String;let bundle:String
    var container:URL {FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/\(bundle)/Data")}
    var nativeUUID:String {["re2":"4C4C44ED-5555-3144-A15E-9285028AFD15","re3":"4C4C4461-5555-3144-A174-EA43301DB10B","re4":"4C4C44CF-5555-3144-A161-D64EFB82E79F","re7":"4C4C4466-5555-3144-A1F6-0D461A1E2960","re8":"4C4C44EB-5555-3144-A1A1-B2C9A3FC8945"][id] ?? ""}
    static let all=[GameProfile(id:"re2",name:"Resident Evil 2",bundle:"jp.co.capcom.RE2US"),GameProfile(id:"re3",name:"Resident Evil 3",bundle:"jp.co.capcom.RE3US"),GameProfile(id:"re4",name:"Resident Evil 4",bundle:"jp.co.capcom.RE4US"),GameProfile(id:"re7",name:"Resident Evil 7",bundle:"jp.co.capcom.RE7US"),GameProfile(id:"re8",name:"Resident Evil Village",bundle:"jp.co.capcom.VillageUS")]
}
struct SaveFile:Identifiable,Hashable {
    var id:String {url.path};let url:URL;let size:Int;let modified:Date;let kind:String;var character:String?=nil
    var title:String {
        let n=url.lastPathComponent.lowercased()
        if n=="data00-1.bin" {return "Systemdaten"}
        if n=="data000.bin" {return "Automatischer Spielstand"+(character.map{" · \($0)"} ?? "")}
        if n.contains("slot"),let index=Int(n.filter(\.isNumber)) {return "Spielstand \(index)"+(character.map{" · \($0)"} ?? "")}
        return url.lastPathComponent
    }
}
struct ScanResult {var files:[SaveFile]=[];var denied:[URL]=[];var searched:[URL]=[]}
struct SaveDocument {
    var container:SaveContainer
    let parsed:ParsedSave
    let source:SaveFile
    let fingerprint:Data
    let game:GameProfile
    let editable:[EditableField]
    let items:[SaveInventory.ItemRow]
    let re2ItemHistory:[RE2ItemHistory]
    let re2WeaponUse:[RE2WeaponUse]
    let re2InventoryLayouts:[RE2InventoryLayout]
    let re2CostumeStates:[RE2CostumeState]
    let re2ProgressFlags:[RE2ProgressFlags]
    let re2SystemMetadata:[RE2SystemMetadata]
    let re2SystemOptions:[RE2SystemOption]
    let re2TofuTimes:[RE2TofuClearTime]
    let re2SystemProgress:RE2SystemProgress?
    let re2ClearRecords:[RE2ClearRecord]
    let re2MapProgress:[RE2MapProgress]
    let re2MapMarkers:[RE2MapMarkerGroup]
    let re2MapParts:[RE2MapPart]
    let re2DoorProgress:[RE2DoorProgress]
    let re2PuzzleProgress:RE2PuzzleProgress?
    let re2MechanismProgress:RE2MechanismProgress?
    let re2TriggerProgress:RE2TriggerProgress?
    let re2EnemyState:RE2EnemyState?
    let re2EnvironmentProgress:RE2EnvironmentProgress?
    let re2RunFlags:[RE2RunFlag]
    let re2RogueFields:[RE2RogueFieldGroup]
    let fileFlags:[DocumentFlag]
    let raccoonFlags:[RaccoonFlag]
    let castellanFlags:[CastellanFlag]
    let charlieFlags:[CharlieFlag]
    let dialLockFlags:[DialLockFlag]
    let storedDocuments:[StoredDocument]
    let re7EasterEggIDs:[String]?
    let difficulty:String?
    let character:String?
    let re2SaveHeader:RE2SaveHeader?
    init(file:SaveFile,game:GameProfile) throws {
        guard LocalSavePolicy.permitsFile(file.url,game:game),file.kind=="DSSS" else {throw SaveError.invalid("Nur lokale DSSS-Spielstände im SaveData-Ordner dieses Spiels sind erlaubt.")}
        let size=try file.url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard (44...128*1024*1024).contains(size) else {throw SaveError.invalid("Nicht unterstützte Dateigröße.")}
        let data=try Data(contentsOf:file.url)
        container=try SaveContainer(data:data,key:SaveKeys.key(for:game))
        parsed=try ParsedSave(payload:container.payload)
        source=file;fingerprint=Data(SHA256.hash(data:data));self.game=game
        guard parsed.consumed==container.payload.count,try container.encode()==container.original else {throw SaveError.invalid("Die vollständige unveränderte Rückverschlüsselung stimmt nicht überein.")}
        character=game.id=="re2" ? RE2Character.name(fields:parsed.fields):nil
        re2SaveHeader=RE2SaveHeaderCatalog.details(game:game,fields:parsed.fields,character:character)
        if game.id=="re2" {
            let owner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.MainFlowManager.GameHeaderSaveData".utf8))
            let name=SaveCrypto.murmur(Data("CurrentDifficulty".utf8))
            let matches=parsed.fields.filter{$0.owner==owner && $0.field==name && $0.type==1 && $0.size==4}
            if matches.count==1,let value=Int(matches[0].text) {
                difficulty=[0:"Einfach",1:"Standard",2:"Hardcore"][value].map{"\($0) (Code \(value))"} ?? "Unbekannter Wert \(value)"
            } else {difficulty=nil}
        } else {difficulty=nil}
        items=SaveInventory.rows(game:game,parsed:parsed)
        re2ItemHistory=RE2ItemHistoryCatalog.lists(game:game,source:file,fields:parsed.fields)
        re2WeaponUse=RE2WeaponUseCatalog.entries(game:game,fields:parsed.fields,character:character)
        re2InventoryLayouts=RE2InventoryLayoutCatalog.profiles(game:game,source:file,fields:parsed.fields,character:character)
        re2CostumeStates=RE2CostumeStateCatalog.states(game:game,fields:parsed.fields)
        re2ProgressFlags=RE2ProgressFlagCatalog.lists(game:game,source:file,fields:parsed.fields)
        re2SystemMetadata=RE2SystemMetadataCatalog.entries(game:game,source:file,fields:parsed.fields)
        re2SystemOptions=RE2SystemArrayCatalog.options(game:game,source:file,fields:parsed.fields)
        re2TofuTimes=RE2SystemArrayCatalog.tofuTimes(game:game,source:file,fields:parsed.fields)
        re2SystemProgress=RE2SystemProgressCatalog.details(game:game,source:file,fields:parsed.fields)
        re2ClearRecords=RE2ClearRecordCatalog.records(game:game,source:file,fields:parsed.fields)
        re2MapProgress=RE2MapProgressCatalog.summaries(game:game,fields:parsed.fields,character:character)
        re2MapMarkers=RE2MapMarkerCatalog.groups(game:game,source:file,fields:parsed.fields,character:character)
        re2MapParts=RE2MapPartCatalog.entries(game:game,source:file,fields:parsed.fields,character:character)
        re2DoorProgress=RE2DoorProgressCatalog.entries(game:game,source:file,fields:parsed.fields,character:character)
        re2PuzzleProgress=RE2PuzzleProgressCatalog.details(game:game,source:file,fields:parsed.fields,character:character)
        re2MechanismProgress=RE2MechanismProgressCatalog.details(game:game,source:file,fields:parsed.fields,character:character)
        re2TriggerProgress=RE2TriggerProgressCatalog.details(game:game,source:file,fields:parsed.fields,character:character)
        re2EnemyState=RE2EnemyStateCatalog.details(game:game,source:file,fields:parsed.fields,character:character)
        re2EnvironmentProgress=RE2EnvironmentProgressCatalog.details(game:game,source:file,fields:parsed.fields,character:character)
        re2RunFlags=RE2RunFlagCatalog.flags(game:game,fields:parsed.fields,character:character)
        re2RogueFields=RE2RogueProgressCatalog.groups(game:game,source:file,fields:parsed.fields)
        fileFlags=DocumentFlagCatalog.flags(game:game,source:file,parsed:parsed)
        raccoonFlags=RaccoonFlagCatalog.flags(game:game,source:file,parsed:parsed)
        castellanFlags=CastellanFlagCatalog.flags(game:game,source:file,parsed:parsed)
        charlieFlags=CharlieFlagCatalog.flags(game:game,source:file,parsed:parsed)
        dialLockFlags=DialLockFlagCatalog.flags(game:game,source:file,parsed:parsed)
        storedDocuments=StoredDocumentCatalog.rows(game:game,source:file,parsed:parsed)
        re7EasterEggIDs=RE7EasterEggCatalog.storedIDs(game:game,source:file,parsed:parsed,payload:container.payload)
        editable=try SaveSchemas.fields(game:game,parsed:parsed)+items.compactMap(\.identity)+items.compactMap(\.quantity)+fileFlags.map(\.field)+raccoonFlags.map(\.field)+castellanFlags.map(\.field)+charlieFlags.map(\.field)+dialLockFlags.map(\.field)
    }
    var timeFields:[EditableField] {
        let names:[String]
        switch game.id {
        case "re2","re3":names=["_GameElapsedTime","_DemoSpendingTime","_InventorySpendingTime","_PauseSpendingTime"]
        case "re4":names=["_GameElapsedTime","_DemoSpendingTime","_InventorySpendingTime","_PauseSpendingTime"]
        case "re7":names=["PlayTime"]
        case "re8":names=["Time","Time_pause"]
        default:names=[]
        }
        let hashes=Set(names.map{SaveCrypto.murmur(Data($0.utf8))})
        return editable.filter{hashes.contains($0.scalar.field)}
    }
    func changes(_ values:[Int:String]) throws -> [(EditableField,UInt64)] {
        var result:[(EditableField,UInt64)]=[]
        for field in editable {
            let value=values[field.id] ?? field.initial
            let raw=try field.rawValue(value)
            if try ([field.scalar]+field.mirrors).contains(where:{try container.payload.uint($0.offset,$0.size) != raw}) {result.append((field,raw))}
        }
        if ["re2","re3","re4"].contains(game.id),timeFields.count==4,result.contains(where:{entry in timeFields.contains{$0.id==entry.0.id}}) {
            let totalHash=SaveCrypto.murmur(Data("_GameElapsedTime".utf8))
            let clocks=try timeFields.map{($0.scalar.field,try $0.rawValue(values[$0.id] ?? $0.initial))}
            let total=clocks.first{$0.0==totalHash}!.1
            let parts=clocks.filter{$0.0 != totalHash}.reduce(UInt64(0)){$0+$1.1}
            guard total>=parts else {throw SaveError.invalid("Die Gesamt-Spieluhr darf nicht kleiner als ihre Zeitanteile sein. Verwende zum vollständigen Zurücksetzen „Spielzeit auf 0 vormerken“.")}
        }
        if game.id=="re8",timeFields.count==2,result.contains(where:{entry in timeFields.contains{$0.id==entry.0.id}}) {
            let time=try timeFields[0].rawValue(values[timeFields[0].id] ?? timeFields[0].initial)
            let pause=try timeFields[1].rawValue(values[timeFields[1].id] ?? timeFields[1].initial)
            guard Double(bitPattern:time)>=Double(bitPattern:pause) else {throw SaveError.invalid("Die Spieluhr darf nicht kleiner als ihr Pausenanteil sein. Verwende zum Zurücksetzen „Spielzeit auf 0 vormerken“.")}
        }
        return result
    }
    func documentChanges(_ states:[String:Bool]) throws -> [StoredDocument] {
        let permitted=Dictionary(uniqueKeysWithValues:storedDocuments.filter(\.canEdit).map{($0.id,$0.isRecorded)})
        guard states.keys.allSatisfy({permitted[$0] != nil}) else {throw SaveError.invalid("Unbekannter Dokument-Schalter.")}
        return storedDocuments.filter{$0.canEdit && (states[$0.id] ?? $0.isRecorded) != $0.isRecorded}
    }
    func figureChanges(_ states:[String:Bool]) throws -> [RE7EasterEggCatalog.Figure] {
        guard let existing=re7EasterEggIDs else {
            if states.isEmpty {return []}
            throw SaveError.invalid("Dieser Save enthält keine bearbeitbare RE7-Figurenliste.")
        }
        let known=Set(RE7EasterEggCatalog.figures.map(\.id))
        guard Set(existing).isSubset(of:known),Set(states.keys).isSubset(of:known) else {
            throw SaveError.invalid("Unbekannte Figurenkennung im RE7-Systemsave.")
        }
        return RE7EasterEggCatalog.figures.filter{(states[$0.id] ?? existing.contains($0.id)) != existing.contains($0.id)}
    }
    func encodedData(_ values:[Int:String],documents states:[String:Bool]=[:],figures figureStates:[String:Bool]=[:]) throws -> Data {
        let updates=try changes(values)
        let documentUpdates=try documentChanges(states)
        let figureUpdates=try figureChanges(figureStates)
        guard !updates.isEmpty || !documentUpdates.isEmpty || !figureUpdates.isEmpty else {throw SaveError.invalid("Noch keine Änderung vorgemerkt.")}
        var edited=container
        for (field,value) in updates {for scalar in [field.scalar]+field.mirrors {try edited.payload.put(value,at:scalar.offset,width:scalar.size)}}
        if !documentUpdates.isEmpty {
            let editedParsed=try ParsedSave(payload:edited.payload)
            edited.payload=try DocumentListEditor.replace(game:game,payload:edited.payload,parsed:editedParsed,desired:states,rows:storedDocuments)
        }
        if !figureUpdates.isEmpty {
            let editedParsed=try ParsedSave(payload:edited.payload)
            edited.payload=try RE7EasterEggCatalog.replace(game:game,source:source,payload:edited.payload,parsed:editedParsed,desired:figureStates)
        }
        let encoded=try edited.encode(allowSizeChange:!documentUpdates.isEmpty || !figureUpdates.isEmpty)
        let verified=try SaveContainer(data:encoded,key:container.key)
        let parsed=try ParsedSave(payload:verified.payload)
        guard parsed.consumed==verified.payload.count else {throw SaveError.invalid("Die Save-Struktur ist nach der Bearbeitung unvollständig.")}
        if documentUpdates.isEmpty && figureUpdates.isEmpty {
            guard parsed.objects==self.parsed.objects,parsed.fields.count==self.parsed.fields.count else {throw SaveError.invalid("Die Save-Struktur ist nach der Bearbeitung nicht identisch.")}
        }
        if !figureUpdates.isEmpty,let original=re7EasterEggIDs {
            let expected=Set(original).subtracting(figureStates.filter{!$0.value}.map(\.key)).union(figureStates.filter{$0.value}.map(\.key))
            guard Set(RE7EasterEggCatalog.storedIDs(game:game,source:source,parsed:parsed,payload:verified.payload) ?? [])==expected else {
                throw SaveError.invalid("RE7-Figurenstatus wurde nach dem Verschlüsseln nicht zurückgelesen.")
            }
        }
        for (field,value) in updates {
            for scalar in [field.scalar]+field.mirrors {
                let matches=parsed.fields.filter{$0.path==scalar.path && $0.owner==scalar.owner && $0.field==scalar.field && $0.type==scalar.type}
                guard matches.count==1,try verified.payload.uint(matches[0].offset,matches[0].size)==value else {throw SaveError.invalid("Ein bearbeitetes Feld konnte nicht zurückgelesen werden.")}
            }
        }
        return encoded
    }
}
