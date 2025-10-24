import 'package:flutter/material.dart';
import '../../../../../themes/app_colors.dart';

class RecommendationsSection extends StatelessWidget {
  const RecommendationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _buildRecommendationCard(index),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(int index) {
    final colors = [
      AppColors.secondary,
      const Color(0xFF9C27B0),
      const Color(0xFFFF9800),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
    ];
    final titles = [
      'Innovation Thinking',
      'Choisir ta voix',
      'Leadership Essentials',
      'Creative Writing',
      'Digital Marketing',
    ];
    final authors = [
      'Sarah Jones',
      'Steph N',
      'Mike Chen',
      'Anna Lee',
      'David Kim',
    ];
    final icons = [
      Icons.lightbulb_outline,
      Icons.flag_outlined,
      Icons.leaderboard,
      Icons.edit,
      Icons.trending_up,
    ];

    final color = colors[index % colors.length];
    final title = titles[index % titles.length];
    final author = authors[index % authors.length];
    final icon = icons[index % icons.length];

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to book details
        print('Tapped on $title');
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book cover placeholder
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: color,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      author,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
