from pathlib import Path
from PIL import Image
import xml.etree.ElementTree as ET
import shutil, sys

root = Path('third_party/kenney')
out = Path('assets/images')
out.mkdir(parents=True, exist_ok=True)
frames = []
for xml_path in root.rglob('*.xml'):
    try:
        tree = ET.parse(xml_path)
    except Exception:
        continue
    atlas = xml_path.with_suffix('.png')
    if not atlas.exists():
        for element in tree.iter():
            for key in ('imagePath', 'image', 'texture'):
                value = element.attrib.get(key)
                if value and (xml_path.parent / value).exists():
                    atlas = xml_path.parent / value
                    break
            if atlas.exists():
                break
    if not atlas.exists():
        continue
    try:
        sheet = Image.open(atlas).convert('RGBA')
    except Exception:
        continue
    for element in tree.iter():
        a = element.attrib
        name = a.get('name') or a.get('n')
        if not name:
            continue
        try:
            x = int(float(a.get('x', '0'))); y = int(float(a.get('y', '0')))
            w = int(float(a.get('width', a.get('w', '0')))); h = int(float(a.get('height', a.get('h', '0'))))
        except ValueError:
            continue
        if w > 0 and h > 0 and x >= 0 and y >= 0 and x+w <= sheet.width and y+h <= sheet.height:
            frames.append((name.lower(), sheet.crop((x,y,x+w,y+h))))

for png in root.rglob('*.png'):
    if 'spritesheet' in png.name.lower():
        continue
    try:
        frames.append((png.stem.lower(), Image.open(png).convert('RGBA')))
    except Exception:
        pass

if not frames:
    print('No usable PNG sprites or XML atlases found in Kenney pack', file=sys.stderr)
    sys.exit(2)

aliases = {
 'hero_idle': ['character_beige_idle','platformchar_idle','player_idle','character_idle','oopi_idle','character_beige','idle'],
 'hero_run': ['character_beige_walk_a','character_beige_walk1','character_beige_run','platformchar_walk1','platformchar_run1','player_run','character_beige','walk1','walk_1','run1','walk'],
 'hero_run2': ['character_beige_walk_b','character_beige_walk2','character_beige_run2','platformchar_walk2','platformchar_run2','character_beige','walk2','walk_2','run2'],
 'hero_jump': ['character_beige_jump','platformchar_jump','player_jump','character_beige','jump'],
 'hero_hurt': ['character_beige_hurt','character_beige_fall','platformchar_hurt','player_hurt','character_beige','hurt','fall','dead'],
 'hero_crouch': ['character_beige_duck','character_beige_crouch','crouch','duck'],
 'enemy_slime': ['slime','platformenemy_walk1','enemy_walk1','enemy_idle','enemy'],
 'enemy_spike': ['spike','platformenemy_walk2','enemy_walk2'],
 'enemy_butterfly': ['butterfly','moth','fly'],
 'coin': ['coin_gold','platformcoin','coin'],
 'gem': ['gem','diamond'],
 'crate_sun': ['block_coin','block_sun','crate'],
 'crate': ['crate','woodenblock','block'],
 'block_moss': ['grass_block','moss','block_grass','brick'],
 'checkpoint': ['checkpoint','flag'],
 'spring': ['spring'],
 'treasure': ['treasure','chest'],
 'tree': ['tree'], 'pine': ['pine','bush','tree'], 'bush': ['bush'], 'flowers': ['flower'], 'rock': ['rock'],
 'cloud': ['cloud'], 'background_hills': ['hills','mountain','background'],
 'bridge': ['bridge'], 'platform_grass': ['grass','ground','platform'], 'platform_stone': ['stone','rock','brick'],
 'platform_column': ['column','cliff','wall'],
}

def choose(keys, used):
    for key in keys:
        matches = [(n, im) for n, im in frames if key in n]
        if matches:
            for item in matches:
                if item[0] not in used:
                    return item
            return matches[0]
    return None

used = set()
for alias, keys in aliases.items():
    found = choose(keys, used)
    if found is None:
        found = next(((n, im) for n, im in frames if n not in used), frames[0])
    name, image = found
    used.add(name)
    image.save(out / f'{alias}.png', optimize=True)
    print(f'{alias} <= {name} ({image.width}x{image.height})')

license_files = list(root.rglob('License.txt')) + list(root.rglob('LICENSE.txt')) + list(root.rglob('license.txt'))
if license_files:
    shutil.copy2(license_files[0], Path('assets/KENNEY_LICENSE.txt'))
