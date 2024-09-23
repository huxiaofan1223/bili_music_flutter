[Setup]  
AppName=test_flutter  
AppVersion=1.0  
DefaultDirName={pf}\test_flutter  
DefaultGroupName=test_flutter 
OutputDir=C:\MyAppInstaller  
OutputBaseFilename=MyAppInstaller  
Compression=lzma  
SolidCompression=yes  
PrivilegesRequired=none
  
[Files]  
Source: "C:\Users\admin\Desktop\test_flutter\build\windows\x64\runner\Release\test_flutter.exe"; DestDir: "{app}"; Flags: ignoreversion  
Source: "C:\Users\admin\Desktop\test_flutter\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs  
  
[Icons]  
Name: "{group}\test_flutter"; Filename: "{app}\test_flutter.exe"