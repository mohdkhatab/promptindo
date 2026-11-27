import 'package:flutter/material.dart';

import '../animation/app_curves.dart';
import '../theme/glass_tokens.dart';

/// The full-screen backdrop every route paints over:
/// dark mode = near-black radial gradient (#0A0A0A → #121212), light mode =
/// iOS system grey (#F5F5F7). Cross-fades over 300ms on theme change (§7).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: AppMotion.themeFade,
      curve: AppMotion.themeCurve,
      decoration: isDark
          ? BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.15,
                colors: [t.backgroundCenter, t.backgroundEdge],
              ),
            )
          : BoxDecoration(color: t.backgroundCenter),
      child: const SizedBox.expand(),
    );
  }
}
