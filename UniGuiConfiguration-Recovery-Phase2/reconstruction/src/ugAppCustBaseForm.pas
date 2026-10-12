{
                                                             ███████████    ██
                                                     ████████ █         ███████████
                                                 ██████                         █████
                                              ████                                  █████
                                           ███                                        █████
                                         ███      ███                                   ██████ ██
                                       ███         ██           █            ███          █████     █ ████████
                                      ██                    ████████         ████           ███               █████
                                    ██                                                       ███                   ██████████████
                                    █                                                         ███                          ██████
                                   █                                                           ███                           ███
                                   █                                                            ██                           ██
                                  █                                                             ███                           ██
                                 █                                                              ██                            ██
                                  █                                                            ███                             █
                                   █                                                           ███                             ██
                                    █                                                          ██                              ██
                          ████████████                                                        ███                              ██
                       ███████                                                              ███                                █
                   ████       ██                                                           ███                                ██
                 ████        ██                                                            ███                                ██
               ███          █                                                            ███                                 ██
              ██         ████                                                           ██                                  ██
             ████████████                                                              ██                                 ███
            █                                                                        █████                            ████
           ██                                          █████████████                ██   ███                       █████
           ██                                          ███                         ██      ████                ██████
           ██                                            ████                    ███          ███████████████  ██
         ███                                                █████              ████                          ███
       ██                                                        █           ████
    ███                                                                    ████
 ████                                                                    ████
█████████████████                                                    ██████
                  ██████                                         ██████
                       ██████████                           █████
                        ██████                      █████████
                       █████████ ████████████████████
                            █ ██████
}
unit ugAppCustBaseForm;

interface

uses
  ugPublicObjectManagement,
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, uniGUITypes, uniGUIAbstractClasses,
  uniGUIClasses, uniGUImClasses, uniGUIForm, uniGUImForm, uniGUImJSForm,
  Data.DB, Datasnap.DBClient;

type
  {DLL.APP基类窗体}
  TAppCustBaseForm = class(TUnimForm)
  private
    { Private declarations }
    FUGMM : IUGMM;
    FDataNodeName : String;
    Procedure SetDataNodeName(Value:String);
  public
    { Public declarations }
    Property UGMM : IUGMM Read FUGMM;
    Property DataNodeName : String Read FDataNodeName Write SetDataNodeName;
    constructor Create(AOwner: TComponent);override;//创建
    destructor Destroy; override;//释放
  end;

Function  IIF(ACondition: Boolean; _True, _False: Variant): Variant;

implementation
{$R *.dfm}
uses
  uniGUIApplication;

{$region 'Function  IIF(ACondition: Boolean; _True, _False: Variant): Variant;'}
Function  IIF(ACondition: Boolean; _True, _False: Variant): Variant;
begin
  if ACondition then
    result := _True
  else
    result := _False;
end;
{$ENDREGION}

{TWebCustBaseForm}
Procedure TAppCustBaseForm.SetDataNodeName(Value:String);
var
  c : TClientDataSet;
  k : Integer;
begin
  FDataNodeName := Value;
  for k := 0 to ComponentCount - 1 do
  if Components[k] is TClientDataSet then
  TClientDataSet(Components[k]).DataNodeName := FDataNodeName;
end;

constructor TAppCustBaseForm.Create(AOwner: TComponent);//创建
begin
  inherited Create(AOwner);
  FUGMM := GetUGMM;
  //界面多语言自动翻译
  FUGMM.LC(Self);
end;
destructor TAppCustBaseForm.Destroy;//释放
var
  c : TClientDataSet;
  k : Integer;
begin
  for k := 0 to ComponentCount - 1 do
  if Components[k] is TClientDataSet then
  TClientDataSet(Components[k]).FreeHelperObject;
  inherited Destroy;
end;
end.
