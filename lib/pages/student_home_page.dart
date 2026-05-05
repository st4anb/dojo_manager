import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/firebase_collections.dart';
import '../core/services/image_upload_service.dart';
import 'checkin_view.dart';
import 'student_history_view.dart';
import 'student_events_view.dart';
import 'schedule_view.dart';
import 'student_store_view.dart';
import 'student_tatame_view.dart';
import '../core/services/notification_service.dart';
import 'package:animate_do/animate_do.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../widgets/glass_container.dart';
import '../widgets/belt_badge.dart';
import '../core/utils/pwa_utils.dart';
// PremiumClickable is provided by glass_container.dart

class StudentHomePage extends ConsumerStatefulWidget {
  const StudentHomePage({super.key});

  @override
  ConsumerState<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends ConsumerState<StudentHomePage> {
  int _selectedIndex = 0;
  bool _isUploading = false;
  late Stream<QuerySnapshot> _eventsStream;
  late Stream<DocumentSnapshot> _configGeralStream;
  late Stream<DocumentSnapshot> _appSettingsStream;
  Stream<QuerySnapshot>? _frequenciaStream;
  Stream<QuerySnapshot>? _destaquesStream;

  @override
  void initState() {
    super.initState();
    _eventsStream = FirebaseFirestore.instance
        .collection(FirebaseCollections.eventos)
        .where('data_evento', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('data_evento')
        .limit(1)
        .snapshots();
    
    _configGeralStream = FirebaseFirestore.instance.collection('config').doc('geral').snapshots();
    _appSettingsStream = FirebaseFirestore.instance.collection('config').doc('appSettings').snapshots();
    
    _initNotificationCapture();
  }

  void _initNotificationCapture() {
    // Inicializa o serviço de notificações uma única vez
    NotificationService.instance.init();
  }

  Future<void> _pickAndUploadAvatar(String uid) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final uploadUrl = await ImageUploadService.uploadImage(image);
      
      if (uploadUrl == null) {
        throw Exception('Erro ao hospedar imagem no ImgBB.');
      }

      await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(uid).update({
        'dados_pessoais.foto_url': uploadUrl,
        'foto_url': uploadUrl,
      });
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto de perfil atualizada!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao subir foto: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showExpandedQrCode(BuildContext context, String qrData) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Passe Catraca', style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 250.0,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('FECHAR', style: TextStyle(fontSize: 16)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.value;

    // Escuta mudanças no perfil para sincronizar notificações (Executa apenas uma vez devido às flags no serviço)
    ref.listen(userProfileProvider, (prev, next) {
      if (next.hasValue && next.value != null) {
        final p = next.value!;
        NotificationService.instance.getAndSaveToken(p.uid);
        if (p.role == 'aluno') {
          NotificationService.instance.agendarNotificacoesTreino(p.modalidade);
        }
      }
    });
    
    final qrData = user?.uid ?? 'UID_PENDENTE'; 
    final faixaAtual = profile?.faixa ?? 'BRANCA';
    final isApto = profile?.aptoExameFaixa ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Aluno'),
        actions: [
          Builder(
            builder: (context) {
              final isPendente = profile?.financialStatus != FinancialState.pago;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.bell), 
                    onPressed: () {
                      if (isPendente) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.orange,
                            content: Text('Você possui pendências financeiras. Verifique sua aba de Evolução.'),
                          )
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nenhuma notificação nova.'))
                        );
                      }
                    }
                  ),
                  if (isPendente)
                    Positioned(
                      right: 12, top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    )
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: AppTheme.accentGold),
            onPressed: () => PWAUtils.hardRefresh(),
            tooltip: 'Atualizar App (Hard Refresh)',
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut, color: Colors.redAccent), 
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(user, profile, faixaAtual, isApto, qrData)),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.backgroundBlack,
        selectedItemColor: AppTheme.accentGold,
        unselectedItemColor: AppTheme.textGrey,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.mapPin), label: 'Check-in'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Evolução'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.video), label: 'Tatame'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.history), label: 'Histórico'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.calendar), label: 'Eventos'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.layoutGrid), label: 'Grade'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.shoppingCart), label: 'Vitrine'),
        ],
      ),
    );
  }

  Widget _buildBody(User? user, UserProfileData? profile, String faixaAtual, bool isApto, String qrData) {
    return Column(
      children: [
        _buildUpcomingEventBanner(),
        Expanded(
          child: _buildCurrentTab(user, profile, faixaAtual, isApto, qrData),
        ),
      ],
    );
  }

  Widget _buildUpcomingEventBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        
        final event = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final eventDate = (event['data_evento'] as Timestamp).toDate();
        final daysLeft = eventDate.difference(DateTime.now()).inDays + 1;

        if (daysLeft > 3) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.accentGold,
          child: Row(
            children: [
              const Icon(LucideIcons.calendarClock, color: Colors.black, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ALERTA DE EVENTO: ${event['titulo']} - (${DateFormat('dd/MM').format(eventDate)})! Faltam $daysLeft dias.',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: Colors.black, size: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentTab(User? user, UserProfileData? profile, String faixaAtual, bool isApto, String qrData) {
    switch (_selectedIndex) {
      case 0:
        return const CheckinView();
      case 1:
        return _buildEvolutionView(user, profile, faixaAtual, isApto, qrData);
      case 2:
        return const StudentTatameView();
      case 3:
        return StudentHistoryView(userId: user?.uid ?? '');
      case 4:
        return const StudentEventsView();
      case 5:
        return const ScheduleView(filterModalities: null);
      case 6:
        return _buildStoreTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStoreTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _appSettingsStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final lojaAtiva = data?['lojaAtiva'] as bool? ?? true; 

        if (!lojaAtiva) {
          return const Center(child: Text('Loja Desativada temporariamente.', style: TextStyle(color: AppTheme.textGrey)));
        }
        
        return const StudentStoreView();
      },
    );
  }

  Widget _buildEvolutionView(User? user, UserProfileData? profile, String faixaAtual, bool isApto, String qrData) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _configGeralStream,
      builder: (context, configSnap) {
        final config = configSnap.data?.data() as Map<String, dynamic>? ?? {};

        if (profile == null) {
          return const Center(child: Text('Carregando Perfil...', style: TextStyle(color: AppTheme.accentGold)));
        }

        try {
          _frequenciaStream ??= FirebaseFirestore.instance
              .collection(FirebaseCollections.frequencia)
              .where(
                Filter.or(
                  Filter('aluno_id', isEqualTo: user?.uid), 
                  Filter('uid', isEqualTo: user?.uid),
                  Filter('user_id', isEqualTo: user?.uid)
                )
              )
              .snapshots();

          return StreamBuilder<QuerySnapshot>(
            stream: _frequenciaStream,
            builder: (context, checkinsSnap) {
              if (checkinsSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 40),
                        const SizedBox(height: 16),
                        const Text('Erro ao carregar evolução', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(checkinsSnap.error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }

              final allDocs = checkinsSnap.data?.docs ?? [];
              final approvedCheckins = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status']?.toString().toLowerCase() ?? '';
                return status == 'aprovado';
              }).toList();
              
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: () => setState(() => _selectedIndex = 0),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.accentGold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Esqueceu de fazer o Check-in? Clique aqui', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    Builder(builder: (context) {
                      _destaquesStream ??= FirebaseFirestore.instance.collection('ALUNOS_DESTAQUES').orderBy('createdAt', descending: true).limit(5).snapshots();
                      return StreamBuilder<QuerySnapshot>(
                        stream: _destaquesStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                        final destaques = snapshot.data!.docs;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ESTRELAS DO DOJO 🌟',
                              style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: destaques.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  return Container(
                                    width: 280,
                                    margin: const EdgeInsets.only(right: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardDarkGrey,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppTheme.glassBorder),
                                      boxShadow: AppTheme.premiumShadow,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 35,
                                          backgroundImage: NetworkImage(data['fotoUrl'] ?? ''),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                data['nome'] ?? '',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                data['trajetoria'] ?? '',
                                                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11, height: 1.3),
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    );
                  }),
                  _buildProfileCard(profile, faixaAtual, user, realTimeCount: approvedCheckins.length),
                    const SizedBox(height: 24),
                    if (profile != null)
                      Column(
                        children: profile.modalidade.where((m) => m.isNotEmpty).map((mod) {
                          final faixaMod = profile.getFaixaFor(mod);
                          final int metaMod = profile.resolverMetaExame(config, targetMod: mod);
                          final int metaKi = profile.resolverMetaKi(config, targetMod: mod);
                          final int totalMod = approvedCheckins.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final String modDoc = data['modalidade']?.toString().toLowerCase().trim() ?? 'geral';
                            final String targetMod = mod.toLowerCase().trim();
                            return modDoc == targetMod || modDoc == 'geral';
                          }).length;
                          
                          final int currentKi = profile.kiPorModalidade[mod] ?? 0;

                          return _ModalityProgressCard(
                            totalAulas: totalMod,
                            mod: mod,
                            faixaMod: faixaMod,
                            metaMod: metaMod,
                            currentKi: currentKi,
                            metaKi: metaKi,
                            isLoading: checkinsSnap.connectionState == ConnectionState.waiting,
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    _buildPatchesWall(profile),
                    const SizedBox(height: 24),
                    _buildStableRecentHistory(approvedCheckins),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TREINOS NO MÊS', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('${_countMonthlyCheckins(approvedCheckins)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                              ],
                            ),
                            const Icon(LucideIcons.flame, color: Colors.orange, size: 40),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDarkGrey,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.2)),
                        boxShadow: AppTheme.premiumShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HALL DA FAMA 🏆',
                            style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildAchievementItem(LucideIcons.medal, 'MEDALHAS', profile.carreira.medalhas, Colors.blueAccent),
                              _buildAchievementItem(LucideIcons.award, 'TROFÉUS', profile.carreira.trofeus, AppTheme.accentGold),
                              _buildAchievementItem(LucideIcons.crown, 'CINTURÕES', profile.carreira.cinturoes, Colors.orangeAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: ListTile(
                        leading: const Icon(LucideIcons.qrCode, color: AppTheme.accentGold),
                        title: const Text('PASSE DE ACESSO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Clique para abrir a catraca via QR Code', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                        onTap: () => _showExpandedQrCode(context, qrData),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          );
        } catch (e) {
          return Center(child: Text('Erro na Evolução: $e', style: const TextStyle(color: Colors.white)));
        }
      },
    );
  }

  int _countMonthlyCheckins(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;
    final now = DateTime.now();
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = (data['created_at'] ?? data['dataHora'] ?? data['data_hora']) as Timestamp?;
      if (ts == null) return false;
      final dt = ts.toDate();
      return dt.month == now.month && dt.year == now.year;
    }).length;
  }

  int _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return 0;
    try {
      final parts = birthDateStr.split('/');
      if (parts.length != 3) return 0;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final birthDate = DateTime(year, month, day);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildProfileCard(UserProfileData? profile, String faixaAtual, User? user, {int? realTimeCount}) {
    return PremiumClickable(
      onTap: () {},
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _isUploading ? null : () => _pickAndUploadAvatar(profile?.uid ?? ''),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: 'student_avatar',
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: profile?.fotoUrl == null ? AppTheme.premiumGoldGradient : null,
                        image: profile?.fotoUrl != null ? DecorationImage(
                          image: CachedNetworkImageProvider(profile!.fotoUrl!),
                          fit: BoxFit.cover,
                        ) : null,
                        boxShadow: [
                          BoxShadow(
                            color: profile?.fotoUrl == null 
                                ? AppTheme.accentGold.withValues(alpha: 0.3) 
                                : Colors.black.withValues(alpha: 0.5),
                            blurRadius: 15,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: profile?.fotoUrl == null ? Text(
                        (profile?.nome != null && profile!.nome!.isNotEmpty) 
                            ? profile.nome!.substring(0, 1).toUpperCase() 
                            : 'A',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                        ),
                      ) : null,
                    ),
                  ),
                  if (_isUploading)
                    const GlassContainer(
                      shape: BoxShape.circle,
                      opacity: 0.5,
                      child: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
                    ),
                  if (!_isUploading)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppTheme.accentGold, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.camera, color: Colors.black, size: 14),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              profile?.nome?.toUpperCase() ?? 'ALUNO',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            BeltBadge(faixa: faixaAtual),
            const SizedBox(height: 24),
            // LINHA DE ESTATÍSTICAS (NOVO DESIGN)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatItem('IDADE', profile?.idade != null ? '${profile!.idade}' : '${_calculateAge(profile?.nascimento)}'),
                  _buildStatSeparator(),
                  _buildStatItem('TREINOS', (realTimeCount ?? profile?.frequenciaTotal ?? 0).toString()),
                  _buildStatSeparator(),
                  _buildStatItem(
                    'PESO', 
                    '${profile?.peso?.toStringAsFixed(0) ?? "--"}',
                    onTap: () => _showEditBiometricsModal(context, profile?.peso, profile?.altura, profile?.uid, profile?.nascimento),
                  ),
                  _buildStatSeparator(),
                  _buildStatItem(
                    'ALTURA', 
                    '${profile?.altura?.toStringAsFixed(2) ?? "--"}',
                    onTap: () => _showEditBiometricsModal(context, profile?.peso, profile?.altura, profile?.uid, profile?.nascimento),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: AppTheme.accentGold, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSeparator() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white.withValues(alpha: 0.05),
    );
  }

  void _showEditBiometricsModal(BuildContext context, double? initialPeso, double? initialAltura, String? uid, String? nascimento) {
    if (uid == null) return;
    final pesoMask = MaskTextInputFormatter(mask: "###,##", filter: {"#": RegExp(r'[0-9]')}, initialText: initialPeso?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
    final alturaMask = MaskTextInputFormatter(mask: "#,##", filter: {"#": RegExp(r'[0-9]')}, initialText: initialAltura?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
    final pesoController = TextEditingController(text: pesoMask.getMaskedText());
    final alturaController = TextEditingController(text: alturaMask.getMaskedText());
    final idadeCalculada = _calculateAge(nascimento);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDarkGrey,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Atualizar Biometria', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              enabled: false,
              controller: TextEditingController(text: '$idadeCalculada anos'),
              style: const TextStyle(color: AppTheme.textGrey),
              decoration: const InputDecoration(labelText: 'Idade (Baseado no Nascimento)', prefixIcon: Icon(LucideIcons.calendar, size: 18, color: AppTheme.textGrey)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pesoController,
              keyboardType: TextInputType.number,
              inputFormatters: [pesoMask],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Peso (Kg)', hintText: '00,00', prefixIcon: Icon(LucideIcons.dumbbell, size: 18, color: AppTheme.textGrey)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: alturaController,
              keyboardType: TextInputType.number,
              inputFormatters: [alturaMask],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Altura (m)', hintText: '0,00', prefixIcon: Icon(LucideIcons.ruler, size: 18, color: AppTheme.textGrey)),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final double? p = double.tryParse(pesoController.text.replaceAll(',', '.'));
                final double? a = double.tryParse(alturaController.text.replaceAll(',', '.'));
                await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(uid).update({
                  'peso': p, 
                  'altura': a,
                  'dados_pessoais.peso': p,
                  'dados_pessoais.altura': a,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('Dados biométricos atualizados!')));
                }
              },
              child: const Text('SALVAR ALTERAÇÕES'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumInfoItem(IconData icon, String label, String value, {VoidCallback? onTap, bool showEditIcon = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, size: 14, color: AppTheme.accentGold),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              if (showEditIcon) ...[const SizedBox(width: 4), const Icon(LucideIcons.pencil, size: 8, color: AppTheme.accentGold)],
            ],
          ),
          Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildPremiumInfoSeparator() {
    return Container(height: 20, width: 1, color: Colors.white.withValues(alpha: 0.1));
  }

  Widget _buildAchievementItem(IconData icon, String label, int value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 12),
        Text(value.toString(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildStableRecentHistory(List<QueryDocumentSnapshot> checkins) {
    if (checkins.isEmpty) return const SizedBox.shrink();
    final recent = checkins.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('HISTÓRICO RECENTE 🕒', style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 16),
        ...recent.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final modalidade = data['modalidade'] ?? 'Geral';
          final ts = (data['created_at'] ?? data['dataHora'] ?? data['data_hora']) as Timestamp?;
          final dataFormatada = ts != null ? DateFormat('dd/MM - HH:mm').format(ts.toDate()) : '--';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.cardDarkGrey, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder), boxShadow: AppTheme.premiumShadow),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(LucideIcons.calendarCheck, color: AppTheme.accentGold, size: 18)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(modalidade.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 4), Text(dataFormatada, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12))])),
                const Icon(LucideIcons.checkCircle2, color: Colors.greenAccent, size: 20),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ModalityProgressCard extends StatelessWidget {
  final int totalAulas;
  final String mod;
  final String faixaMod;
  final int metaMod;
  final int currentKi;
  final int metaKi;
  final bool isLoading;

  const _ModalityProgressCard({
    required this.totalAulas, 
    required this.mod, 
    required this.faixaMod, 
    required this.metaMod, 
    required this.currentKi,
    required this.metaKi,
    required this.isLoading
  });

  @override
  Widget build(BuildContext context) {
    final int safeMeta = metaMod <= 0 ? 40 : metaMod;
    final int safeMetaKi = metaKi <= 0 ? 100 : metaKi;
    
    final double progressoFisico = (totalAulas / safeMeta).clamp(0.0, 1.0);
    final double progressoKi = (currentKi / safeMetaKi).clamp(0.0, 1.0);
    
    final bool aptoAssiduidade = totalAulas >= safeMeta;
    final bool aptoTeorico = currentKi >= safeMetaKi;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      opacity: 0.03,
      border: Border.all(
        color: (aptoAssiduidade && aptoTeorico) ? AppTheme.accentGold.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08), 
        width: 1.5
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.swords, size: 16, color: AppTheme.accentGold), 
              const SizedBox(width: 12), 
              Text(mod.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5))
            ]
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // COLUNA 1: FAIXA (80px fixos)
              SizedBox(
                width: 80,
                child: Center(child: BeltBadge(faixa: faixaMod, isSmall: true)),
              ),
              const SizedBox(width: 16),
              // COLUNA 2: BARRAS (1fr)
              Expanded(
                child: Column(
                  children: [
                    _XPProgressBar(
                      progresso: progressoFisico, 
                      atual: totalAulas, 
                      meta: safeMeta, 
                      completo: aptoAssiduidade,
                      label: 'TREINOS FÍSICOS',
                      icon: LucideIcons.calendarCheck,
                      gradient: const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)]), // Azul Suor/Esforço
                    ),
                    const SizedBox(height: 16),
                    _XPProgressBar(
                      progresso: progressoKi, 
                      atual: currentKi, 
                      meta: safeMetaKi, 
                      completo: aptoTeorico,
                      label: 'CONHECIMENTO KI',
                      icon: LucideIcons.brain,
                      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]), // Ouro/Âmbar
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _XPProgressBar extends StatefulWidget {
  final double progresso;
  final int atual;
  final int meta;
  final bool completo;
  final String label;
  final IconData icon;
  final LinearGradient gradient;

  const _XPProgressBar({
    required this.progresso, 
    required this.atual, 
    required this.meta, 
    required this.completo,
    required this.label,
    required this.icon,
    required this.gradient,
  });

  @override
  State<_XPProgressBar> createState() => _XPProgressBarState();
}

