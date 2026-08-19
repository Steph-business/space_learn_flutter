import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:space_learn_flutter/core/services/book_cache_service.dart';

/// Le cache local des livres.
///
/// Un livre ouvert une première fois se télécharge ; les suivantes doivent le
/// lire sur l'appareil. Ces tests vérifient la seule chose dont cela dépend :
/// que la clé du fichier en cache soit STABLE d'une ouverture à l'autre.
///
/// L'adresse du manuscrit, elle, ne l'est pas : le serveur la signe pour quinze
/// minutes, donc chaque ouverture reçoit une adresse différente. Si la clé en
/// dépendait, aucun livre ne serait jamais retrouvé.

class _CheminsDeTest extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _CheminsDeTest(this.racine);
  final String racine;

  @override
  Future<String?> getApplicationDocumentsPath() async => racine;
}

/// Une adresse signée telle que le serveur en produit : même objet, jeton
/// différent à chaque demande.
String signee(String objet, String jeton) =>
    'https://uqmydsydlkwxcfcdtsbu.supabase.co/storage/v1/object/sign/'
    'space-learn-storage/$objet?token=$jeton';

/// Les quatre premiers octets d'un PDF : « %PDF ».
Uint8List faussePdf() => Uint8List.fromList([
  0x25,
  0x50,
  0x44,
  0x46,
  0x2D,
  0x31,
  0x2E,
  0x37,
  0x0A,
  0x25,
]);

