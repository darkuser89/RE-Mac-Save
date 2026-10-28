import Foundation

enum LocalSavePolicy {
    private static func isCloud(_ url:URL) -> Bool {
        let components=url.pathComponents.map{$0.lowercased()}
        if components.contains(where:{$0=="mobile documents" || $0=="cloudstorage" || $0.hasPrefix("icloud~")}) {return true}
        return (try? url.resourceValues(forKeys:[.isUbiquitousItemKey]).isUbiquitousItem)==true
    }
    static func permitsFolder(_ url:URL,game:GameProfile) -> Bool {
        guard !isCloud(url),!isCloud(url.resolvingSymlinksInPath()) else {return false}
        let root=game.container.standardizedFileURL.resolvingSymlinksInPath().path
        let path=url.standardizedFileURL.resolvingSymlinksInPath().path
        return path==root || path.hasPrefix(root+"/")
    }
    static func permitsFile(_ url:URL,game:GameProfile) -> Bool {
        let original=url.standardizedFileURL
        let resolved=original.resolvingSymlinksInPath()
        guard original.path==resolved.path,permitsFolder(resolved,game:game),
              resolved.deletingLastPathComponent().lastPathComponent=="SaveData" else {return false}
        return resolved.lastPathComponent.lowercased().range(of:"^data[0-9-]+(slot)?\\.bin$",options:.regularExpression) != nil
    }
}
