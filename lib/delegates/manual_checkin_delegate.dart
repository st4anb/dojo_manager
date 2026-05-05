import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/constants/firebase_collections.dart';
import '../core/theme/app_theme.dart';

class ManualCheckinDelegate extends SearchDelegate<DocumentSnapshot?> {
  @override
  String get searchFieldLabel => 'Nome do aluno para liberação...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.cardDarkGrey,
        iconTheme: IconThemeData(color: AppTheme.accentGold),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppTheme.textGrey),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppTheme.accentGold),
      scaffoldBackgroundColor: AppTheme.backgroundBlack,
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(LucideIcons.arrowLeft),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Pesquise o aluno pelo nome.', style: TextStyle(color: AppTheme.textGrey)));
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.alunos)
          .where('role', isEqualTo: 'aluno')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));

        final results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['dados_pessoais']?['nome']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase());
        }).toList();

        if (results.isEmpty) {
          return const Center(child: Text('Nenhum aluno encontrado.', style: TextStyle(color: AppTheme.textGrey)));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final doc = results[index];
            final data = doc.data() as Map<String, dynamic>;
            final personal = data['dados_pessoais'] as Map<String, dynamic>?;
            final financeiro = data['financeiro'] as Map<String, dynamic>?;
            final statusFin = financeiro?['statusPagamento'] ?? 'Pendente';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.cardDarkGrey,
                backgroundImage: data['foto_url'] != null ? NetworkImage(data['foto_url']) : null,
                child: data['foto_url'] == null ? const Icon(LucideIcons.user, color: AppTheme.textGrey) : null,
              ),
              title: Text(personal?['nome'] ?? '...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Row(
                children: [
                  Text(personal?['faixa']?.toString().toUpperCase() ?? 'BRANCA', style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: (statusFin == 'Pago' || statusFin == 'pago') ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (statusFin == 'Pago' || statusFin == 'pago') ? 'PAGO' : 'PENDENTE',
                      style: TextStyle(color: (statusFin == 'Pago' || statusFin == 'pago') ? Colors.green : Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              trailing: const Icon(LucideIcons.chevronRight, color: AppTheme.textGrey, size: 16),
              onTap: () => _confirmManualCheckin(context, doc),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmManualCheckin(BuildContext context, DocumentSnapshot studentDoc) async {
    final data = studentDoc.data() as Map<String, dynamic>;
    final personal = data['dados_pessoais'] as Map<String, dynamic>?;
    final financeiro = data['financeiro'] as Map<String, dynamic>?;
    final nome = personal?['nome'] ?? '...';
    final statusFin = financeiro?['statusPagamento'] ?? 'Pendente';
    final isPendente = statusFin != 'Pago' && statusFin != 'pago';

    // SUPORTE A MULTI-MODALIDADE (Busca as modalidades do aluno)
    final dynamic rawMods = personal?['modalidade'] ?? data['modalidade'] ?? ['Geral'];
    final List<String> modalidades = rawMods is List ? List<String>.from(rawMods) : [rawMods.toString()];
    String selectedMod = modalidades.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardDarkGrey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(LucideIcons.shieldCheck, color: AppTheme.accentGold),
              const SizedBox(width: 12),
              const Text('Autoridade Sensei', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Liberar presença manual para:', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(nome, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              if (isPendente)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info, color: Colors.orange, size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Aluno com mensalidade $statusFin. (Bypass Ativo)', style: const TextStyle(color: Colors.orange, fontSize: 11))),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),
              const Text('MODALIDADE DA AULA:', style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: AppTheme.backgroundBlack, borderRadius: BorderRadius.circular(8)),
                child: DropdownButton<String>(
                  value: selectedMod,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardDarkGrey,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white),
                  items: modalidades.map((mod) => DropdownMenuItem(value: mod, child: Text(mod))).toList(),
                  onChanged: (val) => setDialogState(() => selectedMod = val!),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Esta ação registra a frequência e incrementa o progresso do aluno imediatamente.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGrey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CONFIRMAR CHECK-IN'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      // ══════════════════════════════════════════════
      // BLOQUEIO: MÁXIMO 1 CHECK-IN POR DIA
      // ══════════════════════════════════════════════
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final existingCheckins = await FirebaseFirestore.instance
          .collection(FirebaseCollections.frequencia)
          .where('uid', isEqualTo: studentDoc.id)
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      final checkinValido = existingCheckins.docs.any((doc) {
        final status = (doc.data())['status'] ?? '';
        return status != 'recusado';
      });

      if (checkinValido) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
              content: Text('$nome já realizou check-in hoje. Limite diário atingido.'),
            ),
          );
        }
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      // 1. REGISTRA NA COLEÇÃO DE FREQUÊNCIA
      final freqRef = FirebaseFirestore.instance.collection(FirebaseCollections.frequencia).doc();
      batch.set(freqRef, {
        'uid': studentDoc.id,
        'nome': nome,
        'modalidade': selectedMod,
        'status': 'aprovado',
        'status_detalhe': 'Manualmente pelo Sensei (Authority Override)',
        'created_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text('Check-in de $nome ($selectedMod) realizado com sucesso!')),
        );
        close(context, studentDoc);
      }
    }
  }
}
