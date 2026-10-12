unit ugWebConfiguration.DataNodeName;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebConfigurationBase;

type
  TWebDataNodeName = class(TWebConfigurationBase)
    pDataNode: TUniContainerPanel;
    cbDataNodeNames: TUniComboBox;
    cbAddCatalogName: TUniCheckBox;
    cbAddSchemaName: TUniCheckBox;
    procedure UniFrameAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);
  public
    constructor Create(AOwner: TComponent); override;
    function CheckConfigure: Boolean; override;
    procedure LoadConfigure(AJSON: TJSONObject); override;
    procedure SaveConfigure(AJSON: TJSONObject); override;
    procedure CurrentAction(APageActionType: TPageActionType); override;
  end;

implementation

{$R *.dfm}

constructor TWebDataNodeName.Create(AOwner: TComponent);
var
  LNames: string;
begin
  inherited Create(AOwner);
  if Assigned(UGMM) then
  begin
    LNames := UGMM.GetDriverIDByNodeNames;
    { The host returns TStringList.Text (one node per CRLF).  Normalize the
      legacy semicolon form as well, then let TStrings parse the lines. }
    LNames := StringReplace(LNames, ';', sLineBreak, [rfReplaceAll]);
    cbDataNodeNames.Items.Text := LNames;
  end;
end;

procedure TWebDataNodeName.UniFrameAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

function TWebDataNodeName.CheckConfigure: Boolean;
begin
  Result := Trim(cbDataNodeNames.Text) <> '';
end;

procedure TWebDataNodeName.LoadConfigure(AJSON: TJSONObject);
var
  LValue: TJSONValue;
begin
  LValue := AJSON.GetValue('TWebDataNodeName');
  if Assigned(LValue) and not (LValue is TJSONNull) then
    cbDataNodeNames.Text := LValue.Value;
  LValue := AJSON.GetValue('TWebDataNodeNamecbAddCatalogName');
  cbAddCatalogName.Checked := Assigned(LValue) and (LValue.Value = '1');
  LValue := AJSON.GetValue('TWebDataNodeNamecbAddSchemaName');
  cbAddSchemaName.Checked := Assigned(LValue) and (LValue.Value = '1');
end;

procedure TWebDataNodeName.SaveConfigure(AJSON: TJSONObject);
  procedure PutString(const AName, AValue: string);
  var
    LPair: TJSONPair;
  begin
    LPair := AJSON.RemovePair(AName);
    LPair.Free;
    AJSON.AddPair(AName, AValue);
  end;
begin
  PutString('TWebDataNodeName', cbDataNodeNames.Text);
  PutString('TWebDataNodeNamecbAddCatalogName', IntToStr(Ord(cbAddCatalogName.Checked)));
  PutString('TWebDataNodeNamecbAddSchemaName', IntToStr(Ord(cbAddSchemaName.Checked)));
end;

procedure TWebDataNodeName.CurrentAction(APageActionType: TPageActionType);
begin
  inherited CurrentAction(APageActionType);
end;

end.
