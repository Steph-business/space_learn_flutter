/// Prépare un texte de livre pour la lecture à voix haute.
///
/// Le texte brut d'un EPUB ou d'un PDF n'est pas fait pour être dit. Il porte
/// des balises, des entités HTML, des numéros de page, des mots coupés en fin
/// de ligne. Envoyé tel quel au moteur de synthèse, tout cela s'entend : les
/// entités se prononcent, les numéros de page reviennent à chaque tournée, et
/// un mot coupé est dit en deux morceaux.
///
/// Ces fonctions sont pures — pas d'état, pas de plateforme — donc vérifiables
/// une par une.
library;

/// Espaces invisibles à l'œil, écrites en échappement pour qu'on les voie ici.
///
/// Insécable, fine insécable, fine. Elles ressortent en trous dans la diction
/// si on les laisse passer.
const List<String> _espacesInvisibles = ['\u00A0', '\u202F', '\u2009'];

/// Marque interne des fins de paragraphe.
///
/// Nécessaire parce que la préparation du PDF écrase d'abord les retours à la
/// ligne simples : sans marque, le second remplacement effacerait le travail
/// du premier. Ce caractère de contrôle n'apparaît dans aucun livre.
const String _marqueParagraphe = '\u0001';

/// Entités HTML courantes dans les EPUB.
///
/// La liste est courte à dessein : ce sont celles qui apparaissent vraiment
/// dans du texte français. Les autres passent par la règle numérique plus bas.
const Map<String, String> _entites = {
  '&nbsp;': ' ',
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&apos;': "'",
  '&#39;': "'",
  '&laquo;': '«',
  '&raquo;': '»',
  '&hellip;': '…',
  '&mdash;': '—',
  '&ndash;': '–',
  '&rsquo;': '’',
  '&lsquo;': '‘',
  '&eacute;': 'é',
  '&egrave;': 'è',
  '&ecirc;': 'ê',
  '&agrave;': 'à',
  '&ccedil;': 'ç',
  '&ugrave;': 'ù',
  '&ocirc;': 'ô',
  '&icirc;': 'î',
  '&acirc;': 'â',
  '&euml;': 'ë',
  '&iuml;': 'ï',
  '&oelig;': 'œ',
};

/// Transforme le HTML d'un chapitre d'EPUB en texte dicible.
///
/// L'ancienne version faisait `replaceAll(RegExp(r'<[^>]*>'), ' ')` et rien de
/// plus. Trois conséquences s'entendaient : le contenu des balises `<style>` et
/// `<script>` était lu à voix haute comme du texte, les entités restaient
/// telles quelles — « &nbsp; » se prononce —, et les frontières de paragraphes
/// disparaissaient, donc la voix enchaînait sans jamais respirer.
String texteDepuisHtml(String html) {
  if (html.trim().isEmpty) return '';

  var t = html;

  // Ce qui n'est pas destiné au lecteur part avec son contenu.
  t = t.replaceAll(
    RegExp(
      r'<(script|style|head)[^>]*>.*?</\1>',
      caseSensitive: false,
      dotAll: true,
    ),
    ' ',
  );
  t = t.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');

  // Les fins de bloc deviennent des fins de paragraphe. C'est ce qui donnera
  // sa respiration à la lecture : sans elles, un chapitre est une seule phrase
  // de vingt mille caractères.
  t = t.replaceAll(
    RegExp(
      r'</(p|div|h[1-6]|li|blockquote|section|article)>',
      caseSensitive: false,
    ),
    '\n\n',
  );
  t = t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

  // Le reste des balises disparaît sans laisser d'espace au milieu d'un mot :
  // « mot<em>s</em> » doit donner « mots », pas « mot s ».
  t = t.replaceAll(RegExp(r'<[^>]*>'), '');

  t = _decoderEntites(t);
  return _normaliserEspaces(t);
}

/// Prépare le texte extrait d'une page de PDF.
///
/// Les extracteurs rendent la page telle qu'elle est composée : le numéro de
/// page et les mots coupés en fin de ligne s'y trouvent. Dits à voix haute,
/// ils hachent la lecture à chaque page.
String texteDepuisPdf(String brut) {
  if (brut.trim().isEmpty) return '';

  var lignes = brut.split('\n');

  // Une ligne qui ne contient qu'un nombre est un numéro de page. On ne les
  // retire qu'aux extrémités : au milieu d'une page, « 1914 » seul sur sa
  // ligne peut être une date que l'auteur a mise en exergue.
  while (lignes.isNotEmpty && _estNumeroDePage(lignes.first)) {
    lignes = lignes.sublist(1);
  }
  while (lignes.isNotEmpty && _estNumeroDePage(lignes.last)) {
    lignes = lignes.sublist(0, lignes.length - 1);
  }

  var t = lignes.join('\n');

  // Mot coupé en fin de ligne : « com-\nmunauté » se dit en deux morceaux. On
  // ne recolle que devant une minuscule — « Abidjan-\nPort » porte un vrai
  // trait d'union, qu'il faut garder.
  t = t.replaceAllMapped(
    RegExp(r'(\w)[-‐‑]\s*\n\s*([a-zà-öø-ÿ])'),
    (m) => '${m[1]}${m[2]}',
  );

  // Un retour à la ligne simple au milieu d'un paragraphe n'est qu'un effet de
  // mise en page : il devient une espace. Deux retours marquent un vrai
  // paragraphe et doivent survivre au remplacement suivant.
  t = t.replaceAll(RegExp(r'\n{2,}'), _marqueParagraphe);
  t = t.replaceAll('\n', ' ');
  t = t.replaceAll(_marqueParagraphe, '\n\n');

  return _normaliserEspaces(t);
}

