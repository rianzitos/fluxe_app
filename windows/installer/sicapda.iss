; Instalador do SICAPDA para Windows (Inno Setup 6).
; É gerado pelo GitHub Actions (veja tool/empacotar_windows.ps1) a partir de build\windows\x64\runner\Release.
;
; Uso manual (depois de "flutter build windows --release"):
;   ISCC.exe /DAppVersion=1.0.0 windows\installer\sicapda.iss
; O instalador final fica em dist\SICAPDA-Setup.exe

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef Origem
  #define Origem "..\..\build\windows\x64\runner\Release"
#endif
#ifndef Saida
  #define Saida "..\..\dist"
#endif

#define NomeApp "SICAPDA"
#define Exe "SICAPDA.exe"

[Setup]
; Identificador fixo: é ele que faz um instalador novo atualizar a versão já instalada (não mude).
AppId={{CB41ADE8-52C1-4F4F-904A-F98CEE68F9BE}
AppName={#NomeApp}
AppVersion={#AppVersion}
AppVerName={#NomeApp} {#AppVersion}
AppPublisher=Fluxe
AppPublisherURL=https://fluxeteam.com.br
AppSupportURL=https://fluxeteam.com.br
AppUpdatesURL=https://fluxeteam.com.br/sicapda
DefaultDirName={autopf}\{#NomeApp}
DefaultGroupName={#NomeApp}
DisableProgramGroupPage=yes
; Instala só para o usuário atual (não pede senha de administrador); quem quiser pode escolher "para todos".
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
UninstallDisplayName={#NomeApp}
UninstallDisplayIcon={app}\{#Exe}
SetupIconFile=..\runner\resources\app_icon.ico
WizardStyle=modern
WizardImageFile=wizard.bmp
WizardSmallImageFile=wizard_small.bmp
Compression=lzma2/max
SolidCompression=yes
OutputDir={#Saida}
OutputBaseFilename=SICAPDA-Setup

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#Origem}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#NomeApp}"; Filename: "{app}\{#Exe}"
Name: "{autodesktop}\{#NomeApp}"; Filename: "{app}\{#Exe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#Exe}"; Description: "{cm:LaunchProgram,{#NomeApp}}"; Flags: nowait postinstall skipifsilent
