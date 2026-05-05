import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:async';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../models/modalidade_model.dart';
import '../widgets/glass_container.dart'; // [IMPORT]

class ScheduleView extends ConsumerStatefulWidget {
  final List<String>? filterModalities;
  const ScheduleView({super.key, this.filterModalities});

  @override
  ConsumerState<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends ConsumerState<ScheduleView> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  String? _selectedModalityId;
  int _selectedDay = (DateTime.now().weekday >= 1 && DateTime.now().weekday <= 6) ? DateTime.now().weekday : 1;

  @override
  void initState() {
    super.initState();
    // Inicia o timer para atualizar o estado "Ao Vivo" a cada minuto
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const List<String> _dayLabels = ['Todos', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
  static const List<int> _dayValues = [0, 1, 2, 3, 4, 5, 6];

  String _getDayFullName(int day) {
    switch (day) {
      case 1: return 'Segunda-feira';
      case 2: return 'Terça-feira';
      case 3: return 'Quarta-feira';
      case 4: return 'Quinta-feira';
      case 5: return 'Sexta-feira';
      case 6: return 'Sábado';
      case 7: return 'Domingo';
      default: return 'Dia';
    }
  }

  int _getDayValueFromString(String day) {
    switch (day) {
      case 'Segunda-feira': return 1;
      case 'Terça-feira': return 2;
      case 'Quarta-feira': return 3;
      case 'Quinta-feira': return 4;
      case 'Sexta-feira': return 5;
      case 'Sábado': return 6;
      case 'Domingo': return 7;
      default: return 1;
    }
  }

  Color _getModalityColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('jiu') || lower.contains('bjj')) return Colors.blueAccent;
    if (lower.contains('muay') || lower.contains('boxe') || lower.contains('kick')) return Colors.redAccent;
    if (lower.contains('judô') || lower.contains('judo')) return Colors.greenAccent;
    if (lower.contains('karate') || lower.contains('karatê')) return Colors.orangeAccent;
    if (lower.contains('funcional') || lower.contains('fitness')) return Colors.purpleAccent;
    return AppTheme.accentGold;
  }

