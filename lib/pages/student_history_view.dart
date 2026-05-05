import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import '../models/checkin_model.dart';
import '../providers/auth_provider.dart';
import '../core/services/mercadopago_service.dart';
import '../widgets/pagamento_modal.dart';
import 'package:http/http.dart' as http;

class StudentHistoryView extends ConsumerWidget {
  final String userId;
  const StudentHistoryView({super.key, required this.userId});

  Future<void> _abrirWhatsAppSensei(BuildContext context) async {
    String telefone = "5511973772334"; // Fallback
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('geral').get();
      if (doc.exists && doc.data()?['whatsapp_sensei'] != null) {
        telefone = doc.data()!['whatsapp_sensei'];
      }
    } catch (e) {
      debugPrint('Erro ao buscar WhatsApp dinâmico: $e');
    }

    final String mensagem = Uri.encodeComponent("Olá Sensei, tenho uma dúvida sobre minha situação financeira no Dojo Manager.");
    final Uri url = Uri.parse("https://wa.me/$telefone?text=$mensagem");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Não foi possível abrir o WhatsApp"))
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao tentar abrir o WhatsApp"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppTheme.accentGold,
            labelColor: AppTheme.accentGold,
            unselectedLabelColor: AppTheme.textGrey,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(icon: Icon(LucideIcons.calendarCheck), text: 'TREINOS'),
              Tab(icon: Icon(LucideIcons.coins), text: 'FINANCEIRO'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCheckinsList(context, ref),
                _buildPaymentsList(context, profile, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinsList(BuildContext context, WidgetRef ref) {
    final checkinsStream = FirebaseFirestore.instance
        .collection(FirebaseCollections.frequencia)
        .where('aluno_id', isEqualTo: userId)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: checkinsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerList();
        }

        final docs = snapshot.data?.docs ?? [];
        final checkins = docs.map((d) => CheckInModel.fromMap(d.id, d.data() as Map<String, dynamic>?)).toList();

        // Ordenação Local (Client-side) para evitar erro de índice no Firestore
        checkins.sort((a, b) => b.dataHora.compareTo(a.dataHora));

        if (checkins.isEmpty) {
          return _buildEmptyState(LucideIcons.calendar, 'Nenhum treino registrado ainda. Bora pro tatame!');
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirebaseCollections.alunos)
              .doc(userId)
              .collection(FirebaseCollections.diarioAtleta)
              .snapshots(),
          builder: (context, diarySnap) {
            final notes = diarySnap.data?.docs ?? [];

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: checkins.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) return _buildTrainingCountHeader(checkins.length);
                if (index == checkins.length + 1) return _buildSupportButton(context, ref);

                final docIndex = index - 1;
                final checkIn = checkins[docIndex];
                
                final dateFormatted = DateFormat("dd MMM yyyy - HH:mm").format(checkIn.dataHora);

                QueryDocumentSnapshot? noteForDay;
                final checkinTime = checkIn.dataHora;
                for (var n in notes) {
                  final nData = n.data() as Map<String, dynamic>;
                  final nTs = (nData['data_hora'] ?? nData['createdAt']) as Timestamp?;
                  if (nTs != null) {
                    final nTime = nTs.toDate();
                    if (nTime.year == checkinTime.year && nTime.month == checkinTime.month && nTime.day == checkinTime.day) {
                      noteForDay = n;
                      break;
                    }
                  }
                }

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDarkGrey,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.1)),
                    ),
                    child: ExpansionTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.doorOpen,
                          color: AppTheme.accentGold,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        dateFormatted, 
                        style: const TextStyle(
                          color: Colors.white70, 
                          fontWeight: FontWeight.w500, 
                          fontSize: 12
                        )
                      ),
                      subtitle: Text(
                        'Check-in Confirmado - ${checkIn.modalidade}', 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 14, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5
                        )
                      ),
                      trailing: Icon(
                        noteForDay != null ? LucideIcons.bookOpen : LucideIcons.plus, 
                        color: noteForDay != null ? AppTheme.accentGold : AppTheme.textGrey.withValues(alpha: 0.5), 
                        size: 16
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: noteForDay != null ? _buildNoteContent(noteForDay) : _buildAddNotePrompt(context, Timestamp.fromDate(checkIn.dataHora)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTrainingCountHeader(int total) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.accentGold.withValues(alpha: 0.15), AppTheme.cardDarkGrey], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Text('🔥', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FREQUÊNCIA TOTAL', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(children: [
                  TextSpan(text: '$total', style: const TextStyle(color: AppTheme.accentGold, fontSize: 28, fontWeight: FontWeight.w900)),
                  const TextSpan(text: ' treinos', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                ]),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('OSS! 🥋', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(total >= 30 ? 'Elite Athlete' : total >= 10 ? 'Dedicado' : 'Começando', style: TextStyle(color: total >= 30 ? AppTheme.accentGold : total >= 10 ? Colors.greenAccent : AppTheme.textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList(BuildContext context, UserProfileData? profile, WidgetRef ref) {
    if (profile == null) return _buildShimmerList();

    final DateTime? dataPagamento = profile.ultimaConfirmacao;
    final DateTime? proximoVencimento = profile.proximoVencimento;
    
    final bool isNovoAluno = dataPagamento == null;
    final now = DateTime.now();
    final bool isVencido = proximoVencimento != null && now.isAfter(proximoVencimento);
    final int diasParaVencer = proximoVencimento != null ? proximoVencimento.difference(now).inDays : 999;
    final bool isFaturaAberta = !isVencido && diasParaVencer <= 5;
    
    String statusFinanceiro = 'em dia';
    if (isVencido) {
      statusFinanceiro = 'vencido';
    } else if (isFaturaAberta) {
      statusFinanceiro = 'fatura aberta';
    }
    
    final bool showPayButton = isVencido || isFaturaAberta;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('PAGAMENTOS')
          .where('aluno_id', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildShimmerList();
        final List<QueryDocumentSnapshot> historyDocs = List.from(snapshot.data?.docs ?? []);

        // Ordenação Local (Dart)
        historyDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final tsA = (dataA['pagoEm'] ?? dataA['data_pagamento'] ?? dataA['data_confirmacao'] ?? dataA['data'] ?? dataA['criadoEm']) as Timestamp?;
          final tsB = (dataB['pagoEm'] ?? dataB['data_pagamento'] ?? dataB['data_confirmacao'] ?? dataB['data'] ?? dataB['criadoEm']) as Timestamp?;
          if (tsA == null || tsB == null) return 0;
          return tsB.compareTo(tsA); // Decrescente
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (profile.planoCorporativo != 'nenhum')
              _buildCorporateActiveCard(context, profile)
            else if (isNovoAluno || historyDocs.isEmpty)
              _buildAdesaoCard(context, profile, ref, historyDocs)
            else ...[
              _buildCountdown(profile.proximoVencimento),
              const SizedBox(height: 16),
              _buildTimelineCard(
                context, 
                profile, 
                ref, 
                title: 'SITUAÇÃO ATUAL', 
                dataVencimento: proximoVencimento, 
                status: statusFinanceiro, 
                showPayButton: showPayButton
              ),
              const SizedBox(height: 12),
              if (dataPagamento != null)
                _buildTimelineCard(
                  context, 
                  profile, 
                  ref, 
                  title: 'ÚLTIMO PAGAMENTO', 
                  dataVencimento: dataPagamento, 
                  status: 'confirmado', 
                  showPayButton: false
                ),
            ],

            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(profile.planoCorporativo != 'nenhum' ? 'HISTÓRICO DE VALIDAÇÕES' : 'HISTÓRICO DE TRANSAÇÕES', style: const TextStyle(color: AppTheme.textGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),

            if (profile.planoCorporativo != 'nenhum')
              _buildCorporateHistoryList(profile)
            else if (historyDocs.isEmpty)
              _buildEmptyState(LucideIcons.history, 'Nenhuma transação financeira registrada.')
            else
              ...historyDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final valor = (data['valor'] ?? 0.0).toDouble();
                final status = (data['status'] ?? 'pago').toString().toLowerCase();
                final isPago = status == 'pago' || status == 'aprovado';
                
                final color = isPago ? Colors.green : Colors.orange;
                final icon = isPago ? LucideIcons.checkCircle : LucideIcons.clock;

                final timestamp = (data['pagoEm'] ?? data['data_pagamento'] ?? data['data_confirmacao'] ?? data['data'] ?? data['criadoEm']) as Timestamp?;
                final dataFmt = timestamp != null ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate()) : '---';
                final String vStr = 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppTheme.cardDarkGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), 
                    side: BorderSide(color: color.withOpacity(0.2))
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.1), 
                      child: Icon(icon, color: color, size: 20)
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['titulo']?.toString().toUpperCase() ?? (isPago ? 'PAGAMENTO APROVADO' : 'PAGAMENTO PENDENTE'), 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                          ),
                        ),
                        if (data['receipt_url'] != null)
                          IconButton(
                            icon: const Icon(LucideIcons.fileText, color: AppTheme.accentGold, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comprovante enviado para o e-mail cadastrado.'), backgroundColor: Colors.green));
                            },
                            tooltip: 'Ver Comprovante',
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dataFmt, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                        if (!isPago && data['slug'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: InkWell(
                              onTap: () async {
                                final scaffold = ScaffoldMessenger.of(context);
                                try {
                                  final confirmado = await MercadoPagoService.verificarStatusPagamento(
                                    alunoId: userId,
                                    orderNsu: doc.id,
                                  );
                                  
                                  scaffold.clearSnackBars();
                                  if (confirmado) {
                                    scaffold.showSnackBar(const SnackBar(content: Text('✅ Pagamento Confirmado! Seu histórico será atualizado em instantes.'), backgroundColor: Colors.green));
                                  } else {
                                    scaffold.showSnackBar(const SnackBar(content: Text('⏳ Pagamento ainda não detectado. Aguarde alguns minutos ou fale com o Sensei.'), backgroundColor: Colors.orange));
                                  }
                                } catch (e) {
                                  scaffold.showSnackBar(const SnackBar(content: Text('❌ Falha na verificação. Tente novamente mais tarde.'), backgroundColor: Colors.redAccent));
                                }
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.refreshCw, color: AppTheme.accentGold, size: 12),
                                  SizedBox(width: 6),
                                  Text(
                                    'JÁ PAGUEI / ATUALIZAR STATUS', 
                                    style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), 
                      child: Text(vStr, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11))
                    ),
                  ),
                );
              }),

            _buildSupportButton(context, ref),
          ],
        );
      },
    );
  }

  Widget _buildCountdown(DateTime? proximoVencimento) {
    if (proximoVencimento == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final difference = proximoVencimento.difference(now).inDays;
    final isAtrasado = difference < 0;
    
    final color = isAtrasado ? Colors.redAccent : (difference <= 5 ? Colors.orangeAccent : Colors.greenAccent);
    final label = isAtrasado 
        ? 'Mensalidade Vencida há ${difference.abs()} dias' 
        : (difference <= 5 
            ? 'Sua fatura fecha em breve (${difference} dias)' 
            : 'Mensalidade em Dia!');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: color.withValues(alpha: 0.3))
      ),
      child: Row(
        children: [
          Icon(isAtrasado ? LucideIcons.alertTriangle : LucideIcons.timer, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCorporateActiveCard(BuildContext context, UserProfileData profile) {
    final isWH = profile.planoCorporativo == 'wellhub';
    final color = isWH ? Colors.pinkAccent : Colors.greenAccent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.cardDarkGrey, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(children: [Icon(isWH ? LucideIcons.dumbbell : LucideIcons.activity, color: color, size: 32), const SizedBox(height: 12), const Text('Aluno conveniado corporativo não haverá cobrança no perfil dele.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textGrey, fontSize: 13))]),
    );
  }

  Widget _buildCorporateHistoryList(UserProfileData profile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(FirebaseCollections.frequencia).where('aluno_id', isEqualTo: profile.uid).where('status', isEqualTo: 'aprovado').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('Nenhum check-in validado.', style: TextStyle(color: AppTheme.textGrey))));
        final label = profile.planoCorporativo == 'wellhub' ? 'WELLHUB' : 'TOTAL PASS';
        return Column(children: docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['created_at'] as Timestamp?;
          final date = ts != null ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate()) : '---';
          return Card(margin: const EdgeInsets.only(bottom: 12), color: AppTheme.cardDarkGrey, child: ListTile(leading: const Icon(LucideIcons.checkCircle, color: Colors.blueAccent), title: const Text('CHECK-IN VALIDADO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text(date, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text('Pago pelo $label', style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)))));
        }).toList());
      },
    );
  }

  Widget _buildAdesaoCard(BuildContext context, UserProfileData profile, WidgetRef ref, List<QueryDocumentSnapshot> historyDocs) {
    bool isPago = false;
    if (historyDocs.isNotEmpty) {
      final docData = historyDocs.first.data() as Map<String, dynamic>;
      if (docData['status']?.toString().toLowerCase() == 'pago') isPago = true;
    }
    if (isPago || profile.statusPagamento.toLowerCase() == 'pago') {
      return Card(color: Colors.green.withValues(alpha: 0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.green)), child: const Padding(padding: EdgeInsets.all(20.0), child: Column(children: [Icon(LucideIcons.checkCircle, color: Colors.green, size: 32), SizedBox(height: 12), Text('ADESÃO PAGA COM SUCESSO!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 8), Text('Seu acesso total foi liberado. Bom treino!', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textGrey, fontSize: 12))])));
    }
    return Card(color: Colors.orange.withValues(alpha: 0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.orange)), child: Padding(padding: const EdgeInsets.all(20.0), child: Column(children: [const Icon(LucideIcons.sparkles, color: Colors.orange, size: 32), const SizedBox(height: 12), const Text('MENSALIDADE DE ADESÃO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8), const Text('Seja bem-vindo! Regularize sua primeira mensalidade para liberar seu acesso total.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textGrey, fontSize: 12)), const SizedBox(height: 20), _payButton(context, profile, ref)])));
  }

  Widget _buildTimelineCard(BuildContext context, UserProfileData profile, WidgetRef ref, {required String title, required DateTime? dataVencimento, required String status, required bool showPayButton}) {
    Color color;
    String statusLabel = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'vencido':
        color = Colors.redAccent;
        statusLabel = 'MENSALIDADE VENCIDA';
        break;
      case 'fatura aberta':
      case 'aberta':
        color = Colors.orangeAccent;
        statusLabel = 'FATURA ABERTA';
        break;
      case 'em dia':
      case 'confirmado':
      case 'pago':
        color = Colors.greenAccent;
        statusLabel = 'EM DIA';
        break;
      default:
        color = AppTheme.textGrey;
    }

    final dataFmt = dataVencimento != null ? DateFormat('dd/MM/yyyy').format(dataVencimento) : '--/--/----';
    
    return Card(
      color: AppTheme.cardDarkGrey, 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: color.withValues(alpha: 0.3))
      ), 
      child: Padding(
        padding: const EdgeInsets.all(16.0), 
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)), 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), 
                  child: Text(statusLabel, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))
                )
              ]
            ), 
            const SizedBox(height: 12), 
            Row(
              children: [
                Icon(LucideIcons.calendar, color: color, size: 20), 
                const SizedBox(width: 12), 
                Text(dataFmt, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), 
                const Spacer(), 
                if (showPayButton) _payButton(context, profile, ref, small: true)
              ]
            )
          ]
        )
      )
    );
  }

  Widget _payButton(BuildContext context, UserProfileData profile, WidgetRef ref, {bool small = false}) {
    return ElevatedButton(
      onPressed: () async {
        // 1. Busca o valor no banco de dados (protegido)
        double valorBase = 5.0;
        try {
          final doc = await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(profile.uid).get();
          if (doc.exists) {
            final financeiro = doc.data()?['financeiro'] as Map<String, dynamic>? ?? {};
            valorBase = (financeiro['valor_plano'] ?? doc.data()?['valor_plano'] ?? 5.0).toDouble();
            
            // TEMPORÁRIO: Se o valor for inferior a R$ 5,00, forçamos para 5.0 para evitar 403 (PolicyAgent) do Mercado Pago
            if (valorBase < 5.0) valorBase = 5.0;
          }
        } catch (e) {
          debugPrint('Erro ao buscar valor: $e');
        }

        if (!context.mounted) return;
        
        bool loadingVisible = false;
        
        // Mostra Loading Nativo
        showDialog(
          context: context, 
          barrierDismissible: false, 
          builder: (ctx) {
            loadingVisible = true;
            return const AlertDialog(
              backgroundColor: AppTheme.cardDarkGrey, 
              content: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  CircularProgressIndicator(color: AppTheme.accentGold), 
                  SizedBox(height: 16), 
                  Text('Gerando PIX...', style: TextStyle(color: Colors.white))
                ]
              )
            );
          }
        );

        try {
          // 2. HTTP POST Limpo e Direto para Vercel
          final email = FirebaseAuth.instance.currentUser?.email ?? 'aluno@dojomanager.com';
          final response = await http.post(
            Uri.parse('https://backend-vercel-theta-rouge.vercel.app/api/pagamentos/gerar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'aluno_id': profile.uid,
              'valor': valorBase,
              'email': email,
            }),
          ).timeout(const Duration(seconds: 15));

          if (context.mounted && loadingVisible) {
            Navigator.pop(context); // Fecha o modal "Gerando PIX..."
            loadingVisible = false;
          }

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final String checkoutUrl = data['url'] ?? '';
            
            if (context.mounted && checkoutUrl.isNotEmpty) {
              debugPrint('✅ Link gerado: $checkoutUrl');
              // Forçar abertura na mesma aba para burlar bloqueador de pop-ups no mobile web
              await launchUrl(Uri.parse(checkoutUrl), webOnlyWindowName: '_self');
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Erro ao gerar link de pagamento. Fale com o Sensei.'),
                  backgroundColor: Colors.redAccent,
                )
              );
            }
          }
        } catch (e) {
          debugPrint('❌ Erro no fluxo de pagamento: $e');
          if (context.mounted) {
            if (loadingVisible) {
              Navigator.pop(context); // Garante que o loading seja fechado em caso de erro
              loadingVisible = false;
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Erro de conexão ou processamento: $e'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              )
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentGold, 
        foregroundColor: Colors.black, 
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 32, vertical: small ? 8 : 14), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
      ), 
      child: Text(small ? 'PAGAR' : 'PAGAR AGORA', style: const TextStyle(fontWeight: FontWeight.bold))
    );
  }

  void schedulePaymentReminder(DateTime vencimento) {
    final targetDate = vencimento.subtract(const Duration(days: 3));
    if (DateTime.now().isBefore(targetDate)) debugPrint('Lembrete financeiro agendado para: $targetDate');
  }

  void _showLoading(BuildContext context, String msg) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(backgroundColor: AppTheme.cardDarkGrey, content: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(color: AppTheme.accentGold), const SizedBox(height: 16), Text(msg, style: const TextStyle(color: Colors.white))])));
  }

  Widget _buildShimmerList() {
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: 6, itemBuilder: (context, index) => Shimmer.fromColors(baseColor: AppTheme.cardDarkGrey, highlightColor: Colors.grey.shade800, child: Container(height: 72, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)))));
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 48, color: AppTheme.textGrey), const SizedBox(height: 16), Text(message, style: const TextStyle(color: AppTheme.textGrey))]));
  }

  Widget _buildSupportButton(BuildContext context, WidgetRef ref) {
    return Padding(padding: const EdgeInsets.only(top: 24, bottom: 40), child: Column(children: [const Text('Tem alguma dúvida sobre sua situação?', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)), const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => _abrirWhatsAppSensei(context), style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.accentGold), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), icon: const Icon(LucideIcons.messageSquare, size: 18, color: AppTheme.accentGold), label: const Text('FALAR COM O SENSEI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]));
  }



  Widget _buildNoteContent(QueryDocumentSnapshot noteDoc) {
    final data = noteDoc.data() as Map<String, dynamic>;
    final text = data['texto_nota'] ?? '';
    final intensity = data['intensidade'] ?? 3;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Divider(color: Colors.white10), const SizedBox(height: 8), Row(children: [Text(_getIntensityEmoji(intensity), style: const TextStyle(fontSize: 20)), const SizedBox(width: 8), const Text('ANOTAÇÃO DE TREINO', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))]), const SizedBox(height: 8), Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))]);
  }

  Widget _buildAddNotePrompt(BuildContext context, Timestamp? checkinTs) {
    return Column(children: [const Divider(color: Colors.white10), const SizedBox(height: 8), TextButton.icon(onPressed: () => _showDiaryModal(context, checkinTs), icon: const Icon(LucideIcons.plus, size: 14, color: AppTheme.textGrey), label: const Text('ADICIONAR NOTA AO DIÁRIO', style: TextStyle(color: AppTheme.textGrey, fontSize: 11, fontWeight: FontWeight.bold)), style: TextButton.styleFrom(backgroundColor: AppTheme.backgroundBlack, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))]);
  }

  String _getIntensityEmoji(int intensity) {
    switch (intensity) { case 1: return '🧘'; case 2: return '🥋'; case 3: return '🔥'; case 4: return '🥵'; case 5: return '💀'; default: return '🥋'; }
  }

  void _showDiaryModal(BuildContext context, Timestamp? originalTs) {
    final noteController = TextEditingController(); int intensity = 3;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppTheme.cardDarkGrey, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => Padding(padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Diário de Treino 🥋', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Registre o que aprendeu nesta aula.', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)), const SizedBox(height: 24), TextField(controller: noteController, maxLines: 5, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Como foi o treino?', hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)), filled: true, fillColor: AppTheme.backgroundBlack, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))), const SizedBox(height: 24), const Text('NÍVEL DE ESFORÇO', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_intensityEmojiItem(1, '🧘', intensity, (v) => setModalState(() => intensity = v)), _intensityEmojiItem(2, '🥋', intensity, (v) => setModalState(() => intensity = v)), _intensityEmojiItem(3, '🔥', intensity, (v) => setModalState(() => intensity = v)), _intensityEmojiItem(4, '🥵', intensity, (v) => setModalState(() => intensity = v)), _intensityEmojiItem(5, '💀', intensity, (v) => setModalState(() => intensity = v))]), const SizedBox(height: 32), ElevatedButton(onPressed: () async { if (noteController.text.isEmpty) return; await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(userId).collection(FirebaseCollections.diarioAtleta).add({'data_hora': originalTs ?? FieldValue.serverTimestamp(), 'texto_nota': noteController.text, 'intensidade': intensity}); if (context.mounted) Navigator.pop(ctx); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black), child: const Text('SALVAR NO DIÁRIO'))]))));
  }

  Widget _intensityEmojiItem(int val, String emoji, int current, Function(int) onSelect) {
    bool selected = val == current;
    return GestureDetector(onTap: () => onSelect(val), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: selected ? AppTheme.accentGold.withValues(alpha: 0.1) : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: selected ? AppTheme.accentGold : Colors.white10)), child: Text(emoji, style: const TextStyle(fontSize: 20))));
  }
}
