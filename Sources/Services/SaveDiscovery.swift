import Foundation
struct SaveDiscovery {
    static func scan(game:GameProfile,extra:URL?=nil) -> ScanResult {
        var result=ScanResult(),seen=Set<String>()
        let roots=extra.map{[$0]} ?? [game.container.appendingPathComponent("Library/Application Support"),game.container.appendingPathComponent("Documents")]
        for root in roots {
            guard LocalSavePolicy.permitsFolder(root,game:game) else {result.denied.append(root);continue}
            result.searched.append(root)
            do {try walk(root,depth:0,seen:&seen,files:&result.files)}
            catch let e as NSError {if e.code != NSFileReadNoSuchFileError && e.code != NSFileNoSuchFileError {result.denied.append(root)}}
        }
        result.files.removeAll{!LocalSavePolicy.permitsFile($0.url,game:game)}
        result.files.sort{$0.url.path<$1.url.path};return result
    }
    private static func walk(_ root:URL,depth:Int,seen:inout Set<String>,files:inout [SaveFile]) throws {
        guard depth<=10,seen.count<10000 else {return}
        let fm=FileManager.default
        let values=try root.resourceValues(forKeys:[.isSymbolicLinkKey,.isDirectoryKey])
        guard values.isSymbolicLink != true else {return}
        if values.isDirectory != true {try addFile(root,files:&files);return}
        let entries=try fm.contentsOfDirectory(at:root,includingPropertiesForKeys:[.isDirectoryKey,.isSymbolicLinkKey],options:[.skipsHiddenFiles])
        for url in entries {
            guard seen.insert(url.standardizedFileURL.path).inserted else {continue}
            let v=try url.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey]);if v.isSymbolicLink==true {continue}
            if v.isDirectory==true {if !["Caches","Logs","WebKit"].contains(url.lastPathComponent) {try walk(url,depth:depth+1,seen:&seen,files:&files)}}
            else {try addFile(url,files:&files)}
        }
    }
    private static func addFile(_ url:URL,files:inout [SaveFile]) throws {
        let name=url.lastPathComponent.lowercased()
        guard name.range(of:"^data[0-9-]+(slot)?\\.bin$",options:.regularExpression) != nil else {return}
        let attr=try url.resourceValues(forKeys:[.fileSizeKey,.contentModificationDateKey]);let size=attr.fileSize ?? 0
        guard size>=16,size<=128*1024*1024 else {return}
        let handle=try FileHandle(forReadingFrom:url);defer{try? handle.close()};let header=try handle.read(upToCount:16) ?? Data()
        let magic=String(data:header.prefix(4),encoding:.ascii) ?? "Unbekannt"
        guard magic=="DSSS" else {return}
        files.append(SaveFile(url:url,size:size,modified:attr.contentModificationDate ?? .distantPast,kind:magic))
    }
}
