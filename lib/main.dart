import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:provider/provider.dart';

import 'state/desktop_controller.dart';
import 'theme/app_theme.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Windows audio backend for just_audio.
  JustAudioMediaKit.ensureInitialized();

  final controller = DesktopController();
  await controller.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: controller,
      child: const SoundcoreDesktopApp(),
    ),
  );
}

class SoundcoreDesktopApp extends StatelessWidget {
  const SoundcoreDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '安克录音豆 · 桌面转写',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
