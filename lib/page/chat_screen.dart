  import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_storage/firebase_storage.dart';
  import 'package:intl/intl.dart';
  import 'package:path_provider/path_provider.dart';
  import 'package:record/record.dart';
  import 'package:uuid/uuid.dart';
  import '../controller/chat_provider.dart';

  class ChatScreen extends ConsumerStatefulWidget {
    final String userId;
    final String userEmail;
    final String currentUserId;
    final bool? isGroup;
    final String lastMassage;

    const ChatScreen({
      super.key,
      required this.userId,
      required this.userEmail,
      required this.currentUserId,
      required this.lastMassage,
      this.isGroup,
    });

    @override
    ConsumerState<ChatScreen> createState() => _ChatScreenState();
  }

  class _ChatScreenState extends ConsumerState<ChatScreen> {
    final _messageController = TextEditingController();
    final AudioRecorder _record = AudioRecorder();
    bool _composing = false;
    bool _isRecording = false;
    String? _recordingPath;

    @override
    void dispose() {
      _messageController.dispose();
      super.dispose();
    }

    void _send() {
      final text = _messageController.text.trim();
      if (text.isEmpty) return;

      ref
          .read(chatControllerProvider.notifier)
          .sendMessage(
            userId: widget.userId,
            currentUserId: widget.currentUserId,
            message: text,
          );

      _messageController.clear();
      setState(() => _composing = false);
    }

    Future<void> _sendAudioMessage(String path) async {
      final file = File(path);
      final fileName = const Uuid().v4();
      final ref = FirebaseStorage.instance.ref().child(
        'audio_messages/$fileName.m4a',
      );
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(getChatId(widget.currentUserId, widget.userId))
          .collection('messages')
          .add({
            'senderId': widget.currentUserId,
            'timestamp': FieldValue.serverTimestamp(),
            'audioUrl': url,
            'isRead': false,
          });
    }

    Future<void> _startRecording() async {
      final hasPermission = await _record.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _record.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _recordingPath = path;
        _isRecording = true;
      });
    }

    Future<void> _stopAndSendRecording() async {
      final path = await _record.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await _sendAudioMessage(path);
      }
    }

    @override
    Widget build(BuildContext context) {
      final selection = ref.watch(chatControllerProvider);
      final chatId = getChatId(widget.currentUserId, widget.userId);
      final messages = ref.watch(chatMessagesProvider(chatId));
      final selecting = selection.isNotEmpty;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Scaffold(
        appBar: AppBar(
          title: Text(
            selecting ? '${selection.length} selected' : widget.userEmail,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: selecting
              ? [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => ref
                        .read(chatControllerProvider.notifier)
                        .deleteMessages(chatId),
                  ),
                ]
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (snap) {
                  final docs = snap.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Start chatting!',
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (_, index) {
                      final msg = docs[index];
                      final data = msg.data() as Map<String, dynamic>?;

                      final isMe = data?['senderId'] == widget.currentUserId;
                      final msgId = msg.id;
                      final selected = selection.contains(msgId);
                      final ts = data?['timestamp'];
                      final audioUrl =
                          data != null && data.containsKey('audioUrl')
                          ? data['audioUrl']
                          : null;

                      String formattedTime = '';
                      if (ts != null && ts is Timestamp) {
                        final time = ts.toDate().toLocal();
                        formattedTime = DateFormat('hh:mm a').format(time);
                      }

                      final bgColor = selected
                          ? Colors.red.withOpacity(0.6)
                          : isMe
                          ? Colors.blue
                          : isDark
                          ? Colors.blueGrey.shade700
                          : Colors.grey.shade300;

                      final textColor = isMe || selected
                          ? Colors.white
                          : isDark
                          ? Colors.white
                          : Colors.black;

                      return GestureDetector(
                        onLongPress: () => ref
                            .read(chatControllerProvider.notifier)
                            .toggleSelection(msgId),
                        onTap: () {
                          if (selecting) {
                            ref
                                .read(chatControllerProvider.notifier)
                                .toggleSelection(msgId);
                          }
                        },
                        child: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 14,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: Radius.circular(isMe ? 12 : 0),
                                bottomRight: Radius.circular(isMe ? 0 : 12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (audioUrl != null)
                                  IconButton(
                                    icon: Icon(
                                      Icons.play_arrow,
                                      color: textColor,
                                    ),
                                    onPressed: () {
                                      // TODO: Implement audio playback
                                    },
                                  )
                                else
                                  Text(
                                    data?['text'] ?? '',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                if (formattedTime.isNotEmpty)
                                  Text(
                                    formattedTime,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey[800]
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onChanged: (text) =>
                          setState(() => _composing = text.trim().isNotEmpty),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _isRecording ? Colors.red : Colors.grey,
                    child: IconButton(
                      icon: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        if (_isRecording) {
                          await _stopAndSendRecording();
                        } else {
                          await _startRecording();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _composing
                        ? Colors.blue
                        : Colors.grey.shade400,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _composing ? _send : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  String getChatId(String a, String b) =>
      a.hashCode <= b.hashCode ? '${a}_$b' : '${b}_$a';
