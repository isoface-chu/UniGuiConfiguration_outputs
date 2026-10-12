unit ugWebConfiguration.DetailedStructure;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebConfigurationBase, ugWebConfiguration.DataStructure;

type
  TWebDetailedStructure = class(TWebDataStructure)
  public
    function CheckConfigure: Boolean; override;
    procedure LoadConfigure(AJSON: TJSONObject); override;
    procedure SaveConfigure(AJSON: TJSONObject); override;
    procedure CurrentAction(APageActionType: TPageActionType); override;
  end;

implementation

{$R *.dfm}

function TWebDetailedStructure.CheckConfigure: Boolean;
begin
  Result := inherited CheckConfigure;
end;

procedure TWebDetailedStructure.LoadConfigure(AJSON: TJSONObject);
begin
  inherited LoadConfigure(AJSON);
end;

procedure TWebDetailedStructure.SaveConfigure(AJSON: TJSONObject);
begin
  inherited SaveConfigure(AJSON);
end;

procedure TWebDetailedStructure.CurrentAction(APageActionType: TPageActionType);
begin
  inherited CurrentAction(APageActionType);
end;

end.
