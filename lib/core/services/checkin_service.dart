import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/checkin_model.dart';

class CheckInService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registra a presença do aluno com validação de duplicidade por dia.
  Future<void> registrarCheckIn({
    required BuildContext context,
    required String alunoId,
    required String alunoNome,
    required String modalidade,
  }) async {
    try {
      // 1. Definir o range de "Hoje" (00:00:00 até 23:59:59)
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // 2. Consulta de Duplicidade
      final querySnapshot = await _firestore
          .collection('FREQUENCIA')
          .where('aluno_id', isEqualTo: alunoId)
          .where('dataHora', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dataHora', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1) // Só precisamos saber se existe um
          .get();

      // 3. Validação: Se o aluno já fez check-in hoje, abortamos.
      if (querySnapshot.docs.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🥋 Você já confirmou sua presença hoje! Bom treino.'),
              backgroundColor: Colors.blueAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // 4. Criação do Documento
      final novoCheckIn = CheckInModel(
        id: '', // Firestore gera o ID
        alunoId: alunoId,
        alunoNome: alunoNome,
        dataHora: now,
        modalidade: modalidade,
      );

      // 5. Salvamento no Firestore
      await _firestore.collection('FREQUENCIA').add(novoCheckIn.toMap());

      // 6. Feedback de Sucesso
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Presença confirmada! Bom treino, Guerreiro!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao registrar presença: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
