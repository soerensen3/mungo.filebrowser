{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit mungo.filebrowser.main;

{$warn 5023 off : no warning about unused units}
interface

uses
  mungo.filebrowser, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('mungo.filebrowser', @Register);
end.
