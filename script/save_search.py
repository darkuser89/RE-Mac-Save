#!/usr/bin/env python3
"""Read-only queries against the Save Editor's local, disposable search index."""
import argparse
from contextlib import closing
import json
import sqlite3
import sys
from pathlib import Path

DEFAULT_DB = Path('/private/tmp/ResidentEvil-Save-Suche.sqlite')


def connect(path):
    if not path.is_file():
        raise SystemExit(f'Kein Suchindex: {path}. In der App „Schnellindex aktualisieren“ wählen.')
    db = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
    db.row_factory = sqlite3.Row
    version = db.execute("SELECT value FROM meta WHERE key='schema'").fetchone()
    if version is None or version[0] != '1':
        raise SystemExit('Unbekannte Suchindex-Version. Index in der App neu erstellen.')
    return db


def emit(rows, as_json):
    for row in rows:
        item = dict(row)
        if as_json:
            print(json.dumps(item, ensure_ascii=False, sort_keys=True))
        else:
            print('\t'.join(f'{key}={value if value is not None else "<Textwert verborgen>"}'
                            for key, value in item.items()))


def files(db, args):
    created = db.execute("SELECT value FROM meta WHERE key='created_utc'").fetchone()[0]
    print(f'Index erstellt: {created}', file=sys.stderr)
    where = 'WHERE game=?' if args.game else ''
    rows = db.execute(f'SELECT game,name,character,fields,sha256 FROM saves {where} ORDER BY game,name',
                      [args.game] if args.game else [])
    emit(rows, args.json)
    errors = db.execute('SELECT game,name,message FROM failures ORDER BY game,name').fetchall()
    if errors:
        print(f'{len(errors)} nicht indexierte Datei(en):', file=sys.stderr)
        emit(errors, args.json)


def find(db, args):
    clauses, params = [], []
    if args.game:
        clauses.append('s.game=?'); params.append(args.game)
    if args.file:
        clauses.append('s.name=?'); params.append(args.file)
    if args.owner:
        clauses.append('f.owner=?'); params.append(args.owner.lower().removeprefix('0x'))
    if args.field:
        clauses.append('f.field=?'); params.append(args.field.lower().removeprefix('0x'))
    for kind, name, column in [('field', args.field_name, 'f.field'),
                               ('owner', args.owner_name, 'f.owner')]:
        if name:
            candidates = db.execute('SELECT hash,candidates FROM names WHERE kind=?' +
                                    (' AND game=?' if args.game else ''),
                                    [kind] + ([args.game] if args.game else [])).fetchall()
            hashes = sorted({row['hash'] for row in candidates
                             if any(part.casefold() == name.casefold()
                                    for part in row['candidates'].split(' | '))})
            clauses.append(f'{column} IN ({",".join("?" for _ in hashes)})' if hashes else '1=0')
            params.extend(hashes)
    if args.type is not None:
        clauses.append('f.type=?'); params.append(args.type)
    if args.term:
        pattern = f'%{args.term}%'
        clauses.append('(f.path LIKE ? OR f.value LIKE ? OR fn.candidates LIKE ? OR own.candidates LIKE ?)')
        params.extend([pattern] * 4)
    if not clauses:
        raise SystemExit('Bitte Suchbegriff oder mindestens einen Filter angeben.')
    base = '''FROM scalars f JOIN saves s ON s.id=f.save_id
              LEFT JOIN names fn ON fn.game=s.game AND fn.kind='field' AND fn.hash=f.field
              LEFT JOIN names own ON own.game=s.game AND own.kind='owner' AND own.hash=f.owner'''
    condition = ' WHERE ' + ' AND '.join(clauses)
    count = db.execute('SELECT count(*) ' + base + condition, params).fetchone()[0]
    print(f'Treffer: {count}', file=sys.stderr)
    rows = db.execute('''SELECT s.game,s.name AS save,f.ordinal,f.owner,own.candidates AS owner_name,
                        f.field,fn.candidates AS field_name,f.type,f.size,f.path,f.occurrence,f.value ''' +
                      base + condition + ' ORDER BY s.game,s.name,f.ordinal LIMIT ?', params + [args.limit])
    emit(rows, args.json)


