"""Assemble a static, iframe-ready Web preview around an existing Godot export."""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys

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
runtime={}
for folder in ['game','platform','assets','addons','scenes']:
    for file in sorted((root/folder).rglob('*')):
        if file.is_file() and file.suffix in ['.gd','.json','.tscn','.glb','.png','.ogg','.wav','.aar'] and not any(part in ['downloads','ios','csharp','sample'] for part in file.parts):
            with file.open('rb') as stream:runtime[file.relative_to(root).as_posix()]=hashlib.file_digest(stream,'sha256').hexdigest()
for name in ['project.godot','export_presets.cfg']:
    runtime[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
runtime_hash=hashlib.sha256(json.dumps(runtime,sort_keys=True).encode()).hexdigest()
dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True).strip())
metadata={'game':'Popline Park','source_commit':commit,'uncommitted_changes':dirty,'runtime_tree_sha256':runtime_hash,'source_identity':('local-uncommitted/'+runtime_hash if dirty else commit),'engine':'4.5.1.stable','web_threads':False}
(target/'build.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
print('Assembled',target,'from',metadata['source_identity'])
