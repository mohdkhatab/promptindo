import 'package:image_picker/image_picker.dart';

import '../utils/image_utils.dart';

/// Opens the system picker (camera or gallery) and returns re-encoded JPEG
/// bytes ready for Storage (type + 8MB rules are satisfied by construction).
Future<CompressedImage?> pickAndCompress({required bool fromCamera}) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  if (file == null) return null;
  return compressForUpload(file);
}
