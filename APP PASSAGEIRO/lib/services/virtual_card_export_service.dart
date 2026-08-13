import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

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
    String? initialDirectory,
  }) async {
    try {
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        confirmButtonText: 'Guardar',
        initialDirectory: initialDirectory,
        canCreateDirectories: true,
      );

      if (location == null) {
        return VirtualCardExportResult.cancelled();
      }

      final file = File(location.path);
      await file.writeAsBytes(bytes, flush: true);
      return VirtualCardExportResult.saved(file.path);
    } catch (_) {
      return VirtualCardExportResult.failure(
        'Não foi possível guardar o cartão.',
      );
    }
  }
}