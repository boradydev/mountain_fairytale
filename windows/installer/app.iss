#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef BuildNumber
  #error BuildNumber is required
#endif
#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif

[Setup]
AppId={{8AD2131E-386D-4BEA-9E39-0CBA8E438F0C}
AppName=Mountain Fairytale
AppVersion={#AppVersion}
AppPublisher=boradydev
AppPublisherURL=https://github.com/boradydev/mountain_fairytale
VersionInfoVersion={#AppVersion}.{#BuildNumber}
DefaultDirName={localappdata}\Programs\MountainFairytale
DefaultGroupName=Mountain Fairytale
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
OutputDir={#OutputDir}
OutputBaseFilename=MountainFairytale-{#AppVersion}-windows-x64-Setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=no
RestartApplications=no
SetupMutex=MountainFairytaleSetup
UninstallDisplayIcon={app}\mountain_fairytale.exe
UninstallDisplayName=Mountain Fairytale
ChangesAssociations=no

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\Mountain Fairytale"; Filename: "{app}\mountain_fairytale.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\Mountain Fairytale"; Filename: "{app}\mountain_fairytale.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\mountain_fairytale.exe"; Description: "Запустить Mountain Fairytale"; Flags: nowait postinstall skipifsilent
Filename: "{app}\mountain_fairytale.exe"; Flags: nowait skipifnotsilent; Check: IsUpdate

[Code]
function IsUpdate(): Boolean;
begin
  Result := ExpandConstant('{param:UPDATE|0}') = '1';
end;

function InitializeSetup(): Boolean;
var
  InstalledVersion: String;
  Attempts: Integer;
  InstalledPacked, CandidatePacked: Int64;
begin
  Result := True;
  { WinSparkle starts Setup immediately before requesting app shutdown.
    Wait briefly, but never kill an app or discard unsaved documents. }
  Attempts := 0;
  while CheckForMutexes('Local\MountainFairytaleRunning') and (Attempts < 100) do
  begin
    Sleep(100);
    Attempts := Attempts + 1;
  end;
  if CheckForMutexes('Local\MountainFairytaleRunning') then
  begin
    SuppressibleMsgBox('Закройте Mountain Fairytale перед установкой обновления.', mbError, MB_OK, IDOK);
    Result := False;
    Exit;
  end;
  if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{8AD2131E-386D-4BEA-9E39-0CBA8E438F0C}_is1', 'DisplayVersion', InstalledVersion) then
  begin
    if StrToVersion(InstalledVersion, InstalledPacked) and StrToVersion('{#AppVersion}', CandidatePacked) and
       (ComparePackedVersion(InstalledPacked, CandidatePacked) > 0) then
    begin
      SuppressibleMsgBox('Установлена более новая версия приложения. Установка отменена.', mbError, MB_OK, IDOK);
      Result := False;
    end;
  end;
end;
