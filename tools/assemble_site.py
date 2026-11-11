"""Assemble a static, iframe-ready Web preview around an existing Godot export."""
from pathlib import Path
import json, shutil, subprocess, sys

root=Path(__file__).resolve().parents[1]
target=Path(sys.argv[1] if len(sys.argv)>1 else root/'build/site').resolve()
assert (target/'play/index.html').is_file(), 'Export Web to <site>/play/index.html first'
target.mkdir(parents=True,exist_ok=True)
shutil.copy2(root/'public/index.html',target/'index.html')
for folder in ['review','marketing','docs']:
    shutil.copytree(root/folder,target/folder,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.import','*.private.*'))
for name in ['LICENSE','NOTICE']:
    shutil.copy2(root/name,target/name)
shutil.copytree(root/'LICENSES',target/'LICENSES',dirs_exist_ok=True)
try: commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
except (OSError,subprocess.CalledProcessError): commit='uncommitted-local-review'
(target/'build.json').write_text(json.dumps({'game':'Popline Park','source_commit':commit,'engine':'4.5.1.stable','web_threads':False},indent=2),encoding='utf-8')
print('Assembled',target,'from',commit)
