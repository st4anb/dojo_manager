import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import '../core/services/image_upload_service.dart';
import '../models/modalidade_model.dart';
import '../core/utils/data_seeder.dart';

class ModalityManagementPage extends StatefulWidget {
  const ModalityManagementPage({super.key});

  @override
  State<ModalityManagementPage> createState() => _ModalityManagementPageState();
}

class _ModalityManagementPageState extends State<ModalityManagementPage> {
  final _firestore = FirebaseFirestore.instance;

  String _getDayName(int day) {
    const days = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ];
    if (day < 1 || day > 7) return 'Desconhecido';
    return days[day - 1];
  }

  Future<void> _showModalityForm({ModalidadeModel? modalidade}) async {
    final bool isEditing = modalidade != null;
    final nameController = TextEditingController(text: isEditing ? modalidade.nome : '');
    final professorController = TextEditingController(text: isEditing ? modalidade.professor : '');
    List<Map<String, dynamic>> tempSchedules = isEditing ? List.from(modalidade.gradeHorarios) : [];
    
    String selectedDay = 'Segunda-feira';
    final timeController = TextEditingController(text: '19:00 - 20:30');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDarkGrey,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24, left: 24, right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Editar Modalidade' : 'Nova Modalidade', 
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, color: AppTheme.textGrey)),
                  ],
                ),
                const SizedBox(height: 24),
                
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nome da Modalidade',
                    labelStyle: TextStyle(color: AppTheme.textGrey),
                    hintText: 'Ex: Jiu-Jitsu',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: professorController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Professor Responsável',
                    labelStyle: TextStyle(color: AppTheme.textGrey),
                    hintText: 'Ex: Mestre Hélio',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
                
                const SizedBox(height: 32),
                const Row(
                  children: [
                    Icon(LucideIcons.toggleLeft, color: AppTheme.accentGold, size: 20),
                    SizedBox(width: 8),
                    Text('STATUS DA MODALIDADE', style: TextStyle(color: AppTheme.accentGold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(height: 16),
                
                SwitchListTile(
                  title: const Text('Modalidade Ativa', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Se inativa, não aparecerá na grade para os alunos.', style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                  value: true, // TODO: Link to state
                  activeColor: AppTheme.accentGold,
                  onChanged: (val) {}, // TODO: Link to state
                ),
                
                const SizedBox(height: 32),
                
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      final data = {
                        'nome': nameController.text,
                        'professor': professorController.text,
                        'gradeHorarios': tempSchedules,
                        'ativo': true,
                        if (!isEditing) 'created_at': FieldValue.serverTimestamp(),
                      };
                      
                      if (isEditing) {
                        await _firestore.collection(FirebaseCollections.modalidades).doc(modalidade.id).update(data);
                      } else {
                        await _firestore.collection(FirebaseCollections.modalidades).add(data);
                      }
                      
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isEditing ? 'SALVAR ALTERAÇÕES' : 'CRIAR MODALIDADE', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateBackground(String docId) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
    );

    try {
      final url = await ImageUploadService.uploadImage(image);
      if (url != null) {
        await _firestore.collection(FirebaseCollections.modalidades).doc(docId).update({
          'background_url': url,
        });
      }
    } finally {
      if (mounted) Navigator.pop(context); // Remove progress indicator
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Gestão de Modalidades'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.wrench, color: Colors.greenAccent),
            tooltip: 'Reparar Histórico (Fix Legado)',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.cardDarkGrey,
                  title: const Text('Reparar Histórico?'),
                  content: const Text('Esta ferramenta corrige registros antigos (uid -> aluno_id) para garantir que todos os check-ins passados sejam contados corretamente.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('REPARAR', style: TextStyle(color: Colors.greenAccent))),
                  ],
                ),
              );

              if (confirm == true) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.accentGold),
                        SizedBox(height: 16),
                        Text('Reparando Histórico... Isso pode levar um tempo.', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    )),
                  );

                  int fixedCount = 0;
                  try {
                    final snap = await FirebaseFirestore.instance.collection(FirebaseCollections.frequencia).get();
                    final batch = FirebaseFirestore.instance.batch();
                    int batchCount = 0;

                    for (var doc in snap.docs) {
                      final data = doc.data();
                      bool needsFix = false;
                      Map<String, dynamic> updates = {};

                      // Fix ID field
                      if (data['aluno_id'] == null && data['uid'] != null) {
                        updates['aluno_id'] = data['uid'];
                        needsFix = true;
                      }

                      // Fix Modalidade null to 'Geral' or lowercase
                      if (data['modalidade'] == null) {
                        updates['modalidade'] = 'Geral';
                        needsFix = true;
                      }

                      if (needsFix) {
                        batch.update(doc.reference, updates);
                        batchCount++;
                        fixedCount++;
                        
                        if (batchCount >= 400) {
                          await batch.commit();
                          batchCount = 0;
                        }
                      }
                    }

                    if (batchCount > 0) await batch.commit();

                    if (context.mounted) {
                      Navigator.pop(context); // Remove loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reparo concluído! $fixedCount registros normalizados.'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro no reparo: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.database, color: Colors.blueAccent),
            tooltip: 'Popular Grade Oficial',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.cardDarkGrey,
                  title: const Text('Popular Grade Oficial?'),
                  content: const Text('Isso atualizará os horários das modalidades oficiais do CT Pandora.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('POPULAR', style: TextStyle(color: Colors.blueAccent))),
                  ],
                ),
              );
              if (confirm == true) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
                  );
                }
                await DataSeeder.seedOfficialSchedule();
                if (context.mounted) {
                  Navigator.pop(context); // Remove loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Grade oficial populada com sucesso!')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus, color: AppTheme.accentGold),
            onPressed: () => _showModalityForm(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection(FirebaseCollections.modalidades).orderBy('nome').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Erro ao carregar modalidades: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(LucideIcons.swords, size: 64, color: AppTheme.textGrey),
                   const SizedBox(height: 16),
                   const Text('Nenhuma modalidade cadastrada.', style: TextStyle(color: AppTheme.textGrey)),
                   const SizedBox(height: 24),
                   ElevatedButton(onPressed: () => _showModalityForm(), child: const Text('ADICIONAR PRIMEIRA')),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final modalidade = ModalidadeModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
              final String? bgUrl = modalidade.backgroundUrl;
              final List schedules = modalidade.gradeHorarios;

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.cardDarkGrey,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      if (bgUrl != null && bgUrl.isNotEmpty)
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: bgUrl,
                            imageBuilder: (context, imageProvider) => Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
                                ),
                              ),
                            ),
                            placeholder: (context, url) => Container(color: AppTheme.cardDarkGrey),
                            errorWidget: (context, url, error) => Container(color: AppTheme.cardDarkGrey),
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        modalidade.nome.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      if (modalidade.professor != null && modalidade.professor!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Row(
                                            children: [
                                              const Icon(LucideIcons.user, size: 12, color: AppTheme.accentGold),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Prof. ${modalidade.professor}',
                                                style: const TextStyle(color: AppTheme.accentGold, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(LucideIcons.image, color: Colors.white70, size: 20),
                                        onPressed: () => _updateBackground(modalidade.id),
                                        tooltip: 'Fundo',
                                      ),
                                      IconButton(
                                        icon: const Icon(LucideIcons.calendar, color: AppTheme.accentGold, size: 20),
                                        onPressed: () => showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: AppTheme.cardDarkGrey,
                                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                                          builder: (ctx) => _ScheduleEditor(docId: modalidade.id, schedules: modalidade.gradeHorarios),
                                        ),
                                        tooltip: 'Horários',
                                      ),
                                      IconButton(
                                        icon: const Icon(LucideIcons.pencil, color: Colors.white70, size: 20),
                                        onPressed: () => _showModalityForm(modalidade: modalidade),
                                        tooltip: 'Editar',
                                      ),
                                      IconButton(
                                        icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor: AppTheme.cardDarkGrey,
                                              title: const Text('Excluir Modalidade?'),
                                              content: const Text('Isso removerá os horários e a arte vinculada.'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('EXCLUIR', style: TextStyle(color: Colors.redAccent))),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await _firestore.collection(FirebaseCollections.modalidades).doc(modalidade.id).delete();
                                          }
                                        },
                                        tooltip: 'Excluir',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Icon(LucideIcons.clock, size: 14, color: AppTheme.textGrey),
                                const SizedBox(width: 8),
                                Text(
                                  '${schedules.length} horários cadastrados',
                                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: schedules.take(4).map((s) {
                                final day = s['dia'] is String ? s['dia'].substring(0, 3) : _getDayName(s['dia'] as int).substring(0, 3);
                                final time = s['horario'] ?? '${s['inicio']} - ${s['fim']}';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Text(
                                    '$day: $time',
                                    style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (schedules.length > 4)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('+ ${schedules.length - 4} outros', style: const TextStyle(color: AppTheme.accentGold, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
// Removendo código redundante abaixo...

class _ScheduleEditor extends StatefulWidget {
  final String docId;
  final List<dynamic> schedules;
  const _ScheduleEditor({required this.docId, required this.schedules});

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late List<dynamic> _schedules;
  int _selectedDay = 1; // Segunda
  TimeOfDay _startTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 30);

  @override
  void initState() {
    super.initState();
    _schedules = List.from(widget.schedules);
  }

  String _getDayName(int day) {
    switch (day) {
      case 1: return 'Segunda';
      case 2: return 'Terça';
      case 3: return 'Quarta';
      case 4: return 'Quinta';
      case 5: return 'Sexta';
      case 6: return 'Sábado';
      case 7: return 'Domingo';
      default: return '';
    }
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance.collection(FirebaseCollections.modalidades).doc(widget.docId).update({
      'gradeHorarios': _schedules,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Horários da Aula', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, color: AppTheme.textGrey)),
            ],
          ),
          const SizedBox(height: 24),
          
          // Seletor de Dia
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final isSelected = _selectedDay == dayNum;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_getDayName(dayNum).substring(0, 3)),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedDay = dayNum),
                    selectedColor: AppTheme.accentGold,
                    labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          
          // Seletor de Hora
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('Inicia às', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                  subtitle: Text(_startTime.format(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _startTime);
                    if (picked != null) setState(() => _startTime = picked);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text('Termina às', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                  subtitle: Text(_endTime.format(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _endTime);
                    if (picked != null) setState(() => _endTime = picked);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.plusCircle, color: Colors.greenAccent),
                onPressed: () {
                  setState(() {
                    _schedules.add({
                      'dia': _selectedDay,
                      'inicio': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                      'fim': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                    });
                  });
                },
              ),
            ],
          ),
          
          const Divider(color: Colors.white10, height: 32),
          
          Expanded(
            child: ListView.builder(
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final s = _schedules[index];
                return ListTile(
                  leading: const Icon(LucideIcons.calendar, size: 16, color: AppTheme.textGrey),
                  title: Text(_getDayName(s['dia']), style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text('${s['inicio']} até ${s['fim']}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                    onPressed: () => setState(() => _schedules.removeAt(index)),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('SALVAR ALTERAÇÕES', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
