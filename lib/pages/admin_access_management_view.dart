import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/firebase_collections.dart';
import '../core/theme/app_theme.dart';
import '../widgets/glass_container.dart';

/// Central de moderação de acesso de alunos.
///
/// Exibe todos os alunos com filtros de status:
///   TODOS · PENDENTES · APROVADOS · BLOQUEADOS
///
/// Cada card tem ação de 1-clique reversível:
///   Pendente  → [Aprovar] / [Negar]
///   Ativo     → [Revogar]
///   Bloqueado → [Reativar]
class AdminAccessManagementView extends StatefulWidget {
  const AdminAccessManagementView({super.key});

  @override
  State<AdminAccessManagementView> createState() =>
      _AdminAccessManagementViewState();
}

class _AdminAccessManagementViewState
    extends State<AdminAccessManagementView> {
  /// null = TODOS
  String? _filterStatus;

  static const _filters = [
    (null, 'TODOS', AppTheme.accentGold),
    ('pendente', 'PENDENTES', Colors.amber),
    ('aprovado', 'APROVADOS', Colors.greenAccent),
    ('bloqueado', 'BLOQUEADOS', Colors.redAccent),
  ];

  Future<void> _updateStatus(DocumentReference ref, String newStatus) async {
    // Mantém compatibilidade com status_acesso para controle de permissões
    final statusAcesso = newStatus == 'aprovado' ? 'ativo' : newStatus;
    await ref.update({
      'status': newStatus,
      'status_acesso': statusAcesso,
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ativo':
      case 'aprovado':
        return Colors.greenAccent;
      case 'bloqueado':
        return Colors.redAccent;
      default:
        return Colors.amber;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'ativo':
      case 'aprovado':
        return LucideIcons.shieldCheck;
      case 'bloqueado':
        return LucideIcons.shieldOff;
      default:
        return LucideIcons.clock;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ativo':
      case 'aprovado':
        return 'APROVADO';
      case 'bloqueado':
        return 'BLOQUEADO';
      default:
        return 'PENDENTE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(LucideIcons.shieldCheck,
                    color: AppTheme.accentGold, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GESTÃO DE ACESSO',
                        style: TextStyle(
                          color: AppTheme.accentGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Moderação de Alunos (V5-FINAL-RECKONING)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Contador de pendentes em tempo real
                _PendingCounter(),
              ],
            ),

            const SizedBox(height: 20),

            // Filtros de status
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _filters.map((f) {
                  final (status, label, color) = f;
                  final isSelected = _filterStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filterStatus = status),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.15)
                              : AppTheme.glassBg,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: isSelected
                                ? color.withValues(alpha: 0.6)
                                : AppTheme.glassBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? color : AppTheme.textGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Lista de alunos
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('ALUNOS').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          '🚨 ERRO DE INFRAESTRUTURA (V5): ${snapshot.error}\n\n[Nota: Query sem filtros. Se o erro cita "users", há um sequestro no Firebase.]',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
                  }

                  // FILTRAGEM E ORDENAÇÃO MANUAL (SCORCHED EARTH)
                  var docs = snapshot.data?.docs ?? [];
                  
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final role = data['role']?.toString().toLowerCase() ?? '';
                    
                    // Extração robusta do status com fallback para legado
                    String statusValue = data['status']?.toString().toLowerCase() ?? '';
                    final statusAcesso = data['status_acesso']?.toString().toLowerCase() ?? '';
                    
                    if (statusValue.isEmpty) {
                      if (statusAcesso == 'ativo') statusValue = 'aprovado';
                      else if (statusAcesso == 'pendente') statusValue = 'pendente';
                      else if (statusAcesso == 'bloqueado') statusValue = 'bloqueado';
                    }
                    
                    if (role != 'aluno') return false;
                    
                    if (_filterStatus != null) {
                      return statusValue == _filterStatus;
                    }
                    return true;
                  }).toList();

                  filteredDocs.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final dateA = (dataA['created_at'] as Timestamp?)?.toDate() ?? DateTime(2000);
                    final dateB = (dataB['created_at'] as Timestamp?)?.toDate() ?? DateTime(2000);
                    return dateB.compareTo(dateA);
                  });

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _filterStatus == 'pendente'
                                ? LucideIcons.checkCircle
                                : LucideIcons.users,
                            size: 48,
                            color: AppTheme.textGrey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filterStatus == 'pendente'
                                ? 'Nenhum aluno pendente. ✓'
                                : 'Nenhum aluno encontrado.',
                            style: const TextStyle(
                                color: AppTheme.textGrey, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 900;
                      if (isDesktop) {
                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 500,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 100,
                          ),
                          itemCount: filteredDocs.length,
                          itemBuilder: (_, i) => _buildStudentRow(filteredDocs[i]),
                        );
                      }
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredDocs.length,
                        itemBuilder: (_, i) => _buildStudentRow(filteredDocs[i]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MODAL DE DETALHES DO ALUNO
  // ═══════════════════════════════════════════════════════════

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

  void _showStudentDetailModal(BuildContext context, Map<String, dynamic> data) {
    final personal = data['dados_pessoais'] as Map<String, dynamic>? ?? {};
    final endereco = data['endereco'] as Map<String, dynamic>? ?? {};
    final saude = data['saude_emergencia'] as Map<String, dynamic>? ?? {};
    final financeiro = data['financeiro'] as Map<String, dynamic>? ?? {};

    final String nome = _getName(data);
    final String email = (data['dados_pessoais']?['email'] ?? data['email'] ?? '').toString();
    final String telefone = _getPhone(data);
    final String nascimento = personal['nascimento'] as String? ?? data['nascimento'] as String? ?? 'Não informado';
    final String cpfRg = personal['cpf_rg'] as String? ?? '';
    final String faixa = personal['faixa'] as String? ?? 'BRANCA';
    final String aptidao = personal['status_aptidao'] as String? ?? '';
    final String fotoUrl = personal['foto_url'] as String? ?? data['foto_url'] as String? ?? '';
    final dynamic modRaw = personal['modalidade'] ?? data['modalidade'];
    final List<String> mods = modRaw is List ? List<String>.from(modRaw) : (modRaw is String ? [modRaw] : ['Geral']);
    final String status = data['status_acesso'] as String? ?? 'ativo';
    final color = _statusColor(status);

    // Endereço
    final String logradouro = endereco['logradouro'] as String? ?? '';
    final String numero = endereco['numero'] as String? ?? '';
    final String bairro = endereco['bairro'] as String? ?? '';
    final String cidade = endereco['cidade'] as String? ?? '';
    final String uf = endereco['uf'] as String? ?? '';
    final String cep = endereco['cep'] as String? ?? '';
    final String complemento = endereco['complemento'] as String? ?? '';
    final String enderecoCompleto = [
      if (logradouro.isNotEmpty) '$logradouro${numero.isNotEmpty ? ", $numero" : ""}',
      if (complemento.isNotEmpty) complemento,
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) '$cidade${uf.isNotEmpty ? " - $uf" : ""}',
      if (cep.isNotEmpty) 'CEP: $cep',
    ].join('\n');

    // Emergência
    final String emergNome = saude['contatoEmergenciaNome'] as String? ?? '';
    final String emergTel = saude['contatoEmergenciaTel'] as String? ?? '';
    final String parentesco = saude['parentesco'] as String? ?? '';
    final String convenio = saude['nome_convenio'] as String? ?? 'Nenhum';
    final String lesoes = saude['historico_lesoes'] as String? ?? '';

    // Financeiro
    final String statusPgto = financeiro['statusPagamento'] as String? ?? '';

    // Cor da faixa para glow neon
    final faixaColor = _beltColor(faixa);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar detalhes',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim, secondAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 5 * curved.value,
            sigmaY: 5 * curved.value,
          ),
          child: Container(
            color: Colors.black.withValues(alpha: 0.7 * curved.value),
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - curved.value)),
              child: Transform.scale(
                scale: 0.95 + 0.05 * curved.value,
                child: Opacity(
                  opacity: curved.value,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      pageBuilder: (context, anim, secondAnim) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF191919).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Close button row ──
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(LucideIcons.x, color: AppTheme.textGrey, size: 20),
                              splashRadius: 20,
                            ),
                          ),

                          // ── Scrollable content ──
                          Flexible(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // ═════ HEADER ═════
                                  // Avatar grande
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.cardDarkGrey,
                                      image: fotoUrl.isNotEmpty
                                          ? DecorationImage(image: NetworkImage(fotoUrl), fit: BoxFit.cover)
                                          : null,
                                      border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
                                      boxShadow: [
                                        BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2),
                                      ],
                                    ),
                                    child: fotoUrl.isEmpty
                                        ? const Icon(LucideIcons.user, color: AppTheme.textGrey, size: 36)
                                        : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // Nome
                                  Text(
                                    nome,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Status + Faixa badges
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Status badge
                                      _ModalBadge(
                                        icon: _statusIcon(status),
                                        label: _statusLabel(status),
                                        color: color,
                                      ),
                                      const SizedBox(width: 8),
                                      // Faixa badge com glow neon
                                      _ModalBadge(
                                        icon: LucideIcons.award,
                                        label: faixa,
                                        color: faixaColor,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (aptidao.isNotEmpty)
                                    Text(aptidao, style: TextStyle(color: aptidao == 'Apto' ? Colors.greenAccent : Colors.amber, fontSize: 11, fontWeight: FontWeight.w700)),

                                  const SizedBox(height: 20),

                                  // ═════ MODALIDADES ═════
                                  _ModalSection(
                                    icon: LucideIcons.swords,
                                    title: 'MODALIDADES',
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: mods.map((m) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentGold.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(50),
                                          border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(m, style: const TextStyle(color: AppTheme.accentGold, fontSize: 11, fontWeight: FontWeight.w900)),
                                      )).toList(),
                                    ),
                                  ),

                                  // ═════ DADOS PESSOAIS ═════
                                  _ModalSection(
                                    icon: LucideIcons.user,
                                    title: 'DADOS PESSOAIS',
                                    child: Column(
                                      children: [
                                        if (nascimento.isNotEmpty) _InfoRow(icon: LucideIcons.calendar, label: 'Nascimento', value: nascimento),
                                        if (cpfRg.isNotEmpty) _InfoRow(icon: LucideIcons.fingerprint, label: 'CPF/RG', value: cpfRg),
                                      ],
                                    ),
                                  ),

                                  // ═════ CONTATO ═════
                                  _ModalSection(
                                    icon: LucideIcons.phone,
                                    title: 'CONTATO',
                                    child: Column(
                                      children: [
                                        if (telefone.isNotEmpty)
                                          _InfoRow(
                                            icon: LucideIcons.messageCircle,
                                            label: 'Telefone',
                                            value: telefone,
                                            onTap: () {
                                              final cleanPhone = telefone.replaceAll(RegExp(r'[^0-9]'), '');
                                              launchUrl(Uri.parse('https://wa.me/55$cleanPhone'));
                                            },
                                            actionColor: Colors.greenAccent,
                                          ),
                                        if (email.isNotEmpty) _InfoRow(icon: LucideIcons.mail, label: 'E-mail', value: email),
                                      ],
                                    ),
                                  ),

                                  // ═════ ENDEREÇO ═════
                                  if (enderecoCompleto.trim().isNotEmpty)
                                    _ModalSection(
                                      icon: LucideIcons.mapPin,
                                      title: 'ENDEREÇO',
                                      child: Text(
                                        enderecoCompleto,
                                        style: const TextStyle(color: AppTheme.textGrey, fontSize: 12, height: 1.5),
                                      ),
                                    ),

                                  // ═════ EMERGÊNCIA ═════
                                  if (emergNome.isNotEmpty || emergTel.isNotEmpty)
                                    _ModalSection(
                                      icon: LucideIcons.alertTriangle,
                                      title: 'CONTATO DE EMERGÊNCIA',
                                      titleColor: Colors.redAccent,
                                      child: Column(
                                        children: [
                                          if (emergNome.isNotEmpty)
                                            _InfoRow(
                                              icon: LucideIcons.userCheck,
                                              label: emergNome,
                                              value: parentesco.isNotEmpty ? '($parentesco)' : '',
                                              valueColor: AppTheme.textGrey,
                                            ),
                                          if (emergTel.isNotEmpty)
                                            _InfoRow(
                                              icon: LucideIcons.phoneCall,
                                              label: 'Tel. Emergência',
                                              value: emergTel,
                                              onTap: () {
                                                final cleanPhone = emergTel.replaceAll(RegExp(r'[^0-9]'), '');
                                                launchUrl(Uri.parse('tel:+55$cleanPhone'));
                                              },
                                              actionColor: Colors.redAccent,
                                            ),
                                        ],
                                      ),
                                    ),

                                  // ═════ SAÚDE ═════
                                  if (convenio != 'Nenhum' || lesoes.isNotEmpty)
                                    _ModalSection(
                                      icon: LucideIcons.heartPulse,
                                      title: 'SAÚDE',
                                      child: Column(
                                        children: [
                                          if (convenio != 'Nenhum') _InfoRow(icon: LucideIcons.building2, label: 'Convênio', value: convenio),
                                          if (lesoes.isNotEmpty) _InfoRow(icon: LucideIcons.activity, label: 'Lesões', value: lesoes),
                                        ],
                                      ),
                                    ),

                                  // ═════ FINANCEIRO ═════
                                  if (statusPgto.isNotEmpty)
                                    _ModalSection(
                                      icon: LucideIcons.banknote,
                                      title: 'FINANCEIRO',
                                      child: _InfoRow(
                                        icon: LucideIcons.creditCard,
                                        label: 'Pagamento',
                                        value: statusPgto.toUpperCase(),
                                        valueColor: statusPgto == 'pendente' ? Colors.amber : Colors.greenAccent,
                                      ),
                                    ),
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

  Color _beltColor(String faixa) {
    switch (faixa.toUpperCase()) {
      case 'BRANCA': return Colors.white;
      case 'CINZA': return Colors.grey;
      case 'AMARELA': return Colors.yellow;
      case 'LARANJA': return Colors.orange;
      case 'VERDE': return Colors.green;
      case 'AZUL': return Colors.blue;
      case 'ROXA': return Colors.purple;
      case 'MARROM': return const Color(0xFF8B4513);
      case 'PRETA': return const Color(0xFFCC0000);
      case 'CORAL': return Colors.pinkAccent;
      default: return AppTheme.textGrey;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // CARD DO ALUNO (Row na lista)
  // ═══════════════════════════════════════════════════════════

  Widget _buildStudentRow(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final personal = data['dados_pessoais'] as Map<String, dynamic>?;
    final String nome = _getName(data);
    final dynamic modRaw = personal?['modalidade'] ?? data['modalidade'];
    final List<String> mods = modRaw is List
        ? List<String>.from(modRaw)
        : (modRaw is String ? [modRaw] : ['Geral']);
    final String fotoUrl = personal?['foto_url'] as String? ??
        data['foto_url'] as String? ??
        '';
    // Extração robusta do status para o card
    String status = data['status']?.toString().toLowerCase() ?? '';
    final String statusAcesso = data['status_acesso']?.toString().toLowerCase() ?? '';
    
    if (status.isEmpty) {
      if (statusAcesso == 'ativo') status = 'aprovado';
      else if (statusAcesso == 'pendente') status = 'pendente';
      else if (statusAcesso == 'bloqueado') status = 'bloqueado';
      else status = 'pendente'; // Fallback final
    }
    
    final color = _statusColor(status);

    return GestureDetector(
      onTap: () => _showStudentDetailModal(context, data),
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        borderRadius: 20,
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cardDarkGrey,
                image: fotoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(fotoUrl), fit: BoxFit.cover)
                    : null,
                border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
              ),
              child:
                  fotoUrl.isEmpty ? const Icon(LucideIcons.user, color: AppTheme.textGrey, size: 20) : null,
            ),

            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: color.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon(status), size: 9, color: color),
                            const SizedBox(width: 4),
                            Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          mods.join(', '),
                          style: const TextStyle(
                              color: AppTheme.textGrey, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons — 1 clique, sem dialog
            _buildActionButtons(doc, status),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(DocumentSnapshot doc, String currentStatus) {
    if (currentStatus == 'pendente') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionBtn(
            icon: LucideIcons.check,
            color: Colors.greenAccent,
            tooltip: 'Aprovar',
            onTap: () => _updateStatus(doc.reference, 'aprovado'),
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            icon: LucideIcons.x,
            color: Colors.redAccent,
            tooltip: 'Negar',
            onTap: () => _updateStatus(doc.reference, 'bloqueado'),
          ),
        ],
      );
    } else if (currentStatus == 'ativo') {
      return _ActionBtn(
        icon: LucideIcons.shieldOff,
        color: Colors.redAccent,
        tooltip: 'Revogar acesso',
        onTap: () => _updateStatus(doc.reference, 'bloqueado'),
      );
    } else {
      // bloqueado
      return _ActionBtn(
        icon: LucideIcons.shieldCheck,
        color: Colors.greenAccent,
        tooltip: 'Reativar acesso',
        onTap: () => _updateStatus(doc.reference, 'aprovado'),
      );
    }
  }
}

