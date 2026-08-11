/**
 * geo-keyboard — Latin → Georgian transliteration engine (prototype, JS).
 * This is the reference implementation; it will be ported to Swift for iOS.
 *
 * Core idea (pinyin-style IME):
 *   1. The user types informal Latin Georgian ("saxlshi", "gamarjoba").
 *   2. Latin sequences map ambiguously to Georgian letters (t→თ/ტ, k→კ/ქ, ch→ჩ/ჭ ...).
 *   3. We DFS the Latin input against a trie of a frequency-ranked Georgian
 *      dictionary, so only real-word paths survive.
 *   4. Candidates are scored by word frequency minus mapping penalties.
 */

// ---------------------------------------------------------------------------
// Mappings: latin sequence -> list of [georgianChar, penalty]
// Penalty 0 = the most conventional reading; higher = less common convention.
// Multi-character sequences are tried first but single-char segmentations of
// the same letters are also explored (e.g. "sh" as ს+ჰ), the trie prunes.
// ---------------------------------------------------------------------------
const MAPPINGS = {
  // trigraphs
  tch: [['ჭ', 0.0]],
  dzh: [['ჯ', 0.2]],
  // digraphs
  sh: [['შ', 0.0]],
  ch: [['ჩ', 0.0], ['ჭ', 0.3]],
  zh: [['ჟ', 0.0]],
  kh: [['ხ', 0.0]],
  gh: [['ღ', 0.0]],
  ts: [['ც', 0.1], ['წ', 0.2]],
  tc: [['ც', 0.4], ['წ', 0.5]],
  dz: [['ძ', 0.0]],
  dj: [['ჯ', 0.2]],
  // singles
  a: [['ა', 0.0]],
  b: [['ბ', 0.0]],
  c: [['ც', 0.1], ['ჩ', 0.4], ['წ', 0.5], ['ჭ', 0.7], ['კ', 0.8]],
  d: [['დ', 0.0]],
  e: [['ე', 0.0]],
  f: [['ფ', 0.0]],
  g: [['გ', 0.0], ['ღ', 0.45]],
  h: [['ჰ', 0.0], ['ხ', 0.3]],
  i: [['ი', 0.0]],
  j: [['ჯ', 0.0], ['ჟ', 0.3]],
  k: [['კ', 0.1], ['ქ', 0.1], ['ყ', 0.5]],
  l: [['ლ', 0.0]],
  m: [['მ', 0.0]],
  n: [['ნ', 0.0]],
  o: [['ო', 0.0]],
  p: [['პ', 0.1], ['ფ', 0.2]],
  q: [['ქ', 0.1], ['ყ', 0.1]],
  r: [['რ', 0.0]],
  s: [['ს', 0.0], ['შ', 0.5]],
  t: [['თ', 0.1], ['ტ', 0.2]],
  u: [['უ', 0.0]],
  v: [['ვ', 0.0]],
  w: [['წ', 0.1], ['ვ', 0.4], ['ჭ', 0.5]],
  x: [['ხ', 0.0]],
  y: [['ყ', 0.1], ['ი', 0.5]],
  z: [['ზ', 0.0], ['ძ', 0.3]],
};

// Uppercase conventions (common in translit chat: T=თ, W=ჭ, R=ღ, S=შ ...)
const UPPER_MAPPINGS = {
  T: [['თ', 0.0]],
  t: [['ტ', 0.0], ['თ', 0.15]],
  K: [['ქ', 0.0]],
  k: [['კ', 0.0], ['ქ', 0.15]],
  P: [['ფ', 0.0]],
  p: [['პ', 0.0], ['ფ', 0.15]],
  W: [['ჭ', 0.0]],
  C: [['ჩ', 0.1], ['ც', 0.2]],
  S: [['შ', 0.0]],
  Z: [['ძ', 0.0]],
  J: [['ჟ', 0.0]],
  R: [['ღ', 0.0]],
  X: [['ხ', 0.0]],
  G: [['ღ', 0.2], ['გ', 0.2]],
  Q: [['ყ', 0.0]],
  H: [['ხ', 0.2], ['ჰ', 0.2]],
};

const MAX_SEQ_LEN = 3;

