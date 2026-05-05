import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import '../widgets/student_edit_dialog.dart';
import '../core/utils/termo_pdf_generator.dart';
import '../providers/auth_provider.dart';
import 'package:printing/printing.dart';
import '../widgets/glass_container.dart';
import '../widgets/belt_badge.dart';
import '../core/utils/dossie_pdf_generator.dart';
import 'package:file_picker/file_picker.dart';
import '../core/services/firebase_storage_service.dart';

class StudentsListView extends StatefulWidget {
  final TextEditingController? searchController;
  const StudentsListView({super.key, this.searchController});

  @override
  State<StudentsListView> createState() => _StudentsListViewState();
}

class _StudentsListViewState extends State<StudentsListView> {
  String _searchQuery = '';
  List<DocumentSnapshot> alunosOriginais = [];
  List<DocumentSnapshot> alunosFiltrados = [];

  final List<String> modalidadesDisponiveis = [
    'MMA', 'Kickboxing', 'Jiu-jitsu', 'Boxing', 
    'Karate', 'Funcional', 'Self Defense', 'Muay Thai',
    'Múltiplas Lutas'
  ];
  List<String> modalidadesSelecionadas = [];
  bool _filtroComAtestado = false;
  bool _filtroPendentesSaude = false;
  bool _filtroPendentesLGPD = false; // [NOVO]
  bool _isGeneratingPdf = false; // [NOVO] Estado de loading para PDF

