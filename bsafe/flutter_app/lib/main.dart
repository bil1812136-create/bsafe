import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/providers/connectivity_provider.dart';
import 'package:bsafe_app/providers/inspection_provider.dart';
import 'package:bsafe_app/providers/language_provider.dart';
import 'package:bsafe_app/providers/navigation_provider.dart';
import 'package:bsafe_app/screens/home_screen.dart';
import 'package:bsafe_app/screens/report_screen.dart';
import 'package:bsafe_app/screens/history_screen.dart';
import 'package:bsafe_app/screens/analysis_screen.dart';
import 'package:bsafe_app/screens/inspection_screen.dart';
import 'package:bsafe_app/screens/followup_screen.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:bsafe_app/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Supabase (只有在填入 URL/Key 後才啟用)
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

  runApp(const BSafeApp());
}

class BSafeApp extends StatelessWidget {
  const BSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => InspectionProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: MaterialApp(
        title: 'B-SAFE 建築安全',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainNavigationScreen(),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const ReportScreen(),
    const HistoryScreen(),
    const AnalysisScreen(),
    const FollowUpScreen(),
    const InspectionScreen(), // 位置 tab — 使用現有 UWB 定位功能
  ];

  @override
  Widget build(BuildContext context) {
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final int currentIndex = navigationProvider.currentIndex;
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final reportProvider = Provider.of<ReportProvider>(context);
    final unreadFollowups =
        reportProvider.reports.where((r) => r.hasUnreadCompany).length;

    return Scaffold(
      appBar: currentIndex == 5
          ? null // 位置頁面（InspectionScreen）有自己的 AppBar
          : AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield, size: 24),
                  const SizedBox(width: 8),
                  const Text('B-SAFE'),
                  const SizedBox(width: 12),
                  Consumer<ConnectivityProvider>(
                    builder: (context, connectivity, _) {
                      return GestureDetector(
                        onTap: () {
                          connectivity.toggleManualOfflineMode();
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
                                        ? languageProvider.t('switched_online')
                                        : languageProvider
                                            .t('switched_offline'),
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
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                connectivity.isOnline
                                    ? Icons.wifi
                                    : Icons.wifi_off,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                connectivity.isOnline
                                    ? languageProvider.t('online')
                                    : languageProvider.t('offline'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: languageProvider.t('settings'),
                  icon: const Icon(Icons.settings),
                  onPressed: () =>
                      _showSettingsSheet(context, languageProvider),
                ),
              ],
            ),
      body: Column(
        children: [
          // Offline Banner（位置頁面不顯示，因為它有自己的 UI）
          if (!connectivityProvider.isOnline && currentIndex != 5)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: connectivityProvider.isManualOfflineMode
                  ? Colors.blue.shade700
                  : Colors.orange,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    connectivityProvider.isManualOfflineMode
                        ? Icons.do_not_disturb_on
                        : Icons.wifi_off,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      connectivityProvider.isManualOfflineMode
                          ? languageProvider.t('manual_offline_hint')
                          : languageProvider.t('offline_sync_hint'),
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
          // Main Content
          Expanded(child: _screens[currentIndex]),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: BottomNavigationBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                currentIndex: currentIndex,
                onTap: (index) => navigationProvider.setIndex(index),
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppTheme.primaryColor,
                unselectedItemColor: Colors.grey.shade400,
                showUnselectedLabels: true,
                selectedFontSize: 12,
                unselectedFontSize: 10,
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.home_rounded),
                    activeIcon: const Icon(Icons.home_rounded),
                    label: languageProvider.t('nav_home'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.camera_alt_rounded),
                    activeIcon: const Icon(Icons.camera_alt_rounded),
                    label: languageProvider.t('nav_report'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.history_rounded),
                    activeIcon: const Icon(Icons.history_rounded),
                    label: languageProvider.t('nav_history'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.bar_chart_rounded),
                    activeIcon: const Icon(Icons.bar_chart_rounded),
                    label: languageProvider.t('nav_analysis'),
                  ),
                  BottomNavigationBarItem(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.forum_rounded),
                        if (unreadFollowups > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    activeIcon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.forum_rounded),
                        if (unreadFollowups > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    label: languageProvider.t('nav_followup'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.place_rounded),
                    activeIcon: const Icon(Icons.place_rounded),
                    label: languageProvider.t('nav_location'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(
      BuildContext context, LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.t('settings'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                languageProvider.t('language'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              RadioListTile<AppLanguage>(
                value: AppLanguage.zh,
                groupValue: languageProvider.language,
                onChanged: (value) {
                  if (value == null) return;
                  languageProvider.setLanguage(value);
                },
                title: Text(languageProvider.t('chinese')),
              ),
              RadioListTile<AppLanguage>(
                value: AppLanguage.en,
                groupValue: languageProvider.language,
                onChanged: (value) {
                  if (value == null) return;
                  languageProvider.setLanguage(value);
                },
                title: Text(languageProvider.t('english')),
              ),
            ],
          ),
        );
      },
    );
  }
}
