import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';

class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key});

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  static const double dojoLat = -23.4040862;
  static const double dojoLng = -46.5391125;
  static const double maxCheckinDistanceMeters = 150.0;

  bool _isCheckingLoc = false;

  Future<void> _handleCheckIn() async {
    setState(() => _isCheckingLoc = true);

    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'GPS Desativado.';

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permissão Negada.';
      }
      if (permission == LocationPermission.deniedForever) throw 'Permissão bloqueada.';

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );

      final distance = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        dojoLat, dojoLng,
      );

      if (!mounted) return;

      if (distance <= maxCheckinDistanceMeters) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // ---- GATEKEEPER FINANCEIRO ----
          // 1. Busca os dados do aluno para verificar se usa convênio (Wellhub/TotalPass)
          bool usaConvenio = false;
          String nomeAluno = 'Aluno Desconhecido';
          try {
             final alunoDoc = await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(user.uid).get();
             if (alunoDoc.exists) {
               nomeAluno = alunoDoc.data()?['nome'] ?? 'Aluno';
               usaConvenio = alunoDoc.data()?['usa_beneficio'] == true;
             }
          } catch (_) {}

          // 2. Se não usar convênio, faz a verificação financeira padrão
          if (!usaConvenio) {
            final matDoc = await FirebaseFirestore.instance.collection(FirebaseCollections.matriculas).doc(user.uid).get();
            if (matDoc.exists) {
              final matData = matDoc.data()!;
              final status = matData['status_pagamento'] as String? ?? 'Pendente';
              final vencimentoTs = matData['vencimento'] as Timestamp?;
              final now = DateTime.now();
              final hoje = DateTime(now.year, now.month, now.day);
              bool isVencido = false;
              
              if (vencimentoTs != null) {
                final vencDt = vencimentoTs.toDate();
                final vencimentoMidnight = DateTime(vencDt.year, vencDt.month, vencDt.day);
                if (hoje.isAfter(vencimentoMidnight)) isVencido = true;
              }

              if (status == 'Pendente' || isVencido) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Colors.red, content: Text('Acesso Negado: Mensalidade Pendente. Regularize sua matrícula no setor financeiro do app.'), duration: Duration(seconds: 4))
                );
                return; // BLOQUEIO ATIVADO
              }
            }
          }

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

          // Cria a requisição na Fila (Padronizado)
          await FirebaseFirestore.instance.collection(FirebaseCollections.frequencia).doc().set({
            'aluno_id': user.uid,
            'aluno_nome': nomeAluno,
            'status': 'solicitado',
            'dataHora': FieldValue.serverTimestamp(),
          });
        }

        if (!mounted) return;

        // Sucesso
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(backgroundColor: Colors.green.shade800, content: Text('Sua solicitação foi enviada ao Sensei! (${distance.toStringAsFixed(0)}m)')),
        );
        // Só manda para a home agora que tá na fila!
        context.go('/student');
      } else {
        // ---- LOG DE FALHA DE GPS (Para o Dashboard Admin) ----
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          String nomeAluno = 'Aluno Desconhecido';
          try {
             final alunoDoc = await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(user.uid).get();
             if (alunoDoc.exists) nomeAluno = alunoDoc.data()?['nome'] ?? 'Aluno';
          } catch (_) {}

          await FirebaseFirestore.instance.collection(FirebaseCollections.frequencia).add({
            'uid': user.uid,
            'nome': nomeAluno,
            'status': 'recusado',
            'status_detalhe': 'Falha de GPS: Distância ${distance.toStringAsFixed(0)}m',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(backgroundColor: Colors.redAccent, content: Text('Fora da área do C.T.! Distância: ${distance.toStringAsFixed(0)}m')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingLoc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(LucideIcons.mapPin, size: 64, color: AppTheme.accentGold),
              const SizedBox(height: 24),
              const Text(
                'Hora do Treino?',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirme sua presença pelo GPS se estiver nas dependências do Dojo.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _isCheckingLoc ? null : _handleCheckIn,
                  icon: _isCheckingLoc 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black))
                      : const Icon(LucideIcons.checkCircle),
                  label: Text(_isCheckingLoc ? 'VERIFICANDO LOCAL...' : 'FAZER CHECK-IN AGORA'),
                  style: ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 32),

              TextButton(
                onPressed: () => context.go('/student'),
                child: const Text('PULAR E IR PARA O PAINEL', style: TextStyle(color: AppTheme.textGrey, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
