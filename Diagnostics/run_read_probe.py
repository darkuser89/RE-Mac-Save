#!/usr/bin/env python3
"""Run an explicitly approved, exact-build, read-only save-key probe.

The user must approve DYLD_INSERT_LIBRARIES testing before running this tool.
Does not terminate existing games or write any game/save file.
"""
import argparse
import json
import os
import plistlib
import subprocess
from pathlib import Path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profiles',type=Path)
    parser.add_argument('game',choices=['re2','re3','re7','re8'])
    parser.add_argument('module',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    profiles=json.loads(args.profiles.read_text())
    spec=next(p for p in profiles if p['id']==args.game)
    app=Path(spec['app']);info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if info['CFBundleIdentifier']!=spec['bundle'] or info['CFBundleExecutable']!=spec['executable']:
        raise SystemExit('App identity changed; no launch.')
    processes=subprocess.check_output(['ps','-axo','pid=,comm='],text=True).splitlines()
    for profile in profiles:
        executable=str(Path(profile['app'])/'Contents/MacOS'/profile['executable'])
        if any(line.strip().endswith(executable) for line in processes):
            raise SystemExit('An RE test/game is already running; no second launch or termination.')
    if not args.module.is_file():raise SystemExit('Probe module missing.')
    args.output.mkdir(parents=True,exist_ok=True)
    destination=args.output/(args.game+'-key.json')
    fd=os.open(destination,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    environment=os.environ.copy()
    environment.update(DYLD_INSERT_LIBRARIES=str(args.module.resolve()),RESAVE_READ_PROBE_FD=str(fd),RESAVE_READ_PROBE_SPEC=json.dumps(spec,separators=(',',':')))
    try:
        child=subprocess.Popen([str(app/'Contents/MacOS'/spec['executable'])],env=environment,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,pass_fds=(fd,),start_new_session=True)
    finally:os.close(fd)
    (args.output/(args.game+'-process.json')).write_text(json.dumps({'pid':child.pid,'app':str(app)}))
    print(json.dumps({'game':args.game,'pid':child.pid,'readOnlyKeyCheck':True}))

if __name__=='__main__':main()
