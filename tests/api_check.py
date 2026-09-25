import msgpack, glob, re, os, json, sys
p = glob.glob('/root/.cargo/registry/src/*/rbx_reflection_database-3.0.0+roblox-728/database.msgpack')[0]
db = msgpack.unpackb(open(p,'rb').read(), raw=False, strict_map_key=False)
classes, enums = db[1], db[2]
def props_of(cls):
    out = set()
    while cls:
        c = classes.get(cls)
        if not c: break
        out |= set(c[3].keys())
        cls = c[2]
    return out
errors = []
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src')
files = []
for d, _, fs in os.walk(ROOT):
    for f in fs:
        if f.endswith('.luau'): files.append(os.path.join(d, f))

def block_keys(src, start):
    # src[start] == '{' ; return top-level keys
    depth = 0; i = start; keys = []; buf = ''
    while i < len(src):
        ch = src[i]
        if ch in '{([':
            depth += 1
        elif ch in '})]':
            depth -= 1
            if depth == 0: break
        if depth == 1:
            m = re.match(r'[\s,{]*([A-Za-z_]\w*)\s*=(?!=)', src[i:])
            if m and (i == start or src[i] in ',\n\t {'):
                keys.append(m.group(1))
                i += m.end() - 1
        i += 1
    return keys

for path in files:
    src = open(path).read()
    rel = os.path.relpath(path, ROOT)
    for m in re.finditer(r'Enum\.(\w+)\.(\w+)', src):
        e, item = m.groups()
        if e not in enums: errors.append(f'{rel}: unknown enum {e}')
        elif item not in enums[e][1]: errors.append(f'{rel}: unknown enum item Enum.{e}.{item}')
    for m in re.finditer(r'(?:Instance\.new|UI\.New)\("(\w+)"', src):
        if m.group(1) not in classes: errors.append(f'{rel}: unknown class {m.group(1)}')
    # UI.New("Class", { ... })
    for m in re.finditer(r'UI\.New\("(\w+)",\s*\{', src):
        cls = m.group(1); keys = block_keys(src, m.end() - 1)
        valid = props_of(cls)
        for k in keys:
            if k not in valid and k != 'Parent': errors.append(f'{rel}: {cls} has no property {k}')
    for fn, cls in (('UI.Label', 'TextLabel'), ('UI.Button', 'TextButton'), ('UI.Scroll', 'ScrollingFrame'), ('UI.Bar', 'Frame')):
        for m in re.finditer(re.escape(fn) + r'\([^{)]*\{', src):
            keys = block_keys(src, m.end() - 1)
            valid = props_of(cls)
            for k in keys:
                if k not in valid and k not in ('Parent', 'MaxTextSize'): errors.append(f'{rel}: {fn} ({cls}) has no property {k}')
    # local x = Instance.new("C") ; x.Prop =
    for m in re.finditer(r'local (\w+) = Instance\.new\("(\w+)"\)', src):
        var, cls = m.groups(); valid = props_of(cls)
        for pm in re.finditer(r'\b' + var + r'\.(\w+)\s*=[^=]', src):
            if pm.group(1) not in valid: errors.append(f'{rel}: {cls} ({var}) has no property {pm.group(1)}')
    # newPart extra tables in BuildingModels: {... } after material arg
    if rel.endswith('BuildingModels.luau'):
        for m in re.finditer(r'newPart\([^\n]*?(\{[^\n]*\})\)', src):
            for k in re.findall(r'(\w+)\s*=', m.group(1)):
                if k not in props_of('Part'): errors.append(f'{rel}: Part has no property {k}')

# JSON models
def walk(node, rel):
    cls = node.get('className')
    if cls:
        if cls not in classes: errors.append(f'{rel}: unknown class {cls}')
        valid = props_of(cls)
        for k in node.get('properties', {}):
            if k not in valid: errors.append(f'{rel}: {cls} has no property {k}')
    for c in node.get('children', []): walk(c, rel)
for f in glob.glob(ROOT + '/Workspace/*.json'):
    walk(json.load(open(f)), os.path.basename(f))
proj = json.load(open(os.path.join(os.path.dirname(ROOT), 'default.project.json')))
def walkp(node, name):
    cls = node.get('$className')
    if cls:
        valid = props_of(cls)
        for k in node.get('$properties', {}):
            if k not in valid: errors.append(f'project {name}: {cls} has no property {k}')
    for k, v in node.items():
        if not k.startswith('$') and isinstance(v, dict): walkp(v, k)
walkp(proj['tree'], 'root')
print('\n'.join(sorted(set(errors))) or 'API check OK')
print(len(files), 'luau files scanned')
