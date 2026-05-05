import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';

class DashboardCrmView extends StatefulWidget {
  const DashboardCrmView({super.key});

  @override
  State<DashboardCrmView> createState() => _DashboardCrmViewState();
}

class _DashboardCrmViewState extends State<DashboardCrmView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeChip = 'Todos'; // 'Todos', 'Ativos', 'Devedores', 'Pendente Anamnese'
  
  Map<String, dynamic>? _selectedStudent;
  String? _selectedStudentId;

  int totalAtivos = 0;
  int totalInadimplentes = 0;
  double mrrMensal = 0.0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _calculateMetrics(List<QueryDocumentSnapshot> matriculas) async {
    int ativos = 0;
    int inadimplentes = 0;
    double mrrSoma = 0.0;

    // 1. Buscar valor padrão como fallback
    double valorPadrao = 75.0;
    try {
      final config = await FirebaseFirestore.instance.collection('config').doc('geral').get();
      if (config.exists) {
        valorPadrao = (config.data()?['mensalidade_valor'] ?? 75.0).toDouble();
      }
    } catch (e) {
      debugPrint('Erro ao buscar mensalidade padrão no CRM: $e');
    }

    final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    for (var doc in matriculas) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status_pagamento'] ?? 'Pendente';
      final vencimentoTs = data['vencimento'] as Timestamp?;
      final valorIndividual = (data['valor_plano'] ?? valorPadrao).toDouble();
      
      bool isVencido = false;
      if (vencimentoTs != null) {
        final vDt = vencimentoTs.toDate();
        if (hoje.isAfter(DateTime(vDt.year, vDt.month, vDt.day))) {
          isVencido = true;
        }
      }

      if (status == 'Pendente' || status == 'Vencido' || isVencido) {
        inadimplentes++;
      } else if (status == 'Pago') {
        ativos++;
        mrrSoma += valorIndividual;
      }
    }

    // Delay setState to avoid building cycle errors
    if (mounted) {
      setState(() {
        totalAtivos = ativos;
        totalInadimplentes = inadimplentes;
        mrrMensal = mrrSoma;
      });
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.cardDarkGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<QueryDocumentSnapshot> alunosList, List<QueryDocumentSnapshot> matriculasList) {
    // Cruza as strings
    var filtered = alunosList.where((alunoDoc) {
      final aData = alunoDoc.data() as Map<String, dynamic>;
      final nome = aData['nome']?.toString().toLowerCase() ?? '';
      
      // Busca Textual
      if (_searchQuery.isNotEmpty && !nome.contains(_searchQuery)) return false;

      // Busca na Mátricula
      final matDoc = matriculasList.where((m) => m.id == alunoDoc.id).firstOrNull;
      final mData = matDoc?.data() as Map<String, dynamic>?;
      final statusMat = mData?['status_pagamento'] ?? 'Pendente';
      final vTs = mData?['vencimento'] as Timestamp?;
      bool isVenc = false;
      if (vTs != null) {
        final h = DateTime.now();
        final dt = vTs.toDate();
        if (DateTime(h.year, h.month, h.day).isAfter(DateTime(dt.year, dt.month, dt.day))) isVenc = true;
      }
      final bool inadimplente = statusMat == 'Pendente' || statusMat == 'Vencido' || isVenc;

      if (_activeChip == 'Ativos' && inadimplente) return false;
      if (_activeChip == 'Devedores' && !inadimplente) return false;
      if (_activeChip == 'Pendente Anamnese' && aData['is_anamnese_completed'] == true) return false;
      
      return true;
    }).toList();

    return Expanded(
      child: Container(
        decoration: BoxDecoration(color: AppTheme.cardDarkGrey, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.premiumShadow, border: Border.all(color: AppTheme.glassBorder)),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 0.5),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: const WidgetStatePropertyAll(Colors.black12),
              columns: const [
                DataColumn(label: Text('Atleta', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Plano', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Anamnese', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Pagamento', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold))),
              ],
              rows: filtered.map((doc) {
                final aData = doc.data() as Map<String, dynamic>;
                
                final matDoc = matriculasList.where((m) => m.id == doc.id).firstOrNull;
                final mData = matDoc?.data() as Map<String, dynamic>?;
                final statusMat = mData?['status_pagamento'] ?? 'Pendente';
                final isOk = aData['is_anamnese_completed'] == true;

                final bool isSelected = _selectedStudentId == doc.id;

                return DataRow(
                  color: WidgetStatePropertyAll(isSelected ? AppTheme.accentGold.withValues(alpha: 0.1) : Colors.transparent),
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedStudentId = doc.id;
                      _selectedStudent = {...aData, 'matricula': mData};
                    });
                  },
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14, backgroundColor: isSelected ? AppTheme.accentGold : AppTheme.backgroundBlack,
                            child: Icon(LucideIcons.user, size: 14, color: isSelected ? Colors.black : AppTheme.textGrey),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(aData['nome'] ?? '', style: TextStyle(color: isSelected ? AppTheme.accentGold : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${aData['modalidade'] ?? ''} - ${aData['faixa'] ?? ''}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                            ],
                          )
                        ],
                      )
                    ),
                    DataCell(Text(mData?['plano'] ?? 'Mensal', style: const TextStyle(color: AppTheme.textGrey))),
                    DataCell(Icon(isOk ? LucideIcons.checkCircle : LucideIcons.alertTriangle, color: isOk ? Colors.green : Colors.orange, size: 16)),
                    DataCell(Text(statusMat, style: TextStyle(color: statusMat == 'Pago' ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                );
              }).toList(),
            ),
          )
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_selectedStudent == null) {
      return Container(
        width: 350,
        margin: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(color: AppTheme.cardDarkGrey, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.premiumShadow, border: Border.all(color: AppTheme.glassBorder)),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.search, size: 64, color: AppTheme.textGrey),
              SizedBox(height: 16),
              Text('Selecione um Aluno', style: TextStyle(color: AppTheme.textGrey)),
            ],
          ),
        ),
      );
    }

    final data = _selectedStudent!;
    final mat = data['matricula'] as Map<String, dynamic>?;

    Timestamp? vTs = mat?['vencimento'];
    String vencString = 'Não definido';
    if (vTs != null) {
      vencString = DateFormat('dd/MM/yyyy').format(vTs.toDate());
    }

    final isApto = data['apto_exame_faixa'] == true;

    return Container(
      width: 350,
      margin: const EdgeInsets.only(left: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardDarkGrey, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)), boxShadow: AppTheme.premiumShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 24, backgroundColor: Colors.black26, child: Icon(LucideIcons.user, color: AppTheme.accentGold)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['nome'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(data['email'] ?? '', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                  ],
                )
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, color: AppTheme.textGrey),
                onPressed: () => setState(() { _selectedStudent = null; _selectedStudentId = null; }),
              )
            ],
          ),
          const Divider(height: 32, color: Colors.black12),
          
          const Text('GESTÃO FINANCEIRA', style: TextStyle(color: AppTheme.textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Vencimento:', style: TextStyle(color: Colors.white)),
                Text(vencString, style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
              ]
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.backgroundBlack, foregroundColor: Colors.white),
            onPressed: () async {
              final newDate = await showDatePicker(
                context: context, initialDate: vTs?.toDate() ?? DateTime.now(),
                firstDate: DateTime(2020), lastDate: DateTime(2030),
                builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.accentGold, onPrimary: Colors.black, surface: AppTheme.cardDarkGrey)), child: child!),
              );
              if (newDate != null && mounted) {
                await FirebaseFirestore.instance.collection(FirebaseCollections.matriculas).doc(_selectedStudentId).update({'vencimento': Timestamp.fromDate(newDate)});
                setState(() => _selectedStudent!['matricula']['vencimento'] = Timestamp.fromDate(newDate));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vencimento alterado!')));
              }
            },
            icon: const Icon(LucideIcons.calendarDays, size: 16),
            label: const Text('Alterar Vencimento'),
          ),

          const SizedBox(height: 24),
          const Text('EVOLUÇÃO E SAÚDE', style: TextStyle(color: AppTheme.textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.backgroundBlack, foregroundColor: Colors.white),
                  onPressed: () {
                    // Editar Faixa Modal
                    final TextEditingController beltCtrl = TextEditingController(text: data['faixa'] ?? '');
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.cardDarkGrey, title: const Text('Alterar Faixa', style: TextStyle(color: Colors.white)),
                        content: TextField(controller: beltCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Faixa (Ex: AZUL)', labelStyle: TextStyle(color: AppTheme.textGrey))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textGrey))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(_selectedStudentId).update({
                                'faixa': beltCtrl.text.trim().toUpperCase(),
                                'dados_pessoais.faixa': beltCtrl.text.trim().toUpperCase(),
                              });
                              setState(() => _selectedStudent!['faixa'] = beltCtrl.text.trim().toUpperCase());
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Salvar'),
                          )
                        ]
                      )
                    );
                  },
                  icon: const Icon(LucideIcons.medal, size: 16),
                  label: Text('Faixa: ${data['faixa'] ?? '?'}', style: const TextStyle(fontSize: 12)),
                )
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: isApto ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1), foregroundColor: isApto ? Colors.red : Colors.green),
            onPressed: () async {
              await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(_selectedStudentId).update({'apto_exame_faixa': !isApto});
              setState(() => _selectedStudent!['apto_exame_faixa'] = !isApto);
            },
            icon: Icon(isApto ? LucideIcons.xCircle : LucideIcons.checkCircle2, size: 16),
            label: Text(isApto ? 'Revogar Exame' : 'Autorizar Exame de Faixa', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.backgroundBlack, foregroundColor: AppTheme.textGrey),
            onPressed: () async {
               // Load Anamnese text
               final doc = await FirebaseFirestore.instance.collection(FirebaseCollections.saudeAnamnese).doc(_selectedStudentId).get();
               if (!mounted) return;
               if (!doc.exists) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atestado não encontrado/Pendente.')));
                 return;
               }
               final b64 = doc.data()?['atestado_base64'] as String?;
               if (b64 != null && b64.isNotEmpty) {
                 showDialog(
                   context: context, builder: (ctx) => Dialog(
                     backgroundColor: Colors.transparent,
                     child: InteractiveViewer(child: Image.memory(base64Decode(b64))),
                   )
                 );
               }
            },
            icon: const Icon(LucideIcons.fileText, size: 16),
            label: const Text('Visualizar Ficha Médica (Atestado)'),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(FirebaseCollections.matriculas).snapshots(),
      builder: (context, matSnapshot) {
        
        final matriculas = matSnapshot.data?.docs ?? [];
        _calculateMetrics(matriculas);

        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER
              const Text('Dashboard CRM', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textWhite)),
              const SizedBox(height: 24),
              // METRICS (Vertical Layout)
              Column(
                children: [
                  _buildMetricCard('Atletas em Dia', totalAtivos.toString(), LucideIcons.users, Colors.green),
                  _buildMetricCard('Inadimplentes (Risco)', totalInadimplentes.toString(), LucideIcons.alertTriangle, Colors.red),
                  _buildMetricCard('Caixa Atual (Arrecadado)', 'R\$ ${mrrMensal.toStringAsFixed(2)}', LucideIcons.trendingUp, AppTheme.accentGold),
                ],
              ),
              const SizedBox(height: 32),
              // BODY
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tabela Principal
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // FILTERS
                              Wrap(
                                spacing: 8,
                                children: ['Todos', 'Ativos', 'Devedores', 'Pendente Anamnese'].map((c) {
                                  final isActive = _activeChip == c;
                                  return FilterChip(
                                    label: Text(c, style: TextStyle(color: isActive ? Colors.black : AppTheme.textGrey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                                    selected: isActive,
                                    selectedColor: AppTheme.accentGold,
                                    backgroundColor: AppTheme.cardDarkGrey,
                                    onSelected: (_) => setState(() { _activeChip = c; _selectedStudent = null; _selectedStudentId = null; }),
                                  );
                                }).toList(),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 250,
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                                  decoration: InputDecoration(
                                    hintText: 'Pesquisar Aluno...',
                                    prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppTheme.textGrey),
                                    filled: true, fillColor: AppTheme.cardDarkGrey,
                                    isDense: true, contentPadding: const EdgeInsets.all(12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                            ]
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection(FirebaseCollections.alunos).where('role', isEqualTo: 'aluno').snapshots(),
                            builder: (context, alunoSnap) {
                              if (alunoSnap.hasError) return const Expanded(child: Center(child: Text('Erro.')));
                              if (!alunoSnap.hasData) return const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)));
                              return _buildTable(alunoSnap.data!.docs, matriculas);
                            }
                          )
                        ],
                      )
                    ),

                    // Side Panel
                    if (_selectedStudent != null) _buildRightPanel()
                  ],
                ),
              )
            ],
          ),
        );
      }
    );
  }
}
