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
        backgroundColor: Colors.green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "ÉCRIRE",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutilsEcritureSection(onToolSelected: _onToolSelected),
            const SizedBox(height: 25),
            _buildSelectedWidget(),
          ],
        ),
      ),
    );
  }
}
