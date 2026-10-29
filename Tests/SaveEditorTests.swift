import Foundation
import CryptoKit
func check(_ value:Bool,_ message:String) {if !value {fatalError(message)}}
func rejected(_ message:String,_ action:() throws -> Void) {do {try action();fatalError("Nicht abgelehnt: "+message)} catch {}}
@main struct Tests {
 static func main() throws {
    let names = try ItemNameCatalog.load(from: URL(fileURLWithPath: ProcessInfo.processInfo.environment["RESAVE_ITEM_NAMES"]!))
    check(names.entry(gameID:"re2",itemID:"32")?.name=="Farbband","RE2-Name aus Spieltext")
    check(names.entry(gameID:"re2",itemID:"Waffe 46")?.name=="Kampfmesser","RE2-Waffe aus Spieltext")
    check(names.entry(gameID:"re4",itemID:"112800000")?.name=="Pistolenmunition","RE4-Name aus Spieltext")
    check(names.entry(gameID:"re7",itemID:"MiaDriversLicense")?.name=="Führerschein","RE7-Name aus Spieltext")
    check(names.entry(gameID:"re8",itemID:"1179972000")==nil,"Unbekannte Village-ID bleibt ohne geratenen Namen")
    let re2RecordDetails=try RE2RecordTextCatalog.load(from:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE2_RECORD_DETAILS"]!))
    check(re2RecordDetails.count==87 && re2RecordDetails[58]?.title=="Schatzjäger" &&
          re2RecordDetails[0]?.title=="Einwohner von Raccoon City" &&
          re2RecordDetails[19]?.objective=="Töten Sie 10 Gegner mit einer Pistole." &&
          re2RecordDetails[75]?.catalogValue==14000 &&
          [86,87,89,90].allSatisfy{re2RecordDetails[$0]==nil},
          "RE2-Rekorde über Katalog-GUIDs zugeordnet; unbelegte IDs bleiben namenlos")
    let re2RewardDetails=try RE2RewardTextCatalog.load(from:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE2_REWARD_DETAILS"]!))
    check(re2RewardDetails.count==98 && re2RewardDetails[37]?.name=="Raccoon City A" &&
          re2RewardDetails[55]?.name=="Leon (Freizeit)" &&
          re2RewardDetails[114]?.name=="Robert und Emma Kendo" &&
          re2RewardDetails[0]==nil && re2RewardDetails[132]==nil,
          "RE2-Figuren und Konzeptgrafiken über native Belohnungs-IDs zugeordnet")
    let re2FieldNames=try RE2FieldNameCatalog.load(from:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE2_FIELD_NAMES"]!))
    check(re2FieldNames.count==319 && re2FieldNames["9d58d1c7"]==["id"] && re2FieldNames["f7ec3e63"]==["HP"] && re2FieldNames["9074a186"]==["SystemSaveDataList"],"RE2-Skalar- und Pfadfeldnamen aus installiertem Build")
    check(re2FieldNames["ad69cc16"]==["HeightExpand","LastSavedTimeStamp"],"RE2-Hashkollision wird nicht geraten")
    let re2OwnerNames=try RE2OwnerNameCatalog.load(from:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE2_OWNER_NAMES"]!))
    check(re2OwnerNames.count==109 &&
          re2OwnerNames["4e4210f9"]==["app.ropeway.gamemastering.RecordManager.SystemSaveData"] &&
          re2OwnerNames["2f11c239"]==["app.ropeway.CostumeManager.SystemSaveData"] &&
          re2OwnerNames["2a3b1ae0"]==["app.ropeway.CostumeManager.CostumeData"] &&
          re2OwnerNames["00215d66"]==["via.userdata.Variable"] &&
          re2OwnerNames["2675722d"]==["app.ropeway.gamemastering.InventoryManager.PrimitiveItem"] &&
          re2OwnerNames["55d1d375"]==["app.ropeway.gamemastering.InventoryManager.ItemExData"] &&
          re2OwnerNames["2b1634eb"]==["via.storage.saveService.SaveFileDetail"] &&
          re2OwnerNames["090ff53c"]==["app.ropeway.gamemastering.UIMapManager.SaveData"] &&
          re2OwnerNames["b6f9870b"]==["app.ropeway.gamemastering.RogueRecordManager.RogueSystemSaveData"] &&
          re2OwnerNames["162a6b99"]==["app.ropeway.gamemastering.RogueAccessoryManager.RogueSystemSaveData"] &&
          re2OwnerNames["c5ab2ae2"]==["app.ropeway.rogue.GimmickRogueRaccoonFigureManager.RogueSystemSaveData"],
          "RE2-Besitzernamen aus nativen Klassen- und Namespace-Zeichenketten")
    check(re2OwnerNames["b15a035f"]?.count==2,"Mehrdeutiger RE2-Besitzerhash behält beide Kandidaten")
    let labeledCostumePath=RE2FieldNameCatalog.labeledPath("/9e0932a9.9074a186[6]/2f11c239.0c0cda67[0]/2a3b1ae0.6686824e",fieldNames:re2FieldNames,ownerNames:re2OwnerNames)
    check(labeledCostumePath.contains("SystemSaveDataList[6]") && labeledCostumePath.contains("UserCostumeDataList[0]") && labeledCostumePath.hasSuffix("app.ropeway.CostumeManager.CostumeData.CostumeID"),"RE2-Pfad zeigt belegte Listen- und Typnamen")
    check(RE2FieldNameCatalog.labeledPath("/b15a035f.695a3627[0]",fieldNames:re2FieldNames,ownerNames:re2OwnerNames)=="/b15a035f._Data[0]","Mehrdeutiger Besitzer wird im lesbaren Pfad nicht geraten")
    let numericProbe=SaveScalar(id:0,owner:0x4e4210f9,field:0xf7ec3e63,type:7,offset:0,size:4,
                                path:"/9e0932a9.9074a186[7]/4e4210f9.f7ec3e63",text:"42")
    let privateTextProbe=SaveScalar(id:1,owner:0x4e4210f9,field:0xf7ec3e63,type:15,offset:4,size:16,
                                    path:"/9e0932a9.9074a186[7]/4e4210f9.f7ec3e63[1]",text:"account-data")
    let rawFields=[numericProbe,privateTextProbe]
    check(RE2RawFieldCatalog.numericCount(rawFields)==1,"RE2-Feldsuche zählt ausschließlich Zahlen- und Bool-Felder")
    check(RE2RawFieldCatalog.textCount(rawFields)==1,"RE2-Feldsuche zählt Textfeld-Strukturen getrennt")
    let rawMatch=RE2RawFieldCatalog.search(rawFields,query:"HP",fieldNames:re2FieldNames,ownerNames:re2OwnerNames)
    check(rawMatch.matches==2 && rawMatch.rows.first?.fieldLabel=="HP" && rawMatch.rows.first?.value=="42" &&
          rawMatch.rows.first?.namedPath.contains("SystemSaveDataList[7]")==true &&
          rawMatch.rows.last?.value=="Textwert verborgen" && rawMatch.rows.last?.type==15,
          "RE2-Feldsuche zeigt native Namen und Textfeld-Struktur ohne Textwert")
    check(RE2RawFieldCatalog.search(rawFields,query:"account-data",fieldNames:re2FieldNames,ownerNames:re2OwnerNames).matches==0,
          "RE2-Feldsuche sucht nicht in Textwerten mit möglichen Kontodaten")
    let textOnly=RE2RawFieldCatalog.search(rawFields,query:"#text",fieldNames:re2FieldNames,ownerNames:re2OwnerNames)
    check(textOnly.matches==1 && textOnly.rows[0].value=="Textwert verborgen" &&
          !textOnly.rows[0].namedPath.contains("account-data"),
          "RE2-Textfeld-Strukturen getrennt suchbar, ohne gespeicherten Text")
    let bounded=RE2RawFieldCatalog.search(rawFields,query:"42",limit:0,fieldNames:re2FieldNames,ownerNames:re2OwnerNames)
    check(bounded.matches==2 && bounded.rows.isEmpty,"RE2-Feldsuche begrenzt Anzeige ohne Trefferverlust")
    func re2StatusFields(_ owner:String,_ name:String,_ count:Int,_ set:Set<Int>) -> [SaveScalar] {
        let ownerHash=SaveCrypto.murmur(Data(owner.utf8)),fieldHash=SaveCrypto.murmur(Data(name.utf8))
        return (0..<count).map {index in
            SaveScalar(id:index,owner:ownerHash,field:fieldHash,type:2,offset:index,size:1,
                       path:"/\(String(format:"%08x",ownerHash)).\(String(format:"%08x",fieldHash))[\(index)]",
                       text:set.contains(index) ? "true":"false")
        }
    }
    let re2Game=GameProfile.all.first{$0.id=="re2"}!
    let re2System=SaveFile(url:URL(fileURLWithPath:"/private/tmp/data00-1.bin"),size:0,modified:Date(),kind:"DSSS")
    let re2Campaign=SaveFile(url:URL(fileURLWithPath:"/private/tmp/data001Slot.bin"),size:0,modified:Date(),kind:"DSSS")
    let re2ThirdSlot=SaveFile(url:URL(fileURLWithPath:"/private/tmp/data003Slot.bin"),size:0,modified:Date(),kind:"DSSS")
    let re2Rogue=SaveFile(url:URL(fileURLWithPath:"/private/tmp/data021Slot.bin"),size:0,modified:Date(),kind:"DSSS")
    check(RE2CampaignSavePolicy.matches(game:re2Game,source:re2Campaign,character:"Leon") &&
          RE2CampaignSavePolicy.matches(game:re2Game,source:re2ThirdSlot,character:"Leon") &&
          !RE2CampaignSavePolicy.matches(game:re2Game,source:re2ThirdSlot,character:nil) &&
          !RE2CampaignSavePolicy.matches(game:re2Game,source:re2Rogue,character:"Leon"),
          "Alle bestätigten RE2-Kampagnenslots zuordnen, Zusatzmodus und unklare Figur ausschließen")
    func re2SystemFields(_ name:String,_ count:Int,_ type:Int32,_ values:[Int:String]) -> [SaveScalar] {
        let hash=SaveCrypto.murmur(Data(name.utf8))
        return (0..<count).map {index in
            SaveScalar(id:index,owner:0x4e4210f9,field:hash,type:type,offset:index*(type==2 ? 1:4),size:type==2 ? 1:4,
                       path:String(format:"/9e0932a9.9074a186[7]/4e4210f9.%08x[%d]",hash,index),
                       text:values[index] ?? (type==2 ? "false":"0"))
        }
    }
    let recordFields=re2SystemFields("IsClearedRecord",91,2,[3:"true"])
        + re2SystemFields("IsNewClearedRecord",91,2,[3:"true"])
        + re2SystemFields("RecordProgressNumber",91,7,[3:"12"])
        + re2SystemFields("IsOpenedReward",133,2,[8:"true"])
        + re2SystemFields("IsNewReward",133,2,[8:"true"])
    let recordDetails=RE2SystemProgressCatalog.details(game:re2Game,source:re2System,fields:recordFields)
    check(recordDetails?.records.count==91 && recordDetails?.rewards.count==133 &&
          recordDetails?.records[3].cleared==true && recordDetails?.records[3].newMark==true &&
          recordDetails?.records[3].progress==12 && recordDetails?.rewards[8].opened==true &&
          recordDetails?.rewards[8].newMark==true,
          "RE2-Rekord- und Belohnungsstatus nach gespeicherter ID lesen")
    check(RE2SystemProgressCatalog.details(game:re2Game,source:re2Campaign,fields:recordFields)==nil,
          "Rekorddetails nicht einem Kampagnensave zuordnen")
    check(RE2SystemProgressCatalog.details(game:re2Game,source:re2System,fields:recordFields+[recordFields[0]])==nil,
          "Doppelte RE2-Rekord-ID ausblenden")
    check(RE2SystemProgressCatalog.details(game:re2Game,source:re2System,fields:Array(recordFields.dropFirst()))==nil,
          "Unvollständige RE2-Rekordliste ausblenden")
    let roguePrefix="/3f25bafa.a9a2c119[1]/b6f9870b."
    let rogueRecordHash=SaveCrypto.murmur(Data("IsClearedRogueRecord".utf8))
    let rogueRecords=(0..<15).map {index in
        SaveScalar(id:index,owner:0xb6f9870b,field:rogueRecordHash,type:2,offset:index,size:1,
                   path:roguePrefix+String(format:"%08x[%d]",rogueRecordHash,index),text:index==3 ? "true":"false")
    }
    let roguePlayHash=SaveCrypto.murmur(Data("RoguePlayCount".utf8))
    let roguePlay=SaveScalar(id:15,owner:0xb6f9870b,field:roguePlayHash,type:7,offset:15,size:4,
                             path:roguePrefix+String(format:"%08x",roguePlayHash),text:"2")
    let rogueGroups=RE2RogueProgressCatalog.groups(game:re2Game,source:re2Rogue,fields:rogueRecords+[roguePlay],names:re2FieldNames)
    check(rogueGroups.count==2 && rogueGroups.first(where:{$0.name=="IsClearedRogueRecord"})?.markedCount==1 &&
          rogueGroups.first(where:{$0.name=="RoguePlayCount"})?.entries.first?.value=="2",
          "RE2-Zusatzmodus liest indizierte Flags und Einzelzähler nur lesend")
    check(RE2RogueProgressCatalog.groups(game:re2Game,source:re2Campaign,fields:rogueRecords,names:re2FieldNames).isEmpty,
          "Rogue-Daten nicht einem Kampagnensave zuordnen")
    check(RE2RogueProgressCatalog.groups(game:re2Game,source:re2Rogue,fields:rogueRecords+[rogueRecords[0]],names:re2FieldNames).isEmpty,
          "Doppelte Rogue-Status-ID ausblenden")
    let wrongRogueIndex=rogueRecords.map {scalar in
        SaveScalar(id:scalar.id,owner:scalar.owner,field:scalar.field,type:scalar.type,offset:scalar.offset,
                   size:scalar.size,path:scalar.path.replacingOccurrences(of:"a9a2c119[1]",with:"a9a2c119[0]"),text:scalar.text)
    }
    check(RE2RogueProgressCatalog.groups(game:re2Game,source:re2Rogue,fields:wrongRogueIndex,names:re2FieldNames).isEmpty,
          "Falschen Zusatzmodus-Listenindex nicht als gespeicherte Werte anzeigen")
    let goddessOwner=SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickGoddessStatue.SaveData".utf8))
    let circuitOwner=SaveCrypto.murmur(Data("app.ropeway.gimmick.action.GimmickCircuitPuzzle.SaveData".utf8))
    let goddessParent="/7f9decbe.8aab887b[23]/8413308a.34be46bd[75]/6f42ff0a.1bd539fc"
    let circuitParent="/7f9decbe.8aab887b[23]/8413308a.34be46bd[287]/80b16114.1bd539fc"
    let medalHash=SaveCrypto.murmur(Data("HasMedal".utf8))
    let stateHash=SaveCrypto.murmur(Data("State".utf8))
    let turnHash=SaveCrypto.murmur(Data("PanelTurn".utf8))
    let actionHash=SaveCrypto.murmur(Data("ActionCount".utf8))
    let medalFields=(0..<3).map {index in
        SaveScalar(id:index,owner:goddessOwner,field:medalHash,type:2,offset:index,size:1,
                   path:goddessParent+String(format:"/%08x.%08x[%d]",goddessOwner,medalHash,index),
                   text:index==1 ? "true":"false")
    }
    let goddessState=SaveScalar(id:3,owner:goddessOwner,field:stateHash,type:1,offset:3,size:4,
                                path:goddessParent+String(format:"/%08x.%08x",goddessOwner,stateHash),text:"1")
    let panelFields=(0..<16).map {index in
        SaveScalar(id:index+4,owner:circuitOwner,field:turnHash,type:7,offset:index*4,size:4,
                   path:circuitParent+String(format:"/%08x.%08x[%d]",circuitOwner,turnHash,index),
                   text:String(index%4))
    }
    let circuitActions=SaveScalar(id:20,owner:circuitOwner,field:actionHash,type:7,offset:64,size:4,
                                  path:circuitParent+String(format:"/%08x.%08x",circuitOwner,actionHash),text:"18")
    let puzzleFields=medalFields+[goddessState]+panelFields+[circuitActions]
    let puzzle=RE2PuzzleProgressCatalog.details(game:re2Game,source:re2Campaign,fields:puzzleFields,character:"Leon")
    check(puzzle?.goddessStatue?.medallions==[false,true,false] && puzzle?.goddessStatue?.stateCode==1 &&
          puzzle?.circuitPuzzle?.panelTurns.count==16 && puzzle?.circuitPuzzle?.panelTurns[3]==3 &&
          puzzle?.circuitPuzzle?.actionCount==18,
          "RE2-Göttinnenstatue und Schaltkreisrätsel nur aus gepaarten Spielobjekten lesen")
    check(RE2PuzzleProgressCatalog.details(game:re2Game,source:re2System,fields:puzzleFields,character:nil)==nil,
          "Rätselstände nicht der Systemdatei zuordnen")
    check(RE2PuzzleProgressCatalog.details(game:re2Game,source:re2Campaign,fields:puzzleFields+[medalFields[0]],character:"Leon")?.goddessStatue==nil,
          "Doppelte Medaillon-ID ausblenden")
    let foreignState=SaveScalar(id:3,owner:goddessOwner,field:stateHash,type:1,offset:3,size:4,
                                path:goddessParent.replacingOccurrences(of:"[75]",with:"[76]")+String(format:"/%08x.%08x",goddessOwner,stateHash),text:"1")
    check(RE2PuzzleProgressCatalog.details(game:re2Game,source:re2Campaign,fields:medalFields+[foreignState],character:"Leon")==nil,
          "Unterschiedliche Göttinnenstatuen-Objekte nicht zusammenführen")
    let doorOwner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.UIMapManager.DoorInfo".utf8))
    let doorPrefix="/7f9decbe.8aab887b[8]/090ff53c.cb78b1f4/b15a035f.695a3627["
    let doorSpecs:[(String,Int32,String)]=[("_Hash",8,"12345"),("_MapId",1,"0"),("_State",1,"2")]
    let doorFields=(0..<2).flatMap {index in
        doorSpecs.enumerated().map {offset,spec in
            let field=SaveCrypto.murmur(Data(spec.0.utf8))
            return SaveScalar(id:index*3+offset,owner:doorOwner,field:field,type:spec.1,
                              offset:index*12+offset*4,size:4,
                              path:doorPrefix+"\(index)]"+String(format:"/%08x.%08x",doorOwner,field),
                              text:spec.0=="_Hash" ? String(12345+index):spec.2)
        }
    }
    let doorRows=RE2DoorProgressCatalog.entries(game:re2Game,source:re2Campaign,fields:doorFields,character:"Leon")
    check(doorRows.count==2 && doorRows[0].doorHash==12345 && doorRows[1].id==1 && doorRows[1].stateCode==2,
          "RE2-Türstatus aus vollständigen, gepaarten Kartendatensätzen lesen")
    check(RE2DoorProgressCatalog.entries(game:re2Game,source:re2System,fields:doorFields,character:nil).isEmpty,
          "Türstatus nicht dem Systemsave zuordnen")
    check(RE2DoorProgressCatalog.entries(game:re2Game,source:re2Campaign,fields:doorFields+[doorFields[0]],character:"Leon").isEmpty,
          "Doppeltes Türfeld ausblenden")
    check(RE2DoorProgressCatalog.entries(game:re2Game,source:re2Campaign,fields:Array(doorFields.dropLast()),character:"Leon").isEmpty,
          "Unvollständigen Türdatensatz ausblenden")
    let markerSpecs:[(String,String,String,[(String,Int32,String)])]=[
        ("app.ropeway.gamemastering.UIMapManager.ItemLockerInfo","itemLockerData",
         "/7f9decbe.8aab887b[8]/090ff53c.00c7b7b6/b2f815e5.695a3627[",
         [("_Hash",8,"200"),("_MapId",1,"112"),("_SlotNum",8,"400")]),
        ("app.ropeway.gamemastering.UIMapManager.GimmickInfo","gimmickData",
         "/7f9decbe.8aab887b[8]/090ff53c.0031712c/f4f012fc.695a3627[",
         [("_Hash",8,"250"),("_MapId",1,"118")]),
        ("app.ropeway.gamemastering.UIMapManager.TypewriterInfo","typewriterData",
         "/7f9decbe.8aab887b[8]/090ff53c.d1a4c8f8/dd9eb20d.695a3627[",
         [("_Hash",8,"300"),("_MapId",1,"120")])]
    var markerFields:[SaveScalar]=[]
    for (ownerName,_,prefix,fields) in markerSpecs {
        let owner=SaveCrypto.murmur(Data(ownerName.utf8))
        for index in 0..<2 {
            for (name,type,value) in fields {
                let hash=SaveCrypto.murmur(Data(name.utf8))
                let text=name=="_Hash" ? String((Int(value) ?? 0)+index):value
                markerFields.append(SaveScalar(id:markerFields.count+400,owner:owner,field:hash,type:type,
                                               offset:markerFields.count*4,size:4,
                                               path:prefix+"\(index)]"+String(format:"/%08x.%08x",owner,hash),text:text))
            }
        }
    }
    let markerGroups=RE2MapMarkerCatalog.groups(game:re2Game,source:re2Campaign,fields:markerFields,character:"Leon")
    check(markerGroups.count==3 && markerGroups[0].id=="itemLockerData" &&
          markerGroups[0].markers.map(\.objectHash)==[200,201] && markerGroups[0].markers[0].slotNumber==400 &&
          markerGroups[1].id=="gimmickData" && markerGroups[1].markers[0].mapID==118 &&
          markerGroups[2].id=="typewriterData" && markerGroups[2].markers[1].mapID==120,
          "RE2-Kartenobjekte nur aus vollständigen, gleichnamigen Datensätzen lesen")
    check(RE2MapMarkerCatalog.groups(game:re2Game,source:re2System,fields:markerFields,character:nil).isEmpty,
          "Kartenobjekte nicht Systemdaten zuordnen")
    check(RE2MapMarkerCatalog.groups(game:re2Game,source:re2Campaign,fields:markerFields+[markerFields[0]],character:"Leon").map(\.id)==["gimmickData","typewriterData"],
          "Doppelte Itemschrank-Felder ausblenden")
    check(RE2MapMarkerCatalog.groups(game:re2Game,source:re2Campaign,fields:Array(markerFields.dropLast()),character:"Leon").map(\.id)==["itemLockerData","gimmickData"],
          "Unvollständige Schreibmaschinen-Datensätze ausblenden")
    let mapPartOwner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.UIMapManager.MapPartsChangeInfo".utf8))
    let mapPartPrefix="/7f9decbe.8aab887b[8]/090ff53c.d584af3a/0e13127e.ef5095c4["
    let mapPartFields=(0..<64).flatMap {index -> [SaveScalar] in
        let parent=mapPartPrefix+"\(index)]"
        return [("State",Int32(1),4,String(index)),("Done",Int32(2),1,index==3 ? "true":"false")].enumerated().map {offset,spec in
            let field=SaveCrypto.murmur(Data(spec.0.utf8))
            return SaveScalar(id:800+index*2+offset,owner:mapPartOwner,field:field,type:spec.1,
                              offset:800+index*8+offset*4,size:spec.2,
                              path:parent+String(format:"/%08x.%08x",mapPartOwner,field),text:spec.3)
        }
    }
    let mapParts=RE2MapPartCatalog.entries(game:re2Game,source:re2Campaign,fields:mapPartFields,character:"Leon")
    check(mapParts.count==64 && mapParts[3].done && mapParts[3].stateCode==3 && !mapParts[63].done,
          "RE2-Kartenbauteile nur aus 64 vollständigen State/Done-Paaren lesen")
    check(RE2MapPartCatalog.entries(game:re2Game,source:re2System,fields:mapPartFields,character:nil).isEmpty,
          "Kartenbauteile nicht Systemdaten zuordnen")
    check(RE2MapPartCatalog.entries(game:re2Game,source:re2Campaign,fields:Array(mapPartFields.dropLast()),character:"Leon").isEmpty,
          "Unvollständige Kartenbauteil-Liste ausblenden")
    check(RE2MapPartCatalog.entries(game:re2Game,source:re2Campaign,fields:mapPartFields+[mapPartFields[0]],character:"Leon").isEmpty,
          "Doppelte Kartenbauteil-Werte ausblenden")
    func mechanism(_ ownerName:String,_ fieldName:String,_ type:Int32,_ text:String,_ parent:String,_ id:Int,arrayIndex:Int?=nil) -> SaveScalar {
        let owner=SaveCrypto.murmur(Data(ownerName.utf8))
        let field=SaveCrypto.murmur(Data(fieldName.utf8))
        return SaveScalar(id:id,owner:owner,field:field,type:type,offset:id*4,size:type==2 ? 1:4,
                          path:parent+String(format:"/%08x.%08x",owner,field)+(arrayIndex.map {"[\($0)]"} ?? ""),text:text)
    }
    let switchName="app.ropeway.gimmick.action.GimmickToggleSwitch.SaveData"
    let plugName="app.ropeway.gimmick.action.GimmickPlugPlaceControl.SaveData"
    let clockName="app.ropeway.gimmick.action.GimmickClockGearControl.SaveData"
    let autoDoorName="app.ropeway.gimmick.action.GimmickAutoDoor.SaveData"
    let wiringName="app.ropeway.gimmick.action.GimmickWiringNodeBase.SaveData"
    let elevatorName="app.ropeway.gimmick.action.GimmickElevator.SaveData"
    let shelfName="app.ropeway.gimmick.action.GimmickMobileBookShelf.SaveData"
    let movableName="app.ropeway.gimmick.action.GimmickRigidBodySavable.SaveData"
    let fanName="app.ropeway.gimmick.action.GimmickFanForOvercurrent.SaveData"
    let rigidName="app.ropeway.gimmick.action.GimmickRigidbody.SaveData"
    let gateName="app.ropeway.gimmick.action.GimmickPlugGateControl.SaveData"
    let bulkheadName="app.ropeway.gimmick.action.GimmickLaboratoryBulkhead.SaveData"
    let shutterName="app.ropeway.gimmick.action.GimmickShutterG2Break.SaveData"
    let topboardName="app.ropeway.gimmick.action.GimmickTopboard.SaveData"
    let switchParent="/7f9decbe.8aab887b[23]/8413308a.34be46bd[42]/6fa91e18.1bd539fc"
    let plugParent="/7f9decbe.8aab887b[23]/8413308a.c81a3eff[91]/29a21e52.1bd539fc"
    let clockParent="/7f9decbe.8aab887b[23]/8413308a.c81a3eff[83]/a288cd46.1bd539fc"
    let switchFields=[mechanism(switchName,"Toggle",2,"true",switchParent,300),
                      mechanism(switchName,"_isToggleApply",2,"true",switchParent,301),
                      mechanism(switchName,"_isToggleEndApply",2,"false",switchParent,302)]
    let plugFields=[mechanism(plugName,"nowPlug",1,"3",plugParent,303),
                    mechanism(plugName,"isInitPlug",2,"true",plugParent,304)]
    let clockFields=[mechanism(clockName,"nowTop",1,"2",clockParent,305),
                     mechanism(clockName,"nowBottom",1,"1",clockParent,306),
                     mechanism(clockName,"isInitGear",2,"true",clockParent,307)]
    let firstHash=SaveCrypto.murmur(Data("isFirst".utf8))
    let clockOwner=SaveCrypto.murmur(Data(clockName.utf8))
    let firstFields=(0..<4).map {index in
        SaveScalar(id:308+index,owner:clockOwner,field:firstHash,type:2,offset:308+index,size:1,
                   path:clockParent+String(format:"/%08x.%08x[%d]",clockOwner,firstHash,index),
                   text:index==0 ? "true":"false")
    }
    let autoDoorParent="/7f9decbe.8aab887b[23]/8413308a.34be46bd[75]/80e2f7c5.1bd539fc"
    let wiringParent="/7f9decbe.8aab887b[23]/8413308a.34be46bd[48]/9847e6b3.1bd539fc"
    let elevatorParent="/7f9decbe.8aab887b[23]/8413308a.34be46bd[69]/73c3755b.1bd539fc"
    let autoDoorFields=[mechanism(autoDoorName,"HasOpened",2,"true",autoDoorParent,312)]
    let wiringFields=[mechanism(wiringName,"HasBrokenMotor",2,"true",wiringParent,313),
                      mechanism(wiringName,"SwitchedIndex",7,"-1",wiringParent,314)]
    let elevatorFields=[mechanism(elevatorName,"CurIndex",7,"1",elevatorParent,315)]
    let shelfParent="/7f9decbe.8aab887b[23]/8413308a.34be46bd[105]/9aa81c3c.1bd539fc"
    let movableParent="/7f9decbe.8aab887b[23]/8413308a.59a3dafc[2]/fa8abf85.1bd539fc"
    let fanParent="/7f9decbe.8aab887b[23]/8413308a.34be46bd[63]/b843da90.1bd539fc"
    var shelfFields: [SaveScalar] = [mechanism(shelfName,"isInit",2,"true",shelfParent,316)]
    for index in 0..<4 {
        let position = mechanism(shelfName,"PosNum",7,String(index+1),shelfParent,317+index*2,arrayIndex:index)
        let locked = mechanism(shelfName,"isLock",2,index==2 ? "true":"false",shelfParent,318+index*2,arrayIndex:index)
        shelfFields.append(position)
        shelfFields.append(locked)
    }
    let movableFields=[mechanism(movableName,"HasMoved",2,"true",movableParent,325)]
    let fanFields=[mechanism(fanName,"HasBroken",2,"true",fanParent,326)]
    var plugFirstFields:[SaveScalar]=[]
    for index in 0..<6 {
        plugFirstFields.append(mechanism(plugName,"isFirst",2,index==1 ? "true":"false",plugParent,327+index,arrayIndex:index))
    }
    let rigidParent="/7f9decbe.8aab887b[23]/8413308a.34be46bd[1]/22a089f8.1bd539fc"
    let gateParent="/7f9decbe.8aab887b[23]/8413308a.c81a3eff[505]/1e149e87.1bd539fc"
    let bulkheadParent="/7f9decbe.8aab887b[23]/8413308a.34be46bd[243]/f57f51a6.1bd539fc"
    let shutterParent="/7f9decbe.8aab887b[23]/8413308a.59a3dafc[39]/6f269a41.1bd539fc"
    let topboardParent="/7f9decbe.8aab887b[23]/8413308a.59a3dafc[81]/3cdf6985.1bd539fc"
    let rigidFields=[mechanism(rigidName,"Status",7,"0",rigidParent,333)]
    let gateFields=[mechanism(gateName,"InsertCount",7,"5",gateParent,334),
                    mechanism(gateName,"EjectCount",7,"2",gateParent,335)]
    let bulkheadFields=[mechanism(bulkheadName,"HasOpened",2,"true",bulkheadParent,336)]
    let shutterFields=[mechanism(shutterName,"IsBreak",2,"true",shutterParent,337)]
    let topboardFields=[mechanism(topboardName,"IsFall",2,"false",topboardParent,338)]
    var allMechanisms: [SaveScalar] = []
    for group in [switchFields,plugFields,clockFields,firstFields,autoDoorFields,wiringFields,elevatorFields,shelfFields,movableFields,fanFields,plugFirstFields,rigidFields,gateFields,bulkheadFields,shutterFields,topboardFields] {
        allMechanisms.append(contentsOf:group)
    }
    let mechanisms=RE2MechanismProgressCatalog.details(game:re2Game,source:re2Campaign,fields:allMechanisms,character:"Leon")
    let baseMechanismsValid = mechanisms?.switches.count==1 && mechanisms?.switches[0].toggled==true &&
        mechanisms?.switches[0].finalApplied==false && mechanisms?.plugs[0].plugCode==3 &&
        mechanisms?.clockGear?.topCode==2 && mechanisms?.clockGear?.firstFlags==[true,false,false,false]
    let worldMechanismsValid = mechanisms?.autoDoors.first?.opened==true &&
        mechanisms?.wiringNodes.first?.switchedIndex == -1 && mechanisms?.elevators.first?.currentIndex==1
    let newMechanismsValid = mechanisms?.bookShelves.first?.positions==[1,2,3,4] &&
        mechanisms?.bookShelves.first?.locked==[false,false,true,false] &&
        mechanisms?.movables.first?.moved==true && mechanisms?.fans.first?.broken==true
    let plugFirstValid = mechanisms?.plugFirstFlags.first?.flags==[false,true,false,false,false,false]
    let objectCodesValid = mechanisms?.rigidBodies.first?.code==0 &&
        mechanisms?.plugGates.first?.inserted==5 && mechanisms?.plugGates.first?.ejected==2
    let objectFlagsValid = mechanisms?.laboratoryBulkheads.first?.value==true &&
        mechanisms?.g2Shutters.first?.value==true && mechanisms?.topboards.first?.value==false
    check(baseMechanismsValid && worldMechanismsValid && newMechanismsValid,
          "RE2-Mechanik nur aus vollständigen und passend typisierten Objektgruppen lesen")
    check(plugFirstValid && objectCodesValid && objectFlagsValid,
          "Weitere RE2-Objektgruppen nur aus exakten Pfaden lesen")
    check(RE2MechanismProgressCatalog.details(game:re2Game,source:re2System,fields:allMechanisms,character:nil)==nil,
          "Mechanikzustände nicht dem Systemsave zuordnen")
    check(RE2MechanismProgressCatalog.details(game:re2Game,source:re2Campaign,fields:allMechanisms+[switchFields[0]],character:"Leon")?.switches.isEmpty==true,
          "Doppeltes Schalterfeld ausblenden")
    check(RE2MechanismProgressCatalog.details(game:re2Game,source:re2Campaign,fields:Array(plugFields.dropLast())+switchFields,character:"Leon")?.plugs.isEmpty==true,
          "Unvollständigen Steckplatz ausblenden")
    check(RE2MechanismProgressCatalog.details(game:re2Game,source:re2Campaign,fields:allMechanisms+autoDoorFields,character:"Leon")?.autoDoors.isEmpty==true,
          "Doppelte automatische Tür ausblenden")
    check(RE2MechanismProgressCatalog.details(game:re2Game,source:re2Campaign,fields:allMechanisms.filter {$0.id != 314},character:"Leon")?.wiringNodes.isEmpty==true,
          "Unvollständigen Verkabelungsknoten ausblenden")
    check(RE2MechanismProgressCatalog.details(game:re2Game,source:re2Campaign,fields:allMechanisms.filter {$0.id != 324},character:"Leon")?.bookShelves.isEmpty==true,
          "Unvollständige Bücherregal-Positionen ausblenden")
    check(RE2MechanismProgressCatalog.details(game:re2Game,source:re2Campaign,fields:allMechanisms+movableFields,character:"Leon")?.movables.isEmpty==true,
          "Doppeltes Bewegungsflag ausblenden")
    check(RE2MechanismProgressCatalog.details(game:re2Game,source:re2Campaign,fields:allMechanisms.filter {$0.id != 332},character:"Leon")?.plugFirstFlags.isEmpty==true,
          "Unvollständige Steckplatz-Erstflags ausblenden")
    check(RE2MechanismProgressCatalog.details(game:re2Game,source:re2Campaign,fields:allMechanisms+gateFields,character:"Leon")?.plugGates.isEmpty==true,
          "Doppeltes Stecktor ausblenden")
    let triggerName="app.ropeway.gimmick.action.TriggerSaveData"
    let itemTriggerName="app.ropeway.gimmick.action.TriggerSaveDataUseItem"
    let triggerParent="/7f9decbe.8aab887b[23]/8413308a.c81a3eff[2]/b145081f.51b3dc27[0]"
    let itemTriggerParent="/7f9decbe.8aab887b[23]/8413308a.c81a3eff[9]/b145081f.51b3dc27[1]"
    let triggerFields=[mechanism(triggerName,"Key",8,"7",triggerParent,339),
                       mechanism(triggerName,"DoneSucceed",2,"true",triggerParent,340)]
    let itemTriggerFields=[mechanism(itemTriggerName,"Key",8,"8",itemTriggerParent,341),
                           mechanism(itemTriggerName,"DoneSucceed",2,"false",itemTriggerParent,342),
                           mechanism(itemTriggerName,"HasUsed",2,"true",itemTriggerParent,343,arrayIndex:0),
                           mechanism(itemTriggerName,"HasUsed",2,"false",itemTriggerParent,344,arrayIndex:1)]
    let triggerProgress=RE2TriggerProgressCatalog.details(game:re2Game,source:re2Campaign,
                                                          fields:triggerFields+itemTriggerFields,character:"Leon")
    check(triggerProgress?.triggers.first?.entries.first?.key==7 &&
          triggerProgress?.triggers.first?.completedCount==1 &&
          triggerProgress?.itemTriggers.first?.entries.first?.usedFlags==[true,false],
          "RE2-Trigger aus vollständigen Schlüssel- und Erfolgsfeldern lesen")
    let alternateParent="/7f9decbe.8aab887b[23]/8413308a.c81a3eff[2]/5a30060b.51b3dc27[0]"
    let rareParent="/7f9decbe.8aab887b[23]/8413308a.c81a3eff[2]/1e149e87.51b3dc27[0]"
    let alternateFields=[mechanism(triggerName,"Key",8,"9",alternateParent,345),
                         mechanism(triggerName,"DoneSucceed",2,"false",alternateParent,346),
                         mechanism(triggerName,"Key",8,"10",rareParent,347),
                         mechanism(triggerName,"DoneSucceed",2,"true",rareParent,348)]
    let allTriggerKinds=RE2TriggerProgressCatalog.details(game:re2Game,source:re2Campaign,
                                                          fields:triggerFields+alternateFields,character:"Leon")
    check(allTriggerKinds?.triggers.count==3 &&
          Set(allTriggerKinds?.triggers.map(\.listKind) ?? [])==Set(["b145081f","5a30060b","1e149e87"]),
          "RE2-Triggerlisten mit drei belegten Kennungen getrennt anzeigen")
    let duplicateTrigger=RE2TriggerProgressCatalog.details(game:re2Game,source:re2Campaign,
                                                            fields:triggerFields+Array(triggerFields.prefix(1))+itemTriggerFields,
                                                            character:"Leon")
    check(duplicateTrigger?.triggers.isEmpty==true && duplicateTrigger?.itemTriggers.count==1,
          "Doppeltes Trigger-Schlüsselfeld ausblenden")
    let gapItemTrigger=RE2TriggerProgressCatalog.details(game:re2Game,source:re2Campaign,
                                                          fields:triggerFields+itemTriggerFields.filter {$0.id != 343},
                                                          character:"Leon")
    check(gapItemTrigger?.itemTriggers.isEmpty==true,
          "Lücke im HasUsed-Array ausblenden")
    check(RE2TriggerProgressCatalog.details(game:re2Game,source:re2System,
                                            fields:triggerFields+itemTriggerFields,character:nil)==nil,
          "Triggerzustände nicht dem Systemsave zuordnen")
    let enemyName="app.ropeway.enemy.savedata.EmSaveData"
    let enemyParent="/7f9decbe.8aab887b[29]/44ccdde9.1d563f16[0]"
    let enemyScalars:[(String,Int32,String)]=[
        ("SceneID",1,"347"),("AreaID",1,"0"),("KindID",1,"2"),("InheritID",7,"-1"),
        ("FlagData",8,"8"),("DataVersion",8,"4"),("BirthedTime",11,"36.0"),
        ("UnloadedTime",11,"108.0")]
    var enemyFields:[SaveScalar]=[]
    for (index,spec) in enemyScalars.enumerated() {
        enemyFields.append(mechanism(enemyName,spec.0,spec.1,spec.2,enemyParent,500+index))
    }
    for index in 0..<3 {
        enemyFields.append(mechanism(enemyName,"HitPointData",7,String(100-index),enemyParent,508+index,arrayIndex:index))
    }
    for index in 0..<10 {
        enemyFields.append(mechanism(enemyName,"TransformData",11,String(Double(index)),enemyParent,511+index,arrayIndex:index))
    }
    let enemyState=RE2EnemyStateCatalog.details(game:re2Game,source:re2Campaign,fields:enemyFields,character:"Leon")
    check(enemyState?.records.count==1 && enemyState?.records.first?.sceneID==347 &&
          enemyState?.records.first?.hitPointData==[100,99,98] &&
          enemyState?.records.first?.transformData.count==10,
          "RE2-Gegnerzustand aus vollständig gepaarten nativen Feldern lesen")
    check(RE2EnemyStateCatalog.details(game:re2Game,source:re2Campaign,
                                       fields:enemyFields.filter{$0.id != 509},character:"Leon")==nil,
          "Unvollständigen Gegner-Trefferpunktblock ausblenden")
    check(RE2EnemyStateCatalog.details(game:re2Game,source:re2Campaign,
                                       fields:enemyFields+[enemyFields[0]],character:"Leon")==nil,
          "Doppelten Gegner-Szenencode ausblenden")
    check(RE2EnemyStateCatalog.details(game:re2Game,source:re2System,
                                       fields:enemyFields,character:nil)==nil,
          "Gegnerzustände nicht Systemdaten zuordnen")
    let tutorialOwner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.TutorialManager.GameSaveData".utf8))
    let tutorialField=SaveCrypto.murmur(Data("IsDispTutorial".utf8))
    let tutorialPrefix="/7f9decbe.8aab887b[12]/91bb4685.bfb6252d["
    let tutorialFields=(0..<63).map {index in
        SaveScalar(id:400+index,owner:tutorialOwner,field:tutorialField,type:2,offset:400+index,size:1,
                   path:tutorialPrefix+"\(index)]",text:[2,7,32].contains(index) ? "true":"false")
    }
    let windowOwner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.UIMapManager.WindowInfo".utf8))
    let windowPrefix="/7f9decbe.8aab887b[8]/090ff53c.c07d05d1/934e2e6b.695a3627["
    let windowFields=(0..<2).flatMap {index in
        [("_Hash",Int32(8),String(20000+index)),("_MapId",Int32(1),"226"),
         ("_IsBarricade",Int32(2),index==0 ? "true":"false")].enumerated().map {offset,spec in
            let hash=SaveCrypto.murmur(Data(spec.0.utf8))
            return SaveScalar(id:500+index*3+offset,owner:windowOwner,field:hash,type:spec.1,
                              offset:500+index*12+offset*4,size:spec.1==2 ? 1:4,
                              path:windowPrefix+"\(index)]"+String(format:"/%08x.%08x",windowOwner,hash),text:spec.2)
        }
    }
    let environment=RE2EnvironmentProgressCatalog.details(game:re2Game,source:re2Campaign,
                                                           fields:tutorialFields+windowFields,character:"Leon")
    check(environment?.displayedTutorials?.count==63 && environment?.displayedTutorials?[7]==true &&
          environment?.displayedTutorials?.filter({$0}).count==3 &&
          environment?.windows.count==2 && environment?.windows[0].barricaded==true &&
          environment?.windows[1].barricaded==false,
          "RE2-Tutorial-Flags und gepaarte Fensterdatensätze lesen")
    check(RE2EnvironmentProgressCatalog.details(game:re2Game,source:re2System,
                                                fields:tutorialFields+windowFields,character:nil)==nil,
          "Tutorials und Fenster nicht dem Systemsave zuordnen")
    check(RE2EnvironmentProgressCatalog.details(game:re2Game,source:re2Campaign,
                                                fields:tutorialFields+[tutorialFields[0]]+windowFields,character:"Leon")?.displayedTutorials==nil,
          "Doppelte Tutorial-ID ausblenden")
    check(RE2EnvironmentProgressCatalog.details(game:re2Game,source:re2Campaign,
                                                fields:tutorialFields+Array(windowFields.dropLast()),character:"Leon")?.windows.isEmpty==true,
          "Unvollständigen Fenstereintrag ausblenden")
    let dataOwner=SaveCrypto.murmur(Data("app.ropeway.inventory.Data".utf8))
    let mainOwner=SaveCrypto.murmur(Data("app.ropeway.inventory.MainSlotData".utf8))
    let subOwner=SaveCrypto.murmur(Data("app.ropeway.inventory.SubSlotData".utf8))
    let shortcutOwner=SaveCrypto.murmur(Data("app.ropeway.inventory.ShortcutSlotData".utf8))
    let layoutRoot="/7f9decbe.8aab887b[15]/41f30892.cbe14e81[0]"
    func layoutField(_ owner:UInt32,_ name:String,_ type:Int32,_ text:String,_ tail:String,_ id:Int) -> SaveScalar {
        let field=SaveCrypto.murmur(Data(name.utf8))
        return SaveScalar(id:id,owner:owner,field:field,type:type,offset:id*4,size:4,
                          path:layoutRoot+tail+String(format:"/%08x.%08x",owner,field),text:text)
    }
    var layoutFields=[layoutField(dataOwner,"_SurvivorType",1,"1","",600),
                      layoutField(dataOwner,"CurrentSlotSize",7,"8","",601),
                      layoutField(dataOwner,"_CurrentSlotSize",7,"8","",602)]
    for name in ["MainData","_MainData"] {
        let tail=String(format:"/%08x.%08x",dataOwner,SaveCrypto.murmur(Data(name.utf8)))
        layoutFields.append(layoutField(mainOwner,"_Index",7,"0",tail,layoutFields.count+600))
        layoutFields.append(layoutField(mainOwner,"_LastWeaponType",1,"9",tail,layoutFields.count+600))
    }
    for name in ["SubData","_SubData"] {
        let tail=String(format:"/%08x.%08x",dataOwner,SaveCrypto.murmur(Data(name.utf8)))
        layoutFields.append(layoutField(subOwner,"_LastWeaponType",1,"-1",tail,layoutFields.count+600))
    }
    for (listIndex,name) in ["ShortcutDataList","SubShortcutDataList","_ShortcutDataList","_SubShortcutDataList"].enumerated() {
        for index in 0..<4 {
            let tail=String(format:"/%08x.%08x[%d]",dataOwner,SaveCrypto.murmur(Data(name.utf8)),index)
            layoutFields.append(layoutField(shortcutOwner,"_ShortcutKind",1,String(listIndex),tail,layoutFields.count+600))
            layoutFields.append(layoutField(shortcutOwner,"_Index",7,index==0 && listIndex==0 ? "0":"-1",tail,layoutFields.count+600))
            layoutFields.append(layoutField(shortcutOwner,"_LastWeaponType",1,index==0 && listIndex==0 ? "9":"-1",tail,layoutFields.count+600))
        }
    }
    let layout=RE2InventoryLayoutCatalog.profiles(game:re2Game,source:re2Campaign,fields:layoutFields,character:"Claire")
    check(layout.count==1 && layout[0].survivorCode==1 && layout[0].slotSize==8 &&
          layout[0].mainSlot.lastWeaponCode==9 && layout[0].shortcuts.count==4 &&
          layout[0].subShortcuts.count==4 && layout[0].storedShortcuts.count==4 &&
          layout[0].storedSubShortcuts.count==4 && layout[0].shortcuts[0].slotIndex==0 &&
          layout[0].storedSubShortcuts[3].slotIndex == -1,
          "RE2-Figurenprofil, Kapazität und vier Schnellplatzlisten paaren")
    check(RE2InventoryLayoutCatalog.profiles(game:re2Game,source:re2ThirdSlot,fields:layoutFields,character:"Leon").count==1,
          "RE2-Inventarprofile auch in Kampagnen-Slot 3 anzeigen")
    check(RE2InventoryLayoutCatalog.profiles(game:re2Game,source:re2System,fields:layoutFields,character:nil).isEmpty,
          "Inventarprofil nicht dem Systemsave zuordnen")
    let absentWeapon=RE2InventoryLayoutCatalog.profiles(game:re2Game,source:re2Campaign,
                                                         fields:Array(layoutFields.dropLast()),character:"Claire")
    check(absentWeapon.count==1 && absentWeapon[0].storedSubShortcuts[3].lastWeaponCode==nil,
          "Nicht gespeicherten Waffencode des Schnellplatzes als fehlend ausgeben")
    let absentBoth=RE2InventoryLayoutCatalog.profiles(game:re2Game,source:re2Campaign,
                                                       fields:Array(layoutFields.dropLast(2)),character:"Claire")
    check(absentBoth.count==1 && absentBoth[0].storedSubShortcuts[3].slotIndex==nil &&
          absentBoth[0].storedSubShortcuts[3].lastWeaponCode==nil,
          "Leeren Schnellplatz ohne Index und Waffencode anzeigen")
    let shorter=RE2InventoryLayoutCatalog.profiles(game:re2Game,source:re2Campaign,
                                                    fields:Array(layoutFields.dropLast(3)),character:"Claire")
    check(shorter.count==1 && shorter[0].storedSubShortcuts.count==3,
          "Variable Anzahl gespeicherter Schnellplätze lesen")
    let re2ItemOwner="app.ropeway.gamemastering.ItemManager.SystemSaveData"
    let re2SystemStatus=re2StatusFields(re2ItemOwner,"GetItemList",297,[15,32])+re2StatusFields(re2ItemOwner,"GetWeaponList",383,[9])
    let systemHistory=RE2ItemHistoryCatalog.lists(game:re2Game,source:re2System,fields:re2SystemStatus,names:names)
    check(systemHistory.count==2 && systemHistory[0].recorded.map(\.name)==["Pistolenmunition","Farbband"] && systemHistory[1].recorded.map(\.name)==["SLS 60"],"RE2-Systemstatus zeigt benannte Gegenstände und Waffen nach nativer ID")
    let searchedStatus=re2StatusFields("app.ropeway.gamemastering.ItemManager.SaveData","IsSearchedItem",297,[87,102])
    let campaignHistory=RE2ItemHistoryCatalog.lists(game:re2Game,source:re2Campaign,fields:searchedStatus,names:names)
    check(campaignHistory.count==1 && campaignHistory[0].recorded.map(\.name)==["S.T.A.R.S.-Abzeichen","USB-Dongle"],"RE2-Untersuchungsstatus wird spielstandgebunden angezeigt")
    let inventoryOwner="app.ropeway.gamemastering.InventoryManager.SaveData"
    let inventoryEffects=re2StatusFields(inventoryOwner,"GetKeyItemEffect",297,[32])
        + re2StatusFields(inventoryOwner,"GetKeyWeaponEffect",383,[9])
        + re2StatusFields(inventoryOwner,"IsCustomWeaponEffect",383,[46])
        + re2StatusFields(inventoryOwner,"IsAddRankItem",297,[15])
    let extendedHistory=RE2ItemHistoryCatalog.lists(game:re2Game,source:re2Campaign,fields:searchedStatus+inventoryEffects,names:names)
    check(extendedHistory.count==5 && extendedHistory.map(\.recorded.count)==[2,1,1,1,1] &&
          extendedHistory[1].recorded[0].name=="Farbband" &&
          extendedHistory[2].recorded[0].name=="SLS 60" &&
          extendedHistory[3].recorded[0].name=="Kampfmesser",
          "RE2-Inventareffekte nur aus vollständigen indizierten Listen und nativen IDs lesen")
    check(RE2ItemHistoryCatalog.lists(game:re2Game,source:re2Campaign,fields:searchedStatus+Array(inventoryEffects.dropFirst()),names:names).count==4,
          "Unvollständige RE2-Effektliste ausblenden")
    let useWeaponsOwner=SaveCrypto.murmur(Data("app.ropeway.PlayerManager.GameSaveData".utf8))
    let useWeaponsHash=SaveCrypto.murmur(Data("UseWeapons".utf8))
    let usedWeaponIDs=[1,31,8,41]
    let usedWeaponFields=usedWeaponIDs.enumerated().map {index,weaponID in
        SaveScalar(id:index,owner:useWeaponsOwner,field:useWeaponsHash,type:1,offset:index*4,size:4,
                   path:String(format:"/2412050a.%08x[%d]",useWeaponsHash,index),text:String(weaponID))
    }
    let usedWeapons=RE2WeaponUseCatalog.entries(game:re2Game,fields:usedWeaponFields,character:"Leon",names:names)
    check(usedWeapons.map(\.name)==["Matilda","Lightning Hawk","Broom Hc","EMF Visualizer"] && usedWeapons.map(\.weaponID)==usedWeaponIDs,"RE2-UseWeapons-Liste zeigt bestätigte Waffen-IDs mit Namen")
    check(RE2WeaponUseCatalog.entries(game:re2Game,fields:usedWeaponFields,character:nil,names:names).isEmpty,"Ohne eindeutige Spielfigur keine Waffenliste")
    check(RE2WeaponUseCatalog.entries(game:re2Game,fields:usedWeaponFields+[usedWeaponFields[0]],character:"Leon",names:names).isEmpty,"Doppelter Waffenlistenindex wird abgelehnt")
    let costumeIDHash=SaveCrypto.murmur(Data("CostumeID".utf8))
    let costumeFields=[
        SaveScalar(id:0,owner:0,field:costumeIDHash,type:1,offset:0,size:4,path:"/costume[0]",text:"13"),
        SaveScalar(id:1,owner:0,field:costumeIDHash,type:1,offset:4,size:4,path:"/costume[1]",text:"16"),
        SaveScalar(id:2,owner:0,field:costumeIDHash,type:15,offset:8,size:4,path:"/text",text:"private"),
        SaveScalar(id:3,owner:0,field:0,type:1,offset:12,size:4,path:"/other",text:"42")
    ]
    let costumes=RE2CostumeStateCatalog.states(game:re2Game,fields:costumeFields)
    check(costumes.count==1 && costumes[0].entries.map(\.value)==["13","16"] && costumes[0].distinctValues==["13","16"],"RE2-Kostümwerte nur lesend und ohne Textfelder")
    check(RE2CostumeStateCatalog.states(game:GameProfile.all.first{$0.id=="re3"}!,fields:costumeFields).isEmpty,"RE2-Kostümwerte nur für RE2")
    let userCostumeHash=SaveCrypto.murmur(Data("UserCostumeDataList".utf8))
    let checkedCostumeHash=SaveCrypto.murmur(Data("CheckedCostumeDataList".utf8))
    let separatedCostumes=[
        SaveScalar(id:0,owner:0,field:costumeIDHash,type:1,offset:0,size:4,path:String(format:"/a.%08x[0]/b.%08x",userCostumeHash,costumeIDHash),text:"16"),
        SaveScalar(id:1,owner:0,field:costumeIDHash,type:1,offset:4,size:4,path:String(format:"/a.%08x[0]/b.%08x",checkedCostumeHash,costumeIDHash),text:"3")
    ]
    let groupedCostumes=RE2CostumeStateCatalog.states(game:re2Game,fields:separatedCostumes)
    check(groupedCostumes.count==2 && groupedCostumes[0].title.contains("Benutzer-Kostümdaten") && groupedCostumes[0].entries.map(\.value)==["16"] && groupedCostumes[1].title.contains("Geprüfte Kostümdaten") && groupedCostumes[1].entries.map(\.value)==["3"],"RE2-Kostüm-IDs nach tatsächlicher Quellliste getrennt")
    let costumeOwner=SaveCrypto.murmur(Data("app.ropeway.CostumeManager.CostumeData".utf8))
    let survivorTypeHash=SaveCrypto.murmur(Data("SurvivorType".utf8))
    let costumeParent=String(format:"/a.%08x[0]/%08x",userCostumeHash,costumeOwner)
    let pairedCostumes=[
        SaveScalar(id:0,owner:costumeOwner,field:costumeIDHash,type:1,offset:0,size:4,path:String(format:"%@.%08x",costumeParent,costumeIDHash),text:"16"),
        SaveScalar(id:1,owner:costumeOwner,field:survivorTypeHash,type:1,offset:4,size:4,path:String(format:"%@.%08x",costumeParent,survivorTypeHash),text:"0"),
        SaveScalar(id:2,owner:costumeOwner,field:survivorTypeHash,type:1,offset:8,size:4,path:String(format:"/a.%08x[1]/%08x.%08x",userCostumeHash,costumeOwner,survivorTypeHash),text:"1")
    ]
    let pairedStates=RE2CostumeStateCatalog.states(game:re2Game,fields:pairedCostumes)
    check(pairedStates.count==1 && pairedStates[0].entries.count==1 && pairedStates[0].entries[0].survivorTypeCode==0,"RE2-Kostüm-ID nur mit Figurentyp aus demselben Eintrag verbinden")
    check(RE2CostumeStateCatalog.states(game:re2Game,fields:[pairedCostumes[0],pairedCostumes[2]])[0].entries[0].survivorTypeCode==nil,"RE2-Kostümtyp aus anderem Eintrag nicht zuordnen")
    let systemMetaSpecs:[(UInt32,String,Int32,Int,String)]=[
        (0x4683bfe1,"LastSaveSlotId",7,4,"3"),
        (0x4683bfe1,"LastSavedTimeTicks",9,8,"639288507851617920"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"LatestGameId",8,4,"37"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"IsFirstPlayLeon",2,1,"false"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"IsClearedGameImmediately",2,1,"false"),
        (SaveCrypto.murmur(Data("app.ropeway.GameClock.SystemSaveData".utf8)),"_SystemElapsedTime",10,8,"16410718948"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"IsCheckedNewMark_NewGamePlus",2,1,"true"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"IsOpenedPopUp_ExtraContentsNotice",2,1,"true"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"IsOpenedPopUp_TofuCharacter",2,1,"false"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"IsOpenedPopUp_Weapon",2,1,"false"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"The4thClearPlayTime",10,8,"0"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"IsCheckedNewMark_ClearState",2,1,"true"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"IsCheckedNewMark_Extra",2,1,"true"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"HuntedTreasureOfRecord059",8,4,"3"),
        (SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.SystemSaveData".utf8)),"IsOpenedPopUp_NewGamePlus",2,1,"true")
    ]
    let systemMetaFields=systemMetaSpecs.enumerated().map {index,spec in
        let (owner,name,type,size,value)=spec
        let field=SaveCrypto.murmur(Data(name.utf8))
        let rootIndex=owner==0x4683bfe1 ? 2 : (owner==SaveCrypto.murmur(Data("app.ropeway.GameClock.SystemSaveData".utf8)) ? 0 : 7)
        return SaveScalar(id:index,owner:owner,field:field,type:type,offset:index*8,size:size,
            path:String(format:"/9e0932a9.9074a186[%d]/%08x.%08x",rootIndex,owner,field),text:value)
    }
    let systemMeta=RE2SystemMetadataCatalog.entries(game:re2Game,source:re2System,fields:systemMetaFields)
    check(systemMeta.count==15 && systemMeta[0].value=="3" && systemMeta[3].value=="false" && systemMeta[14].value=="true",
          "RE2-Systemwerte nur aus eindeutig passenden nativen Rohfeldern lesen")
    check(RE2SystemMetadataCatalog.entries(game:re2Game,source:re2Campaign,fields:systemMetaFields).isEmpty &&
          RE2SystemMetadataCatalog.entries(game:GameProfile.all.first{$0.id=="re3"}!,source:re2System,fields:systemMetaFields).isEmpty,
          "RE2-Systemwerte nicht in Kampagnensaves oder anderen Spielen anbieten")
    check(RE2SystemMetadataCatalog.entries(game:re2Game,source:re2System,fields:systemMetaFields+[systemMetaFields[0]]).count==14,
          "Mehrdeutige RE2-Systemwerte ausblenden")
    let misplacedMeta=SaveScalar(id:99,owner:systemMetaFields[0].owner,field:systemMetaFields[0].field,
        type:7,offset:0,size:4,path:"/other/4683bfe1.c3e42c22",text:"3")
    check(RE2SystemMetadataCatalog.entries(game:re2Game,source:re2System,fields:[misplacedMeta]).isEmpty,
          "RE2-Systemwerte nur aus der bestätigten Systemliste lesen")
    let wrongIndexMeta=SaveScalar(id:100,owner:systemMetaFields[0].owner,field:systemMetaFields[0].field,
        type:7,offset:0,size:4,path:"/9e0932a9.9074a186[5]/4683bfe1.c3e42c22",text:"3")
    check(RE2SystemMetadataCatalog.entries(game:re2Game,source:re2System,fields:[wrongIndexMeta]).isEmpty,
          "RE2-Systemwerte nur am bestätigten Systemeintragsindex lesen")
    func re2SystemArray(_ ownerName:String,_ name:String,_ count:Int,_ type:Int32,_ size:Int,
                        _ listIndex:Int,_ value:(Int)->String) -> [SaveScalar] {
        let owner=SaveCrypto.murmur(Data(ownerName.utf8))
        let field=SaveCrypto.murmur(Data(name.utf8))
        return (0..<count).map {index in
            SaveScalar(id:index,owner:owner,field:field,type:type,offset:index*size,size:size,
                       path:String(format:"/9e0932a9.9074a186[%d]/%08x.%08x[%d]",listIndex,owner,field,index),
                       text:value(index))
        }
    }
    let optionOwner="app.ropeway.OptionManager.SystemSaveData"
    let storedOptions=re2SystemArray(optionOwner,"optionData",134,8,4,8) {index in index==13 ? "7":"0"}
    let defaultOptions=re2SystemArray(optionOwner,"defaultData",134,8,4,8) {_ in "0"}
    let optionRows=RE2SystemArrayCatalog.options(game:re2Game,source:re2System,fields:storedOptions+defaultOptions)
    check(optionRows.count==134 && optionRows.filter(\.differs).map(\.id)==[13] &&
          optionRows[13].stored==7 && optionRows[13].defaultValue==0,
          "RE2-Systemoptionen indexgleich aus beiden nativen Listen lesen")
    check(RE2SystemArrayCatalog.options(game:re2Game,source:re2System,fields:storedOptions+defaultOptions+[storedOptions[0]]).isEmpty &&
          RE2SystemArrayCatalog.options(game:re2Game,source:re2Campaign,fields:storedOptions+defaultOptions).isEmpty &&
          RE2SystemArrayCatalog.options(game:re2Game,source:re2System,
             fields:storedOptions+re2SystemArray(optionOwner,"defaultData",134,8,4,9) {_ in "0"}).isEmpty,
          "RE2-Optionsvergleich bei doppelten, falschen oder unpassenden Listen ausblenden")
    let tofuFields=re2SystemArray("app.ropeway.gamemastering.RecordManager.SystemSaveData",
                                  "TofuClearPlayTime",5,10,8,7) {index in String(index*100)}
    let tofuRows=RE2SystemArrayCatalog.tofuTimes(game:re2Game,source:re2System,fields:tofuFields)
    check(tofuRows.count==5 && tofuRows[4].rawValue==400 &&
          RE2SystemArrayCatalog.tofuTimes(game:re2Game,source:re2System,fields:Array(tofuFields.dropLast())).isEmpty,
          "RE2-Tofu-Zeitplätze nur aus vollständiger nativer Liste lesen")
    func re2ProgressFields(_ name:String,_ count:Int,_ marked:Set<Int>) -> [SaveScalar] {
        let hash=SaveCrypto.murmur(Data(name.utf8))
        return (0..<count).map {index in
            SaveScalar(id:index,owner:0x4e4210f9,field:hash,type:2,offset:index,size:1,
                       path:String(format:"/9e0932a9.9074a186[7]/4e4210f9.%08x[%d]",hash,index),
                       text:marked.contains(index) ? "true":"false")
        }
    }
    let progressFields=re2ProgressFields("IsClearedRecord",91,[0,30,90])
        + re2ProgressFields("IsOpenedReward",133,[4,132])
        + re2ProgressFields("IsClearedGame",21,[7])
    let progress=RE2ProgressFlagCatalog.lists(game:re2Game,source:re2System,fields:progressFields)
    check(progress.count==3 && progress[0].marked==[0,30,90] && progress[1].marked==[4,132] && progress[2].marked==[7],"RE2-Systemfortschritt liest drei vollständige indizierte Statuslisten")
    check(RE2ProgressFlagCatalog.lists(game:re2Game,source:re2Campaign,fields:progressFields).isEmpty,"Rekordstatus wird nur in der RE2-Systemdatei angezeigt")
    check(RE2ProgressFlagCatalog.lists(game:re2Game,source:re2System,fields:Array(progressFields.dropFirst())).count==2,"Unvollständige Rekordliste wird nicht angezeigt")
    func mapFields(_ ownerName:String,_ fieldName:String,_ count:Int,_ marked:Set<Int>,_ numeric:Bool=false) -> [SaveScalar] {
        let owner=SaveCrypto.murmur(Data(ownerName.utf8)),field=SaveCrypto.murmur(Data(fieldName.utf8))
        return (0..<count).map {index in
            SaveScalar(id:index,owner:owner,field:field,type:numeric ? 1:2,offset:index*4,size:numeric ? 4:1,
                       path:String(format:"/%08x.%08x[%d]",owner,field,index),
                       text:numeric ? (marked.contains(index) ? "2":"0"):(marked.contains(index) ? "true":"false"))
        }
    }
    let sampleMap=mapFields("app.ropeway.gamemastering.UIMapManager.SaveData","openedFloor",33,[1,2])
        + mapFields("app.ropeway.gamemastering.UIMapManager.SaveData","mapDispState",563,[4],true)
        + mapFields("app.ropeway.gui.MapClearingResultManager.MapData","Arrived",3,[0])
        + mapFields("app.ropeway.gui.MapClearingResultManager.UnitData","HasCleared",4,[0,2])
        + mapFields("app.ropeway.gamemastering.UIMapManager.MapPartsChangeInfo","Done",64,[3])
    let mapSummary=RE2MapProgressCatalog.summaries(game:re2Game,fields:sampleMap,character:"Leon")
    check(mapSummary.count==5 && mapSummary[0].total==33 && mapSummary[0].distribution.last?.count==2 && mapSummary[1].distribution.last?.code==2,"RE2-Kartenlisten lesen vollständige Codes und Statuszahlen")
    check(RE2MapProgressCatalog.summaries(game:re2Game,fields:sampleMap,character:nil).isEmpty,"Kartenstatus nur für eindeutige RE2-Kampagnendatei")
    check(RE2MapProgressCatalog.summaries(game:re2Game,fields:Array(sampleMap.dropFirst()),character:"Leon").count==4,"Unvollständige feste Kartenliste wird ausgelassen")
    let recordOwner=SaveCrypto.murmur(Data("app.ropeway.gamemastering.RecordManager.GameSaveData".utf8))
    let runFields=[
        SaveScalar(id:0,owner:recordOwner,field:SaveCrypto.murmur(Data("UseSpecialWeapon".utf8)),type:2,offset:0,size:1,path:"/record.special",text:"true"),
        SaveScalar(id:1,owner:recordOwner,field:SaveCrypto.murmur(Data("UseAimAssist".utf8)),type:2,offset:1,size:1,path:"/record.aim",text:"false")
    ]
    let runFlags=RE2RunFlagCatalog.flags(game:re2Game,fields:runFields,character:"Leon")
    check(runFlags.count==2 && runFlags[0].isSet && !runFlags[1].isSet,"RE2-Spielmerkmale nur aus eindeutigen Bool-Feldern lesen")
    check(RE2RunFlagCatalog.flags(game:re2Game,fields:runFields+[runFields[0]],character:"Leon").count==1,"Mehrdeutiges RE2-Spielmerkmal ausblenden")
    check(RE2RunFlagCatalog.flags(game:re2Game,fields:runFields,character:nil).isEmpty,"Spielmerkmale ohne eindeutige RE2-Figur ausblenden")
    func resultFields(_ name:String,_ type:Int32,_ size:Int,_ value:(Int)->String) -> [SaveScalar] {
        let hash=SaveCrypto.murmur(Data(name.utf8))
        return (0..<21).map {index in
            SaveScalar(id:index,owner:0x4e4210f9,field:hash,type:type,offset:index*size,size:size,
                       path:String(format:"/9e0932a9.9074a186[7]/4e4210f9.%08x[%d]",hash,index),text:value(index))
        }
    }
    let clearFields=progressFields+resultFields("ClearTime",10,8,{$0==7 ? "169007204":"0"})
        + resultFields("ClearRank",1,4,{$0==7 ? "1":"0"})
        + resultFields("SaveCount",7,4,{_ in "0"})
    let clearRecords=RE2ClearRecordCatalog.records(game:re2Game,source:re2System,fields:clearFields)
    let clearSlots=RE2ClearRecordCatalog.slots(game:re2Game,source:re2System,fields:clearFields)
    check(clearSlots.count==21 && clearSlots[7].cleared && !clearSlots[0].cleared &&
          clearSlots[7].clearTimeRaw==169007204 && clearSlots[0].clearTimeRaw==0,
          "RE2-Ergebnisübersicht liest auch die 20 unbelegten Systemplätze indexgleich")
    let wrongResultParent=clearFields.map {field in
        SaveScalar(id:field.id,owner:field.owner,field:field.field,type:field.type,
                   offset:field.offset,size:field.size,
                   path:field.path.replacingOccurrences(of:"[7]/",with:"[6]/"),text:field.text)
    }
    check(RE2ClearRecordCatalog.slots(game:re2Game,source:re2System,fields:wrongResultParent).isEmpty,
          "RE2-Abschlussplätze nur aus dem bestätigten Systemlistenindex lesen")
    check(clearRecords.count==1 && clearRecords[0].id==7 && clearRecords[0].clearTimeRaw==169007204 && clearRecords[0].rankCode==1 && clearRecords[0].saveCount==0,"RE2-Abschlussdaten verbinden vier native Listen über denselben Index")
    check(clearRecords[0].displayTime=="00:02:49" && clearRecords[0].observedScenario==nil && clearRecords[0].observedRank==nil,
          "Unbelegte Abschluss-IDs bleiben unbenannt; Zeitwert wird als Mikrosekunden angezeigt")
    let observedLeonResult=RE2ClearRecord(id:2,clearTimeRaw:169007204,rankCode:1,saveCount:0)
    check(observedLeonResult.displayTime=="00:02:49" && observedLeonResult.observedScenario=="Leon · Veteran" &&
          observedLeonResult.observedRank=="S+","Beobachteten Leon-Abschluss mit Screenshot-Zeit und Rang abgleichen")
    check(RE2ClearRecordCatalog.records(game:re2Game,source:re2Campaign,fields:clearFields).isEmpty,"Abschlussdaten nur aus RE2-Systemsave")
    check(RE2ClearRecordCatalog.records(game:re2Game,source:re2System,fields:Array(clearFields.dropLast())).isEmpty,"Unvollständige Abschlussdaten werden nicht angezeigt")
    let re2Files=try DocumentFlagCatalog.load(from:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE2_FILE_NAMES"]!))
    check(re2Files.count==64 && re2Files[1]=="Ereignisbericht" && re2Files[89]==nil,"RE2-Dokumenttitel aus lokalen Spieltexten; interne Leer-IDs ausgeschlossen")
    let re3Files=try DocumentFlagCatalog.load(from:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE3_FILE_NAMES"]!))
    check(re3Files.count==71 && re3Files[1]=="Jills Bericht" && re3Files[89]==nil,"RE3-Dokumenttitel aus lokalen Spieltexten; Platzhalter ausgeschlossen")
    let re4Documents=try StoredDocumentCatalog.load(from:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE4_DOCUMENT_NAMES"]!))
    check(re4Documents.count==53 && re4Documents["4"]=="Missionsbeschreibung","RE4-Dokumenttitel aus lokalen Spieltexten")
    let re7Documents=try StoredDocumentCatalog.load(from:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE7_DOCUMENT_NAMES"]!))
    check(re7Documents.count==110 && re7Documents["File_Title_063"]=="E-Mail von Mia","RE7-Dokumenttitel aus lokalen Spieltexten")
    let villageDocuments=try JSONDecoder().decode([String:[String:String]].self,from:Data(contentsOf:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE8_DOCUMENT_NAMES"]!)))
    check(villageDocuments["base"]?.count==56 && villageDocuments["rose"]?.count==36 && villageDocuments["rose"]?["746256480"]=="Das Megamyzet-Theorem","Village-Dokument-IDs aus installiertem Dateikatalog mit deutschen Titeln")
    check(SaveCrypto.murmur(Data())==0x81f16f39,"Murmur3 fixture")
    func re2CharacterField(_ owner:String,_ name:String,_ type:Int32,_ value:String) -> SaveScalar {
        SaveScalar(id:0,owner:SaveCrypto.murmur(Data(owner.utf8)),field:SaveCrypto.murmur(Data(name.utf8)),type:type,offset:0,size:type==15 ? value.utf16.count*2:4,path:"",text:value)
    }
    let re2Header="app.ropeway.gamemastering.MainFlowManager.GameHeaderSaveData"
    let re2Player="app.ropeway.PlayerManager.GameSaveData"
    let re2Detail="via.storage.saveService.SaveFileDetail"
    let leonFields=[re2CharacterField(re2Header,"SurvivorTypeValue",1,"0"),re2CharacterField(re2Player,"PlayerType",1,"0"),re2CharacterField(re2Detail,"SubTitle",15,"Speicherdaten – Platz 1 Leon")]
    let claireFields=[re2CharacterField(re2Header,"SurvivorTypeValue",1,"1"),re2CharacterField(re2Player,"PlayerType",1,"1000"),re2CharacterField(re2Detail,"SubTitle",15,"Speicherdaten – Platz 2 Claire")]
    check(RE2Character.name(fields:leonFields)=="Leon" && RE2Character.name(fields:claireFields)=="Claire","RE2-Charakter aus unabhängigen Header- und Spielerdaten")
    check(RE2Character.name(fields:Array(claireFields.dropLast())+[leonFields.last!])==nil,"Widersprüchlicher RE2-Savetitel wird nicht geraten")
    check(RE2Character.name(fields:[claireFields[0],leonFields[1]])==nil,"Widersprüchliche RE2-Charaktercodes werden nicht geraten")
    let leonHeaderFields=leonFields+[
        re2CharacterField(re2Header,"Title",15,"falscher Besitzer"),
        re2CharacterField(re2Detail,"Title",15,"Speichern 1"),
        re2CharacterField(re2Header,"ScenarioTypeValue",1,"0"),
        re2CharacterField(re2Header,"AreaId",1,"127"),
        re2CharacterField(re2Header,"LocationId",1,"3"),
        re2CharacterField(re2Header,"GameId",8,"31"),
        re2CharacterField("app.ropeway.gamemastering.ScenarioSequenceManager.GameSaveData","ScenarioNo",1,"33"),
        re2CharacterField("app.ropeway.GameRankSystem.GameSaveData","GameRank",7,"8")
    ]
    let shownHeader=RE2SaveHeaderCatalog.details(game:re2Game,fields:leonHeaderFields,character:"Leon")
    check(shownHeader?.title=="Speichern 1" && shownHeader?.subtitle=="Speicherdaten – Platz 1 Leon" && shownHeader?.scenarioCode==0 && shownHeader?.areaID==127 && shownHeader?.locationID==3 && shownHeader?.gameID==31 && shownHeader?.sequenceStepCode==33 && shownHeader?.dynamicRankCode==8,"RE2-Spielstandkopf zeigt nur exakte Felder aus dem richtigen Besitzer")
    check(RE2SaveHeaderCatalog.details(game:re2Game,fields:leonHeaderFields+[leonHeaderFields[5]],character:"Leon")==nil,"Mehrdeutiger RE2-Szenariocode wird nicht angezeigt")
    check(RE2SaveHeaderCatalog.details(game:GameProfile.all[1],fields:leonHeaderFields,character:"Leon")==nil,"RE2-Spielstandkopf ist spielgebunden")
    check(RE2SaveHeaderCatalog.details(game:re2Game,fields:leonHeaderFields,character:nil)==nil,"Systemsave ohne Figur hat keinen Kampagnenkopf")
    let playClockOwner=SaveCrypto.murmur(Data("app.ropeway.GameClock.GameSaveData".utf8))
    func clockField(_ name:String,_ value:String) -> SaveScalar {
        SaveScalar(id:0,owner:playClockOwner,field:SaveCrypto.murmur(Data(name.utf8)),
                   type:10,offset:0,size:8,path:"/clock",text:value)
    }
    let claireClockFields=[clockField("_GameElapsedTime","3706401757"),
                           clockField("_InventorySpendingTime","493259370"),
                           clockField("_PauseSpendingTime","578771869")]
    let claireClockFile=SaveFile(url:URL(fileURLWithPath:"/private/tmp/data002Slot.bin"),size:0,modified:Date(),kind:"DSSS")
    let claireClock=RE2PlayClockCatalog.clock(game:re2Game,source:claireClockFile,fields:claireClockFields)
    check(claireClock?.displayed==2634370518 && claireClock?.displayedTime=="00:43:54",
          "RE2-Ergebnisanzeige aus Claires drei gespeicherten Spieluhrwerten")
    check(RE2PlayClockCatalog.clock(game:re2Game,source:re2System,fields:claireClockFields)==nil,
          "RE2-Ergebnisuhr stammt nicht aus der Systemdatei")
    check(RE2PlayClockCatalog.clock(game:re2Game,source:claireClockFile,fields:claireClockFields+[claireClockFields[0]])==nil,
          "Mehrdeutige RE2-Spieluhr wird nicht angezeigt")
    var eggList=Data()
    func eggWord(_ value:UInt32) {var bytes=Data(count:4);try! bytes.put(UInt64(value),at:0,width:4);eggList+=bytes}
    eggWord(0);eggWord(1);eggWord(RE7EasterEggCatalog.owner)
    eggWord(RE7EasterEggCatalog.name);eggWord(UInt32.max)
    eggWord(16);eggWord(16);eggWord(1);eggWord(0)
    while eggList.count%16 != 0 {eggList.append(0)}
    eggList+=Data(0..<16)
    let re7Game=GameProfile.all.first{$0.id=="re7"}!
    let re7SystemFile=SaveFile(url:URL(fileURLWithPath:"/private/tmp/data00-1.bin"),size:eggList.count,modified:Date(),kind:"DSSS")
    let eggIDs=RE7EasterEggCatalog.storedIDs(game:re7Game,source:re7SystemFile,parsed:try ParsedSave(payload:eggList),payload:eggList)
    check(eggIDs==["000102030405060708090a0b0c0d0e0f"],"RE7-Sammelliste liest gespeicherte 16-Byte-Kennung ohne Zuordnungsannahme")
    check(RE7EasterEggCatalog.storedIDs(game:GameProfile.all[0],source:re7SystemFile,parsed:try ParsedSave(payload:eggList),payload:eggList)==nil,"RE7-Sammelliste ist spielgebunden")
    var emptyEgg=Data(eggList.prefix(36))
    try emptyEgg.put(0,at:28,width:4)
    let firstFigure=RE7EasterEggCatalog.figures[0]
    let setEgg=try RE7EasterEggCatalog.replace(game:re7Game,source:re7SystemFile,payload:emptyEgg,parsed:try ParsedSave(payload:emptyEgg),desired:[firstFigure.id:true])
    check(RE7EasterEggCatalog.storedIDs(game:re7Game,source:re7SystemFile,parsed:try ParsedSave(payload:setEgg),payload:setEgg)==[firstFigure.id],"RE7-Figur hinzufügen und zurücklesen")
    let clearEgg=try RE7EasterEggCatalog.replace(game:re7Game,source:re7SystemFile,payload:setEgg,parsed:try ParsedSave(payload:setEgg),desired:[firstFigure.id:false])
    check(clearEgg==emptyEgg,"RE7-Figur entfernen und leere Ausgangsliste bytegenau wiederherstellen")
    // Large, real-format RE7 UInt8 buffers must not be mistaken for a
    // million editable fields; the following ordinary field must remain aligned.
    var blob=Data()
    func word(_ value:UInt32) {var bytes=Data(count:4);try! bytes.put(UInt64(value),at:0,width:4);blob+=bytes}
    word(0);word(2);word(123);word(456);word(UInt32.max)
    word(4);word(1);word(1048704);word(0)
    blob+=Data(repeating:0x5a,count:1048704)
    word(789);word(7);word(4);word(42)
    let blobParsed=try ParsedSave(payload:blob)
    check(blobParsed.consumed==blob.count && blobParsed.fields.count==1 && blobParsed.fields[0].text=="42","Großer RE7-Byteblock samt nachfolgendem Feld")
    var largeRE7=blob
    func appendRE7Word(_ value:UInt32) {var bytes=Data(count:4);try! bytes.put(UInt64(value),at:0,width:4);largeRE7+=bytes}
    appendRE7Word(0);appendRE7Word(1);appendRE7Word(SaveCrypto.murmur(Data("app.FileSaveData".utf8)))
    appendRE7Word(SaveCrypto.murmur(Data("ReleaseFileIds".utf8)));appendRE7Word(UInt32.max)
    appendRE7Word(17);appendRE7Word(8);appendRE7Word(1);appendRE7Word(1)
    appendRE7Word(1);appendRE7Word(SaveCrypto.murmur(Data("app.FileSaveData.ReleaseFilePlayer".utf8)))
    appendRE7Word(SaveCrypto.murmur(Data("fileId".utf8)));appendRE7Word(15)
    let re7ID="File_Title_063";appendRE7Word(UInt32(re7ID.utf16.count))
    for code in re7ID.utf16 {largeRE7.append(UInt8(truncatingIfNeeded:code));largeRE7.append(UInt8(truncatingIfNeeded:code>>8))}
    let largeParsed=try ParsedSave(payload:largeRE7)
    let largeArray=DocumentListEditor.array(game:GameProfile.all.first{$0.id=="re7"}!,parsed:largeParsed)!
    check(try SaveRebuilder.replaceArray(in:largeRE7,array:largeArray,elements:largeArray.elements.map{Data(largeRE7[$0])})==largeRE7,"Großer RE7-Binärblock beim Dokument-Neuaufbau bytegenau erhalten")
    var truncated=blob;truncated.removeLast(100)
    rejected("Abgeschnittener großer Byteblock") {_=try ParsedSave(payload:truncated)}
    let clock=EditableField(id:0,title:"Zeit",description:"",scalar:SaveScalar(id:0,owner:0,field:0,type:10,offset:0,size:8,path:"",text:"3198795"),maximum:315360000,factor:1000000)
    let swapInput=Data([0,1,2,3,4,5,6,7,8,9,10,11])
    check(SaveCrypto.swapped(swapInput)==Data([3,2,1,0,7,6,5,4,11,10,9,8]) && SaveCrypto.swapped(SaveCrypto.swapped(swapInput))==swapInput,"Worttausch und zweifache Umkehrung")
    let clockZero=try clock.rawValue("0"),clockExact=try clock.rawValue("3,198795")
    check(clock.initial=="3.198795" && clockZero==0 && clockExact==3198795,"Exakte Mikrosekunden und vollständiges Zurücksetzen")
    rejected("Zu viele Zeit-Dezimalstellen") {_=try clock.rawValue("3.1987951")}
    let health=EditableField(id:0,title:"Gesundheit",description:"",scalar:SaveScalar(id:0,owner:0,field:0,type:11,offset:0,size:4,path:"",text:"999.75"),maximum:100000,factor:1)
    check(try health.rawValue("999,5")==UInt64(Float(999.5).bitPattern),"Float-Gesundheit ohne Ganzzahlkonvertierung")
    for invalid in ["nan","inf","-1","100001"] {rejected("Ungültige Float-Eingabe") {_=try health.rawValue(invalid)}}
    let itemID=EditableField(id:1,title:"Gegenstands-ID",description:"",scalar:SaveScalar(id:1,owner:0,field:0,type:1,offset:0,size:4,path:"",text:"33"),maximum:297,factor:1,minimum:1)
    check(try itemID.rawValue("32")==32,"RE2-Gegenstands-ID")
    for invalid in ["0","298","-1","1.5"] {rejected("Ungültige RE2-Gegenstands-ID") {_=try itemID.rawValue(invalid)}}
    let found=EditableField(id:2,title:"Ereignisbericht",description:"",scalar:SaveScalar(id:2,owner:DocumentFlagCatalog.owners["re2"]!,field:DocumentFlagCatalog.name,type:2,offset:0,size:1,path:"GetFileList[1]",text:"true"),maximum:1,factor:1)
    let unset=try found.rawValue("0"),set=try found.rawValue("1")
    check(found.initial=="1" && unset==0 && set==1,"RE2-Dokumentfund als einzelnes Bool-Feld")
    for invalid in ["true","false","2","-1","1.0"] {rejected("Ungültiger Dokument-Fundstatus") {_=try found.rawValue(invalid)}}
    var figures=Data()
    func figureWord(_ value:UInt32) {var bytes=Data(count:4);try! bytes.put(UInt64(value),at:0,width:4);figures+=bytes}
    figureWord(0);figureWord(1);figureWord(RaccoonFlagCatalog.owner)
    figureWord(RaccoonFlagCatalog.name);figureWord(UInt32.max)
    figureWord(16);figureWord(1);figureWord(20);figureWord(0)
    figures+=Data((0..<20).map{[0,3,7,12].contains($0) ? UInt8(1):UInt8(0)})
    let figureParsed=try ParsedSave(payload:figures)
    check(figureParsed.fields.first?.path.hasPrefix(String(format:"/%08x.%08x",RaccoonFlagCatalog.owner,RaccoonFlagCatalog.name))==true,"Save-Feldpfad behält achtstellige Hashes")
    let re2=GameProfile.all.first{$0.id=="re2"}!
    let figureFile=SaveFile(url:URL(fileURLWithPath:"/private/tmp/data00-1.bin"),size:figures.count,modified:Date(),kind:"DSSS")
    let figureFlags=RaccoonFlagCatalog.flags(game:re2,source:figureFile,parsed:figureParsed)
    check(figureFlags.count==15 && figureFlags.filter{$0.field.initial=="1"}.count==4,"RE2-Figurenarray mit vier zerstörten Figuren")
    let targetFigure=figureFlags[3].field
    try figures.put(try targetFigure.rawValue("0"),at:targetFigure.scalar.offset,width:1)
    let revisedFigures=try ParsedSave(payload:figures)
    check(RaccoonFlagCatalog.flags(game:re2,source:figureFile,parsed:revisedFigures)[3].field.initial=="0","RE2-Figurenstatus einzeln ausschalten und zurücklesen")
    rejected("Ungültiger Figurenstatus") {_=try targetFigure.rawValue("2")}
    var castellans=Data()
    func castellanWord(_ value:UInt32) {var bytes=Data(count:4);try! bytes.put(UInt64(value),at:0,width:4);castellans+=bytes}
    castellanWord(0);castellanWord(1);castellanWord(CastellanFlagCatalog.owner)
    castellanWord(CastellanFlagCatalog.name);castellanWord(UInt32.max)
    castellanWord(17);castellanWord(8);castellanWord(16);castellanWord(1)
    for (index,chapter) in CastellanFlagCatalog.chapters.enumerated() {
        castellanWord(2);castellanWord(CastellanFlagCatalog.entryOwner)
        castellanWord(CastellanFlagCatalog.chapterName);castellanWord(1);castellanWord(4);castellanWord(UInt32(chapter))
        castellanWord(CastellanFlagCatalog.brokenName);castellanWord(2);castellanWord(1)
        castellans+=Data([index==3 ? 1:0,0,0,0])
    }
    let re4=GameProfile.all.first{$0.id=="re4"}!
    let castellanFile=SaveFile(url:URL(fileURLWithPath:"/private/tmp/data00-1.bin"),size:castellans.count,modified:Date(),kind:"DSSS")
    let castellanParsed=try ParsedSave(payload:castellans)
    let castellanFlags=CastellanFlagCatalog.flags(game:re4,source:castellanFile,parsed:castellanParsed)
    check(castellanFlags.count==16 && castellanFlags.filter{$0.field.initial=="1"}.count==1 && castellanFlags[3].chapter==22100,"RE4-Kastellanenliste mit Kapitelcodes und Zerstörungsstatus")
    let targetCastellan=castellanFlags[3].field
    try castellans.put(try targetCastellan.rawValue("0"),at:targetCastellan.scalar.offset,width:1)
    check(CastellanFlagCatalog.flags(game:re4,source:castellanFile,parsed:try ParsedSave(payload:castellans))[3].field.initial=="0","RE4-Kastellanenstatus einzeln ausschalten und zurücklesen")
    rejected("Ungültiger Kastellanenstatus") {_=try targetCastellan.rawValue("2")}
    try castellans.put(2,at:targetCastellan.scalar.offset,width:1)
    rejected("Beschädigter Kastellanen-Speicherwert") {_=try ParsedSave(payload:castellans)}
    var charlies=Data()
    func charlieWord(_ value:UInt32) {var bytes=Data(count:4);try! bytes.put(UInt64(value),at:0,width:4);charlies+=bytes}
    charlieWord(0);charlieWord(1);charlieWord(CharlieFlagCatalog.owner)
    charlieWord(CharlieFlagCatalog.name);charlieWord(UInt32.max)
    charlieWord(2);charlieWord(1);charlieWord(20);charlieWord(0)
    charlies+=Data((0..<20).map{[1,6,13].contains($0) ? UInt8(1):UInt8(0)})
    let re3=GameProfile.all.first{$0.id=="re3"}!
    let charlieFile=SaveFile(url:URL(fileURLWithPath:"/private/tmp/data00-1.bin"),size:charlies.count,modified:Date(),kind:"DSSS")
    let charlieParsed=try ParsedSave(payload:charlies)
    let charlieFlags=CharlieFlagCatalog.flags(game:re3,source:charlieFile,parsed:charlieParsed)
    check(charlieFlags.count==20 && charlieFlags.filter{$0.field.initial=="1"}.count==3,"RE3-Charlie-Array mit 20 Figuren")
    let targetCharlie=charlieFlags[1].field
    try charlies.put(try targetCharlie.rawValue("0"),at:targetCharlie.scalar.offset,width:1)
    let revisedCharlie=try ParsedSave(payload:charlies)
    check(CharlieFlagCatalog.flags(game:re3,source:charlieFile,parsed:revisedCharlie)[1].field.initial=="0","RE3-Charlie-Status einzeln ausschalten und zurücklesen")
    rejected("Ungültiger Charlie-Status") {_=try targetCharlie.rawValue("2")}
    try charlies.put(2,at:targetCharlie.scalar.offset,width:1)
    rejected("Beschädigter Charlie-Speicherwert") {_=try ParsedSave(payload:charlies)}
    var locks=Data()
    func lockWord(_ value:UInt32) {var bytes=Data(count:4);try! bytes.put(UInt64(value),at:0,width:4);locks+=bytes}
    lockWord(0);lockWord(1);lockWord(DialLockFlagCatalog.owner)
    lockWord(DialLockFlagCatalog.name);lockWord(UInt32.max)
    lockWord(16);lockWord(1);lockWord(20);lockWord(0)
    locks+=Data(repeating:1,count:20)
    let lockParsed=try ParsedSave(payload:locks)
    let lockFile=SaveFile(url:URL(fileURLWithPath:"/private/tmp/data00-1.bin"),size:locks.count,modified:Date(),kind:"DSSS")
    let lockFlags=DialLockFlagCatalog.flags(game:re3,source:lockFile,parsed:lockParsed)
    check(lockFlags.count==20 && lockFlags.allSatisfy{$0.field.initial=="1"},"RE3-Schlossarray mit 20 gesetzten Flags")
    let targetLock=lockFlags[6].field
    try locks.put(try targetLock.rawValue("0"),at:targetLock.scalar.offset,width:1)
    let revisedLocks=try ParsedSave(payload:locks)
    check(DialLockFlagCatalog.flags(game:re3,source:lockFile,parsed:revisedLocks)[6].field.initial=="0","RE3-Schlossstatus einzeln ausschalten und zurücklesen")
    rejected("Ungültiger Schlossstatus") {_=try targetLock.rawValue("2")}
    for profile in GameProfile.all {check((4...56).contains(try SaveKeys.key(for:profile).count),"Spielgebundener Schlüssel vorhanden") }
    if ProcessInfo.processInfo.environment["RESAVE_TEST_FIXTURE_ONLY"]=="1" {
        for profile in GameProfile.all {
            let local=profile.container.appendingPathComponent("Library/Application Support/Test/SaveData/data001Slot.bin")
            let cloud=profile.container.appendingPathComponent("Library/Mobile Documents/iCloud~test/SaveData/data001Slot.bin")
            check(LocalSavePolicy.permitsFile(local,game:profile),"Lokaler Save-Pfad für \(profile.name)")
            check(!LocalSavePolicy.permitsFile(cloud,game:profile),"Cloud-Pfad für \(profile.name) abgelehnt")
        }
        print("OFFLINE FIXTURE TESTS PASSED: serializer, item and document catalogs, collectible flags, game keys and local-only save policy.")
        return
    }
    let game=GameProfile.all.first{$0.id=="re4"}!
    let scan=SaveDiscovery.scan(game:game)
    check(!scan.searched.contains{$0.path.contains("Mobile Documents")},"Keine Cloud-Suche")
    check(scan.files.allSatisfy{$0.kind=="DSSS" && LocalSavePolicy.permitsFile($0.url,game:game)},"Nur lokale Originaldateien")
    guard !scan.files.isEmpty else {throw SaveError.invalid("Reale lokale RE4-Saves für den Nur-Lese-Test nicht verfügbar.")}
    let scratch=FileManager.default.temporaryDirectory.appendingPathComponent("RESaveEditorTest-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:scratch,withIntermediateDirectories:true)
    defer {try? FileManager.default.removeItem(at:scratch)}
    var checked=0,fieldsChecked=0
    for input in scan.files {
        let original=try Data(contentsOf:input.url),fingerprint=Data(SHA256.hash(data:original))
        let container=try SaveContainer(data:original),parsed=try ParsedSave(payload:container.payload)
        check(try container.encode()==original,"Unveränderte Rückverschlüsselung")
        check(parsed.consumed==container.payload.count,"Gesamte Save-Struktur gelesen")
        let doc=try SaveDocument(file:input,game:game)
        if input.url.lastPathComponent=="data00-1.bin" {
            let documents=StoredDocumentCatalog.rows(game:game,source:input,parsed:doc.parsed,names:re4Documents)
            check(documents.count>=53 && documents.contains{$0.id=="4" && $0.isRecorded},"RE4-Leseliste und echte Dokumenttitel aus Systemdaten")
            let target=documents.first{$0.canEdit && !$0.isRecorded}!
            let amended=try DocumentListEditor.replace(game:game,payload:doc.container.payload,parsed:doc.parsed,desired:[target.id:true],rows:documents)
            var wrapped=doc.container;wrapped.payload=amended
            let bytes=try wrapped.encode(allowSizeChange:true)
            let verified=try SaveContainer(data:bytes)
            let changedRows=StoredDocumentCatalog.rows(game:game,source:input,parsed:try ParsedSave(payload:verified.payload),names:re4Documents)
            check(changedRows.first{$0.id==target.id}?.isRecorded==true,"RE4-Lesestatus im neu serialisierten Save")
            let unchanged=try SaveRebuilder.replaceArray(in:doc.container.payload,array:DocumentListEditor.array(game:game,parsed:doc.parsed)!,elements:DocumentListEditor.array(game:game,parsed:doc.parsed)!.elements.map{Data(doc.container.payload[$0])})
            check(unchanged==doc.container.payload,"Serializer reproduziert RE4-Systemdatei unverändert bytegenau")
        }
        for field in doc.editable {
            var values=Dictionary(uniqueKeysWithValues:doc.editable.map{($0.id,$0.initial)})
            let before=Double(field.initial)!,after=before>=Double(field.maximum) ? before-1:before+1
            values[field.id]=field.factor==1 && !field.isFloating ? String(UInt64(after)):String(after)
            let output=try doc.encodedData(values),changed=try SaveContainer(data:output)
            let ranges=([field.scalar]+field.mirrors).map{$0.offset..<($0.offset+$0.size)}
            for scalar in [field.scalar]+field.mirrors {check(try changed.payload.uint(scalar.offset,scalar.size)==field.rawValue(values[field.id]!),"Bearbeitetes Feld zurückgelesen")}
            for offset in container.payload.indices where !ranges.contains(where:{$0.contains(offset)}) {check(changed.payload[offset]==container.payload[offset],"Andere Daten bleiben identisch")}
            check(Data(output.prefix(32))==Data(original.prefix(32)),"Kontozuordnung und Header erhalten")
            let fixture=scratch.appendingPathComponent("data001Slot.bin")
            try original.write(to:fixture)
            try FileManager.default.setAttributes([.posixPermissions:0o640],ofItemAtPath:fixture.path)
            try LocalSaveWriter.replaceExisting(at:fixture,expected:fingerprint,output:output) {written in
                check(try SaveContainer(data:written).payload==changed.payload,"Geschriebene Datei entschlüsselt")
            }
            check(try Data(contentsOf:fixture)==output,"Bestehender Pfad enthält bearbeiteten Save")
            check((try FileManager.default.attributesOfItem(atPath:fixture.path)[.posixPermissions] as? NSNumber)?.intValue==0o640,"Dateirechte erhalten")
            check(try FileManager.default.contentsOfDirectory(atPath:scratch.path).filter{$0.hasPrefix(".resave-")}.isEmpty,"Kein Austauschbestand bleibt zurück")
            rejected("Veralteter Ausgangsstand") {try LocalSaveWriter.replaceExisting(at:fixture,expected:fingerprint,output:original,verify:{_ in})}
            check(try Data(contentsOf:fixture)==output,"Veraltete Änderung überschreibt nichts")
            // Fail only after the atomic exchange: the original fixture must return.
            try original.write(to:fixture)
            var verificationCount=0
            rejected("Fehlgeschlagene Rückprüfung") {
                try LocalSaveWriter.replaceExisting(at:fixture,expected:fingerprint,output:output) {_ in
                    verificationCount+=1
                    if verificationCount==2 {throw SaveError.invalid("Erzwungener Rückprüfungsfehler")}
                }
            }
            check(verificationCount==2,"Rücknahme nach Austausch tatsächlich ausgeführt")
            check(try Data(contentsOf:fixture)==original,"Original bei Fehler atomar wiederhergestellt")
            // Simulate another writer immediately before commit.
            var concurrent=original;concurrent[40]^=1
            rejected("Gleichzeitige Änderung vor Austausch") {
                try LocalSaveWriter.replaceExisting(at:fixture,expected:fingerprint,output:output,beforeSwap:{try concurrent.write(to:fixture)},verify:{_ in})
            }
            check(try Data(contentsOf:fixture)==concurrent,"Fremde Änderung bleibt erhalten")
            var invalid=values;invalid[field.id]="-1";rejected("Negative Werte") {_=try doc.encodedData(invalid)}
            invalid[field.id]=String(field.maximum+1);rejected("Überlauf") {_=try doc.encodedData(invalid)}
            fieldsChecked+=1
        }
        var corrupt=original;corrupt[40]^=1;rejected("Falsche Prüfsumme") {_=try SaveContainer(data:corrupt)}
        rejected("Falscher Schlüssel") {_=try SaveContainer(data:original,key:Data("invalid-key".utf8))}
        rejected("Abgeschnittene Datei") {_=try SaveContainer(data:Data(original.prefix(30)))}
        check(Data(SHA256.hash(data:try Data(contentsOf:input.url)))==fingerprint,"Echter Spielstand im Test unverändert")
        checked+=1
    }
    let cloud=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/iCloud~jp~co~capcom~RE4US/Documents/SaveData/data001Slot.bin")
    check(!LocalSavePolicy.permitsFile(cloud,game:game),"Cloud-Pfad abgelehnt")
    check(!LocalSavePolicy.permitsFolder(cloud.deletingLastPathComponent(),game:game),"Cloud-Ordnerfreigabe abgelehnt")
    for profile in GameProfile.all {
        let nestedCloud=profile.container.appendingPathComponent("Library/Mobile Documents/iCloud~test/SaveData/data001Slot.bin")
        check(!LocalSavePolicy.permitsFile(nestedCloud,game:profile),"Auch Cloud-Unterordner im Spielcontainer abgelehnt")
        let normal=profile.container.appendingPathComponent("Library/Application Support/Test/SaveData/data001Slot.bin")
        check(LocalSavePolicy.permitsFile(normal,game:profile),"Lokale Spielcontainer-Ziele aller Profile")
    }
    let wrongGame=GameProfile.all.first{$0.id=="re3"}!
    check(!LocalSavePolicy.permitsFile(scan.files[0].url,game:wrongGame),"Anderer Spielcontainer abgelehnt")
    let outside=SaveDiscovery.scan(game:game,extra:scratch)
    check(outside.files.isEmpty && outside.searched.isEmpty && outside.denied.count==1,"Fremder Ordner wird nicht durchsucht")
    let pack=SaveFile(url:game.container.appendingPathComponent("SaveData/saveDataPackFile.bin"),size:64,modified:Date(),kind:"PACK")
    rejected("Paket-Eingabe") {_=try SaveDocument(file:pack,game:game)}
    let link=scratch.appendingPathComponent("linked.bin")
    try FileManager.default.createSymbolicLink(at:link,withDestinationURL:scratch.appendingPathComponent("data001Slot.bin"))
    rejected("Symbolischer Link als Schreibziel") {try LocalSaveWriter.replaceExisting(at:link,expected:Data(),output:Data(),verify:{_ in})}
    check(try FileManager.default.contentsOfDirectory(atPath:scratch.path).filter{$0.hasPrefix(".resave-")}.isEmpty,"Alle temporären Austauschdateien entfernt")
    check(checked>=2,"Reale Slot- und Systemdaten geprüft")
    print("LOCAL SAVE TESTS PASSED: \(checked) real files read only, \(fieldsChecked) field edits; existing-path atomic replacement on disposable fixtures, permissions, checksum/account/other-byte preservation, stale/concurrent-change rejection, rollback after readback failure, cloud/pack/foreign-folder/symlink rejection; no persistent copies and real saves unchanged.")
 }
}
