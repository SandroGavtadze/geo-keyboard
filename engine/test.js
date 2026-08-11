// Quick accuracy harness for the transliteration engine.
const fs = require('fs');
const { Engine } = require('./translit.js');

const words = fs.readFileSync(__dirname + '/../data/ka_words_freq.tsv', 'utf8')
  .trim().split('\n').map(l => { const [w, f] = l.split('\t'); return [w, +f]; });
const bigrams = fs.readFileSync(__dirname + '/../data/ka_bigrams.tsv', 'utf8')
  .trim().split('\n').map(l => { const [a, b, c] = l.split('\t'); return [a, b, +c]; });

const t0 = Date.now();
const eng = new Engine(words, bigrams);
console.log(`loaded ${eng.wordCount} words in ${Date.now() - t0}ms\n`);

// [latin input, expected georgian]
const CASES = [
  ['saxlshi', 'სახლში'],
  ['xar', 'ხარ'],
  ['gamarjoba', 'გამარჯობა'],
  ['rogor', 'როგორ'],
  ['ra', 'რა'],
  ['aris', 'არის'],
  ['kargad', 'კარგად'],
  ['madloba', 'მადლობა'],
  ['dzalian', 'ძალიან'],
  ['tbilisshi', 'თბილისში'],
  ['shen', 'შენ'],
  ['chven', 'ჩვენ'],
  ['ojaxi', 'ოჯახი'],
  ['sikvaruli', 'სიყვარული'],
  ['gilocav', 'გილოცავ'],
  ['dges', 'დღეს'],
  ['xval', 'ხვალ'],
  ['gushin', 'გუშინ'],
  ['sadili', 'სადილი'],
  ['wigni', 'წიგნი'],
  ['tsavedit', 'წავედით'],
  ['gogo', 'გოგო'],
  ['bichi', 'ბიჭი'],
  ['qali', 'ქალი'],
  ['kaci', 'კაცი'],
  ['bavshvi', 'ბავშვი'],
  ['deda', 'დედა'],
  ['mama', 'მამა'],
  ['dzma', 'ძმა'],
  ['da', 'და'],
  ['tu', 'თუ'],
  ['ki', 'კი'],
  ['ara', 'არა'],
  ['diax', 'დიახ'],
  ['gmadlobt', 'გმადლობთ'],
  ['ukacravad', 'უკაცრავად'],
  ['sakartvelo', 'საქართველო'],
  ['kartuli', 'ქართული'],
  ['ena', 'ენა'],
  ['tsqali', 'წყალი'],
  ['wyali', 'წყალი'],
  ['puri', 'პური'],
  ['ghvino', 'ღვინო'],
  ['gvino', 'ღვინო'],
  ['tsiteli', 'წითელი'],
  ['lamazi', 'ლამაზი'],
  ['didi', 'დიდი'],
  ['patara', 'პატარა'],
  ['axali', 'ახალი'],
  ['dzveli', 'ძველი'],
  ['modi', 'მოდი'],
  ['tsadi', 'წადი'],
  ['minda', 'მინდა'],
  ['ginda', 'გინდა'],
  ['vici', 'ვიცი'],
  ['ar', 'არ'],
  ['var', 'ვარ'],
  ['iyo', 'იყო'],
  ['ikneba', 'იქნება'],
  ['dღes', 'დღეს'],
  ['gaigebs', 'გაიგებს'],
  ['gagimarjos', 'გაგიმარჯოს'],
  ['nakhvamdis', 'ნახვამდის'],
  ['naxvamdis', 'ნახვამდის'],
  ['tamashi', 'თამაში'],
  ['simghera', 'სიმღერა'],
  ['cekva', 'ცეკვა'],
  ['mze', 'მზე'],
  ['mtvare', 'მთვარე'],
  ['zgva', 'ზღვა'],
  ['zghva', 'ზღვა'],
  ['mta', 'მთა'],
  ['gza', 'გზა'],
  ['manqana', 'მანქანა'],
  ['fuli', 'ფული'],
  ['dro', 'დრო'],
  ['weli', 'წელი'],
  ['tve', 'თვე'],
  ['kvira', 'კვირა'],
  ['dila', 'დილა'],
  ['saghamo', 'საღამო'],
  ['ghame', 'ღამე'],
];

let top1 = 0, top3 = 0, miss = [];
for (const [latin, expected] of CASES) {
  const sugg = eng.suggest(latin, { max: 5 });
  const texts = sugg.map(s => s.text);
  if (texts[0] === expected) top1++;
  if (texts.slice(0, 3).includes(expected)) top3++;
  else miss.push([latin, expected, texts.slice(0, 4).join(' | ')]);
}
console.log(`top-1: ${top1}/${CASES.length} (${(100 * top1 / CASES.length).toFixed(1)}%)`);
console.log(`top-3: ${top3}/${CASES.length} (${(100 * top3 / CASES.length).toFixed(1)}%)`);
if (miss.length) {
  console.log('\nMISSES (not in top-3):');
  for (const [l, e, got] of miss) console.log(`  ${l} -> wanted ${e}, got: ${got}`);
}

// Latency check
const t1 = Date.now();
for (let i = 0; i < 200; i++) eng.suggest('gamarjoba', { max: 5 });
console.log(`\navg suggest latency: ${((Date.now() - t1) / 200).toFixed(2)}ms`);

// Sentence demo
const sentence = 'saxlshi xar';
const out = sentence.split(' ').map(w => (eng.suggest(w, { max: 1 })[0] || {}).text).join(' ');
console.log(`\n"${sentence}" -> "${out}"`);
