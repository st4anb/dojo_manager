import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';

class StatusTreinoCard extends StatefulWidget {
  final List<String> studentModalities;
  const StatusTreinoCard({super.key, this.studentModalities = const []});

  @override
  State<StatusTreinoCard> createState() => _StatusTreinoCardState();
}

class _StatusTreinoCardState extends State<StatusTreinoCard> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  // Chave estável para evitar re-animação em rebuilds do StreamBuilder
  String _lastCardType = '';
  late Stream<QuerySnapshot> _modalitiesStream;

  @override
  void initState() {
    super.initState();
    _modalitiesStream = FirebaseFirestore.instance.collection(FirebaseCollections.modalidades).snapshots();
    // Atualiza a cada 30 segundos para manter o countdown vivo
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int weekday = _now.weekday; // 1=Monday, 7=Sunday
    final String currentTime = DateFormat('HH:mm').format(_now);

    return StreamBuilder<QuerySnapshot>(
      stream: _modalitiesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final modalities = snapshot.data!.docs;
        if (modalities.isEmpty) return const SizedBox.shrink();

        Map<String, dynamic>? activeClass;
        Map<String, dynamic>? nextClass;
        String? activeBg;
        String? nextBg;
        String? activeName;
        String? nextName;

        for (var doc in modalities) {
          final data = doc.data() as Map<String, dynamic>;
          final String name = data['nome'] ?? '';
          
          // FILTRO POR MODALIDADE DO ALUNO (Chave Primária) ⚡
          if (widget.studentModalities.isNotEmpty && !widget.studentModalities.contains(name)) {
            continue;
          }

          final schedules = data['horarios'] as List? ?? [];
          
          for (var s in schedules) {
            if (s['dia'] == weekday) {
              final String start = s['inicio'];
              final String end = s['fim'];

              if (currentTime.compareTo(start) >= 0 && currentTime.compareTo(end) < 0) {
                activeClass = s;
                activeBg = data['background_url'];
                activeName = name;
              } else if (currentTime.compareTo(start) < 0) {
                if (nextClass == null || start.compareTo(nextClass['inicio']) < 0) {
                  nextClass = s;
                  nextBg = data['background_url'];
                  nextName = name;
                }
              }
            }
          }
        }

        if (activeClass != null) {
          final cardType = 'live_$activeName';
          final shouldAnimate = _lastCardType != cardType;
          _lastCardType = cardType;
          return _buildLiveCard(
            modality: activeName!,
            startTime: activeClass['inicio'],
            endTime: activeClass['fim'],
            bgUrl: activeBg,
            animate: shouldAnimate,
          );
        }

        if (nextClass != null) {
          final startTime = nextClass['inicio'];
          final parts = startTime.split(':');
          final nextDt = DateTime(_now.year, _now.month, _now.day, int.parse(parts[0]), int.parse(parts[1]));
          final diff = nextDt.difference(_now).inMinutes;

          final cardType = 'next_$nextName';
          final shouldAnimate = _lastCardType != cardType;
          _lastCardType = cardType;
          return _buildNextCard(
            modality: nextName!,
            startTime: startTime,
            endTime: nextClass['fim'],
            minutesUntil: diff,
            bgUrl: nextBg,
            animate: shouldAnimate,
          );
        }

        // Dia sem aulas para o perfil do aluno
        final cardType = 'rest';
        final shouldAnimate = _lastCardType != cardType;
        _lastCardType = cardType;
        return _buildRestDayCard(hasFiltered: widget.studentModalities.isNotEmpty, animate: shouldAnimate);
      },
    );
  }

  /// Card AO VIVO — classe acontecendo agora
  Widget _buildLiveCard({
    required String modality,
    required String startTime,
    required String endTime,
    String? bgUrl,
    bool animate = false,
  }) {
    final card = Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: bgUrl != null && bgUrl.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(bgUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.65), BlendMode.darken),
              )
            : null,
        color: bgUrl == null || bgUrl.isEmpty ? AppTheme.cardDarkGrey : null,
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              bottom: -20,
              right: -20,
              child: Icon(
                LucideIcons.flame,
                size: 120,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Pulse(
                    infinite: true,
                    duration: const Duration(seconds: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.radio, size: 12, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'ACONTECENDO AGORA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    modality.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Georgia',
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 14, color: AppTheme.accentGold),
                      const SizedBox(width: 6),
                      Text(
                        '$startTime — $endTime',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 16,
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
    );

    if (animate) {
      return FadeInDown(duration: const Duration(milliseconds: 600), child: card);
    }
    return card;
  }

  /// Card PRÓXIMA AULA — com countdown
  Widget _buildNextCard({
    required String modality,
    required String startTime,
    required String endTime,
    required int minutesUntil,
    String? bgUrl,
    bool animate = false,
  }) {
    final String countdownText;
    if (minutesUntil > 60) {
      final h = minutesUntil ~/ 60;
      final m = minutesUntil % 60;
      countdownText = 'Começa em ${h}h ${m > 0 ? '${m}min' : ''}';
    } else {
      countdownText = 'Começa em $minutesUntil minutos';
    }

    final card = Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: bgUrl != null && bgUrl.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(bgUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.65), BlendMode.darken),
              )
            : null,
        color: bgUrl == null || bgUrl.isEmpty ? AppTheme.cardDarkGrey : null,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGold.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              bottom: -20,
              right: -20,
              child: Icon(
                LucideIcons.calendar,
                size: 120,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.timer, size: 12, color: AppTheme.accentGold),
                        SizedBox(width: 6),
                        Text(
                          'PRÓXIMO TREINO',
                          style: TextStyle(
                            color: AppTheme.accentGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    modality.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Georgia',
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 14, color: AppTheme.accentGold),
                      const SizedBox(width: 6),
                      Text(
                        '$startTime — $endTime',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FadeIn(
                    child: Text(
                      countdownText,
                      style: const TextStyle(
                        color: AppTheme.accentGold,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (animate) {
      return FadeInDown(duration: const Duration(milliseconds: 600), child: card);
    }
    return card;
  }

  /// Card dia de descanso
  Widget _buildRestDayCard({bool hasFiltered = false, bool animate = false}) {
    final card = Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardDarkGrey,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.moonStar, size: 24, color: AppTheme.textGrey),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIA DE DESCANSO',
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  hasFiltered 
                    ? 'Nenhuma aula das suas modalidades hoje. Recupere-se!'
                    : 'Nenhuma aula programada para hoje. Recupere-se!',
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (animate) {
      return FadeInDown(duration: const Duration(milliseconds: 400), child: card);
    }
    return card;
  }
}
