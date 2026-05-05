import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_collections.dart';

class AdminService {
  /// Promove um aluno a Admin, isenta mensalidades e limpa cobranças pendentes.
  static Future<void> promoteStudentToAdmin(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 1. Referência do documento do Aluno
    final alunoRef = firestore.collection(FirebaseCollections.alunos).doc(uid);

    // 2. Query para cobranças pendentes do aluno na coleção global PAGAMENTOS
    // Nota: Usamos 'aluno_id' conforme padrão observado no FinancialListView
    final pagamentosPendentes = await firestore
        .collection(FirebaseCollections.pagamentos)
        .where('aluno_id', isEqualTo: uid)
        .where('status', isEqualTo: 'Pendente')
        .get();

    // ─── OPERAÇÕES NO BATCH (Atômico) ───

    // Atualiza o Perfil: Role para admin e isenção financeira imediata
    // Usamos dot notation para não sobrescrever o mapa 'financeiro' inteiro
    batch.update(alunoRef, {
      'role': 'admin',
      'financeiro.statusPagamento': 'isento',
      'financeiro.status': 'isento', // Atualiza ambos para maior compatibilidade
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Deleta os documentos de cobrança pendente para evitar cobranças indevidas
    for (var doc in pagamentosPendentes.docs) {
      batch.delete(doc.reference);
    }

    // Executa o commit
    await batch.commit();
  }
}
