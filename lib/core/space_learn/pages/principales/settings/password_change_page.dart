import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_dimensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/utils/app_notifications.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/auth/forgot_password.dart';

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
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
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

      if (!mounted) return;

      if (success) {
        AppNotifications.showPremiumDialog(
          context,
          title: "Mot de passe modifié",
          message:
              "Votre mot de passe a été mis à jour avec succès dans la base de données. Vous pourrez vous connecter avec ce nouveau mot de passe.",
          confirmText: "D'accord",
          isSuccess: true,
          onConfirm: () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showSnackBar(
          context,
          message: e.toString().replaceFirst("Exception: ", ""),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
