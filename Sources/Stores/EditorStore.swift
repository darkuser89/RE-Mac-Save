import Foundation
import AppKit
import Combine
@MainActor final class EditorStore:ObservableObject {
    @Published var gameID="re4"
    @Published var selectedFile:String?
    @Published var scans:[String:ScanResult]=[:]
    @Published var document:SaveDocument?
    @Published var values:[Int:String]=[:]
    @Published var documentPresence:[String:Bool]=[:]
    @Published var figurePresence:[String:Bool]=[:]
    @Published var fileSearch=""
    @Published var message="Spielstände werden gesucht …"
    @Published private var scanning=false
    @Published private var loading=false
    @Published private(set) var isSaving=false
    @Published private(set) var isInspecting=false
    @Published var error:String?
    var busy:Bool {scanning || loading || isSaving || isInspecting}
    var game:GameProfile {GameProfile.all.first{$0.id==gameID}!}
    var files:[SaveFile] {scans[gameID]?.files ?? []}
    private var scopes:[String:URL]=[:]
    private var loadID=UUID()
    private var scanID=UUID()
    func refresh() {
        scanning=true;let request=UUID();scanID=request
        for game in GameProfile.all {
            if scopes[game.id]==nil,let bookmark=UserDefaults.standard.data(forKey:"Folder.\(game.id)") {
                var stale=false
                if let url=try? URL(resolvingBookmarkData:bookmark,options:[.withSecurityScope],relativeTo:nil,bookmarkDataIsStale:&stale),LocalSavePolicy.permitsFolder(url,game:game),url.startAccessingSecurityScopedResource(){scopes[game.id]=url}
            }
        }
        let extra=scopes
        Task {
            let results=await Task.detached(priority:.userInitiated){() -> [String:ScanResult] in
                var found=Dictionary(uniqueKeysWithValues:GameProfile.all.map{($0.id,SaveDiscovery.scan(game:$0,extra:extra[$0.id]))})
                if let re2=GameProfile.all.first(where:{$0.id=="re2"}),var scan=found["re2"] {
                    for index in scan.files.indices {scan.files[index].character=RE2Character.read(file:scan.files[index],game:re2)}
                    found["re2"]=scan
                }
                return found
            }.value
            guard scanID==request else {return}
            scans=results;scanning=false
            let count=results.values.reduce(0){$0+$1.files.count};message="\(count) lokale Save-Dateien gefunden."
        }
    }
    func switchGame() {loadID=UUID();loading=false;selectedFile=nil;document=nil;values=[:];documentPresence=[:];figurePresence=[:];fileSearch="";error=nil}
    func load() {
        let request=UUID();loadID=request
        guard let file=files.first(where:{$0.id==selectedFile}) else {document=nil;values=[:];documentPresence=[:];figurePresence=[:];loading=false;return}
        document=nil;values=[:];documentPresence=[:];figurePresence=[:];fileSearch="";error=nil;loading=true;let game=game
        Task {
            let result=await Task.detached(priority:.userInitiated){Result{try SaveDocument(file:file,game:game)}}.value
            guard loadID==request,gameID==game.id,selectedFile==file.id else {return}
            loading=false
            switch result {case .success(let doc):document=doc;values=Dictionary(uniqueKeysWithValues:doc.editable.map{($0.id,$0.initial)});documentPresence=Dictionary(uniqueKeysWithValues:doc.storedDocuments.filter(\.canEdit).map{($0.id,$0.isRecorded)});figurePresence=doc.re7EasterEggIDs.map { ids in Dictionary(uniqueKeysWithValues:RE7EasterEggCatalog.figures.map{($0.id,ids.contains($0.id))}) } ?? [:];message="Lokale Datei geprüft. Änderungen werden erst mit „Speichern“ übernommen."
            case .failure(let e):error=e.localizedDescription;message="Datei bleibt unverändert."}
        }
    }
    func chooseFolder() {
        let id=gameID
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.allowsMultipleSelection=false
        let profile=game
        panel.message="Wähle den lokalen SaveData-Ordner von \(game.name) innerhalb seines Spielcontainers."
        panel.prompt="Ordner freigeben";panel.directoryURL=game.container
        panel.begin { [weak self] response in
            guard response == .OK,let url=panel.url,let self else {return}
            guard LocalSavePolicy.permitsFolder(url,game:profile) else {self.error="Bitte einen lokalen Ordner innerhalb von \(profile.container.path) wählen.";return}
            self.scopes[id]?.stopAccessingSecurityScopedResource()
            _=url.startAccessingSecurityScopedResource();self.scopes[id]=url
            if let bookmark=try? url.bookmarkData(options:[.withSecurityScope],includingResourceValuesForKeys:nil,relativeTo:nil){UserDefaults.standard.set(bookmark,forKey:"Folder.\(id)")}
            self.switchGame();self.refresh()
        }
    }
    func revealFolder() {
        if let file=files.first {NSWorkspace.shared.activateFileViewerSelecting([file.url])}
        else {NSWorkspace.shared.open(game.container)}
    }
    var pending:[(EditableField,UInt64)] {(try? document?.changes(values)) ?? []}
    var pendingDocuments:[StoredDocument] {(try? document?.documentChanges(documentPresence)) ?? []}
    var pendingFigures:[RE7EasterEggCatalog.Figure] {(try? document?.figureChanges(figurePresence)) ?? []}
    var validationError:String? {
        guard let document else {return nil}
        do {_=try document.changes(values);_=try document.documentChanges(documentPresence);_=try document.figureChanges(figurePresence);return nil} catch {return error.localizedDescription}
    }
    func prepareZeroTime() {if let document {for field in document.timeFields {values[field.id]="0"}}}
    func reset() {if let doc=document {values=Dictionary(uniqueKeysWithValues:doc.editable.map{($0.id,$0.initial)});documentPresence=Dictionary(uniqueKeysWithValues:doc.storedDocuments.filter(\.canEdit).map{($0.id,$0.isRecorded)});figurePresence=doc.re7EasterEggIDs.map { ids in Dictionary(uniqueKeysWithValues:RE7EasterEggCatalog.figures.map{($0.id,ids.contains($0.id))}) } ?? [:]}}
    func save() {
        guard let doc=document,!busy else {return}
        let snapshot=values,documentSnapshot=documentPresence,figureSnapshot=figurePresence
        do {_=try doc.changes(values);_=try doc.documentChanges(documentPresence);_=try doc.figureChanges(figurePresence)} catch {self.error=error.localizedDescription;return}
        isSaving=true;error=nil
        Task {
            let result=await Task.detached(priority:.userInitiated){Result{try LocalSaveWriter.save(document:doc,values:snapshot,documents:documentSnapshot,figures:figureSnapshot)}}.value
            isSaving=false
            switch result {
            case .success(let saved):
                document=saved;values=Dictionary(uniqueKeysWithValues:saved.editable.map{($0.id,$0.initial)});documentPresence=Dictionary(uniqueKeysWithValues:saved.storedDocuments.filter(\.canEdit).map{($0.id,$0.isRecorded)});figurePresence=saved.re7EasterEggIDs.map { ids in Dictionary(uniqueKeysWithValues:RE7EasterEggCatalog.figures.map{($0.id,ids.contains($0.id))}) } ?? [:]
                if let index=scans[gameID]?.files.firstIndex(where:{$0.id==saved.source.id}) {scans[gameID]?.files[index]=saved.source}
                message="Lokal gespeichert: \(saved.source.url.lastPathComponent). Du kannst das Spiel jetzt starten."
            case .failure(let failure):error=failure.localizedDescription;message="Speichern nicht abgeschlossen."
            }
        }
    }
    func exportInventory() {
        let snapshot=scans
        let panel=NSSavePanel();panel.title="Fundliste exportieren";panel.nameFieldStringValue="Resident-Evil-Spielstaende.json"
        panel.message="Die Liste enthält die gefundenen Dateipfade, Größen und Änderungszeiten. Spielstände werden nicht kopiert."
        panel.begin { [weak self] response in
            guard response == .OK,let url=panel.url,let self else {return}
            do {
                let games:[[String:Any]]=GameProfile.all.map {game in
                    let scan=snapshot[game.id] ?? ScanResult()
                    return ["game":game.name,"files":scan.files.map{["path":$0.url.path,"bytes":$0.size,"format":$0.kind,"modified":ISO8601DateFormatter().string(from:$0.modified)] as [String:Any]},"searchedFolders":scan.searched.map(\.path),"unreadableFolders":scan.denied.map(\.path)]
                }
                let report:[String:Any]=["created":ISO8601DateFormatter().string(from:Date()),"games":games]
                let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
                // Reports must never be placed inside any discovered save directory.
                let target=url.resolvingSymlinksInPath().standardizedFileURL
                let folders=snapshot.values.flatMap(\.files).map{$0.url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path+"/"}
                guard !folders.contains(where:{target.path.hasPrefix($0)}) else {throw SaveError.invalid("Bitte die Fundliste außerhalb der Saveordner speichern.")}
                try data.write(to:target,options:.withoutOverwriting)
                self.message="Fundliste exportiert: \(url.lastPathComponent)"
            } catch {self.error=error.localizedDescription}
        }
    }
    func inspectFormats() {inspectFormats(selectedOnly:false)}
    func inspectSelectedFormat() {inspectFormats(selectedOnly:true)}
    func inspectAllFormats() {inspectFormats(selectedOnly:false,allGames:true)}
    private func inspectFormats(selectedOnly:Bool,allGames:Bool=false) {
        let snapshot=scans
        let selected=gameID
        let selectedSave=selectedFile
        let panel=NSSavePanel();panel.title=allGames ? "Alle fünf Spiele prüfen" : selectedOnly ? "Ausgewählten Save prüfen":"Lokale Save-Formate prüfen";panel.nameFieldStringValue=allGames ? "Lokale-Save-Pruefung-alle.json":"Lokale-Save-Pruefung-\(selected).json"
        panel.message=allGames ? "Prüft alle gefundenen lokalen Saves der fünf Spiele. Schreibtests erfolgen nur in kurzlebigen Testdateien; Original-Saves bleiben unverändert." : selectedOnly ? "Prüft den ausgewählten lokalen Save. Schreibtests erfolgen nur in kurzlebigen Testdateien; das Original bleibt unverändert.":"Prüft die lokalen Saves des ausgewählten Spiels. Schreibtests erfolgen nur in kurzlebigen Testdateien; Original-Saves bleiben unverändert."
        panel.begin { [weak self] response in
            guard response == .OK,let target=panel.url,let self else {return}
            let folders=snapshot.values.flatMap(\.files).map{$0.url.deletingLastPathComponent().resolvingSymlinksInPath().path+"/"}
            guard !folders.contains(where:{target.resolvingSymlinksInPath().path.hasPrefix($0)}) else {self.error="Prüfbericht bitte außerhalb der Saveordner speichern.";return}
            self.isInspecting=true;self.error=nil;self.message="Lokale Save-Dateien werden geprüft …"
            Task {
                var inputScans=allGames ? snapshot : [selected:snapshot[selected] ?? ScanResult()]
                if selectedOnly,var one=inputScans[selected] {one.files=one.files.filter{$0.id==selectedSave};inputScans[selected]=one}
                let result=await Task.detached(priority:.userInitiated){SaveFormatInspector.inspect(inputScans)}.value
                self.isInspecting=false
                do {
                    let data=try JSONSerialization.data(withJSONObject:["files":result],options:[.prettyPrinted,.sortedKeys])
                    try data.write(to:target,options:.withoutOverwriting)
                    let okay=result.filter{$0["roundTrip"] as? Bool==true}.count
                    let edits=result.reduce(0){$0+($1["editTests"] as? Int ?? 0)}
                    self.message="\(okay) von \(result.count) lokalen Dateien und \(edits) Feldänderungen geprüft. Originale unverändert."
                } catch {self.error=error.localizedDescription}
            }
        }
    }
}
