#!/usr/bin/env python3
"""Compiles data/ka_words_freq.tsv + data/ka_bigrams.tsv into the binary
dictionary the iOS engine memory-maps (ka_dictionary.bin).

Run from anywhere after changing either TSV:

    python3 tools/build_dictionary.py

Format (little-endian) — keep in sync with CompiledDictionary in
ios-app/GeoIME/Sources/GeoIME/Engine.swift:

    header   magic "GEOT", u32 version, u32 alphabetCount, u32 nodeCount,
             u32 wordCount, u32 bigramCount
    alphabet alphabetCount x u32 unicode scalar
    nodes    nodeCount x 20 bytes, breadth-first so siblings are contiguous:
             u32 firstChild, u32 parent, i32 freq, i32 best,
             u8 childCount, u8 alphabet index, u16 padding
    bigrams  bigramCount x (u32 prevNode, u32 nextNode, u32 count),
             sorted by prevNode, then count descending
"""
import struct
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORDS = ROOT / "data" / "ka_words_freq.tsv"
BIGRAMS = ROOT / "data" / "ka_bigrams.tsv"
OUT = ROOT / "ios-app" / "GeoIME" / "Sources" / "GeoIME" / "Resources" / "ka_dictionary.bin"

VERSION = 1
INT32_MAX = 2**31 - 1


class Node:
    __slots__ = ("children", "freq", "best", "index", "parent", "char")

    def __init__(self, parent=None, char=0):
        self.children = {}  # insertion-ordered: most frequent branch first
        self.freq = 0
        self.best = 0
        self.index = 0
        self.parent = parent
        self.char = char


def rows(path, columns):
    for line in path.read_text(encoding="utf-8").split("\n"):
        parts = line.split("\t")
        if len(parts) == columns:
            yield parts


def main():
    words = [(w, min(int(f), INT32_MAX)) for w, f in rows(WORDS, 2)]
    alphabet = sorted({c for w, _ in words for c in w})
    if len(alphabet) > 255:
        sys.exit(f"alphabet has {len(alphabet)} characters; the format allows 255")
    char_index = {c: i for i, c in enumerate(alphabet)}

    root = Node()
    terminal = {}
    for word, freq in words:
        node = root
        for c in word:
            node.best = max(node.best, freq)
            child = node.children.get(c)
            if child is None:
                child = node.children[c] = Node(node, char_index[c])
            node = child
        node.best = max(node.best, freq)
        node.freq = freq
        terminal[word] = node

    order = []
    queue = deque([root])
    while queue:
        node = queue.popleft()
        node.index = len(order)
        order.append(node)
        queue.extend(node.children.values())

    bigrams = []
    skipped = 0
    for prev, nxt, count in rows(BIGRAMS, 3):
        if prev in terminal and nxt in terminal:
            bigrams.append((terminal[prev].index, terminal[nxt].index, int(count)))
        else:
            skipped += 1
    bigrams.sort(key=lambda b: (b[0], -b[2]))

    out = bytearray()
    out += b"GEOT"
    out += struct.pack("<5I", VERSION, len(alphabet), len(order), len(terminal), len(bigrams))
    out += struct.pack(f"<{len(alphabet)}I", *(ord(c) for c in alphabet))
    for node in order:
        children = list(node.children.values())
        first_child = children[0].index if children else 0
        parent = node.parent.index if node.parent else 0
        out += struct.pack("<IIiiBBH", first_child, parent, node.freq, node.best, len(children), node.char, 0)
    for entry in bigrams:
        out += struct.pack("<3I", *entry)

    OUT.write_bytes(out)
    print(f"{OUT.relative_to(ROOT)}: {len(terminal)} words, {len(order)} nodes, "
          f"{len(bigrams)} bigrams ({skipped} skipped), {len(out) / 1_048_576:.2f} MB")


if __name__ == "__main__":
    main()
