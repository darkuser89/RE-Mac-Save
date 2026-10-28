import Foundation

struct ItemNameCatalog: Decodable {
    struct Entry: Decodable {
        let name: String
        let code: String
        let unexamined: String?
    }
    struct Game: Decodable {
        let items: [String: Entry]
        let weapons: [String: Entry]
    }
    let games: [String: Game]

    static let bundled: ItemNameCatalog? = {
        guard let url = Bundle.main.url(forResource: "ItemNames", withExtension: "json") else { return nil }
        return try? load(from: url)
    }()

    static func load(from url: URL) throws -> ItemNameCatalog {
        try JSONDecoder().decode(ItemNameCatalog.self, from: Data(contentsOf: url))
    }

    func entry(gameID: String, itemID: String) -> Entry? {
        guard let game = games[gameID] else { return nil }
        if itemID.hasPrefix("Waffe ") {
            return game.weapons[String(itemID.dropFirst("Waffe ".count))]
        }
        return game.items[itemID]
    }
}
