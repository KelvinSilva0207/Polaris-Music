; -----------------------------------------------------------------------------
;  Polaris Music - instalador oficial para Windows
;
;  Compilar con:  installer\build_installer.ps1
;  o directamente: ISCC.exe /DMyAppVersion=1.0.0 installer\polaris_music.iss
;
;  El instalador es por usuario por defecto (sin UAC), lo que permite que la
;  autoactualización desde la app se ejecute de forma silenciosa. Tambien puede
;  instalarse para todos los usuarios con /ALLUSERS o desde el dialogo inicial.
; -----------------------------------------------------------------------------

#define MyAppName "Polaris Music"
#define MyAppShortName "Polaris"
#define MyAppPublisher "Kelvin Silva"
#define MyAppURL "https://github.com/KelvinSilva0207/Polaris-Music"
#define MyAppExeName "polaris_music.exe"
#define MyAppId "{{3E8A9C42-5F1B-4D7A-B2E6-9C4F0A1D8B73}"
#define MyAppCopyright "Copyright (C) 2026 Kelvin Silva"

; La version se inyecta con la variable de entorno POLARIS_VERSION desde
; build_installer.ps1. Si se compila a mano, se usa el valor de respaldo.
#ifndef MyAppVersion
  #define MyAppVersion GetEnv("POLARIS_VERSION")
  #if MyAppVersion == ""
    #define MyAppVersion "1.0.0"
  #endif
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
VersionInfoVersion={#MyAppVersion}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} - Instalador
VersionInfoProductName={#MyAppName}
VersionInfoCopyright={#MyAppCopyright}

; Instalacion por usuario por defecto: {autopf} resuelve a
; %LOCALAPPDATA%\Programs con privilegios minimos y a Program Files con /ALLUSERS.
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
UsePreviousAppDir=yes
UsePreviousTasks=yes
AllowNoIcons=yes

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

OutputDir=Output
OutputBaseFilename=Polaris-Music-Setup-{#MyAppVersion}
SetupIconFile=..\assets\icons\polaris_music.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
WizardStyle=modern dark polar includetitlebar
WizardImageFile=assets\wizard.png
WizardSmallImageFile=assets\wizard_small.png
WizardImageStretch=yes
ShowLanguageDialog=no
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
CloseApplications=yes
RestartApplications=no
SetupLogging=no

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Messages]
spanish.WelcomeLabel2=Este asistente instalará [name/ver] en su equipo.%n%nPolaris Music es un reproductor de audio con temas dinámicos, ecualizador DSP de 10 bandas y biblioteca local.%n%nHaga clic en Siguiente para continuar.
spanish.FinishedLabel=La instalación de [name] ha finalizado.%n%nPolaris Music ya está listo para reproducir tu biblioteca.

[CustomMessages]
spanish.CreateDesktopIcon=Crear un acceso directo en el escritorio
spanish.LaunchAfterUpdate=Iniciar Polaris Music

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[InstallDelete]
; Limpia iconos de versiones anteriores: el proyecto usa un unico icono
; (assets\icons\polaris_music.ico) y estos archivos ya no se empaquetan.
Type: files; Name: "{app}\data\flutter_assets\assets\icons\app_icon.ico"
Type: files; Name: "{app}\data\flutter_assets\assets\icons\tray.ico"
Type: files; Name: "{app}\data\flutter_assets\assets\icons\polaris.png"

[Files]
; Build de Flutter para Windows (exe, DLLs y carpeta data).
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppName}"; Tasks: desktopicon

[Registry]
; Permite abrir la app desde Inicio > Ejecutar escribiendo "polaris_music".
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey

[Run]
; Instalacion normal: casilla "Iniciar Polaris Music" en la pagina final.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

; Autoactualizacion desde la app: /AUTOUPDATE + /SILENT. Al terminar se vuelve
; a abrir la app automaticamente, ya con la version nueva.
Filename: "{app}\{#MyAppExeName}"; Flags: nowait; Check: ShouldRelaunchAfterUpdate

[Code]
function CmdLineParamExists(const Value: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
  begin
    if CompareText(ParamStr(I), Value) = 0 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function ShouldRelaunchAfterUpdate(): Boolean;
begin
  Result := WizardSilent and CmdLineParamExists('/AUTOUPDATE');
end;
