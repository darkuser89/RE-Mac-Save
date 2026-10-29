import Foundation
import CryptoKit
import SQLite3

struct SaveSearchSummary {
    let files:Int
    let fields:Int
    let errors:Int
    let location:URL
}

enum SaveSearchIndex {
    static let location=URL(fileURLWithPath:"/private/tmp/ResidentEvil-Save-Suche.sqlite")
    private static let transient=unsafeBitCast(-1,to:sqlite3_destructor_type.self)

    static func build(_ scans:[String:ScanResult],at target:URL=location) throws -> SaveSearchSummary {
        guard target.path.hasPrefix("/private/tmp/") else {
            throw SaveError.invalid("Der Suchindex darf nur unter /private/tmp liegen.")
        }
        let temporary=target.deletingLastPathComponent().appendingPathComponent(".\(target.lastPathComponent).\(UUID().uuidString).tmp")
        defer {try? FileManager.default.removeItem(at:temporary)}
        var db:OpaquePointer?
        guard sqlite3_open_v2(temporary.path,&db,SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,nil)==SQLITE_OK,
              let db else {throw SaveError.invalid("Suchindex konnte nicht erstellt werden.")}
        defer {sqlite3_close(db)}
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:temporary.path)
        try execute(db,"PRAGMA journal_mode=MEMORY; PRAGMA synchronous=OFF; PRAGMA temp_store=MEMORY;")
        try execute(db,"""
          CREATE TABLE meta(key TEXT PRIMARY KEY,value TEXT NOT NULL);
          CREATE TABLE saves(id INTEGER PRIMARY KEY,game TEXT NOT NULL,name TEXT NOT NULL,path TEXT NOT NULL,
              character TEXT,modified TEXT NOT NULL,sha256 TEXT NOT NULL,objects INTEGER NOT NULL,fields INTEGER NOT NULL);
          CREATE TABLE scalars(save_id INTEGER NOT NULL,ordinal INTEGER NOT NULL,owner TEXT NOT NULL,
              field TEXT NOT NULL,type INTEGER NOT NULL,size INTEGER NOT NULL,path TEXT NOT NULL,
              occurrence INTEGER NOT NULL,value TEXT,PRIMARY KEY(save_id,ordinal));
          CREATE TABLE names(game TEXT NOT NULL,kind TEXT NOT NULL,hash TEXT NOT NULL,candidates TEXT NOT NULL,
              PRIMARY KEY(game,kind,hash));
          CREATE TABLE failures(game TEXT NOT NULL,name TEXT NOT NULL,message TEXT NOT NULL);
        """)
        try execute(db,"INSERT INTO meta VALUES('schema','1'); INSERT INTO meta VALUES('created_utc',strftime('%Y-%m-%dT%H:%M:%SZ','now'));")
        try execute(db,"BEGIN IMMEDIATE")
        do {
            try insertNames(db)
            let saveStatement=try prepare(db,"INSERT INTO saves(game,name,path,character,modified,sha256,objects,fields) VALUES(?,?,?,?,?,?,?,?)")
            let fieldStatement=try prepare(db,"INSERT INTO scalars(save_id,ordinal,owner,field,type,size,path,occurrence,value) VALUES(?,?,?,?,?,?,?,?,?)")
            let failureStatement=try prepare(db,"INSERT INTO failures(game,name,message) VALUES(?,?,?)")
            defer {sqlite3_finalize(saveStatement);sqlite3_finalize(fieldStatement);sqlite3_finalize(failureStatement)}
            var fileCount=0,fieldCount=0,errorCount=0
            let formatter=ISO8601DateFormatter()
            for game in GameProfile.all {
                for file in scans[game.id]?.files ?? [] {
                    do {
                        guard LocalSavePolicy.permitsFile(file.url,game:game),file.kind=="DSSS" else {
                            throw SaveError.invalid("Kein erlaubter lokaler DSSS-Save.")
                        }
                        let data=try Data(contentsOf:file.url)
                        let container=try SaveContainer(data:data,key:SaveKeys.key(for:game))
                        let parsed=try ParsedSave(payload:container.payload)
                        guard parsed.consumed==container.payload.count,try container.encode()==data else {
                            throw SaveError.invalid("Save-Roundtrip fehlgeschlagen.")
                        }
                        let digest=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
                        bind(saveStatement,1,game.id);bind(saveStatement,2,file.url.lastPathComponent)
                        bind(saveStatement,3,file.url.path);bind(saveStatement,4,file.character)
                        bind(saveStatement,5,formatter.string(from:file.modified));bind(saveStatement,6,digest)
                        sqlite3_bind_int64(saveStatement,7,Int64(parsed.objects))
                        sqlite3_bind_int64(saveStatement,8,Int64(parsed.fields.count))
                        try step(db,saveStatement)
                        let saveID=sqlite3_last_insert_rowid(db)
                        var occurrences:[String:Int]=[:]
                        for scalar in parsed.fields {
                            let occurrence=occurrences[scalar.path,default:0]
                            occurrences[scalar.path]=occurrence+1
                            sqlite3_bind_int64(fieldStatement,1,saveID)
                            sqlite3_bind_int64(fieldStatement,2,Int64(scalar.id))
                            bind(fieldStatement,3,String(format:"%08x",scalar.owner))
                            bind(fieldStatement,4,String(format:"%08x",scalar.field))
                            sqlite3_bind_int64(fieldStatement,5,Int64(scalar.type))
                            sqlite3_bind_int64(fieldStatement,6,Int64(scalar.size))
                            bind(fieldStatement,7,scalar.path)
                            sqlite3_bind_int64(fieldStatement,8,Int64(occurrence))
                            // Serialized text can contain private account data. Index only its structure.
                            bind(fieldStatement,9,scalar.type==15 ? nil:scalar.text)
                            try step(db,fieldStatement)
                        }
                        fileCount+=1;fieldCount+=parsed.fields.count
                    } catch {
                        bind(failureStatement,1,game.id);bind(failureStatement,2,file.url.lastPathComponent)
                        bind(failureStatement,3,error.localizedDescription)
                        try step(db,failureStatement);errorCount+=1
                    }
                }
            }
            guard fileCount>0 else {throw SaveError.invalid("Keine lokalen Saves konnten indexiert werden.")}
            try execute(db,"COMMIT")
            try execute(db,"CREATE INDEX scalars_owner ON scalars(owner); CREATE INDEX scalars_field ON scalars(field); CREATE INDEX scalars_value ON scalars(value); CREATE INDEX saves_game_name ON saves(game,name);")
            try execute(db,"PRAGMA optimize")
            // The database has committed its contents; the scoped defers finalize
            // prepared statements and close the handle after this atomic rename.
            let rc=temporary.path.withCString {source in target.path.withCString {destination in rename(source,destination)}}
            guard rc==0 else {throw SaveError.invalid("Suchindex konnte nicht ersetzt werden.")}
            return SaveSearchSummary(files:fileCount,fields:fieldCount,errors:errorCount,location:target)
        } catch {
            _=sqlite3_exec(db,"ROLLBACK",nil,nil,nil)
            throw error
        }
    }

    private static func insertNames(_ db:OpaquePointer) throws {
        let stmt=try prepare(db,"INSERT INTO names VALUES(?,?,?,?)")
        defer {sqlite3_finalize(stmt)}
        for (kind,catalog) in [("field",RE2FieldNameCatalog.bundled),("owner",RE2OwnerNameCatalog.bundled)] {
            for (hash,candidates) in catalog.sorted(by:{$0.key<$1.key}) {
                bind(stmt,1,"re2");bind(stmt,2,kind);bind(stmt,3,hash)
                bind(stmt,4,candidates.joined(separator:" | "))
                try step(db,stmt)
            }
        }
    }
    private static func execute(_ db:OpaquePointer,_ sql:String) throws {
        guard sqlite3_exec(db,sql,nil,nil,nil)==SQLITE_OK else {
            throw SaveError.invalid("SQLite: \(String(cString:sqlite3_errmsg(db)))")
        }
    }
    private static func prepare(_ db:OpaquePointer,_ sql:String) throws -> OpaquePointer {
        var statement:OpaquePointer?
        guard sqlite3_prepare_v2(db,sql,-1,&statement,nil)==SQLITE_OK,let statement else {
            throw SaveError.invalid("SQLite: \(String(cString:sqlite3_errmsg(db)))")
        }
        return statement
    }
    private static func bind(_ statement:OpaquePointer,_ index:Int32,_ value:String?) {
        if let value {_=value.withCString{sqlite3_bind_text(statement,index,$0,-1,transient)}}
        else {_=sqlite3_bind_null(statement,index)}
    }
    private static func step(_ db:OpaquePointer,_ statement:OpaquePointer) throws {
        guard sqlite3_step(statement)==SQLITE_DONE else {
            throw SaveError.invalid("SQLite: \(String(cString:sqlite3_errmsg(db)))")
        }
        sqlite3_reset(statement);sqlite3_clear_bindings(statement)
    }
}
