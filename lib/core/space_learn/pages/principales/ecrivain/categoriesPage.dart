import 'package:flutter/material.dart';
import 'package:space_learn_flutter/core/themes/app_colors.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        title: const Text(
          'Catégories',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          CategoryCard(name: 'Roman', count: 12, color: Colors.blue),
          CategoryCard(name: 'Science-Fiction', count: 8, color: Colors.purple),
          CategoryCard(name: 'Fantasy', count: 5, color: Colors.orange),
          CategoryCard(name: 'Manga', count: 15, color: Colors.red),
          CategoryCard(name: 'Biographie', count: 3, color: Colors.green),
          CategoryCard(
            name: 'Développement Personnel',
            count: 7,
            color: Colors.teal,
          ),
        ],
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String name;
  final int count;
  final Color color;

  const CategoryCard({
    super.key,
    required this.name,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.bookmark, color: color),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count livres',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: () {
          // Navigate to category details
        },
      ),
    );
  }
}
