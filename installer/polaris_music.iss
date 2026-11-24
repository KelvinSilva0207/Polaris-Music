; -----------------------------------------------------------------------------
;  Polaris Music - instalador oficial para Windows
;
;  Compilar con:  installer\build_installer.ps1
;  o directamente: ISCC.exe /DMyAppVersion=1.1.1 installer\polaris_music.iss
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
    #define MyAppVersion "1.1.1"
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
; Pagina de bienvenida con el logo y el ecualizador animado.
DisableWelcomePage=no
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
SetupIconFile=..\assets\icons\app.ico
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
; La app mantiene este mutex en main.dart, también cuando queda en la bandeja.
; Así el instalador puede liberar el ejecutable antes de reemplazarlo.
AppMutex=PolarisMusicMutex
CloseApplications=yes
RestartApplications=yes
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
; (assets\icons\app.ico) y estos archivos ya no se empaquetan.
Type: files; Name: "{app}\data\flutter_assets\assets\icons\app_icon.ico"
Type: files; Name: "{app}\data\flutter_assets\assets\icons\polaris_music.ico"
Type: files; Name: "{app}\data\flutter_assets\assets\icons\tray.ico"
Type: files; Name: "{app}\data\flutter_assets\assets\icons\polaris.png"

[Files]
; Build de Flutter para Windows (exe, DLLs y carpeta data).
; Solo se sobrescribe {app}: la base de datos Drift, temas, caché y ajustes
; viven en %LOCALAPPDATA%\Polaris Music y no se tocan nunca.
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

{ ---------------------------------------------------------------------------
  Espera a que la app libere el mutex antes de sobrescribir archivos.

  La autoactualización lanza primero un helper que espera a que el proceso de
  Polaris termine. Esta comprobación es una red de seguridad: si el helper falla
  o el proceso sigue vivo, esperamos hasta 30 s en modo /AUTOUPDATE antes de
  tocar EXE/DLLs. En una instalación interactiva no se aplica este espera:
  Inno Setup cierra la app mediante AppMutex + CloseApplications.
  --------------------------------------------------------------------------- }

const
  SYNCHRONIZE_ACCESS = $00100000;

function OpenMutexW(DesiredAccess: Longword; InheritHandle: Boolean; Name: String): Longword;
  external 'OpenMutexW@kernel32.dll stdcall';
function CloseHandle(Handle: Longword): Boolean;
  external 'CloseHandle@kernel32.dll stdcall';
function GetTickCount(): Longword;
  external 'GetTickCount@kernel32.dll stdcall';
procedure Sleep(Milliseconds: Longword);
  external 'Sleep@kernel32.dll stdcall';

function PolarisMutexHandle(): Longword;
begin
  Result := OpenMutexW(SYNCHRONIZE_ACCESS, False, 'PolarisMusicMutex');
end;

function WaitForPolarisExit(TimeoutMs: Longword): Boolean;
var
  Started, Handle: Longword;
begin
  Started := GetTickCount();
  repeat
    Handle := PolarisMutexHandle();
    if Handle = 0 then
    begin
      Result := True;
      Exit;
    end;
    CloseHandle(Handle);
    Sleep(200);
  until (GetTickCount() - Started) >= TimeoutMs;
  Result := PolarisMutexHandle() = 0;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if WizardSilent and CmdLineParamExists('/AUTOUPDATE') then
  begin
    if not WaitForPolarisExit(30000) then
      Result := 'Polaris Music sigue abierto. Ciérralo e inténtalo de nuevo.';
  end;
end;

{ ---------------------------------------------------------------------------
  Animacion de bienvenida
  ---------------------------------------------------------------------------
  Dibuja un ecualizador animado sobre la imagen lateral del asistente.
  Cada barra es un TPanel independiente; un temporizador de Windows actualiza
  su altura mientras la pagina de bienvenida (o la final) esta visible.
  No usa recursos externos y no interfiere con la instalacion silenciosa. }

const
  EqBarCount = 11;

var
  EqBars: array of TPanel;
  EqTimerId: Longword;
  EqTimerHwnd: Longword;
  EqCallback: Longword;
  EqPhase: Integer;
  EqHost: TWinControl;

function SetTimer(hWnd, nIDEvent, uElapse, lpTimerFunc: Longword): Longword;
  external 'SetTimer@user32.dll stdcall';

function KillTimer(hWnd, nIDEvent: Longword): Bool;
  external 'KillTimer@user32.dll stdcall';

