import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/discussionModel.dart';

/// Le coeur affiche sur chaque sujet ne bougeait jamais.
///
/// L'interface cherchait le compte sous quatre cles — `likes_count`,
/// `likesCount`, `nb_likes`, `nbr_likes` — dont aucune n'a jamais existe cote
/// serveur. La valeur retombait donc a zero quoi qu'il arrive, et rien ne le
/// signalait : un compteur a zero ressemble a un sujet que personne n'a aime.
void main() {
  Discussion depuis(Map<String, dynamic> json) => Discussion.fromJson({
    'id': 'd1',
    'titre': 'Un sujet',
    ...json,
  });

  test('le compte est lu sous la cle que le serveur envoie', () {
    expect(depuis({'nombre_jaime': 7}).likesCount, 7);
  });

  test('un sujet que personne n\'a aime vaut zero, pas nul', () {
    expect(depuis({}).likesCount, 0);
  });

  test('mon propre etat est lu', () {
    expect(depuis({'aime_par_moi': true}).aimeParMoi, isTrue);
    expect(depuis({'aime_par_moi': false}).aimeParMoi, isFalse);
    // Absent, on ne suppose pas que j'ai aime.
    expect(depuis({}).aimeParMoi, isFalse);
  });

  test('copyWith ne change que ce qu\'on lui donne', () {
    // Recopier les champs a la main a chaque modification est un piege : le
    // jour ou l'on en ajoute un, chaque copie oubliee le perd sans bruit.
    final avant = depuis({
      'nombre_jaime': 3,
      'aime_par_moi': false,
      'categorie': 'Avis de lecture',
      'description': 'une description',
      'nom_utilisateur': 'Awa',
    });

    final apres = avant.copyWith(likesCount: 4, aimeParMoi: true);

    expect(apres.likesCount, 4);
    expect(apres.aimeParMoi, isTrue);
    // Tout le reste survit.
    expect(apres.id, avant.id);
    expect(apres.titre, avant.titre);
    expect(apres.categorie, 'Avis de lecture');
    expect(apres.description, 'une description');
    expect(apres.nomUtilisateur, 'Awa');
  });
}
