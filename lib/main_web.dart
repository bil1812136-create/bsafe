import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/infrastructure/supabase_service.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';
import 'package:bsafe_app/features/surveyor_web/presentation/pages/web_dashboard_page.dart';

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
    debugPrint('✅ Web Dashboard: Supabase 已連接');
  }

  runApp(const BSafeWebApp());
}

class BSafeWebApp extends StatelessWidget {
  const BSafeWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B-SAFE 管理後台',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      ),
      home: const WebDashboardScreen(),
    );
  }
}
