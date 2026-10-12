unit ugRegDllControl;


{ Register the configuration wizard with the host's generic dialog-property
  bridge. The host owns the design inspector and calls AddDllControl after
  passing its TGlobalVariable instance to this DLL. }

interface

procedure AddDllControl;
procedure DelDllControl;

implementation

uses
  System.Classes,
  System.TypInfo,
  ugPublicObjectManagement,
  ugCallModular,
  ugWebConfigurationModule;

const
  CWebRunFrameClassName = 'TUgWebRunFrame';
  CConfigStreamPropertyName = 'ConfigStream';

procedure OpenWebRunFrameConfigStream(AObject: TObject);
var
  LWizard: TComponent;
begin
  if not (AObject is TComponent) then
    Exit;

  LWizard := ugCallModular.CallModular('WebConfigurationModule',
    TComponent(AObject));
  if LWizard is TWebConfigurationModule then
    TWebConfigurationModule(LWizard).ShowModal;
end;

procedure AddWebRunFrameConfigStreamProperty;
var
  LWebRunFrameClass: TPersistentClass;
begin
  { TUgWebRunFrame belongs to the host and is deliberately resolved through
    Delphi's class registry. Keeping it out of this DLL's uses list avoids a
    second static copy of the large host run-frame unit. }
  LWebRunFrameClass := GetClass(CWebRunFrameClassName);
  if not Assigned(LWebRunFrameClass) then
    Exit;

  CustomDialogPropertys.RegisterDialogProperty(
    TypeInfo(TUgConfigurationStream),
    LWebRunFrameClass,
    CConfigStreamPropertyName,
    OpenWebRunFrameConfigStream);
end;

procedure AddDllControl;
begin
  AddWebRunFrameConfigStreamProperty;
end;

procedure DelDllControl;
var
  LIndex: Integer;
  LWebRunFrameClass: TPersistentClass;
begin
  LWebRunFrameClass := GetClass(CWebRunFrameClassName);
  if not Assigned(LWebRunFrameClass) then
    Exit;

  LIndex := CustomDialogPropertys.IndexOfClass(
    TypeInfo(TUgConfigurationStream),
    LWebRunFrameClass,
    CConfigStreamPropertyName);
  if LIndex >= 0 then
    CustomDialogPropertys.Items[LIndex].Free;
end;

end.
