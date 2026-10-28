import Foundation

// Names come from the exact installed Mac builds' native type metadata.
// A field is offered only when its owner/name pair is unique and its on-disk
// primitive type agrees. Repeated NPC, inventory and challenge data is excluded.
enum SaveSchemas {
    struct Specification {
        let owner:UInt32;let name:String;let title:String;let detail:String
        let type:Int32;let maximum:UInt64;let factor:UInt64
        init(_ owner:String,_ name:String,_ title:String,_ detail:String,type:Int32=7,maximum:UInt64=9999999,factor:UInt64=1) {
            self.owner=SaveCrypto.murmur(Data(owner.utf8));self.name=name;self.title=title;self.detail=detail;self.type=type;self.maximum=maximum;self.factor=factor
        }
        init(hash:UInt32,name:String,title:String,detail:String,type:Int32=7,maximum:UInt64=9999999,factor:UInt64=1) {
            owner=hash;self.name=name;self.title=title;self.detail=detail;self.type=type;self.maximum=maximum;self.factor=factor
        }
    }
    static func fields(game:GameProfile,parsed:ParsedSave) throws -> [EditableField] {
        let specs:[Specification]
        switch game.id {
        case "re2","re3":
            let prefix=game.id=="re2" ? "app.ropeway":"offline"
            var list=[Specification(prefix+".survivor.player.PlayerCondition.GameSaveData","HP","Gesundheit des Spielers","Gespeicherte Lebenspunkte. Erscheint nur bei genau einem Spieler-Datensatz.",maximum:100000),
                      Specification(prefix+".gamemastering.RecordManager.GameSaveData","OpenItemBox","Itembox geöffnet","Anzahl der Itembox-Nutzungen in diesem Spielstand.",maximum:999999),
                      Specification(prefix+".gamemastering.RecordManager.GameSaveData","UseHealItem","Heilgegenstände benutzt","Anzahl benutzter Heilgegenstände in diesem Spielstand.",maximum:999999)]
            for (name,title) in [("_GameElapsedTime","Spieluhr gesamt (Sekunden)"),("_DemoSpendingTime","Zeit in Zwischensequenzen (Sekunden)"),("_InventorySpendingTime","Zeit im Inventar (Sekunden)"),("_PauseSpendingTime","Zeit im Pausemenü (Sekunden)")] {
                list.append(Specification(prefix+".GameClock.GameSaveData",name,title,"Gespeicherter Teil der Spieluhr. Zum vollständigen Zurücksetzen alle vier Spieluhr-Werte auf 0 setzen.",type:10,maximum:315360000,factor:1000000))
            }
            list += [Specification(prefix+".EnemyManager.GameSaveData","TotalEnemyKillCount","Besiegte Gegner","Gespeicherter Gegnerzähler dieses Spielstands.",type:8,maximum:999999),
                     Specification(prefix+".PlayerManager.GameSaveData","CounterAttackNumber","Gegenangriffe","Gespeicherter Zähler ausgeführter Gegenangriffe.",maximum:999999),
                     Specification(prefix+".PlayerManager.GameSaveData","DamagedNumber","Eingesteckte Treffer","Gespeicherter Zähler der Gegnertreffer.",maximum:999999),
                     Specification(prefix+".gamemastering.MainFlowManager.GameHeaderSaveData","SaveTimes","Speicherungen in diesem Spielstand","Zähler im Spielstandkopf; löscht keine Spielstände.",maximum:999999),
                     Specification(prefix+".GameRankSystem.GameSaveData","RankPoint","Dynamischer Rangwert","Gespeicherter Rangwert dieses Spielstands.",type:11,maximum:1000000),
                     Specification(prefix+".gamemastering.InventoryManager.SaveData","GetItemCount","Aufgesammelte Gegenstände (Zähler)","Gespeicherter Aufnahmezähler; fügt dem Inventar keine Gegenstände hinzu.",maximum:999999)]
            if game.id=="re2" {
                list += [Specification("app.ropeway.PlayerManager.GameSaveData","Pedometer","Schritte (Statistik)","Gespeicherter Schrittzähler dieser Spielfigur.",maximum:99999999),
                         Specification("app.ropeway.PlayerManager.GameSaveData","TotalMovingDistance","Bewegungsdistanz (Spielwert)","Gespeicherte Bewegung; die Einheit ist im Spielstand nicht angegeben.",type:11,maximum:10000000),
                         Specification(hash:0x6f91cbfe,name:"FireCount",title:"Abgegebene Schüsse (Statistik)",detail:"Gespeicherter Schusszähler dieses Spielstands.",type:8,maximum:999999),
                         Specification(hash:0x6f91cbfe,name:"ContactCount",title:"Schusskontakte (Statistik)",detail:"Vom Spiel registrierte Kontakte; nicht zwingend Treffer gegen Gegner.",type:8,maximum:999999)]
            }
            if game.id=="re3" {
                list += [Specification("offline.gamemastering.RecordManager.SystemSaveData","TotalShopPoint","Shop-Punkte","Gespeicherter Punktestand für den Shop; hebt keine Artikelsperren auf."),
                         Specification("offline.gamemastering.MainFlowManager.GameHeaderSaveData","DeadCount","Tode in diesem Spielstand","Zähler im Spielstandkopf.",maximum:999999),
                         Specification("offline.gamemastering.RecordManager.GameSaveData","NemesisDownCount","Nemesis niedergeschlagen","Gespeicherter Zähler für niedergeschlagenen Nemesis.",maximum:999999),
                         Specification("offline.gamemastering.RecordManager.GameSaveData","EmergencyAvoidanceCount","Ausweichmanöver","Gespeicherter Zähler für Ausweichmanöver.",maximum:999999),
                         Specification("offline.gamemastering.RecordManager.GameSaveData","VomitingCount","Erbrochen","Gespeicherter Ereigniszähler.",maximum:999999)]
            }
            specs=list
        case "re4":
            var list=[Specification(hash:0x52dfdaa8,name:"PTAS",title:"Peseten",detail:"Geldbestand dieses Spielstands."),
                   Specification(hash:0x4d4f1555,name:"_ExPoint",title:"Bonuspunkte (CP)",detail:"Punkte für den Bonusshop; schaltet keine Artikel automatisch frei."),
                   Specification(hash:0xf53e644f,name:"_SaveCount",title:"Anzahl Speicherungen",detail:"Kampagnen-Zähler; löscht keine Spielstände.",maximum:99999),
                   Specification(hash:0x8b03d75b,name:"_GameElapsedTime",title:"Spielzeit (Sekunden)",detail:"Gespeicherte Kampagnenzeit einschließlich Bruchteilen einer Sekunde.",type:10,maximum:315360000,factor:1000000)]
            for (name,title) in [("_DemoSpendingTime","Zeit in Zwischensequenzen (Sekunden)"),("_InventorySpendingTime","Zeit im Inventar (Sekunden)"),("_PauseSpendingTime","Zeit im Pausemenü (Sekunden)")] {
                list.append(Specification("share.GameClock.GameSaveData",name,title,"Gespeicherter Teil der Kampagnenuhr. Für das vollständige Zurücksetzen alle vier Zeitwerte auf 0 setzen.",type:10,maximum:315360000,factor:1000000))
            }
            list += [Specification("chainsaw.GameRankSystem.GameRankSaveData","ActionPoint","Rangpunkte: Aktionen","Gespeicherter Ranganteil für Aktionen.",type:11,maximum:1000000),
                     Specification("chainsaw.GameRankSystem.GameRankSaveData","ItemPoint","Rangpunkte: Gegenstände","Gespeicherter Ranganteil für Gegenstände.",type:11,maximum:1000000),
                     Specification("chainsaw.GameRankSystem.GameRankSaveData","RankPointKillCount","Rangzähler: besiegte Gegner","Gespeicherter Gegnerzähler der Rangberechnung.",maximum:999999)]
            specs=list
        case "re7":
            specs=[Specification("app.SaveData","PlayTime","Spielzeit (Sekunden)","Gespeicherte Spielzeit in ganzen Sekunden.",maximum:315360000),
                   Specification("app.PlayerStatus.PlayerSaveDataClass","Health","Gesundheit des Spielers","Gespeicherte Lebenspunkte; nur bei genau einem eindeutig vorhandenen Spieler.",type:11,maximum:100000),
                   Specification("app.SaveData","RestartCount","Neustarts nach dem Tod","Gespeicherter Neustart-Zähler dieses Spielstands.",maximum:999999),
                   Specification("app.OptionMenu.SaveData","_openedItemBoxCount","Itembox geöffnet","Anzahl der Itembox-Nutzungen.",type:8,maximum:999999),
                   Specification("app.OptionMenu.SaveData","_antiqueCoinCount","Antike Münzen gefunden","Statistik gefundener Münzen; erzeugt keine Münzen im Inventar.",type:8,maximum:999999),
                   Specification("app.OptionMenu.SaveData","_useHealingCount","Heilgegenstände benutzt","Anzahl benutzter Heilgegenstände.",type:8,maximum:999999),
                   Specification("app.OptionMenu.SaveData","_useStabilizersCount","Stabilisatoren benutzt","Gespeicherter Nutzungszähler; verändert keine Waffenwerte.",type:8,maximum:999999),
                   Specification("app.OptionMenu.SaveData","_useSteroidsCount","Steroide benutzt","Gespeicherter Nutzungszähler; verändert nicht die maximale Gesundheit.",type:8,maximum:999999),
                   Specification("app.SaveData","RankPoint","Dynamischer Rangwert","Gespeicherter Rangwert dieses Spielstands.",type:11,maximum:1000000),
                   Specification("app.OptionMenu.SaveData","_successJustGuardCount","Erfolgreiche perfekte Blocks","Gespeicherter Block-Zähler.",type:8,maximum:999999)]
        case "re8":
            let rose=parsed.fields.contains{$0.owner==SaveCrypto.murmur(Data("app.Ch10PlayerInfoHolder.Ch10PlayerInfo_SaveSection".utf8))}
            var list=[Specification("app.PlayerInfo_SaveSection","SaveHealth","Gesundheit des Spielers","Gespeicherte Lebenspunkte von Ethan beziehungsweise Rose.",type:11,maximum:100000),
                      Specification("app.CPManager.SystemSaveData","CP","Bonuspunkte (CP)","Punkte für den Bonusshop; schaltet keine Artikel automatisch frei."),
                      Specification(rose ? "app.Ch10GameRecordManager.SaveDataCh10.PlayerUnit":"app.GameRecordManager.SaveData.PlayerUnit","CountOfDead","Anzahl Tode",rose ? "Todeszähler des Rose-DLC-Spielstands.":"Todeszähler dieses Hauptspiel-Spielstands.",maximum:999999)]
            list += [Specification("app.GameRecordManager.SystemSaveData","TotalGotMoney","Insgesamt erhaltene Lei (Statistik)","Systemweiter Aufnahmezähler; ändert nicht den aktuellen Lei-Bestand.",maximum:999999999),
                     Specification("app.GameRecordManager.SystemSaveData","CountOfGameClears","Hauptspiel-Abschlüsse (Systemstatistik)","Systemweiter Abschlusszähler; schaltet keine Inhalte frei.",maximum:999999),
                     Specification("app.Ch10GameRecordManager.SystemSaveDataCh10","CountOfGameClears","Rose-Abschlüsse (Systemstatistik)","Systemweiter Abschlusszähler des Rose-DLC; schaltet keine Inhalte frei.",maximum:999999)]
            if rose {
                list += [Specification("app.Ch10PlayerInfoHolder.Ch10PlayerInfo_SaveSection","SaveCurrentESPEnergy","Roses gespeicherte Kraftenergie","Energievorrat der übernatürlichen Fähigkeit im Rose-DLC.",maximum:100000),
                         Specification("app.Ch10RankManager.SaveDataClass","rankPoint","Roses Rangpunkte","Gespeicherter Rangwert im Rose-DLC.",maximum:1000000),
                         Specification("app.Ch10GameRecordManager.SaveDataCh10.PlayerUnit","CountOfGameClears","Rose-DLC abgeschlossen (Zähler)","Gespeicherter Abschlusszähler im Rose-DLC.",maximum:999999)]
            } else {
                list += [Specification("app.InventoryManager.SaveData","money","Lei","Geldbestand dieses Hauptspiel-Spielstands."),
                         Specification("app.RankManager.SaveDataClass","rankPoint","Dynamischer Rangwert","Gespeicherter Rangwert des Hauptspiels.",maximum:1000000),
                         Specification("app.GameRecordManager.SaveData.PlayerUnit","CountOfGameClears","Hauptspiel abgeschlossen (Zähler)","Gespeicherter Abschlusszähler dieses Spielstands.",maximum:999999),
                         Specification("app.GameRecordManager.SaveData.PlayerUnit","UsedMoney","Ausgegebene Lei (Statistik)","Gespeicherter Ausgabenzähler; ändert den aktuellen Lei-Bestand nicht.",maximum:999999999)]
            }
            list.append(Specification(rose ? "app.Ch10GameRecordManager.SaveDataCh10.PlayerUnit":"app.GameRecordManager.SaveData.PlayerUnit","CountOfCompound","Herstellungen (Zähler)","Gespeicherter Herstellungszähler; fügt keine Gegenstände hinzu.",maximum:999999))
            specs=list
        default:throw SaveError.invalid("Unbekanntes Spielprofil.")
        }
        var result:[EditableField]=[]
        for spec in specs {
            let matches=parsed.fields.filter{$0.owner==spec.owner && $0.field==SaveCrypto.murmur(Data(spec.name.utf8))}
            guard matches.count==1,let scalar=matches.first else {continue}
            guard scalar.type==spec.type,scalar.size==(spec.type==10 || spec.type==12 ? 8:4) else {throw SaveError.invalid("\(spec.title): Der Datentyp stimmt nicht mit dem bestätigten Save-Schema überein.")}
            let field=EditableField(id:scalar.id,title:spec.title,description:spec.detail,scalar:scalar,maximum:spec.maximum,factor:spec.factor)
            // Inactive player placeholders (for example -1 health) are not edits.
            guard (try? field.rawValue(field.initial)) != nil else {continue}
            result.append(field)
        }
        if game.id=="re8" {
            // Native PlayingTimeHash (3613960333), confirmed in both Ethan and
            // Rose saves. Select the dictionary key/value pair, never array[0].
            let keys=parsed.fields.filter{$0.owner==0x7acfd0c8 && $0.field==0xb47c1b3e && $0.type==8 && $0.size==4 && $0.text=="3613960333"}
            if keys.count==1,let key=keys.first,let slash=key.path.lastIndex(of:"/") {
                let valuePath=String(key.path[..<slash])+"/7acfd0c8.fd8c731e/8cf1c719."
                for (name,title) in [("Time","Spieluhr gesamt (Sekunden)"),("Time_pause","Pausenanteil der Spieluhr (Sekunden)")] {
                    let hash=SaveCrypto.murmur(Data(name.utf8))
                    let matches=parsed.fields.filter{$0.owner==0x8cf1c719 && $0.field==hash && $0.path==valuePath+String(format:"%08x",hash)}
                    if matches.count==1,let scalar=matches.first,scalar.type==12,scalar.size==8 {
                        let field=EditableField(id:scalar.id,title:title,description:"Aktive Spieluhr des Hauptspiels beziehungsweise Rose-DLC. Zum Zurücksetzen beide Zeitwerte auf 0 vormerken.",scalar:scalar,maximum:315360000,factor:1000)
                        if (try? field.rawValue(field.initial)) != nil {result.append(field)}
                    }
                }
            }
        }
        return result
    }
}
