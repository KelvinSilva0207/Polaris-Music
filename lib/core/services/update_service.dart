import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../constants/app_paths.dart';
import '../models/update_info.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';
import '../utils/semver.dart';

/// Comprobación de actualizaciones contra las releases de GitHub.
///
/// Fase 1: consulta la última release, compara versiones y descarga el binario
/// a la carpeta de descargas de la app. La instalación desatendida queda para
/// la fase de empaquetado (MSIX / APK), por lo que aquí solo se abre el archivo
/// o la página de la release.
class UpdateService {
  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  static const String _tag = 'Updates';

  final Dio _dio;

  String? _currentVersion;

  Future<String> currentVersion() async {
    final String? cached = _currentVersion;
    if (cached != null) return cached;
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      _currentVersion = info.version.isEmpty
          ? AppConstants.appVersionFallback
          : info.version;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo leer la versión instalada', error, stack);
      _currentVersion = AppConstants.appVersionFallback;
    }
    return _currentVersion!;
  }

  /// Consulta `releases/latest`. Devuelve `null` si no hay red o la API falla.
  Future<UpdateInfo?> checkForUpdates() async {
    final String current = await currentVersion();
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .get<Map<String, dynamic>>(
            AppConstants.githubReleasesUrl,
            options: Options(
              headers: <String, String>{
                'Accept': 'application/vnd.github+json',
                'User-Agent': '${AppConstants.appName}/$current',
              },
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 10),
            ),
          );

      final Map<String, dynamic>? json = response.data;
      if (json == null) return null;

      final String tag = (json['tag_name'] as String?)?.trim() ?? '';
      final String latestRaw = tag.isEmpty
          ? ((json['name'] as String?) ?? AppConstants.appVersionFallback)
          : tag;

      final SemanticVersion? latest = SemanticVersion.tryParse(latestRaw);
      final SemanticVersion? installed = SemanticVersion.tryParse(current);
      final bool available =
          latest != null && installed != null && latest > installed;

      final String? assetUrl = _pickAsset(json['assets']);
      final String? assetName = _pickAssetName(json['assets']);

      return UpdateInfo(
        currentVersion: current,
        latestVersion: latest?.toString() ?? latestRaw,
        isUpdateAvailable: available,
        title: (json['name'] as String?) ?? latestRaw,
        changelog: (json['body'] as String?) ?? '',
        htmlUrl:
            (json['html_url'] as String?) ?? AppConstants.githubReleasesPage,
        downloadUrl: assetUrl,
        assetName: assetName,
        publishedAt: DateTime.tryParse((json['published_at'] as String?) ?? '')
            ?.toLocal(),
      );
    } on DioException catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo consultar GitHub: ${error.message ?? error.type.name}',
        error,
        stack,
      );
      return null;
    } catch (error, stack) {
      AppLog.w(_tag, 'Respuesta inesperada de GitHub', error, stack);
      return null;
    }
  }

  String? _pickAsset(dynamic assets) {
    final Map<String, dynamic>? chosen = _chooseAsset(assets);
    return chosen?['browser_download_url'] as String?;
  }

  String? _pickAssetName(dynamic assets) {
    final Map<String, dynamic>? chosen = _chooseAsset(assets);
    return chosen?['name'] as String?;
  }

  /// Prefiere el instalador de la plataforma actual; si no existe, cualquier
  /// archivo descargable de la release.
  Map<String, dynamic>? _chooseAsset(dynamic rawAssets) {
    if (rawAssets is! List) return null;
    final List<Map<String, dynamic>> assets = rawAssets
        .whereType<Map<String, dynamic>>()
        .where(
          (Map<String, dynamic> a) =>
              (a['browser_download_url'] as String?) != null,
        )
        .toList(growable: false);
    if (assets.isEmpty) return null;

    final List<String> preferredExtensions;
    if (kIsWeb) {
      preferredExtensions = <String>[];
    } else if (Platform.isWindows) {
      preferredExtensions = <String>['.exe', '.msix', '.msixbundle', '.zip'];
    } else if (Platform.isAndroid) {
      preferredExtensions = <String>['.apk', '.aab'];
    } else {
      preferredExtensions = <String>[];
    }

    for (final String ext in preferredExtensions) {
      for (final Map<String, dynamic> asset in assets) {
        final String name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith(ext)) return asset;
      }
    }
    return assets.first;
  }

  /// Descarga el binario de la release. Devuelve la ruta local, o `null`.
  Future<String?> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final String? url = info.downloadUrl;
    if (url == null || url.isEmpty) return null;

    try {
      final Directory dir = await AppPaths.downloads();
      final String rawName = info.assetName ?? p.basename(Uri.parse(url).path);
      final String safeName = FileUtils.sanitizeFileName(
        rawName.isEmpty ? 'polaris_update' : rawName,
      );
      final String target = p.join(dir.path, safeName);

      await _dio.download(
        url,
        target,
        deleteOnError: true,
        cancelToken: cancelToken,
        options: Options(
          headers: <String, String>{
            'User-Agent': '${AppConstants.appName}/${info.currentVersion}',
          },
          followRedirects: true,
        ),
        onReceiveProgress: onProgress,
      );

      AppLog.i(_tag, 'Actualización descargada en $target');
      return target;
    } on DioException catch (error, stack) {
      AppLog.w(_tag, 'Falló la descarga de la actualización', error, stack);
      return null;
    } catch (error, stack) {
      AppLog.w(_tag, 'Error inesperado al descargar', error, stack);
      return null;
    }
  }

  Future<bool> openReleasePage(UpdateInfo info) => _open(
    info.htmlUrl.isEmpty ? AppConstants.githubReleasesPage : info.htmlUrl,
  );

  Future<bool> openDownloadedFile(String path) => _open(path);

  /// Abre la carpeta de descargas en el explorador (Windows).
  Future<bool> openDownloadsFolder() async {
    try {
      final Directory dir = await AppPaths.downloads();
      if (!kIsWeb && Platform.isWindows) {
        await Process.run('explorer.exe', <String>[dir.path]);
        return true;
      }
      return await _open(dir.path);
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo abrir la carpeta de descargas', error, stack);
      return false;
    }
  }

  Future<bool> _open(String target) async {
    try {
      final Uri uri = Uri.file(target);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      final Uri parsed = Uri.parse(target);
      return await launchUrl(parsed, mode: LaunchMode.externalApplication);
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo abrir $target', error, stack);
      return false;
    }
  }
}
