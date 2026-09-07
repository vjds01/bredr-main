class PetMediaValidation {
  PetMediaValidation._();

  static const int maxVideoBytes = 50 * 1024 * 1024;

  static bool isMp4Path(String path) => path.toLowerCase().endsWith('.mp4');

  static bool isVideoSizeAllowed(int sizeBytes) =>
      sizeBytes >= 0 && sizeBytes <= maxVideoBytes;

  static List<String> uniqueAdditionalUrls(
    Iterable<String> urls, {
    String? exclude,
  }) {
    final excluded = exclude?.trim() ?? '';
    final seen = <String>{if (excluded.isNotEmpty) excluded};
    return urls.map((url) => url.trim()).where((url) {
      if (url.isEmpty || !seen.add(url)) return false;
      return true;
    }).toList();
  }
}
