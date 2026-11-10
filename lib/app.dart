import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/surahs/presentation/screens/surah_list_screen.dart';

class TafseerAudioApp extends StatelessWidget {
  const TafseerAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const SurahListScreen(),
    );
  }
}