/// Découpe un texte en morceaux dicibles d'un seul tenant.
///
/// Le moteur Android refuse au-delà d'une certaine longueur par énoncé, et
/// l'application lui passait une page ou un chapitre entier : la lecture
/// s'arrêtait en cours de route sans rien dire. Découper sert aussi la reprise
/// — on repart du morceau où l'on s'était arrêté, pas du début de la page.
///
/// La coupe cherche d'abord une fin de phrase, puis une virgule ou un
/// point-virgule, puis une espace. Couper en plein mot est le dernier recours :
/// un texte sans aucune espace sur [maxCaracteres] est de toute façon illisible.
List<String> decouperPourLecture(String texte, {int maxCaracteres = 3500}) {
  final propre = _normaliserEspaces(texte);
  if (propre.isEmpty) return const [];
  if (maxCaracteres < 1) return [propre];

  final morceaux = <String>[];
  var reste = propre;

  while (reste.length > maxCaracteres) {
    final fenetre = reste.substring(0, maxCaracteres);
    var coupe = _dernierIndice(fenetre, RegExp(r'[.!?…][\s»")\]]'));
    if (coupe <= 0) coupe = _dernierIndice(fenetre, RegExp(r'[;:,]\s'));
    if (coupe <= 0) coupe = fenetre.lastIndexOf(' ');
    if (coupe <= 0) coupe = maxCaracteres - 1;

    final morceau = reste.substring(0, coupe + 1).trim();
    if (morceau.isNotEmpty) morceaux.add(morceau);
    reste = reste.substring(coupe + 1).trimLeft();
  }

  if (reste.trim().isNotEmpty) morceaux.add(reste.trim());
  return morceaux;
}

/// Position de la dernière occurrence d'un motif, ou -1.
int _dernierIndice(String texte, RegExp motif) {
  int dernier = -1;
  for (final m in motif.allMatches(texte)) {
    dernier = m.start;
  }
  return dernier;
}

bool _estNumeroDePage(String ligne) {
  final l = ligne.trim();
  if (l.isEmpty) return false;
  // « 12 », « - 12 - », « Page 12 », ou une numérotation romaine.
  return RegExp(
        r'^[-–—\s]*(page\s+)?\d{1,4}[-–—\s]*$',
        caseSensitive: false,
      ).hasMatch(l) ||
      RegExp(r'^[ivxlcdm]{1,7}$', caseSensitive: false).hasMatch(l);
}

String _decoderEntites(String texte) {
  var t = texte;
  _entites.forEach((entite, valeur) {
    t = t.replaceAll(entite, valeur);
  });

  // Entités numériques : &#233; et &#xE9;. Sans elles, un EPUB produit par un
  // outil qui encode tous les accents rendrait un texte inaudible.
  t = t.replaceAllMapped(RegExp(r'&#(\d{1,6});'), (m) {
    final code = int.tryParse(m[1]!);
    return code == null ? m[0]! : String.fromCharCode(code);
  });
  t = t.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]{1,5});'), (m) {
    final code = int.tryParse(m[1]!, radix: 16);
    return code == null ? m[0]! : String.fromCharCode(code);
  });

  // Ce qui reste sous la forme « &mot; » n'est pas prononçable : on le retire
  // plutôt que de le laisser se dire.
  t = t.replaceAll(RegExp(r'&[a-zA-Z]{2,10};'), ' ');
  return t;
}

/// Réduit les espaces sans écraser les paragraphes.
String _normaliserEspaces(String texte) {
  var t = texte.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (final invisible in _espacesInvisibles) {
    t = t.replaceAll(invisible, ' ');
  }
  // Espaces et tabulations multiples, sans toucher aux sauts de ligne.
  t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
  t = t.replaceAll(RegExp(r' *\n *'), '\n');
  // Trois sauts ou plus ne valent pas mieux que deux.
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return t.trim();
}