  IconData _getModalityIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('jiu') || lower.contains('bjj')) return LucideIcons.shield;
    if (lower.contains('muay') || lower.contains('boxe') || lower.contains('kick')) return LucideIcons.flame;
    if (lower.contains('judô') || lower.contains('judo')) return LucideIcons.medal;
    if (lower.contains('karate') || lower.contains('karatê')) return LucideIcons.swords;
    if (lower.contains('wrestling') || lower.contains('luta')) return LucideIcons.users;
    if (lower.contains('funcional') || lower.contains('fitness')) return LucideIcons.dumbbell;
    return LucideIcons.swords;
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove emojis e símbolos
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider).value;
    final bool isAdmin = userProfile?.role == 'admin';

    // Índice da aba que corresponde ao dia atual (seg=0 ... sáb=5). Domingo → seg
    final int initialTabIndex = (_now.weekday >= 1 && _now.weekday <= 6) ? _now.weekday - 1 : 0;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.modalidades)
          .orderBy('nome')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('❌ Erro Firestore (Grade): ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertTriangle, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Erro ao carregar a grade.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Verifique sua conexão ou fale com o Sensei.',
                  style: TextStyle(color: AppTheme.textGrey.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
        }

        final allDocs = snapshot.data?.docs ?? [];
        
        // Log de diagnóstico (DEBUG) para identificar sumiço da grade
        if (allDocs.isEmpty) {
          debugPrint('⚠️ AVISO: Coleção MODALIDADES retornou vazia do Firestore.');
        }

        // FILTRO DE PERFIL E STATUS (Chave Primária e Segura) ⚡
        final docs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          
          // 1. Filtro de Ativação (Regra de Ouro)
          final bool isAtivo = d['ativo'] ?? true;
          if (!isAtivo) return false;

          if (widget.filterModalities != null && 
              widget.filterModalities!.isNotEmpty && 
              !widget.filterModalities!.contains('Geral')) {
            
            final modId = doc.id;
            final modName = _normalize(d['nome'] as String? ?? '');
            
            // Verifica se qualquer uma das modalidades do aluno bate com a da grade (ID ou Nome)
            return widget.filterModalities!.any((m) {
              // Primeiro tenta match por ID (mais seguro)
              if (m == modId) return true;
              
              // Fallback para match por Nome normalizado
              final studentMod = _normalize(m);
              return studentMod == modName || 
                     modName.contains(studentMod) || 
                     studentMod.contains(modName);
            });
          }
          return true;
        }).toList();

        if (docs.isEmpty && allDocs.isNotEmpty) {
          // [PROTOCOLO FINAL] Fallback Obrigatório para Grade Global
          return _buildGlobalGradeFallback(allDocs);
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.calendarOff, size: 64, color: AppTheme.textGrey),
                const SizedBox(height: 16),
                const Text('Nenhuma aula para suas modalidades.', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedModalityId = null),
                  child: const Text('LIMPAR FILTROS', style: TextStyle(color: AppTheme.accentGold)),
                ),
              ],
            ),
          );
        }



        // Constrói a lista flat de todas as aulas usando o Modelo oficial
        final List<_AulaData> todasAulas = [];

        for (var doc in docs) {
          final modalidade = ModalidadeModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          
          for (var h in modalidade.gradeHorarios) {
            int diaVal;
            String inicio;
            String fim;

            if (h['dia'] is String) {
              diaVal = _getDayValueFromString(h['dia']);
              final String timeStr = h['horario'] ?? '00:00 - 00:00';
              final parts = timeStr.split(' - ');
              inicio = parts[0];
              fim = parts.length > 1 ? parts[1] : '00:00';
            } else {
              diaVal = h['dia'] as int? ?? 1;
              inicio = h['inicio'] as String? ?? '00:00';
              fim = h['fim'] as String? ?? '00:00';
            }

            todasAulas.add(_AulaData(
              modalityId: modalidade.id,
              modalidade: modalidade.nome,
              dia: diaVal,
              inicio: inicio,
              fim: fim,
              backgroundUrl: modalidade.backgroundUrl ?? '',
              originalData: h,
              professor: h['professor'] as String? ?? 'Sensei Michael',
            ));
          }
        }

        // Mapa de modalidades ativas para o Dropdown no Admin
        final Map<String, String> modMap = {for (var doc in docs) doc.id: (doc.data() as Map<String, dynamic>)['nome'] as String? ?? 'Geral'};

        // Ordenação Dinâmica
        todasAulas.sort((a, b) {
          if (_selectedDay == 0) {
            final diaComp = a.dia.compareTo(b.dia);
            if (diaComp != 0) return diaComp;
          }
          return a.inicio.compareTo(b.inicio);
        });

        final aulasFiltradas = todasAulas.where((a) => 
          (_selectedDay == 0 || a.dia == _selectedDay) && 
          (_selectedModalityId == null || a.modalityId == _selectedModalityId)
        ).toList();

        final Map<String, List<_AulaData>> groupedAulas = {};
        if (_selectedDay == 0) {
          for (var aula in aulasFiltradas) {
            final dayName = _getDayFullName(aula.dia);
            groupedAulas.putIfAbsent(dayName, () => []).add(aula);
          }
        }

        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GRADE DE HORÁRIOS',
                        style: TextStyle(
                          color: AppTheme.accentGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const Text(
                        'CT PANDORA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Filtro de Dia
                      const Text('Dia da Semana', style: TextStyle(color: AppTheme.textGrey, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _dayValues.map((day) {
                            final isSelected = _selectedDay == day;
                            final label = _dayLabels[_dayValues.indexOf(day)];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (val) => setState(() => _selectedDay = day),
                                selectedColor: AppTheme.accentGold,
                                backgroundColor: AppTheme.glassBg,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: isSelected ? AppTheme.accentGold : AppTheme.glassBorder),
                                showCheckmark: false,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Filtro de Modalidade
                      const Text('Modalidade', style: TextStyle(color: AppTheme.textGrey, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('TODAS'),
                                selected: _selectedModalityId == null,
                                onSelected: (val) => setState(() => _selectedModalityId = null),
                                selectedColor: AppTheme.accentGold.withValues(alpha: 0.3),
                                backgroundColor: AppTheme.glassBg,
                                labelStyle: TextStyle(
                                  color: _selectedModalityId == null ? AppTheme.accentGold : Colors.white,
                                  fontWeight: _selectedModalityId == null ? FontWeight.bold : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: _selectedModalityId == null ? AppTheme.accentGold : AppTheme.glassBorder),
                                showCheckmark: false,
                              ),
                            ),
                            ...docs.map((doc) {
                              final id = doc.id;
                              final nome = (doc.data() as Map<String, dynamic>)['nome'] ?? '';
                              final isSelected = _selectedModalityId == id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(nome.toUpperCase()),
                                  selected: isSelected,
                                  onSelected: (val) => setState(() => _selectedModalityId = isSelected ? null : id),
                                  selectedColor: AppTheme.accentGold.withValues(alpha: 0.3),
                                  backgroundColor: AppTheme.glassBg,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppTheme.accentGold : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: isSelected ? AppTheme.accentGold : AppTheme.glassBorder),
                                  showCheckmark: false,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth > 900;
              final int crossCount = constraints.maxWidth > 1200 ? 3 : (constraints.maxWidth > 800 ? 2 : 1);
              
              if (aulasFiltradas.isEmpty) {
                return Center(
                  child: FadeIn(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.searchX, size: 48, color: AppTheme.textGrey),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhuma aula encontrada para este filtro.',
                          style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (_selectedDay == 0) {
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: groupedAulas.entries.expand((entry) {
                    return [
                      SliverToBoxAdapter(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSectionHeader(entry.key),
                      )),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: isDesktop 
                          ? SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 160,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildScheduleItem(entry.value[index], index, _now, entry.value[index].dia, isAdmin, modMap),
                                childCount: entry.value.length,
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildScheduleItem(entry.value[index], index, _now, entry.value[index].dia, isAdmin, modMap),
                                childCount: entry.value.length,
                              ),
                            ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 48)), // Envelopamento (Margin entre dias)
                    ];
                  }).toList(),
                );
              }

              if (isDesktop) {
                return GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    mainAxisExtent: 160,
                  ),
                  itemCount: aulasFiltradas.length,
                  itemBuilder: (context, index) {
                    final aula = aulasFiltradas[index];
                    return _buildScheduleItem(aula, index, _now, aula.dia, isAdmin, modMap);
                  },
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: aulasFiltradas.length,
                itemBuilder: (context, index) {
                  final aula = aulasFiltradas[index];
                  return _buildScheduleItem(aula, index, _now, aula.dia, isAdmin, modMap);
                },
              );
            },
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // LISTA VERTICAL DE MODALIDADES (ANTIGO CARROSSEL)
  // ═══════════════════════════════════════════════════════
  Widget _buildModalityVerticalList(List<QueryDocumentSnapshot> docs) {
    return Column(
      children: docs.map((doc) {
        final id = doc.id;
        final data = doc.data() as Map<String, dynamic>;
        final nome = data['nome'] as String? ?? 'Modalidade';
        final bgUrl = data['background_url'] as String? ?? '';
        final List horariosRaw = (data['gradeHorarios'] ?? data['horarios'] ?? []);
        final isActive = _selectedModalityId == id;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _selectedModalityId = (_selectedModalityId == id ? null : id)),
              highlightColor: AppTheme.accentGold.withValues(alpha: 0.1),
              splashColor: AppTheme.accentGold.withValues(alpha: 0.2),
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? AppTheme.accentGold : Colors.transparent,
                    width: 2,
                  ),
                  image: bgUrl.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(bgUrl),
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                          isActive 
                            ? Colors.black.withValues(alpha: 0.4) 
                            : Colors.black.withValues(alpha: 0.6),
                          BlendMode.darken,
                        ),
                      )
                    : null,
                  color: AppTheme.cardDarkGrey,
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: AppTheme.accentGold.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ] : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Icon(
                          _getModalityIcon(nome),
                          size: 24,
                          color: AppTheme.accentGold.withValues(alpha: 0.6),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Georgia',
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(LucideIcons.clock, size: 10, color: AppTheme.accentGold),
                                const SizedBox(width: 6),
                                Text(
                                  '${horariosRaw.length} aulas na semana',
                                  style: const TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ITEM DA GRADE DE HORÁRIOS
  // ═══════════════════════════════════════════════════════
  Widget _buildScheduleItem(_AulaData aula, int index, DateTime currentFullTime, int tabWeekday, bool isAdmin, Map<String, String> modMap) {
    final currentTime = '${currentFullTime.hour.toString().padLeft(2, '0')}:${currentFullTime.minute.toString().padLeft(2, '0')}';
    final bool isToday = currentFullTime.weekday == tabWeekday;
    final bool isLive = isToday &&
        currentTime.compareTo(aula.inicio) >= 0 &&
        currentTime.compareTo(aula.fim) < 0;
    final bool isPast = isToday && currentTime.compareTo(aula.fim) >= 0;

    final modalityColor = _getModalityColor(aula.modalidade);

    return FadeInUp(
      duration: Duration(milliseconds: 200 + (index * 50)),
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 16),
        borderRadius: 20,
        blur: 15,
        opacity: 0.05,
        border: Border.all(
          color: isLive ? AppTheme.accentGold.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
          width: 1, 
        ),
        boxShadow: isLive ? [
          BoxShadow(
            color: AppTheme.accentGold.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ] : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Indicador Lateral Esquerdo
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: modalityColor,
                    boxShadow: [
                      BoxShadow(color: modalityColor.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 1),
                    ],
                  ),
                ),
              ),
              // Background Image (if any)
              if (aula.backgroundUrl.isNotEmpty)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: aula.backgroundUrl,
                    imageBuilder: (context, imageProvider) => Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: isPast ? 0.8 : 0.6),
                            BlendMode.darken,
                          ),
                        ),
                      ),
                    ),
                    placeholder: (context, url) => Container(color: AppTheme.cardDarkGrey),
                    errorWidget: (context, url, error) => Container(color: AppTheme.cardDarkGrey),
                  ),
                ),
              
              // Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Coluna de Horário
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          aula.inicio,
                          style: TextStyle(
                            color: isLive ? AppTheme.accentGold : Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        Text(
                          aula.fim,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    const VerticalDivider(
                      color: Colors.white10,
                      indent: 10,
                      endIndent: 10,
                      width: 40,
                    ),

                    // Informações da Aula
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(_getModalityIcon(aula.modalidade), size: 14, color: AppTheme.accentGold),
                              const SizedBox(width: 8),
                              Text(
                                _getDayFullName(aula.dia).toUpperCase(),
                                style: const TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            aula.modalidade.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(LucideIcons.user, size: 12, color: AppTheme.textGrey),
                              const SizedBox(width: 6),
                              Text(
                                'Prof. ${aula.professor}',
                                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status Badge e Botão Editar
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isAdmin)
                          PremiumClickable(
                            onTap: () => _showEditScheduleModal(context, aula, modMap),
                            borderRadius: 50,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: const Icon(LucideIcons.settings, size: 16, color: AppTheme.textWhite),
                            ),
                          ),
                        if (isAdmin && (isLive || isPast)) const SizedBox(height: 8),
                        if (isLive)
                          Pulse(
                            infinite: true,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.radio, size: 16, color: Colors.white),
                            ),
                          ),
                        if (isPast)
                          const Icon(LucideIcons.checkCircle, size: 24, color: Colors.white24),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // MODAL DE EDIÇÃO DE HORÁRIO (ADMIN CRUD)
  // ═══════════════════════════════════════════════════════
  void _showEditScheduleModal(BuildContext context, _AulaData aula, Map<String, String> modMap) {
    int editDay = aula.dia;
    String editInicio = aula.inicio;
    String editFim = aula.fim;
    String editProf = aula.professor;
    String editModId = aula.modalityId;

    bool isSaving = false;

    Future<TimeOfDay?> pickTimeSafely(BuildContext context, String currentStr) async {
      final parts = currentStr.split(':');
      TimeOfDay initialTime = TimeOfDay.now();
      if (parts.length == 2) {
        initialTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
      }
      return showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppTheme.accentGold,
                onPrimary: Colors.black,
                surface: AppTheme.cardDarkGrey,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim, secondAnim) {
        return StatefulBuilder(builder: (context, setStateModal) {
          void updateTimeField(bool isInicio) async {
            final picked = await pickTimeSafely(context, isInicio ? editInicio : editFim);
            if (picked != null) {
              final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              setStateModal(() {
                if (isInicio) editInicio = formatted;
                else editFim = formatted;
              });
            }
          }

          Future<void> saveChanges() async {
            setStateModal(() => isSaving = true);
            try {
              final firestore = FirebaseFirestore.instance;
              
              if (editModId == aula.modalityId) {
                // Mesma modalidade, apenas atualizar vetor
                final docRef = firestore.collection(FirebaseCollections.modalidades).doc(aula.modalityId);
                await docRef.update({
                  'gradeHorarios': FieldValue.arrayRemove([aula.originalData])
                });
                
                final updatedData = Map<String, dynamic>.from(aula.originalData);
                updatedData['dia'] = editDay;
                updatedData['inicio'] = editInicio;
                updatedData['fim'] = editFim;
                updatedData['horario'] = '$editInicio - $editFim'; // legado se existir
                updatedData['professor'] = editProf;
                
                await docRef.update({
                  'gradeHorarios': FieldValue.arrayUnion([updatedData])
                });
              } else {
                // Mudou a modalidade! Remover do antigo e inserir no novo
                final oldRef = firestore.collection(FirebaseCollections.modalidades).doc(aula.modalityId);
                await oldRef.update({
                  'gradeHorarios': FieldValue.arrayRemove([aula.originalData])
                });
                
                final newRef = firestore.collection(FirebaseCollections.modalidades).doc(editModId);
                final newData = {
                  'dia': editDay,
                  'inicio': editInicio,
                  'fim': editFim,
                  'horario': '$editInicio - $editFim',
                  'professor': editProf,
                };
                await newRef.update({
                  'gradeHorarios': FieldValue.arrayUnion([newData])
                });
              }

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reunião atualizada com sucesso!'), backgroundColor: Colors.green),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red),
                );
              }
            } finally {
              if (mounted) setStateModal(() => isSaving = false);
            }
          }

          Future<void> deleteAula() async {
            setStateModal(() => isSaving = true);
            try {
              final docRef = FirebaseFirestore.instance.collection(FirebaseCollections.modalidades).doc(aula.modalityId);
              await docRef.update({
                'gradeHorarios': FieldValue.arrayRemove([aula.originalData])
              });
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Aula removida.'), backgroundColor: Colors.redAccent),
                );
              }
            } catch (e) {
               // ignore
            } finally {
              if (mounted) setStateModal(() => isSaving = false);
            }
          }

          return SafeArea(
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: GlassContainer(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  blur: 20,
                  opacity: 0.6,
                  borderRadius: 20,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'EDITAR AULA',
                          style: TextStyle(color: AppTheme.accentGold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Dia
                        const Text('Dia da Semana', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.cardDarkGrey,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: editDay,
                              dropdownColor: AppTheme.cardDarkGrey,
                              isExpanded: true,
                              items: _dayValues.map((d) {
                                return DropdownMenuItem(value: d, child: Text(_getDayFullName(d)));
                              }).toList(),
                              onChanged: (v) => setStateModal(() => editDay = v!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Time Pickers
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Início', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => updateTimeField(true),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardDarkGrey,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppTheme.glassBorder),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(editInicio, style: const TextStyle(color: Colors.white, fontSize: 16)),
                                          const Icon(LucideIcons.clock, size: 16, color: AppTheme.textGrey),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Término', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => updateTimeField(false),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardDarkGrey,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppTheme.glassBorder),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(editFim, style: const TextStyle(color: Colors.white, fontSize: 16)),
                                          const Icon(LucideIcons.clock, size: 16, color: AppTheme.textGrey),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Modalidade
                        const Text('Modalidade', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                        const SizedBox(height: 8),
                        if (modMap.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.cardDarkGrey,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.glassBorder),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: modMap.containsKey(editModId) ? editModId : null,
                                dropdownColor: AppTheme.cardDarkGrey,
                                isExpanded: true,
                                hint: const Text('Selecione'),
                                items: modMap.entries.map((e) {
                                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setStateModal(() => editModId = v);
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Professor
                        const Text('Professor Responsável', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: editProf,
                          onChanged: (v) => editProf = v,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(LucideIcons.user, size: 18, color: AppTheme.textGrey),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Actions
                        if (isSaving)
                          const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton(
                                onPressed: saveChanges,
                                child: const Text('SALVAR ALTERAÇÕES'),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancelar', style: TextStyle(color: AppTheme.textGrey)),
                              ),
                              const SizedBox(height: 24),
                              TextButton.icon(
                                onPressed: () {
                                  showDialog(context: context, builder: (ctx) => AlertDialog(
                                    backgroundColor: AppTheme.cardDarkGrey,
                                    title: const Text('Excluir aula?'),
                                    content: const Text('Tem certeza que deseja remover esta aula da grade?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Voltar', style: TextStyle(color: AppTheme.textGrey))),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          deleteAula();
                                        }, 
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                        child: const Text('Sim, excluir'),
                                      )
                                    ],
                                  ));
                                },
                                icon: const Icon(LucideIcons.trash2, size: 16),
                                label: const Text('Excluir Aula da Grade'),
                                style: TextButton.styleFrom(foregroundColor: Colors.redAccent.withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
      transitionBuilder: (context, anim, secondAnim, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - anim.value)),
          child: Opacity(
            opacity: anim.value,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildGlobalGradeFallback(List<QueryDocumentSnapshot> allDocs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.calendarCheck, size: 64, color: AppTheme.accentGold),
          const SizedBox(height: 16),
          const Text('EXIBINDO GRADE GERAL DO CT PANDORA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Complete seu cadastro para ver as aulas ideais para você.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => setState(() => widget.filterModalities?.clear()),
            icon: const Icon(LucideIcons.eye, size: 18),
            label: const Text('MANTER GRADE COMPLETA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold.withValues(alpha: 0.1),
              foregroundColor: AppTheme.accentGold,
              side: const BorderSide(color: AppTheme.accentGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Row(
        children: [
          const Text('📅', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// DELEGATE PARA SLIVER PERSISTENT HEADER
// ═══════════════════════════════════════════════════════
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._child);
  final Widget _child;

  @override
  double get minExtent => 76.0;
  @override
  double get maxExtent => 76.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

// ═══════════════════════════════════════════════════════
// MODELO INTERNO
// ═══════════════════════════════════════════════════════

class _AulaData {
  final String modalityId;
  final String modalidade;
  final int dia;
  final String inicio;
  final String fim;
  final String backgroundUrl;
  final Map<String, dynamic> originalData;
  final String professor;

  _AulaData({
    required this.modalityId,
    required this.modalidade,
    required this.dia,
    required this.inicio,
    required this.fim,
    required this.backgroundUrl,
    required this.originalData,
    required this.professor,
  });
}
