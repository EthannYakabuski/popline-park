"""Create a local-only expansion receipt; never equate dirty source with the public commit."""
from pathlib import Path
import hashlib,json,subprocess,zipfile
root=Path(__file__).resolve().parents[1]
out=root/'build/expansion-v1.1'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
artifacts={}
for name in ['android/popline-park-1.1-debug.aab','android/popline-park-1.1-test.apk','android/popline-park-1.1-acceptance.apk','site/play/index.pck','site/play/index.wasm']:
    p=out/name
    item={'bytes':p.stat().st_size,'sha256':sha(p)}
    if p.suffix in ['.aab','.apk']:
        with zipfile.ZipFile(p) as z:
            names=z.namelist()
            config=json.loads(z.read(next(n for n in names if n.endswith('/platform/config.json'))))
            assert config['admob']['test_mode'] and not config['play_games']['enabled'] and not config['play_games']['game_id']
            assert any(n.endswith('/LICENSES/NotoSansCJK-OFL.txt') for n in names)
            assert not any('/tests/' in n or '/marketing/' in n or n.endswith(('.jks','.keystore')) for n in names)
            item['packaged_notices_test_ids_and_exclusions']='PASS'
    artifacts['build/expansion-v1.1/'+name]=item
paths=subprocess.check_output(['git','ls-files','-co','--exclude-standard','-z'],cwd=root).decode().split('\0')
source={}
for rel in sorted(set(paths)):
    if rel and ((root/rel).suffix in ['.gd','.json','.tscn','.cfg'] or rel=='project.godot') and not rel.startswith(('docs/','marketing/','build/')):
        source[rel]=sha(root/rel)
receipt={'game':'Popline Park','version':'1.1.0 (2)','publication':'LOCAL ONLY; not committed, pushed or deployed','base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'source_files_sha256':source,'source_tree_sha256':hashlib.sha256(json.dumps(source,sort_keys=True).encode()).hexdigest(),'artifacts':artifacts,'engine':'4.5.1.stable.official.f62fdbde1','physical_device_verified':False,'production_services_verified':False}
(root/'docs/expansion-build-evidence.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'source_tree_sha256':receipt['source_tree_sha256'],'artifacts':artifacts},indent=2))
