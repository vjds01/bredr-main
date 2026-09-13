import 'package:breedr/services/pet_media_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PetMediaValidation', () {
    test('accepts supported image extensions case-insensitively', () {
      expect(PetMediaValidation.isImagePath('pet.JPG'), isTrue);
      expect(PetMediaValidation.isImagePath('pet.jpeg'), isTrue);
      expect(PetMediaValidation.isImagePath('pet.PNG'), isTrue);
      expect(PetMediaValidation.isImagePath('pet.gif'), isFalse);
    });

    test('accepts an image exactly 5 MB and rejects larger images', () {
      expect(PetMediaValidation.isImageSizeAllowed(5 * 1024 * 1024), isTrue);
      expect(
        PetMediaValidation.isImageSizeAllowed(5 * 1024 * 1024 + 1),
        isFalse,
      );
    });

    test('accepts MP4 extensions case-insensitively', () {
      expect(PetMediaValidation.isMp4Path('pet-video.mp4'), isTrue);
      expect(PetMediaValidation.isMp4Path('PET-VIDEO.MP4'), isTrue);
      expect(PetMediaValidation.isMp4Path('pet-video.mov'), isFalse);
    });

    test('accepts a video exactly 50 MB', () {
      expect(
        PetMediaValidation.isVideoSizeAllowed(PetMediaValidation.maxVideoBytes),
        isTrue,
      );
    });

    test('rejects a video even one byte above 50 MB', () {
      expect(
        PetMediaValidation.isVideoSizeAllowed(
          PetMediaValidation.maxVideoBytes + 1,
        ),
        isFalse,
      );
    });

    test('removes the profile image and duplicate additional URLs', () {
      expect(
        PetMediaValidation.uniqueAdditionalUrls(const [
          'profile.jpg',
          'extra.jpg',
          'extra.jpg',
          'second.jpg',
        ], exclude: 'profile.jpg'),
        const ['extra.jpg', 'second.jpg'],
      );
    });
  });
}
