// main profile screen with image picker integrated
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widget/profile_image_picker.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final User currentUser;

  const ProfileScreen({super.key, required this.currentUser});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String userName = '';
  String joinDate = '';
  late TextEditingController nameController;
  late TextEditingController emailController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('start')
        .doc(widget.currentUser.uid)
        .get();

    final data = userDoc.data();
    if (data != null) {
      setState(() {
        userName = data['name'] ?? 'No Name';
        nameController.text = userName;
        emailController.text = widget.currentUser.email ?? 'No Email';
        final ts = data['createdAt'];
        if (ts != null && ts is Timestamp) {
          joinDate = DateFormat('dd MMM yyyy').format(ts.toDate());
        }
      });
    }
  }

  Future<void> _changePassword() async {
    final currentUser = widget.currentUser;
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassController,
              decoration: const InputDecoration(hintText: 'Current password'),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPassController,
              decoration: const InputDecoration(hintText: 'New password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Change')),
        ],
      ),
    );

    if (result == true) {
      final oldPassword = oldPassController.text.trim();
      final newPassword = newPassController.text.trim();

      if (newPassword.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 6 characters')),
        );
        return;
      }

      try {
        final email = currentUser.email;
        if (email == null) throw 'No email available';

        final cred = EmailAuthProvider.credential(email: email, password: oldPassword);
        await currentUser.reauthenticateWithCredential(cred);
        await currentUser.updatePassword(newPassword);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Password changed successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Widget _buildReadOnlyField(TextEditingController controller, IconData icon, String label) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ProfileImagePicker(),
          const SizedBox(height: 30),
          _buildReadOnlyField(nameController, Icons.person, 'Name'),
          const SizedBox(height: 30),
          _buildReadOnlyField(emailController, Icons.email, 'Email'),
          const SizedBox(height: 30),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 8),
              Text('Joined: $joinDate', style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 50,
            width: 400,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.lock_reset, color: Colors.white),
              label: const Text('Change Password', style: TextStyle(color: Colors.white)),
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
