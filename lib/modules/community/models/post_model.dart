import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { aluno, destaque, campeonato, graduacao, trajetoria }

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String imageUrl;
  final String text;
  final PostType type;
  final DateTime createdAt;
  final int ossCount;
  final int commentCount;

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.imageUrl,
    required this.text,
    required this.type,
    required this.createdAt,
    this.ossCount = 0,
    this.commentCount = 0,
  });

  factory PostModel.fromMap(String id, Map<String, dynamic> data) {
    return PostModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Desconhecido',
      userPhoto: data['userPhoto'],
      imageUrl: data['imageUrl'] ?? '',
      text: data['text'] ?? '',
      type: _parseType(data['type']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ossCount: data['ossCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'imageUrl': imageUrl,
      'text': text,
      'type': type.name,
      'createdAt': FieldValue.serverTimestamp(),
      'ossCount': ossCount,
      'commentCount': commentCount,
    };
  }

  static PostType _parseType(String? typeStr) {
    return PostType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => PostType.aluno,
    );
  }
}

class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String text;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.text,
    required this.createdAt,
  });

  factory CommentModel.fromMap(String id, Map<String, dynamic> data) {
    return CommentModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Desconhecido',
      userPhoto: data['userPhoto'],
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
