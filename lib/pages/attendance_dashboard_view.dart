import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import '../widgets/glass_container.dart';

class AttendanceDashboardView extends StatelessWidget {
  final Function(int)? onTabSelected;
  const AttendanceDashboardView({super.key, this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, now),
          const SizedBox(height: 32),
          _buildKPIRow(todayStart, todayEnd),
          const SizedBox(height: 32),
          _buildMainContent(context, todayStart, todayEnd),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DateTime now) {
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CENTRAL DE COMANDO',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textWhite,
                      letterSpacing: 2,
                      fontSize: 24,
                    ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat("'SENSEI ADMIN •' EEEE, dd 'DE' MMMM", 'pt_BR').format(now).toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Icon(LucideIcons.layoutDashboard, color: AppTheme.accentGold, size: 32),
        ],
      ),
    );
  }

  Widget _buildKPIRow(DateTime start, DateTime end) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.frequencia)
          .where('dataHora', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dataHora', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .snapshots(),
      builder: (context, freqSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirebaseCollections.alunos)
              .where('role', isEqualTo: 'aluno')
              .snapshots(),
          builder: (context, alunoSnapshot) {
            final freqDocs = freqSnapshot.data?.docs ?? [];
            final totalAlunos = alunoSnapshot.data?.docs.length ?? 0;

            final aprovados = freqDocs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'aprovado').length;
            final falhas = freqDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == 'recusado' || (data['status_detalhe']?.toString().contains('GPS') ?? false);
            }).length;
            final pendentes = freqDocs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'solicitado').length;

            return Row(
              children: [
                Expanded(child: _buildKPICard('PRESENÇAS', aprovados.toString(), LucideIcons.checkCircle2, Colors.greenAccent, '+12% vs. Ontem')),
                const SizedBox(width: 16),
                Expanded(child: _buildKPICard('FALHAS/GPS', falhas.toString(), LucideIcons.xCircle, Colors.redAccent, '0%')),
                const SizedBox(width: 16),
                Expanded(child: _buildKPICard('PENDENTES', pendentes.toString(), LucideIcons.clock, AppTheme.accentGold, 'Estável')),
                const SizedBox(width: 16),
                Expanded(child: _buildKPICard('ATIVOS', '$totalAlunos/100', LucideIcons.users, Colors.blueAccent, '+2%', showProgress: true, progress: totalAlunos / 100)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color, String trend, {bool showProgress = false, double progress = 0}) {
    return FadeInLeft(
      duration: const Duration(milliseconds: 600),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            if (showProgress) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, DateTime start, DateTime end) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _buildWeeklyChart(),
                  const SizedBox(height: 24),
                  _buildModalityDistribution(),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: _buildPendingApprovalsTable(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeeklyChart() {
    return FadeInUp(
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PRESENÇAS NA SEMANA',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                ),
                Icon(LucideIcons.trendingUp, color: AppTheme.accentGold, size: 16),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 200,
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
                        interval: 5,
                        getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                        reservedSize: 28,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          const days = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
                          if (val >= 0 && val < 7) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(days[val.toInt()], style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 1),
                        const FlSpot(1, 2),
                        const FlSpot(2, 7),
                        const FlSpot(3, 3),
                        const FlSpot(4, 9),
                        const FlSpot(5, 2),
                        const FlSpot(6, 1),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.4,
                      color: AppTheme.accentGold,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentGold.withValues(alpha: 0.3),
                            AppTheme.accentGold.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
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

  Widget _buildModalityDistribution() {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ALUNOS POR MODALIDADE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                SizedBox(
                  height: 150,
                  width: 150,
                  child: Stack(
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 5,
                          centerSpaceRadius: 45,
                          sections: [
                            PieChartSectionData(color: AppTheme.accentGold, value: 35, radius: 15, showTitle: false),
                            PieChartSectionData(color: Colors.blueAccent, value: 25, radius: 15, showTitle: false),
                            PieChartSectionData(color: Colors.greenAccent, value: 20, radius: 15, showTitle: false),
                            PieChartSectionData(color: Colors.redAccent, value: 15, radius: 15, showTitle: false),
                            PieChartSectionData(color: Colors.purpleAccent, value: 5, radius: 15, showTitle: false),
                          ],
                        ),
                      ),
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('TOTAL', style: TextStyle(color: AppTheme.textGrey, fontSize: 8, fontWeight: FontWeight.bold)),
                            Text('6', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                            Text('ATIVOS', style: TextStyle(color: AppTheme.textGrey, fontSize: 8, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                const Expanded(
                  child: Column(
                    children: [
                      _LegendItem(color: AppTheme.accentGold, label: 'Jiu-Jitsu', value: '2'),
                      _LegendItem(color: Colors.blueAccent, label: 'Muay Thai', value: '1'),
                      _LegendItem(color: Colors.greenAccent, label: 'Judô', value: '1'),
                      _LegendItem(color: Colors.redAccent, label: 'Boxe', value: '1'),
                      _LegendItem(color: Colors.purpleAccent, label: 'Outros', value: '1'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApprovalsTable() {
    return FadeInRight(
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PENDENTES DE ENTRADA',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                ),
                Icon(LucideIcons.listFilter, color: AppTheme.textGrey, size: 16),
              ],
            ),
            const SizedBox(height: 24),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirebaseCollections.frequencia)
                  .where('status', isEqualTo: 'solicitado')
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(LucideIcons.checkCircle2, color: Colors.white10, size: 48),
                          SizedBox(height: 16),
                          Text('Nenhum pendente', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (ctx, i) => const Divider(color: Colors.white10, height: 24),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String name = data['aluno_nome'] ?? '...';
                    final String modality = data['modalidade'] ?? 'Geral';
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white10,
                          backgroundImage: data['aluno_foto'] != null ? NetworkImage(data['aluno_foto']) : null,
                          child: data['aluno_foto'] == null ? const Icon(LucideIcons.user, size: 16, color: AppTheme.textGrey) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(modality.toUpperCase(), style: const TextStyle(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ActionBtn(icon: LucideIcons.check, color: Colors.greenAccent, onTap: () => _approve(docs[index])),
                        const SizedBox(width: 8),
                        _ActionBtn(icon: LucideIcons.x, color: Colors.redAccent, onTap: () => _reject(docs[index])),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(DocumentSnapshot doc) async {
    await doc.reference.update({
      'status': 'aprovado',
      'status_detalhe': 'Aprovado pelo Admin',
    });
  }

  Future<void> _reject(DocumentSnapshot doc) async {
    await doc.reference.update({
      'status': 'recusado',
      'status_detalhe': 'Recusado pelo Admin',
    });
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendItem({required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11))),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
