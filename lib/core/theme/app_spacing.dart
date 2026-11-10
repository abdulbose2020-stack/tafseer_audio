import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double screenPadding = 20;
  static const double contentMaxWidth = 760;
  static const double cardRadius = 20;

  static const BorderRadius cardBorderRadius = BorderRadius.all(
    Radius.circular(cardRadius),
  );
}
