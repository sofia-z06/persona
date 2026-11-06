// [News] Taguer les articles (mots-clés, 0 token)
// Liste commune : doit être la même que celle acceptée par set_interests
const TAGS = {
  espace:        ['espace', 'nasa', 'esa', 'spacex', 'fusee', 'satellite', 'astronaute', 'lune', 'mars', 'planete', 'galaxie', 'telescope', 'orbite', 'asteroide', 'cosmos', 'artemis'],
  science:       ['science', 'scientifique', 'chercheur', 'etude', 'recherche', 'physique', 'chimie', 'biologie', 'decouverte', 'laboratoire', 'genetique', 'fossile'],
  ia:            ['ia', 'intelligence artificielle', 'chatgpt', 'openai', 'llm', 'machine learning', 'deep learning', 'gemini', 'claude', 'anthropic', 'mistral', 'algorithme', 'robot', 'neurone'],
  tech:          ['tech', 'technologie', 'logiciel', 'smartphone', 'apple', 'google', 'microsoft', 'cybersecurite', 'piratage', 'internet', 'informatique', 'startup', 'puce'],
  international: ['international', 'monde', 'ukraine', 'russie', 'chine', 'etats-unis', 'israel', 'gaza', 'onu', 'otan', 'diplomatie', 'guerre', 'sommet', 'europe'],
  politique:     ['politique', 'election', 'gouvernement', 'president', 'ministre', 'parlement', 'senat', 'assemblee', 'vote', 'parti', 'midterms'],
  economie:      ['economie', 'bourse', 'inflation', 'entreprise', 'marche', 'croissance', 'emploi', 'banque', 'petrole', 'commerce'],
  sante:         ['sante', 'maladie', 'medecin', 'hopital', 'vaccin', 'virus', 'cancer', 'traitement', 'epidemie'],
  environnement: ['climat', 'environnement', 'rechauffement', 'pollution', 'biodiversite', 'energie', 'co2', 'ecologie', 'meteo'],
};

function clean(t) {
  return ' ' + String(t || '').toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9 -]/g, ' ').replace(/\s+/g, ' ') + ' ';
}

return $input.all().map(i => {
  const a = i.json;
  const text = clean(a.title + ' ' + a.title + ' ' + a.description); // titre compte double
  const tags = [];
  for (const [tag, words] of Object.entries(TAGS)) {
    if (words.some(w => text.includes(' ' + w + ' ') || text.includes(' ' + w + 's '))) tags.push(tag);
  }
  // Garantie : au moins un tag (celui du flux d'origine)
  if (!tags.length) tags.push(TAGS[a.topic] ? a.topic : 'international');
  return { json: { ...a, tags } };
});