/// Botão de ação compacto com glass + neon glow no hover.
class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: _hovered ? 0.25 : 0.1),
              border: Border.all(
                color: widget.color.withValues(alpha: _hovered ? 0.7 : 0.3),
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(widget.icon, size: 16, color: widget.color),
          ),
        ),
      ),
    );
  }
}

/// Badge em tempo real com a contagem de alunos pendentes.
class _PendingCounter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ALUNOS').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final count = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final role = data['role']?.toString().toLowerCase() ?? '';
          final status = data['status']?.toString().toLowerCase() ?? '';
          return role == 'aluno' && status == 'pendente';
        }).length;

        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.clock, size: 12, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                '$count pendente${count > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// COMPONENTES INTERNOS DO MODAL
// ═══════════════════════════════════════════════════════════

/// Badge compacto para status e faixa dentro do modal.
class _ModalBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ModalBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

/// Seção do modal com título e ícone.
class _ModalSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? titleColor;
  final Widget child;

  const _ModalSection({required this.icon, required this.title, required this.child, this.titleColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  (titleColor ?? AppTheme.accentGold).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Title row
          Row(
            children: [
              Icon(icon, size: 13, color: titleColor ?? AppTheme.accentGold),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: titleColor ?? AppTheme.accentGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Linha de informação com ícone, label e valor.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? actionColor;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.actionColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: actionColor ?? AppTheme.textGrey),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: valueColor ?? AppTheme.textGrey,
                      fontSize: 12,
                      decoration: onTap != null ? TextDecoration.underline : null,
                      decorationColor: actionColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onTap != null)
            Icon(LucideIcons.externalLink, size: 12, color: actionColor ?? AppTheme.textGrey),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: row);
    }
    return row;
  }
}