// ---------------------------------------------------------------------------
// Trie over the Georgian dictionary
// ---------------------------------------------------------------------------
class TrieNode {
  constructor() {
    this.children = new Map(); // georgian char -> TrieNode
    this.freq = 0;             // >0 iff a word ends here
    this.best = 0;             // max word freq in this subtree (for pruning/completions)
  }
}

class Engine {
  /**
   * @param {Array<[string, number]>} words  [georgianWord, frequency] sorted desc
   * @param {Array<[string, string, number]>} bigrams  [prev, next, count]
   */
  constructor(words, bigrams = []) {
    this.root = new TrieNode();
    this.freqs = new Map();
    let n = 0;
    for (const [w, f] of words) {
      this.freqs.set(w, f);
      this._insert(w, f);
      n++;
    }
    this.wordCount = n;
    this.bigrams = new Map(); // prev -> [[next, count], ...] sorted desc
    for (const [a, b, c] of bigrams) {
      if (!this.bigrams.has(a)) this.bigrams.set(a, []);
      this.bigrams.get(a).push([b, c]);
    }
    for (const list of this.bigrams.values()) list.sort((x, y) => y[1] - x[1]);
  }

  _insert(word, freq) {
    let node = this.root;
    for (const ch of word) {
      if (node.best < freq) node.best = freq;
      if (!node.children.has(ch)) node.children.set(ch, new TrieNode());
      node = node.children.get(ch);
    }
    if (node.best < freq) node.best = freq;
    node.freq = freq;
  }

  isWord(w) { return this.freqs.has(w); }

  /**
   * Literal (non-dictionary) transliteration: best-effort greedy conversion.
   * Used for the verbatim candidate so out-of-vocabulary words still convert.
   */
  literal(latin) {
    let out = '';
    let i = 0;
    const s = latin;
    while (i < s.length) {
      let matched = false;
      for (let len = MAX_SEQ_LEN; len >= 1; len--) {
        const seqRaw = s.slice(i, i + len);
        const seq = seqRaw.toLowerCase();
        // case-sensitive first
        if (len === 1 && UPPER_MAPPINGS[seqRaw]) {
          out += UPPER_MAPPINGS[seqRaw][0][0];
          i += 1; matched = true; break;
        }
        if (MAPPINGS[seq]) {
          out += MAPPINGS[seq][0][0];
          i += len; matched = true; break;
        }
      }
      if (!matched) { out += s[i]; i += 1; }
    }
    return out;
  }

  _optionsAt(s, i) {
    // Returns [[consumedLen, geoChar, penalty], ...]
    const opts = [];
    for (let len = Math.min(MAX_SEQ_LEN, s.length - i); len >= 1; len--) {
      const raw = s.slice(i, i + len);
      const lower = raw.toLowerCase();
      if (len === 1) {
        // case-sensitive single-letter conventions
        if (UPPER_MAPPINGS[raw]) {
          for (const [g, p] of UPPER_MAPPINGS[raw]) opts.push([1, g, p]);
        }
        if (MAPPINGS[lower]) {
          for (const [g, p] of MAPPINGS[lower]) opts.push([1, g, p]);
        }
      } else if (MAPPINGS[lower]) {
        for (const [g, p] of MAPPINGS[lower]) opts.push([len, g, p]);
      }
    }
    // dedupe (len,char) keeping min penalty
    const seen = new Map();
    for (const [l, g, p] of opts) {
      const k = l + g;
      if (!seen.has(k) || seen.get(k)[2] > p) seen.set(k, [l, g, p]);
    }
    return [...seen.values()];
  }

