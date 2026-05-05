import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../services/social_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final XFile initialImage;
  const CreatePostScreen({super.key, required this.initialImage});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final SocialService _socialService = SocialService();
  final TextEditingController _captionController = TextEditingController();
  PostType _selectedType = PostType.aluno;
  bool _isPublishing = false;

  Future<void> _publish() async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);

    try {
      // 1. CAPTURAR WYSIWYG (FOTO + LOGO)
      RenderRepaintBoundary boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0); 
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List bytes = byteData!.buffer.asUint8List();

      final compositeFile = XFile.fromData(bytes, mimeType: 'image/png', name: 'composite_post.png');

      // 2. UPLOAD E COMPRESSÃO
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final profile = ref.read(userProfileProvider).value;
      final imageUrl = await _socialService.uploadPostImage(compositeFile, user.uid);

      // 3. SALVAR NO FIRESTORE
      final post = PostModel(
        id: FirebaseFirestore.instance.collection('posts').doc().id,
        userId: user.uid,
        userName: profile?.nome ?? user.displayName ?? 'Atleta',
        userPhoto: profile?.fotoUrl ?? user.photoURL,
        imageUrl: imageUrl,
        text: _captionController.text.trim(),
        type: _selectedType,
        createdAt: DateTime.now(),
      );

      await _socialService.savePost(post);

      if (mounted) {
        context.pop(); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Postagem publicada com sucesso!')));
      }
    } catch (e) {
      debugPrint('Erro ao publicar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao publicar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final isAdmin = profile?.role == 'admin';

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        title: const Text('Nova Postagem', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isPublishing)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGold))))
          else
            TextButton(
              onPressed: _publish,
              child: const Text('PUBLICAR', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // WYSIWYG PREVIEW
            RepaintBoundary(
              key: _boundaryKey,
              child: Stack(
                children: [
                   AspectRatio(
                     aspectRatio: 1,
                     child: kIsWeb 
                        ? Image.network(widget.initialImage.path, fit: BoxFit.cover)
                        : Image.network(widget.initialImage.path, fit: BoxFit.cover), // XFile path is usable with network image for blobs
                   ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'C.T. PANDORA',
                              style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                            Image.asset('assets/images/logo_ct_pandora.png', width: 40, opacity: const AlwaysStoppedAnimation(0.8)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // CAPTION
            TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Escreva uma legenda...',
                hintStyle: const TextStyle(color: AppTheme.textGrey),
                filled: true,
                fillColor: AppTheme.cardDarkGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            // EXCLUSIVE ADMIN OPTIONS
            if (isAdmin) ...[
              const Text('TIPO DE POSTAGEM (ADMIN)', style: TextStyle(color: AppTheme.textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: PostType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(type.name.toUpperCase(), style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : Colors.white)),
                    selected: isSelected,
                    selectedColor: AppTheme.accentGold,
                    backgroundColor: AppTheme.cardDarkGrey,
                    onSelected: (val) => setState(() => _selectedType = type),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