{ TColor usa formato BGR: $00BBGGRR. }
function AccentBarColor(Index: Integer): TColor;
begin
  case Index mod 4 of
    0: Result := $00F65C8B; { violeta 139,92,246 }
    1: Result := $00FA8BA7; { lavanda 167,139,250 }
    2: Result := $00FDB5C4; { lila claro 196,181,253 }
    else Result := $00FF5C7C; { violeta intenso 124,92,255 }
  end;
end;

{ Patron determinista de alturas (porcentaje de la altura maxima). }
function EqBarUnit(Index: Integer): Integer;
begin
  case Index mod 12 of
    0: Result := 34;
    1: Result := 58;
    2: Result := 78;
    3: Result := 100;
    4: Result := 72;
    5: Result := 46;
    6: Result := 86;
    7: Result := 62;
    8: Result := 40;
    9: Result := 68;
    10: Result := 92;
    else Result := 52;
  end;
end;

procedure LayoutEqualizer;
var
  Img: TBitmapImage;
  I, BarWidth, Gap, TotalWidth, Left0, Baseline, MaxHeight, BarHeight: Integer;
begin
  if (WizardForm = nil) or (WizardForm.WizardBitmapImage = nil) then Exit;

  Img := WizardForm.WizardBitmapImage;
  if (Img.Width <= 0) or (Img.Height <= 0) then Exit;

  BarWidth := Img.Width div 36;
  if BarWidth < 4 then BarWidth := 4;
  Gap := BarWidth div 2;
  if Gap < 2 then Gap := 2;

  TotalWidth := EqBarCount * BarWidth + (EqBarCount - 1) * Gap;
  Left0 := Img.Left + (Img.Width - TotalWidth) div 2;
  Baseline := Img.Top + (Img.Height * 87) div 100;
  MaxHeight := (Img.Height * 7) div 100;
  if MaxHeight < 24 then MaxHeight := 24;

  for I := 0 to EqBarCount - 1 do
  begin
    BarHeight := (MaxHeight * EqBarUnit(EqPhase + I)) div 100;
    if BarHeight < 6 then BarHeight := 6;
    EqBars[I].Width := BarWidth;
    EqBars[I].Height := BarHeight;
    EqBars[I].Left := Left0 + I * (BarWidth + Gap);
    EqBars[I].Top := Baseline - BarHeight;
  end;
end;

procedure TickEqualizer(Arg1, Arg2, Arg3, Arg4: Longword);
var
  I: Integer;
  ShouldShow: Boolean;
begin
  if WizardForm = nil then Exit;
  if WizardForm.CurPageID = wpInstalling then Exit;

  ShouldShow := (WizardForm.CurPageID = wpWelcome) or
    (WizardForm.CurPageID = wpFinished);
  for I := 0 to EqBarCount - 1 do
    EqBars[I].Visible := ShouldShow;

  if not ShouldShow then Exit;

  Inc(EqPhase);
  LayoutEqualizer;
end;

procedure InitializeEqualizer;
var
  I: Integer;
  Img: TBitmapImage;
begin
  if WizardSilent then Exit;
  if (WizardForm = nil) or (WizardForm.WizardBitmapImage = nil) then Exit;

  { Los paneles deben ser hermanos de la imagen lateral: si se crean
    directamente sobre el formulario quedan detras de MainPanel y no se ven. }
  Img := WizardForm.WizardBitmapImage;
  EqHost := Img.Parent;
  if EqHost = nil then EqHost := WizardForm;

  SetArrayLength(EqBars, EqBarCount);
  for I := 0 to EqBarCount - 1 do
  begin
    EqBars[I] := TPanel.Create(EqHost);
    EqBars[I].Parent := EqHost;
    EqBars[I].Caption := '';
    EqBars[I].BevelOuter := bvNone;
    EqBars[I].BevelInner := bvNone;
    EqBars[I].ParentBackground := False;
    { El estilo personalizado del asistente ignora Color: sin elementos de
      estilo, cada barra conserva su tono violeta. }
    EqBars[I].StyleElements := [];
    EqBars[I].Color := AccentBarColor(I);
    EqBars[I].Visible := False;
    EqBars[I].BringToFront;
  end;

  LayoutEqualizer;
  EqCallback := CreateCallback(@TickEqualizer);
  EqTimerHwnd := WizardForm.Handle;
  EqTimerId := SetTimer(EqTimerHwnd, 0, 110, EqCallback);
end;

procedure InitializeWizard;
begin
  InitializeEqualizer;
end;

procedure DeinitializeSetup;
begin
  if EqTimerId <> 0 then
  begin
    KillTimer(EqTimerHwnd, EqTimerId);
    EqTimerId := 0;
  end;
end;
