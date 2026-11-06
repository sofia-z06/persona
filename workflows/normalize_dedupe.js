// [News] Normaliser + dédupliquer (issue #17)
// Format commun : title, url, source, description, published_at (+ topic)
const MAX_AGE_HOURS = 48;     // ignorer les articles plus vieux
const TITLE_SIMILARITY = 0.8; // 0..1, au-dessus = titres quasi identiques

const now = Date.now();

// Clé d'URL : sans http(s), sans www, sans #, sans paramètres de tracking, sans / final
function urlKey(u) {
  // sans new URL() : pas toujours dispo dans le Code node de n8n
  let s = String(u || '').trim();
  const m = s.match(/^https?:\/\/([^\/?#]+)([^?#]*)(\?[^#]*)?/i);
  if (!m) return null; // URL invalide
  const host = m[1].toLowerCase().replace(/^www\./, '');
  const path = m[2].replace(/\/+$/, '');
  const params = (m[3] || '').replace(/^\?/, '').split('&')
    .filter(p => p && !/^(utm_|xtor|at_|fbclid|gclid)/i.test(p))
    .sort().join('&');
  return host + path + (params ? '?' + params : '');
}

// Titre simplifié : minuscules, sans accents ni ponctuation
function words(t) {
  const s = String(t || '').toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9 ]/g, ' ');
  return new Set(s.split(/\s+/).filter(w => w.length > 2));
}

// Similarité entre deux titres (mots en commun / mots au total)
function similarity(a, b) {
  if (!a.size || !b.size) return 0;
  let common = 0;
  for (const w of a) if (b.has(w)) common++;
  return common / (a.size + b.size - common);
}

function stripHtml(h) {
  return String(h || '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

// 1. Mise au format commun
const articles = $input.all().map(i => {
  const j = i.json;
  const src = (j.source && typeof j.source === 'object') ? j.source.name : j.source;
  const date = new Date(j.isoDate || j.publishedAt || j.pubDate || j.published_at || '');
  return {
    title: stripHtml(j.title),
    url: String(j.link || j.url || '').trim(),
    source: src || 'unknown',
    description: stripHtml(j.contentSnippet || j.description || j.summary).slice(0, 500),
    published_at: isNaN(date.getTime()) ? null : date.toISOString(),
    topic: j.topic || 'international',
  };
});

// 2. Filtrage : URL valide, titre, date de moins de 48h
const recent = articles.filter(a => {
  if (!a.title || !urlKey(a.url)) return false;
  if (!a.published_at) return false;
  const ageH = (now - new Date(a.published_at).getTime()) / 3600000;
  return ageH >= -1 && ageH <= MAX_AGE_HOURS;
});

// 3. Plus récents d'abord, puis dédoublonnage
recent.sort((a, b) => b.published_at.localeCompare(a.published_at));
const seenUrls = new Set();
const kept = [];
for (const a of recent) {
  const key = urlKey(a.url);
  if (seenUrls.has(key)) continue;                       // même URL
  const w = words(a.title);
  if (kept.some(k => similarity(k._w, w) >= TITLE_SIMILARITY)) continue; // titre quasi identique
  seenUrls.add(key);
  kept.push({ ...a, _w: w });
}

return kept.map(({ _w, ...a }) => ({ json: a }));
