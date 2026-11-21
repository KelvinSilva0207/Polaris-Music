# Firma de release de Polaris Music (Android)

## Por qué fallaban las actualizaciones

Los APK publicados se firmaban con el keystore `debug` de la máquina que
compilaba. Ese keystore es distinto en cada PC y en cada runner de GitHub, por
lo que Android rechazaba instalar una versión nueva encima de la anterior con
`INSTALL_FAILED_UPDATE_INCOMPATIBLE` (el error de "conflicto de paquete").

Además, `versionCode` era el número de build de `pubspec.yaml` (`7`), lo que
no garantizaba crecimiento al cambiar de versión semántica.

## Clave persistente (una sola vez)

En Windows, desde la raíz del repo:

```powershell
powershell -ExecutionPolicy Bypass -File android\generate_release_keystore.ps1 -PrintSecrets
```

El script:

- crea `%LOCALAPPDATA%\Polaris Music\signing\polaris-release.jks` (fuera del
  repo, **no se versiona**);
- genera passwords aleatorios y escribe `android/key.properties` (también
  ignorado por Git);
- con `-PrintSecrets` imprime los valores para los secrets de GitHub.

`build.gradle.kts` lee la firma en este orden:

1. variables de entorno `POLARIS_KEYSTORE_PATH`,
   `POLARIS_KEYSTORE_PASSWORD`, `POLARIS_KEY_ALIAS`, `POLARIS_KEY_PASSWORD`;
2. `android/key.properties`.

Si no hay ninguna configuración, la build de **debug local** sigue usando la
clave debug, pero `flutter build apk --release` avisa. CI exige firma real
mediante `POLARIS_REQUIRE_RELEASE_SIGNING=true`.

## Secrets del workflow

Configura en `Settings > Secrets and variables > Actions`:

| Secret | Valor |
| --- | --- |
| `POLARIS_KEYSTORE_BASE64` | Base64 del `.jks` |
| `POLARIS_KEYSTORE_PASSWORD` | Password del store |
| `POLARIS_KEY_ALIAS` | `polaris_release` (o el alias elegido) |
| `POLARIS_KEY_PASSWORD` | Password de la clave |

El job `build-android` decodifica el keystore en `$RUNNER_TEMP` y lo pasa a
Gradle. La clave nunca se sube al artefacto ni al repo.

> **Importante:** la primera versión firmada con esta clave no se puede
> instalar encima de un APK anterior firmado con la clave debug. El usuario
> debe desinstalar una sola vez. A partir de ahí, todas las actualizaciones
> se instalan encima conservando datos y ajustes.

## VersionCode incremental

`android/app/build.gradle.kts` calcula:

```
versionCode = major * 10_000_000 + minor * 100_000 + patch * 1_000 + build
```

Para `version: 1.0.8+9` el valor es `10_008_009`, mayor que el anterior
`10_007_008`.
Cada subida de `major`, `minor`, `patch` o `build` aumenta el código. El
número de build debe estar entre `0` y `999`.

Al publicar, cambia `version` en `pubspec.yaml` (por ejemplo `1.0.8+1`). El
instalador de Windows toma la parte semántica automáticamente.

## Verificación

```powershell
flutter build apk --release
```

Para confirmar la firma:

```powershell
keytool -printcert -jarfile build\app\outputs\flutter-apk\app-release.apk
```
