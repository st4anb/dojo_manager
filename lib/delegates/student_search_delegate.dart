import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/constants/firebase_collections.dart';
import '../core/theme/app_theme.dart';
import '../widgets/student_edit_dialog.dart';

class StudentSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => 'Buscar nome do aluno...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.cardDarkGrey,
        iconTheme: IconThemeData(color: AppTheme.accentGold),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppTheme.textGrey),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppTheme.accentGold),
      scaffoldBackgroundColor: AppTheme.backgroundBlack,
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(LucideIcons.arrowLeft),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.search, size: 64, color: AppTheme.cardDarkGrey),
            SizedBox(height: 16),
            Text('Digite o nome de um aluno para buscar', style: TextStyle(color: AppTheme.textGrey)),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.alunos)
          .where('role', isEqualTo: 'aluno')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Erro na busca.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));

        final results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['nome']?.toString().toLowerCase() ?? '';
          final emergency = data['contato_emergencia']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) || emergency.contains(query.toLowerCase());
        }).toList();

        if (results.isEmpty) {
          return const Center(child: Text('Nenhum aluno encontrado.', style: TextStyle(color: AppTheme.textGrey)));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final doc = results[index];
            final data = doc.data() as Map<String, dynamic>;
            final emergency = data['contato_emergencia'] ?? '---';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.cardDarkGrey,
                backgroundImage: data['foto_url'] != null ? NetworkImage(data['foto_url']) : null,
                child: data['foto_url'] == null ? const Icon(LucideIcons.user, color: AppTheme.textGrey) : null,
              ),
              title: Text(data['nome'] ?? '...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Faixa: ${data['faixa'] ?? ""}\nEmergência: $emergency', 
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
              isThreeLine: true,
              trailing: const Icon(LucideIcons.chevronRight, color: AppTheme.accentGold, size: 16),
              onTap: () {
                close(context, null);
                showEditStudentDialog(context, doc);
              },
            );
          },
        );
      },
    );
  }
}
