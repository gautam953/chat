import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProfileImageNotifier extends StateNotifier<File?> {
  ProfileImageNotifier() : super(null) {
    _loadImageFromPrefs();
  }

  Future<void> _loadImageFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image');
    if (path != null && File(path).existsSync()) {
      state = File(path);
    }
  }

  Future<void> pickImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      return; // or show a dialog
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final filename = p.basename(pickedFile.path);
      final savedPath = p.join(directory.path, filename);
      final savedFile = await File(pickedFile.path).copy(savedPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image', savedFile.path);

      state = savedFile;
    }
  }
}
