import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_collections.dart';

class DataSeeder {
  static Future<void> seedOfficialSchedule() async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final List<Map<String, dynamic>> modalities = [
      {
        'nome': 'Boxe',
        'professor': 'Sensei Michael',
        'ativo': true,
        'gradeHorarios': [
          {'dia': 2, 'inicio': '08:30', 'fim': '10:00'},
          {'dia': 2, 'inicio': '19:30', 'fim': '21:00'},
          {'dia': 4, 'inicio': '08:30', 'fim': '10:00'},
          {'dia': 4, 'inicio': '19:30', 'fim': '21:00'},
        ],
      },
      {
        'nome': 'Circuito Funcional',
        'professor': 'Sensei Michael',
        'ativo': true,
        'gradeHorarios': [
          {'dia': 2, 'inicio': '07:30', 'fim': '08:30'},
          {'dia': 2, 'inicio': '17:00', 'fim': '18:00'},
          {'dia': 2, 'inicio': '19:00', 'fim': '20:00'},
          {'dia': 4, 'inicio': '07:30', 'fim': '08:30'},
          {'dia': 4, 'inicio': '17:00', 'fim': '18:00'},
          {'dia': 4, 'inicio': '19:00', 'fim': '20:00'},
        ],
      },
      {
        'nome': 'Kickboxing',
        'professor': 'Sensei Michael',
        'ativo': true,
        'gradeHorarios': [
          {'dia': 1, 'inicio': '16:00', 'fim': '17:00'},
          {'dia': 2, 'inicio': '08:30', 'fim': '10:00'},
          {'dia': 2, 'inicio': '17:00', 'fim': '18:30'},
          {'dia': 3, 'inicio': '16:00', 'fim': '17:00'},
          {'dia': 3, 'inicio': '21:00', 'fim': '22:30'},
          {'dia': 4, 'inicio': '08:30', 'fim': '10:00'},
          {'dia': 4, 'inicio': '17:00', 'fim': '18:30'},
          {'dia': 5, 'inicio': '21:00', 'fim': '22:30'},
        ],
      },
      {
        'nome': 'Judô',
        'professor': 'Sensei Michael',
        'ativo': true,
        'gradeHorarios': [
          {'dia': 6, 'inicio': '08:00', 'fim': '09:30'},
        ],
      },
      {
        'nome': 'Muay Thai',
        'professor': 'Sensei Michael',
        'ativo': true,
        'gradeHorarios': [
          {'dia': 1, 'inicio': '18:00', 'fim': '19:20'},
          {'dia': 3, 'inicio': '18:00', 'fim': '19:20'},
          {'dia': 2, 'inicio': '08:30', 'fim': '10:00'},
          {'dia': 4, 'inicio': '08:30', 'fim': '10:00'},
        ],
      },
      {
        'nome': 'Karatê Kyokushin',
        'professor': 'Sensei Michael',
        'ativo': true,
        'gradeHorarios': [
          {'dia': 1, 'inicio': '15:30', 'fim': '16:30'},
          {'dia': 2, 'inicio': '08:30', 'fim': '10:00'},
          {'dia': 3, 'inicio': '15:30', 'fim': '16:30'},
          {'dia': 3, 'inicio': '19:30', 'fim': '20:30'},
          {'dia': 4, 'inicio': '08:30', 'fim': '10:00'},
          {'dia': 5, 'inicio': '15:30', 'fim': '16:30'},
          {'dia': 5, 'inicio': '19:30', 'fim': '20:30'},
        ],
      },
      {
        'nome': 'Jiu-Jitsu',
        'professor': 'Sensei Michael',
        'ativo': true,
        'gradeHorarios': [
          {'dia': 2, 'inicio': '09:00', 'fim': '10:30'},
          {'dia': 2, 'inicio': '19:00', 'fim': '20:30'},
          {'dia': 3, 'inicio': '09:00', 'fim': '10:30'},
          {'dia': 3, 'inicio': '19:00', 'fim': '20:30'},
          {'dia': 5, 'inicio': '18:00', 'fim': '19:00'},
          {'dia': 6, 'inicio': '07:30', 'fim': '09:00'},
        ],
      },
      {
        'nome': 'Jiu-Jitsu Kids',
        'professor': 'Sensei Michael',
        'ativo': true,
        'gradeHorarios': [
          {'dia': 2, 'inicio': '17:00', 'fim': '19:00'},
          {'dia': 4, 'inicio': '17:00', 'fim': '19:00'},
        ],
      },
      {
        'nome': 'MMA',
        'professor': 'Sensei Michael',
        'ativo': true,
        'gradeHorarios': [
          {'dia': 6, 'inicio': '07:00', 'fim': '09:00'},
        ],
      },
    ];

    for (var mod in modalities) {
      // Busca se já existe uma modalidade com esse nome para atualizar
      final query = await firestore
          .collection(FirebaseCollections.modalidades)
          .where('nome', isEqualTo: mod['nome'])
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        batch.update(query.docs.first.reference, mod);
      } else {
        final newDoc = firestore.collection(FirebaseCollections.modalidades).doc();
        batch.set(newDoc, {
          ...mod,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }
}
