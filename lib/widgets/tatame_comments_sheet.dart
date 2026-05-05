import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/comment_model.dart';
import '../providers/auth_provider.dart';

class TatameCommentsSheet extends ConsumerStatefulWidget {
  final String treinoId;
  const TatameCommentsSheet({super.key, required this.treinoId});

  @override
  ConsumerState<TatameCommentsSheet> createState() => _TatameCommentsSheetState();
}

class _TatameCommentsSheetState extends ConsumerState<TatameCommentsSheet> {
  final _commentCtrl = TextEditingController();

  Future<void> _postComment() async {
    if (_commentCtrl.text.isEmpty) return;
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return;

    final comment = CommentModel(
      id: '',
      alunoId: profile.uid,
      alunoNome: profile.nome ?? 'Aluno',
      texto: _commentCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('TATAME_VIRTUAL')
        .doc(widget.treinoId)
        .collection('COMENTARIOS')
        .add(comment.toMap());

    _commentCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final isAdmin = profile?.role == 'admin';

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.backgroundBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textGrey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Interações no Tatame 🥋💬', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('TATAME_VIRTUAL')
                  .doc(widget.treinoId)
                  .collection('COMENTARIOS')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SelectableText(
                        'Erro ao carregar interações: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.accentGold),
                        SizedBox(height: 12),
                        Text('Conectando ao tatame...', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text('Nenhuma interação ainda.', style: TextStyle(color: AppTheme.textGrey)));
                }

                final comments = snapshot.data!.docs;

                if (comments.isEmpty) return const Center(child: Text('Nenhuma interação ainda.', style: TextStyle(color: AppTheme.textGrey)));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final data = comments[index].data() as Map<String, dynamic>;
                    final model = CommentModel.fromMap(comments[index].id, data);

                    return _CommentTile(
                      comment: model,
                      isAdmin: isAdmin,
                      onReply: (reply) async {
                        await comments[index].reference.update({'respostaAdmin': reply});
                      },
                      onDelete: isAdmin ? () => comments[index].reference.delete() : null,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isAdmin ? 'Responder como Sensei...' : 'Deixe sua dúvida...',
                      hintStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
                      filled: true,
                      fillColor: AppTheme.cardDarkGrey,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _postComment,
                  icon: const Icon(LucideIcons.send, color: AppTheme.accentGold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final bool isAdmin;
  final Function(String) onReply;
  final VoidCallback? onDelete;

  const _CommentTile({required this.comment, required this.isAdmin, required this.onReply, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardDarkGrey.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(comment.alunoNome, style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 12)),
              Row(
                children: [
                  Text(DateFormat('dd/MM HH:mm').format(comment.createdAt), style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 14),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(comment.texto, style: const TextStyle(color: Colors.white, fontSize: 14)),
          if (comment.respostaAdmin != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RESPOSTA DO SENSEI 🥋', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text(comment.respostaAdmin!, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ] else if (isAdmin) ...[
            TextButton(
              onPressed: () => _showReplyDialog(context),
              child: const Text('RESPONDER', style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  void _showReplyDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDarkGrey,
        title: const Text('Responder Aluno', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Escreva sua resposta...', hintStyle: TextStyle(color: AppTheme.textGrey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () { onReply(ctrl.text); Navigator.pop(context); }, child: const Text('ENVIAR')),
        ],
      ),
    );
  }
}
