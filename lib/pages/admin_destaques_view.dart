import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../core/theme/app_theme.dart';
import '../models/aluno_destaque_model.dart';
import '../core/services/image_upload_service.dart';

class AdminDestaquesView extends StatefulWidget {
  const AdminDestaquesView({super.key});

  @override
  State<AdminDestaquesView> createState() => _AdminDestaquesViewState();
}

class _AdminDestaquesViewState extends State<AdminDestaquesView> {
  final _nomeCtrl = TextEditingController();
  final _trajetoriaCtrl = TextEditingController();
  XFile? _imageFile;
  Uint8List? _imageBytes;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _saveDestaque() async {
    if (_nomeCtrl.text.isEmpty || _trajetoriaCtrl.text.isEmpty || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, preencha todos os campos e selecione uma foto.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final imageUrl = await ImageUploadService.uploadImage(_imageFile!);
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('Falha no upload da foto para o ImgBB.');
      }

      final model = AlunoDestaqueModel(
        id: '',
        nome: _nomeCtrl.text.trim(),
        trajetoria: _trajetoriaCtrl.text.trim(),
        fotoUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('ALUNOS_DESTAQUES').add(model.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aluno Destaque cadastrado com sucesso!'), backgroundColor: Colors.green));
        _nomeCtrl.clear();
        _trajetoriaCtrl.clear();
        setState(() {
          _imageFile = null;
          _imageBytes = null;
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
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Alunos Destaques 🌟', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const Text('Homenageie os alunos que se destacam por sua evolução e trajetoria', style: TextStyle(color: AppTheme.textGrey)),
          const SizedBox(height: 32),
          
          _buildForm(),
          const SizedBox(height: 32),
          
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          const Text('DESTAQUES ATUAIS', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          
          Expanded(child: _buildRecentList()),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardDarkGrey, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder), boxShadow: AppTheme.premiumShadow),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundBlack,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                  ),
                  child: _imageBytes != null 
                    ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(LucideIcons.userPlus, color: AppTheme.accentGold), SizedBox(height: 4), Text('Foto', style: TextStyle(color: AppTheme.textGrey, fontSize: 10))],
                      ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _nomeCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco('Nome Completo do Aluno'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _trajetoriaCtrl,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco('Descreva a trajetória, superação e conquistas do aluno...'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveDestaque,
              icon: _isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(LucideIcons.star),
              label: Text(_isSaving ? 'SALVANDO...' : 'PUBLICAR DESTAQUE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
      filled: true,
      fillColor: AppTheme.backgroundBlack,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildRecentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ALUNOS_DESTAQUES').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SelectableText(
                'Erro ao carregar destaques: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('Nenhum aluno destacado ainda.', style: TextStyle(color: AppTheme.textGrey)));
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) return const Center(child: Text('Nenhum aluno destacado ainda.', style: TextStyle(color: AppTheme.textGrey)));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final model = AlunoDestaqueModel.fromMap(docs[index].id, data);

            return Card(
              color: AppTheme.backgroundBlack,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
              child: ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(model.fotoUrl)),
                title: Text(model.nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(model.trajetoria, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
                  onPressed: () => docs[index].reference.delete(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
