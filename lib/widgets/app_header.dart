import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The dark navy header bar shown at the top of every screen, so headers
/// look the same everywhere: an optional back chevron, a title, and
/// optional trailing icon buttons (see [AppHeaderIconButton]).
///
/// Screens place this as the first child of their `body` (not Scaffold's
/// `appBar` slot) so every header handles the safe-area top inset - and
/// looks - exactly the same way.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  final String title;

  /// Shown as a leading back chevron when set - omit on the app's one
  /// root screen (Home).
  final VoidCallback? onBack;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(onBack != null ? 4 : 20, 10, 16, 10),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: onBack,
                ),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              for (final action in actions) ...[
                const SizedBox(width: 8),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small square icon button drawn on [AppHeader]'s navy background -
/// used for every header action (Home's Summary/Manage shortcuts,
/// Container detail's duplicate/empty) so they all match.
class AppHeaderIconButton extends StatelessWidget {
  const AppHeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;

  /// Null disables the button (dimmed, not tappable) - e.g. while a save
  /// is in flight.
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.navyLight,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: onPressed == null ? 0.4 : 1),
            size: 20,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
