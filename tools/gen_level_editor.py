#!/usr/bin/env python3
"""Generator of tools/level_editor.html - the browser level editor.

Reads everything the editor needs straight from the sources, so the editor
always matches the game:
  inc/defs.inc        colour constants (COL_*, CHEST_COLOR, ROBOT_COLOR)
  src/world.asm       theme_table (tilesets + colours), world_table (names,
                      level ranges -> theme of each existing level)
  src/*.asm           run cells of every theme (ASCII art comments "; --- name"
                      in the generated gfx files) and the robot sprites
  src/mapdata.asm     the existing levels (plan_level_table, blocks world<n>_levels,
                      labels map<world><level>), for loading

The page itself is tools/level_editor_template.html; this script only
injects the data (placeholder /*__DATA__*/).

Usage (from the project folder):
    python -B tools/gen_level_editor.py
then open tools/level_editor.html in a browser. Re-run after changing a
tileset, the theme colours or the levels in mapdata.asm.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(ROOT, 'tools', 'level_editor_template.html')
OUT = os.path.join(ROOT, 'tools', 'level_editor.html')

ROBOT_DIRS = {'ROBOT_DIR_RIGHT': 0, 'ROBOT_DIR_LEFT': 1,
              'ROBOT_DIR_UP': 2, 'ROBOT_DIR_DOWN': 3}


def read(path):
    with open(path, encoding='utf-8', errors='replace') as f:
        return f.read().splitlines()


def strip_comment(line):
    return line.split(';', 1)[0]


# ---------------------------------------------------------------- constants
def parse_consts(lines, consts):
    """NAME = value lines (numbers or names already known)."""
    for line in lines:
        m = re.match(r'^\s*([A-Za-z_]\w*)\s*=\s*([^;]+)', line)
        if not m:
            continue
        try:
            consts[m.group(1)] = evaluate(m.group(2).strip(), consts)
        except (KeyError, ValueError):
            pass
    return consts


def evaluate(expr, consts):
    """Tiny evaluator: numbers ($hex, %bin, dec), known names, + and -."""
    expr = expr.strip()
    total, sign = 0, 1
    for tok in re.findall(r'[+-]|[^+\-\s]+', expr):
        if tok == '+':
            sign = 1
        elif tok == '-':
            sign = -1
        else:
            if tok.startswith('$'):
                v = int(tok[1:], 16)
            elif tok.startswith('%'):
                v = int(tok[1:], 2)
            elif re.match(r'^\d+$', tok):
                v = int(tok)
            else:
                v = consts[tok]
            total += sign * v
            sign = 1
    return total


def byte_tokens(lines, start):
    """Collect the !byte / !word operands of the record starting at line
    index start (the label line) until the next label or directive."""
    out = []
    for line in lines[start + 1:]:
        code = strip_comment(line).strip()
        if not code:
            continue
        m = re.match(r'^!(byte|word)\s+(.*)$', code)
        if not m:
            break
        out += [(m.group(1), t.strip()) for t in m.group(2).split(',') if t.strip()]
    return out


def find_label(lines, label):
    for i, line in enumerate(lines):
        if re.match(r'^%s(\s|$|;)' % re.escape(label), line):
            return i
    raise KeyError('label not found: ' + label)


# ---------------------------------------------------------------- graphics
def art_blocks(lines, start_label, end_label):
    """ASCII art blocks '; --- name' + ';   pixels' between two labels."""
    i = find_label(lines, start_label)
    j = find_label(lines, end_label)
    blocks, name = [], None
    for line in lines[i:j]:
        m = re.match(r'^;\s*---\s*(.+?)\s*$', line)
        if m:
            name = m.group(1)
            blocks.append([name, []])
            continue
        m = re.match(r'^;\s{2,}(\S+)\s*$', line)
        if m and blocks:
            blocks[-1][1].append(m.group(1))
    return blocks


def all_src():
    files = {}
    for path in sorted(glob.glob(os.path.join(ROOT, 'src', '*.asm'))):
        files[path] = read(path)
    return files


def find_in_sources(src, label):
    for path, lines in src.items():
        try:
            return lines, find_label(lines, label)
        except KeyError:
            pass
    raise KeyError('label not found in src/*.asm: ' + label)


def main():
    consts = {}
    parse_consts(read(os.path.join(ROOT, 'inc', 'defs.inc')), consts)
    src = all_src()
    world = read(os.path.join(ROOT, 'src', 'world.asm'))
    parse_consts(world, consts)
    mapdata = read(os.path.join(ROOT, 'src', 'mapdata.asm'))
    consts.update(ROBOT_DIRS)

    # ---- themes
    table = [v for _, v in byte_tokens(world, find_label(world, 'theme_table'))]
    themes = []
    for label in table:
        toks = byte_tokens(world, find_label(world, label))
        cells_label = toks[0][1]
        cols = [evaluate(v, consts) for k, v in toks[2:]]
        lines, _ = find_in_sources(src, cells_label)
        cells = art_blocks(lines, cells_label, cells_label + '_end')
        ncell = len(cells)
        themes.append({
            'id': label,
            'name': label.replace('theme_', '').capitalize(),
            'bg1': cols[0] & 15,
            'bg2': cols[1] & 15,
            'cells': {n: rows for n, rows in cells},
            'cellColors': {cells[k][0]: cols[2 + k] & 7 for k in range(ncell)},
            'robotPlanColor': cols[-1] & 7,
        })

    # ---- robot sprites (shared by all themes)
    lines, _ = find_in_sources(src, 'gfx_run_sprites')
    spr = art_blocks(lines, 'gfx_run_sprites', 'gfx_run_sprites_end')
    sprites = {n: rows for n, rows in spr}
    robot = [sprites['robot right'], sprites['robot left'],
             sprites['robot up'], sprites['robot down']]
    robot_color = consts.get('ROBOT_COLOR', 15)

    # ---- worlds -> theme of each level
    theme_consts = {}
    for line in world:
        m = re.match(r'^(THEME_\w+)\s*=\s*(\d+)', line)
        if m:
            theme_consts[m.group(1)] = int(m.group(2))
    worlds = []
    wlabels = [v for _, v in byte_tokens(world, find_label(world, 'world_table'))]
    for wl in wlabels:
        toks = byte_tokens(world, find_label(world, wl))
        theme = theme_consts.get(toks[0][1], 0)
        name_label = toks[4][1]
        name = wl.replace('world_', '').capitalize()
        for line in world:
            m = re.match(r'^%s\s+!text\s+"([^"]*)"' % re.escape(name_label), line)
            if m:
                name = m.group(1)
        worlds.append({'name': name, 'theme': theme})

    # ---- existing levels: plan_level_table is grouped in blocks world<n>_levels,
    # every level is labelled map<world><level>
    start = find_label(mapdata, 'plan_level_table')
    blocks, cur = {}, None
    for line in mapdata[start + 1:]:
        if line.startswith('plan_level_count'):
            break
        m = re.match(r'^world(\d+)_levels\b', line)
        if m:
            cur = int(m.group(1))
            blocks[cur] = []
            continue
        m = re.match(r'^\s*!word\s+([^;]*)', line)
        if m and cur is not None:
            blocks[cur] += [t.strip() for t in m.group(1).split(',') if t.strip()]
    levels = []
    for w in sorted(blocks):
        for pos, label in enumerate(blocks[w], 1):
            idx = find_label(mapdata, label)
            vals = [evaluate(v, consts) for _, v in byte_tokens(mapdata, idx)]
            # comment block directly above the label
            comment = []
            k = idx - 1
            while k >= 0 and mapdata[k].startswith(';'):
                comment.insert(0, mapdata[k][1:].rstrip())
                k -= 1
            para = []
            for c in comment:
                if not c.strip():
                    if para:
                        break
                    continue
                para.append(c.strip())
            desc = ''
            if para and re.match(r'^map\d\d\b', para[0]):
                desc = re.sub(r'^map\d\d\s*(\([^)]*\))?\s*:?\s*', '', ' '.join(para))
            title = ''
            for c in comment:
                m = re.search(r'"([^"]+)"', c)
                if m:
                    title = m.group(1)
                    break
            winfo = worlds[w - 1] if w <= len(worlds) else {'name': 'World %d' % w, 'theme': 0}
            levels.append({'label': label, 'world': w, 'level': pos, 'bytes': vals,
                           'title': title, 'desc': desc, 'theme': winfo['theme'],
                           'worldName': winfo['name']})

    data = {
        'themes': themes,
        'robot': robot,
        'robotColor': robot_color & 15,
        'worlds': worlds,
        'levels': levels,
        'mapCols': consts.get('MAP_COLS', 10),
        'mapRows': consts.get('MAP_ROWS', 10),
        'maxGoals': 16,
        'maxLocks': consts.get('MAX_LOCKS', 4),
    }
    for line in mapdata:
        m = re.match(r'^MAX_GOALS\s*=\s*(\d+)', line)
        if m:
            data['maxGoals'] = int(m.group(1))

    with open(TEMPLATE, encoding='utf-8') as f:
        page = f.read()
    if '/*__DATA__*/' not in page:
        sys.exit('placeholder /*__DATA__*/ missing in ' + TEMPLATE)
    page = page.replace('/*__DATA__*/', 'const DATA = ' + json.dumps(data, separators=(',', ':')) + ';')
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(page)
    print('wrote', os.path.relpath(OUT, ROOT), '-', len(themes), 'themes,',
          len(levels), 'levels')


if __name__ == '__main__':
    main()
