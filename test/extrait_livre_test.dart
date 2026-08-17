import 'package:flutter_test/flutter_test.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/book_model.dart';

/// Le contrat de l'extrait entre le serveur et l'application.
///
/// Le serveur nomme ces champs `fichier_extrait_url` et `nb_pages_extrait`. Le
/// modèle en cherchait quatre autres — `extrait_url`, `extraitUrl`,
/// `extract_url`, `extractUrl` — et jamais ceux-là : ce que le serveur envoyait
/// à chaque réponse, le modèle le perdait à chaque fois, si bien que « ce livre
/// a-t-il un aperçu ? » se répondait toujours par non. Rien ne le signalait,
/// parce que l'écran retombait sur `fichier_url`, que le serveur remplit déjà
/// avec l'extrait pour un lecteur non acheteur.
///
/// Ces tests font échouer la prochaine divergence de nom.
void main() {
  Map<String, dynamic> reponseServeur({
    String? extrait,
    int? nbPages,
    String? fichier,
  }) {
    return {
      'id': 'l1',
      'auteur_id': 'a1',
      'titre': 'Un titre',
      'description': 'Une description.',
      'format': 'PDF',
      'prix': 5000,
      'stock': 0,
      'statut': 'publie',
      if (fichier != null) 'fichier_url': fichier,
      if (extrait != null) 'fichier_extrait_url': extrait,
      if (nbPages != null) 'nb_pages_extrait': nbPages,
    };
  }

  test("le nombre de pages de l'aperçu est lu sous le nom du serveur", () {
    final livre = BookModel.fromJson(
      reponseServeur(extrait: 'l1/manuscript_ab_extrait.pdf', nbPages: 3),
    );

    expect(livre.nbPagesExtrait, 3);
    expect(livre.aUnExtrait, isTrue);
  });

  test("sans extrait, le livre le dit", () {
    final livre = BookModel.fromJson(reponseServeur(fichier: 'l1/complet.pdf'));

    expect(livre.nbPagesExtrait, 0);
    expect(livre.aUnExtrait, isFalse);
  });

  test("le chemin brut de l'extrait n'est pas retenu comme adresse", () {
    // Le serveur ne signe que `fichier_url`. Le chemin de l'extrait voyage
    // brut, sans jeton : le retenir menait à un 400 sur le stockage privé.
    // C'est `nb_pages_extrait` qui porte l'information utile.
    final livre = BookModel.fromJson(
      reponseServeur(extrait: 'l1/manuscript_ab_extrait.pdf', nbPages: 3),
    );

    expect(livre.extraitUrl, isNull);
  });

  test("le nombre de pages survit à un aller-retour JSON", () {
    // La page de lecture reçoit un livre sous forme de Map, pas de BookModel :
    // ce que toJson() omet, l'écran ne le voit jamais. Le drapeau du manuscrit
    // s'est déjà perdu ainsi une fois.
    final livre = BookModel.fromJson(
      reponseServeur(extrait: 'l1/apercu.pdf', nbPages: 5),
    );
    final relu = BookModel.fromJson(livre.toJson());

    expect(relu.nbPagesExtrait, 5);
    expect(relu.aUnExtrait, isTrue);
  });

  test("un nombre de pages transmis en chaîne reste un nombre", () {
    final json = reponseServeur(extrait: 'l1/apercu.pdf');
    json['nb_pages_extrait'] = '4';

    expect(BookModel.fromJson(json).nbPagesExtrait, 4);
  });
}
