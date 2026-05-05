import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String alunoId;
  final String alunoNome;
  final String texto;
  final DateTime createdAt;
  final String? respostaAdmin;

  CommentModel({
    required this.id,
    required this.alunoId,
    required this.alunoNome,
    required this.texto,
    required this.createdAt,
    this.respostaAdmin,
  });

  factory CommentModel.fromMap(String id, Map<String, dynamic> data) {
    // [CORREÇÃO EMERGÊNCIA] Blindagem de data para evitar travamento na Visão do Aluno
    DateTime? parsedDate;
    try {
      if (data['createdAt'] is Timestamp) {
        parsedDate = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        parsedDate = DateTime.tryParse(data['createdAt']);
      }
    } catch (_) {
      parsedDate = null;
    }

    return CommentModel(
      id: id,
      alunoId: data['alunoId']?.toString() ?? '',
      alunoNome: data['alunoNome']?.toString() ?? 'Aluno',
      texto: data['texto']?.toString() ?? '',
      createdAt: parsedDate ?? DateTime.now(),
      respostaAdmin: data['respostaAdmin']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alunoId': alunoId,
      'alunoNome': alunoNome,
      'texto': texto,
      'createdAt': createdAt,
      'respostaAdmin': respostaAdmin,
    };
  }
}
