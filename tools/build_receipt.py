"""Bind final local artifacts to their source commit and inspect packaged notices."""
from pathlib import Path
import hashlib, json, subprocess, zipfile
root=Path(__file__).resolve().parents[1]
def digest(p):
    with p.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
artifacts={}
for rel in ['build/android/popline-park-debug.aab','build/android/popline-park-test.apk','build/android/popline-park-acceptance.apk','build/site/play/index.pck','build/site/play/index.wasm']:
    p=root/rel
    artifacts[rel]={'bytes':p.stat().st_size,'sha256':digest(p)}
for rel in list(artifacts)[:3]:
    with zipfile.ZipFile(root/rel) as z:
        names=z.namelist()
        configs=[n for n in names if n.endswith('/platform/config.json')]
        assert len(configs)==1
        config=json.loads(z.read(configs[0]))
        assert config['admob']['test_mode'] is True and config['play_games']['enabled'] is False
        assert not config['play_games']['game_id']
        assert any(n.endswith('/LICENSES/NotoSansCJK-OFL.txt') for n in names),'Missing font notice '+rel
        assert any(n.endswith('/LICENSES/admob-MIT.txt') for n in names)
        assert not any('/tests/' in n or '/marketing/' in n or '/downloads/' in n or n.endswith(('.jks','.keystore')) for n in names)
        artifacts[rel]['packaged_notices_and_test_config']='PASS'
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
paths=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')
runtime={p:digest(root/p) for p in paths if p and (p.startswith(('game/','platform/','assets/','addons/','LICENSES/','scenes/')) or p in ['project.godot','export_presets.cfg','LICENSE','NOTICE'])}
receipt={'game':'Popline Park','source_commit_at_receipt':commit,'godot':'4.5.1.stable.official.f62fdbde1','package':'com.ethannyakabuski.poplinepark','version':'1.0.0 (1)','artifacts':artifacts,'runtime_source_files_sha256':runtime,'physical_device_verified':False,'production_services_verified':False}
(root/'docs/build-evidence.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'source_commit':commit,'artifacts':artifacts},indent=2))
