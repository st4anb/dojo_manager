import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import '../providers/auth_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:animate_do/animate_do.dart';
import '../widgets/status_treino_card.dart';

class CheckinView extends ConsumerStatefulWidget {
  const CheckinView({super.key});

  @override
  ConsumerState<CheckinView> createState() => _CheckinViewState();
}

class _CheckinViewState extends ConsumerState<CheckinView> {
  bool _isCheckingLoc = false;
  bool _successCheckin = false; // Flag para estado de sucesso
  String? _selectedMod;
  bool _didAutoSelectMod = false; // Flag para evitar auto-select durante build

  Future<void> _handleCheckIn() async {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return;

    // Se tiver múltiplas modalidades e nenhuma selecionada, avisa
    if (profile.modalidade.length > 1 && _selectedMod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text('Por favor, selecione a modalidade da aula.')),
      );
      return;
    }

    setState(() => _isCheckingLoc = true);

    try {
      // 1. BUSCA CONFIGURAÇÕES DINÂMICAS DO DOJO
      double dojoLat = -23.4040862; 
      double dojoLng = -46.5391125; 
      double maxDist = 150.0;       

      try {
        final configDoc = await FirebaseFirestore.instance.collection('config').doc('geral').get();
        if (configDoc.exists) {
          final data = configDoc.data()!;
          final bool usarTemp = data['usar_local_temporario'] ?? false;
          dojoLat = (usarTemp ? (data['temp_lat'] ?? dojoLat) : (data['dojo_lat'] ?? dojoLat)).toDouble();
          dojoLng = (usarTemp ? (data['temp_lng'] ?? dojoLng) : (data['dojo_lng'] ?? dojoLng)).toDouble();
          maxDist = (data['checkin_raio'] ?? maxDist).toDouble();
        }
      } catch (_) {}

      // 2. VALIDAÇÃO DE GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'GPS Desativado.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permissão Negada.';
      }
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );

      final distance = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        dojoLat, dojoLng,
      );

      if (!mounted) return;

      if (distance <= maxDist) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // ══════════════════════════════════════════════
          // BLOQUEIO: MÁXIMO 1 CHECK-IN POR DIA
          // ══════════════════════════════════════════════
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

          // 1. Buscamos os check-ins do usuário (apenas filtro de igualdade para evitar erro de índice)
          final existingCheckins = await FirebaseFirestore.instance
              .collection(FirebaseCollections.frequencia)
              .where('aluno_id', isEqualTo: user.uid)
              .get();

          // 2. Mágica: Filtramos pelo dia de HOJE localmente
          final checkinValido = existingCheckins.docs.any((doc) {
            final data = doc.data();
            // Suporte legado: tentamos ler tanto 'dataHora' quanto 'created_at'
            final ts = (data['dataHora'] ?? data['created_at']) as Timestamp?;
            if (ts == null) return false;

            final dt = ts.toDate();
            final isToday = dt.isAfter(startOfDay) && dt.isBefore(endOfDay);
            final status = data['status'] ?? '';
            
            // É de hoje e não foi recusado?
            return isToday && status != 'recusado';
          });

          if (checkinValido) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                  content: Text('🥋 Você já realizou seu check-in hoje! Bom descanso, Oss! 💪'),
                ),
              );
            }
            return; // IMPEDE nova gravação
          }

          // CAPTURA FCM TOKEN PARA NOTIFICAÇÕES (Solicitado)
          String? fcmToken;
          try {
            fcmToken = await FirebaseMessaging.instance.getToken();
          } catch (_) {}

          final mod = _selectedMod ?? profile.modalidade.first;

          // REGISTRA COMO SOLICITAÇÃO (Novo Modelo Padronizado)
          await FirebaseFirestore.instance.collection(FirebaseCollections.frequencia).doc().set({
            'aluno_id': user.uid,
            'aluno_nome': profile.nome ?? 'Aluno',
            'modalidade': mod,
            'status': 'solicitado',
            'fcm_token': fcmToken,
            'dataHora': FieldValue.serverTimestamp(),
          });

          if (!mounted) return;
          setState(() => _successCheckin = true); // Ativa tela de sucesso
        }
      } else {
        throw 'Você precisa estar nas dependências do Dojo. Distância: ${distance.toStringAsFixed(0)}m';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(backgroundColor: Colors.redAccent, content: Text('Falha: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingLoc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    
    // Fallback de modalidade se houver apenas uma
    // HOTFIX: Mover mutação de estado para fora do build() para evitar loop infinito
    if (profile != null && profile.modalidade.length == 1 && _selectedMod == null && !_didAutoSelectMod) {
      _didAutoSelectMod = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedMod == null) {
          setState(() => _selectedMod = profile.modalidade.first);
        }
      });
    }

    if (_successCheckin) {
      return _buildSuccessState();
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatusTreinoCard(studentModalities: profile?.modalidade ?? []),
            const SizedBox(height: 16),
            const Icon(LucideIcons.mapPin, size: 64, color: AppTheme.accentGold),
            const SizedBox(height: 24),
            const Text(
              'Pronto para o Treino?',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sua entrada será validada pelo Sensei assim que você solicitar.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            if (profile != null && profile.modalidade.length > 1) ...[
              const Text('QUAL AULA VOCÊ VAI FAZER?', style: TextStyle(color: AppTheme.accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppTheme.cardDarkGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.glassBorder)),
                child: DropdownButton<String>(
                  value: _selectedMod,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: AppTheme.cardDarkGrey,
                  style: const TextStyle(color: Colors.white),
                  items: profile.modalidade.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _selectedMod = val),
                  hint: const Text('Selecione a modalidade', style: TextStyle(color: AppTheme.textGrey)),
                ),
              ),
              const SizedBox(height: 32),
            ],

            SizedBox(
              height: 64,
              child: ElevatedButton.icon(
                onPressed: _isCheckingLoc ? null : _handleCheckIn,
                icon: _isCheckingLoc 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black))
                    : const Icon(LucideIcons.send, color: Colors.black),
                label: Text(_isCheckingLoc ? 'ENVIANDO SOLICITAÇÃO...' : 'SOLICITAR ENTRADA AGORA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'A autorização do Sensei ignora pendências financeiras.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.greenAccent, width: 2),
                ),
                child: const Icon(LucideIcons.checkCircle, size: 80, color: Colors.greenAccent),
              ),
              const SizedBox(height: 32),
              const Text(
                'Solicitação Enviada!',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Aguarde a autorização do Sensei na porta ou tatame.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
              ),
              const SizedBox(height: 48),
              
              ElevatedButton.icon(
                onPressed: _showDiaryModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(LucideIcons.bookOpen, size: 20),
                label: const Text('REGISTRAR NOTA DE TREINO', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _successCheckin = false),
                child: const Text('VOLTAR AO INÍCIO', style: TextStyle(color: AppTheme.textGrey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDiaryModal() {
    final noteController = TextEditingController();
    int intensity = 3; // 1-5

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDarkGrey,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Diário de Treino 🥋',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'O que você aprendeu hoje? Alguma dificuldade?',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              
              TextField(
                controller: noteController,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: Melhorei a saída da montada e senti dificuldade no gás durante o rola...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 14),
                  filled: true,
                  fillColor: AppTheme.backgroundBlack,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text('NÍVEL DE ESFORÇO / CANSAÇO', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _intensityEmoji(1, '🧘', 'Leve', intensity, (val) => setModalState(() => intensity = val)),
                  _intensityEmoji(2, '🥋', 'Normal', intensity, (val) => setModalState(() => intensity = val)),
                  _intensityEmoji(3, '🔥', 'Intenso', intensity, (val) => setModalState(() => intensity = val)),
                  _intensityEmoji(4, '🥵', 'Exaustivo', intensity, (val) => setModalState(() => intensity = val)),
                  _intensityEmoji(5, '💀', 'Guerra', intensity, (val) => setModalState(() => intensity = val)),
                ],
              ),
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: () async {
                  if (noteController.text.isEmpty) return;
                  await _saveDiaryNote(noteController.text, intensity);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    setState(() => _successCheckin = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nota salva no seu diário!'), backgroundColor: Colors.green),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('SALVAR NO DIÁRIO', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intensityEmoji(int val, String emoji, String label, int current, Function(int) onSelect) {
    bool selected = val == current;
    return GestureDetector(
      onTap: () => onSelect(val),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppTheme.accentGold.withValues(alpha: 0.1) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? AppTheme.accentGold : Colors.white10),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: selected ? AppTheme.accentGold : AppTheme.textGrey, fontSize: 10, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> _saveDiaryNote(String text, int intensity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection(FirebaseCollections.alunos)
        .doc(user.uid)
        .collection(FirebaseCollections.diarioAtleta)
        .add({
      'data_hora': FieldValue.serverTimestamp(),
      'texto_nota': text,
      'intensidade': intensity,
    });
  }
  // Metodos de pagamento e alertas financeiros movidos para dentro do escopo da classe








}
