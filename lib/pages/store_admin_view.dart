import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:typed_data';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import '../core/services/image_upload_service.dart';
import '../widgets/glass_container.dart';

class StoreAdminView extends StatefulWidget {
  const StoreAdminView({super.key});

  @override
  State<StoreAdminView> createState() => _StoreAdminViewState();
}

class _StoreAdminViewState extends State<StoreAdminView> {
  String _searchQuery = '';
  String _selectedCategory = 'Tudo';
  String _selectedStatus = 'Tudo';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['Tudo', 'Kimonos', 'Camisetas', 'Acessórios', 'Suplementos', 'Equipamentos'];
  final List<String> _statuses = ['Tudo', 'Publicado', 'Pausado', 'Sem Estoque'];

  Future<void> _showProductDialog({QueryDocumentSnapshot? doc}) async {
    final isEditing = doc != null;
    final data = isEditing ? doc.data() as Map<String, dynamic> : null;
    
    final titleCtrl = TextEditingController(text: isEditing ? (data?['nome'] ?? data?['titulo'] ?? '') : '');
    final descCtrl = TextEditingController(text: isEditing ? (data?['descricao'] ?? '') : '');
    // Preço em Reais para o input
    final precoInReais = isEditing ? ((data?['preco'] ?? 0) / 100).toStringAsFixed(2) : '';
    final precoCtrl = TextEditingController(text: precoInReais);
    
    String category = isEditing ? (data?['categoria'] ?? 'Equipamentos') : 'Equipamentos';
    String status = isEditing ? (data?['status'] ?? 'Publicado') : 'Publicado';
    String? currentImageUrl = isEditing ? (data?['imagemUrl'] ?? data?['url_imagem']) : null;
    Uint8List? selectedImageBytes;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardDarkGrey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppTheme.glassBorder)),
              title: Text(isEditing ? 'EDITAR PRODUTO' : 'NOVO ANÚNCIO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
                        if (result != null && result.files.single.bytes != null) {
                          selectedImageBytes = result.files.single.bytes!;
                          setModalState(() {});
                        }
                      },
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.2)),
                        ),
                        child: selectedImageBytes != null 
                          ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.memory(selectedImageBytes!, fit: BoxFit.contain))
                          : (currentImageUrl != null 
                              ? ClipRRect(borderRadius: BorderRadius.circular(15), child: CachedNetworkImage(imageUrl: currentImageUrl, fit: BoxFit.contain))
                              : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.camera, color: AppTheme.accentGold, size: 40), SizedBox(height: 8), Text('Adicionar Foto', style: TextStyle(color: AppTheme.textGrey, fontSize: 12))])),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildField(titleCtrl, 'Nome do Produto', LucideIcons.tag),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDropdown(category, _categories.where((c) => c != 'Tudo').toList(), (v) => setModalState(() => category = v!), 'Categoria')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField(precoCtrl, 'Preço (R\$)', LucideIcons.coins, isNumeric: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(status, _statuses.where((s) => s != 'Tudo').toList(), (v) => setModalState(() => status = v!), 'Status'),
                    const SizedBox(height: 16),
                    _buildField(descCtrl, 'Descrição', LucideIcons.alignLeft, maxLines: 3),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGrey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: isSaving ? null : () async {
                    if (titleCtrl.text.isEmpty || precoCtrl.text.isEmpty) return;
                    setModalState(() => isSaving = true);
                    try {
                      String? imageUrl = currentImageUrl;
                      if (selectedImageBytes != null) {
                        imageUrl = await ImageUploadService.uploadImageFromBytes(selectedImageBytes!);
                      }
                      
                      final updateData = {
                        'nome': titleCtrl.text.trim(),
                        'categoria': category,
                        'status': status,
                        'descricao': descCtrl.text.trim(),
                        'preco': (double.parse(precoCtrl.text.replaceAll(',', '.')) * 100).toInt(),
                        'imagemUrl': imageUrl,
                        'ativo': status == 'Publicado',
                        'updated_at': FieldValue.serverTimestamp(),
                      };

                      if (isEditing) {
                        await doc.reference.update(updateData);
                      } else {
                        updateData['created_at'] = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance.collection(FirebaseCollections.lojaProdutos).add(updateData);
                      }
                      Navigator.pop(ctx);
                    } catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Erro: $e')));
                    }
                    setModalState(() => isSaving = false);
                  },
                  child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('SALVAR PRODUTO', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool isNumeric = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
        prefixIcon: Icon(icon, size: 16, color: AppTheme.accentGold),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged, String label) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
      dropdownColor: AppTheme.cardDarkGrey,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildSearchAndFilters(),
          const SizedBox(height: 32),
          _buildProductGrid(),
          const SizedBox(height: 48),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInDown(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VITRINE DO DOJO', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
              Text('Gerencie os produtos visíveis para os alunos', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {}, // Inicializar logic
                icon: const Icon(LucideIcons.settings, size: 14),
                label: const Text('RESET PARÂMETROS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textGrey, side: const BorderSide(color: Colors.white10)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showProductDialog(),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('ANUNCIAR NOVO PRODUTO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return FadeIn(
      delay: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Buscar produtos...',
                  hintStyle: TextStyle(color: AppTheme.textGrey),
                  prefixIcon: Icon(LucideIcons.search, color: AppTheme.accentGold, size: 18),
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            const SizedBox(width: 16),
            _buildFilterDropdown(LucideIcons.shirt, _categories, _selectedCategory, (v) => setState(() => _selectedCategory = v!)),
            const SizedBox(width: 8),
            _buildFilterDropdown(LucideIcons.eye, _statuses, _selectedStatus, (v) => setState(() => _selectedStatus = v!)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(IconData icon, List<String> items, String value, Function(String?) onChanged) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(icon, size: 14, color: AppTheme.textGrey),
          dropdownColor: AppTheme.cardDarkGrey,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(FirebaseCollections.lojaProdutos).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Erro de conexão.', style: TextStyle(color: Colors.red)));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));

        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nome = (data['nome'] ?? data['titulo'] ?? '').toString().toLowerCase();
          final cat = data['categoria'] ?? 'Equipamentos';
          final status = data['status'] ?? 'Publicado';

          bool matchesSearch = nome.contains(_searchQuery);
          bool matchesCat = _selectedCategory == 'Tudo' || cat == _selectedCategory;
          bool matchesStatus = _selectedStatus == 'Tudo' || status == _selectedStatus;

          return matchesSearch && matchesCat && matchesStatus;
        }).toList();

        if (filteredDocs.isEmpty) return _buildEmptyState();

        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 0.75,
              ),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) => _buildProductCard(filteredDocs[index]),
            );
          }
        );
      }
    );
  }

  Widget _buildProductCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nome = data['nome'] ?? data['titulo'] ?? '---';
    final urlImagem = data['imagemUrl'] ?? data['url_imagem'] as String?;
    final preco = data['preco'] ?? 0;
    final status = data['status'] ?? 'Publicado';
    
    Color statusColor = status == 'Publicado' ? Colors.greenAccent : (status == 'Pausado' ? Colors.orangeAccent : Colors.redAccent);

    return FadeInUp(
      child: GlassContainer(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Area
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: urlImagem != null && urlImagem.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: CachedNetworkImage(imageUrl: urlImagem, fit: BoxFit.contain),
                    )
                  : const Icon(LucideIcons.image, color: Colors.black12, size: 48),
              ),
            ),
            // Info Area
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(data['categoria'] ?? 'Geral', style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('R\$ ${(preco / 100).toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.w900, fontSize: 18)),
                        _buildStatusBadge(status, statusColor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Actions Row
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(onPressed: () => _showProductDialog(doc: doc), icon: const Icon(LucideIcons.pencil, size: 16, color: Colors.white70)),
                  IconButton(onPressed: () => doc.reference.delete(), icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return FadeIn(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Column(
            children: [
              const Icon(LucideIcons.shoppingBag, size: 80, color: Colors.white10),
              const SizedBox(height: 24),
              const Text('Sua vitrine está vazia.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Clique em 'Anunciar Novo Produto' para começar a vender.", style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: () => _showProductDialog(), child: const Text('CADASTRAR PRIMEIRO PRODUTO')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageBtn(LucideIcons.chevronLeft, false),
        _buildPageNum('1', true),
        _buildPageNum('2', false),
        _buildPageNum('3', false),
        _buildPageBtn(LucideIcons.chevronRight, false),
      ],
    );
  }

  Widget _buildPageBtn(IconData icon, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {},
        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: active ? AppTheme.accentGold : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: active ? Colors.black : Colors.white)),
      ),
    );
  }

  Widget _buildPageNum(String num, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {},
        child: Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: active ? AppTheme.accentGold : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: Text(num, style: TextStyle(color: active ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
      ),
    );
  }
}
