import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  // ── Headings ───────────────────────────────────────────────────────────
  static const heading = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.3,
  );

  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

  static const sectionTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  // ── Body ───────────────────────────────────────────────────────────────
  static const body = TextStyle(fontSize: 15, height: 1.4);

  static const bodyCompact = TextStyle(fontSize: 14);

  static const caption = TextStyle(fontSize: 12);

  static const tiny = TextStyle(fontSize: 11);

  static const micro = TextStyle(fontSize: 10);

  // ── Form ───────────────────────────────────────────────────────────────
  static const fieldLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const fieldText = TextStyle(fontSize: 15);

  static const fieldHint = TextStyle(fontSize: 14);

  // ── Buttons ────────────────────────────────────────────────────────────
  static const buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const buttonMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  // ── Numeric / Stats ────────────────────────────────────────────────────
  static const statValue = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

  static const statLabel = TextStyle(fontSize: 12);

  static const ringValue = TextStyle(fontSize: 36, fontWeight: FontWeight.bold);
}
