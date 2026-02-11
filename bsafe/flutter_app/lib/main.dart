import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/providers/connectivity_provider.dart';
import 'package:bsafe_app/providers/inspection_provider.dart';
import 'package:bsafe_app/screens/inspection_screen.dart';
import 'package:bsafe_app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
        ChangeNotifierProvider(create: (_) => InspectionProvider()),
      ],
      child: MaterialApp(
        title: 'B-SAFE 建築安全',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const InspectionScreen(),
      ),
    );
  }
}

