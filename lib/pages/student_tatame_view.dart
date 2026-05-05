import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../models/tatame_virtual_model.dart';
import '../widgets/tatame_comments_sheet.dart';
import '../providers/auth_provider.dart';
import '../core/constants/firebase_collections.dart';

class StudentTatameView extends ConsumerStatefulWidget {
  const StudentTatameView({super.key});

  @override
  ConsumerState<StudentTatameView> createState() => _StudentTatameViewState();
}

class _StudentTatameViewState extends ConsumerState<StudentTatameView> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    if (profile == null) return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('TATAME_VIRTUAL')
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhum conteúdo disponível.', style: TextStyle(color: AppTheme.textGrey)));

        final treinos = snapshot.data!.docs.map((doc) => TatameVirtualModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
        
        // Ordenar fixados no topo
        treinos.sort((a, b) {
          final aFix = snapshot.data!.docs.firstWhere((d) => d.id == a.id).get('fixado') == true;
          final bFix = snapshot.data!.docs.firstWhere((d) => d.id == b.id).get('fixado') == true;
          if (aFix && !bFix) return -1;
          if (!aFix && bFix) return 1;
          return 0;
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: treinos.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs.firstWhere((d) => d.id == treinos[index].id);
            return _TatameCard(treino: treinos[index], treinoDoc: doc, profile: profile);
          },
        );
      },
    );
  }
}

class _TatameCard extends ConsumerStatefulWidget {
  final TatameVirtualModel treino;
  final DocumentSnapshot treinoDoc;
  final UserProfileData profile;
  const _TatameCard({required this.treino, required this.treinoDoc, required this.profile});

  @override
  ConsumerState<_TatameCard> createState() => _TatameCardState();
}

class _TatameCardState extends ConsumerState<_TatameCard> {
  bool _isClaiming = false;
  bool _hasClaimed = false;

  @override
  void initState() {
    super.initState();
    _checkClaimStatus();
  }

  Future<void> _checkClaimStatus() async {
    final claimDoc = await FirebaseFirestore.instance
        .collection(FirebaseCollections.alunos)
        .doc(widget.profile.uid)
        .collection('ki_reivindicado')
        .doc(widget.treino.id)
        .get();
    if (mounted) setState(() => _hasClaimed = claimDoc.exists);
  }

  void _abrirNoYoutube() async {
    if (widget.treino.youtubeUrl.isNotEmpty) {
      final url = Uri.parse(widget.treino.youtubeUrl);
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _claimKI() async {
    if (_hasClaimed || _isClaiming) return;
    setState(() => _isClaiming = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // 1. Registrar a reivindicação para evitar duplicidade
      final claimRef = FirebaseFirestore.instance
          .collection(FirebaseCollections.alunos)
          .doc(widget.profile.uid)
          .collection('ki_reivindicado')
          .doc(widget.treino.id);
      
      batch.set(claimRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'ki_concedido': widget.treino.kiValue,
        'modalityId': widget.treino.modalityId,
      });

      // 2. Atualizar o saldo de KI do aluno na modalidade
      final studentRef = FirebaseFirestore.instance
          .collection(FirebaseCollections.alunos)
          .doc(widget.profile.uid);
      
      batch.update(studentRef, {
        'ki_por_modalidade.${widget.treino.modalityId}': FieldValue.increment(widget.treino.kiValue),
      });

      await batch.commit();
      
      if (mounted) {
        setState(() {
          _hasClaimed = true;
          _isClaiming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Parabéns! +${widget.treino.kiValue} KI em ${widget.treino.modalityId}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TatameCommentsSheet(treinoId: widget.treino.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasGallery = widget.treino.galeria.length > 1;
    final isFixado = (widget.treinoDoc.data() as Map<String, dynamic>)['fixado'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.cardDarkGrey,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isFixado ? AppTheme.accentGold.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
        boxShadow: isFixado ? [BoxShadow(color: AppTheme.accentGold.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: -5)] : AppTheme.premiumShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ÁREA DE MÍDIA
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                hasGallery 
                  ? _GalleryCarousel(images: widget.treino.galeria)
                  : GestureDetector(
                      onTap: _abrirNoYoutube,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(imageUrl: widget.treino.imagemUrl, fit: BoxFit.cover),
                          Container(color: Colors.black.withValues(alpha: 0.3)),
                          if (widget.treino.youtubeUrl.isNotEmpty)
                            const Center(child: Icon(Icons.play_circle_fill, color: AppTheme.accentGold, size: 64)),
                        ],
                      ),
                    ),
                if (isFixado)
                  Positioned(
                    top: 16, right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppTheme.accentGold, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.pin, color: Colors.black, size: 12),
                          SizedBox(width: 4),
                          Text('FIXADO', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 16, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                    child: Text(widget.treino.modalityId.toUpperCase(), style: const TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(widget.treino.titulo, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
                    Row(
                      children: [
                        IconButton(icon: const Icon(LucideIcons.heart, color: AppTheme.textGrey, size: 20), onPressed: () {}),
                        IconButton(icon: const Icon(LucideIcons.messageSquare, color: AppTheme.textGrey, size: 20), onPressed: () => _showComments(context)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.treino.descricao, style: const TextStyle(color: AppTheme.textGrey, fontSize: 14, height: 1.5)),
                const SizedBox(height: 24),
                
                // BOTÃO DE REIVINDICAÇÃO
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_hasClaimed || _isClaiming) ? null : () {
                      _abrirNoYoutube();
                      _claimKI();
                    },
                    icon: _isClaiming 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Icon(_hasClaimed ? LucideIcons.checkCircle2 : LucideIcons.zap, size: 18),
                    label: Text(
                      _hasClaimed 
                        ? 'ESTUDO CONCLUÍDO (+${widget.treino.kiValue} KI)' 
                        : 'ASSISTIR E REIVINDICAR ${widget.treino.kiValue} KI',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasClaimed ? Colors.white10 : AppTheme.accentGold,
                      foregroundColor: _hasClaimed ? AppTheme.textGrey : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryCarousel extends StatefulWidget {
  final List<String> images;
  const _GalleryCarousel({required this.images});

  @override
  State<_GalleryCarousel> createState() => _GalleryCarouselState();
}

class _GalleryCarouselState extends State<_GalleryCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (idx) => setState(() => _currentPage = idx),
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: widget.images[index],
              fit: BoxFit.cover,
            );
          },
        ),
        // Indicadores (Dots)
        Positioned(
          bottom: 12,
          right: 0, left: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _currentPage == index ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _currentPage == index ? AppTheme.accentGold : Colors.white38,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}


