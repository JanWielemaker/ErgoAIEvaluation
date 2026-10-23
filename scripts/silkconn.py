#!/usr/bin/env python3
"""silkconn.py FILE... -- rewrite old SILK/Flora connectives in rule bodies
for ErgoAI 3.01:  is -> \\is   and -> ,   or -> ;   'not G'/'naf G' -> \\naf G   'neg G' -> \\neg G (also in heads)
Only outside quoted text and only after ':-' or '?-' in a statement.  `not(` with no
space is left alone: the corpus also uses not/1 as an ordinary term."""
import re, sys

WORD = re.compile(r'[A-Za-z_0-9#]')

def convert(text):
    out = []
    i, n = 0, len(text)
    in_body = False
    while i < n:
        c = text[i]
        if c in '"\'':                      # quoted atom/string/IRI
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == '\\' else 1
            out.append(text[i:j+1]); i = j + 1; continue
        if text.startswith('//', i) and (i == 0 or text[i-1] in ' \t\n'):
            j = text.find('\n', i); j = n if j < 0 else j
            out.append(text[i:j]); i = j; continue
        if text.startswith(':-', i) or text.startswith('?-', i):
            in_body = True; out.append(text[i:i+2]); i += 2; continue
        if c == '.' and (i+1 == n or text[i+1] in ' \t\n') :
            in_body = False; out.append(c); i += 1; continue
        if c.isalpha() and (i == 0 or not WORD.match(text[i-1])) \
                and (i == 0 or text[i-1] not in '\\?%'):
            m = re.match(r'[A-Za-z_0-9]+', text[i:]); w = m.group(0)
            after = text[i+len(w):i+len(w)+1]
            if not in_body and not (w == 'neg' and after in (' ', '\t')):
                out.append(w); i += len(w); continue
            if after not in ('#', '(', ':') or w in ('and', 'or'):
                if w == 'is' and after in (' ', '\t'):
                    out.append('\\is'); i += 2; continue
                if w == 'and' and after in (' ', '\t', '\n', '('):
                    out.append(','); i += 3; continue
                if w == 'or' and after in (' ', '\t', '\n', '('):
                    out.append(';'); i += 2; continue
                if w in ('not', 'naf') and after in (' ', '\t'):
                    out.append('\\naf'); i += 3; continue
                if w == 'neg' and after in (' ', '\t'):
                    out.append('\\neg'); i += 3; continue
            out.append(w); i += len(w); continue
        out.append(c); i += 1
    return ''.join(out)

for f in sys.argv[1:]:
    s = open(f, encoding='utf-8', errors='surrogateescape').read()
    open(f, 'w', encoding='utf-8', errors='surrogateescape').write(convert(s))
