import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

// Firebase Auth provider
final authProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// Firestore provider
final fireStoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Auth StateNotifier provider
final authStateProvider =
StateNotifierProvider<AuthStateNotifier, AsyncValue<User?>>((ref) {
  return AuthStateNotifier(ref);
});

class AuthStateNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;

  AuthStateNotifier(this.ref) : super(const AsyncValue.loading()) {
    _checkLoggedInUser();
  }

  Future<void> _checkLoggedInUser() async {
    final user = ref.read(authProvider).currentUser;
    if (user != null) {
      await _updatePushIds(user);
    }
    state = AsyncValue.data(user);
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final userCredential = await ref
          .read(authProvider)
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;

      if (user != null) {
        await Future.delayed(const Duration(seconds: 2));

        final pushSub = OneSignal.User.pushSubscription;
        final oneSignalId = pushSub.id;
        final isSubscribed = pushSub.optedIn ?? false;
        final fcmToken = await FirebaseMessaging.instance.getToken();

        print("📲 OneSignal ID: $oneSignalId");
        print("🔔 Opted In: $isSubscribed");
        print("📩 FCM Token: $fcmToken");

        await ref.read(fireStoreProvider).collection('start').doc(user.uid).set({
          'name': name,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'oneSignalId': (isSubscribed && oneSignalId != null) ? oneSignalId : '',
          'fcmToken': fcmToken ?? '',
        });
      }

      state = AsyncValue.data(user);
    } on FirebaseAuthException catch (e, st) {
      state = AsyncValue.error(e.message ?? "Registration failed", st);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final userCredential = await ref
          .read(authProvider)
          .signInWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;

      await _updatePushIds(user);
      state = AsyncValue.data(user);
    } on FirebaseAuthException catch (e, st) {
      state = AsyncValue.error(e.message ?? "Login failed", st);
    }
  }

  Future<void> _updatePushIds(User? user) async {
    if (user == null) return;

    await Future.delayed(const Duration(seconds: 2));
    final pushSub = OneSignal.User.pushSubscription;
    final oneSignalId = pushSub.id;
    final isSubscribed = pushSub.optedIn ?? false;
    final fcmToken = await FirebaseMessaging.instance.getToken();

    print("📲 OneSignal ID: $oneSignalId");
    print("🔔 Opted In: $isSubscribed");
    print("📩 FCM Token: $fcmToken");

    final userRef = ref.read(fireStoreProvider).collection('start').doc(user.uid);
    final doc = await userRef.get();
    final data = doc.data();

    if (!doc.exists) {
      await userRef.set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'oneSignalId': (isSubscribed && oneSignalId != null) ? oneSignalId : '',
        'fcmToken': fcmToken ?? '',
      });
      return;
    }

    if (isSubscribed && oneSignalId != null && oneSignalId.isNotEmpty && data?['oneSignalId'] != oneSignalId) {
      await userRef.update({'oneSignalId': oneSignalId});
    }

    if (fcmToken != null && fcmToken.isNotEmpty && data?['fcmToken'] != fcmToken) {
      await userRef.update({'fcmToken': fcmToken});
    }
  }
}
