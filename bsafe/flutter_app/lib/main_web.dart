import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/services/supabase_service.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:bsafe_app/screens/web/web_dashboard_screen.dart';

/// ══════════════════════════════════════════════════════════
/// B-SAFE Web Dashboard — 公司管理後台
///
/// 使用方式：flutter run -d chrome --target lib/main_web.dart
/// 部署方式：flutter build web --target lib/main_web.dart
/// ══════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseService.isConfigured) {
    await Supabase.initialize(
      url: SupabaseService.supabaseUrl,
      anonKey: SupabaseService.supabaseAnonKey,
    );
    debugPrint('✅ Web Dashboard: Supabase connected');
  }

  runApp(const BSafeWebApp());
}

class BSafeWebApp extends StatelessWidget {
  const BSafeWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B-SAFE Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      ),
      home: const WebDashboardScreen(),
    );
  }
}
