[Setup]  
AppName=bili_music  
AppVersion=1.0  
DefaultDirName={pf}\bili_music  
DefaultGroupName=bili_music 
OutputDir=C:\MyAppInstaller  
OutputBaseFilename=MyAppInstaller  
Compression=lzma  
SolidCompression=yes  
PrivilegesRequired=none
  
[Files]  
Source: "C:\Users\admin\Desktop\bili_music\build\windows\x64\runner\Release\bili_music.exe"; DestDir: "{app}"; Flags: ignoreversion  
Source: "C:\Users\admin\Desktop\bili_music\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs  
  
[Icons]  
Name: "{group}\bili_music"; Filename: "{app}\bili_music.exe"