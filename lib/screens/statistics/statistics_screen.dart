import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/transaction_provider.dart';

const _categoryColors = [
  Color(0xFF2E7D6B), Color(0xFFE94560), Color(0xFF4A6FA5),
  Color(0xFFF4A261), Color(0xFF9B5DE5), Color(0xFF00B4A0),
  Color(0xFFFF6B6B), Color(0xFFFFD166), Color(0xFF6A994E),
  Color(0xFFBC6C25),
];

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: Consumer<TransactionProvider>(
        builder: (context, txProvider, _) {
          if (txProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final hasAnyData = txProvider.last6MonthsTotals
              .any((m) => m.income > 0 || m.expense > 0);

          if (!hasAnyData) {
            return Center(
              child: Text(
                'Aucune donnée disponible',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Revenus vs dépenses (6 mois)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: _MonthlyBarChart(
                  data: txProvider.last6MonthsTotals,
                  currency: currency,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Dépenses par catégorie (ce mois)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (txProvider.categoryBreakdown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Aucune dépense ce mois',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                _CategoryPieChart(
                  data: txProvider.categoryBreakdown,
                  currency: currency,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List data;
  final CurrencyProvider currency;

  const _MonthlyBarChart({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<double>(0, (max, m) {
      final localMax = m.income > m.expense ? m.income : m.expense;
      return localMax > max ? localMax : max;
    });

    return BarChart(
      BarChartData(
        maxY: maxVal == 0 ? 100 : maxVal * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                currency.formatCurrency(rod.toY),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();
                final label = DateFormat('MMM', 'fr_FR').format(data[index].month);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label[0].toUpperCase() + label.substring(1),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          final m = data[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: m.income, color: Colors.green, width: 10,
                  borderRadius: BorderRadius.circular(4)),
              BarChartRodData(toY: m.expense, color: Colors.red, width: 10,
                  borderRadius: BorderRadius.circular(4)),
            ],
          );
        }),
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final Map<String, double> data;
  final CurrencyProvider currency;

  const _CategoryPieChart({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0.0, (sum, v) => sum + v);
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: List.generate(entries.length, (i) {
                final entry = entries[i];
                final percent = (entry.value / total * 100);
                return PieChartSectionData(
                  value: entry.value,
                  color: _categoryColors[i % _categoryColors.length],
                  title: '${percent.toStringAsFixed(0)}%',
                  radius: 60,
                  titleStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(entries.length, (i) {
          final entry = entries[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: _categoryColors[i % _categoryColors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.key)),
                Text(
                  currency.formatCurrency(entry.value),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}