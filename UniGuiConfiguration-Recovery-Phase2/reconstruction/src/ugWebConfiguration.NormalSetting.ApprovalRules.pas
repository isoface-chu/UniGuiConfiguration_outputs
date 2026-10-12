unit ugWebConfiguration.NormalSetting.ApprovalRules;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebCustBaseForm;

type
  TWebNormalSettingApprovalRules = class(TWebCustBaseForm)
    cbDataStatus: TUniComboBox;
    cbCorresponding: TUniComboBox;
    cbCheckType: TUniComboBox;
    cbAuditDepartment: TUniComboBox;
    UniContainerPanel1: TUniContainerPanel;
    cbAuditUser: TUniComboBox;
    cbAuditTime: TUniComboBox;
    cbRepulseDepartment: TUniComboBox;
    cbRepulseUser: TUniComboBox;
    cbRepulseTime: TUniComboBox;
    cbRepulseRemark: TUniComboBox;
    btOK: TUniButton;
    procedure btOKClick(Sender: TObject);
  private
    FConfiguredValue: string;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(AColumns: TClientDataSet; const AValue: string);
    property ConfiguredValue: string read FConfiguredValue;
  end;

implementation

{$R *.dfm}

function ApprovalJSONValue(AJSON: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if not Assigned(AJSON) then Exit;
  LValue := AJSON.GetValue(AName);
  if Assigned(LValue) then Result := LValue.Value;
end;

constructor TWebNormalSettingApprovalRules.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  cbCheckType.Items.Clear;
  cbCheckType.Items.Add('0');
  cbCheckType.Items.Add('1');
  cbCheckType.Items.Add('2');
end;

procedure TWebNormalSettingApprovalRules.Prepare(AColumns: TClientDataSet;
  const AValue: string);
var
  LBookmark: TBookmark;
  LJSONValue: TJSONValue;
  LJSON: TJSONObject;
  LName: string;
  LCombos: array[0..8] of TUniComboBox;
  I: Integer;
begin
  FConfiguredValue := AValue;
  LCombos[0] := cbDataStatus;
  LCombos[1] := cbCorresponding;
  LCombos[2] := cbAuditDepartment;
  LCombos[3] := cbAuditUser;
  LCombos[4] := cbAuditTime;
  LCombos[5] := cbRepulseDepartment;
  LCombos[6] := cbRepulseUser;
  LCombos[7] := cbRepulseTime;
  LCombos[8] := cbRepulseRemark;
  for I := Low(LCombos) to High(LCombos) do
    LCombos[I].Items.Clear;

  if Assigned(AColumns) and AColumns.Active and not AColumns.IsEmpty then
  begin
    LBookmark := AColumns.GetBookmark;
    AColumns.DisableControls;
    try
      AColumns.First;
      while not AColumns.Eof do
      begin
        if AColumns.FieldByName('fdSELECT').AsBoolean then
        begin
          LName := AColumns.FieldByName('fdCOLUMN_NAME').AsString;
          for I := Low(LCombos) to High(LCombos) do
            LCombos[I].Items.Add(LName);
        end;
        AColumns.Next;
      end;
    finally
      if AColumns.BookmarkValid(LBookmark) then AColumns.GotoBookmark(LBookmark);
      AColumns.FreeBookmark(LBookmark);
      AColumns.EnableControls;
    end;
  end;

  LJSON := nil;
  LJSONValue := nil;
  if Trim(AValue) <> '' then LJSONValue := TJSONObject.ParseJSONValue(AValue);
  try
    if LJSONValue is TJSONObject then LJSON := TJSONObject(LJSONValue);
    cbDataStatus.Text := ApprovalJSONValue(LJSON, 'cbDataStatus');
    cbCorresponding.Text := ApprovalJSONValue(LJSON, 'cbCorresponding');
    cbCheckType.Text := ApprovalJSONValue(LJSON, 'cbCheckType');
    cbAuditDepartment.Text := ApprovalJSONValue(LJSON, 'cbAuditDepartment');
    cbAuditUser.Text := ApprovalJSONValue(LJSON, 'cbAuditUser');
    cbAuditTime.Text := ApprovalJSONValue(LJSON, 'cbAuditTime');
    cbRepulseDepartment.Text := ApprovalJSONValue(LJSON, 'cbRepulseDepartment');
    cbRepulseUser.Text := ApprovalJSONValue(LJSON, 'cbRepulseUser');
    cbRepulseTime.Text := ApprovalJSONValue(LJSON, 'cbRepulseTime');
    cbRepulseRemark.Text := ApprovalJSONValue(LJSON, 'cbRepulseRemark');
  finally
    LJSONValue.Free;
  end;
end;

procedure TWebNormalSettingApprovalRules.btOKClick(Sender: TObject);
var
  LJSON: TJSONObject;
begin
  if Trim(cbDataStatus.Text) = '' then
    raise Exception.Create('请设置数据状态字段。');
  if Trim(cbCorresponding.Text) = '' then
    raise Exception.Create('请设置对应字段。');
  if Trim(cbCheckType.Text) = '' then
    raise Exception.Create('请设置校验类型。');
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('cbDataStatus', cbDataStatus.Text);
    LJSON.AddPair('cbCorresponding', cbCorresponding.Text);
    LJSON.AddPair('cbCheckType', cbCheckType.Text);
    LJSON.AddPair('cbAuditDepartment', cbAuditDepartment.Text);
    LJSON.AddPair('cbAuditUser', cbAuditUser.Text);
    LJSON.AddPair('cbAuditTime', cbAuditTime.Text);
    LJSON.AddPair('cbRepulseDepartment', cbRepulseDepartment.Text);
    LJSON.AddPair('cbRepulseUser', cbRepulseUser.Text);
    LJSON.AddPair('cbRepulseTime', cbRepulseTime.Text);
    LJSON.AddPair('cbRepulseRemark', cbRepulseRemark.Text);
    FConfiguredValue := LJSON.Format(2);
  finally
    LJSON.Free;
  end;
  ModalResult := mrOk;
end;

end.
