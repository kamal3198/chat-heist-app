import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserSearchRepository {
  final FirebaseFirestore _firestore;

  UserSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> streamUsersByPrefix(String input) {
    final search = input.toLowerCase().trim();
    debugPrint('[UserSearch] normalized search="$search"');

    if (search.length < 2) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }

    return _firestore
        .collection('users_public')
        .orderBy('username_search')
        .startAt(<String>[search])
        .endAt(<String>['$search\uf8ff'])
        .limit(20)
        .snapshots()
        .map((snapshot) {
      debugPrint('[UserSearch] snapshot.size=${snapshot.size}');
      final ids = snapshot.docs.map((doc) => doc.id).toList(growable: false);
      debugPrint('[UserSearch] docIds=$ids');

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'uid': data['uid'] ?? doc.id,
          'username': data['username'] ?? '',
          'displayName': data['displayName'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
        };
      }).toList(growable: false);
    }).handleError((error, stackTrace) {
      debugPrint('[UserSearch] error=$error');
      debugPrint('[UserSearch] stack=$stackTrace');
    });
  }
}

