import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data'; // [NOVO] Para bytes de imagem cross-platform
import '../core/theme/app_theme.dart';
import '../models/tatame_virtual_model.dart';
import '../core/services/image_upload_service.dart';
import '../widgets/tatame_comments_sheet.dart';
import '../widgets/glass_container.dart'; // [IMPORT]

class AdminTatameView extends StatefulWidget {
  const AdminTatameView({super.key});

  @override
  State<AdminTatameView> createState() => _AdminTatameViewState();
}

class _AdminTatameViewState extends State<AdminTatameView> {
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _kiCtrl = TextEditingController(text: '10');
  String _selectedCategory = '🥋 Jiu-Jitsu';
  String _selectedModality = 'Geral';
  bool _isTrajetoriaMode = false;
  XFile? _imageFile;
  Uint8List? _imageBytes;
  List<XFile> _galleryFiles = [];
  List<Uint8List> _galleryBytes = [];
  bool _isSaving = false;

  final List<String> _categories = [
    '🥋 Técnica / Aula',
    '⏱️ Circuito Funcional',
    '🥋 Jiu-Jitsu Kids',
    '🥋 Jiu-Jitsu',
    '🥊 Muay Thai',
    '🥊 Boxe',
    '🤼 MMA',
    '🥊 Kickboxing',
    '🥋 Judô',
    '🥋 Karatê Kyokushin',
    '🏆 Trajetória do Atleta',
  ];

  final List<String> _modalities = [
    'Geral',
    'Jiu-jitsu',
    'Muay Thai',
    'Boxe',
    'MMA',
    'Kickboxing',
    'Judô',
    'Karatê',
    'Funcional',
  ];

