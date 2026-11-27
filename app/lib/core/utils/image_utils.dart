import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Client-side re-encode before upload.
///
/// Storage rules validate type + size but cannot strip EXIF, so images are
/// re-encoded here (which also drops EXIF — mirroring the PHP backend's
/// re-encode-and-strip-EXIF behaviour) and downscaled to keep uploads fast on
/// mobile data.
class CompressedImage {
  const CompressedImage({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

Future<CompressedImage?> compressForUpload(
  XFile file, {
  int minWidth = 1280,
  int minHeight = 1280,
  int quality = 82,
}) async {
  try {
    final bytes = await FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      keepExif: false,
    );
    if (bytes == null || bytes.isEmpty) return null;

    final name = '${_stripExtension(file.name)}.jpg';
    return CompressedImage(
      bytes: bytes,
      fileName: name,
      contentType: 'image/jpeg',
    );
  } catch (_) {
    // Fall back to the raw bytes if compression fails on this platform.
    final raw = await file.readAsBytes();
    if (raw.isEmpty) return null;
    return CompressedImage(
      bytes: raw,
      fileName: file.name,
      contentType: 'image/jpeg',
    );
  }
}

String _stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}
