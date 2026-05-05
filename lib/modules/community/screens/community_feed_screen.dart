import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../services/social_service.dart';
import '../widgets/post_card_widget.dart';
import 'create_post_screen.dart';
import '../../../core/theme/app_theme.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final SocialService _socialService = SocialService();
  final ScrollController _scrollController = ScrollController();
  
  List<QueryDocumentSnapshot> _postDocs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _socialService.getPostsPaginated(limit: 10);
      setState(() {
        _postDocs = docs;
        _isLoading = false;
        if (docs.isNotEmpty) {
          _lastDocument = docs.last;
        }
        if (docs.length < 10) _hasMore = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar posts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    
    try {
      final docs = await _socialService.getPostsPaginated(startAfter: _lastDocument, limit: 10);
      setState(() {
        _postDocs.addAll(docs);
        _isLoading = false;
        if (docs.isNotEmpty) {
          _lastDocument = docs.last;
        }
        if (docs.length < 10) _hasMore = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar mais posts: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _pickImageAndGoToCreate() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => CreatePostScreen(initialImage: image)),
      ).then((_) {
        _loadInitialPosts();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        title: const Text('Tatame Virtual', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: AppTheme.accentGold,
        onRefresh: _loadInitialPosts,
        child: _postDocs.isEmpty && _isLoading 
            ? _buildSkeletonList()
            : _postDocs.isEmpty 
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _postDocs.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _postDocs.length) {
                      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: AppTheme.accentGold)));
                    }
                    
                    final doc = _postDocs[index];
                    final post = PostModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                    return PostCardWidget(post: post);
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImageAndGoToCreate,
        backgroundColor: AppTheme.accentGold,
        child: const Icon(LucideIcons.camera, color: Colors.black),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 24),
        height: 480,
        decoration: BoxDecoration(
          color: AppTheme.cardDarkGrey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Container(width: 150, height: 16, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
            Expanded(child: Container(color: Colors.white10)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                   const SizedBox(height: 8),
                   Container(width: 200, height: 14, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: const Icon(LucideIcons.swords, size: 64, color: AppTheme.accentGold),
            ),
            const SizedBox(height: 24),
            const Text('O Tatame está vazio', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Compartilhe seu treino e inspire a comunidade!', 
              textAlign: TextAlign.center, 
              style: TextStyle(color: AppTheme.textGrey)
            ),
          ],
        ),
      ),
    );
  }
}
