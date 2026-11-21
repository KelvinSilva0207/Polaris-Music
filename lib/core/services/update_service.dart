import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../models/update_info.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';
import '../utils/semver.dart';

/// Comprobación de actualizaciones contra las releases de GitHub.
///
/// Consulta la última release, compara versiones y descarga el binario a la
/// carpeta de descargas de la app. En Windows el instalador de Inno Setup se
/// puede ejecutar en modo desatendido y la app se reinicia al terminar; en el
/// resto de plataformas se abre el archivo o la página de la release.
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
  ///
  /// En Windows se prioriza el instalador (`Polaris-Music-Setup-*.exe`) sobre
  /// otros `.exe` o el ZIP portable, para que el botón "Instalar ahora" reciba
  /// siempre el paquete correcto.
  Map<String, dynamic>? _chooseAsset(dynamic rawAssets) {
    if (rawAssets is! List) return null;
    final List<Map<String, dynamic>> assets = rawAssets
        .whereType<Map<String, dynamic>>()
        .where(
          (Map<String, dynamic> a) =>
              (a['browser_download_url'] as String?) != null,
        )
        .where((Map<String, dynamic> a) {
          final String name = (a['name'] as String? ?? '').toLowerCase();
          return !_ignoredAssetExtensions.any(name.endsWith);
        })
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

    int score(Map<String, dynamic> asset) {
      final String name = (asset['name'] as String? ?? '').toLowerCase();
      int value = 0;
      for (int i = 0; i < preferredExtensions.length; i++) {
        if (name.endsWith(preferredExtensions[i])) {
          value += (preferredExtensions.length - i) * 10;
          break;
        }
      }
      if (name.contains('setup') || name.contains('installer')) {
        value += 6;
      }
      if (name.contains('polaris')) {
        value += 2;
      }
      return value;
    }

    final List<Map<String, dynamic>> sorted =
        List<Map<String, dynamic>>.of(assets)
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
            return score(b).compareTo(score(a));
          });
    return sorted.first;
  }

  static const List<String> _ignoredAssetExtensions = <String>[
    '.sha256',
    '.sha512',
    '.sig',
    '.txt',
    '.json',
    '.yml',
    '.yaml',
    '.blockmap',
  ];

  /// Descarga el binario de la release. Devuelve la ruta local, o `null`.
  Future<String?> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final String? url = info.downloadUrl;
    if (url == null || url.isEmpty) return null;

    try {
      // Los binarios de actualización son temporales: el instalador se lanza
      // desde aquí y Android copia el APK a su propio `cacheDir` antes de
      // compartirlo con el instalador del sistema.
      final Directory dir = await getTemporaryDirectory();
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

      final String? resolved = _resolveDownloadedBinary(dir, target);
      if (resolved == null) {
        AppLog.w(_tag, 'No se encontró un binario válido en ${dir.path}');
        return null;
      }
      final int size = File(resolved).lengthSync();
      if (size <= 0) {
        AppLog.w(_tag, 'La descarga está vacía: $resolved');
        return null;
      }

      AppLog.i(_tag, 'Actualización descargada en $resolved ($size bytes)');
      return resolved;
    } on DioException catch (error, stack) {
      AppLog.w(_tag, 'Falló la descarga de la actualización', error, stack);
      return null;
    } catch (error, stack) {
      AppLog.w(_tag, 'Error inesperado al descargar', error, stack);
      return null;
    }
  }

  /// Busca el binario descargado dentro del directorio temporal.
  ///
  /// En Windows se prefieren los instaladores `*-Setup-*.exe`, pero se acepta
  /// cualquier `.exe` por si la release cambia el patrón de nombres. En Android
  /// se busca un `.apk`.
  String? _resolveDownloadedBinary(Directory dir, String downloaded) {
    final File direct = File(downloaded);
    if (direct.existsSync() &&
        direct.lengthSync() > 0 &&
        _isInstallerCandidate(direct.path)) {
      return direct.path;
    }

    final List<File> candidates = dir
        .listSync()
        .whereType<File>()
        .where((File file) => _isInstallerCandidate(file.path))
        .where((File file) {
          try {
            return file.lengthSync() > 0;
          } catch (_) {
            return false;
          }
        })
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((File a, File b) {
      final DateTime aTime = a.statSync().modified;
      final DateTime bTime = b.statSync().modified;
      return bTime.compareTo(aTime);
    });
    return candidates.first.path;
  }

  bool _isInstallerCandidate(String path) {
    final String name = p.basename(path).toLowerCase();
    if (!kIsWeb && Platform.isAndroid) return name.endsWith('.apk');
    if (!kIsWeb && Platform.isWindows) {
      return name.endsWith('.exe') &&
          (name.contains('-setup-') ||
              name.contains('setup') ||
              name.startsWith('polaris'));
    }
    return true;
  }

  /// `true` si la actualización puede instalarse sin salir de la app.
  bool get canInstallSilently => !kIsWeb && Platform.isWindows;

  /// Argumentos del instalador de Inno Setup para una actualización silenciosa.
  ///
  /// `/FORCECLOSEAPPLICATIONS` evita el diálogo de cierre y `AppMutex` permite
  /// detectar también el proceso residente en la bandeja. El helper de PowerShell
  /// creado en [installDownloadedUpdate] espera a que esta app termine antes de
  /// ejecutar el instalador, así no hay DLL/EXE bloqueados.
  static List<String> installerArguments({required bool allUsers}) => <String>[
    '/SILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/CLOSEAPPLICATIONS',
    '/FORCECLOSEAPPLICATIONS',
    '/RESTARTAPPLICATIONS',
    '/LOG',
    '/AUTOUPDATE',
    allUsers ? '/ALLUSERS' : '/CURRENTUSER',
  ];

  /// Ejecuta el instalador descargado en modo desatendido.
  ///
  /// Se lanza un proceso detached de PowerShell que espera a que **esta**
  /// instancia termine (liberando mutex, Drift y DLLs) y solo entonces arranca
  /// el instalador. La app debe cerrarse justo después de que este método
  /// devuelva `true`; el instalador vuelve a abrirla con `/AUTOUPDATE`.
  Future<bool> installDownloadedUpdate(String path) async {
    if (!canInstallSilently) return false;

    try {
      final File installer = File(path);
      if (!await installer.exists()) {
        AppLog.w(_tag, 'El instalador ya no existe en $path');
        return false;
      }

      final List<String> arguments = installerArguments(
        allUsers: _installScopeArgument() == '/ALLUSERS',
      );

      final File helper = await _writeUpdateHelper(installer.path, arguments);
      try {
        final Process process = await Process.start('powershell.exe', <String>[
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          helper.path,
        ], mode: ProcessStartMode.detached);
        AppLog.i(
          _tag,
          'Actualizador lanzado (pid ${process.pid}); espera a que termine '
          'esta instancia antes de instalar',
        );
        return true;
      } catch (error, stack) {
        AppLog.w(
          _tag,
          'No se pudo lanzar el helper; se intenta el instalador directo',
          error,
          stack,
        );
        final Process process = await Process.start(
          installer.path,
          arguments,
          mode: ProcessStartMode.detached,
        );
        AppLog.i(_tag, 'Instalador directo lanzado (pid ${process.pid})');
        return true;
      }
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo lanzar el instalador', error, stack);
      return false;
    }
  }

  /// Escribe un script temporal que espera el PID actual y luego instala.
  ///
  /// No usa variables de PowerShell: todos los valores se inyectan como
  /// literales comillas simples para evitar inyección por rutas con `$`.
  Future<File> _writeUpdateHelper(
    String installer,
    List<String> arguments,
  ) async {
    final Directory dir = await getTemporaryDirectory();
    final File script = File(p.join(dir.path, 'polaris-update-$pid.ps1'));
    final String quotedArgs = arguments.map(_powerShellQuote).join(', ');
    // El script corre en otro proceso: $pid sería el del helper. Inyectamos
    // como literal el PID de esta instancia de Flutter, que es la que debe
    // terminar antes de sobrescribir EXE/DLLs.
    final int parentPid = pid;

    final StringBuffer content = StringBuffer()
      ..writeln('try {')
      ..writeln(
        '  (Get-Process -Id $parentPid -ErrorAction Stop)'
        '.WaitForExit(60000) | Out-Null',
      )
      ..writeln('} catch {}')
      ..writeln('try {')
      ..writeln(
        '  Start-Process -FilePath ${_powerShellQuote(installer)} '
        '-ArgumentList @($quotedArgs) -ErrorAction Stop | Out-Null',
      )
      ..writeln('} catch {')
      ..writeln(
        '  Remove-Item -LiteralPath ${_powerShellQuote(script.path)} '
        '-Force -ErrorAction SilentlyContinue',
      )
      ..writeln('  exit 1')
      ..writeln('}')
      ..writeln(
        'Remove-Item -LiteralPath ${_powerShellQuote(script.path)} '
        '-Force -ErrorAction SilentlyContinue',
      );

    await script.writeAsString(content.toString());
    return script;
  }

  static String _powerShellQuote(String value) =>
      "'${value.replaceAll("'", "''")}'";

  /// Elige el ámbito de instalación para que una actualización no duplique la
  /// app: `Program Files` → todos los usuarios; cualquier otra ruta → usuario
  /// actual (sin UAC).
  String _installScopeArgument() {
    try {
      final String executable = Platform.resolvedExecutable.toLowerCase();
      final Iterable<String> roots = <String?>[
        Platform.environment['ProgramFiles'],
        Platform.environment['ProgramFiles(x86)'],
        Platform.environment['ProgramW6432'],
      ].whereType<String>();
      for (final String root in roots) {
        final String normalized = root.toLowerCase().trimRight();
        if (normalized.isNotEmpty && executable.startsWith(normalized)) {
          return '/ALLUSERS';
        }
      }
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo detectar el ámbito de instalación',
        error,
        stack,
      );
    }
    return '/CURRENTUSER';
  }

  Future<bool> openReleasePage(UpdateInfo info) => _open(
    info.htmlUrl.isEmpty ? AppConstants.githubReleasesPage : info.htmlUrl,
  );

  Future<bool> openDownloadedFile(String path) => _open(path);

  /// Abre la carpeta de descargas en el explorador (Windows).
  Future<bool> openDownloadsFolder() async {
    try {
      final Directory dir = await getTemporaryDirectory();
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
