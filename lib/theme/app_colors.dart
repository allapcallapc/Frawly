import 'package:flutter/material.dart';

/// Shared color tokens for the app's redesigned look - a dark navy header
/// bar over a light, card-based body. Kept in one place so the header,
/// id chips, and surfaces used across Home/Summary/etc. stay in sync.
class AppColors {
  const AppColors._();

  /// The dark slate-navy used for header bars and id chips.
  static const navy = Color(0xFF1E293B);

  /// A lighter navy for icon buttons drawn on top of [navy].
  static const navyLight = Color(0xFF334155);

  /// The light gray-blue page background behind white cards.
  static const background = Color(0xFFF1F3F6);

  /// The light gray track behind an unselected segmented control.
  static const segmentTrack = Color(0xFFE7EAEE);
}
