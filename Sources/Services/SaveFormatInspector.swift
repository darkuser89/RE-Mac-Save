import Foundation
import CryptoKit

enum SaveFormatInspector {
    static func inspect(_ scans:[String:ScanResult]) -> [[String:Any]] {
        var results:[[String:Any]]=[]
        let scratch=FileManager.default.temporaryDirectory.appendingPathComponent("RESaveValidation-"+UUID().uuidString)
        do {try FileManager.default.createDirectory(at:scratch,withIntermediateDirectories:true)} catch {return [["error":error.localizedDescription]]}
        defer {try? FileManager.default.removeItem(at:scratch)}
        for game in GameProfile.all {
            for file in scans[game.id]?.files ?? [] {
                var result:[String:Any]=["game":game.id,"path":file.url.path]
                do {
                    let doc=try SaveDocument(file:file,game:game),original=doc.container.original
                    result["roundTrip"]=true;result["objects"]=doc.parsed.objects;result["fields"]=doc.parsed.fields.count
                    if game.id=="re3",file.url.lastPathComponent=="data00-1.bin" {
                        result["charlieHeads"]=doc.charlieFlags.map{["id":$0.number-1,"destroyed":$0.field.initial=="1"]}
                    }
                    result["sha256"]=doc.fingerprint.map{String(format:"%02x",$0)}.joined()
                    var edits:[[String:Any]]=[]
                    for field in doc.editable {
                        let current=Double(field.initial) ?? 0
                        let next=current+1<=Double(field.maximum) ? current+1:max(0,current-1)
                        let input:String
                        if field.isFloating {input=String(next)}
                        else {
                            let stored=try doc.container.payload.uint(field.scalar.offset,field.scalar.size)
                            let increment=stored.addingReportingOverflow(1)
                            let rawNext = !increment.overflow && increment.partialValue<=field.maximum*field.factor ? increment.partialValue:stored-1
                            input=field.display(rawNext)
                        }
                        let raw=try field.rawValue(input)
                        let output=try doc.encodedData([field.id:input])
                        let changed=try SaveContainer(data:output,key:doc.container.key)
                        guard Data(output.prefix(32))==Data(original.prefix(32)) else {throw SaveError.invalid("Konto-Rückprüfung fehlgeschlagen.")}
                        let scalars=[field.scalar]+field.mirrors
                        for scalar in scalars {guard try changed.payload.uint(scalar.offset,scalar.size)==raw else {throw SaveError.invalid("Feld-Rückprüfung fehlgeschlagen.")}}
                        let ranges=scalars.map{$0.offset..<($0.offset+$0.size)}
                        guard changed.payload.count==doc.container.payload.count else {throw SaveError.invalid("Geänderte Nutzdatenlänge.")}
                        guard unchangedOutside(doc.container.payload,changed.payload,excluding:ranges) else {throw SaveError.invalid("Andere Save-Daten wurden verändert.")}
                        guard try doc.changes([:]).isEmpty else {throw SaveError.invalid("Unveränderte Werte werden fälschlich als Änderung erkannt.")}
                        for invalid in (["-1","nan","inf",String(field.maximum+1)]+(field.minimum>0 ? ["0"]:[])) {
                            do {_=try field.rawValue(invalid);throw SaveError.invalid("Ungültige Eingabe wurde akzeptiert.")} catch let failure as SaveError {
                                if failure.localizedDescription=="Ungültige Eingabe wurde akzeptiert." {throw failure}
                            }
                        }
                        // The storage primitive is exercised on one disposable fixture
                        // per editable file. No write is made in a game container.
                        if edits.isEmpty {
                            let fixture=scratch.appendingPathComponent("data001Slot.bin")
                            try original.write(to:fixture)
                            try FileManager.default.setAttributes([.posixPermissions:0o640],ofItemAtPath:fixture.path)
                            try LocalSaveWriter.replaceExisting(at:fixture,expected:doc.fingerprint,output:output) {written in
                                guard try SaveContainer(data:written,key:doc.container.key).payload==changed.payload else {throw SaveError.invalid("Geschriebener Save ist nicht identisch.")}
                            }
                            guard try Data(contentsOf:fixture)==output,
                                  (try FileManager.default.attributesOfItem(atPath:fixture.path)[.posixPermissions] as? NSNumber)?.intValue==0o640 else {throw SaveError.invalid("Dateiaustausch oder Rechteprüfung fehlgeschlagen.")}
                            try original.write(to:fixture)
                            var calls=0,rollbackRejected=false
                            do {try LocalSaveWriter.replaceExisting(at:fixture,expected:doc.fingerprint,output:output) {_ in calls+=1;if calls==2 {throw SaveError.invalid("Absichtlicher Testfehler")}}} catch {rollbackRejected=true}
                            guard rollbackRejected,calls==2,try Data(contentsOf:fixture)==original else {throw SaveError.invalid("Rücknahmeprüfung fehlgeschlagen.")}
                            try FileManager.default.removeItem(at:fixture)
                        }
                        edits.append(["title":field.title,"initial":field.initial,"testInput":input,"verified":true])
                    }
                    if let entry=doc.storedDocuments.first(where:{$0.canEdit && !$0.isRecorded}) ?? doc.storedDocuments.first(where:{$0.canEdit}) {
                        let newValue = !entry.isRecorded
                        let output=try doc.encodedData([:],documents:[entry.id:newValue])
                        let changed=try SaveContainer(data:output,key:doc.container.key)
                        let changedParsed=try ParsedSave(payload:changed.payload)
                        let rows=StoredDocumentCatalog.rows(game:game,source:file,parsed:changedParsed)
                        guard rows.first(where:{$0.id==entry.id})?.isRecorded==newValue else {
                            throw SaveError.invalid("Dokumentstatus nach Teständerung nicht zurückgelesen.")
                        }
                        let fixture=scratch.appendingPathComponent("data001Slot.bin")
                        try original.write(to:fixture)
                        try LocalSaveWriter.replaceExisting(at:fixture,expected:doc.fingerprint,output:output) {written in
                            let verified=try SaveContainer(data:written,key:doc.container.key)
                            let reread=try ParsedSave(payload:verified.payload)
                            guard reread.consumed==verified.payload.count else {throw SaveError.invalid("Dokument-Save konnte nicht vollständig gelesen werden.")}
                        }
                        guard try Data(contentsOf:fixture)==output else {throw SaveError.invalid("Dokument-Änderung auf Testdatei fehlt.")}
                        try FileManager.default.removeItem(at:fixture)
                        result["documentEditVerified"]=["id":entry.id,"initial":entry.isRecorded,"after":newValue,"originalUnchanged":true]
                    }
                    for section in ["Inventar","Itembox"] {
                        if let item=doc.items.first(where:{$0.section==section && $0.identity != nil && $0.quantity != nil}),let identity=item.identity,let quantity=item.quantity {
                            let newID=identity.initial=="1" ? "2":"1"
                            let current=UInt64(quantity.initial) ?? 1
                            let newCount=String(current<quantity.maximum ? current+1:current-1)
                            let output=try doc.encodedData([identity.id:newID,quantity.id:newCount])
                            let changed=try SaveContainer(data:output,key:doc.container.key)
                            guard try changed.payload.uint(identity.scalar.offset,identity.scalar.size)==identity.rawValue(newID),
                                  (try changed.payload.uint(quantity.scalar.offset,quantity.scalar.size))==(try quantity.rawValue(newCount)) else {throw SaveError.invalid("\(section): Gegenstands-ID und Menge wurden nicht gemeinsam zurückgelesen.")}
                            result[section=="Itembox" ? "itemBoxIDAndQuantityVerified":"itemIDAndQuantityVerified"]=true
                        }
                    }
                    let timeFields=doc.timeFields
                    let zeroValues=Dictionary(uniqueKeysWithValues:timeFields.map{($0.id,"0")})
                    if !zeroValues.isEmpty,!(try doc.changes(zeroValues)).isEmpty {
                        let output=try doc.encodedData(zeroValues)
                        let zeroed=try SaveContainer(data:output,key:doc.container.key)
                        for field in timeFields {guard try zeroed.payload.uint(field.scalar.offset,field.scalar.size)==0 else {throw SaveError.invalid("Zeit wurde nicht vollständig zurückgesetzt.")}}
                        let timeRanges=timeFields.map{$0.scalar.offset..<($0.scalar.offset+$0.scalar.size)}
                        guard unchangedOutside(doc.container.payload,zeroed.payload,excluding:timeRanges) else {throw SaveError.invalid("Zeitrücksetzung verändert andere Daten.")}
                        result["timeResetVerified"]=true
                    }
                    result["editable"]=edits;result["editTests"]=edits.count
                    result["diagnostic"]=diagnostic(doc)
                    if game.id=="re7" {
                        if let ids=doc.re7EasterEggIDs {
                            result["re7EasterEggStoredIDs"]=ids
                            let known=Set(RE7EasterEggCatalog.figures.map(\.id))
                            if Set(ids).isSubset(of:known),let figure=RE7EasterEggCatalog.figures.first {
                                let desired = !ids.contains(figure.id)
                                let output=try doc.encodedData([:],figures:[figure.id:desired])
                                let changed=try SaveContainer(data:output,key:doc.container.key)
                                let changedParsed=try ParsedSave(payload:changed.payload)
                                guard RE7EasterEggCatalog.storedIDs(game:game,source:file,parsed:changedParsed,payload:changed.payload)?.contains(figure.id)==desired else {
                                    throw SaveError.invalid("RE7-Figurenstatus nach Teständerung nicht zurückgelesen.")
                                }
                                let fixture=scratch.appendingPathComponent("re7-system.bin")
                                try original.write(to:fixture)
                                try LocalSaveWriter.replaceExisting(at:fixture,expected:doc.fingerprint,output:output) {written in
                                    let verified=try SaveContainer(data:written,key:doc.container.key)
                                    let reread=try ParsedSave(payload:verified.payload)
                                    guard reread.consumed==verified.payload.count else {throw SaveError.invalid("RE7-Figuren-Testdatei konnte nicht vollständig gelesen werden.")}
                                }
                                guard try Data(contentsOf:fixture)==output else {throw SaveError.invalid("RE7-Figuren-Teständerung fehlt.")}
                                try FileManager.default.removeItem(at:fixture)
                                result["re7FigureEditVerified"]=["id":figure.id,"initial":!desired,"after":desired,"originalUnchanged":true]
                                if ids.isEmpty {
                                    let all=Dictionary(uniqueKeysWithValues:RE7EasterEggCatalog.figures.map{($0.id,true)})
                                    let allOutput=try doc.encodedData([:],figures:all)
                                    let allContainer=try SaveContainer(data:allOutput,key:doc.container.key)
                                    let allParsed=try ParsedSave(payload:allContainer.payload)
                                    guard RE7EasterEggCatalog.storedIDs(game:game,source:file,parsed:allParsed,payload:allContainer.payload)?.count==20 else {
                                        throw SaveError.invalid("Nicht alle 20 RE7-Figuren wurden zurückgelesen.")
                                    }
                                    let cleared=try RE7EasterEggCatalog.replace(game:game,source:file,payload:allContainer.payload,parsed:allParsed,desired:Dictionary(uniqueKeysWithValues:RE7EasterEggCatalog.figures.map{($0.id,false)}))
                                    guard cleared==doc.container.payload else {throw SaveError.invalid("RE7-Figurenliste wurde nach dem Ausschalten nicht bytegenau wiederhergestellt.")}
                                    result["re7All20FiguresVerified"]=true
                                }
                            }
                        }
                    }
                    if game.id=="re2" || game.id=="re3" {
                        if game.id=="re2" {
                            result["difficulty"]=doc.difficulty ?? "Nicht im gewählten Save enthalten"
                            result["costumeFieldProbe"]=re2CostumeFields(doc)
                            result["scalarFieldInventory"]=re2ScalarInventory(doc)
                            result["itemDiscoveryProbe"]=re2ItemDiscovery(doc)
                            result["rogueFieldGroups"]=doc.re2RogueFields.map {group in
                                ["name":group.name,"count":group.entries.count,
                                 "values":group.entries.map {["index":$0.index ?? -1,"value":$0.value] as [String:Any]}] as [String:Any]
                            }
                            if let progress=doc.re2SystemProgress {
                                result["recordDetails"]=progress.records.map {record in
                                    ["id":record.id,"cleared":record.cleared,"new":record.newMark,"progress":record.progress] as [String:Any]
                                }
                                result["rewardDetails"]=progress.rewards.map {reward in
                                    ["id":reward.id,"opened":reward.opened,"new":reward.newMark] as [String:Any]
                                }
                            }
                            if let puzzle=doc.re2PuzzleProgress {
                                var values:[String:Any]=[:]
                                if let statue=puzzle.goddessStatue {
                                    values["goddessStatue"]=["medallions":statue.medallions,"stateCode":statue.stateCode] as [String:Any]
                                }
                                if let circuit=puzzle.circuitPuzzle {
                                    values["circuitPuzzle"]=["panelTurns":circuit.panelTurns,"actionCount":circuit.actionCount] as [String:Any]
                                }
                                result["puzzleProgress"]=values
                            }
                            if let mechanisms=doc.re2MechanismProgress {
                                var values:[String:Any]=[
                                    "switches":mechanisms.switches.map {row in
                                        ["index":row.id,"toggle":row.toggled,"applied":row.applied,"finalApplied":row.finalApplied] as [String:Any]
                                    },
                                    "plugs":mechanisms.plugs.map {row in
                                        ["index":row.id,"plugCode":row.plugCode,"initialized":row.initialized] as [String:Any]
                                    }
                                ]
                                if let gear=mechanisms.clockGear {
                                    values["clockGear"]=["topCode":gear.topCode,"bottomCode":gear.bottomCode,
                                                         "initialized":gear.initialized,"firstFlags":gear.firstFlags] as [String:Any]
                                }
                                result["mechanismProgress"]=values
                            }
                            if let environment=doc.re2EnvironmentProgress {
                                var values:[String:Any]=[
                                    "windows":environment.windows.map {row in
                                        ["index":row.id,"hash":String(format:"%08x",row.objectHash),
                                         "mapID":row.mapID,"barricaded":row.barricaded] as [String:Any]
                                    }
                                ]
                                if let tutorials=environment.displayedTutorials {
                                    values["displayedTutorialIDs"]=tutorials.indices.filter {tutorials[$0]}
                                    values["tutorialCount"]=tutorials.count
                                }
                                result["environmentProgress"]=values
                            }
                            if !doc.re2InventoryLayouts.isEmpty {
                                result["inventoryLayouts"]=doc.re2InventoryLayouts.map {profile in
                                    ["profile":profile.id,"survivorCode":profile.survivorCode,
                                     "slotSize":profile.slotSize,"storedSlotSize":profile.storedSlotSize,
                                     "mainSlot":["index":profile.mainSlot.index,"lastWeaponCode":profile.mainSlot.lastWeaponCode],
                                     "savedMainSlot":["index":profile.savedMainSlot.index,"lastWeaponCode":profile.savedMainSlot.lastWeaponCode],
                                     "subWeaponCode":profile.subWeaponCode,"savedSubWeaponCode":profile.savedSubWeaponCode,
                                     "shortcuts":profile.shortcuts.map {shortcut in
                                         ["index":shortcut.id,"kindCode":shortcut.kindCode,
                                          "slotIndex":shortcut.slotIndex.map {$0 as Any} ?? NSNull(),
                                          "lastWeaponCode":shortcut.lastWeaponCode.map {$0 as Any} ?? NSNull()] as [String:Any]
                                     }] as [String:Any]
                                }
                            }
                            if !doc.re2DoorProgress.isEmpty {
                                result["doorProgress"]=doc.re2DoorProgress.map {door in
                                    ["index":door.id,"hash":String(format:"%08x",door.doorHash),
                                     "mapID":door.mapID,"stateCode":door.stateCode] as [String:Any]
                                }
                            }
                        }
                        for section in ["Inventar","Itembox"] {
                            result[section.lowercased()]=doc.items.filter{$0.section==section}.map {item in
                                ["location":item.location,"id":item.itemID,"storedCount":item.storedCount,"canEditID":item.identity != nil,"canEditCount":item.quantity != nil] as [String:Any]
                            }
                        }
                    }
                    guard Data(SHA256.hash(data:try Data(contentsOf:file.url)))==doc.fingerprint else {throw SaveError.invalid("Quelle wurde während der Prüfung geändert.")}
                    result["originalUnchanged"]=true
                } catch {result["error"]=error.localizedDescription;result["roundTrip"]=false}
                results.append(result)
            }
        }
        return results
    }
    private static func unchangedOutside(_ original:Data,_ edited:Data,excluding ranges:[Range<Int>]) -> Bool {
        guard original.count==edited.count else {return false}
        var cursor=0
        for range in ranges.sorted(by:{$0.lowerBound<$1.lowerBound}) {
            guard range.lowerBound>=0,range.upperBound<=original.count else {return false}
            if range.lowerBound>cursor && original[cursor..<range.lowerBound] != edited[cursor..<range.lowerBound] {return false}
            cursor=max(cursor,range.upperBound)
        }
        return original[cursor..<original.count] == edited[cursor..<edited.count]
    }
    private static func re2CostumeFields(_ doc:SaveDocument) -> [[String:Any]] {
        // Read-only field-name candidates from the installed RE2 runtime.
        // A match alone is not an editable costume mapping.
        let candidates=["CostumeID","CostumeId","CurrentCostumeId","CurrentCostume",
            "CostumeLeon","CostumeClaire","CostumeAda","CostumeSherry","CostumeType",
            "CurrentCostumeType","DefaultCostumeType","PlCostumeType","TargetCostume",
            "CostumeBit","CostumeList","CostumeData","CostumeDataList",
            "UserCostumeDataList","CheckedCostumeDataList","ScenarioCostumeDataList",
            "CostumeUserDataList","CostumeParams","CostumeA","CostumeB","_Costume",
            "RequestChangeUserCostumeID","CostumeCondition","CostumeMode","costume_id",
            "m_costume","costume","CostumeSetting","CostumeSettings"]
        let names=Dictionary(uniqueKeysWithValues:candidates.map{(SaveCrypto.murmur(Data($0.utf8)),$0)})
        return doc.parsed.fields.compactMap {field in
            guard let name=names[field.field] else {return nil}
            return ["name":name,"owner":String(format:"%08x",field.owner),"field":String(format:"%08x",field.field),
                    "path":field.path,"type":field.type,"size":field.size,"value":field.text] as [String:Any]
        }
    }
    private static func re2ScalarInventory(_ doc:SaveDocument) -> [[String:Any]] {
        // Read-only digest of every decoded scalar. Text can contain account
        // tokens, so only numeric/Boolean values are included in the report.
        struct Group {
            var count=0
            var values:[String]=[]
            var paths:[String]=[]
            var truncated=false
        }
        var groups:[String:Group]=[:]
        for field in doc.parsed.fields {
            let key=String(format:"%08x.%08x.%d.%d",field.owner,field.field,field.type,field.size)
            var group=groups[key] ?? Group()
            group.count+=1
            if field.type != 15 && !group.values.contains(field.text) {
                if group.values.count<32 {group.values.append(field.text)} else {group.truncated=true}
            }
            if group.paths.count<3 {group.paths.append(field.path)}
            groups[key]=group
        }
        return groups.keys.sorted().map {key in
            let group=groups[key]!
            let parts=key.split(separator:".")
            let names=parts.count==4 ? RE2FieldNameCatalog.names(for:UInt32(parts[1],radix:16) ?? 0):[]
            let owners=parts.count==4 ? RE2OwnerNameCatalog.names(for:UInt32(parts[0],radix:16) ?? 0):[]
            return ["signature":key,"fieldNameCandidates":names,"ownerNameCandidates":owners,
                    "count":group.count,"values":group.values,
                    "valuesTruncated":group.truncated,"samplePaths":group.paths,
                    "sampleNamedPaths":group.paths.map{RE2FieldNameCatalog.labeledPath($0)}] as [String:Any]
        }
    }
    private static func re2ItemDiscovery(_ doc:SaveDocument) -> [[String:Any]] {
        let specs=[("app.ropeway.gamemastering.ItemManager.SystemSaveData","GetItemList"),
                   ("app.ropeway.gamemastering.ItemManager.SystemSaveData","GetWeaponList"),
                   ("app.ropeway.gamemastering.ItemManager.SaveData","IsSearchedItem"),
                   ("app.ropeway.gamemastering.ItemManager.SaveData","ChangedItemName"),
                   ("app.ropeway.gamemastering.ItemManager.SaveData","ChangedItemText"),
                   ("app.ropeway.gamemastering.InventoryManager.SaveData","GetKeyItemEffect"),
                   ("app.ropeway.gamemastering.InventoryManager.SaveData","GetKeyWeaponEffect"),
                   ("app.ropeway.gamemastering.InventoryManager.SaveData","IsCustomWeaponEffect"),
                   ("app.ropeway.gamemastering.InventoryManager.SaveData","IsAddRankItem")]
        return specs.compactMap {owner,name in
            let ownerHash=SaveCrypto.murmur(Data(owner.utf8)),nameHash=SaveCrypto.murmur(Data(name.utf8))
            let matches=doc.parsed.fields.filter{$0.owner==ownerHash && $0.field==nameHash && $0.type==2 && $0.size==1}
            guard !matches.isEmpty else {return nil}
            let trueIndices=matches.compactMap {field -> Int? in
                guard field.text=="true",let open=field.path.lastIndex(of:"["),let close=field.path.lastIndex(of:"]"),open<close else {return nil}
                return Int(field.path[field.path.index(after:open)..<close])
            }
            return ["name":name,"count":matches.count,"trueIndices":trueIndices.sorted()] as [String:Any]
        }
    }
    private static func diagnostic(_ doc:SaveDocument) -> [[String:Any]] {
        // Bounded, named owners only; no complete inventory/player-data dump.
        let owners=["app.SaveData","app.PlayerStatus.PlayerSaveDataClass","app.InGameContentTimer.ContentTimerSave","app.CH9InGameContentTimer.CH9ContentTimerSave","app.ContentTimer.Storage","app.CPManager.SystemSaveData"]
        let names=["PlayTime","RestartCount","Health","Time","Time_pause","CP"]
        let ownerMap=Dictionary(uniqueKeysWithValues:owners.map{(SaveCrypto.murmur(Data($0.utf8)),$0)})
        let nameMap=Dictionary(uniqueKeysWithValues:names.map{(SaveCrypto.murmur(Data($0.utf8)),$0)})
        var result:[[String:Any]]=[]
        for (index,field) in doc.parsed.fields.enumerated() where ownerMap[field.owner] != nil && nameMap[field.field] != nil {
            var row:[String:Any]=["owner":ownerMap[field.owner]!,"name":nameMap[field.field]!,"type":field.type,"value":field.text,"path":field.path]
            if ownerMap[field.owner]=="app.ContentTimer.Storage" && nameMap[field.field]=="Time" {
                row["preceding"]=doc.parsed.fields[max(0,index-5)..<index].map{["owner":String(format:"%08x",$0.owner),"field":String(format:"%08x",$0.field),"type":$0.type,"value":$0.text,"path":$0.path] as [String:Any]}
            }
            result.append(row)
            if result.count>=100 {break}
        }
        return result
    }
}
