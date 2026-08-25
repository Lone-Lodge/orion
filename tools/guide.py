# Build docs/syntax.sv.html from docs/SYNTAX.sv.md.
#
# One source. The markdown is what GitHub renders and what a person reads in
# the repo; the page is the same text on the workshop paper, with the code
# coloured. A .md served by Pages arrives as raw text in the browser, which is
# why the guide links the page and not the file. `--check` fails when the
# committed page is not what this script makes.
#
#   python tools/guide.py           # write docs/index.html
#   python tools/guide.py --check   # fail if the committed page is stale
import html
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'docs', 'SYNTAX.sv.md')
PAGE = os.path.join(ROOT, 'docs', 'syntax.sv.html')

TITLE = 'Orions syntax'
LEDE = 'Varje ord och form i spraket, pa en sida.'

SHELL = """<!DOCTYPE html>
<html lang="sv">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{lede}">
<link rel="stylesheet" href="style.css">
</head>
<body>

<a class="skip" href="#guide">Hoppa till innehallet</a>

<header>
<h1>{title}</h1>
<p class="lede">{lede}</p>
<p class="lede"><a href="index.html">Faltguiden</a> ar sidan pa engelska som
visar spraket i tolv program. Den har sidan ar uppslagsverket.</p>
</header>

<nav class="toc" aria-labelledby="toc-h">
<h2 class="toc-h" id="toc-h">Pa den har sidan</h2>
<ol>
{toc}</ol>
</nav>

<main id="guide">
{body}</main>

<footer>
<p>Orion ar skrivet i Orion. Kompilatorn kompilerar sig sjalv.
<a href="https://github.com/Lone-Lodge/orion">Kallkoden pa GitHub</a>.</p>
</footer>

<script src="highlight.js"></script>

</body>
</html>
"""


def inline(text):
    """Markdown spans: code, bold, links. Escaped first so code stays literal."""
    out, i, parts = '', 0, []
    for m in re.finditer(r'`([^`]+)`', text):
        parts.append(('t', text[i:m.start()]))
        parts.append(('c', m.group(1)))
        i = m.end()
    parts.append(('t', text[i:]))
    for kind, chunk in parts:
        if kind == 'c':
            out += '<code>' + html.escape(chunk) + '</code>'
            continue
        chunk = html.escape(chunk)
        chunk = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', chunk)
        chunk = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', chunk)
        out += chunk
    return out


def slug(text):
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')


def render(md):
    lines = md.split('\n')
    body, toc, i, n = [], [], 0, 0
    para = []

    def flush():
        if para:
            body.append('<p>' + inline(' '.join(para)) + '</p>')
            para.clear()

    while i < len(lines):
        line = lines[i]
        if line.startswith('```'):
            flush()
            lang = line[3:].strip()
            i += 1
            code = []
            while i < len(lines) and not lines[i].startswith('```'):
                code.append(lines[i])
                i += 1
            i += 1
            tag = ' data-code' if lang in ('python', 'orion') else ''
            body.append('<pre><code' + tag + '>' +
                        html.escape('\n'.join(code)) + '</code></pre>')
            continue
        if line.startswith('|') and i + 1 < len(lines) and set(lines[i + 1].replace('|', '').strip()) <= set('-: '):
            flush()
            head = [c.strip() for c in line.strip('|').split('|')]
            i += 2
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                rows.append([c.strip() for c in lines[i].strip('|').split('|')])
                i += 1
            body.append('<table><thead><tr>' +
                        ''.join('<th>' + inline(c) + '</th>' for c in head) +
                        '</tr></thead><tbody>' +
                        ''.join('<tr>' + ''.join('<td>' + inline(c) + '</td>' for c in r) + '</tr>'
                                for r in rows) +
                        '</tbody></table>')
            continue
        if line.startswith('- '):
            flush()
            items = []
            while i < len(lines) and (lines[i].startswith('- ') or
                                      (items and lines[i].startswith('  ') and lines[i].strip())):
                if lines[i].startswith('- '):
                    items.append(lines[i][2:].strip())
                else:
                    items[-1] += ' ' + lines[i].strip()
                i += 1
            body.append('<ul>' + ''.join('<li>' + inline(t) + '</li>' for t in items) + '</ul>')
            continue
        if line.startswith('## '):
            flush()
            n += 1
            title = line[3:].strip()
            sid = slug(title)
            toc.append('<li><a href="#{0}">{1}</a></li>'.format(sid, inline(title)))
            body.append('<h2 id="{0}">{1}. {2}</h2>'.format(sid, n, inline(title)))
            i += 1
            continue
        if line.startswith('# '):
            flush()
            i += 1
            continue
        if line.strip() == '':
            flush()
            i += 1
            continue
        para.append(line.strip())
        i += 1
    flush()
    return '\n'.join(body), '\n'.join(toc) + '\n'


def build():
    md = open(SOURCE, encoding='utf-8').read()
    body, toc = render(md)
    return SHELL.format(title=TITLE, lede=LEDE, toc=toc, body=body)


if __name__ == '__main__':
    page = build()
    if '--check' in sys.argv:
        have = open(PAGE, encoding='utf-8').read() if os.path.exists(PAGE) else ''
        if have.replace('\r\n', '\n') != page:
            print('  syntax: FAIL - docs/syntax.sv.html is stale, run python tools/guide.py')
            sys.exit(1)
        print('  syntax: docs/syntax.sv.html matches docs/SYNTAX.sv.md')
    else:
        open(PAGE, 'w', encoding='utf-8', newline='').write(page)
        print('  syntax: docs/syntax.sv.html written from docs/SYNTAX.sv.md')
