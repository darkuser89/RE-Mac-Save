import Foundation
@main struct BuildSchemaHints {
    static func main() throws {
        guard CommandLine.arguments.count==3 else {throw SaveError.invalid("Expected input and output paths.")}
        let input=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
        let names=try JSONSerialization.jsonObject(with:input) as! [String:[String:[String]]]
        var result:[String:[String:[String:String]]]=[:]
        for (game,tables) in names {
            var mapped:[String:[String:String]]=[:]
            for (kind,values) in tables {
                var hashes:[String:String]=[:]
                for value in values where !value.isEmpty {
                    let hash=String(SaveCrypto.murmur(Data(value.utf8)))
                    hashes[hash]=hashes[hash].map{$0==value ? value:"<hash collision>"} ?? value
                }
                mapped[kind]=hashes
            }
            result[game]=mapped
        }
        let output=try JSONSerialization.data(withJSONObject:result,options:.sortedKeys)
        try output.write(to:URL(fileURLWithPath:CommandLine.arguments[2]),options:.withoutOverwriting)
        print("Static schema name hashes prepared; no save data read.")
    }
}
