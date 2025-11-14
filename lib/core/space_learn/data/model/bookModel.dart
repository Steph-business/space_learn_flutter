class BookModel {
  final String id;
  final String title;
  final String author;
  final String description;
  final double price;
  final List<String> chapters; // Liste d'IDs de chapitres
  final String? coverImage;
  final bool isOwned; // Pour différencier bibliothèque vs marketplace

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.price,
    required this.chapters,
    this.coverImage,
    this.isOwned = false,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      chapters: List<String>.from(json['chapters'] ?? []),
      coverImage: json['cover_image'],
      isOwned: json['is_owned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'price': price,
      'chapters': chapters,
      'cover_image': coverImage,
      'is_owned': isOwned,
    };
  }
}

// Mock data pour les livres
class MockBooks {
  static final List<BookModel> ownedBooks = [
    BookModel(
      id: '1',
      title: 'L\'Art de la guerre',
      author: 'Sun Tzu',
      description: 'Un classique sur la stratégie militaire et la philosophie.',
      price: 0.0,
      chapters: ['chap1', 'chap2', 'chap3'],
      isOwned: true,
    ),
    BookModel(
      id: '2',
      title: 'Atomic Habits',
      author: 'James Clear',
      description:
          'Comment construire de bonnes habitudes et se débarrasser des mauvaises.',
      price: 0.0,
      chapters: ['chap4', 'chap5'],
      isOwned: true,
    ),
  ];

  static final List<BookModel> marketplaceBooks = [
    BookModel(
      id: '3',
      title: 'L\'importance des réseaux',
      author: 'Jean Dupont',
      description: 'Guide pour développer son réseau professionnel.',
      price: 12.99,
      chapters: ['chap6', 'chap7'],
    ),
    BookModel(
      id: '4',
      title: 'Créer une entreprise',
      author: 'Alice Martin',
      description: 'Étapes pour lancer sa startup.',
      price: 15.99,
      chapters: ['chap8', 'chap9'],
    ),
    BookModel(
      id: '5',
      title: 'Apprendre Flutter',
      author: 'Sophie K.',
      description: 'Tutoriel complet pour Flutter.',
      price: 10.50,
      chapters: ['chap10'],
    ),
  ];
}
