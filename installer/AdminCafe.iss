#define MyAppName "AdminCafe"
#define MyAppExeName "AdminCafe.exe"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

#define BuildOutputDir "..\\build\\windows\\x64\\runner\\Release"
#define DistOutputDir "..\\dist"

[Setup]
AppId={{D06B3798-9A89-4592-95E1-54E52204D094}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=TechCafe
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir={#DistOutputDir}
OutputBaseFilename=AdminCafe-Setup-{#MyAppVersion}
SetupIconFile=..\\windows\\runner\\resources\\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildOutputDir}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb,*.lib,*.exp,*.ilk"

[Icons]
Name: "{group}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"
Name: "{autodesktop}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
