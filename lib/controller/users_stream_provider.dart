import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentUserProvider = Provider<User?>((ref) {
return FirebaseAuth.instance.currentUser;
});

final usersStreamProvider = StreamProvider<QuerySnapshot>((ref) {
return FirebaseFirestore.instance
    .collection('start')
    .orderBy('createdAt', descending: true)
    .snapshots();
});
