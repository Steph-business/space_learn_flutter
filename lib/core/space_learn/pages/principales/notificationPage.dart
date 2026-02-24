import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/notification_provider.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';
import '../widgets/auteur/accueil/notification_recent.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFF0F172A)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.45,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF475569), Color(0xFF0F172A)],
              ),
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              "Notifications",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: () async {
                  final token = await TokenStorage.getToken();
                  if (token != null) {
                    context.read<NotificationProvider>().markAllAsRead(token);
                  }
                },
                child: const Text(
                  "Tout lire",
                  style: TextStyle(color: Color(0xFF06B6D4), fontSize: 13),
                ),
              ),
            ],
          ),
          body: const SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [SizedBox(height: 20), RecentNotificationsPage()],
            ),
          ),
        ),
      ],
    );
  }
}
