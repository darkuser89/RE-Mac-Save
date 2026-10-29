import SwiftUI
struct ContentView:View {
    @StateObject private var store=EditorStore()
    var body:some View {
        VStack(spacing:0) {
        NavigationSplitView {
            List(selection:$store.gameID) {
                Section("Spiele") {
                    ForEach(GameProfile.all) {game in
                        VStack(alignment:.leading,spacing:3) {
                            Text(game.name).font(.headline)
                            let scan=store.scans[game.id]
                            Text(scan?.denied.isEmpty==false ? "Zugriff erforderlich" : "\(scan?.files.count ?? 0) lokale Saves").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical,5).tag(game.id)
                    }
                }
            }.listStyle(.sidebar).navigationSplitViewColumnWidth(min:190,ideal:205,max:240)
        } content: {
            VStack(alignment:.leading,spacing:0) {
                HStack {Text("Spielstände").font(.headline);Spacer();Text("\(store.files.count)").foregroundStyle(.secondary)}.padding()
                if store.files.isEmpty {
                    ContentUnavailableView("Keine lesbaren Saves",systemImage:"folder.badge.questionmark",description:Text("Wähle den SaveData-Ordner, falls macOS den automatischen Zugriff sperrt."))
                } else {
                    List(store.files,selection:$store.selectedFile) {file in
                        VStack(alignment:.leading,spacing:4) {
                            Text(file.title).font(.headline)
                            Text(file.url.lastPathComponent).font(.caption.monospaced()).foregroundStyle(.secondary)
                            Text(file.modified,format:.dateTime.day().month().year().hour().minute()).font(.caption2).foregroundStyle(.secondary)
                        }.padding(.vertical,5).tag(file.id)
                    }
                }
                Divider()
                VStack(alignment:.leading,spacing:8) {
                    Button("Lokalen Ordner freigeben …",systemImage:"folder.badge.plus",action:store.chooseFolder)
                    Button("Im Finder zeigen",systemImage:"folder",action:store.revealFolder)
                }.padding()
            }.navigationSplitViewColumnWidth(min:210,ideal:235,max:300)
        } detail: {
            EditorDetailView(store:store)
        }
        .navigationTitle("Resident Evil Save Editor")
        .toolbar {
            ToolbarItem {Button(action:store.inspectSelectedFormat){Label("Ausgewählten Save prüfen",systemImage:"checkmark.shield.fill")}.disabled(store.busy || store.selectedFile==nil)}
            ToolbarItem {Button(action:store.inspectFormats){Label("Saves dieses Spiels prüfen",systemImage:"checkmark.shield")}.disabled(store.busy || store.scans.isEmpty)}
            ToolbarItem {Button(action:store.inspectAllFormats){Label("Alle fünf Spiele prüfen",systemImage:"checkmark.shield.lefthalf.filled")}.disabled(store.busy || store.scans.isEmpty)}
            ToolbarItem {Button(action:store.exportInventory){Label("Fundliste exportieren",systemImage:"list.bullet.rectangle")}.disabled(store.busy || store.scans.isEmpty)}
            ToolbarItem {Button(action:store.refresh){Label("Neu suchen",systemImage:"arrow.clockwise")}.disabled(store.busy)}
        }
        .disabled(store.isSaving || store.isInspecting)
        Divider()
        HStack(spacing:8){if store.busy {ProgressView().controlSize(.small)};Text(store.message).font(.caption).foregroundStyle(.secondary);Spacer();Text("Nur lokale Spielstände").font(.caption).foregroundStyle(.secondary)}.padding(10).background(.bar)
        }
        .onAppear{store.refresh()}
        .onChange(of:store.gameID){_,_ in store.switchGame()}
        .onChange(of:store.selectedFile){_,_ in store.load()}
    }
}
struct EditorDetailView:View {
    @ObservedObject var store:EditorStore
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                VStack(alignment:.leading,spacing:7) {
                    Text(store.game.name).font(.largeTitle.bold())
                    Text("Lokale Spielstände direkt bearbeiten").font(.title3).foregroundStyle(.secondary)
                }
                if let doc=store.document {
                    Label("Lokale Datei und Entschlüsselung geprüft",systemImage:"checkmark.shield.fill").foregroundStyle(.green)
                    VStack(alignment:.leading,spacing:6) {Text(doc.source.title).font(.headline);Text(doc.source.url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled);Text("\(doc.parsed.objects) Datenobjekte · \(doc.parsed.fields.count) Felder · \(ByteCountFormatter.string(fromByteCount:Int64(doc.source.size),countStyle:.file))").font(.caption).foregroundStyle(.secondary)}
                    if let character=doc.character {Label("Spielfigur: \(character)",systemImage:"person.fill").font(.headline)}
                    if let difficulty=doc.difficulty {Label("Schwierigkeit: \(difficulty)",systemImage:"shield.lefthalf.filled").font(.headline)}
                    if let header=doc.re2SaveHeader {
                        VStack(alignment:.leading,spacing:5) {
                            Text("RE2-Spielstandkopf").font(.headline)
                            if let title=header.title {Text("Gespeicherter Titel: \(title)")}
                            if let subtitle=header.subtitle {Text("Gespeicherter Untertitel: \(subtitle)")}
                            Text("Szenariocode \(header.scenarioCode) · Bereichs-ID \(header.areaID) · Orts-ID \(header.locationID)").font(.subheadline.monospacedDigit())
                            if let gameID=header.gameID {Text("Interne Spiel-ID: \(gameID)").font(.caption)}
                            if let step=header.sequenceStepCode {Text("Interner Fortschrittsschritt: \(step)").font(.caption.monospacedDigit())}
                            if let rank=header.dynamicRankCode {Text("Dynamischer Rangcode: \(rank)").font(.caption.monospacedDigit())}
                            Text("Kennungen aus dem Save; Szenario, Ort, Fortschrittsschritt und Rangcode sind noch keinem Spielnamen sicher zugeordnet.").font(.caption).foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                    }
                    Divider()
                    let inventoryIDs=Set(doc.items.flatMap{[$0.identity,$0.quantity].compactMap{$0?.id}})
                    let fileFlagIDs=Set(doc.fileFlags.map{$0.field.id})
                    let raccoonFlagIDs=Set(doc.raccoonFlags.map{$0.field.id})
                    let castellanFlagIDs=Set(doc.castellanFlags.map{$0.field.id})
                    let charlieFlagIDs=Set(doc.charlieFlags.map{$0.field.id})
                    let dialLockFlagIDs=Set(doc.dialLockFlags.map{$0.field.id})
                    if !doc.items.isEmpty {
                        Divider()
                        Text("Gegenstände im Spielstand").font(.title2.bold())
                        Text("Inventar und Itembox sind getrennt. Bei RE2/RE3 lassen sich ID und Menge bereits belegter einfacher Gegenstände ändern. Waffen und leere Plätze bleiben gesperrt.").font(.caption).foregroundStyle(.secondary)
                        ForEach(["Inventar","Itembox"],id:\.self) {section in
                            let rows=doc.items.filter{$0.section==section}
                            if !rows.isEmpty {Text("\(section) · \(rows.count) Einträge").font(.headline)}
                            ForEach(rows) {item in
                            VStack(alignment:.leading,spacing:6) {
                                let shownID=item.identity.flatMap{store.values[$0.id]} ?? item.itemID
                                let itemName=ItemNameCatalog.bundled?.entry(gameID:store.gameID,itemID:shownID)
                                HStack {
                                    VStack(alignment:.leading,spacing:3) {
                                        Text(itemName?.name ?? "Unbekannter Gegenstand").font(.headline)
                                        Text(item.location).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(shownID.hasPrefix("Waffe") ? shownID:"ID \(shownID)").font(.caption.monospaced()).textSelection(.enabled)
                                }
                                if let unexamined=itemName?.unexamined,unexamined != itemName?.name {Text("Vor Untersuchung: \(unexamined)").font(.caption).foregroundStyle(.secondary)}
                                if let field=item.identity {fieldEditor(field)}
                                if let field=item.quantity {fieldEditor(field)}
                                else {Text("\(item.itemID.hasPrefix("Waffe") ? "Gespeicherter Waffenwert":"Gespeicherte Menge"): \(item.storedCount) · nur lesbar").font(.caption).foregroundStyle(.secondary)}
                            }.padding(10).background(.quaternary.opacity(0.35),in:RoundedRectangle(cornerRadius:8))
                            }
                        }
                    }
                    if !doc.re2ItemHistory.isEmpty {
                        Divider()
                        Text("RE2-Gegenstandsstatus").font(.title2.bold())
                        Text("Aus den gespeicherten Statuslisten gelesen. Diese Angaben sind nur lesbar und ändern weder Inventar noch Spielfortschritt.").font(.caption).foregroundStyle(.secondary)
                        ForEach(doc.re2ItemHistory) {list in
                            DisclosureGroup("\(list.title) · \(list.recorded.count) von \(list.total) Statusplätzen markiert") {
                                if list.recorded.isEmpty {Text("Noch kein Eintrag markiert.").foregroundStyle(.secondary)}
                                ForEach(list.recorded) {entry in
                                    HStack {Text(entry.name);Spacer();Text("ID \(entry.id)").font(.caption.monospaced()).foregroundStyle(.secondary)}.padding(.vertical,2)
                                }
                            }
                        }
                    }
                    if !doc.re2WeaponUse.isEmpty {
                        Divider()
                        Text("RE2-Waffenkennungen").font(.title2.bold())
                        Text("Aus der gespeicherten Liste „UseWeapons“. Namen stammen aus den installierten Spieltexten; die Wirkung der Liste ist noch nicht im Spiel verglichen. Nur lesbar.").font(.caption).foregroundStyle(.secondary)
                        ForEach(doc.re2WeaponUse) {weapon in
                            HStack {Text(weapon.name);Spacer();Text("ID \(weapon.weaponID)").font(.caption.monospaced()).foregroundStyle(.secondary)}.padding(.vertical,2)
                        }
                    }
                    if !doc.re2CostumeStates.isEmpty {
                        Divider()
                        Text("RE2-Kostümdaten").font(.title2.bold())
                        Text("Die Werte stammen direkt aus diesem Save. Eine Kostüm-ID ist noch keinem sichtbaren Outfit zugeordnet; diese Angaben sind deshalb nur lesbar.").font(.caption).foregroundStyle(.secondary)
                        ForEach(doc.re2CostumeStates) {state in
                            DisclosureGroup("\(state.title) · \(state.entries.count) Werte") {
                                Text("Unterschiedliche gespeicherte Werte: \(state.distinctValues.joined(separator:", "))").font(.caption).foregroundStyle(.secondary)
                                ForEach(state.entries) {entry in
                                    HStack(alignment:.firstTextBaseline) {
                                        Text("Eintrag \(entry.id + 1)").font(.caption)
                                        Spacer(minLength:10)
                                        Text(entry.value).font(.caption.monospaced()).textSelection(.enabled)
                                    }.help("Interner Save-Pfad: \(entry.path)").padding(.vertical,2)
                                }
                            }
                        }
                    }
                    if !doc.re2ProgressFlags.isEmpty {
                        Divider()
                        Text("RE2-Systemfortschritt").font(.title2.bold())
                        Text("Die internen IDs stammen aus Statuslisten der lokalen Systemdatei. Titel und Wirkung einzelner IDs sind noch nicht zugeordnet; die Anzeige ist nur lesbar.").font(.caption).foregroundStyle(.secondary)
                        ForEach(doc.re2ProgressFlags) {list in
                            DisclosureGroup("\(list.title) · \(list.marked.count) von \(list.total)") {
                                if list.marked.isEmpty {Text("Kein Eintrag markiert.").foregroundStyle(.secondary)}
                                ForEach(list.marked,id:\.self) {index in
                                    Text("Interne ID \(index)").font(.caption.monospaced()).padding(.vertical,2)
                                }
                            }
                        }
                        if !doc.re2ClearRecords.isEmpty {
                            DisclosureGroup("Abschlussdetails · \(doc.re2ClearRecords.count) gesetzte ID") {
                                Text("Zu jeder gesetzten Spielabschluss-ID stehen ein Zeitwert, Rangcode und Speicherzähler. Die Einheit des Zeitwerts sowie die Bedeutung von ID und Rangcode sind noch nicht belegt.").font(.caption).foregroundStyle(.secondary)
                                ForEach(doc.re2ClearRecords) {record in
                                    VStack(alignment:.leading,spacing:3) {
                                        Text("Interne Abschluss-ID \(record.id)").font(.subheadline.bold())
                                        Text("Zeitwert \(record.clearTimeRaw) · Rangcode \(record.rankCode) · Speicherzähler \(record.saveCount)").font(.caption.monospacedDigit())
                                    }.padding(.vertical,3)
                                }
                            }
                        }
                    }
                    if !doc.fileFlags.isEmpty {
                        Divider()
                        Text("Gefundene Dokumente").font(.title2.bold())
                        let found=doc.fileFlags.filter{(store.values[$0.field.id] ?? $0.field.initial)=="1"}.count
                        Text("\(found) von \(doc.fileFlags.count) benannten Dokumenten gefunden · \(store.game.name)-Systemdaten").font(.subheadline)
                        Text("\(89-doc.fileFlags.count) weitere interne Dokument-IDs haben im installierten Spiel keinen verwendbaren Titel und bleiben gesperrt. Änderungen werden erst beim Speichern in die lokale Systemdatei geschrieben.").font(.caption).foregroundStyle(.secondary)
                        TextField("Dokument suchen",text:$store.fileSearch).textFieldStyle(.roundedBorder)
                        ForEach(doc.fileFlags.filter{store.fileSearch.isEmpty || $0.title.localizedCaseInsensitiveContains(store.fileSearch) || String($0.number).contains(store.fileSearch)}) {flag in
                            Toggle(isOn:Binding(get:{(store.values[flag.field.id] ?? flag.field.initial)=="1"},set:{store.values[flag.field.id]=$0 ? "1":"0"})) {
                                HStack {Text(String(format:"%02d",flag.number)).font(.caption.monospaced()).foregroundStyle(.secondary).frame(width:25,alignment:.leading);Text(flag.title)}
                            }.toggleStyle(.switch).padding(.vertical,3)
                        }
                    }
                    if !doc.raccoonFlags.isEmpty {
                        Divider()
                        Text("Mr. Raccoon-Figuren").font(.title2.bold())
                        let destroyed=doc.raccoonFlags.filter{(store.values[$0.field.id] ?? $0.field.initial)=="1"}.count
                        Text("\(destroyed) von 15 Figuren abgeschossen · spielstandübergreifende RE2-Systemdaten").font(.subheadline)
                        Text("Jeder Schalter ändert genau eine Figuren-ID. Die Änderung wird erst mit „Lokalen Spielstand speichern“ in die lokale Systemdatei geschrieben. Beende RE2 vorher vollständig.").font(.caption).foregroundStyle(.secondary)
                        ForEach(doc.raccoonFlags) {flag in
                            Toggle(isOn:Binding(get:{(store.values[flag.field.id] ?? flag.field.initial)=="1"},set:{store.values[flag.field.id]=$0 ? "1":"0"})) {
                                Text("Mr. Raccoon \(String(format:"%02d",flag.number)) · ID \(flag.number-1)")
                            }.toggleStyle(.switch).padding(.vertical,3)
                        }
                    }
                    if let ids=doc.re7EasterEggIDs {
                        Divider()
                        Text("Mr. Everywhere-Figuren").font(.title2.bold())
                        let known=Set(RE7EasterEggCatalog.figures.map(\.id))
                        let editable=Set(ids).isSubset(of:known)
                        let found=RE7EasterEggCatalog.figures.filter{store.figurePresence[$0.id] == true}.count
                        Text("\(found) von 20 Figuren als zerstört markiert · RE7-Systemdaten").font(.subheadline)
                        Text("Die Reihenfolge folgt den Spielgebieten und ist keine offizielle Figurennummer. Jeder Schalter ändert eine eigene GUID; gespeichert wird erst mit „Lokalen Spielstand speichern“ bei beendetem RE7. Die Zuordnung stammt aus den installierten Spielszenen; eine Ladeprüfung einer bearbeiteten Datei im Spiel steht noch aus.").font(.caption).foregroundStyle(.secondary)
                        if editable {
                            ForEach(RE7EasterEggCatalog.figures) {figure in
                                Toggle(isOn:Binding(get:{store.figurePresence[figure.id] ?? ids.contains(figure.id)},set:{store.figurePresence[figure.id]=$0})) {
                                    Text("Mr. Everywhere \(String(format:"%02d",figure.number)) · \(figure.location)")
                                }.toggleStyle(.switch).padding(.vertical,3)
                            }
                        } else {
                            Text("Unbekannte gespeicherte Kennung: Bearbeitung gesperrt.").foregroundStyle(.orange)
                            ForEach(ids,id:\.self) {id in Text(id).font(.caption.monospaced()).textSelection(.enabled)}
                        }
                    }
                    if !doc.castellanFlags.isEmpty {
                        Divider()
                        Text("Aufzieh-Kastellane").font(.title2.bold())
                        let destroyed=doc.castellanFlags.filter{(store.values[$0.field.id] ?? $0.field.initial)=="1"}.count
                        Text("\(destroyed) von 16 Figuren zerstört · spielstandübergreifende RE4-Systemdaten").font(.subheadline)
                        Text("Jeder Schalter ändert den Status genau eines Kapitels. Die Änderung wird erst mit „Lokalen Spielstand speichern“ in die lokale Systemdatei geschrieben. Beende RE4 vorher vollständig.").font(.caption).foregroundStyle(.secondary)
                        ForEach(doc.castellanFlags) {flag in
                            Toggle(isOn:Binding(get:{(store.values[flag.field.id] ?? flag.field.initial)=="1"},set:{store.values[flag.field.id]=$0 ? "1":"0"})) {
                                Text("Aufzieh-Kastellan \(String(format:"%02d",flag.number)) · Kapitel-ID \(String(flag.chapter))")
                            }.toggleStyle(.switch).padding(.vertical,3)
                        }
                    }
                    if !doc.charlieFlags.isEmpty {
                        Divider()
                        Text("Charlie-Figuren").font(.title2.bold())
                        let destroyed=doc.charlieFlags.filter{(store.values[$0.field.id] ?? $0.field.initial)=="1"}.count
                        Text("\(destroyed) von 20 Figuren zerstört · spielstandübergreifende RE3-Systemdaten").font(.subheadline)
                        Text("Jeder Schalter ändert genau eine Charlie-ID. Die Änderung wird erst mit „Lokalen Spielstand speichern“ in die lokale Systemdatei geschrieben. Beende RE3 vorher vollständig.").font(.caption).foregroundStyle(.secondary)
                        ForEach(doc.charlieFlags) {flag in
                            Toggle(isOn:Binding(get:{(store.values[flag.field.id] ?? flag.field.initial)=="1"},set:{store.values[flag.field.id]=$0 ? "1":"0"})) {
                                Text("Charlie \(String(format:"%02d",flag.number)) · ID \(flag.number-1)")
                            }.toggleStyle(.switch).padding(.vertical,3)
                        }
                    }
                    if !doc.dialLockFlags.isEmpty {
                        Divider()
                        Text("RE3-Schlossstatus").font(.title2.bold())
                        let recorded=doc.dialLockFlags.filter{(store.values[$0.field.id] ?? $0.field.initial)=="1"}.count
                        Text("\(recorded) von 20 Schloss-Flags gesetzt · spielstandübergreifende RE3-Systemdaten").font(.subheadline)
                        Text("Die einzelnen Schlösser lassen sich noch nicht mit Ortsnamen verbinden. Die internen IDs 0–19 können einzeln ein- und ausgeschaltet werden; gespeichert wird erst nach „Lokalen Spielstand speichern“.").font(.caption).foregroundStyle(.secondary)
                        ForEach(doc.dialLockFlags) {flag in
                            Toggle(isOn:Binding(get:{(store.values[flag.field.id] ?? flag.field.initial)=="1"},set:{store.values[flag.field.id]=$0 ? "1":"0"})) {
                                Text("Schloss \(String(format:"%02d",flag.number)) · ID \(flag.number-1)")
                            }.toggleStyle(.switch).padding(.vertical,3)
                        }
                    }
                    if !doc.storedDocuments.isEmpty {
                        Divider()
                        Text("Dokumente im lokalen Save").font(.title2.bold())
                        let recorded=doc.storedDocuments.filter{store.documentPresence[$0.id] ?? $0.isRecorded}.count
                        Text("\(recorded) gespeicherte Einträge · \(doc.storedDocuments.count) angezeigte Dokumente").font(.subheadline)
                        Text(store.gameID=="re4" ? "RE4 speichert hier die Leseliste. Die Schalter ändern „gelesen“, nicht den Fund im aktuellen Spielstand." : store.gameID=="re7" ? "RE7 speichert gefundene Dokumente als variable Liste im gewählten Spielstand. Die Schalter werden erst beim Speichern übernommen." : "Village speichert gefundene Dokument-IDs im gewählten Spielstand. Eindeutig mit deutschen Spieltexten verbundene IDs können bearbeitet werden.").font(.caption).foregroundStyle(.secondary)
                        TextField("Dokument suchen",text:$store.fileSearch).textFieldStyle(.roundedBorder)
                        ForEach(doc.storedDocuments.filter{store.fileSearch.isEmpty || $0.title.localizedCaseInsensitiveContains(store.fileSearch) || $0.id.localizedCaseInsensitiveContains(store.fileSearch)}) {row in
                            let shown=store.documentPresence[row.id] ?? row.isRecorded
                            let label=HStack(alignment:.firstTextBaseline,spacing:10) {
                                Image(systemName:shown ? "checkmark.circle.fill":"circle").foregroundStyle(shown ? Color.green:Color.secondary)
                                VStack(alignment:.leading,spacing:2) {
                                    Text(row.title)
                                    Text("ID \(row.id) · \(shown==row.isRecorded ? row.status : (shown ? "Eintrag vorgemerkt":"Entfernung vorgemerkt"))").font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                            if row.canEdit {
                                Toggle(isOn:Binding(get:{store.documentPresence[row.id] ?? row.isRecorded},set:{store.documentPresence[row.id]=$0})) {label}.toggleStyle(.switch).accessibilityLabel("\(row.title), ID \(row.id)").padding(.vertical,3)
                            } else {label.padding(.vertical,3)}
                        }
                    }
                    ForEach(doc.editable.filter{!inventoryIDs.contains($0.id) && !fileFlagIDs.contains($0.id) && !raccoonFlagIDs.contains($0.id) && !castellanFlagIDs.contains($0.id) && !charlieFlagIDs.contains($0.id) && !dialLockFlagIDs.contains($0.id)}) {field in fieldEditor(field)}
                    if !doc.timeFields.isEmpty {Button("Spielzeit auf 0 vormerken",systemImage:"clock.arrow.circlepath",action:store.prepareZeroTime)}
                    if doc.editable.isEmpty && doc.re7EasterEggIDs == nil {Text("Diese Datei ist vollständig lesbar, enthält aber keine eindeutig zugeordneten bearbeitbaren Werte. Wähle einen anderen Spielstand.").foregroundStyle(.secondary)}
                    if !store.pending.isEmpty || !store.pendingDocuments.isEmpty || !store.pendingFigures.isEmpty {
                        GroupBox("Vorgemerkte Änderungen") {
                            VStack(alignment:.leading,spacing:6) {
                                ForEach(store.pending, id:\.0.id) {field,value in Text("\(field.title): \(field.initial) → \(field.display(value))").frame(maxWidth:.infinity,alignment:.leading)}
                                ForEach(store.pendingDocuments) {row in Text("\(row.title): \(row.isRecorded ? "ein":"aus") → \((store.documentPresence[row.id] ?? row.isRecorded) ? "ein":"aus")").frame(maxWidth:.infinity,alignment:.leading)}
                                ForEach(store.pendingFigures) {figure in Text("Mr. Everywhere \(String(format:"%02d",figure.number)): \((doc.re7EasterEggIDs ?? []).contains(figure.id) ? "zerstört":"nicht zerstört") → \((store.figurePresence[figure.id] ?? false) ? "zerstört":"nicht zerstört")").frame(maxWidth:.infinity,alignment:.leading)}
                            }.padding(4)
                        }
                    }
                    if let problem=store.validationError {Label(problem,systemImage:"exclamationmark.triangle").foregroundStyle(.orange)}
                    HStack {Button("Änderungen verwerfen",action:store.reset);Spacer();Button("Lokalen Spielstand speichern",systemImage:"internaldrive",action:store.save).buttonStyle(.borderedProminent).disabled((store.pending.isEmpty && store.pendingDocuments.isEmpty && store.pendingFigures.isEmpty) || store.validationError != nil || store.busy)}
                    Text("Speichert direkt in der oben angegebenen lokalen Datei mit unverändertem Dateinamen und unveränderter Konto-Zuordnung. Beende das Spiel vor dem Speichern vollständig. Eine Ladeprüfung im Spiel steht noch aus.").font(.caption).foregroundStyle(.secondary)
                } else {
                    if let selected=store.files.first(where:{$0.id==store.selectedFile}) {
                        VStack(alignment:.leading,spacing:6) {
                            Text(selected.title).font(.headline)
                            Text(selected.url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            Text("\(selected.kind) · \(ByteCountFormatter.string(fromByteCount:Int64(selected.size),countStyle:.file))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let error=store.error {Label(error,systemImage:"info.circle").foregroundStyle(.secondary).textSelection(.enabled)}
                    GroupBox("Bearbeitung") {
                        VStack(alignment:.leading,spacing:10) {
                            Text("Wähle links einen lokalen Spielstand oder die Systemdaten aus. Es erscheinen nur Werte, die in dieser Datei eindeutig vorhanden und ihrem Spielprofil zugeordnet sind.")
                            Text("Keine Werte werden geraten und keine verschlüsselten Dateien blind verändert.").font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth:.infinity,alignment:.leading).padding(5)
                    }
                    if let scan=store.scans[store.gameID],!scan.denied.isEmpty {
                        GroupBox("macOS benötigt deine Ordnerfreigabe") {VStack(alignment:.leading,spacing:10) {Text("Der Spielcontainer wurde erkannt, sein Inhalt ist für diese App noch nicht lesbar. Bitte den SaveData-Ordner über die Ordnerauswahl freigeben.");Button("Ordner auswählen …",action:store.chooseFolder)}.padding(5)}
                    }
                    Text("Suchort").font(.headline)
                    Text(store.game.container.path).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if store.document != nil,let error=store.error {Label(error,systemImage:"exclamationmark.triangle").foregroundStyle(.orange).textSelection(.enabled)}
            }.padding(26).frame(maxWidth:760,alignment:.leading)
        }.frame(minWidth:430)
    }
    private func fieldEditor(_ field:EditableField) -> some View {
        VStack(alignment:.leading,spacing:6) {
            HStack {Text(field.title).font(.headline);Spacer();TextField("Wert",text:Binding(get:{store.values[field.id] ?? field.initial},set:{store.values[field.id]=$0})).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width:150).accessibilityLabel(field.title)}
            Text(field.description).font(.caption).foregroundStyle(.secondary)
            Text("Original: \(field.initial)").font(.caption.monospaced()).foregroundStyle(.secondary)
        }
    }
}
