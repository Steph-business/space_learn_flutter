import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DailyQuoteSection extends StatelessWidget {
  const DailyQuoteSection({super.key});

  static const List<Map<String, String>> _quotes = [
    {
      'text':
          'Un lecteur vit mille vies avant de mourir. Celui qui ne lit jamais n\'en vit qu\'une seule.',
      'author': 'George R.R. Martin',
    },
    {
      'text':
          'La lecture est pour l\'esprit ce que l\'exercice est pour le corps.',
      'author': 'Joseph Addison',
    },
    {
      'text':
          'Les livres sont des miroirs : on n\'y voit que ce qu\'on y apporte.',
      'author': 'Carlos Ruiz Zafón',
    },
    {
      'text':
          'Une bibliothèque est infinie, et les limites de notre curiosité sont les seules barrières.',
      'author': 'Jorge Luis Borges',
    },
    {
      'text': 'C\'est dans les livres que se trouve la médecine de l\'âme.',
      'author': 'Diodore de Sicile',
    },
    {
      'text':
          'Lire, c\'est boire et manger. L\'esprit qui ne lit pas maigrit comme le corps qui ne mange pas.',
      'author': 'Victor Hugo',
    },
    {
      'text':
          'Les livres sont les abeilles qui portent le pollen d\'un esprit à l\'autre.',
      'author': 'James Russell Lowell',
    },
    {
      'text': 'Un bon livre est un événement dans ma vie.',
      'author': 'Stendhal',
    },
    {
      'text':
          'On ne peut pas lire trop de livres, mais on peut ne pas lire les bons.',
      'author': 'Alexandre Dumas',
    },
    {
      'text':
          'La vraie connaissance est de connaître l\'étendue de son ignorance.',
      'author': 'Confucius',
    },
    {
      'text': 'Ouvrir un livre, c\'est ouvrir une fenêtre sur le monde.',
      'author': 'Proverbe',
    },
    {
      'text':
          'La lecture est une conversation avec les plus grands esprits des siècles passés.',
      'author': 'René Descartes',
    },
  ];

  static const List<List<Color>> _gradients = [
    [AppColors.indigoVeryDark, AppColors.indigoDark],
    [AppColors.violetDark, AppColors.indigoDeep],
    [AppColors.tealDark, AppColors.blueSkyDark],
    [AppColors.amberDark, AppColors.orange],
    [AppColors.pinkDeepDark, AppColors.pinkDark],
    [AppColors.greenDeep, AppColors.success],
  ];

  @override
  Widget build(BuildContext context) {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year))
        .inDays;
    final quote = _quotes[dayOfYear % _quotes.length];
    final gradient = _gradients[dayOfYear % _gradients.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative quote mark
          Positioned(
            top: -10,
            left: -4,
            child: Text(
              '"',
              style: GoogleFonts.merriweather(
                fontSize: 100,
                color: Colors.white.withOpacity(0.08),
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Citation du jour',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Quote text
              Text(
                quote['text']!,
                style: GoogleFonts.merriweather(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.7,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 14),
              // Author
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 2,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    quote['author']!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
