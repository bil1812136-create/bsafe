import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/theme/app_theme.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ReportProvider>(
        builder: (context, reportProvider, _) {
          if (reportProvider.isLoading && reportProvider.reports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = reportProvider.statistics;
          final trendData = reportProvider.trendData;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Risk Distribution Pie Chart
                const Text(
                  '📊 風險分佈',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: _buildPieChart(stats),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _LegendItem(
                            color: AppTheme.riskHigh,
                            label: '高風險',
                            value: stats['highRisk'] ?? 0,
                          ),
                          _LegendItem(
                            color: AppTheme.riskMedium,
                            label: '中風險',
                            value: stats['mediumRisk'] ?? 0,
                          ),
                          _LegendItem(
                            color: AppTheme.riskLow,
                            label: '低風險',
                            value: stats['lowRisk'] ?? 0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Trend Line Chart
                const Text(
                  '📈 近7天趨勢',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: _buildLineChart(trendData),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ChartLegend(color: AppTheme.riskHigh, label: '高'),
                          SizedBox(width: 20),
                          _ChartLegend(color: AppTheme.riskMedium, label: '中'),
                          SizedBox(width: 20),
                          _ChartLegend(color: AppTheme.riskLow, label: '低'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Status Bar Chart
                const Text(
                  '📋 處理狀態',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 200,
                    child: _buildBarChart(stats),
                  ),
                ),

                const SizedBox(height: 24),

                // Summary Cards
                const Text(
                  '📌 重點數據',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: '需緊急處理',
                        value: '${stats['urgent'] ?? 0}',
                        icon: Icons.warning_amber_rounded,
                        color: AppTheme.riskHigh,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: '本月新增',
                        value: '${stats['total'] ?? 0}',
                        icon: Icons.add_chart,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: '處理中',
                        value:
                            '${(stats['total'] ?? 0) - (stats['pending'] ?? 0) - (stats['resolved'] ?? 0)}',
                        icon: Icons.autorenew,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: '完成率',
                        value: _calculateCompletionRate(stats),
                        icon: Icons.check_circle,
                        color: AppTheme.riskLow,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  String _calculateCompletionRate(Map<String, dynamic> stats) {
    final total = stats['total'] ?? 0;
    final resolved = stats['resolved'] ?? 0;
    if (total == 0) return '0%';
    return '${((resolved / total) * 100).toStringAsFixed(1)}%';
  }

  Widget _buildPieChart(Map<String, dynamic> stats) {
    final high = (stats['highRisk'] ?? 0).toDouble();
    final medium = (stats['mediumRisk'] ?? 0).toDouble();
    final low = (stats['lowRisk'] ?? 0).toDouble();
    final total = high + medium + low;

    if (total == 0) {
      return const Center(
        child: Text(
          '暫無數據',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            value: high,
            color: AppTheme.riskHigh,
            title:
                high > 0 ? '${(high / total * 100).toStringAsFixed(0)}%' : '',
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            radius: 60,
          ),
          PieChartSectionData(
            value: medium,
            color: AppTheme.riskMedium,
            title: medium > 0
                ? '${(medium / total * 100).toStringAsFixed(0)}%'
                : '',
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            radius: 60,
          ),
          PieChartSectionData(
            value: low,
            color: AppTheme.riskLow,
            title: low > 0 ? '${(low / total * 100).toStringAsFixed(0)}%' : '',
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            radius: 60,
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> trendData) {
    if (trendData.isEmpty) {
      return const Center(
        child: Text(
          '暫無數據',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < trendData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      trendData[index]['date'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // High risk line
          LineChartBarData(
            spots: trendData.asMap().entries.map((e) {
              return FlSpot(
                  e.key.toDouble(), (e.value['high'] ?? 0).toDouble());
            }).toList(),
            color: AppTheme.riskHigh,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.riskHigh.withOpacity(0.1),
            ),
          ),
          // Medium risk line
          LineChartBarData(
            spots: trendData.asMap().entries.map((e) {
              return FlSpot(
                  e.key.toDouble(), (e.value['medium'] ?? 0).toDouble());
            }).toList(),
            color: AppTheme.riskMedium,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.riskMedium.withOpacity(0.1),
            ),
          ),
          // Low risk line
          LineChartBarData(
            spots: trendData.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), (e.value['low'] ?? 0).toDouble());
            }).toList(),
            color: AppTheme.riskLow,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.riskLow.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(Map<String, dynamic> stats) {
    final pending = (stats['pending'] ?? 0).toDouble();
    final inProgress =
        ((stats['total'] ?? 0) - pending - (stats['resolved'] ?? 0)).toDouble();
    final resolved = (stats['resolved'] ?? 0).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY:
            [pending, inProgress, resolved].reduce((a, b) => a > b ? a : b) + 2,
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: pending,
                color: Colors.orange,
                width: 40,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: inProgress,
                color: Colors.blue,
                width: 40,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          ),
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(
                toY: resolved,
                color: AppTheme.riskLow,
                width: 40,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final titles = ['待處理', '處理中', '已解決'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    titles[value.toInt()],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
