import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/providers/connectivity_provider.dart';
import 'package:bsafe_app/screens/home_screen.dart';
import 'package:bsafe_app/screens/report_screen.dart';
import 'package:bsafe_app/screens/history_screen.dart';
import 'package:bsafe_app/screens/analysis_screen.dart';
import 'package:bsafe_app/screens/location_screen.dart';
import 'package:bsafe_app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

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
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ReportScreen(),
    const HistoryScreen(),
    const AnalysisScreen(),
    const LocationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);

    return Scaffold(
      appBar: AppBar(
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

                    // 顯示切換提示
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
                              connectivity.isOnline ? '已切換到在線模式' : '已切換到離線模式',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          connectivity.isOnline ? Icons.wifi : Icons.wifi_off,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          connectivity.isOnline ? '在線' : '離線',
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
      ),
      body: Column(
        children: [
          // Offline Banner
          if (!connectivityProvider.isOnline)
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
                          ? '手動離線模式 - 點擊右上角圖標切換'
                          : '離線模式 - 資料將在恢復連線後同步',
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
          Expanded(child: _screens[_currentIndex]),
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
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppTheme.primaryColor,
                unselectedItemColor: Colors.grey.shade400,
                showUnselectedLabels: true,
                selectedFontSize: 12,
                unselectedFontSize: 10,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    activeIcon: Icon(Icons.home_rounded),
                    label: '首頁',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.camera_alt_rounded),
                    activeIcon: Icon(Icons.camera_alt_rounded),
                    label: '上報',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history_rounded),
                    activeIcon: Icon(Icons.history_rounded),
                    label: '記錄',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart_rounded),
                    activeIcon: Icon(Icons.bar_chart_rounded),
                    label: '分析',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.place_rounded),
                    activeIcon: Icon(Icons.place_rounded),
                    label: '位置',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
