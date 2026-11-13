import 'package:flutter/foundation.dart';

/// Información de una release de GitHub y disponibilidad de actualización.
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.isUpdateAvailable,
    this.title = '',
    this.changelog = '',
    this.htmlUrl = '',
    this.downloadUrl,
    this.assetName,
    this.publishedAt,
  });

  final String currentVersion;
  final String latestVersion;
  final bool isUpdateAvailable;
  final String title;
  final String changelog;
  final String htmlUrl;
  final String? downloadUrl;
  final String? assetName;
  final DateTime? publishedAt;

  static const UpdateInfo upToDate = UpdateInfo(
    currentVersion: '',
    latestVersion: '',
    isUpdateAvailable: false,
  );
}
