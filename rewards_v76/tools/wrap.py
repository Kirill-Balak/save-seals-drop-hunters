import pathlib, subprocess, sys, re, textwrap

root = pathlib.Path(__file__).resolve().parent.parent
tool = root.parent / 'rewards_v20/tools/vendor/shrinko8-main/shrinko8.py'
source, target, literals = map(pathlib.Path, sys.argv[1:4])
literal_start, literal_end, extra_first, extra_stop, row_offset = map(int, sys.argv[4:9])
pretty = target.with_name('pretty.p8')
subprocess.run([sys.executable, str(tool), str(source), str(pretty),
    '--unminify', '--unminify-indent', '1'], check=True)
data = pretty.read_text(encoding='utf-8')
header, code = data.split('__lua__\n', 1)
code = re.split(r'\n__[a-z_]+[:_]', code, maxsplit=1)[0]

# The VM can generate string literals wider than the editor limit.
# Read long binary literals from reserved ROM rows at runtime.
sys.path.insert(0, str(tool.parent))
from pico_defs import from_p8str, to_p8str
from pico_parse import parse
from pico_srcdefs import Source
from pico_tokenize import TokenType, parse_string_literal, tokenize
pico_code = to_p8str(code)
tokens, errors = tokenize(Source(str(pretty), pico_code), all_comments=True)
assert not errors, errors
for comment in sorted(
    (comment for token in tokens for comment in token.children if comment.isblock),
    key=lambda comment: comment.idx, reverse=True,
):
    blank = re.sub(r'[^\n]', ' ', pico_code[comment.idx:comment.endidx])
    pico_code = pico_code[:comment.idx] + blank + pico_code[comment.endidx:]
packed_literals = bytearray()
for index in range(len(tokens) - 1, -1, -1):
    token = tokens[index]
    if token.type != TokenType.string:
        continue
    previous = tokens[index - 1].value if index else None
    explicit = previous == "rom_literal"
    width = 30 if token.value.startswith('[') else 26
    if not explicit and max(map(len, token.value.split('\n'))) <= width:
        continue
    value = parse_string_literal(token.value)
    start = tokens[index - 1].idx if explicit else token.idx
    if previous == "split" and re.fullmatch(r"\d+(,\d+)+", value):
        rows = textwrap.wrap(value.replace(",", ", "), 27, break_long_words=False)
        expr = '[[\n' + '\n'.join(rows) + '\n]]'
    else:
        offset = len(packed_literals)
        packed_literals.extend(map(ord, value))
        expr = f'\nsub(rom_data,{offset + 1},{offset + len(value)})\n'
        if not explicit and previous not in (",", ".."):
            expr = '(' + expr + ')'
    pico_code = pico_code[:start] + expr + pico_code[token.endidx:]
code = from_p8str(pico_code)
if packed_literals:
    loader = f"""--core
local rom_data=chr(peek({literal_start},{literal_end - literal_start}))
for y={extra_first},{extra_stop - 1} do
 rom_data..=chr(peek(y*64+{row_offset},{64 - row_offset}))
end
"""
    code = code.replace("--core\n", loader, 1)
literals.write_bytes(packed_literals)

output = []
long = False
for raw in code.splitlines():
    indent = '\t' * min(4, len(raw) - len(raw.lstrip(' ')))
    line = raw.strip()
    if line.startswith('print(') and line.endswith(')'):
        line = '?' + line[6:-1]
    if line.startswith('--') and len(line) > 30:
        output.extend(indent + '-- ' + s for s in textwrap.wrap(line[2:].strip(), 27))
        continue
    if line.startswith('?'):
        parts, quote, escape = [], None, False
        for i, c in enumerate(line):
            if quote:
                parts.append(c)
                if escape: escape = False
                elif c == '\\': escape = True
                elif c == quote: quote = None
            elif c in '\"\'':
                quote = c
                parts.append(c)
            elif c.isspace():
                left = parts[-1] if parts else ''
                right = line[i+1:].lstrip()[:1]
                if (left.isalnum() or left == '_') and (right.isalnum() or right == '_'):
                    parts.append(' ')
            else: parts.append(c)
        line = ''.join(parts)
        if len(line) <= 30:
            output.append(indent + line)
            continue
        line = 'print(' + line[1:] + ')'
    if long:
        if ']]' in line:
            long = False
            body, line = line.split(']]', 1)
            if len(body) + 2 > 30:
                raise RuntimeError('long string row exceeds 30: ' + body)
            output.append(body + ']]')
            line = line.strip()
            if not line: continue
        else:
            if len(line) > 30:
                raise RuntimeError('long string row exceeds 30: ' + line)
            output.append(line)
            continue
    line = indent + line
    if '[[' in line and not line.startswith('--'):
        long = ']]' not in line
    while len(line) > 30:
        quote = None
        cuts = []
        escape = False
        for i, c in enumerate(line[:30]):
            if quote:
                if escape: escape = False
                elif c == '\\': escape = True
                elif c == quote: quote = None
            elif c in '\"\'': quote = c
            elif c.isspace() or c in ',({[]})': cuts.append(i + 1)
            elif line[i:i+2] == '..' and i+2<=30:
                cuts.append(i+2)
        if not cuts:
            raise RuntimeError('cannot wrap: ' + line)
        at = cuts[-1]
        prefix = line[:len(line) - len(line.lstrip('\t'))]
        if at <= len(prefix):
            raise RuntimeError('cannot wrap identifier: ' + line)
        output.append(line[:at].rstrip())
        line = prefix + line[at:].lstrip()
    output.append(line)
while output and not output[0].strip():
    output.pop(0)
output_code = '\n'.join(output) + '\n'
wrapped = Source(str(target), to_p8str(output_code))
tokens, errors = tokenize(wrapped)
assert not errors, errors
_, errors = parse(wrapped, tokens)
assert not errors, errors
target.write_text(header + '__lua__\n' + output_code, encoding='utf-8')
counted = subprocess.run([sys.executable, str(tool), str(target), '--count'],
                         check=True, capture_output=True, text=True)
print(counted.stdout, end='')
if int(re.search(r'tokens: (\d+)', counted.stdout).group(1)) > 8192:
    raise RuntimeError('shipping cartridge exceeds 8192 tokens')
