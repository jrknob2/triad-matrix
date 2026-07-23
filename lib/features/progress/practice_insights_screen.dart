import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';

class PracticeInsightsScreen extends StatelessWidget {
  const PracticeInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DrumScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: <Widget>[
          DrumPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const DrumSectionTitle(text: 'Coming Soon'),
                const SizedBox(height: 12),
                _InsightPlaceholderRow(
                  icon: Icons.timer_outlined,
                  title: 'Practice time',
                  subtitle: 'Weekly and monthly practice totals.',
                ),
                Divider(color: DrumcabularyTheme.edgeBorder),
                _InsightPlaceholderRow(
                  icon: Icons.check_circle_outline,
                  title: 'Exercises completed',
                  subtitle: 'Completed lessons and mastered exercises.',
                ),
                Divider(color: DrumcabularyTheme.edgeBorder),
                _InsightPlaceholderRow(
                  icon: Icons.calendar_today_outlined,
                  title: 'Practice rhythm',
                  subtitle: 'Recent sessions and current consistency.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightPlaceholderRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InsightPlaceholderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, color: DrumcabularyTheme.edgeOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: DrumcabularyTheme.edgeTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DrumcabularyTheme.edgeTextSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
