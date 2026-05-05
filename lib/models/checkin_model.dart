import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInModel {
  final String id;
  final String alunoId;
  final String alunoNome;
  final DateTime dataHora;
  final String modalidade;

  CheckInModel({
    required this.id,
    required this.alunoId,
    required this.alunoNome,
    required this.dataHora,
    required this.modalidade,
  });

  factory CheckInModel.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return CheckInModel(
        id: id,
        alunoId: '',
        alunoNome: 'N/A',
        dataHora: DateTime.now(),
        modalidade: 'Geral',
      );
    }

    // [CORREÇÃO CRÍTICA] Tratamento resiliente de múltiplos campos de data
    DateTime parsedDate = DateTime.now();
    try {
      final ts = (data['dataHora'] ?? data['created_at'] ?? data['data_hora']) as Timestamp?;
      if (ts != null) {
        parsedDate = ts.toDate();
      } else {
        // Tenta buscar como string se não for Timestamp
        final str = data['dataHora']?.toString() ?? data['created_at']?.toString() ?? data['data_hora']?.toString();
        if (str != null) {
          final dt = DateTime.tryParse(str);
          if (dt != null) parsedDate = dt;
        }
      }
    } catch (_) {
      // Fallback seguro
    }

    return CheckInModel(
      id: id,
      alunoId: data['aluno_id']?.toString() ?? data['uid']?.toString() ?? '',
      alunoNome: data['aluno_nome']?.toString() ?? 'Aluno',
      dataHora: parsedDate,
      modalidade: data['modalidade']?.toString() ?? 'Geral',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'aluno_id': alunoId,
      'aluno_nome': alunoNome,
      'dataHora': Timestamp.fromDate(dataHora),
      'modalidade': modalidade,
    };
  }
}
