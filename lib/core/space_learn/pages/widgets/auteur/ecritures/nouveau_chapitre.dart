import 'package:flutter/material.dart';

class NouveauChapitreWidget extends StatelessWidget {
  const NouveauChapitreWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Nouveau chapitre",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: "Titre du chapitre",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            maxLines: 6,
            decoration: InputDecoration(
              hintText: "Contenu du chapitre...",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Center(
              child: Text("Enregistrer", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
