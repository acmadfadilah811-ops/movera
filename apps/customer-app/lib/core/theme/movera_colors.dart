import 'package:flutter/material.dart';

/// Palet Movera: gelap netral dengan satu warna aksen.
class MoveraColors {
  MoveraColors._();

  static const bg = Color(0xff0a0a0a);
  static const surface = Color(0xff121212);
  static const card = Color(0xff1a1a1a);
  static const accent = Color(0xff76eb07);
  static const onAccent = Colors.black;
  static const text = Colors.white;
  static const textMuted = Colors.white60;
  static const textFaint = Colors.white38;
  static const danger = Color(0xffff6b6b);
  static const warning = Color(0xffffb84d);

  static Color get border => Colors.white.withValues(alpha: 0.06);
}
