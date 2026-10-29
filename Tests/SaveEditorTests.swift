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
    let re2FieldNames=try RE2FieldNameCatalog.load(from:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE2_FIELD_NAMES"]!))
    check(re2FieldNames.count==319 && re2FieldNames["9d58d1c7"]==["id"] && re2FieldNames["f7ec3e63"]==["HP"] && re2FieldNames["9074a186"]==["SystemSaveDataList"],"RE2-Skalar- und Pfadfeldnamen aus installiertem Build")
    check(re2FieldNames["ad69cc16"]==["HeightExpand","LastSavedTimeStamp"],"RE2-Hashkollision wird nicht geraten")
    let re2OwnerNames=try RE2OwnerNameCatalog.load(from:URL(fileURLWithPath:ProcessInfo.processInfo.environment["RESAVE_RE2_OWNER_NAMES"]!))
    check(re2OwnerNames.count==106 &&
          re2OwnerNames["4e4210f9"]==["app.ropeway.gamemastering.RecordManager.SystemSaveData"] &&
          re2OwnerNames["2f11c239"]==["app.ropeway.CostumeManager.SystemSaveData"] &&
          re2OwnerNames["2a3b1ae0"]==["app.ropeway.CostumeManager.CostumeData"] &&
          re2OwnerNames["00215d66"]==["via.userdata.Variable"] &&
          re2OwnerNames["2675722d"]==["app.ropeway.gamemastering.InventoryManager.PrimitiveItem"] &&
          re2OwnerNames["55d1d375"]==["app.ropeway.gamemastering.InventoryManager.ItemExData"] &&
          re2OwnerNames["2b1634eb"]==["via.storage.saveService.SaveFileDetail"] &&
          re2OwnerNames["090ff53c"]==["app.ropeway.gamemastering.UIMapManager.SaveData"],
          "RE2-Besitzernamen aus nativen Klassen- und Namespace-Zeichenketten")
    check(re2OwnerNames["b15a035f"]?.count==2,"Mehrdeutiger RE2-Besitzerhash behält beide Kandidaten")
    let labeledCostumePath=RE2FieldNameCatalog.labeledPath("/9e0932a9.9074a186[6]/2f11c239.0c0cda67[0]/2a3b1ae0.6686824e",fieldNames:re2FieldNames,ownerNames:re2OwnerNames)
    check(labeledCostumePath.contains("SystemSaveDataList[6]") && labeledCostumePath.contains("UserCostumeDataList[0]") && labeledCostumePath.hasSuffix("app.ropeway.CostumeManager.CostumeData.CostumeID"),"RE2-Pfad zeigt belegte Listen- und Typnamen")
    check(RE2FieldNameCatalog.labeledPath("/b15a035f.695a3627[0]",fieldNames:re2FieldNames,ownerNames:re2OwnerNames)=="/b15a035f._Data[0]","Mehrdeutiger Besitzer wird im lesbaren Pfad nicht geraten")
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
    let re2ItemOwner="app.ropeway.gamemastering.ItemManager.SystemSaveData"
    let re2SystemStatus=re2StatusFields(re2ItemOwner,"GetItemList",297,[15,32])+re2StatusFields(re2ItemOwner,"GetWeaponList",383,[9])
    let systemHistory=RE2ItemHistoryCatalog.lists(game:re2Game,source:re2System,fields:re2SystemStatus,names:names)
    check(systemHistory.count==2 && systemHistory[0].recorded.map(\.name)==["Pistolenmunition","Farbband"] && systemHistory[1].recorded.map(\.name)==["SLS 60"],"RE2-Systemstatus zeigt benannte Gegenstände und Waffen nach nativer ID")
    let searchedStatus=re2StatusFields("app.ropeway.gamemastering.ItemManager.SaveData","IsSearchedItem",297,[87,102])
    let campaignHistory=RE2ItemHistoryCatalog.lists(game:re2Game,source:re2Campaign,fields:searchedStatus,names:names)
    check(campaignHistory.count==1 && campaignHistory[0].recorded.map(\.name)==["S.T.A.R.S.-Abzeichen","USB-Dongle"],"RE2-Untersuchungsstatus wird spielstandgebunden angezeigt")
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
    func re2ProgressFields(_ name:String,_ count:Int,_ marked:Set<Int>) -> [SaveScalar] {
        let hash=SaveCrypto.murmur(Data(name.utf8))
        return (0..<count).map {index in
            SaveScalar(id:index,owner:0x4e4210f9,field:hash,type:2,offset:index,size:1,
                       path:String(format:"/4e4210f9.%08x[%d]",hash,index),
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
    func resultFields(_ name:String,_ type:Int32,_ size:Int,_ value:(Int)->String) -> [SaveScalar] {
        let hash=SaveCrypto.murmur(Data(name.utf8))
        return (0..<21).map {index in
            SaveScalar(id:index,owner:0x4e4210f9,field:hash,type:type,offset:index*size,size:size,
                       path:String(format:"/4e4210f9.%08x[%d]",hash,index),text:value(index))
        }
    }
    let clearFields=progressFields+resultFields("ClearTime",10,8,{$0==7 ? "169007204":"0"})
        + resultFields("ClearRank",1,4,{$0==7 ? "1":"0"})
        + resultFields("SaveCount",7,4,{_ in "0"})
    let clearRecords=RE2ClearRecordCatalog.records(game:re2Game,source:re2System,fields:clearFields)
    check(clearRecords.count==1 && clearRecords[0].id==7 && clearRecords[0].clearTimeRaw==169007204 && clearRecords[0].rankCode==1 && clearRecords[0].saveCount==0,"RE2-Abschlussdaten verbinden vier native Listen über denselben Index")
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
