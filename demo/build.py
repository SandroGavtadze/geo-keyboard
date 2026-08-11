#!/usr/bin/env python3
"""Build demo/index.html: inline the engine and dictionary into template.html."""
import os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
words = open(f'{root}/data/ka_words_freq.tsv').read().strip().split('\n')
words_s = '\n'.join(l.replace('\t', ' ') for l in words)
bigrams = open(f'{root}/data/ka_bigrams.tsv').read().strip().split('\n')
bigrams_s = '\n'.join(l.replace('\t', ' ') for l in bigrams)
engine = open(f'{root}/engine/translit.js').read()
tpl = open(f'{root}/demo/template.html').read()
out = tpl.replace('__WORDS__', words_s).replace('__BIGRAMS__', bigrams_s).replace('__ENGINE__', engine)
open(f'{root}/demo/index.html', 'w').write(out)
print('built demo/index.html: %.1f MB' % (os.path.getsize(f'{root}/demo/index.html') / 1e6))
