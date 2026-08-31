import 'package:flutter/material.dart';

/// Light palette matching the Figma "Bredar" seller dashboard reference:
/// light-gray page background, white cards, near-black text, soft borders.
///
/// NOTE: token *names* are kept as-is (`white`, `bg`, `greyDark`, ...) even
/// though their values no longer literally match the name, to avoid a
/// 1000+ occurrence rename across the app. Read them by role, not by name:
/// `white` = primary text/icon color, `bg` = page background, etc.
class AppColors {
  // Backgrounds
  static const Color bg       = Color(0xFFFFFFFF); // page background — pure white
  static const Color surface  = Color(0xFFFFFFFF); // card background — same as page bg, so
                                                     // cards rely on border + shadow (below) to
                                                     // read as distinct layers, not on fill color
  static const Color surface2 = Color(0xFFF1F1F3); // secondary surface (icon chips, chips)
  static const Color surface3 = Color(0xFFE3E3E8); // pressed/hover surface

  // Borders & Dividers — darkened from EBEBEF so card edges are visible
  // against a pure-white page background instead of disappearing into it.
  static const Color border  = Color(0xFFD9D9E0);
  static const Color divider = Color(0xFFD9D9E0);

  // Text — role: primary text/icon on light surfaces
  static const Color white    = Color(0xFF000000); // primary text — pure black for max contrast
  static const Color grey     = Color(0xFF52525B); // secondary text — darkened for legibility
  static const Color greyDark = Color(0xFFB4B4BC); // faint/muted (axis labels, low-emphasis icons)

  // Accent — dark primary for seller actions (buttons, active states)
  static const Color accent   = Color(0xFF18181B);

  // Semantic
  static const Color success  = Color(0xFF16A34A);
  static const Color warning  = Color(0xFFD97706);
  static const Color error    = Color(0xFFDC2626);
  static const Color info     = Color(0xFF4F46E5);

  // Chart colors — matches the Figma kit's line/bar/donut accents
  static const List<Color> chartPalette = [
    Color(0xFF818CF8), // indigo — primary line/bar series
    Color(0xFFFBBF24), // amber — secondary bar series
    Color(0xFFA78BFA), // purple — donut "new customer" arc
    Color(0xFFFCA5A5), // pink — donut "returning customer" arc
    Color(0xFF16A34A), // green — success accent
  ];
}
