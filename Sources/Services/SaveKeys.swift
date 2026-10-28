import Foundation

enum SaveKeys {
    static func key(for game:GameProfile) throws -> Data {
        if game.id=="re4" {return SaveCrypto.re4Key}
        let url:URL?
        #if SAVE_EDITOR_TESTS
        url=ProcessInfo.processInfo.environment["RESAVE_TEST_KEY_FILE"].map{URL(fileURLWithPath:$0)}
        #else
        url=Bundle.main.url(forResource:"VerifiedSaveKeys",withExtension:"json")
        #endif
        guard let url,let size=try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize,size<=65536,
              let data=try? Data(contentsOf:url),
              let catalog=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              catalog["version"] as? Int==1,
              let games=catalog["games"] as? [String:[String:Any]],let entry=games[game.id],
              entry["verifiedLocalHeader"] as? Bool==true,
              entry["uuid"] as? String==game.nativeUUID,
              let encoded=entry["key"] as? String,let key=Data(base64Encoded:encoded),(4...56).contains(key.count) else {
            throw SaveError.invalid("Der bestätigte lokale Save-Schlüssel für \(game.name) fehlt in diesem Build.")
        }
        return key
    }
}