def diff(db, args):
    matches = db.execute('SELECT id,name FROM saves WHERE game=? AND name IN (?,?)',
                         (args.game, args.before, args.after)).fetchall()
    by_name = {row['name']: row['id'] for row in matches}
    if len(by_name) != 2 or args.before == args.after:
        raise SystemExit('Beide unterschiedlichen Dateinamen müssen im gewählten Spiel indexiert sein.')
    def snapshot(save_id):
        return {(row['path'], row['occurrence']): (row['value'], row['type'], row['size'])
                for row in db.execute('SELECT path,occurrence,value,type,size FROM scalars WHERE save_id=?',
                                      (save_id,))}
    old, new = snapshot(by_name[args.before]), snapshot(by_name[args.after])
    changed = 0
    added = removed = 0
    for key in sorted(old.keys() | new.keys()):
        before, after = old.get(key), new.get(key)
        if before == after:
            continue
        if before is None:
            added += 1
        elif after is None:
            removed += 1
        if args.common_only and (before is None or after is None):
            continue
        changed += 1
        if changed <= args.limit:
            record = {'path': key[0], 'occurrence': key[1], 'before': before[0] if before else None,
                      'after': after[0] if after else None, 'kind': 'changed' if before and after else
                      ('removed' if before else 'added')}
            if args.json:
                print(json.dumps(record, ensure_ascii=False, sort_keys=True))
            else:
                print(f'{record["kind"]}\t{key[0]}#{key[1]}\t{record["before"]} -> {record["after"]}')
    print(f'Unterschiedliche Positionen im gewählten Vergleich: {changed}; hinzugekommen: {added}; '
          f'weggefallen: {removed}', file=sys.stderr)


def owners(db, args):
    clauses, params = [], []
    if args.game:
        clauses.append('s.game=?'); params.append(args.game)
    if args.file:
        clauses.append('s.name=?'); params.append(args.file)
    if args.unknown:
        clauses.append('n.candidates IS NULL')
    condition = ' WHERE ' + ' AND '.join(clauses) if clauses else ''
    rows = db.execute('''SELECT s.game,f.owner,n.candidates AS owner_name,count(*) AS fields,
                         count(DISTINCT s.id) AS saves
                         FROM scalars f JOIN saves s ON s.id=f.save_id
                         LEFT JOIN names n ON n.game=s.game AND n.kind='owner' AND n.hash=f.owner'''
                      + condition + ' GROUP BY s.game,f.owner ORDER BY fields DESC LIMIT ?',
                      params + [args.limit])
    emit(rows, args.json)


def main():
    parser = argparse.ArgumentParser(description='Lokale RE-Save-Felder im von der App erzeugten Index suchen.')
    parser.add_argument('--db', type=Path, default=DEFAULT_DB)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('files', help='Indexierte Dateien und Standzeit anzeigen')
    p.add_argument('--game', choices=['re2','re3','re4','re7','re8']); p.add_argument('--json', action='store_true')
    p = sub.add_parser('find', help='Feldnamen, Besitzer, Pfade und Zahlenwerte durchsuchen')
    p.add_argument('term', nargs='?'); p.add_argument('--game', choices=['re2','re3','re4','re7','re8'])
    p.add_argument('--file'); p.add_argument('--owner'); p.add_argument('--field')
    p.add_argument('--field-name', help='exakter RE2-Feldname, nutzt den Hash-Index')
    p.add_argument('--owner-name', help='exakter RE2-Besitzername, nutzt den Hash-Index')
    p.add_argument('--type', type=int); p.add_argument('--limit', type=int, default=80)
    p.add_argument('--json', action='store_true')
    p = sub.add_parser('diff', help='Zwei Saves desselben Spiels nach Feldpfad vergleichen')
    p.add_argument('game', choices=['re2','re3','re4','re7','re8'])
    p.add_argument('before'); p.add_argument('after'); p.add_argument('--limit', type=int, default=100)
    p.add_argument('--common-only', action='store_true', help='nur veränderte gemeinsame Rohpfade')
    p.add_argument('--json', action='store_true')
    p = sub.add_parser('owners', help='Felder nach Besitzerhash gruppieren')
    p.add_argument('--game', choices=['re2','re3','re4','re7','re8']); p.add_argument('--file')
    p.add_argument('--unknown', action='store_true'); p.add_argument('--limit', type=int, default=100)
    p.add_argument('--json', action='store_true')
    args = parser.parse_args()
    if hasattr(args, 'limit') and not 1 <= args.limit <= 10000:
        parser.error('--limit muss zwischen 1 und 10000 liegen')
    if args.command == 'find' and (args.field_name or args.owner_name) and args.game != 're2':
        parser.error('Namenskandidaten sind derzeit nur mit --game re2 verfügbar')
    with closing(connect(args.db)) as db:
        {'files': files, 'find': find, 'diff': diff, 'owners': owners}[args.command](db, args)


if __name__ == '__main__':
    main()
