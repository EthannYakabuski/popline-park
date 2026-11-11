"""Small release-content checks, separate from runtime acceptance."""
from pathlib import Path
import json, struct

root=Path(__file__).resolve().parents[1]
def png_size(path):
    data=path.read_bytes()
    assert data[:8]==b'\x89PNG\r\n\x1a\n', path
    return struct.unpack('>II',data[16:24])

listing=json.loads((root/'marketing/store-listing.json').read_text(encoding='utf-8'))
assert len(listing['title'])<=30 and len(listing['short_description'])<=80
assert len((root/'marketing/long-description.txt').read_text(encoding='utf-8'))<=4000
catalog=json.loads((root/'game/catalog.json').read_text(encoding='utf-8'))
assert len(catalog['achievements'])==20 and len(catalog['leaderboards'])==3
config=json.loads((root/'platform/config.json').read_text(encoding='utf-8'))
assert config['admob']['test_mode'] is True
assert config['play_games']['enabled'] is False
assert config['play_games']['game_id']==''
assert not any(config['play_games']['achievements'].values())
assert not any(config['play_games']['leaderboards'].values())
for group in ['achievements','leaderboards']:
    for item in catalog[group]:
        assert png_size(root/'marketing'/group/(item['key']+'.png'))==(512,512)
        assert png_size(root/'assets/ui/badges'/(item['key']+'.png'))==(128,128)
assert png_size(root/'marketing/app-icon-512.png')==(512,512)
assert png_size(root/'marketing/feature-graphic-1024x500.png')==(1024,500)
for profile,size in [('phone',(1080,1920)),('tablet7',(800,1280)),('tablet10',(1200,1920))]:
    for name in ['01-park-home','02-first-line','03-boardslide','04-line-landed','05-locker','06-journal']:
        assert png_size(root/'marketing/screenshots'/profile/(name+'.png'))==size
for path in ['LICENSE','NOTICE','LICENSES/INDEX.txt','LICENSES/kenney-board-game-icons.txt']:
    assert (root/path).is_file(),path
print('CONTENT_VALIDATION_PASS: copy limits, 20 achievements, 3 boards, test mappings, icon sizes, 18 genuine capture dimensions, notices')
