import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerHelper {
  static final _picker = ImagePicker();

  /// Pick from gallery
  static Future<File?> pickFromGallery() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    return xFile != null ? File(xFile.path) : null;
  }

  /// Take a photo with camera
  static Future<File?> takePhoto() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    return xFile != null ? File(xFile.path) : null;
  }

  /// Show bottom sheet to choose camera or gallery
  static Future<File?> showPickerSheet(BuildContext context) async {
    File? result;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFE8EA),
                  child: Icon(Icons.camera_alt,
                      color: Color(0xFFF43845)),
                ),
                title: const Text('Take a Photo',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  result = await takePhoto();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F0FF),
                  child: Icon(Icons.photo_library_outlined,
                      color: Color(0xFF5399F0)),
                ),
                title: const Text('Upload from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  result = await pickFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
    return result;
  }
}
