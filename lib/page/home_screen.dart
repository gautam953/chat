import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:untitled/page/profile_screen.dart';
import '../controller/home_providers.dart';
import 'chat_screen.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);

class FirestoreUser {
  final String id;
  final String name;
  final String email;

  FirestoreUser({required this.id, required this.name, required this.email});

  factory FirestoreUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FirestoreUser(
      id: doc.id,
      name: data['name'] ?? 'No Name',
      email: data['email'] ?? 'No Email',
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _selectedUserIds = <String>{};
  late TextEditingController _searchController;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        setState(() => _searchQuery = _searchController.text.toLowerCase());
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String getChatId(String a, String b) =>
      a.hashCode <= b.hashCode ? '${a}_$b' : '${b}_$a';

  void _toggleSelection(String uid) {
    setState(() {
      _selectedUserIds.contains(uid)
          ? _selectedUserIds.remove(uid)
          : _selectedUserIds.add(uid);
    });
  }

  Future<void> _createGroupChat(User cu) async {
    if (_selectedUserIds.isEmpty) return;

    // Ask for group name
    final groupName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Group Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Group name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (groupName == null || groupName.isEmpty) return;

    final members = [..._selectedUserIds, cu.uid];

    final group = await FirebaseFirestore.instance.collection('groupChats').add(
      {
        'createdAt': FieldValue.serverTimestamp(),
        'members': members,
        'createdBy': cu.uid,
        'groupName': groupName, // ✅ save group name
      },
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          userId: group.id,
          userEmail: groupName,
          currentUserId: cu.uid,
          isGroup: true,
          lastMassage: '',
        ),
      ),
    );

    setState(() => _selectedUserIds.clear());
  }

  Widget _buildUserCard(FirestoreUser user, User cu) {
    final isSel = _selectedUserIds.contains(user.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(getChatId(cu.uid, user.id))
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (ctx, snap) {
        String lastMessage = '';
        String time = '';

        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final doc = snap.data!.docs.first;
          final data = doc.data() as Map<String, dynamic>? ?? {};

          final senderId = data['senderId'];
          final msgText = data['text'] ?? '';
          final ts = data['timestamp'];

          if (msgText is String) {
            lastMessage = senderId == cu.uid ? 'You: $msgText' : msgText;
          }

          if (ts is Timestamp) {
            final date = ts.toDate();
            time = DateFormat('hh:mm a').format(date);
          }
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isSel
              ? Colors.blue.withOpacity(0.1)
              : isDark
              ? Colors.grey[900]
              : Colors.white,
          child: ListTile(
            tileColor: isSel ? Colors.blue.withOpacity(0.15) : null,
            onTap: () {
              if (_selectedUserIds.isNotEmpty) {
                _toggleSelection(user.id);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      userId: user.id,
                      userEmail: user.email,
                      currentUserId: cu.uid,
                      lastMassage: lastMessage,
                    ),
                  ),
                );
              }
            },
            onLongPress: () => _toggleSelection(user.id),
            title: Text(
              user.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            trailing: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(getChatId(cu.uid, user.id))
                  .collection('messages')
                  .where('senderId', isNotEqualTo: cu.uid)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (ctx, unreadSnap) {
                int unreadCount = 0;
                if (unreadSnap.hasData) {
                  unreadCount = unreadSnap.data!.docs.length;
                }

                if (unreadCount > 0) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                }

                return Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cu = ref.watch(currentUserProvider);
    final currentIndex = ref.watch(navIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(hintText: 'Search...'),
              )
            : Text(
                _selectedUserIds.isNotEmpty
                    ? '${_selectedUserIds.length} selected'
                    : 'Chat App',
              ),
        actions: [
          if (_selectedUserIds.isNotEmpty && cu != null)
            IconButton(
              icon: const Icon(Icons.group_add),
              onPressed: () => _createGroupChat(cu),
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() => _isSearching = !_isSearching),
          ),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: [home(), buildGroupList(), profile()],
      ),
      floatingActionButton: Container(
        height: 50,
        width: 330,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(
                Icons.home,
                color: currentIndex == 0 ? Colors.white : Colors.grey,
              ),
              onPressed: () => ref.read(navIndexProvider.notifier).state = 0,
            ),
            IconButton(
              icon: Icon(
                Icons.group,
                color: currentIndex == 1 ? Colors.white : Colors.grey,
              ),
              onPressed: () => ref.read(navIndexProvider.notifier).state = 1,
            ),
            IconButton(
              icon: Icon(
                Icons.person,
                color: currentIndex == 2 ? Colors.white : Colors.grey,
              ),
              onPressed: () => ref.read(navIndexProvider.notifier).state = 2,
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget buildGroupList() {
    final cu = ref.watch(currentUserProvider);
    if (cu == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groupChats')
          .where('members', arrayContains: cu.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No group chats found.'));
        }
        return ListView(
          children: snapshot.data!.docs
              .map((doc) => _buildGroupCard(doc, cu.uid))
              .toList(),
        );
      },
    );
  }

  Widget _buildGroupCard(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;
    final groupId = doc.id;
    final members = List<String>.from(data['members'] ?? []);
    final createdAt = data['createdAt'] as Timestamp?;

    return Card(
      child: ListTile(
        title: Text('${data["groupName"]}'),
        subtitle: Text('Members: ${members.length}'),
        trailing: Text(
          createdAt != null
              ? DateFormat('dd MMM, hh:mm a').format(createdAt.toDate())
              : '',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                userId: groupId,
                userEmail: 'Group Chat',
                currentUserId: currentUserId,
                isGroup: true,
                lastMassage: '',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget profile() {
    return Builder(
      builder: (context) {
        final cu = ref.watch(currentUserProvider);
        if (cu == null) return const Center(child: CircularProgressIndicator());
        return ProfileScreen(currentUser: cu);
      },
    );
  }

  Widget home() {
    final cu = ref.watch(currentUserProvider);
    final stream = ref.watch(usersStreamProvider);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: stream.when(
        data: (snap) {
          final list = snap.docs
              .where((d) => d.id != cu?.uid)
              .map(FirestoreUser.fromDoc)
              .where(
                (u) =>
                    u.name.toLowerCase().contains(_searchQuery) ||
                    u.email.toLowerCase().contains(_searchQuery),
              )
              .toList();

          if (list.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => _buildUserCard(list[i], cu!),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
