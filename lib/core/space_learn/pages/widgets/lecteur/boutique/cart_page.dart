import 'package:space_learn_flutter/core/themes/app_colors.dart';
import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/cart_provider.dart';
import 'package:space_learn_flutter/core/space_learn/pages/widgets/details/payment_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Mon Panier",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: cart.items.isEmpty
          ? _buildEmptyCart(context)
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final book = cart.items[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 70,
                                height: 90,
                                color: AppColors.scaffoldBackground,
                                child:
                                    book.imageCouverture != null &&
                                        book.imageCouverture!.isNotEmpty
                                    ? Image.network(
                                        book.imageCouverture!,
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(
                                        Icons.book,
                                        color: AppColors.textHint,
                                      ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.titre,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    book.authorName,
                                    style: AppTextStyles.withColor(AppTextStyles.body12, AppColors.slateLight),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "${book.prix} FCFA",
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => cart.removeItem(book.id),
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _buildSummary(context, cart),
              ],
            ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AppColors.slateLight,
            ),
          ),
          SizedBox(height: 24),
          Text(
            "Votre panier est vide",
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Explorez la boutique pour y ajouter des livres",
            style: AppTextStyles.withColor(AppTextStyles.body, AppColors.slateLight),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text("Aller à la boutique"),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, CartProvider cart) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total",
                  style: GoogleFonts.poppins(
                    color: AppColors.slateLight,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "${cart.totalPrice.toInt()} FCFA",
                  style: AppTextStyles.pageTitle,
                ),
              ],
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // If we have multiple books, we might need a modified PaymentPage or loop through them
                  // For now, let's take the first one or logic that fits the app
                  if (cart.items.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PaymentPage(book: cart.items.first.toJson()),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Procéder au paiement",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}