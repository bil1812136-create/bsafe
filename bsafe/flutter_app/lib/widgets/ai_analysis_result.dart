import 'package:flutter/material.dart';
import 'package:bsafe_app/theme/app_theme.dart';

class AIAnalysisResult extends StatelessWidget {
  final Map<String, dynamic> result;

  const AIAnalysisResult({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final riskLevel = result['risk_level'] ?? 'low';
    final riskScore = result['risk_score'] ?? 0;
    final isUrgent = result['is_urgent'] ?? false;
    final analysis = result['analysis'] ?? '';
    final recommendations = result['recommendations'] as List<dynamic>? ?? [];
    final damageTypes = result['damage_types'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getRiskColor(riskLevel).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.getRiskColor(riskLevel).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI 分析結果',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.riskHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '緊急',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Risk Score
          Row(
            children: [
              // Score Circle
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.getRiskColor(riskLevel).withOpacity(0.1),
                  border: Border.all(
                    color: AppTheme.getRiskColor(riskLevel),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$riskScore',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getRiskColor(riskLevel),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '風險評分',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getRiskColor(riskLevel),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AppTheme.getRiskLabel(riskLevel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Detected Damage Types
          if (damageTypes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '檢測到的損壞類型',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: damageTypes.map((type) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    type.toString(),
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Analysis Text
          if (analysis.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '分析說明',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                analysis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],

          // Recommendations
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '處理建議',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...recommendations.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value.toString(),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