void main() {
  late Directory racine;
  late BookCacheService cache;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    racine = await Directory.systemTemp.createTemp('cache_livre_test');
    PathProviderPlatform.instance = _CheminsDeTest(racine.path);
    cache = BookCacheService();
    await cache.clearAllCache();
  });

  tearDown(() async {
    if (await racine.exists()) await racine.delete(recursive: true);
  });

  /// Dépose un fichier dans le cache comme le ferait un téléchargement.
  ///
  /// Les aperçus vont dans leur sous-dossier, exactement comme le service les
  /// y range : le test doit refléter l'organisation réelle, sinon il ne
  /// vérifie que lui-même.
  Future<File> deposer(
    String bookId,
    String url,
    Uint8List octets, {
    bool extrait = false,
  }) async {
    var chemin = '${racine.path}/cached_books';
    if (extrait) chemin = '$chemin/extraits';
    final dossier = Directory(chemin);
    await dossier.create(recursive: true);
    final ext = url.toLowerCase().contains('.epub') ? '.epub' : '.pdf';
    final f = File('${dossier.path}/$bookId$ext');
    await f.writeAsBytes(octets);
    return f;
  }

  group('Un livre déjà téléchargé est retrouvé', () {
    const id = 'a1b2c3d4-0000-0000-0000-000000000001';

    test('à la même adresse', () async {
      final url = signee('manuscrits/livre.pdf', 'jeton-1');
      await deposer(id, url, faussePdf());

      expect(await cache.isBookCached(id, url), isTrue);
      expect(await cache.getCachedBookBytes(id, url), isNotNull);
    });

    /// LE point qui compte. L'adresse est signée pour quinze minutes : la
    /// seconde ouverture en reçoit forcément une autre. Si la clé du cache en
    /// dépendait, chaque ouverture retéléchargerait le livre entier.
    test('à une adresse re-signée entre-temps', () async {
      final premiere = signee('manuscrits/livre.pdf', 'jeton-1');
      await deposer(id, premiere, faussePdf());

      final seconde = signee('manuscrits/livre.pdf', 'jeton-2-tout-autre');
      expect(
        await cache.isBookCached(id, seconde),
        isTrue,
        reason: 'le livre est retéléchargé à chaque ouverture',
      );
      expect(await cache.getCachedBookBytes(id, seconde), isNotNull);
    });

    test('même si le serveur change de seau ou de chemin', () async {
      await deposer(id, signee('manuscrits/v1/livre.pdf', 'j1'), faussePdf());

      final autre = signee('manuscrits/v2/livre-renomme.pdf', 'j2');
      expect(await cache.isBookCached(id, autre), isTrue);
    });
  });

  group("L'extension de l'adresse ne décide de rien", () {
    const id = 'a1b2c3d4-0000-0000-0000-000000000004';

    /// Le serveur ne signe pas toujours un chemin qui porte le nom du fichier.
    /// Quand il n'en porte pas, le service retombait sur « .pdf » par défaut :
    /// un EPUB déposé sous `<id>.epub` était cherché sous `<id>.pdf`, donc
    /// jamais trouvé, donc retéléchargé à chaque ouverture — sans le moindre
    /// signal, le cache répondant simplement « absent ».
    test('un EPUB est retrouvé depuis une adresse sans extension', () async {
      await deposer(id, signee('manuscrits/livre.epub', 'j1'), faussePdf());

      final sansExtension = signee('objets/9f3c-a1', 'j2');
      expect(
        await cache.isBookCached(id, sansExtension),
        isTrue,
        reason: 'le livre est retéléchargé à chaque ouverture',
      );
      expect(await cache.getCachedBookBytes(id, sansExtension), isNotNull);
    });

    /// Et l'inverse : un PDF cherché depuis une adresse qui annonce un EPUB.
    test('un PDF est retrouvé depuis une adresse .epub', () async {
      await deposer(id, signee('manuscrits/livre.pdf', 'j1'), faussePdf());

      final autre = signee('manuscrits/livre.epub', 'j2');
      expect(await cache.isBookCached(id, autre), isTrue);
      expect(await cache.getCachedBookBytes(id, autre), isNotNull);
    });

    /// La suppression suit la même règle, sinon l'écran « Téléchargements »
    /// annoncerait un retrait sans rien effacer.
    test(
      "la suppression trouve le fichier quelle que soit l'extension",
      () async {
        final f = await deposer(id, signee('m/l.epub', 'j1'), faussePdf());

        await cache.clearBookCache(id, signee('objets/9f3c-a1', 'j2'));
        expect(f.existsSync(), isFalse);
      },
    );

    /// La souplesse sur l'extension ne doit pas rouvrir la confusion que le
    /// sous-dossier a fermée : un aperçu reste un aperçu.
    test("un aperçu n'est pas servi à la place du manuscrit", () async {
      await deposer(
        id,
        signee('extraits/l.epub', 'j1'),
        faussePdf(),
        extrait: true,
      );

      expect(await cache.isBookCached(id, signee('objets/x', 'j2')), isFalse);
    });
  });

  group('Ce qui n\'est pas un livre est écarté', () {
    const id = 'a1b2c3d4-0000-0000-0000-000000000002';

    /// Une page d'erreur enregistrée à la place du manuscrit : on l'efface,
    /// sans quoi le lecteur ouvrirait du HTML.
    test('un fichier corrompu est supprimé et redemandé', () async {
      final url = signee('manuscrits/livre.pdf', 'j1');
      final f = await deposer(
        id,
        url,
        Uint8List.fromList('<!DOCTYPE html>'.codeUnits),
      );

      expect(await cache.getCachedBookBytes(id, url), isNull);
      expect(
        f.existsSync(),
        isFalse,
        reason: 'le fichier invalide reste en place et sera relu indéfiniment',
      );
    });

    test('un fichier tronqué aussi', () async {
      final url = signee('manuscrits/livre.pdf', 'j1');
      await deposer(id, url, Uint8List.fromList([0x25, 0x50]));
      expect(await cache.getCachedBookBytes(id, url), isNull);
    });
  });

  /// Un PDF valide dont l'en-tête ne commence pas au tout premier octet.
  ///
  /// La signature était exigée à l'offset 0. Or certains outils produisent des
  /// PDF précédés d'une ligne vide ou d'un BOM UTF-8, et les visionneuses les
  /// ouvrent sans broncher. Le cache, lui, les jetait à chaque relecture : le
  /// livre s'affichait donc parfaitement ET se retéléchargeait à chaque
  /// ouverture, sans que rien ne le signale.
  group('Un PDF précédé de quelques octets reste un PDF', () {
    const id = 'a1b2c3d4-0000-0000-0000-000000000005';

    Uint8List avecPrefixe(List<int> prefixe) =>
        Uint8List.fromList([...prefixe, ...faussePdf()]);

    test('un BOM UTF-8 ne fait pas jeter le fichier', () async {
      final url = signee('manuscrits/livre.pdf', 'j1');
      final f = await deposer(id, url, avecPrefixe([0xEF, 0xBB, 0xBF]));

      expect(await cache.getCachedBookBytes(id, url), isNotNull);
      expect(
        f.existsSync(),
        isTrue,
        reason: 'le livre repartirait en téléchargement à chaque ouverture',
      );
    });

    test('une ligne vide non plus', () async {
      final url = signee('manuscrits/livre.pdf', 'j1');
      await deposer(id, url, avecPrefixe([0x0D, 0x0A]));
      expect(await cache.getCachedBookBytes(id, url), isNotNull);
    });

    /// La tolérance s'arrête aux premiers octets : au-delà, ce n'est plus un
    /// en-tête mais un fichier qui contient « %PDF » par hasard.
    test('mais pas une signature perdue au milieu du fichier', () async {
      final url = signee('manuscrits/livre.pdf', 'j1');
      await deposer(id, url, avecPrefixe(List<int>.filled(2048, 0x41)));
      expect(await cache.getCachedBookBytes(id, url), isNull);
    });
  });

  group('L\'extrait et le manuscrit ne se confondent pas', () {
    const id = 'a1b2c3d4-0000-0000-0000-000000000003';

    /// Les deux documents appartiennent au MÊME livre, donc au même
    /// identifiant. S'ils partagent la même entrée de cache, l'un sert à la
    /// place de l'autre : un lecteur qui a lu l'aperçu puis acheté l'ouvrage
    /// se voit resservir les deux pages de l'aperçu, définitivement — le cache
    /// n'expire pas.
    test('lire l\'aperçu ne remplace pas le manuscrit acheté', () async {
      final urlExtrait = signee('extraits/livre.pdf', 'j1');
      await deposer(id, urlExtrait, faussePdf(), extrait: true);

      // Le lecteur achète, puis ouvre le manuscrit complet.
      final urlManuscrit = signee('manuscrits/livre.pdf', 'j2');

      expect(
        await cache.isBookCached(id, urlManuscrit),
        isFalse,
        reason: 'l\'aperçu est resservi à la place du livre acheté',
      );
      expect(await cache.getCachedBookBytes(id, urlManuscrit), isNull);
    });

    /// Et dans l'autre sens : posséder le livre ne doit pas faire passer le
    /// manuscrit entier pour un aperçu gratuit.
    test('avoir le manuscrit ne tient pas lieu d\'aperçu', () async {
      await deposer(id, signee('manuscrits/livre.pdf', 'j1'), faussePdf());

      final urlExtrait = signee('extraits/livre.pdf', 'j2');
      expect(
        await cache.isBookCached(id, urlExtrait, extrait: true),
        isFalse,
        reason: 'le manuscrit complet serait servi comme aperçu',
      );
    });

    /// Chacun garde le sien, et les deux coexistent.
    test('les deux vivent côte à côte', () async {
      await deposer(id, signee('manuscrits/l.pdf', 'j1'), faussePdf());
      await deposer(
        id,
        signee('extraits/l.pdf', 'j2'),
        faussePdf(),
        extrait: true,
      );

      expect(await cache.isBookCached(id, signee('m/l.pdf', 'j3')), isTrue);
      expect(
        await cache.isBookCached(id, signee('e/l.pdf', 'j4'), extrait: true),
        isTrue,
      );
    });

    /// L'écran « Téléchargements » ne liste que les livres réellement acquis :
    /// un aperçu de deux pages n'y a pas sa place, et son identifiant y
    /// apparaîtrait comme un doublon du livre.
    test('les aperçus n\'apparaissent pas dans les téléchargements', () async {
      await deposer(
        id,
        signee('extraits/l.pdf', 'j1'),
        faussePdf(),
        extrait: true,
      );

      expect(await cache.listerCache(), isEmpty);

      await deposer(id, signee('manuscrits/l.pdf', 'j2'), faussePdf());
      final liste = await cache.listerCache();
      expect(liste.length, 1);
      expect(liste.first.livreId, id);
    });
  });
}
