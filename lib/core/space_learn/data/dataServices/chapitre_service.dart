import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_client.dart';
import '../../../utils/api_routes.dart';
import '../model/chapitre_model.dart';

class ChapitreService {
  final http.Client client;

  ChapitreService({http.Client? client})
    : client = client ?? ApiClient.instance;

  /// Récupère les chapitres d'un livre depuis le backend.
  Future<List<ChapitreModel>> getChapitres(String livreId) async {
    try {
      final response = await client.get(
        Uri.parse('${ApiRoutes.baseUrlsGin}/api/books/$livreId/chapters'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final data = responseData['data'];
        if (data != null && data is List) {
          return data.map((ch) => ChapitreModel.fromJson(ch)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // `createChapitres` A ÉTÉ RETIRÉE, ET IL FAUT SAVOIR POURQUOI.
  //
  // Elle déposait en bloc les chapitres d'un livre — POST
  // /api/books/:id/chapters — et AUCUN écran ne l'appelait : ni
  // `ajouter_livre_page`, ni la modification d'un livre, ni le lecteur. Rien
  // dans `lib/` ne la nommait, ce qui se vérifie d'un `grep createChapitres`.
  //
  // Ce n'était pas seulement du poids mort. C'est cette méthode-là qui a laissé
  // une borne du serveur inappliquée sans que personne s'en aperçoive : aucun
  // client ne frappait la route, donc rien ne révélait que la validation ne s'y
  // appliquait pas. Une méthode que personne n'appelle donne l'illusion qu'un
  // parcours existe et qu'il est éprouvé ; c'est le piège que cette campagne
  // rencontre partout — un correctif juste, posé là où rien ne l'atteint.
  //
  // Le dépôt de sommaire depuis l'application n'est pas prévu aujourd'hui : les
  // chapitres viennent du fichier déposé, et `getChapitres` juste au-dessus est
  // bien utilisée (book_detail_page). Si ce parcours voit le jour, la méthode
  // se réécrit avec son écran — et surtout en remontant l'échec au lieu de le
  // rendre en liste vide, comme faisait celle-ci.
}
