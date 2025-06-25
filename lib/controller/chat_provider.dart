// chat_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

String getChatId(String user1, String user2) {
  final sorted = [user1, user2]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final chatMessagesProvider =
StreamProvider.family.autoDispose<QuerySnapshot, String>((ref, chatId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots();
});

class ChatController extends StateNotifier<Set<String>> {
  final Ref ref;

  ChatController(this.ref) : super({});

  void toggleSelection(String id) {
    final current = {...state};
    current.contains(id) ? current.remove(id) : current.add(id);
    state = current;
  }

  void clearSelection() => state = {};

  Future<void> sendMessage({
    required String userId,
    required String currentUserId,
    required String message,
  }) async {
    final firestore = ref.read(firestoreProvider);
    final chatId = getChatId(currentUserId, userId);
    final chatRef =
    firestore.collection('chats').doc(chatId).collection('messages');

    // 1. Add chat message to Firestore
    await chatRef.add({
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
      'senderId': currentUserId,
    });

    // 2. Fetch receiver OneSignal ID
    final receiverDoc = await firestore.collection('start').doc(userId).get();
    final data = receiverDoc.data();

    if (data == null) {
      print("❌ Receiver document not found for userId: $userId");
      return;
    }

    final playerId = data['oneSignalId'];
    print("🎯 Found OneSignal ID: $playerId");

    if (playerId != null && playerId.toString().trim().isNotEmpty) {
      try {
        print("📨 Sending push via OneSignal to $playerId");
        await NotificationService.sendPushNotification(
          token: playerId,
          message: message,
        );
      } catch (e) {
        print("🚨 Failed to send OneSignal notification: $e");
      }
    } else {
      print("⚠️ No valid OneSignal ID found for receiver with userId: $userId");
    }
  }

  Future<void> deleteMessages(String chatId) async {
    final firestore = ref.read(firestoreProvider);
    final chatRef =
    firestore.collection('chats').doc(chatId).collection('messages');

    for (final id in state) {
      await chatRef.doc(id).delete();
    }
    clearSelection();
  }
}

final chatControllerProvider =
StateNotifierProvider<ChatController, Set<String>>((ref) {
  return ChatController(ref);
});
