import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';

class CheckinApprovalCard extends StatelessWidget {
  final DocumentSnapshot doc;

  const CheckinApprovalCard({super.key, required this.doc});

  Future<void> _handleAuthorize(BuildContext context, Map<String, dynamic> data) async {
    final uid = data['aluno_id'] ?? data['uid'];
    final nome = data['aluno_nome'] ?? data['nome'] ?? 'Aluno';
    
    final batch = FirebaseFirestore.instance.batch();

    // 1. Autoriza a frequência
    batch.update(doc.reference, {
      'status': 'aprovado',
      'status_detalhe': 'Autorizado pelo Sensei (Fila de Espera)',
    });

    try {
      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text('Entrada de $nome autorizada!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Erro ao autorizar: $e')),
        );
      }
    }
  }

  Future<void> _handleDeny(BuildContext context) async {
    try {
      await doc.reference.update({
        'status': 'recusado',
        'status_detalhe': 'Recusado pelo Sensei na Fila de Espera',
        'denied_at': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.redAccent, content: Text('Solicitação negada.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Erro ao negar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final uid = data['aluno_id'] ?? data['uid'];
    final nome = data['aluno_nome'] ?? data['nome'] ?? 'Desconhecido';
    final mod = data['modalidade'] ?? 'Geral';
    final ts = (data['dataHora'] ?? data['created_at']) as Timestamp?;
    final time = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '--:--';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(uid).get(),
      builder: (context, studentSnap) {
        bool isPendente = false;
        if (studentSnap.hasData && studentSnap.data!.exists) {
          final sData = studentSnap.data!.data() as Map<String, dynamic>;
          final statusFin = sData['financeiro']?['statusPagamento'] ?? 'Pendente';
          isPendente = statusFin != 'Pago' && statusFin != 'pago';
        }

        return Card(
          color: AppTheme.cardDarkGrey,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPendente ? const BorderSide(color: Colors.orange, width: 1) : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Avatar com status visual
                CircleAvatar(
                  backgroundColor: isPendente ? Colors.orange.withValues(alpha: 0.2) : AppTheme.accentGold.withValues(alpha: 0.2),
                  child: Icon(LucideIcons.user, color: isPendente ? Colors.orange : AppTheme.accentGold),
                ),
                const SizedBox(width: 16),
                
                // Área de Texto (Flexível)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(mod.toString().toUpperCase(), style: const TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          Text('Solicitado às $time', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                        ],
                      ),
                      if (isPendente) ...[
                        const SizedBox(height: 6),
                        const Text(
                          '⚠️ FINANCEIRO PENDENTE (Sensei Override)', 
                          style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),

                // Agrupamento de Ações
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.xCircle, color: Colors.redAccent, size: 28),
                      onPressed: () => _handleDeny(context),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.checkCircle, color: Colors.green, size: 28),
                      onPressed: () => _handleAuthorize(context, data),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
