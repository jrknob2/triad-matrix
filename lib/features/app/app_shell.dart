import 'package:flutter/material.dart';

import '../today/today_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: const TodayScreen(),
    );
  }
}
