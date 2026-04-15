import 'package:flutter/material.dart';

class StartupSplashScreen extends StatelessWidget {
  const StartupSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double iconWidth = (constraints.maxWidth * 0.86).clamp(
              320.0,
              620.0,
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image(
                  image: const AssetImage('assets/icons/app_icon_splash.png'),
                  width: iconWidth,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
