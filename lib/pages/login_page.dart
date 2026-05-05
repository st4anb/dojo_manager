import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  int _wrongAttempts = 0;
  bool _isLoading = false;
  bool _isSendingReset = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _wrongAttempts = 0; // Reset
      
      // Forçar redirecionamento manual pós-login para evitar "congelamento"
      if (mounted) {
        // Buscamos o papel (role) rapidamente para decidir o destino
        final doc = await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(cred.user!.uid).get();
        if (!mounted) return;
        if (doc.exists) {
          final role = doc.data()?['role'] ?? 'aluno';
          if (role == 'admin') {
            if (context.mounted) context.go('/admin');
          } else {
            // Se aluno, verifica anamnese para decidir rota
            final anamneseOk = doc.data()?['is_anamnese_completed'] ?? false;
            if (context.mounted) context.go(anamneseOk ? '/student' : '/anamnese');
          }
        } else {
          // Fallback se perfil ainda não existir (raro em login)
          if (context.mounted) context.go('/student');
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro ao fazer login.';
      if (e.code == 'wrong-password' || e.code == 'user-not-found') {
        setState(() => _wrongAttempts++);
        message = 'Login inválido. Verifique seus dados.';
      } else if (e.code == 'invalid-email') {
        message = 'E-mail inválido.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final provider = GoogleAuthProvider();
      final cred = await FirebaseAuth.instance.signInWithPopup(provider);

      if (mounted) {
        final doc = await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(cred.user!.uid).get();
        if (!mounted) return;

        if (doc.exists) {
          // ═══ V16 FORCE-SYNC: INJEÇÃO INCONDICIONAL ═══
          // SEMPRE injeta nome/email/foto do Google no Firestore
          // Usa update() com DOT NOTATION para NUNCA destruir telefone, nascimento, etc.
          await FirebaseFirestore.instance
              .collection(FirebaseCollections.alunos)
              .doc(cred.user!.uid)
              .update({
                'dados_pessoais.nome': cred.user!.displayName ?? '',
                'dados_pessoais.email': cred.user!.email ?? '',
                'dados_pessoais.foto_url': cred.user!.photoURL ?? '',
                'nome': cred.user!.displayName ?? '',
                'foto_url': cred.user!.photoURL ?? '',
                'last_login_sync': FieldValue.serverTimestamp(),
              });
          
          debugPrint('🔄 FORCE-SYNC: ${cred.user!.displayName} sincronizado no login');

          final existingData = doc.data()!;
          final role = existingData['role'] ?? 'aluno';
          if (role == 'admin') {
            context.go('/admin');
          } else {
            final anamneseOk = existingData['is_anamnese_completed'] ?? false;
            final statusAcesso = existingData['status_acesso'] ?? 'ativo';
            
            if (statusAcesso == 'pendente' || statusAcesso == 'bloqueado') {
              context.go('/pending');
            } else {
              context.go(anamneseOk ? '/student' : '/anamnese');
            }
          }
        } else {
          // Documento não existe -> Cria imediatamente e manda pro aguarde
          final novoAluno = {
            'uid': cred.user!.uid,
            'role': 'aluno',
            'status': 'pendente',
            'status_acesso': 'pendente',
            'created_at': FieldValue.serverTimestamp(),
            'nome': cred.user!.displayName ?? 'Usuário Google',
            'foto_url': cred.user!.photoURL ?? '',
            'dados_pessoais': {
              'nome': cred.user!.displayName ?? 'Usuário Google',
              'email': cred.user!.email ?? '',
            },
            'financeiro': {
              'statusPagamento': 'pendente',
            }
          };
          await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(cred.user!.uid).set(novoAluno);
          
          if (mounted) setState(() => _isLoading = false);
          context.go('/pending');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no login com Google: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha o campo de e-mail para recuperar sua senha.')),
      );
      return;
    }

    setState(() => _isSendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link de recuperação enviado! Verifique sua caixa de entrada e a pasta de spam.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Erro ao enviar e-mail de recuperação.';
      if (e.code == 'user-not-found') {
        message = 'Este e-mail não foi encontrado em nossa base.';
      } else if (e.code == 'invalid-email') {
        message = 'O formato do e-mail é inválido.';
      } else if (e.code == 'too-many-requests') {
        message = 'Muitas tentativas. Tente novamente mais tarde.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50.0),
              borderSide: const BorderSide(color: AppTheme.accentGold, width: 3),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_ct_pandora.png',
                height: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'C.T. PANDORA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 48),

              _buildTextField('email/telefone:', '@gmail.com', _emailController),
              const SizedBox(height: 24),
              _buildTextField('senha:', '••••••••', _passwordController, isPassword: true),
              
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0),
                    ),
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('ENTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: _isSendingReset ? null : _handlePasswordReset,
                child: _isSendingReset 
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGold))
                  : const Text(
                      'ESQUECI MINHA SENHA',
                      style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OU', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1)),
                ],
              ),
              
              const SizedBox(height: 32),

              // Botão de Login com Google
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0),
                    ),
                  ),
                  icon: Icon(LucideIcons.chrome, color: Colors.white, size: 20),
                  label: const Text(
                    'CONTINUAR COM GOOGLE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OU', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1)),
                ],
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => context.go('/register'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0),
                    ),
                  ),
                  icon: const Icon(LucideIcons.userPlus, color: AppTheme.accentGold, size: 20),
                  label: const Text(
                    'CRIAR CONTA MANUALMENTE',
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
