import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/services/session_service.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/forgot_password.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/login.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';
import 'package:space_learn_flutter/core/utils/profile_storage.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({super.key});

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.suivreLeTheme(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldBackground
          : const Color.fromARGB(255, 250, 249, 246),
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.accentInk),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Changer le mot de passe",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.accentInk,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sécurisez votre compte",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Votre nouveau mot de passe doit comporter au moins 6 caractères.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            _buildPasswordField(
              controller: _currentController,
              label: "Mot de passe actuel",
              obscureText: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordPage(),
                    ),
                  );
                },
                child: Text(
                  "Mot de passe oublié ?",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _newController,
              label: "Nouveau mot de passe",
              obscureText: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 20),
            _buildPasswordField(
              controller: _confirmController,
              label: "Confirmer le nouveau mot de passe",
              obscureText: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusInner,
                    ),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.onAccent,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        "Mettre à jour le mot de passe",
                        style: GoogleFonts.poppins(
                          color: AppColors.onAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.poppins(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: isDark ? AppColors.textHint : Colors.black54,
        ),
        prefixIcon: Icon(Icons.lock_outline, color: AppColors.accentInk),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.accentInk,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          borderSide: BorderSide(
            color: isDark ? AppColors.textHint : Colors.grey,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInner),
          borderSide: BorderSide(
            color: isDark ? AppColors.textHint : Colors.grey,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;

    final current = _currentController.text.trim();
    final newPass = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      AppNotifications.showSnackBar(
        context,
        message: "Veuillez remplir tous les champs.",
        isError: true,
      );
      return;
    }
    if (newPass != confirm) {
      AppNotifications.showSnackBar(
        context,
        message: "Les mots de passe ne correspondent pas.",
        isError: true,
      );
      return;
    }
    if (newPass.length < 6) {
      AppNotifications.showSnackBar(
        context,
        message: "Le nouveau mot de passe doit contenir au moins 6 caractères.",
        isError: true,
      );
      return;
    }
    if (current == newPass) {
      AppNotifications.showSnackBar(
        context,
        message: "Le nouveau mot de passe doit être différent de l'actuel.",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _authService.changePassword(
        currentPassword: current,
        newPassword: newPass,
      );

      if (success) {
        // Le serveur révoque TOUTES les lignées de rafraîchissement, y
        // compris celle de CET appareil (RevoquerToutesLesSessions, sans
        // exclusion de la session courante). Annoncer un plein succès et
        // laisser continuer programmait donc une éjection « votre session a
        // expiré » dans l'heure, au milieu de n'importe quel écran. On se
        // reconnecte tout de suite avec le nouveau mot de passe — l'écran
        // l'a en main — pour repartir sur une lignée propre.
        final reconnecte = await _seReconnecter(newPass);

        // La purge locale se fait AVANT le test mounted : même si l'écran a
        // été quitté pendant l'attente, une session dont la lignée est
        // révoquée ne doit pas rester dans le coffre.
        if (!reconnecte) {
          await SessionService.terminer();
        }

        if (!mounted) return;

        if (reconnecte) {
          AppNotifications.showPremiumDialog(
            context,
            title: "Mot de passe modifié",
            message:
                "Votre mot de passe a été mis à jour. Par sécurité, vos autres appareils ont été déconnectés ; celui-ci reste connecté.",
            confirmText: "D'accord",
            isSuccess: true,
            onConfirm: () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          );
        } else {
          // La reconnexion silencieuse a échoué : mieux vaut une déconnexion
          // PROPRE et expliquée maintenant qu'une coupure inexpliquée, mise
          // sur le dos d'une « session expirée », dans l'heure qui vient.
          await AppNotifications.showPremiumDialog(
            context,
            title: "Mot de passe modifié",
            message:
                "Votre mot de passe a été mis à jour et, par sécurité, toutes vos sessions ont été fermées. Reconnectez-vous avec votre nouveau mot de passe.",
            confirmText: "Se reconnecter",
            isSuccess: true,
          );

          // Le retour à l'écran de connexion ne dépend PLUS du bouton.
          //
          // Le dialogue s'ouvre avec barrierDismissible : un appui à côté le
          // fermait sans exécuter onConfirm, et l'on restait sur les réglages
          // d'une application qui n'avait plus ni jeton ni profil — jusqu'au
          // premier 401 et son « votre session a expiré », c'est-à-dire
          // exactement la coupure inexpliquée que ce correctif devait
          // supprimer, avancée d'une heure.
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      } else {
        // Même famille de défaut que dans otp.dart : un `if` sans `else` sur
        // une réponse « réussie mais fausse ». `changePassword` ne rend jamais
        // false aujourd'hui — elle lève — mais si cela changeait, l'écran
        // arrêterait son chargeur sans un mot : ni succès, ni erreur, alors
        // que le mot de passe aurait peut-être changé. On lève, le catch
        // affiche.
        throw Exception("Réponse inattendue du serveur.");
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: messageLisible(
            e,
            repli: "Changement de mot de passe impossible.",
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Reconnexion silencieuse après le changement de mot de passe.
  ///
  /// L'adresse vient du SERVEUR d'abord : la révocation ne porte que sur les
  /// lignées de rafraîchissement, le jeton d'accès en main reste valable le
  /// temps de cet appel. L'ordre inverse était dangereux — `saved_email_key`
  /// est une clé D'APPAREIL, pas de compte : sur un téléphone partagé elle
  /// pouvait porter l'adresse de quelqu'un d'autre, et le nouveau mot de passe
  /// partait alors sous cette adresse-là (tentative échouée sur le compte d'un
  /// tiers, décomptée par la limite de /auth/login), pendant que la personne
  /// était éjectée juste après un changement pourtant réussi.
  ///
  /// La clé mémorisée ne sert donc plus que de repli quand le serveur n'a pas
  /// répondu — et elle est désormais écrite par les deux chemins de connexion
  /// puis effacée par SessionService.terminer, ce qui la garde à jour.
  ///
  /// `login()` enregistre les nouveaux jetons : la session repart sur une
  /// lignée de rafraîchissement propre, non révoquée.
  Future<bool> _seReconnecter(String nouveauMotDePasse) async {
    try {
      String? email;
      try {
        final token = await TokenStorage.getToken();
        if (token != null && token.isNotEmpty) {
          email = (await _authService.getUser(token))?.email;
        }
      } catch (e) {
        // Serveur injoignable ou jeton refusé : on tentera le repli local.
        debugPrint('Adresse du compte non résolue par le serveur : $e');
      }
      email ??= await ProfileStorage.getSavedEmail();

      final adresse = email?.trim() ?? '';
      if (adresse.isEmpty) return false;

      await _authService.login(adresse, nouveauMotDePasse);
      // La clé cesse de mentir : c'est bien ce compte-ci qui est connecté sur
      // cet appareil.
      await ProfileStorage.saveSavedEmail(adresse);
      return true;
    } catch (e) {
      debugPrint('Reconnexion après changement de mot de passe : $e');
      return false;
    }
  }
}
