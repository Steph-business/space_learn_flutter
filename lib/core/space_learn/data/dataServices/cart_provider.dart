import 'package:flutter/foundation.dart';
import '../model/book_model.dart';

class CartProvider extends ChangeNotifier {
  final List<BookModel> _items = [];

  List<BookModel> get items => List.unmodifiable(_items);

  double get totalPrice => _items.fold(
    0,
    (sum, item) => sum + (double.tryParse(item.prix.toString()) ?? 0),
  );

  int get itemCount => _items.length;

  void addItem(BookModel book) {
    if (!_items.any((item) => item.id == book.id)) {
      _items.add(book);
      notifyListeners();
    }
  }

  void removeItem(String bookId) {
    _items.removeWhere((item) => item.id == bookId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  bool isInCart(String bookId) {
    return _items.any((item) => item.id == bookId);
  }
}
