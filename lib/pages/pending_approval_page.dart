import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_container.dart';

/// Tela exibida para alunos com status_acesso == 'pendente' ou 'bloqueado'.
///
/// - Pendente: aguardando aprovação do admin
/// - Bloqueado: acesso negado/revogado
///
/// Reativas: qualquer mudança no Firestore (aprovação do admin) redireciona
/// automaticamente via o guard no app_routes.dart.
class PendingApprovalPage extends ConsumerWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    final isBloqueado = profile?.statusAcesso == 'bloqueado';

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      body: Stack(
        children: [
          // Background ambient glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isBloqueado ? Colors.redAccent : AppTheme.accentGold)
                        .withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Icon
                    FadeInDown(
                      duration: const Duration(milliseconds: 700),
                      child: _AnimatedStatusIcon(isBloqueado: isBloqueado),
                    ),

                    const SizedBox(height: 40),

                    // Glass Card
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 200),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(32),
                        borderRadius: 24,
                        border: Border.all(
                          color: isBloqueado
                              ? Colors.redAccent.withValues(alpha: 0.3)
                              : AppTheme.accentGold.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isBloqueado
                                    ? Colors.redAccent
                                    : AppTheme.accentGold)
                                .withValues(alpha: 0.1),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                        ],
                        child: Column(
                          children: [
                            // Title
                            Text(
                              isBloqueado
                                  ? 'ACESSO NÃO AUTORIZADO'
                                  : 'CADASTRO ENVIADO!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isBloqueado
                                    ? Colors.redAccent
                                    : AppTheme.accentGold,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: (isBloqueado
                                            ? Colors.redAccent
                                            : AppTheme.accentGold)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Subtitle
                            Text(
                              isBloqueado
                                  ? 'Seu acesso foi negado ou revogado pelo instrutor.\n\nFale com a recepção do CT Pandora para regularizar sua situação.'
                                  : 'Seu cadastro foi recebido com sucesso.\n\nAguarde a ativação pelo seu instrutor. Você receberá uma notificação assim que o acesso for liberado.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: (isBloqueado
                                        ? Colors.redAccent
                                        : Colors.amber)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: (isBloqueado
                                          ? Colors.redAccent
                                          : Colors.amber)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isBloqueado
                                        ? LucideIcons.shieldOff
                                        : LucideIcons.clock,
                                    size: 14,
                                    color: isBloqueado
                                        ? Colors.redAccent
                                        : Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isBloqueado ? 'ACESSO BLOQUEADO' : 'EM ANÁLISE',
                                    style: TextStyle(
                                      color: isBloqueado
                                          ? Colors.redAccent
                                          : Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Logout Button (Red Glass)
                    FadeIn(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 500),
                      child: PremiumClickable(
                        onTap: () => FirebaseAuth.instance.signOut(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC3545).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  const Color(0xFFDC3545).withValues(alpha: 0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC3545)
                                    .withValues(alpha: 0.1),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.logOut,
                                      color: Color(0xFFFF4D5E), size: 18),
                                  SizedBox(width: 10),
                                  Text(
                                    'SAIR',
                                    style: TextStyle(
                                      color: Color(0xFFFF4D5E),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (!isBloqueado)
                      FadeIn(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 700),
                        child: const Text(
                          'Esta tela atualizará automaticamente quando seu acesso for liberado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícone animado com pulsing glow — ampulheta para pendente, escudo-off para bloqueado.
class _AnimatedStatusIcon extends StatefulWidget {
  final bool isBloqueado;
  const _AnimatedStatusIcon({required this.isBloqueado});

  @override
  State<_AnimatedStatusIcon> createState() => _AnimatedStatusIconState();
}

class _AnimatedStatusIconState extends State<_AnimatedStatusIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isBloqueado ? Colors.redAccent : AppTheme.accentGold;
    final icon = widget.isBloqueado ? LucideIcons.shieldOff : LucideIcons.shieldCheck;

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.08),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _glow.value),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: color, size: 52),
        );
      },
    );
  }
}
