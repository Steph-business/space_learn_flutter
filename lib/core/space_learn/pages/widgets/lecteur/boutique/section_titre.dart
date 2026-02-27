import 'package:space_learn_flutter/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.sectionTitleSemiBold,
        ),
        // Icons removed for cleaner look
      ],
    );
  }
}
