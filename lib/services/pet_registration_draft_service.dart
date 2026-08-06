import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet_listing_data.dart';

class PetRegistrationDraftService {
  PetRegistrationDraftService._();

  static final PetRegistrationDraftService instance =
      PetRegistrationDraftService._();

  static const _keyPrefix = 'pet_registration_draft';

  Future<PetListingData?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PetListingData.fromDraftJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDraft(PetListingData petData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(petData.toDraftJson()));
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  String get _draftKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${_keyPrefix}_$uid';
  }
}
