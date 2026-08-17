import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:space_learn_flutter/core/services/onboarding_guide_service.dart';

/// Système de visite guidée interactive (Coach Marks) inspiré des grandes plateformes
/// (Spotify, Airbnb, Notion, Duolingo) pour Space Learn.
class SpaceLearnTour {
  static TutorialCoachMark? _currentTutorial;

  /// Lance le guide d'accueil interactif
  static void startHomeTour({
    required BuildContext context,
    required GlobalKey searchBarKey,
    GlobalKey? dailyGoalKey,
    GlobalKey? featuredBooksKey,
    GlobalKey? profileKey,
    VoidCallback? onComplete,
  }) {
    // Si un tutoriel est déjà en cours, ne pas en superposer un autre
    if (_currentTutorial != null) return;

    final List<TargetFocus> targets = [];

    // Étape 1 : Barre de Recherche
    if (searchBarKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "search_bar",
          keyTarget: searchBarKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return _buildTourCard(
                  step: 1,
                  totalSteps: 3,
                  title: "Explorez & Recherchez 🔍",
                  description:
                      "Trouvez facilement vos livres favoris, découvrez de nouveaux auteurs et explorez les catégories astronomiques et scientifiques.",
                  controller: controller,
                );
              },
            ),
          ],
        ),
      );
    }

    // Étape 2 : Objectif quotidien / Statistiques
    if (dailyGoalKey != null && dailyGoalKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "daily_goal",
          keyTarget: dailyGoalKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 20,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return _buildTourCard(
                  step: 2,
                  totalSteps: 3,
                  title: "Objectifs & Progression 🎯",
                  description:
                      "Suivez votre temps de lecture chaque jour, progressez dans vos objectifs et débloquez des badges exclusifs !",
                  controller: controller,
                );
              },
            ),
          ],
        ),
      );
    }

    // Étape 3 : Nouveautés & Recommandations
    if (featuredBooksKey != null && featuredBooksKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "featured_books",
          keyTarget: featuredBooksKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return _buildTourCard(
                  step: 3,
                  totalSteps: 3,
                  isLast: true,
                  title: "Nouveautés & Sélection 🚀",
                  description:
                      "Accédez aux derniers ouvrages publiés, commencez une lecture instantanée ou écoutez les livres en mode audio.",
                  controller: controller,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) return;

    _currentTutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF070B19),
      opacityShadow: 0.88,
      paddingFocus: 8,
      hideSkip: true, // Utilisation de notre propre bouton Passer dans la carte
      onFinish: () {
        _currentTutorial = null;
        OnboardingGuideService.markHomeTourCompleted();
        onComplete?.call();
      },
      onSkip: () {
        _currentTutorial = null;
        OnboardingGuideService.markHomeTourCompleted();
        onComplete?.call();
        return true;
      },
    );

    _currentTutorial?.show(context: context);
  }

  /// Construction d'une carte de bulle ultra-soignée (Glassmorphic / Modern Dark UI)
  static Widget _buildTourCard({
    required int step,
    required int totalSteps,
    required String title,
    required String description,
    required TutorialCoachMarkController controller,
    bool isLast = false,
  }) {
    final isDark = AppColors.isDark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16192E) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(
          color: AppColors.purple.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.18),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Badge étape + Bouton Passer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.purple, AppColors.violet],
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                ),
                child: Text(
                  "Étape $step / $totalSteps",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: () => controller.skip(),
                borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    "Passer",
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.white60 : Colors.black45,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Titre
          Text(
            title,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : const Color(0xFF1E1E2E),
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            description,
            style: GoogleFonts.poppins(
              color: isDark ? const Color(0xFFB0B7C3) : const Color(0xFF555B6E),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // Boutons de navigation (Précédent / Suivant)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (step > 1)
                OutlinedButton(
                  onPressed: () => controller.previous(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    "Précédent",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              ElevatedButton(
                onPressed: () {
                  if (isLast) {
                    controller.skip();
                  } else {
                    controller.next();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppColors.purple.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 11,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLast ? "C'est parti ! 🚀" : "Suivant",
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isLast) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
