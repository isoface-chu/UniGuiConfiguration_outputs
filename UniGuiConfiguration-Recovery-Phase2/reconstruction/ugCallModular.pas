unit ugCallModular;

{ High-confidence reconstruction based on:
  - the host's UniGuiModularDLL/ugCallModular.pas contract;
  - the DLL's WebConfigurationModule strings and form resource;
  - its exported GetDllComponent entry point.
  The original implementation may differ in exception wording/details. }

interface

uses
  System.Classes;

function CallModular(AName: string; AOwner: TComponent): TComponent;

implementation

uses
  System.SysUtils,
  uniGUIApplication,
  ugWebConfigurationModule;

function CallModular(AName: string; AOwner: TComponent): TComponent;
begin
  if SameText(AName, 'WebConfigurationModule') then
    Exit(UniApplication.UniMainModule.GetFormInstance(TWebConfigurationModule));

  raise Exception.Create('创建模块"' + AName + '"失败。');
end;

end.
