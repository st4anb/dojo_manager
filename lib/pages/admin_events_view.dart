import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import '../core/services/image_upload_service.dart';

class AdminEventsView extends StatefulWidget {
  const AdminEventsView({super.key});

  @override
  State<AdminEventsView> createState() => _AdminEventsViewState();
}

class _AdminEventsViewState extends State<AdminEventsView> {
  final _tituloCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _linkCompraCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _dataEventoCtrl = TextEditingController();
  final _horarioCtrl = TextEditingController();
  DateTime? _selectedEventDate;
  
  XFile? _imageFile;
  bool _isSaving = false;
  String _loadingText = "PUBLICAR EVENTO AGORA";

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  Future<void> _saveEvent() async {
    if (_tituloCtrl.text.isEmpty || _imageFile == null || _selectedEventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Título, Flyer e Data são obrigatórios.')));
      return;
    }

    setState(() {
      _isSaving = true;
      _loadingText = "FAZENDO UPLOAD DO FLYER...";
    });

    try {
      // 1. Upload para ImgBB (Custo Zero) - EXIGÊNCIA RIGOROSA
      final imageUrl = await ImageUploadService.uploadImage(_imageFile!);
      
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('A API de Hospedagem (ImgBB) não retornou um link válido. Verifique sua conexão ou tente outra imagem.');
      }

      setState(() => _loadingText = "SALVANDO NO BANCO DE DADOS...");

      // 2. Salvar no Firestore (Só chega aqui se o upload deu certo)
      await FirebaseFirestore.instance.collection(FirebaseCollections.eventos).add({
        'titulo': _tituloCtrl.text.trim(),
        'descricao': _descricaoCtrl.text.trim(),
        'link_compra': _linkCompraCtrl.text.trim(),
        'whatsapp': _whatsappCtrl.text.trim(),
        'horario': _horarioCtrl.text.trim(),
        'dataEvento': Timestamp.fromDate(_selectedEventDate!), // Nome de campo sincronizado com Model
        'imagemUrl': imageUrl, // Nome de campo sincronizado com Model
        'ativo': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento publicado com sucesso!'), backgroundColor: Colors.green));
        _tituloCtrl.clear();
        _descricaoCtrl.clear();
        _linkCompraCtrl.clear();
        _whatsappCtrl.clear();
        _dataEventoCtrl.clear();
        _horarioCtrl.clear();
        setState(() {
          _imageFile = null;
          _selectedEventDate = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _loadingText = "PUBLICAR EVENTO AGORA";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gerenciar Eventos', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Publique novos eventos, treinamentos e seminários para os alunos.', style: TextStyle(color: AppTheme.textGrey)),
          const SizedBox(height: 32),
          
          // Form & Flyer
          Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 240,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.cardDarkGrey,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3), width: 1),
                    boxShadow: AppTheme.premiumShadow,
                    image: _imageFile != null ? DecorationImage(image: NetworkImage(_imageFile!.path), fit: BoxFit.cover) : null,
                  ),
                  child: _imageFile == null 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.imagePlus, color: AppTheme.accentGold, size: 48),
                            SizedBox(height: 12),
                            Text('Tocar para Upload do Flyer/Poster', style: TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              _buildField('Título do Evento', _tituloCtrl, icon: LucideIcons.tag),
              const SizedBox(height: 12),
              _buildField('Descrição Detalhada', _descricaoCtrl, icon: LucideIcons.text, maxLines: 3),
              const SizedBox(height: 12),
              _buildField('Horário do Evento (ex: 19:00)', _horarioCtrl, icon: LucideIcons.clock),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dataEventoCtrl,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Data do Evento',
                        labelStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
                        prefixIcon: const Icon(LucideIcons.calendar, color: AppTheme.accentGold, size: 18),
                        filled: true,
                        fillColor: AppTheme.backgroundBlack,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context, 
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(), 
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(primary: AppTheme.accentGold, onPrimary: Colors.black, surface: AppTheme.backgroundBlack),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedEventDate = picked;
                            _dataEventoCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('WhatsApp Dúvidas', _whatsappCtrl, icon: LucideIcons.phone)),
                ],
              ),
              const SizedBox(height: 12),
              _buildField('Link de Inscrição Externa (Opcional)', _linkCompraCtrl, icon: LucideIcons.link),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveEvent,
                  icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)) : const Icon(LucideIcons.send),
                  label: Text(_isSaving ? _loadingText : 'PUBLICAR EVENTO AGORA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 48),
          const Text('Eventos Publicados', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(FirebaseCollections.eventos).orderBy('created_at', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Text('Nenhum evento ativo no momento.', style: TextStyle(color: AppTheme.textGrey));
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final dateObs = data['data_evento'] as Timestamp?;
                  final formattedDate = dateObs != null ? DateFormat('dd/MM/yyyy').format(dateObs.toDate()) : 'Data a definir';

                  return Card(
                    color: AppTheme.cardDarkGrey,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(data['flyer_url'], width: 80, height: 80, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['titulo'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.calendar, size: 14, color: AppTheme.accentGold),
                                    const SizedBox(width: 6),
                                    Text(formattedDate, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                            onPressed: () => docs[index].reference.delete(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {IconData? icon, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textGrey),
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.accentGold, size: 20) : null,
        filled: true,
        fillColor: AppTheme.backgroundBlack,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

