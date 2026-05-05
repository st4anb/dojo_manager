import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../pages/login_page.dart';
import '../../pages/register_page.dart';
import '../../pages/pending_approval_page.dart';
import '../../pages/student_home_page.dart';
import '../../pages/checkin_page.dart';
import '../../pages/admin_dashboard_page.dart';
import '../../providers/auth_provider.dart';
import '../../test_home.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfileState = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const RegisterPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/checkin',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const CheckinPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/student',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const StudentHomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const AdminDashboardPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/pending',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const PendingApprovalPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
    ],
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      if (!isAuth) {
        return (isLoggingIn || isRegistering) ? null : '/login';
      }

      if (userProfileState.isLoading) return null;

      final profile = userProfileState.value;
      if (profile == null) {
        // Usuário autenticado mas sem perfil (ex: Login novo do Google incompleto)
        return isRegistering ? null : '/register';
      }
      
      final role = profile.role;
      final statusAcesso = profile.statusAcesso;

      // Guard de acesso: aluno pendente ou bloqueado vai para /pending
      if (role == 'aluno' &&
          (statusAcesso == 'pendente' || statusAcesso == 'bloqueado') &&
          state.matchedLocation != '/pending') {
        return '/pending';
      }

      // Home / Redirecionamento Final
      if (isLoggingIn || isRegistering || state.matchedLocation == '/') {
        if (role == 'admin') {
          return '/admin';
        } else if (role == 'aluno') {
          return '/student';
        }
      }

      return null;
    },
  );
});
