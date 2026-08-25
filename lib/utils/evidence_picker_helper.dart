import 'dart:io';

import 'package:flutter/material.dart';

class SelectedEvidenceFile {
  final File file;
  final String fileName;
  final String fileType;
  final String mimeType;
  final int sizeBytes;

  const SelectedEvidenceFile({
    required this.file,
    required this.fileName,
    required this.fileType,
    required this.mimeType,
    required this.sizeBytes,
  });

  static SelectedEvidenceFile? fromPath(
    String path, {
    required String fileName,
    required int sizeBytes,
  }) {
    final extension = fileName.split('.').last.toLowerCase();
    final fileType = switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'webp' => 'image',
      'mp4' || 'mov' || 'm4v' => 'video',
      _ => '',
    };
    if (fileType.isEmpty) return null;
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      _ => 'application/octet-stream',
    };
    return SelectedEvidenceFile(
      file: File(path),
      fileName: fileName,
      fileType: fileType,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
  }

  bool get isValidSize {
    return sizeBytes <= 50 * 1024 * 1024;
  }

  IconData get icon {
    return switch (fileType) {
      'image' => Icons.image_outlined,
      'video' => Icons.videocam_outlined,
      _ => Icons.attach_file,
    };
  }
}