  @override
  void initState() {
    super.initState();
    if (widget.searchController != null) {
      _searchQuery = widget.searchController!.text;
      widget.searchController!.addListener(_onSearchChanged);
    }
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() => _searchQuery = widget.searchController!.text);
    }
  }

  @override
  void dispose() {
    widget.searchController?.removeListener(_onSearchChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Alunos (V16-FORCE-SYNC)',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                  ),
                  const SizedBox(height: 24),
                  
                  // BARRA DE BUSCA (Estilo Pill)
                  GlassContainer(
                    borderRadius: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: widget.searchController,
                      onChanged: (v) => setState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        icon: Icon(LucideIcons.search, color: AppTheme.accentGold, size: 20),
                        hintText: 'Buscar por Nome, CPF ou Modalidade...',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // INTERFACE DE FILTRO
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...modalidadesDisponiveis.map((mod) {
                          final isSelected = modalidadesSelecionadas.contains(mod);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(mod, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    modalidadesSelecionadas.add(mod);
                                  } else {
                                    modalidadesSelecionadas.remove(mod);
                                  }
                                });
                              },
                              selectedColor: AppTheme.accentGold.withValues(alpha: 0.3),
                              checkmarkColor: AppTheme.accentGold,
                              backgroundColor: AppTheme.backgroundBlack,
                              labelStyle: TextStyle(color: isSelected ? AppTheme.accentGold : AppTheme.textGrey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isSelected ? AppTheme.accentGold : Colors.white10),
                              ),
                            ),
                          );
                        }),
                        
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('Com Atestado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: _filtroComAtestado,
                            onSelected: (val) => setState(() => _filtroComAtestado = val),
                            selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
                            checkmarkColor: Colors.blueAccent,
                            backgroundColor: AppTheme.backgroundBlack,
                            labelStyle: TextStyle(color: _filtroComAtestado ? Colors.blueAccent : AppTheme.textGrey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: _filtroComAtestado ? Colors.blueAccent : Colors.white10),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('Pendentes de Avaliação', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: _filtroPendentesSaude,
                            onSelected: (val) => setState(() => _filtroPendentesSaude = val),
                            selectedColor: Colors.orangeAccent.withValues(alpha: 0.3),
                            checkmarkColor: Colors.orangeAccent,
                            backgroundColor: AppTheme.backgroundBlack,
                            labelStyle: TextStyle(color: _filtroPendentesSaude ? Colors.orangeAccent : AppTheme.textGrey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: _filtroPendentesSaude ? Colors.orangeAccent : Colors.white10),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('Pendentes LGPD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: _filtroPendentesLGPD,
                            onSelected: (val) => setState(() => _filtroPendentesLGPD = val),
                            selectedColor: Colors.orange.withValues(alpha: 0.3),
                            checkmarkColor: Colors.orange,
                            backgroundColor: AppTheme.backgroundBlack,
                            labelStyle: TextStyle(color: _filtroPendentesLGPD ? Colors.orange : AppTheme.textGrey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: _filtroPendentesLGPD ? Colors.orange : Colors.white10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection(FirebaseCollections.alunos).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
                  }
                  
                  final docs = snapshot.data?.docs ?? [];
                  
                  // FILTRAGEM REAL-TIME (Cruzada: Busca + Chips)
                  final query = widget.searchController?.text.toLowerCase() ?? '';
                  final filtered = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final nome = (d['dados_pessoais']?['nome'] ?? d['nome'] ?? '').toString().toLowerCase();
                    final cpf = (d['dados_pessoais']?['cpf'] ?? '').toString();
                    
                    // Busca Texto
                    bool matchesSearch = nome.contains(query) || cpf.contains(query);
                    
                    // Busca Modalidade (Chips)
                    bool matchesModality = true;
                    if (modalidadesSelecionadas.isNotEmpty) {
                      var modData = d['modalidade'] ?? d['dados_pessoais']?['modalidade'];
                      List<String> modalities = modData is String ? [modData] : List<String>.from(modData ?? []);
                      matchesModality = modalidadesSelecionadas.any((m) => modalities.contains(m));
                    }

                    // Filtros Extras
                    if (_filtroComAtestado && (d['dados_pessoais']?['tem_atestado'] != true)) return false;
                    if (_filtroPendentesSaude && (d['dados_pessoais']?['status_aptidao'] != 'Em avaliação para aptidão física')) return false;
                    
                    final bool temTermo = d['termo_assinado_url'] != null || d['termos_matricula']?['urlTermoPdf'] != null;
                    if (_filtroPendentesLGPD && temTermo) return false;

                    return matchesSearch && matchesModality;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('Nenhum aluno encontrado.', style: TextStyle(color: AppTheme.textGrey)));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 24),
                    itemBuilder: (context, index) => _buildStudentRichCard(filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentRichCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final personal = data['dados_pessoais'] as Map<String, dynamic>? ?? {};
    final financeiro = data['financeiro'] as Map<String, dynamic>? ?? {};
    final String nome = personal['nome'] ?? data['nome'] ?? '...';
    
    // Status Financeiro (Semafórico)
    final statusFin = (financeiro['status'] ?? 'pendente').toString().toLowerCase();
    final bool isPago = statusFin == 'pago';
    final Color statusColor = isPago ? Colors.greenAccent : Colors.redAccent;

    // Status LGPD (Audit)
    final bool temTermo = data['termo_assinado_url'] != null || data['termos_matricula']?['urlTermoPdf'] != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: InkWell(
            onTap: () => _showStudentDossierModal(context, doc),
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.cardDarkGrey,
                        backgroundImage: data['foto_url'] != null ? NetworkImage(data['foto_url']) : null,
                        child: data['foto_url'] == null ? const Icon(LucideIcons.user, color: AppTheme.textGrey, size: 24) : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome.toUpperCase(), 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (data['modalidade'] is List) 
                                ? (data['modalidade'] as List).join(' | ').toUpperCase() 
                                : (data['modalidade']?.toString().toUpperCase() ?? 'GERAL'),
                              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!temTermo)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(LucideIcons.shieldAlert, color: Colors.orangeAccent, size: 14),
                        ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, 
                          color: statusColor, 
                          boxShadow: [
                            BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)
                          ]
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStudentDossierModal(BuildContext context, DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StudentDossierModal(doc: doc),
    );
  }

  Widget _buildMiniMetric(String label, int current, int target, IconData icon, Color color) {
    final double progresso = (current / (target > 0 ? target : 1)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: AppTheme.textGrey),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(2))),
            LayoutBuilder(
              builder: (context, constraints) => Container(
                height: 4,
                width: constraints.maxWidth * progresso,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('$current / $target', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Future<void> _extractStudentDossier(DocumentSnapshot doc) async {
    setState(() => _isGeneratingPdf = true);
    try {
      await DossiePdfGenerator.generateAndDownload(doc.data() as Map<String, dynamic>, doc.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dossiê gerado com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar dossiê: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }



  String _getModalityIcon(String m) {
    final lower = m.toLowerCase();
    if (lower.contains('jiu') || lower.contains('judo') || lower.contains('karate')) return '🥋';
    if (lower.contains('box') || lower.contains('muay') || lower.contains('kick')) return '🥊';
    if (lower.contains('funcional') || lower.contains('cross')) return '🏋️';
    if (lower.contains('mma')) return '🤼';
    return '🎯';
  }

  Widget _buildIndividualFinanceSection(DocumentSnapshot studentDoc) {
    final data = studentDoc.data() as Map<String, dynamic>? ?? {};
    final financeiro = data['financeiro'] as Map<String, dynamic>? ?? {};
    final status = financeiro['status']?.toString().toLowerCase() ?? 'pendente';
    final isPago = status == 'pago';

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      opacity: 0.1,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('STATUS FINANCEIRO', style: TextStyle(color: AppTheme.textGrey, fontSize: 8, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(isPago ? 'PAGO' : 'PENDENTE', style: TextStyle(color: isPago ? Colors.green : Colors.red, fontWeight: FontWeight.w900)),
            ],
          ),
          ElevatedButton(
            onPressed: () async {
               final nextStatus = isPago ? 'pendente' : 'pago';
               await studentDoc.reference.update({
                 'financeiro.status': nextStatus,
                 'financeiro.data_pagamento': nextStatus == 'pago' ? Timestamp.now() : null,
               });
            },
            style: ElevatedButton.styleFrom(backgroundColor: isPago ? Colors.redAccent : Colors.green, foregroundColor: Colors.white, minimumSize: const Size(100, 32)),
            child: Text(isPago ? 'REVERTER' : 'PAGAR', style: const TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequenciaBadge(int total) {
    final color = total >= 20 ? Colors.orangeAccent : (total >= 10 ? Colors.greenAccent : AppTheme.textGrey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text('🔥 $total', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoField(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textGrey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: AppTheme.textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  void _showTermoVisualizer(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Column(
          children: [
            AppBar(
              backgroundColor: AppTheme.backgroundBlack,
              title: Text('DOJO V15 - GOLPE DE MISERICÓRDIA: ${_getName(data)}', style: const TextStyle(color: Colors.white, fontSize: 16)),
              leading: IconButton(icon: const Icon(LucideIcons.x, color: Colors.white), onPressed: () => Navigator.pop(context)),
              actions: [
                IconButton(
                  icon: const Icon(LucideIcons.share2, color: AppTheme.accentGold),
                  onPressed: () async {
                    final pdfBytes = await TermoPdfGenerator.generatePdf(data);
                    await Printing.sharePdf(bytes: pdfBytes, filename: 'termo_${data['dados_pessoais']?['nome']}.pdf');
                  },
                ),
              ],
            ),
            Expanded(child: PdfPreview(build: (format) => TermoPdfGenerator.generatePdf(data), useActions: false, loadingWidget: const Center(child: CircularProgressIndicator(color: AppTheme.accentGold)))),
          ],
        ),
      ),
    );
  }

  String _getName(Map<String, dynamic> d) {
    final personal = d['dados_pessoais'] as Map<String, dynamic>?;
    final candidates = [
      personal?['nome'],
      d['nome'],
      d['aluno_nome'],
      d['display_name'],
      d['displayName'],
    ];
    for (var c in candidates) {
      if (c != null && c.toString().trim().isNotEmpty && c.toString().toLowerCase() != 'atleta') {
        return c.toString();
      }
    }
    return 'Nome Pendente';
  }

  String _getPhone(Map<String, dynamic> d) {
    final personal = d['dados_pessoais'] as Map<String, dynamic>?;
    final candidates = [
      personal?['telefone'],
      d['telefone'],
      d['whatsapp'],
    ];
    for (var c in candidates) {
      if (c != null && c.toString().trim().isNotEmpty) return c.toString();
    }
    return '---';
  }

  void _showConfirmationDialog(BuildContext context, String alunoId, String action) {
    final bool isDelete = action == 'excluir';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDarkGrey,
        title: Text(isDelete ? 'EXCLUIR?' : 'Desativar?', style: const TextStyle(color: Colors.white)),
        content: Text(isDelete ? 'Ação irreversível.' : 'O aluno perderá acesso.', style: const TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDelete ? Colors.red : AppTheme.accentGold),
            onPressed: () async {
              Navigator.pop(ctx);
              if (isDelete) {
                await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(alunoId).delete();
              } else {
                await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(alunoId).update({'status': 'inativo'});
              }
            },
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // MODAL DE DETALHES COMPLETOS DO ALUNO
  // ═══════════════════════════════════════════════════════
  void _showStudentDetailModal(BuildContext context, DocumentSnapshot doc, bool apto, int totalAulas, bool isConveniado, bool isPago) {
    final data = doc.data() as Map<String, dynamic>;
    final personal = data['dados_pessoais'] as Map<String, dynamic>? ?? {};
    final endereco = data['endereco'] as Map<String, dynamic>? ?? {};
    final saude = data['saude_emergencia'] ?? data['saude'] as Map<String, dynamic>? ?? {};
    final financeiro = data['financeiro'] as Map<String, dynamic>? ?? {};

    final String nome = (data['dados_pessoais']?['nome'] ?? data['nome'] ?? 'Sem nome').toString();
    final String nascimento = personal['nascimento'] as String? ?? data['nascimento'] as String? ?? 'Não informado';
    final String fotoUrl = personal['foto_url'] as String? ?? data['foto_url'] as String? ?? '';
    final String statusInfo = isConveniado ? 'CONVENIADO' : (isPago ? 'PAGO' : 'PENDENTE');
    
    final dynamic rawPeso = personal['peso'] ?? data['peso'];
    final dynamic rawAltura = personal['altura'] ?? data['altura'];
    final String peso = rawPeso != null ? '$rawPeso kg' : 'Não informado';
    final String altura = rawAltura != null ? '$rawAltura m' : 'Não informado';

    final dynamic modRaw = personal['modalidade'] ?? data['modalidade'];
    final List<String> mods = modRaw is List ? List<String>.from(modRaw) : (modRaw is String ? [modRaw] : ['Geral']);
    final String faixa = personal['faixa'] as String? ?? 'BRANCA';

    final String telefone = (data['dados_pessoais']?['telefone'] ?? data['telefone'] ?? 'Não informado').toString();

    final String emergNome = saude['contatoEmergenciaNome'] as String? ?? '';
    final String emergTel = saude['contatoEmergenciaTel'] as String? ?? '';

    final String logradouro = endereco['logradouro'] as String? ?? '';
    final String numero = endereco['numero'] as String? ?? '';
    final String bairro = endereco['bairro'] as String? ?? '';
    final String cidade = endereco['cidade'] as String? ?? '';
    final String enderecoCompleto = [
      if (logradouro.isNotEmpty) '$logradouro${numero.isNotEmpty ? ", $numero" : ""}',
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) cidade,
    ].join(' - ');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim, secondAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10 * curved.value, sigmaY: 10 * curved.value),
          child: Container(
            color: Colors.black.withValues(alpha: 0.6 * curved.value),
            child: Transform.translate(
              offset: Offset(0, 40 * (1 - curved.value)),
              child: Transform.scale(
                scale: 0.95 + 0.05 * curved.value,
                child: Opacity(opacity: curved.value, child: child),
              ),
            ),
          ),
        );
      },
      pageBuilder: (context, anim, secondAnim) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 750),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDarkGrey.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(LucideIcons.x, color: AppTheme.textGrey),
                            ),
                          ),

                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: CircleAvatar(
                                      radius: 40,
                                      backgroundColor: Colors.black,
                                      backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                                      child: fotoUrl.isEmpty ? const Icon(LucideIcons.user, size: 36, color: AppTheme.textGrey) : null,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(nome, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isConveniado ? Colors.blueAccent.withValues(alpha: 0.2) : (isPago ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(statusInfo, style: TextStyle(color: isConveniado ? Colors.blueAccent : (isPago ? Colors.green : Colors.redAccent), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      if (apto)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                                          ),
                                          child: Column(
                                            children: [
                                              const Text('APTO A EXAME', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                              const Text('V15-GOLPE-MISERICORDIA', style: TextStyle(color: Colors.white24, fontSize: 8)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  _buildFullModalSection(
                                    LucideIcons.user, 'DADOS PESSOAIS',
                                    Row(
                                      children: [
                                        Expanded(child: _buildInfoItem('Nascimento', nascimento, LucideIcons.calendar)),
                                      ],
                                    ),
                                  ),

                                  _buildFullModalSection(
                                    LucideIcons.activity, 'FÍSICO',
                                    Row(
                                      children: [
                                        Expanded(child: _buildInfoItem('Peso', peso, LucideIcons.dumbbell)),
                                        Expanded(child: _buildInfoItem('Altura', altura, LucideIcons.ruler)),
                                      ],
                                    ),
                                  ),

                                  _buildFullModalSection(
                                    LucideIcons.swords, 'TREINO',
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildInfoItem('Faixa Atual', faixa, LucideIcons.award),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 6, runSpacing: 6,
                                          children: mods.map((m) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                            child: Text(m, style: const TextStyle(color: AppTheme.accentGold, fontSize: 11, fontWeight: FontWeight.bold)),
                                          )).toList(),
                                        ),
                                      ],
                                    ),
                                  ),

                                  _buildFullModalSection(
                                    LucideIcons.phone, 'COMUNICAÇÃO',
                                    _buildInfoItem('Telefone / WhatsApp', telefone, LucideIcons.messageCircle, onTap: () {
                                      final num = telefone.replaceAll(RegExp(r'[^0-9]'), '');
                                      if (num.isNotEmpty) url_launcher.launchUrl(Uri.parse('https://wa.me/55$num'));
                                    }, valueColor: Colors.greenAccent),
                                  ),

                                  _buildFullModalSection(
                                    LucideIcons.alertTriangle, 'SEGURANÇA (EMERGÊNCIA)',
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildInfoItem('Contato', emergNome.isNotEmpty ? emergNome : 'Não informado', LucideIcons.userX),
                                        const SizedBox(height: 8),
                                        _buildInfoItem('Telefone', emergTel.isNotEmpty ? emergTel : 'Não informado', LucideIcons.phoneCall, onTap: emergTel.isNotEmpty ? () {
                                          final num = emergTel.replaceAll(RegExp(r'[^0-9]'), '');
                                          url_launcher.launchUrl(Uri.parse('tel:$num'));
                                        } : null, valueColor: Colors.redAccent),
                                      ],
                                    ),
                                    titleColor: Colors.redAccent,
                                  ),

                                  _buildFullModalSection(
                                    LucideIcons.mapPin, 'LOCALIZAÇÃO',
                                    Text(enderecoCompleto.isNotEmpty ? enderecoCompleto : 'Endereço não informado', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13, height: 1.5)),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  const Divider(color: Colors.white10),
                                  
                                  const Text('AÇÕES', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  _buildIndividualFinanceSection(doc),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _ModalActionButton(icon: LucideIcons.pencil, label: 'Editar', color: AppTheme.accentGold, onTap: () {
                                        Navigator.pop(context);
                                        showEditStudentDialog(context, doc); 
                                      }),
                                      _ModalActionButton(icon: LucideIcons.fileText, label: 'Termo PDF', color: Colors.blueAccent, onTap: () => _showTermoVisualizer(context, data)),
                                      _ModalActionButton(icon: LucideIcons.trash2, label: 'Excluir', color: Colors.redAccent, onTap: () {
                                        Navigator.pop(context);
                                        _showConfirmationDialog(context, doc.id, 'excluir');
                                      }),
                                    ],
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullModalSection(IconData icon, String title, Widget child, {Color? titleColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: titleColor ?? AppTheme.textGrey),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: titleColor ?? AppTheme.textGrey, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon, {VoidCallback? onTap, Color? valueColor}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppTheme.textGrey.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w600, decoration: onTap != null ? TextDecoration.underline : null)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _StudentDossierModal extends StatefulWidget {
  final DocumentSnapshot doc;
  const _StudentDossierModal({required this.doc});

  @override
  State<_StudentDossierModal> createState() => _StudentDossierModalState();
}

class _StudentDossierModalState extends State<_StudentDossierModal> {
  bool _isGeneratingPdf = false;
  bool _isEditing = false;
  bool _isSaving = false;

  // Controllers para edição
  late TextEditingController _nomeController;
  late TextEditingController _emailController;
  late TextEditingController _telefoneController;
  late TextEditingController _cpfController;
  late TextEditingController _rgController;
  late TextEditingController _pesoController;
  late TextEditingController _alturaController;
  late TextEditingController _nascimentoController;
  late TextEditingController _mensalidadeController;
  
  // Emergência
  late TextEditingController _emergNomeController;
  late TextEditingController _emergTelController;

  // Endereço
  late TextEditingController _cepController;
  late TextEditingController _ruaController;
  late TextEditingController _numController;
  late TextEditingController _bairroController;
  late TextEditingController _cidadeController;

  Map<String, String> _editingFaixas = {};

  final List<String> _faixas = ['BRANCA', 'CINZA', 'AMARELA', 'LARANJA', 'VERDE', 'AZUL', 'ROXA', 'MARROM', 'PRETA', 'CORAL', 'VERMELHA'];

  Map<String, String> _editingGraus = {}; // [NOVO]

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data() as Map<String, dynamic>? ?? {};
    final personal = data['dados_pessoais'] as Map<String, dynamic>? ?? {};
    final endereco = data['endereco'] as Map<String, dynamic>? ?? {};
    final saude = data['saude_emergencia'] as Map<String, dynamic>? ?? {};
    
    _nomeController = TextEditingController(text: (personal['nome'] ?? data['nome'] ?? '').toString());
    _emailController = TextEditingController(text: (personal['email'] ?? data['email'] ?? '').toString());
    _telefoneController = TextEditingController(text: (personal['telefone'] ?? data['telefone'] ?? '').toString());
    _cpfController = TextEditingController(text: (personal['cpf'] ?? '').toString());
    _rgController = TextEditingController(text: (personal['rg'] ?? '').toString());
    _pesoController = TextEditingController(text: (personal['peso'] ?? '').toString());
    _alturaController = TextEditingController(text: (personal['altura'] ?? '').toString());
    _nascimentoController = TextEditingController(text: (personal['nascimento'] ?? '').toString());
    _mensalidadeController = TextEditingController(text: (data['valor_mensalidade_customizado'] ?? '').toString());
    
    _emergNomeController = TextEditingController(text: (saude['contatoEmergenciaNome'] ?? '').toString());
    _emergTelController = TextEditingController(text: (saude['contatoEmergenciaTel'] ?? '').toString());

    _cepController = TextEditingController(text: (endereco['cep'] ?? '').toString());
    _ruaController = TextEditingController(text: (endereco['logradouro'] ?? '').toString());
    _numController = TextEditingController(text: (endereco['numero'] ?? '').toString());
    _bairroController = TextEditingController(text: (endereco['bairro'] ?? '').toString());
    _cidadeController = TextEditingController(text: (endereco['cidade'] ?? '').toString());

    final currentFaixas = (personal['faixas_por_modalidade'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
    final currentGraus = (personal['graus_por_modalidade'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
    final modalidades = (personal['modalidade'] is List) 
        ? List<String>.from(personal['modalidade']) 
        : (data['modalidade'] is List ? List<String>.from(data['modalidade']) : ['GERAL']);
        
    for (var mod in modalidades) {
      if (mod.isNotEmpty) {
        _editingFaixas[mod] = currentFaixas[mod] ?? personal['faixa'] ?? 'BRANCA';
        _editingGraus[mod] = currentGraus[mod] ?? 'NENHUM';
      }
    }
  }

  int _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return 0;
    try {
      final parts = birthDate.split('/');
      if (parts.length != 3) return 0;
      final birth = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final today = DateTime.now();
      int age = today.year - birth.year;
      if (today.month < birth.month || (today.month == birth.month && today.day < birth.day)) age--;
      return age;
    } catch (e) {
      return 0;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();
    _rgController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    _nascimentoController.dispose();
    _mensalidadeController.dispose();
    _emergNomeController.dispose();
    _emergTelController.dispose();
    _cepController.dispose();
    _ruaController.dispose();
    _numController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>? ?? {};
    final personal = data['dados_pessoais'] as Map<String, dynamic>? ?? {};
    final financeiro = data['financeiro'] as Map<String, dynamic>? ?? {};
    final String nome = personal['nome'] ?? data['nome'] ?? '...';
    final String faixa = personal['faixa'] ?? 'BRANCA';
    final statusFin = (financeiro['status'] ?? 'pendente').toString().toLowerCase();
    final bool isPago = statusFin == 'pago';

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(widget.doc.id).snapshots(),
        builder: (context, studentSnap) {
          if (studentSnap.hasError) return const Center(child: Text('Erro ao carregar dados do aluno', style: TextStyle(color: Colors.red)));
          if (!studentSnap.hasData) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.backgroundBlack,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: const Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
            );
          }

          final profile = UserProfileData.fromFirestore(studentSnap.data!);
          final data = studentSnap.data?.data() as Map<String, dynamic>? ?? {};
          final personal = data['dados_pessoais'] as Map<String, dynamic>? ?? {};
          final financeiro = data['financeiro'] as Map<String, dynamic>? ?? {};
          
          final bool isPago = profile.financialStatus == FinancialState.pago || profile.financialStatus == FinancialState.regularGerenciado;

          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.backgroundBlack,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Colors.white10, width: 1.5)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                // BARRA DE ARRASTE
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 32),

                // HEADER DO DOSSIÊ
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.cardDarkGrey,
                      backgroundImage: data['foto_url'] != null ? NetworkImage(data['foto_url']) : null,
                      child: data['foto_url'] == null ? const Icon(LucideIcons.user, color: AppTheme.textGrey, size: 32) : null,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.nome?.toUpperCase() ?? '...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              BeltBadge(faixa: profile.faixa, isSmall: true),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: (isPago ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(isPago ? 'APROVADO' : 'PENDENTE', style: TextStyle(color: isPago ? Colors.greenAccent : Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isEditing ? _saveChanges : () => setState(() => _isEditing = true),
                      icon: Icon(_isEditing ? LucideIcons.check : LucideIcons.edit, size: 16),
                      label: Text(_isEditing ? 'SALVAR' : 'EDITAR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isEditing ? Colors.greenAccent : AppTheme.cardDarkGrey,
                        foregroundColor: _isEditing ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!_isEditing)
                      ElevatedButton.icon(
                        onPressed: _isGeneratingPdf ? null : () => _exportPdf(data),
                        icon: _isGeneratingPdf ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(LucideIcons.fileText, size: 16),
                        label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                  ],
                ),

                const SizedBox(height: 40),

                // SESSÃO 1: PERFORMANCE (RADIAL PROGRESS)
                const Text('PERFORMANCE DO ATLETA', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 24),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('config').doc('geral').snapshots(),
                  builder: (context, configSnap) {
                    if (configSnap.hasError) return const Center(child: Text('Erro ao carregar configurações', style: TextStyle(color: Colors.red, fontSize: 10)));
                    if (!configSnap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

                    final config = configSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final profile = UserProfileData.fromFirestore(studentSnap.data!);
                    final int metaFisica = profile.resolverMetaExame(config);
                    final int metaKi = profile.resolverMetaKi(config);

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection(FirebaseCollections.frequencia).where('aluno_id', isEqualTo: widget.doc.id).snapshots(),
                      builder: (context, freqSnap) {
                        if (freqSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(color: AppTheme.accentGold, strokeWidth: 2),
                          ));
                        }
                        if (freqSnap.hasError) return const Center(child: Text('Erro ao carregar frequencia', style: TextStyle(color: Colors.red, fontSize: 10)));
                        
                        final checkins = freqSnap.data?.docs ?? [];
                        final aprovados = checkins.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'aprovado').length;
                        
                        // Soma de KI robusta
                        final int currentKi = profile.kiPorModalidade.values.fold(0, (sum, val) => sum + val);

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildRadialProgress('FÍSICO', aprovados, metaFisica, Colors.blueAccent),
                            _buildRadialProgress('TEÓRICO (KI)', currentKi, metaKi, AppTheme.accentGold),
                          ],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 40),

                // SESSÃO 2: DADOS PESSOAIS & CONTATO (GRID)
                const Text('DADOS PESSOAIS & CONTATO', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                  child: Column(
                    children: [
                      if (_isEditing) _buildEditField('NOME COMPLETO', _buildTextInput(_nomeController, 'Nome')),
                      if (_isEditing) const Divider(color: Colors.white10, height: 32),
                      _buildDossierGridRow('NASCIMENTO', _isEditing ? '---' : (personal['nascimento'] ?? '---'), 'IDADE', '${_calculateAge(personal['nascimento'])} ANOS'),
                      if (_isEditing) const SizedBox(height: 12),
                      if (_isEditing) _buildEditField('DATA NASCIMENTO', _buildTextInput(_nascimentoController, 'dd/mm/aaaa')),
                      const Divider(color: Colors.white10, height: 32),
                      Row(
                        children: [
                          Expanded(child: _isEditing 
                            ? _buildEditField('CPF', _buildTextInput(_cpfController, '000.000.000-00'))
                            : _buildDossierField('CPF', _maskCpf(profile.cpf ?? '---'))),
                          const SizedBox(width: 16),
                          Expanded(child: _isEditing 
                            ? _buildEditField('RG', _buildTextInput(_rgController, '00.000.000-0'))
                            : _buildDossierField('RG', profile.rg ?? '---')),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 32),
                      if (_isEditing) ...[
                        const Text('GRADUAÇÕES POR MODALIDADE', style: TextStyle(color: AppTheme.accentGold, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        ..._editingFaixas.keys.map((mod) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(mod.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _editingFaixas[mod],
                                            dropdownColor: AppTheme.backgroundBlack,
                                            isExpanded: true,
                                            style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 12),
                                            menuMaxHeight: 300,
                                            items: _getBeltOptionsFor(mod).map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                            onChanged: (v) => setState(() => _editingFaixas[mod] = v!),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _editingGraus[mod],
                                            dropdownColor: AppTheme.backgroundBlack,
                                            isExpanded: true,
                                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
                                            menuMaxHeight: 300,
                                            items: _getDegreeOptions().map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                            onChanged: (v) => setState(() => _editingGraus[mod] = v!),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ] else ...[
                        _buildDossierField('GRADUAÇÕES', profile.faixasPorModalidade.entries.map((e) {
                          final grau = profile.grausPorModalidade[e.key] ?? 'NENHUM';
                          return '${e.key.toUpperCase()}: ${e.value}${grau != 'NENHUM' ? ' ($grau)' : ''}';
                        }).join(' | ')),
                      ],
                      const Divider(color: Colors.white10, height: 32),
                      const Divider(color: Colors.white10, height: 32),
                      Row(
                        children: [
                          Expanded(child: _isEditing 
                            ? _buildEditField('PESO (KG)', _buildNumericInput(_pesoController, 'kg'))
                            : _buildDossierField('PESO', profile.peso != null ? '${profile.peso} KG' : '---')),
                          const SizedBox(width: 16),
                          Expanded(child: _isEditing 
                            ? _buildEditField('ALTURA (CM)', _buildNumericInput(_alturaController, 'cm'))
                            : _buildDossierField('ALTURA', profile.altura != null ? '${profile.altura} CM' : '---')),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 32),
                      Row(
                        children: [
                          Expanded(child: _isEditing 
                            ? _buildEditField('TELEFONE', _buildTextInput(_telefoneController, '(00) 00000-0000'))
                            : _buildDossierField('TELEFONE', personal['telefone'] ?? '---')),
                          const SizedBox(width: 16),
                          Expanded(child: _isEditing 
                            ? _buildEditField('IDADE', _buildDossierField('', profile.idade != 0 ? '${profile.idade} ANOS' : '---'))
                            : _buildDossierField('IDADE', profile.idade != 0 ? '${profile.idade} ANOS' : '---')),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 32),
                      Row(
                        children: [
                          Expanded(child: _isEditing 
                            ? _buildEditField('CONTATO EMERG.', _buildTextInput(_emergNomeController, 'Nome'))
                            : _buildDossierField('CONTATO EMERG.', profile.contatoEmergenciaNome ?? '---')),
                          const SizedBox(width: 16),
                          Expanded(child: _isEditing 
                            ? _buildEditField('TEL. EMERG.', _buildTextInput(_emergTelController, 'Telefone'))
                            : _buildDossierField('TEL. EMERG.', profile.contatoEmergenciaTel ?? '---')),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 32),
                      _buildDossierField('VALOR MENSALIDADE', 
                        profile.valorMensalidadeCustomizado != null 
                          ? 'R\$ ${profile.valorMensalidadeCustomizado!.toStringAsFixed(2)} (CUSTOM)'
                          : 'PADRÃO (MODALIDADE)'),
                      const Divider(color: Colors.white10, height: 32),
                      _buildDossierField('ENDEREÇO RESIDENCIAL', 
                        _isEditing ? 'EDITANDO CAMPOS ABAIXO' : '${data['endereco']?['logradouro'] ?? ''}, ${data['endereco']?['numero'] ?? ''} - ${data['endereco']?['bairro'] ?? ''}\n${data['endereco']?['cidade'] ?? ''} / ${data['endereco']?['cep'] ?? ''}'),
                      if (_isEditing) ...[
                        const SizedBox(height: 12),
                        _buildEditField('CEP', _buildTextInput(_cepController, '00000-000')),
                        const SizedBox(height: 8),
                        _buildEditField('LOGRADOURO', _buildTextInput(_ruaController, 'Rua/Av')),
                        const SizedBox(height: 8),
                        _buildEditField('NÚMERO', _buildTextInput(_numController, 'Nº')),
                        const SizedBox(height: 8),
                        _buildEditField('BAIRRO', _buildTextInput(_bairroController, 'Bairro')),
                        const SizedBox(height: 8),
                        _buildEditField('CIDADE', _buildTextInput(_cidadeController, 'Cidade')),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // HALL DA FAMA
                const Text('HALL DA FAMA 🏆', style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDarkGrey,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAchievementItem(LucideIcons.medal, 'MEDALHAS', profile.carreira.medalhas, Colors.blueAccent),
                      _buildAchievementItem(LucideIcons.award, 'TROFÉUS', profile.carreira.trofeus, AppTheme.accentGold),
                      _buildAchievementItem(LucideIcons.crown, 'CINTURÕES', profile.carreira.cinturoes, Colors.orangeAccent),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // DOCUMENTAÇÃO & LGPD
                const Text('DOCUMENTAÇÃO & LGPD', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _downloadLgpd(
                    data['termo_assinado_url'] ?? data['termos_matricula']?['urlTermoPdf'], 
                    profile
                  ),
                  icon: const Icon(LucideIcons.shieldCheck, size: 16),
                  label: const Text('BAIXAR TERMO DE RESPONSABILIDADE / LGPD'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 32),

                // SESSÃO 3: STATUS FINANCEIRO
                const Text('GESTÃO FINANCEIRA', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [isPago ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1), Colors.transparent]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: (isPago ? Colors.green : Colors.red).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(isPago ? LucideIcons.checkCircle : LucideIcons.alertCircle, color: isPago ? Colors.greenAccent : Colors.redAccent),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('SITUAÇÃO FINANCEIRA', style: TextStyle(color: AppTheme.textGrey, fontSize: 8, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(isPago ? 'MENSALIDADE EM DIA' : 'PENDÊNCIA FINANCEIRA IDENTIFICADA', style: TextStyle(color: isPago ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_isEditing) ...[
                        const Divider(color: Colors.white10, height: 32),
                        _buildEditField('MENSALIDADE CUSTOMIZADA (R\$)', TextField(
                          controller: _mensalidadeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(hintText: 'Ex: 150.00', hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                        )),
                        const Text('Se preenchido, este valor sobrescreve o padrão global para este aluno.', style: TextStyle(color: AppTheme.accentGold, fontSize: 9, fontStyle: FontStyle.italic)),
                      ] else if (data['valor_mensalidade_customizado'] != null) ...[
                        const SizedBox(height: 12),
                        Text('VALOR CUSTOMIZADO: R\$ ${data['valor_mensalidade_customizado']}', style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // SESSÃO 4: HISTÓRICO DE PAGAMENTOS
                const Text('HISTÓRICO DE LANÇAMENTOS', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection(FirebaseCollections.pagamentos).where('aluno_id', isEqualTo: widget.doc.id).snapshots(),
                  builder: (context, paySnap) {
                    if (!paySnap.hasData || paySnap.data!.docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(16)),
                        child: const Text('Nenhum pagamento registrado no histórico.', style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                      );
                    }
                    final allDocs = paySnap.data!.docs.toList();
                    allDocs.sort((a, b) {
                      final aDate = (a.data() as Map<String, dynamic>)['data_vencimento'];
                      final bDate = (b.data() as Map<String, dynamic>)['data_vencimento'];
                      if (aDate == null && bDate == null) return 0;
                      if (aDate == null) return 1;
                      if (bDate == null) return -1;
                      if (aDate is Timestamp && bDate is Timestamp) return bDate.compareTo(aDate);
                      return 0;
                    });
                    final displayDocs = allDocs.take(5).toList();
                    return Column(
                      children: displayDocs.map((p) {
                        final pData = p.data() as Map<String, dynamic>;
                        final pStatus = (pData['status'] ?? 'Pendente').toString().toLowerCase();
                        final bool isPaid = pStatus == 'pago';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Icon(LucideIcons.receipt, color: isPaid ? Colors.greenAccent : AppTheme.textGrey, size: 16),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pData['referencia'] ?? 'MENSALIDADE', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text('Vencimento: ${pData['data_vencimento'] != null ? DateFormat('dd/MM/yy').format((pData['data_vencimento'] as dynamic).toDate()) : '---'}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 9)),
                                  ],
                                ),
                              ),
                              Text('R\$ ${pData['valor'] ?? '0,00'}', style: TextStyle(color: isPaid ? Colors.greenAccent : Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRadialProgress(String label, int current, int target, Color color) {
    final double pct = (current / (target > 0 ? target : 1)).clamp(0.0, 1.0);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80, height: 80,
              child: CircularProgressIndicator(value: 1.0, strokeWidth: 8, color: Colors.white.withValues(alpha: 0.05)),
            ),
            SizedBox(
              width: 80, height: 80,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 8,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text('${(pct * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.bold)),
        Text('$current/$target', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDossierGridRow(String l1, String v1, String l2, String v2) {
    return Row(
      children: [
        Expanded(child: _buildDossierField(l1, v1)),
        const SizedBox(width: 16),
        Expanded(child: _buildDossierField(l2, v2)),
      ],
    );
  }

  Widget _buildDossierField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
        if (label.isNotEmpty) const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  List<String> _getBeltOptionsFor(String mod) {
    final m = mod.toUpperCase();
    if (m.contains('JIU')) {
      return ['BRANCA', 'CINZA', 'AMARELA', 'LARANJA', 'VERDE', 'AZUL', 'ROXA', 'MARROM', 'PRETA', 'CORAL', 'VERMELHA'];
    }
    if (m.contains('KARATE') || m.contains('KARATÊ')) {
      return ['BRANCA', 'AMARELA', 'VERMELHA', 'LARANJA', 'VERDE', 'ROXA', 'MARROM', 'PRETA'];
    }
    if (m.contains('JUDO') || m.contains('JUDÔ')) {
      return ['BRANCA', 'CINZA', 'AZUL', 'AMARELA', 'LARANJA', 'VERDE', 'ROXA', 'MARROM', 'PRETA'];
    }
    if (m.contains('KICK') || m.contains('MUAY') || m.contains('BOXE')) {
      return ['BRANCA', 'AMARELA', 'LARANJA', 'VERDE', 'AZUL', 'ROXA', 'MARROM', 'PRETA'];
    }
    // Unificado/Global fallback
    return _faixas;
  }

  List<String> _getDegreeOptions() {
    return ['NENHUM', '1º GRAU/DAN', '2º GRAU/DAN', '3º GRAU/DAN', '4º GRAU/DAN', '5º GRAU/DAN', '6º GRAU/DAN', '7º GRAU/DAN', '8º GRAU/DAN', '9º GRAU/DAN', '10º GRAU/DAN'];
  }

  Widget _buildAchievementItem(IconData icon, String label, int value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value.toString(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 8, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _maskCpf(String cpf) {
    if (cpf == '---' || cpf.length < 11) return cpf;
    final clean = cpf.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 11) return cpf;
    return "${clean.substring(0, 3)}.${clean.substring(3, 6)}.${clean.substring(6, 9)}-${clean.substring(9)}";
  }

  Widget _buildEditField(String label, Widget input) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.accentGold, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        input,
      ],
    );
  }

  Widget _buildNumericInput(TextEditingController controller, String suffix) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      decoration: InputDecoration(
        suffixText: suffix,
        suffixStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
        border: InputBorder.none,
        isDense: true,
      ),
    );
  }

  Widget _buildTextInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white10, fontSize: 10),
        border: InputBorder.none,
        isDense: true,
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final ref = FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(widget.doc.id);

      batch.update(ref, {
        'dados_pessoais.nome': _nomeController.text.trim(),
        'dados_pessoais.email': _emailController.text.trim(),
        'dados_pessoais.telefone': _telefoneController.text.trim(),
        'dados_pessoais.cpf': _cpfController.text.trim(),
        'dados_pessoais.rg': _rgController.text.trim(),
        'dados_pessoais.cpf_rg': '${_cpfController.text.trim()} / ${_rgController.text.trim()}',
        'dados_pessoais.peso': _pesoController.text.trim(),
        'dados_pessoais.altura': _alturaController.text.trim(),
        'dados_pessoais.nascimento': _nascimentoController.text.trim(),
        'dados_pessoais.faixas_por_modalidade': _editingFaixas,
        'dados_pessoais.graus_por_modalidade': _editingGraus,
        'dados_pessoais.faixa': _editingFaixas.values.isNotEmpty ? _editingFaixas.values.first : 'BRANCA',
        
        'saude_emergencia.contatoEmergenciaNome': _emergNomeController.text.trim(),
        'saude_emergencia.contatoEmergenciaTel': _emergTelController.text.trim(),

        'endereco.cep': _cepController.text.trim(),
        'endereco.logradouro': _ruaController.text.trim(),
        'endereco.numero': _numController.text.trim(),
        'endereco.bairro': _bairroController.text.trim(),
        'endereco.cidade': _cidadeController.text.trim(),

        'valor_mensalidade_customizado': _mensalidadeController.text.isEmpty ? null : _mensalidadeController.text,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dossiê atualizado com sucesso!'), backgroundColor: Colors.green));
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar dossiê: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _downloadLgpd(String? url, UserProfileData profile) async {
    // 1. Tentar gerar localmente se tivermos a assinatura (Arquitetura On-The-Fly solicitada)
    if (profile.assinaturaBase64 != null || profile.urlAssinaturaImgbb != null) {
      setState(() => _isSaving = true);
      try {
        Uint8List? signatureBytes;
        if (profile.assinaturaBase64 != null) {
          signatureBytes = base64Decode(profile.assinaturaBase64!);
        } else if (profile.urlAssinaturaImgbb != null) {
          final response = await http.get(Uri.parse(profile.urlAssinaturaImgbb!));
          if (response.statusCode == 200) signatureBytes = response.bodyBytes;
        }

        if (signatureBytes != null) {
          final pdfData = {
            'uid': profile.uid,
            'nome': profile.nome,
            'cpf': profile.cpf,
            'rg': profile.rg,
            'idade': profile.idade,
            'nascimento': profile.nascimento,
            'signatureBytes': signatureBytes,
            'dataAssinatura': Timestamp.now(),
          };
          final pdfBytes = await TermoPdfGenerator.generatePdf(pdfData);
          await Printing.sharePdf(bytes: pdfBytes, filename: 'Termo_LGPD_${profile.nome}.pdf');
          return;
        }
      } catch (e) {
        debugPrint('Erro na geração local de PDF: $e');
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }

    // 2. Fallback para URL existente no Storage ou Upload Manual
    if (url == null || url.isEmpty) {
      // Opção de Upload Manual se não existir o termo
      final bool? upload = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardDarkGrey,
          title: const Text('Termo não encontrado', style: TextStyle(color: Colors.white)),
          content: const Text('Deseja fazer o upload manual de um ficheiro PDF para este aluno?', style: TextStyle(color: AppTheme.textGrey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('FAZER UPLOAD')),
          ],
        ),
      );

      if (upload == true) {
        final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
        if (result != null && result.files.isNotEmpty) {
          setState(() => _isSaving = true);
          try {
            final bytes = result.files.first.bytes!;
            final path = 'documentos/termos_assinados/${widget.doc.id}_manual_${DateTime.now().millisecondsSinceEpoch}.pdf';
            final downloadUrl = await FirebaseStorageService.uploadPdf(bytes, path);
            
            if (downloadUrl != null) {
              await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(widget.doc.id).update({
                'termo_assinado_url': downloadUrl,
                'termos_matricula.urlTermoPdf': downloadUrl,
                'termos_matricula.upload_manual': true,
              });
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Termo carregado com sucesso!'), backgroundColor: Colors.green));
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no upload: $e'), backgroundColor: Colors.red));
          } finally {
            if (mounted) setState(() => _isSaving = false);
          }
        }
      }
      return;
    }
    await url_launcher.launchUrl(Uri.parse(url), mode: url_launcher.LaunchMode.externalApplication);
  }

  Future<void> _exportPdf(Map<String, dynamic> data) async {
    setState(() => _isGeneratingPdf = true);
    try {
      // Busca histórico financeiro real para o PDF (Últimas 12 transações conforme OS)
      final paySnap = await FirebaseFirestore.instance
          .collection(FirebaseCollections.pagamentos)
          .where('aluno_id', isEqualTo: widget.doc.id)
          .get();

      final allDocs = paySnap.docs.toList();
      allDocs.sort((a, b) {
        final aDate = a.data()['data_vencimento'];
        final bDate = b.data()['data_vencimento'];
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        if (aDate is Timestamp && bDate is Timestamp) return bDate.compareTo(aDate);
        return 0;
      });

      final limitedDocs = allDocs.take(12).toList();

      final List<Map<String, dynamic>> history = limitedDocs.map((d) {
        final pData = d.data();
        return {
          'referencia': pData['referencia'],
          'status': pData['status'],
          'valor': pData['valor'],
          'dataPagamento': pData['data_pagamento'] != null ? (pData['data_pagamento'] as dynamic).toDate() : null,
        };
      }).toList();

      await DossiePdfGenerator.generateAndDownload(
        data, 
        widget.doc.id,
        paymentHistory: history,
      );
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dossiê exportado com sucesso!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exportar PDF: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }
}



class _ModalActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModalActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
