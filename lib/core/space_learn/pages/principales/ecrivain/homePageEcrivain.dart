import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../themes/app_colors.dart';

class HomePageEcrivain extends StatelessWidget {
  const HomePageEcrivain({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page Ecrivain'),
      ),
      body: const Center(
        child: Text('Welcome to the Writer Home Page'),
      ),
    );
  }
}
