import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/relationService.dart';
import 'package:space_learn_flutter/core/space_learn/data/model/relationModel.dart';

class AbonnesPage extends StatefulWidget {
  final String authorId;
  const AbonnesPage({super.key, required this.authorId});

  @override
  State<AbonnesPage> createState() => _AbonnesPageState();
}

class _AbonnesPageState extends State<AbonnesPage> {
  final RelationService _relationService = RelationService();
  List<RelationModel> _followers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final followers = await _relationService.getFollowers(widget.authorId);

      if (mounted) {
        setState(() {
          _followers = followers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Impossible de charger vos abonnés.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "MES ABONNÉS",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
            )
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
              ),
            )
          : _followers.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _followers.length,
              itemBuilder: (context, index) {
                final follower = _followers[index];
                // Note: For now we only have IDs, in a real scenario the API
                // should return user details or we fetch them here.
                return _buildFollowerTile(follower);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            "Vous n'avez pas encore d'abonnés.",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Publiez plus de contenu pour attirer des lecteurs !",
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFollowerTile(RelationModel follower) {
    final name =
        follower.nomComplet ??
        "Lecteur #${follower.utilisateurId.substring(0, 8)}";
    final photo = follower.profilePhoto;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.2),
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? const Icon(Icons.person, color: Color(0xFF0EA5E9))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  follower.creeLe != null
                      ? "Abonné depuis le ${follower.creeLe!.day}/${follower.creeLe!.month}/${follower.creeLe!.year}"
                      : "Abonné récemment",
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              "Profil",
              style: TextStyle(color: Color(0xFF0EA5E9)),
            ),
          ),
        ],
      ),
    );
  }
}
