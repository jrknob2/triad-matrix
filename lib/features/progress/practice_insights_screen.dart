import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';

class PracticeInsightsScreen extends StatelessWidget {
  const PracticeInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DrumScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: <Widget>[
          Text(
            'Practice Insights',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A focused view of practice time, consistency, and completed exercises is coming soon.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: DrumcabularyTheme.edgeTextSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
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
                const Divider(color: DrumcabularyTheme.edgeBorder),
                _InsightPlaceholderRow(
                  icon: Icons.check_circle_outline,
                  title: 'Exercises completed',
                  subtitle: 'Completed lessons and mastered exercises.',
                ),
                const Divider(color: DrumcabularyTheme.edgeBorder),
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
                    fontWeight: FontWeight.w900,
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