class _XPProgressBarState extends State<_XPProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 12, color: AppTheme.textGrey),
                const SizedBox(width: 8),
                Text(widget.label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
            Text('${widget.atual}/${widget.meta}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              height: 14,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(50), border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5)),
            ),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutQuart,
              tween: Tween(begin: 0.0, end: widget.progresso),
              builder: (context, value, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double currentWidth = constraints.maxWidth * value;
                    if (currentWidth <= 0) return const SizedBox.shrink();
                    return AnimatedBuilder(
                      animation: _scanCtrl,
                      builder: (context, child) {
                        return Container(
                          height: 12,
                          width: currentWidth,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(color: widget.gradient.colors.first.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: widget.gradient,
                                  ),
                                ),
                                Positioned.fill(
                                  child: ShaderMask(
                                    shaderCallback: (rect) {
                                      final center = _scanCtrl.value;
                                      return LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [Colors.transparent, Colors.white.withValues(alpha: 0.0), Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.0), Colors.transparent],
                                        stops: [(center - 0.2).clamp(0.0, 1.0), (center - 0.1).clamp(0.0, 1.0), center.clamp(0.0, 1.0), (center + 0.1).clamp(0.0, 1.0), (center + 0.2).clamp(0.0, 1.0)],
                                      ).createShader(rect);
                                    },
                                    blendMode: BlendMode.srcATop,
                                    child: Container(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

  Widget _buildPatchesWall(UserProfileData? profile) {
    if (profile == null || profile.patchesPorModalidade.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardDarkGrey,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INSÍGNIAS DE ESTUDO (PATCHES) 🎖️', style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: profile.patchesPorModalidade.entries.map((entry) {
              return Column(
                children: [
                  Container(
                    width: 70, height: 70,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3), width: 2),
                      boxShadow: [BoxShadow(color: AppTheme.accentGold.withValues(alpha: 0.1), blurRadius: 10)],
                    ),
                    child: CircleAvatar(
                      backgroundColor: AppTheme.backgroundBlack,
                      backgroundImage: CachedNetworkImageProvider(entry.value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(entry.key.toUpperCase(), style: const TextStyle(color: AppTheme.textGrey, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
