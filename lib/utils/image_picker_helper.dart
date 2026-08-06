import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// 选择多张图片并编码为 base64
///
/// 统一图片选择与 base64 编码逻辑（尺寸上限 1024、质量 80），
/// 返回 base64 与对应原始文件的元组列表；用户取消选择时返回空列表。
Future<List<(String, File)>> pickImagesAsBase64() async {
  final picker = ImagePicker();
  // 使用 pickMultiImage 支持多选
  final picked = await picker.pickMultiImage(
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 80,
  );
  if (picked.isEmpty) return [];

  final result = <(String, File)>[];
  for (final xFile in picked) {
    final file = File(xFile.path);
    final bytes = await file.readAsBytes();
    result.add((base64Encode(bytes), file));
  }
  return result;
}
