import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post_model.dart';
import '../../../core/constants/firebase_collections.dart';
import '../../../core/services/image_upload_service.dart';

class SocialService {
  final _db = FirebaseFirestore.instance;

  // PAGINAÇÃO
  Future<List<QueryDocumentSnapshot>> getPostsPaginated({DocumentSnapshot? startAfter, int limit = 10}) async {
    Query query = _db.collection(FirebaseCollections.posts)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs;
  }

  // OSS (LIKE) COM CHECK DE SUBCOLEÇÃO
  Future<void> toggleOss(String postId, String userId) async {
    final interactionRef = _db.collection(FirebaseCollections.posts)
        .doc(postId)
        .collection('interacoes')
        .doc(userId);

    final doc = await interactionRef.get();
    
    if (doc.exists) {
      await interactionRef.delete();
      await _db.collection(FirebaseCollections.posts).doc(postId).update({
        'ossCount': FieldValue.increment(-1),
      });
    } else {
      await interactionRef.set({'createdAt': FieldValue.serverTimestamp()});
      await _db.collection(FirebaseCollections.posts).doc(postId).update({
        'ossCount': FieldValue.increment(1),
      });
    }
  }

  // COMENTÁRIOS
  Future<void> addComment(String postId, CommentModel comment) async {
    await _db.collection(FirebaseCollections.posts)
        .doc(postId)
        .collection('comments')
        .add(comment.toMap());
    
    await _db.collection(FirebaseCollections.posts).doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  Stream<QuerySnapshot> getCommentsStream(String postId) {
    return _db.collection(FirebaseCollections.posts)
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _db.collection(FirebaseCollections.posts)
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
    
    await _db.collection(FirebaseCollections.posts)
        .doc(postId)
        .update({
          'commentCount': FieldValue.increment(-1),
        });
  }

  // UPLOAD E COMPRESSÃO
  Future<String> uploadPostImage(XFile imageFile, String userId) async {
    final uploadUrl = await ImageUploadService.uploadImage(imageFile);
    if (uploadUrl == null) {
      throw Exception('Erro ao hospedar imagem no ImgBB.');
    }
    return uploadUrl;
  }

  Future<void> savePost(PostModel post) async {
    await _db.collection(FirebaseCollections.posts).doc(post.id).set(post.toMap());
  }
}
