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
  System.SysUtils, System.TypInfo,
  uniGUIApplication,
  ugPublicObjectManagement,
  ugWebConfigurationModule;

function CallModular(AName: string; AOwner: TComponent): TComponent;
var
  LForm: TWebConfigurationModule;
  LPropInfo: PPropInfo;
  LStreamObject: TObject;
begin
  if SameText(AName, 'WebConfigurationModule') then
  begin
    LForm := TWebConfigurationModule(
      UniApplication.UniMainModule.GetFormInstance(TWebConfigurationModule));
    if Assigned(AOwner) then
    begin
      if SameText(AOwner.ClassName, 'TUgWebRunFrame') then
        LForm.AttachRunFrame(AOwner);
      LPropInfo := GetPropInfo(AOwner.ClassInfo, 'ConfigStream');
      if Assigned(LPropInfo) and (LPropInfo.PropType^.Kind = tkClass) then
      begin
        LStreamObject := GetObjectProp(AOwner, LPropInfo);
        if Assigned(LStreamObject) then
          LForm.AttachConfigurationStream(TUgConfigurationStream(LStreamObject));
      end;
    end;
    Exit(LForm);
  end;

  raise Exception.Create('创建模块"' + AName + '"失败。');
end;

end.
