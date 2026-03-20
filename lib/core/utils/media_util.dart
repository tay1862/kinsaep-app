import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SavedMediaAsset {
  final String fileName;
  final String mimeType;
  final String imagePath;
  final String thumbnailBase64;
  final int width;
  final int height;
  final int fileSize;

  const SavedMediaAsset({
    required this.fileName,
    required this.mimeType,
    required this.imagePath,
    required this.thumbnailBase64,
    required this.width,
    required this.height,
    required this.fileSize,
  });
}

class MediaUtil {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickFromCamera() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 1600,
    );
  }

  static Future<XFile?> pickFromGallery() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
  }

  static Future<SavedMediaAsset?> savePickedImage(
    XFile pickedFile, {
    required String itemId,
  }) async {
    final bytes = await pickedFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docsDir.path, 'item_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final extension = p.extension(pickedFile.path).toLowerCase();
    final fileName =
        '$itemId-${DateTime.now().millisecondsSinceEpoch}$extension';
    final localPath = p.join(imagesDir.path, fileName);
    await File(localPath).writeAsBytes(bytes, flush: true);

    final thumbnail = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? 360 : null,
      height: decoded.height >= decoded.width ? 360 : null,
      interpolation: img.Interpolation.average,
    );
    final thumbBytes = img.encodeJpg(thumbnail, quality: 72);

    return SavedMediaAsset(
      fileName: fileName,
      mimeType: _mimeTypeForExtension(extension),
      imagePath: localPath,
      thumbnailBase64: base64Encode(thumbBytes),
      width: decoded.width,
      height: decoded.height,
      fileSize: bytes.length,
    );
  }

  static String _mimeTypeForExtension(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
