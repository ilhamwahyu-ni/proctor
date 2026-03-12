import 'package:flutter/material.dart';

/// A consistent card section wrapper used across screens.
class SectionCard extends StatelessWidget {
  /// Creates a section card.
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  /// Section title.
  final String title;

  /// Optional supporting text.
  final String? subtitle;

  /// Optional trailing widget.
  final Widget? trailing;

  /// Section body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      shadowColor: cs.shadow.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