  /**
   * Main entry: suggestions for a Latin (or Georgian) token.
   * @returns {Array<{text, score, kind}>} kind: exact | completion | verbatim
   */
  suggest(token, { max = 5, prev = null } = {}) {
    if (!token || token.length === 0) {
      return this.predictNext(prev, max);
    }

    // If the user typed Georgian directly, treat as Georgian prefix.
    if (/^[ა-ჰ]+$/.test(token)) {
      return this._georgianPrefix(token, max);
    }

    // DFS states: map key "pos:nodeId" -> min penalty. Use iterative stack.
    const results = new Map();      // word -> {score, kind}
    const reachedEnds = [];         // [node, penalty] states that consumed all input
    const stack = [[0, this.root, 0]];
    const bestAt = new Map();       // pos -> Map(node -> penalty)
    let steps = 0;
    const MAX_STEPS = 20000;

    while (stack.length && steps < MAX_STEPS) {
      steps++;
      const [pos, node, pen] = stack.pop();
      if (pos === token.length) {
        reachedEnds.push([node, pen]);
        continue;
      }
      for (const [len, g, p] of this._optionsAt(token, pos)) {
        const child = node.children.get(g);
        if (!child) continue;
        const npos = pos + len, npen = pen + p;
        let m = bestAt.get(npos);
        if (!m) { m = new Map(); bestAt.set(npos, m); }
        const prevPen = m.get(child);
        if (prevPen !== undefined && prevPen <= npen) continue;
        m.set(child, npen);
        stack.push([npos, child, npen]);
      }
    }

    // Exact words + completions from reached nodes
    for (const [node, pen] of reachedEnds) {
      if (node.freq > 0) {
        this._addResult(results, this._wordAt(node), node.freq, pen, 'exact', node);
      }
      // completions: collect top words in subtree
      this._collectCompletions(node, pen, results, 4);
    }

    let out = [...results.entries()].map(([text, r]) => ({ text, score: r.score, kind: r.kind }));
    out.sort((a, b) => b.score - a.score);
    out = out.slice(0, max);

    // Verbatim literal conversion as fallback / first-class option
    const lit = this.literal(token);
    if (!out.some(o => o.text === lit)) {
      out.push({ text: lit, score: -1, kind: 'verbatim' });
      if (out.length > max) out.length = max;
    }
    return out;
  }

  _addResult(results, word, freq, penalty, kind, node) {
    const score = Math.log(1 + freq) - penalty * 2.0 - (kind === 'completion' ? node._complCost || 0 : 0);
    const cur = results.get(word);
    if (!cur || cur.score < score) results.set(word, { score, kind });
  }

  _collectCompletions(node, pen, results, maxPerNode) {
    // BFS best-first shallow walk for completions
    const heap = [[node, 0]];
    let found = 0;
    const visited = new Set();
    while (heap.length && found < maxPerNode) {
      heap.sort((a, b) => b[0].best - a[0].best);
      const [n, depth] = heap.shift();
      if (visited.has(n)) continue;
      visited.add(n);
      if (n.freq > 0 && depth > 0) {
        const w = this._wordAt(n);
        const complPenalty = pen + 0.35 * depth;
        const score = Math.log(1 + n.freq) - complPenalty * 2.0;
        const cur = results.get(w);
        if (!cur || cur.score < score) results.set(w, { score, kind: 'completion' });
        found++;
      }
      if (depth < 8) {
        for (const c of n.children.values()) heap.push([c, depth + 1]);
      }
    }
  }

  _georgianPrefix(token, max) {
    let node = this.root;
    for (const ch of token) {
      node = node.children.get(ch);
      if (!node) return [{ text: token, score: 0, kind: 'verbatim' }];
    }
    const results = new Map();
    if (node.freq > 0) results.set(token, { score: Math.log(1 + node.freq), kind: 'exact' });
    this._collectCompletions(node, 0, results, 6);
    let out = [...results.entries()].map(([text, r]) => ({ text, score: r.score, kind: r.kind }));
    out.sort((a, b) => b.score - a.score);
    if (!out.some(o => o.text === token)) out.unshift({ text: token, score: 0, kind: 'verbatim' });
    return out.slice(0, max);
  }

  predictNext(prev, max = 3) {
    if (!prev) return [];
    const list = this.bigrams.get(prev) || [];
    return list.slice(0, max).map(([w, c]) => ({ text: w, score: c, kind: 'prediction' }));
  }

  // Reconstruct word by storing parent pointers lazily is memory-heavy;
  // instead we cache words on terminal nodes at insert time.
  _wordAt(node) { return node._word; }
}

// Patch insert to cache word strings on terminal nodes (small memory cost, big simplicity win)
const _origInsert = Engine.prototype._insert;
Engine.prototype._insert = function (word, freq) {
  let node = this.root;
  for (const ch of word) {
    if (node.best < freq) node.best = freq;
    if (!node.children.has(ch)) node.children.set(ch, new TrieNode());
    node = node.children.get(ch);
  }
  if (node.best < freq) node.best = freq;
  node.freq = freq;
  node._word = word;
};

if (typeof module !== 'undefined') module.exports = { Engine, MAPPINGS };
if (typeof window !== 'undefined') window.GeoIME = { Engine, MAPPINGS };
