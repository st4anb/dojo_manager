import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../services/social_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class PostCardWidget extends StatefulWidget {
  final PostModel post;
  const PostCardWidget({super.key, required this.post});

  @override
  State<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<PostCardWidget> {
  final GlobalKey _boundaryKey = GlobalKey();
  final SocialService _socialService = SocialService();

  Future<void> _shareToInstagram() async {
    try {
      RenderRepaintBoundary boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final xFile = XFile.fromData(pngBytes, mimeType: 'image/png', name: 'share_post.png');
      await Share.shareXFiles([xFile], text: 'Confira meu treino no Dojo!');
    } catch (e) {
      debugPrint('Erro ao compartilhar: $e');
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardDarkGrey,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CommentsSection(postId: widget.post.id, socialService: _socialService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.cardDarkGrey,
                    backgroundImage: widget.post.userPhoto != null ? CachedNetworkImageProvider(widget.post.userPhoto!) : null,
                    child: widget.post.userPhoto == null ? const Icon(LucideIcons.user, size: 18, color: AppTheme.textGrey) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(widget.post.type.name.toUpperCase(), style: const TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Text(DateFormat('dd/MM HH:mm').format(widget.post.createdAt), style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                ],
              ),
            ),
            // REPAINT BOUNDARY Wraps the main content to be shared (Image + Brand)
            RepaintBoundary(
              key: _boundaryKey,
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: widget.post.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: AppTheme.cardDarkGrey, child: const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            // ACTIONS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.heart, color: widget.post.ossCount > 0 ? Colors.red : Colors.white),
                    onPressed: () async {
                      if (user != null) {
                        try {
                          await _socialService.toggleOss(widget.post.id, user.uid);
                        } catch (e) {
                          debugPrint('Erro no Oss: $e');
                        }
                      }
                    },
                  ),
                  Text('${widget.post.ossCount} Oss', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(LucideIcons.messageSquare, color: Colors.white),
                    onPressed: _showComments,
                  ),
                  Text('${widget.post.commentCount}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.share2, color: AppTheme.accentGold),
                    onPressed: _shareToInstagram,
                  ),
                ],
              ),
            ),
            // CAPTION
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: '${widget.post.userName} ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    TextSpan(text: widget.post.text, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsSection extends ConsumerStatefulWidget {
  final String postId;
  final SocialService socialService;
  const _CommentsSection({required this.postId, required this.socialService});

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return 'há ${difference.inDays}d';
    if (difference.inHours > 0) return 'há ${difference.inHours}h';
    if (difference.inMinutes > 0) return 'há ${difference.inMinutes}min';
    return 'agora';
  }

  Future<void> _sendComment([String? text]) async {
    final commentText = text ?? _controller.text.trim();
    if (commentText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);
    try {
      final comment = CommentModel(
        id: '',
        userId: user.uid,
        userName: user.displayName ?? 'Atleta',
        userPhoto: user.photoURL,
        text: commentText,
        createdAt: DateTime.now(),
      );
      await widget.socialService.addComment(widget.postId, comment);
      _controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDarkGrey,
        title: const Text('Excluir Comentário?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta ação não pode ser desfeita.', style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('EXCLUIR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.socialService.deleteComment(widget.postId, commentId);
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: AppTheme.cardDarkGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // DRAG HANDLE
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Comentários', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: AppTheme.textGrey, size: 20),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
  
            // LIST
            Flexible(
              child: StreamBuilder(
                stream: widget.socialService.getCommentsStream(widget.postId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(48.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.messageSquare, color: Colors.white10, size: 48),
                          SizedBox(height: 16),
                          Text('Nenhum comentário ainda.\nSeja o primeiro!', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textGrey)),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final profile = ref.watch(userProfileProvider).value;
                      final isAdmin = profile?.role.toLowerCase() == 'admin';
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          radius: 16, 
                          backgroundImage: data['userPhoto'] != null ? CachedNetworkImageProvider(data['userPhoto']) : null,
                          child: data['userPhoto'] == null ? const Icon(LucideIcons.user, size: 16) : null,
                        ),
                        title: Row(
                          children: [
                            Text(data['userName'] ?? 'Atleta', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Text(_formatTimeAgo(date), style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(data['text'] ?? '', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                        ),
                        trailing: isAdmin ? IconButton(
                          icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
                          onPressed: () => _deleteComment(doc.id),
                        ) : null,
                      );
                    },
                  );
                },
              ),
            ),
            
            const Divider(color: Colors.white10, height: 1),
  
            // INPUT FOOTER
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // OSS QUICK BUTTON
                  IconButton(
                    tooltip: 'Enviar Oss!',
                    icon: const Icon(LucideIcons.swords, color: AppTheme.accentGold),
                    onPressed: () => _sendComment('Oss!'),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Adicionar comentário...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSending)
                    const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  else
                    IconButton(
                      icon: const Icon(LucideIcons.send, color: AppTheme.accentGold),
                      onPressed: () => _sendComment(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
