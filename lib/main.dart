import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/core/providers/connectivity_provider.dart';
import 'package:bsafe_app/core/providers/language_provider.dart';
import 'package:bsafe_app/core/providers/navigation_provider.dart';
import 'package:bsafe_app/features/home/presentation/pages/home_page.dart';
import 'package:bsafe_app/features/defect_reporting/presentation/pages/report_page.dart';
import 'package:bsafe_app/features/defect_reporting/presentation/pages/history_page.dart';
import 'package:bsafe_app/features/uwb_positioning/presentation/pages/location_page.dart';
import 'package:bsafe_app/features/settings/presentation/pages/settings_page.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';
import 'package:bsafe_app/infrastructure/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  if (SupabaseService.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseService.supabaseUrl,
        anonKey: SupabaseService.supabaseAnonKey,
      );
      debugPrint('✅ Supabase 雲端已連接');
    } catch (e) {
      debugPrint('⚠️ Supabase 初始化失敗（離線模式）: $e');
    }
  } else {
    debugPrint('ℹ️ Supabase 未設定，使用純本地模式');
  }

  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: const BSafeApp(),
    ),
  );
}

class BSafeApp extends ConsumerWidget {
  const BSafeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageNotifierProvider);
    return MaterialApp(
      title: 'B-SAFE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: lang.locale,
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const LocationScreen(),
    const ReportPage(),
    const HistoryPage(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navigation = ref.watch(navigationNotifierProvider);
    final language = ref.watch(languageNotifierProvider);
    final int currentIndex = navigation.currentIndex;
    final connectivity = ref.watch(connectivityNotifierProvider);

    return Scaffold(
      appBar: currentIndex == 1 || currentIndex == 4
          ? null
          : AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield, size: 24),
                  const SizedBox(width: 8),
                  const Text('B-SAFE 建築安全'),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(connectivityNotifierProvider.notifier)
                          .toggleManualOfflineMode();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                connectivity.isOnline
                                    ? Icons.wifi
                                    : Icons.wifi_off,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                connectivity.isOnline
                                    ? language.t('switched_online')
                                    : language.t('switched_offline'),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: connectivity.isOnline
                              ? Colors.green
                              : Colors.orange,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: connectivity.isOnline
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            connectivity.isOnline ? Icons.wifi : Icons.wifi_off,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            connectivity.isOnline
                                ? language.t('online')
                                : language.t('offline'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: Column(
        children: [
          if (!connectivity.isOnline && currentIndex != 1 && currentIndex != 4)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: connectivity.isManualOfflineMode
                  ? Colors.blue.shade700
                  : Colors.orange,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    connectivity.isManualOfflineMode
                        ? Icons.do_not_disturb_on
                        : Icons.wifi_off,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      connectivity.isManualOfflineMode
                          ? language.t('manual_offline_hint')
                          : language.t('offline_sync_hint'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _screens[currentIndex]),
        ],
      ),
      extendBody: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            ref.read(navigationNotifierProvider.notifier).setIndex(2),
        backgroundColor: AppTheme.primaryColor,
        elevation: 6,
        shape: const CircleBorder(),
        child: Icon(
          Icons.camera_alt_rounded,
          color: Colors.white,
          size: 28,
          shadows: currentIndex == 2
              ? [const Shadow(color: Colors.white54, blurRadius: 8)]
              : null,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppTheme.primaryColor,
        elevation: 8,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                  0, Icons.home_rounded, language.t('nav_home'), currentIndex),
              _buildNavItem(1, Icons.place_rounded, language.t('nav_location'),
                  currentIndex),
              const SizedBox(width: 56),
              _buildNavItem(3, Icons.history_rounded, language.t('nav_history'),
                  currentIndex),
              _buildNavItem(4, Icons.settings_rounded, language.t('settings'),
                  currentIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, String label, int currentIndex) {
    final selected = currentIndex == index;
    final color = selected ? Colors.white : Colors.white60;
    return Expanded(
      child: InkWell(
        onTap: () =>
            ref.read(navigationNotifierProvider.notifier).setIndex(index),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
