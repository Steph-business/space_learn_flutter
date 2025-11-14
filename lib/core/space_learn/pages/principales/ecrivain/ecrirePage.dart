import 'package:flutter/material.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/ecritures/chapitre_en_cours.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/ecritures/nouveau_chapitre.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/ecritures/nouveau_livre.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/ecritures/outils_ecriture_section.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/ecritures/templates.dart';

class EcriturePage extends StatefulWidget {
  const EcriturePage({super.key});

  @override
  State<EcriturePage> createState() => _EcriturePageState();
}

class _EcriturePageState extends State<EcriturePage> {
  String _selectedTool = 'none'; // contrôle du widget affiché

  void _onToolSelected(String tool) {
    setState(() {
      _selectedTool = tool;
    });
  }

  Widget _buildSelectedWidget() {
    switch (_selectedTool) {
      case 'livre':
        return const NouveauLivreWidget();
      case 'chapitre':
        return const NouveauChapitreWidget();
      case 'template':
        return const TemplatesWidget();
      default:
        return const ChapitreEnCours();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.deepPurpleAccent,
        title: const Text(
          "ÉCRITURE",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFF8FAFC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '✍️ Atelier d\'écriture',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Donnez vie à vos idées et créez des histoires extraordinaires',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFBBDEFB),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: const Color(0xFF1976D2),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Astuce : Commencez par définir le thème de votre histoire pour une meilleure cohérence',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF1976D2),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            OutilsEcritureSection(onToolSelected: _onToolSelected),
            const SizedBox(height: 30),
            _buildSelectedWidget(),
          ],
        ),
      ),
    );
  }
}
