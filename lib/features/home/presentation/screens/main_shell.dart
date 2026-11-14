import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_colors.dart';
import '../../../quran/presentation/screens/quran_reader_surahs_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../surahs/presentation/screens/surah_list_screen.dart';

/// The persistent three-destination shell for the application.
///
/// Tafseer, Qur'an, and Settings are separate root screens kept alive by an
/// [IndexedStack], so switching destinations preserves each screen's state
/// without pushing routes. Detail screens continue to open above the shell.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const int tafseerIndex = 0;
  static const int quranIndex = 1;
  static const int settingsIndex = 2;

  static const Key navigationBarKey = Key('main-navigation-bar');
  static const Key tabStackKey = Key('main-tab-stack');
  static const Key tafseerDestinationKey = Key('main-nav-tafseer');
  static const Key quranDestinationKey = Key('main-nav-quran');
  static const Key settingsDestinationKey = Key('main-nav-settings');

  static const List<Widget> _tabs = <Widget>[
    SurahListScreen(),
    QuranReaderSurahsScreen(),
    SettingsScreen(),
  ];

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = MainShell.tafseerIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PopScope(
      canPop: _selectedIndex == MainShell.tafseerIndex,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _selectedIndex == MainShell.tafseerIndex) {
          return;
        }
        setState(() => _selectedIndex = MainShell.tafseerIndex);
      },
      child: Scaffold(
        body: IndexedStack(
          key: MainShell.tabStackKey,
          index: _selectedIndex,
          children: MainShell._tabs,
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: NavigationBar(
            key: MainShell.navigationBarKey,
            selectedIndex: _selectedIndex,
            elevation: 0,
            backgroundColor: colors.surface,
            indicatorColor: colors.gold.withValues(alpha: 0.18),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? colors.goldStrong : colors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              );
            }),
            onDestinationSelected: (index) {
              if (index == _selectedIndex) {
                return;
              }
              setState(() => _selectedIndex = index);
            },
            destinations: [
              NavigationDestination(
                key: MainShell.tafseerDestinationKey,
                icon: Icon(
                  Icons.headphones_rounded,
                  color: colors.textSecondary,
                ),
                selectedIcon: Icon(
                  Icons.headphones_rounded,
                  color: colors.goldStrong,
                ),
                label: 'Tafseer',
              ),
              NavigationDestination(
                key: MainShell.quranDestinationKey,
                icon: Icon(
                  Icons.menu_book_rounded,
                  color: colors.textSecondary,
                ),
                selectedIcon: Icon(
                  Icons.menu_book_rounded,
                  color: colors.goldStrong,
                ),
                label: 'Qur’an',
              ),
              NavigationDestination(
                key: MainShell.settingsDestinationKey,
                icon: Icon(Icons.settings_rounded, color: colors.textSecondary),
                selectedIcon: Icon(
                  Icons.settings_rounded,
                  color: colors.goldStrong,
                ),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
