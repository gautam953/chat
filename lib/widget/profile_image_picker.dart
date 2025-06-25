import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/profile_image_notifier.dart';

class ProfileImagePicker extends ConsumerWidget {
  const ProfileImagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageFile = ref.watch(profileImageProvider);
    final controller = ref.read(profileImageProvider.notifier);

    return GestureDetector(
      onTap: controller.pickImage,
      child: CircleAvatar(
        radius: 60,
        backgroundColor: Colors.blue,
        backgroundImage: imageFile != null ? FileImage(imageFile) : null,
        child: imageFile == null
            ? const Icon(Icons.person, size: 50, color: Colors.white)
            : null,
      ),
    );
  }
}
