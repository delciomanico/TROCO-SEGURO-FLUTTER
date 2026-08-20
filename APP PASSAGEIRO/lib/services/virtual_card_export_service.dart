import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

class VirtualCardExportResult {
  final String? path;
  final String? error;
  final bool cancelled;

  const VirtualCardExportResult._({this.path, this.error, required this.cancelled});

  factory VirtualCardExportResult.saved(String path) {
    return VirtualCardExportResult._(path: path, cancelled: false);
  }

  factory VirtualCardExportResult.cancelled() {
    return const VirtualCardExportResult._(cancelled: true);
  }

  factory VirtualCardExportResult.failure(String error) {
    return VirtualCardExportResult._(error: error, cancelled: false);
  }
}

class VirtualCardExportService {
  static final VirtualCardExportService _instance =
      VirtualCardExportService._internal();
  factory VirtualCardExportService() => _instance;
  VirtualCardExportService._internal();

  Future<VirtualCardExportResult> saveImageBytes(
    Uint8List bytes, {
    required String suggestedName,
  }) async {
    final dotIndex = suggestedName.lastIndexOf('.');
    final baseName =
        dotIndex > 0 ? suggestedName.substring(0, dotIndex) : suggestedName;

    try {
      final path = await FileSaver.instance.saveAs(
        name: baseName,
        bytes: bytes,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );

      if (path == null) {
        return VirtualCardExportResult.cancelled();
      }

      return VirtualCardExportResult.saved(path);
    } catch (_) {
      return VirtualCardExportResult.failure(
        'Não foi possível guardar o cartão.',
      );
    }
  }
}