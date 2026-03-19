import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/providers/connectivity_provider.dart';
import 'package:bsafe_app/providers/navigation_provider.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:bsafe_app/widgets/ai_analysis_result.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  XFile? _selectedImage;
  String? _imageBase64;
  bool _isAnalyzing = false;
  bool _isSubmitting = false;
  bool _isScanning = false;
  // Timer? _scanTimer; // 暫時未使用
  Map<String, dynamic>? _aiResult;

  // AI 分析後的結果
  String? _aiCategory;
  String? _aiSeverity;
  String? _aiTitle;
  String? _aiDescription;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isScanning = true;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear, // 優先使用後置相機
      );

      if (image != null) {
        // 模擬 AI 分析延遲
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

        // 自動觸發 AI 分析
        _analyzeWithAI();

        if (mounted) {
          _showSuccess('✨ AI 分析完成！');
        }
      } else {
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showError('無法選取圖片: $e');
    }
  }

  // 直接打開相機
  void _openCamera() {
    _pickImage(ImageSource.camera);
  }

  // 直接打開相簿
  void _openGallery() {
    _pickImage(ImageSource.gallery);
  }

  Future<void> _analyzeWithAI() async {
    if (_imageBase64 == null) {
      _showError('請先選擇圖片');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final reportProvider =
          Provider.of<ReportProvider>(context, listen: false);

      // 調用 POE API 進行 AI 分析
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
              (damageDetected ? '建築安全問題' : '影像證據不足 / 未檢測到缺陷');
          _aiDescription = result['analysis'] ??
              (damageDetected ? 'AI 自動檢測到建築損壞' : 'AI 未檢測到明顯缺陷，或影像證據不足');
        });

        if (damageDetected) {
          _showSuccess('✅ AI 分析完成（已檢測到問題）');
        } else {
          _showSuccess('ℹ️ AI 分析完成（未檢測到明顯缺陷）');
        }
      } else {
        _showError('AI 未返回有效結果，請重試');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('AI 分析失敗: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _submitReport() async {
    if (_selectedImage == null) {
      _showError('請先上傳照片');
      return;
    }

    if (_aiResult == null) {
      _showError('請等待 AI 分析完成');
      return;
    }

    if (_aiResult!['damage_detected'] != true) {
      _showError('目前結果為「未檢測到明顯缺陷 / 證據不足」，不建議提交問題單');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final connectivity =
          Provider.of<ConnectivityProvider>(context, listen: false);
      final reportProvider =
          Provider.of<ReportProvider>(context, listen: false);
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);

      final report = await reportProvider.addReport(
        title: _aiTitle ?? '建築安全問題',
        description: _aiDescription ?? 'AI 自動檢測',
        category: _aiCategory ?? 'structural',
        severity: _aiSeverity ?? 'moderate',
        imagePath: _selectedImage!.path,
        imageBase64: _imageBase64,
        location: '定位中（UWB）', // 之後會透過 UWB 自動填入
        isOnline: connectivity.isOnline,
      );

      if (report != null) {
        _resetForm();
        _showSuccess('✅ 報告已成功提交！正在跳轉到紀錄頁面...');

        // 等待一下讓用戶看到成功消息，然後自動切換到歷史記錄頁面
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            navigationProvider.goToHistory();
          }
        });
      }
    } catch (e) {
      _showError('提交失敗: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.riskHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.riskLow,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_a_photo,
                    size: 60,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '拍攝建築損壞照片',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI 將自動分析問題類別和嚴重程度',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Preview or Upload Button
                  if (_selectedImage == null)
                    // Upload Buttons - 拍照 & 相簿
                    Stack(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _isScanning ? null : _openCamera,
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        AppTheme.primaryColor
                                            .withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 40,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        '拍照',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '開啟相機',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: _openGallery,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.purple.withValues(alpha: 0.1),
                                        Colors.purple.withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          Colors.purple.withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.purple
                                              .withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.photo_library,
                                          size: 40,
                                          color: Colors.purple,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        '相簿',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '選擇照片',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isScanning)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      '🤖 AI 正在分析環境...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '智能識別安全風險',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    // Image Preview
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
                                    return Image.memory(
                                      snapshot.data!,
                                      width: double.infinity,
                                      height: 280,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return Container(
                                    width: double.infinity,
                                    height: 280,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
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
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'AI 分析中...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.white),
                                    onPressed: _isAnalyzing ? null : _resetForm,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Change Photo Buttons
                        if (!_isAnalyzing)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openCamera,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('重新拍攝'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    side: const BorderSide(
                                        color: AppTheme.primaryColor),
                                    foregroundColor: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openGallery,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('選擇相簿'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    side:
                                        const BorderSide(color: Colors.purple),
                                    foregroundColor: Colors.purple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // AI Analysis Result
                  if (_aiResult != null) ...[
                    AIAnalysisResult(result: _aiResult!),
                    const SizedBox(height: 24),
                  ],

                  // Analysis Status
                  if (_isAnalyzing)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'POE AI 正在分析圖片...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Submit Button
                  if (_aiResult != null && !_isAnalyzing) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '提交報告',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],

                  // Instructions
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 20, color: AppTheme.textSecondary),
                            SizedBox(width: 8),
                            Text(
                              '使用說明',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionItem('1. 拍攝建築損壞部位的清晰照片'),
                        _buildInstructionItem('2. AI 將自動分析問題類別和嚴重程度'),
                        _buildInstructionItem('3. 確認 AI 分析結果後提交報告'),
                        _buildInstructionItem('4. 位置資訊將透過 UWB 自動定位'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(fontSize: 16, color: AppTheme.primaryColor)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