  String? _getThumbnail(String url) {
    if (url.isEmpty) return null;
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return null;
    String? videoId;
    if (uri.host.contains('youtube.com')) {
      videoId = uri.queryParameters['v'];
    } else if (uri.host.contains('youtu.be')) {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return videoId != null ? 'https://img.youtube.com/vi/$videoId/0.jpg' : null;
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    if (_isTrajetoriaMode) {
      final images = await picker.pickMultiImage(imageQuality: 70);
      if (images.isNotEmpty) {
        final List<Uint8List> bytesList = [];
        for (var image in images) {
          bytesList.add(await image.readAsBytes());
        }
        setState(() {
          _galleryFiles = images;
          _galleryBytes = bytesList;
          _imageFile = images.first;
          _imageBytes = bytesList.first;
        });
      }
    } else {
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageFile = image;
          _imageBytes = bytes;
          _galleryFiles = [];
          _galleryBytes = [];
        });
      }
    }
  }

  Future<void> _saveTatameVirtual() async {
    if (_tituloCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Título é obrigatório.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      String mainImageUrl = '';
      List<String> galleryUrls = [];

      // Auto-fetch thumbnail if YouTube link exists and no image selected
      if (_imageFile == null && _youtubeCtrl.text.isNotEmpty) {
        mainImageUrl = _getThumbnail(_youtubeCtrl.text) ?? '';
      }

      if (_imageFile != null) {
        mainImageUrl = await ImageUploadService.uploadImage(_imageFile!) ?? '';
      }

      if (_isTrajetoriaMode && _galleryFiles.isNotEmpty) {
        for (var file in _galleryFiles) {
          final url = await ImageUploadService.uploadImage(file);
          if (url != null) galleryUrls.add(url);
        }
        if (mainImageUrl.isEmpty && galleryUrls.isNotEmpty) {
          mainImageUrl = galleryUrls.first;
        }
      }

      final model = TatameVirtualModel(
        id: '', 
        titulo: _tituloCtrl.text.trim(),
        descricao: _descCtrl.text.trim(),
        imagemUrl: mainImageUrl,
        youtubeUrl: _isTrajetoriaMode ? '' : _youtubeCtrl.text.trim(),
        categoria: _isTrajetoriaMode ? '🏆 Trajetória do Atleta' : _selectedCategory,
        modalityId: _selectedModality,
        kiValue: int.tryParse(_kiCtrl.text) ?? 10,
        ativo: true,
        galeria: galleryUrls,
      );

      await FirebaseFirestore.instance.collection('TATAME_VIRTUAL').add(model.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicado com sucesso!'), backgroundColor: Colors.green));
        _tituloCtrl.clear();
        _descCtrl.clear();
        _youtubeCtrl.clear();
        _kiCtrl.text = '10';
        setState(() {
          _imageFile = null;
          _imageBytes = null;
          _galleryFiles = [];
          _galleryBytes = [];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Feed do Tatame', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const Text('Postagem rápida e gestão de gamificação', style: TextStyle(color: AppTheme.textGrey)),
                ],
              ),
              _buildModeSelector(),
            ],
          ),
          const SizedBox(height: 32),
          
          _buildQuickPost(),
          const SizedBox(height: 32),
          
          const Row(
            children: [
              Icon(LucideIcons.list, color: AppTheme.accentGold, size: 16),
              SizedBox(width: 12),
              Text('CONTEÚDOS PUBLICADOS', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildRecentList(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(color: AppTheme.cardDarkGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.glassBorder)),
      child: Row(
        children: [
          _buildModeToggle(false, LucideIcons.video, 'Aulas'),
          _buildModeToggle(true, LucideIcons.star, 'Atletas'),
        ],
      ),
    );
  }

  Widget _buildModeToggle(bool mode, IconData icon, String label) {
    bool selected = _isTrajetoriaMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _isTrajetoriaMode = mode;
        _imageFile = null;
        _imageBytes = null;
        _galleryFiles = [];
        _galleryBytes = [];
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentGold : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.black : AppTheme.textGrey, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: selected ? Colors.black : AppTheme.textGrey, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPost() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMediaPicker(),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _tituloCtrl,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: _inputDeco('O que vamos ensinar hoje?', LucideIcons.penTool),
                    ),
                    const SizedBox(height: 12),
                    if (!_isTrajetoriaMode) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedModality,
                              dropdownColor: AppTheme.cardDarkGrey,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: _inputDeco('Modalidade Alvo', LucideIcons.target),
                              items: _modalities.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                              onChanged: (val) => setState(() => _selectedModality = val ?? 'Geral'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _kiCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold),
                              decoration: _inputDeco('Valor KI', LucideIcons.zap),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _youtubeCtrl,
                        onChanged: (val) => setState(() {}),
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        decoration: _inputDeco('Link do YouTube (Auto-Thumb)', LucideIcons.youtube),
                      ),
                    ] else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        dropdownColor: AppTheme.cardDarkGrey,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco('Tipo de Destaque', LucideIcons.award),
                        items: ['🏆 Trajetória do Atleta', '🌟 Estrela do Mês', '🥋 Graduação Especial'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val ?? _selectedCategory),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
            decoration: _inputDeco('Adicione uma descrição rápida...', LucideIcons.alignLeft),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _tituloCtrl.clear();
                  _descCtrl.clear();
                  _youtubeCtrl.clear();
                  setState(() {
                    _imageFile = null;
                    _imageBytes = null;
                  });
                },
                child: const Text('LIMPAR', style: TextStyle(color: AppTheme.textGrey)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveTatameVirtual,
                icon: _isSaving 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(LucideIcons.send, size: 16),
                label: Text(_isSaving ? 'POSTANDO...' : 'PUBLICAR AGORA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPicker() {
    final thumbUrl = _getThumbnail(_youtubeCtrl.text);
    
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: AppTheme.backgroundBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.2)),
          image: _imageBytes != null 
            ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
            : (thumbUrl != null ? DecorationImage(image: NetworkImage(thumbUrl), fit: BoxFit.cover) : null),
        ),
        child: (_imageBytes == null && thumbUrl == null)
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isTrajetoriaMode ? LucideIcons.layers : LucideIcons.camera, color: AppTheme.accentGold, size: 28),
                const SizedBox(height: 8),
                const Text('MÍDIA', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            )
          : Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)])),
              child: const Icon(LucideIcons.refreshCw, color: Colors.white, size: 14),
            ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
      prefixIcon: Icon(icon, size: 16, color: AppTheme.accentGold.withValues(alpha: 0.5)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentGold, width: 0.5)),
    );
  }

  Widget _buildRecentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('TATAME_VIRTUAL').orderBy('titulo').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('Nenhum conteúdo publicado.', style: TextStyle(color: AppTheme.textGrey)));

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            mainAxisExtent: 100,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final model = TatameVirtualModel.fromMap(docs[index].id, data);

            return GlassContainer(
              borderRadius: 20,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(image: NetworkImage(model.imagemUrl), fit: BoxFit.cover),
                  ),
                ),
                title: Text(model.titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.modalityId, style: const TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('${model.kiValue} KI', style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.pin, color: AppTheme.textGrey, size: 16),
                      onPressed: () => docs[index].reference.update({'fixado': !(data['fixado'] ?? false)}),
                      color: (data['fixado'] ?? false) ? AppTheme.accentGold : null,
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 16),
                      onPressed: () => docs[index].reference.delete(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
