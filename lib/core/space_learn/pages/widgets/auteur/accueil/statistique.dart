import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authorStatsService.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authServices.dart';
import 'package:space_learn_flutter/core/space_learn/pages/principales/ecrivain/abonnes_page.dart';

class Statistique extends StatefulWidget {
  const Statistique({super.key});

  @override
  State<Statistique> createState() => _StatistiqueState();
}

class _StatistiqueState extends State<Statistique> {
  final AuthorStatsService _authorStatsService = AuthorStatsService();
  final AuthService _authService = AuthService();
  Map<String, dynamic> _stats = {};
  String? _authorId;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        final user = await _authService.getUser(token);
        if (user != null) {
          final data = await _authorStatsService.getAuthorStats(user.id, '30d');
          if (mounted) {
            setState(() {
              _stats = data;
              _authorId = user.id;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading home stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "VENTES",
                  "${_stats['revenue'] ?? 0} €",
                  "+12%",
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_authorId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AbonnesPage(authorId: _authorId!),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Chargement de votre compte..."),
                        ),
                      );
                    }
                  },
                  child: _buildStatCard(
                    "LECTEURS",
                    "${_stats['views'] ?? 0}",
                    "+5%",
                    Icons.people_alt_rounded,
                    const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String growth,
    IconData icon,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              Icon(icon, color: Colors.blueAccent, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.show_chart, color: Colors.greenAccent, size: 14),
              const SizedBox(width: 4),
              Text(
                growth,
                style: GoogleFonts.poppins(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
