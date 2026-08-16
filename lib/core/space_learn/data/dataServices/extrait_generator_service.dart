import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Service responsable de la génération automatique d'extraits / aperçus de livres.
///
/// Applique la règle d'or proportionnelle :
/// - < 4 pages : Aucun extrait (pour protéger les œuvres ultra courtes)
/// - 4 à 15 pages : 1 à 2 pages d'aperçu
/// - 16 à 50 pages : 3 à 5 pages d'aperçu
/// - > 50 pages : 10 pages maximum (ou 10% du livre)
class ExtraitGeneratorService {
  /// Calcule le nombre de pages gratuites à extraire selon la taille du livre.
  static int calculerNombrePagesExtrait(int totalPages) {
    if (totalPages < 4) {
      return 0; // Pas d'extrait pour les œuvres très courtes
    }
    if (totalPages <= 7) {
      return 1;
    }
    if (totalPages <= 15) {
      return 2;
    }
    if (totalPages <= 50) {
      return (totalPages * 0.1).round().clamp(2, 5);
    }
    // Plus de 50 pages
    return (totalPages * 0.1).round().clamp(5, 10);
  }

  /// Génère automatiquement un PDF d'extrait à partir des octets du PDF complet.
  ///
  /// Retourne les octets du fichier extrait ou `null` si le livre est trop court
  /// ou si une erreur survient lors du découpage.
  static Future<Uint8List?> genererExtraitPdf({
    String? cheminFichier,
    Uint8List? octets,
  }) async {
    try {
      final Uint8List donneesPdf =
          octets ?? await File(cheminFichier!).readAsBytes();

      if (donneesPdf.isEmpty) return null;

      final PdfDocument inputDoc = PdfDocument(inputBytes: donneesPdf);
      final int totalPages = inputDoc.pages.count;

      final int nbPagesExtrait = calculerNombrePagesExtrait(totalPages);
      if (nbPagesExtrait <= 0) {
        inputDoc.dispose();
        debugPrint(
          "ExtraitGeneratorService: Livre de $totalPages page(s), aucun extrait automatique généré (règle de protection auteur).",
        );
        return null;
      }

      final PdfDocument outputDoc = PdfDocument();

      for (int i = 0; i < nbPagesExtrait && i < totalPages; i++) {
        final PdfPage sourcePage = inputDoc.pages[i];
        final PdfSection section = outputDoc.sections!.add();
        section.pageSettings.size = sourcePage.size;
        section.pageSettings.margins.all = 0;
        final PdfPage targetPage = section.pages.add();

        final PdfTemplate template = sourcePage.createTemplate();
        targetPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          sourcePage.size,
        );
      }

      final List<int> savedBytes = outputDoc.saveSync();
      outputDoc.dispose();
      inputDoc.dispose();

      debugPrint(
        "ExtraitGeneratorService: Extrait de $nbPagesExtrait pages généré avec succès sur $totalPages pages totales.",
      );
      return Uint8List.fromList(savedBytes);
    } catch (e, stack) {
      debugPrint(
        "ExtraitGeneratorService: Échec de la génération automatique d'extrait : $e\n$stack",
      );
      return null;
    }
  }
}
