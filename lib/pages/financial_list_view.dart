import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import '../core/services/finance_service.dart';
import '../core/services/pdf_service.dart';
import '../widgets/glass_container.dart';

class FinancialListView extends StatefulWidget {
  const FinancialListView({super.key});

  @override
  State<FinancialListView> createState() => _FinancialListViewState();
}

class _FinancialListViewState extends State<FinancialListView> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = DateFormat('MMMM', 'pt_BR').format(now);

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirebaseCollections.alunos)
            .where('role', isEqualTo: 'aluno')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao buscar dados financeiros.'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
          }

          final allDocs = snapshot.data?.docs ?? [];
          final summary = FinanceService.calculateSummaryFromDocs(allDocs);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, summary),
                const SizedBox(height: 32),
                _buildKPIRow(summary, currentMonth),
                const SizedBox(height: 32),
                _buildMainAnalysisRow(summary),
                const SizedBox(height: 32),
                _buildBottomActionRow(summary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FinanceSummary summary) {
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O COFRE',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textWhite,
                      letterSpacing: 2,
                      fontSize: 24,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'VISÃO GERAL FINANCEIRA',
                style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ],
          ),
          IconButton.filled(
            onPressed: () => PdfService.generateFinancialReport(summary),
            icon: const Icon(LucideIcons.fileText, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.cardDarkGrey,
              foregroundColor: AppTheme.accentGold,
              side: const BorderSide(color: AppTheme.glassBorder),
            ),
            tooltip: 'Exportar PDF',
          ),
        ],
      ),
    );
  }

  Widget _buildKPIRow(FinanceSummary summary, String month) {
    return Row(
      children: [
        Expanded(child: _buildKPICard('RECEBIDO ($month)', 'R\$ ${summary.totalRecebido.toStringAsFixed(2)}', Colors.greenAccent, '+5% vs. Abr', sparklineColor: AppTheme.accentGold)),
        const SizedBox(width: 16),
        Expanded(child: _buildKPICard('PENDENTE (Vencido)', 'R\$ ${summary.totalPendente.toStringAsFixed(2)}', Colors.redAccent, '-2%', sparklineColor: Colors.redAccent)),
        const SizedBox(width: 16),
        Expanded(child: _buildKPICard('ADIMPLÊNCIA', '${summary.adimplenciaRate.toStringAsFixed(1)}%', Colors.blueAccent, 'Estável', showProgress: true, progress: summary.adimplenciaRate / 100)),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, Color color, String trend, {Color? sparklineColor, bool showProgress = false, double progress = 0}) {
    return FadeInLeft(
      duration: const Duration(milliseconds: 600),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            if (sparklineColor != null)
              Positioned(
                bottom: 0,
                right: 0,
                left: 0,
                child: SizedBox(
                  height: 30,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [const FlSpot(0, 1), const FlSpot(1, 1.5), const FlSpot(2, 1.2), const FlSpot(3, 2), const FlSpot(4, 1.8), const FlSpot(5, 2.5)],
                          isCurved: true,
                          color: sparklineColor.withValues(alpha: 0.2),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.textGrey, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(trend, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                if (showProgress) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 3,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainAnalysisRow(FinanceSummary summary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: _buildTrendChart()),
        const SizedBox(width: 24),
        Expanded(flex: 4, child: _buildCategoryDonut(summary)),
      ],
    );
  }

  Widget _buildTrendChart() {
    return FadeInUp(
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TENDÊNCIA DE CAIXA TRIMESTRAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                Row(
                  children: [
                    _buildSmallLegend('Receita', AppTheme.accentGold),
                    const SizedBox(width: 12),
                    _buildSmallLegend('Vencido', Colors.redAccent),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) => Text('R\$ ${v.toInt()}k', style: const TextStyle(color: AppTheme.textGrey, fontSize: 9)),
                        reservedSize: 35,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) {
                          const labels = ['ABR', 'MAI', 'JUN'];
                          if (v >= 0 && v < 3) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(labels[v.toInt()], style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)));
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [const FlSpot(0, 15), const FlSpot(1, 28), const FlSpot(2, 22)],
                      isCurved: true,
                      color: AppTheme.accentGold,
                      barWidth: 4,
                      belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AppTheme.accentGold.withValues(alpha: 0.2), AppTheme.accentGold.withValues(alpha: 0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: [const FlSpot(0, 5), const FlSpot(1, 8), const FlSpot(2, 4)],
                      isCurved: true,
                      color: Colors.redAccent,
                      barWidth: 3,
                      belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Colors.redAccent.withValues(alpha: 0.1), Colors.redAccent.withValues(alpha: 0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDonut(FinanceSummary summary) {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DISTRIBUIÇÃO POR CATEGORIA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 32),
            SizedBox(
              height: 140,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(color: AppTheme.accentGold, value: 60, radius: 12, showTitle: false),
                        PieChartSectionData(color: Colors.greenAccent, value: 15, radius: 12, showTitle: false),
                        PieChartSectionData(color: Colors.blueAccent, value: 10, radius: 12, showTitle: false),
                        PieChartSectionData(color: Colors.redAccent, value: 10, radius: 12, showTitle: false),
                        PieChartSectionData(color: Colors.purpleAccent, value: 5, radius: 12, showTitle: false),
                      ],
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('TOTAL', style: TextStyle(color: AppTheme.textGrey, fontSize: 7, fontWeight: FontWeight.bold)),
                        Text('R\$${summary.totalRecebido.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _CategoryLegend(color: AppTheme.accentGold, label: 'Mensalidades', value: '60%'),
            const _CategoryLegend(color: Colors.greenAccent, label: 'Equipamentos', value: '15%'),
            const _CategoryLegend(color: Colors.blueAccent, label: 'Taxas Exame', value: '10%'),
            const _CategoryLegend(color: Colors.redAccent, label: 'Produtos Loja', value: '10%'),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionRow(FinanceSummary summary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildOverdueBuckets()),
        const SizedBox(width: 24),
        Expanded(flex: 5, child: _buildTopOverdueTable(summary)),
      ],
    );
  }

  Widget _buildOverdueBuckets() {
    return FadeInUp(
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('COBRANÇAS POR VENCIMENTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 32),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) {
                          const labels = ['30d', '60d', '90d+'];
                          if (v >= 0 && v < 3) return Text(labels[v.toInt()], style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold));
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _buildBarGroup(0, 45, AppTheme.accentGold),
                    _buildBarGroup(1, 25, AppTheme.accentGold.withValues(alpha: 0.6)),
                    _buildBarGroup(2, 15, Colors.redAccent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [BarChartRodData(toY: y, color: color, width: 25, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))],
    );
  }

  Widget _buildTopOverdueTable(FinanceSummary summary) {
    final overdueList = summary.alunosDetalhados.where((a) => a['status'] == 'VENCIDO' || a['status'] == 'PENDENTE').toList();
    overdueList.sort((a, b) => (b['valor'] as num).compareTo(a['valor'] as num));
    final top3 = overdueList.take(3).toList();

    return FadeInRight(
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AÇÃO URGENTE • TOP ATRASOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 14),
              ],
            ),
            const SizedBox(height: 24),
            if (top3.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Tudo em dia!', style: TextStyle(color: AppTheme.textGrey, fontSize: 12))))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: top3.length,
                separatorBuilder: (ctx, i) => const Divider(color: Colors.white10, height: 20),
                itemBuilder: (context, index) {
                  final al = top3[index];
                  return Row(
                    children: [
                      const CircleAvatar(radius: 14, backgroundColor: Colors.white10, child: Icon(LucideIcons.user, size: 12, color: AppTheme.textGrey)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(al['nome'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('R\$ ${al['valor'].toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      _ActionBtnSmall(icon: LucideIcons.messageSquare, color: AppTheme.accentGold, onTap: () {}),
                      const SizedBox(width: 8),
                      _ActionBtnSmall(icon: LucideIcons.eye, color: AppTheme.textGrey, onTap: () {}),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 2, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _CategoryLegend({required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 9))),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ActionBtnSmall extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtnSmall({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }
}
