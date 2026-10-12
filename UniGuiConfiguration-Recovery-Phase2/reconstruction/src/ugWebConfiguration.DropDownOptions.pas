unit ugWebConfiguration.DropDownOptions;


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
  TWebDropDownOptions = class(TWebCustBaseForm)
    edCaption: TUniEdit;
    edObjectType: TUniEdit;
    UniContainerPanel1: TUniContainerPanel;
    edOptionFields: TUniEdit;
    edOptionCaption: TUniEdit;
    edOptionValue: TUniEdit;
    mmText: TUniMemo;
    edOptionDisplay: TUniEdit;
    edOptionLookupFields: TUniEdit;
    pGridPageSetting: TUniContainerPanel;
    cbGridPageSetting: TUniComboBox;
    sePageSize: TUniSpinEdit;
    btOk: TUniButton;
    pDropDownType: TUniContainerPanel;
    cbDropDownType: TUniComboBox;
    cbDynamicLoading: TUniCheckBox;
    seMaxRecordCount: TUniSpinEdit;
    procedure edOptionFieldsTriggerEvent(Sender: TObject; AButtonId: Integer);
    procedure cbDropDownTypeChange(Sender: TObject);
    procedure btOkClick(Sender: TObject);
    procedure cbDynamicLoadingChange(Sender: TObject);
  private
    FConfiguredValue: string;
    procedure UpdateControls;
  public
    procedure Prepare(const AObjectType, ACaption, AValue: string);
    property ConfiguredValue: string read FConfiguredValue;
  end;

implementation

{$R *.dfm}

function DropDownJSONValue(AJSON: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if not Assigned(AJSON) then Exit;
  LValue := AJSON.GetValue(AName);
  if Assigned(LValue) then Result := LValue.Value;
end;

procedure TWebDropDownOptions.Prepare(const AObjectType, ACaption,
  AValue: string);
var
  LJSONValue: TJSONValue;
  LJSON: TJSONObject;
  LChecked: string;
begin
  FConfiguredValue := AValue;
  edObjectType.Text := AObjectType;
  edCaption.Text := ACaption;
  LJSONValue := nil;
  LJSON := nil;
  if Trim(AValue) <> '' then LJSONValue := TJSONObject.ParseJSONValue(AValue);
  try
    if LJSONValue is TJSONObject then LJSON := TJSONObject(LJSONValue);
    cbDropDownType.Text := DropDownJSONValue(LJSON, 'cbDropDownType');
    mmText.Lines.Text := DropDownJSONValue(LJSON, 'mmText');
    LChecked := DropDownJSONValue(LJSON, 'cbDynamicLoading');
    cbDynamicLoading.Checked := SameText(LChecked, '-1') or
      SameText(LChecked, '1') or SameText(LChecked, 'True');
    seMaxRecordCount.Value := StrToIntDef(
      DropDownJSONValue(LJSON, 'seMaxRecordCount'), 100);
    cbGridPageSetting.Text := DropDownJSONValue(LJSON, 'cbGridPageSetting');
    if cbGridPageSetting.Text = '' then cbGridPageSetting.Text := 'Close';
    sePageSize.Value := StrToIntDef(DropDownJSONValue(LJSON, 'sePageSize'), 100);
    edOptionCaption.Text := DropDownJSONValue(LJSON, 'edOptionCaption');
    edOptionFields.Text := DropDownJSONValue(LJSON, 'edOptionFields');
    edOptionLookupFields.Text := DropDownJSONValue(LJSON, 'edOptionLookupFields');
    edOptionDisplay.Text := DropDownJSONValue(LJSON, 'edOptionDisplay');
    edOptionValue.Text := DropDownJSONValue(LJSON, 'edOptionValue');
  finally
    LJSONValue.Free;
  end;
  UpdateControls;
end;

procedure TWebDropDownOptions.edOptionFieldsTriggerEvent(Sender: TObject; AButtonId: Integer);
begin
  edOptionFields.SetFocus;
  edOptionFields.EmptyText :=
    'FieldName1@Caption1;FieldName2@Caption2;...FieldName_n@Caption_n';
end;

procedure TWebDropDownOptions.cbDropDownTypeChange(Sender: TObject);
begin
  UpdateControls;
end;

procedure TWebDropDownOptions.btOkClick(Sender: TObject);
var
  LJSON: TJSONObject;
begin
  if Trim(cbDropDownType.Text) = '' then
    raise Exception.Create('请选择选项类型。');
  if Trim(mmText.Lines.Text) = '' then
    raise Exception.Create('请输入选项内容。');
  if SameText(cbDropDownType.Text, 'SqlQuery') and
    (Trim(edOptionFields.Text) = '') then
    raise Exception.Create('请输入展示字段。');
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('cbDropDownType', cbDropDownType.Text);
    LJSON.AddPair('mmText', mmText.Lines.Text);
    if cbDynamicLoading.Checked then
      LJSON.AddPair('cbDynamicLoading', '-1')
    else
      LJSON.AddPair('cbDynamicLoading', '0');
    LJSON.AddPair('seMaxRecordCount', IntToStr(Trunc(seMaxRecordCount.Value)));
    LJSON.AddPair('cbGridPageSetting', cbGridPageSetting.Text);
    LJSON.AddPair('sePageSize', IntToStr(Trunc(sePageSize.Value)));
    LJSON.AddPair('edOptionCaption', edOptionCaption.Text);
    LJSON.AddPair('edOptionFields', edOptionFields.Text);
    LJSON.AddPair('edOptionLookupFields', edOptionLookupFields.Text);
    LJSON.AddPair('edOptionDisplay', edOptionDisplay.Text);
    LJSON.AddPair('edOptionValue', edOptionValue.Text);
    FConfiguredValue := LJSON.Format(2);
  finally
    LJSON.Free;
  end;
  ModalResult := mrOk;
end;

procedure TWebDropDownOptions.cbDynamicLoadingChange(Sender: TObject);
begin
  UpdateControls;
end;

procedure TWebDropDownOptions.UpdateControls;
var
  LQuery: Boolean;
begin
  LQuery := SameText(cbDropDownType.Text, 'SqlQuery');
  cbDynamicLoading.Enabled := LQuery;
  seMaxRecordCount.Enabled := LQuery and cbDynamicLoading.Checked;
  pGridPageSetting.Visible := LQuery;
  edOptionFields.Visible := LQuery;
  edOptionCaption.Visible := LQuery;
  edOptionLookupFields.Visible := LQuery;
  edOptionDisplay.Visible := LQuery;
  edOptionValue.Visible := LQuery;
end;

end.
