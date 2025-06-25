import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


final currentUserProvider = Provider<User?>((ref) {
  return FirebaseAuth.instance.currentUser;
});


final usersStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final currentUser = FirebaseAuth.instance.currentUser;
  return FirebaseFirestore.instance
      .collection('start')
      .where('email', isNotEqualTo: currentUser?.email)
      .snapshots();
});
