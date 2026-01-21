# TODO - Implémentation des pages restantes Space Learn Flutter

## Tâches prioritaires
- [x] Créer fichier sampleBookData.dart avec exemple de données livre
- [x] Corriger BookModel pour utiliser la vraie structure API (prix en int)
- [x] Corriger ajouterLivrePage.dart pour utiliser int.tryParse pour le prix
- [ ] Compléter `statsPage.dart` : Ajouter Scaffold et AppBar pour cohérence
- [ ] Ajouter AppBar à `livrePage.dart`
- [ ] Créer modèles : `BookModel.dart` et `ChapterModel.dart` avec mock data
- [ ] Créer `BookDetailPage.dart` : Page de détails livre (titre, auteur, description, chapitres)
- [ ] Créer `ReadingPage.dart` : Page de lecture chapitre (titre, contenu, navigation)
- [ ] Créer `PurchasePage.dart` : Page d'achat livre (titre, prix, bouton acheter)
- [ ] Mettre à jour navigation : onTap dans livre_card.dart pour aller aux détails appropriés
- [ ] Vérifier cohérence : AppBars et boutons retour dans toutes les pages
- [ ] Tester UI : Navigation fluide, mock data affichée correctement

## Pages à vérifier/améliorer
- [ ] `bibliothequePage.dart` : Mock data, navigation vers détails
- [ ] `recherchePage.dart` : Résultats avec navigation
- [ ] `markeplacePage.dart` : Grille livres avec navigation vers achat
- [ ] `homePageLecteur.dart` : Sections avec onTap vers détails/lecture
- [ ] `homePageAuteur.dart` : Cohérence onglets
- [ ] `ecrirePage.dart` : AppBar déjà présent
- [ ] `teamsPage.dart` : AppBar déjà présent

## Cohérence générale
- [ ] Uniformiser AppBars : Titre, bouton retour, couleur
- [ ] Navigation : Utiliser Navigator.push pour détails
- [ ] Thèmes : Utiliser AppColors et AppTextStyles partout
- [ ] Mock data : Listes statiques pour livres/chapitres

## Tests
- [ ] Vérifier navigation entre pages
- [ ] Affichage mock data
- [ ] Boutons fonctionnels (retour, actions)
