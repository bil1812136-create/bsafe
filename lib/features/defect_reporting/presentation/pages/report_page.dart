import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bsafe_app/features/defect_reporting/presentation/providers/report_provider.dart';
import 'package:bsafe_app/core/providers/connectivity_provider.dart';
import 'package:bsafe_app/core/providers/navigation_provider.dart';
import 'package:bsafe_app/core/providers/language_provider.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';
import 'package:bsafe_app/shared/widgets/ai_analysis_result.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  XFile? _selectedImage;
  String? _imageBase64;
  bool _isAnalyzing = false;
  bool _isSubmitting = false;
  bool _isScanning = false;
  Map<String, dynamic>? _aiResult;

  String? _aiCategory;
  String? _aiSeverity;
  String? _aiTitle;
  String? _aiDescription;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isScanning = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image != null) {
        await Future.delayed(const Duration(milliseconds: 1500));
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBase64 = base64Encode(bytes);
          _aiResult = null;
          _aiCategory = null;
          _aiSeverity = null;
          _aiTitle = null;
          _aiDescription = null;
          _isScanning = false;
        });
        _analyzeWithAI();
        if (mounted) _showSuccess('✨ AI 分析完成！');
      } else {
        setState(() => _isScanning = false);
      }
    } catch (e) {
      setState(() => _isScanning = false);
      _showError('無法選取圖片: $e');
    }
  }

  void _openCamera() => _pickImage(ImageSource.camera);
  void _openGallery() => _pickImage(ImageSource.gallery);

  Future<void> _analyzeWithAI() async {
    if (_imageBase64 == null) {
      _showError(context.read<LanguageProvider>().t('upload_photo'));
      return;
    }
    setState(() => _isAnalyzing = true);
    try {
      final reportProvider =
          Provider.of<ReportProvider>(context, listen: false);
      final language = Provider.of<LanguageProvider>(context, listen: false);
      final result = await reportProvider.analyzeImage(_imageBase64!);
      if (!mounted) return;
      if (result != null) {
        final damageDetected = result['damage_detected'] == true;
        setState(() {
          _aiResult = result;
          _aiCategory = result['category'] ??
              (damageDetected ? 'structural' : 'inspection');
          _aiSeverity =
              result['severity'] ?? (damageDetected ? 'moderate' : 'mild');
          _aiTitle = result['title'] ??
              (damageDetected
                  ? language.t('building_safety_issue')
                  : language.t('ai_no_obvious_defect'));
          _aiDescription = result['analysis'] ??
              (damageDetected
                  ? language.t('ai_auto_detect_building_damage')
                  : language.t('ai_no_obvious_defect'));
        });
        damageDetected
            ? _showSuccess(language.t('ai_defect_found'))
            : _showSuccess(language.t('ai_no_defect'));
      } else {
        _showError(language.t('ai_invalid_result'));
      }
    } catch (e) {
      if (!mounted) return;
      _showError(
          '${context.read<LanguageProvider>().t('ai_analysis_failed')}$e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _submitReport() async {
    final language = context.read<LanguageProvider>();
    if (_selectedImage == null) {
      _showError(language.t('upload_photo'));
      return;
    }
    if (_aiResult == null) {
      _showError(language.t('wait_ai_analysis'));
      return;
    }
    if (_aiResult!['damage_detected'] != true) {
      _showError(language.t('no_defect_detected'));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final connectivity =
          Provider.of<ConnectivityProvider>(context, listen: false);
      final reportProvider =
          Provider.of<ReportProvider>(context, listen: false);
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);

      final report = await reportProvider.addReport(
        title: _aiTitle ?? language.t('building_safety_issue'),
        description: _aiDescription ?? language.t('ai_auto_detect'),
        category: _aiCategory ?? 'structural',
        severity: _aiSeverity ?? 'moderate',
        imagePath: _selectedImage!.path,
        imageBase64: _imageBase64,
        location: language.t('positioning'),
        isOnline: connectivity.isOnline,
      );

      if (report != null) {
        _resetForm();
        _showSuccess(language.t('submit_success'));
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) navigationProvider.goToHistory();
        });
      }
    } catch (e) {
      _showError('${language.t('submit_failed')}$e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedImage = null;
      _imageBase64 = null;
      _aiResult = null;
      _aiCategory = null;
      _aiSeverity = null;
      _aiTitle = null;
      _aiDescription = null;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message))
      ]),
      backgroundColor: AppTheme.riskHigh,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message))
      ]),
      backgroundColor: AppTheme.riskLow,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_a_photo,
                      size: 60, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(height: 12),
                  Text(language.t('take_building_photo'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(language.t('ai_analyze_category_severity'),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedImage == null)
                    Stack(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: _imageSourceTile(
                                    lang: language,
                                    icon: Icons.camera_alt,
                                    color: AppTheme.primaryColor,
                                    title: language.t('take_photo'),
                                    subtitle: language.t('take_photo_desc'),
                                    onTap: _isScanning ? null : _openCamera)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _imageSourceTile(
                                    lang: language,
                                    icon: Icons.photo_library,
                                    color: Colors.purple,
                                    title: language.t('gallery'),
                                    subtitle: language.t('select_photo_desc'),
                                    onTap: _openGallery)),
                          ],
                        ),
                        if (_isScanning)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(30)),
                              child: Center(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: const BoxDecoration(
                                              color: AppTheme.primaryColor,
                                              shape: BoxShape.circle),
                                          child:
                                              const CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Colors.white))),
                                      const SizedBox(height: 16),
                                      Text(language.t('ai_analyzing'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(language.t('identify_safety_risks'),
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14)),
                                    ]),
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              FutureBuilder<Uint8List>(
                                future: _selectedImage!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(snapshot.data!,
                                        width: double.infinity,
                                        height: 280,
                                        fit: BoxFit.cover);
                                  }
                                  return Container(
                                      width: double.infinity,
                                      height: 280,
                                      color: Colors.grey[300],
                                      child: const Center(
                                          child: CircularProgressIndicator()));
                                },
                              ),
                              if (_isAnalyzing)
                                Positioned.fill(
                                    child: Container(
                                        color: Colors.black54,
                                        child: const Center(
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                              CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.white)),
                                              SizedBox(height: 16),
                                              Dec(text: 'AI 分析中...')
                                            ])))),
                              Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                      decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.white),
                                          onPressed: _isAnalyzing
                                              ? null
                                              : _resetForm))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_isAnalyzing)
                          Row(children: [
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: _openCamera,
                                    icon: const Icon(Icons.camera_alt),
                                    label: Text(language.t('take_photo')),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        side: const BorderSide(
                                            color: AppTheme.primaryColor),
                                        foregroundColor:
                                            AppTheme.primaryColor))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: _openGallery,
                                    icon: const Icon(Icons.photo_library),
                                    label: Text(language.t('gallery')),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        side: const BorderSide(
                                            color: Colors.purple),
                                        foregroundColor: Colors.purple))),
                          ]),
                      ],
                    ),
                  const SizedBox(height: 24),
                  if (_aiResult != null) ...[
                    AIAnalysisResult(result: _aiResult!),
                    const SizedBox(height: 24)
                  ],
                  if (_isAnalyzing)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200)),
                      child: Row(children: [
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor))),
                        const SizedBox(width: 12),
                        Text(language.t('ai_analyzing'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500))
                      ]),
                    ),
                  if (_aiResult != null && !_isAnalyzing) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white)))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  const Icon(Icons.send, size: 20),
                                  const SizedBox(width: 8),
                                  Text(language.t('quick_report'),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold))
                                ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.info_outline,
                                size: 20, color: AppTheme.textSecondary),
                            SizedBox(width: 8),
                            Text('Instructions',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary))
                          ]),
                          const SizedBox(height: 12),
                          _instruction(
                              'Take a clear photo of the building damage'),
                          _instruction(
                              'AI will automatically analyze the issue category and severity'),
                          _instruction(
                              'Confirm the AI analysis results and submit the report'),
                          _instruction(
                              'Location information will be automatically positioned via UWB'),
                        ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageSourceTile(
      {required LanguageProvider lang,
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05)
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color)),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }

  Widget _instruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('• ',
            style: TextStyle(fontSize: 16, color: AppTheme.primaryColor)),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary, height: 1.4))),
      ]),
    );
  }
}

/// Tiny helper widget used inline in the image overlay.
class Dec extends StatelessWidget {
  final String text;
  const Dec({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600));
}
