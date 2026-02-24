import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/revenus.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/statistique.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';

import 'package:space_learn_flutter/core/space_learn/pages/widgets/auteur/accueil/sections_dashboard.dart';

class HomeContentAuteur extends StatelessWidget {
  final String profileId;
  final String userName;

  const HomeContentAuteur({
    super.key,
    required this.profileId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Statistique(),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Revenus(),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AjouterLivrePage(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.white,
                  size: 24,
                ),
                label: Text(
                  "Publier un nouveau livre",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TopLivresSection(),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: CommentairesRecentsSection(),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ConseilsPublicationSection(),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
