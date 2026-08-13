import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/services/preparation_texte.dart';

/// Ce qu'on envoie au moteur de synthèse est ce qu'on entend.
///
/// L'application lui passait le texte brut : les entités HTML se prononçaient,
/// le contenu des balises `<style>` était lu comme de la prose, les numéros de
/// page revenaient à chaque tournée, et un chapitre entier partait en un seul
/// énoncé — que le moteur Android tronque.
void main() {
  group('EPUB', () {
    test('les balises disparaissent sans couper les mots', () {
      expect(texteDepuisHtml('<p>Un mot<em>s</em> ici.</p>'), 'Un mots ici.');
    });

    test('le contenu des styles et des scripts ne se lit pas', () {
      final html = '''
        <head><title>Chapitre</title></head>
        <style>.p { color: red; font-size: 12px; }</style>
        <script>var x = 1;</script>
        <p>Le vrai texte.</p>
      ''';
      final t = texteDepuisHtml(html);
      expect(t, contains('Le vrai texte.'));
      expect(t, isNot(contains('color')));
      expect(t, isNot(contains('var x')));
      expect(t, isNot(contains('Chapitre')));
    });

    test('les entités se décodent au lieu de se prononcer', () {
      expect(
        texteDepuisHtml(
          '<p>Ma&icirc;tre &amp; l&rsquo;&eacute;l&egrave;ve</p>',
        ),
        'Maître & l’élève',
      );
      // Formes numériques, décimale et hexadécimale.
      expect(texteDepuisHtml('<p>&#233;t&#xE9;</p>'), 'été');
    });

    test('une entité inconnue est retirée, pas dite', () {
      expect(texteDepuisHtml('<p>Avant &zzzz; après</p>'), 'Avant après');
    });

    test('les fins de bloc deviennent des paragraphes', () {
      // Sans elles, la voix enchaîne sans jamais respirer.
      final t = texteDepuisHtml('<p>Premier.</p><p>Second.</p>');
      expect(t, 'Premier.\n\nSecond.');
    });

    test('un chapitre vide ne produit rien', () {
      expect(texteDepuisHtml(''), '');
      expect(texteDepuisHtml('   <p></p>  '), '');
    });
  });

  group('PDF', () {
    test('le numéro de page ne se lit pas', () {
      expect(
        texteDepuisPdf('12\nLe texte de la page.\n- 13 -'),
        'Le texte de la page.',
      );
      expect(texteDepuisPdf('Page 4\nUn texte.'), 'Un texte.');
      expect(texteDepuisPdf('xiv\nUn texte.'), 'Un texte.');
    });

    test('un nombre au milieu de la page reste', () {
      // « 1914 » seul sur sa ligne peut être une date mise en exergue.
      expect(texteDepuisPdf('Avant.\n1914\nAprès.'), 'Avant. 1914 Après.');
    });

    test('un mot coupé en fin de ligne est recollé', () {
      expect(
        texteDepuisPdf('la com-\nmunauté entière'),
        'la communauté entière',
      );
    });

    test('un vrai trait d\'union est conservé', () {
      // Devant une majuscule, le trait d'union appartient au mot.
      expect(texteDepuisPdf('Abidjan-\nPort'), 'Abidjan- Port');
    });

    test('un retour simple devient une espace, un double un paragraphe', () {
      expect(
        texteDepuisPdf('Une phrase\ncoupée par la mise en page.\n\nUn autre.'),
        'Une phrase coupée par la mise en page.\n\nUn autre.',
      );
    });
  });

  group('Découpage', () {
    test('un texte court reste en un seul morceau', () {
      expect(decouperPourLecture('Court.', maxCaracteres: 100), ['Court.']);
    });

    test('aucun morceau ne dépasse la limite', () {
      // C'est la règle qui compte : au-delà, le moteur Android tronque
      // l'énoncé sans rien dire, et la lecture s'arrête en cours de route.
      final long = List.filled(400, 'Une phrase de test.').join(' ');
      final morceaux = decouperPourLecture(long, maxCaracteres: 500);
      expect(morceaux.length, greaterThan(1));
      for (final m in morceaux) {
        expect(m.length, lessThanOrEqualTo(500));
      }
    });

    test('rien ne se perd au découpage', () {
      final long = List.generate(200, (i) => 'Phrase numéro $i.').join(' ');
      final recolle = decouperPourLecture(long, maxCaracteres: 300).join(' ');
      expect(recolle, long);
    });

    test('la coupe tombe sur une fin de phrase quand c\'est possible', () {
      final texte = '${'a' * 90}. ${'b' * 90}. ${'c' * 20}.';
      final morceaux = decouperPourLecture(texte, maxCaracteres: 100);
      expect(morceaux.first, endsWith('.'));
      expect(morceaux.first, isNot(contains('b')));
    });

    test('un mot plus long que la limite ne bloque pas', () {
      // Dernier recours : couper en plein mot plutôt que boucler sans fin.
      final morceaux = decouperPourLecture('x' * 250, maxCaracteres: 100);
      expect(morceaux.length, 3);
      expect(morceaux.join(), 'x' * 250);
    });

    test('un texte vide ne donne aucun morceau', () {
      expect(decouperPourLecture(''), isEmpty);
      expect(decouperPourLecture('   \n  '), isEmpty);
    });
  });
}
