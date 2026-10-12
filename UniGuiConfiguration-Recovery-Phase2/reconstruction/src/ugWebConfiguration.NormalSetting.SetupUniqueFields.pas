unit ugWebConfiguration.NormalSetting.SetupUniqueFields;


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
  TWebNormalSettingSetupUniqueFields = class(TWebCustBaseForm)
    cbField: TUniComboBox;
    pButton: TUniContainerPanel;
    btOk: TUniButton;
    gridMultiSelectFields: TUniDBGrid;
    pFilters: TUniHiddenPanel;
    UniContainerPanel1: TUniContainerPanel;
    UniLabel1: TUniLabel;
    cdsMultiSelectFields: TClientDataSet;
    dsMultiSelectFields: TDataSource;
    procedure btOkClick(Sender: TObject);
    procedure gridMultiSelectFieldsClearFilters(Sender: TObject);
    procedure gridMultiSelectFieldsColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);
  private
    FConfiguredValue: string;
    FRequireRecordField: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(AColumns: TClientDataSet; const AValue: string;
      ARequireRecordField: Boolean);
    property ConfiguredValue: string read FConfiguredValue;
  end;

implementation

{$R *.dfm}

procedure AddUniqueFieldDef(ADataSet: TClientDataSet; const AName: string;
  AType: TFieldType; ASize: Integer = 0);
var
  LDef: TFieldDef;
begin
  LDef := ADataSet.FieldDefs.AddFieldDef;
  LDef.Name := AName;
  LDef.DataType := AType;
  LDef.Size := ASize;
end;

function UniqueJSONValue(AJSON: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if not Assigned(AJSON) then Exit;
  LValue := AJSON.GetValue(AName);
  if Assigned(LValue) then Result := LValue.Value;
end;

constructor TWebNormalSettingSetupUniqueFields.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  cdsMultiSelectFields.Close;
  cdsMultiSelectFields.FieldDefs.Clear;
  AddUniqueFieldDef(cdsMultiSelectFields, 'fdSELECT', ftBoolean);
  AddUniqueFieldDef(cdsMultiSelectFields, 'fdRECNO', ftInteger);
  AddUniqueFieldDef(cdsMultiSelectFields, 'fdCOLUMN_NAME', ftWideString, 80);
  AddUniqueFieldDef(cdsMultiSelectFields, 'fdCAPTION', ftWideString, 255);
  AddUniqueFieldDef(cdsMultiSelectFields, 'fdObject_Type', ftWideString, 80);
  AddUniqueFieldDef(cdsMultiSelectFields, 'fdCOLUMN_TYPENAME', ftWideString, 80);
  AddUniqueFieldDef(cdsMultiSelectFields, 'fdCOLUMN_PRECISION', ftInteger);
  AddUniqueFieldDef(cdsMultiSelectFields, 'fdCOLUMN_SCAL', ftInteger);
  AddUniqueFieldDef(cdsMultiSelectFields, 'fdCOLUMN_LENGTH', ftInteger);
  cdsMultiSelectFields.CreateDataSet;
end;

procedure TWebNormalSettingSetupUniqueFields.Prepare(AColumns: TClientDataSet;
  const AValue: string; ARequireRecordField: Boolean);
var
  LBookmark: TBookmark;
  LJSONValue: TJSONValue;
  LJSON: TJSONObject;
  LName, LSelected: string;
begin
  FConfiguredValue := AValue;
  FRequireRecordField := ARequireRecordField;
  cbField.Visible := ARequireRecordField;
  cbField.Items.Clear;
  cdsMultiSelectFields.EmptyDataSet;

  LJSON := nil;
  LJSONValue := nil;
  if Trim(AValue) <> '' then
    LJSONValue := TJSONObject.ParseJSONValue(AValue);
  try
    if LJSONValue is TJSONObject then LJSON := TJSONObject(LJSONValue);
    cbField.Text := UniqueJSONValue(LJSON, 'cbField');
    LSelected := UniqueJSONValue(LJSON, 'cdsMultiSelectFields');
  finally
    LJSONValue.Free;
  end;

  if not Assigned(AColumns) or not AColumns.Active or AColumns.IsEmpty then Exit;
  LBookmark := AColumns.GetBookmark;
  AColumns.DisableControls;
  try
    AColumns.First;
    while not AColumns.Eof do
    begin
      if AColumns.FieldByName('fdSELECT').AsBoolean then
      begin
        LName := AColumns.FieldByName('fdCOLUMN_NAME').AsString;
        cbField.Items.Add(LName);
        cdsMultiSelectFields.Append;
        cdsMultiSelectFields.FieldByName('fdSELECT').AsBoolean :=
          Pos(';' + LName + ';', ';' + LSelected) > 0;
        cdsMultiSelectFields.FieldByName('fdRECNO').AsInteger :=
          AColumns.FieldByName('fdRECNO').AsInteger;
        cdsMultiSelectFields.FieldByName('fdCOLUMN_NAME').AsString := LName;
        cdsMultiSelectFields.FieldByName('fdCAPTION').AsString :=
          AColumns.FieldByName('fdCAPTION').AsString;
        cdsMultiSelectFields.FieldByName('fdObject_Type').AsString :=
          AColumns.FieldByName('fdOBJECT_TYPE').AsString;
        cdsMultiSelectFields.FieldByName('fdCOLUMN_TYPENAME').AsString :=
          AColumns.FieldByName('fdCOLUMN_TYPENAME').AsString;
        cdsMultiSelectFields.FieldByName('fdCOLUMN_PRECISION').AsInteger :=
          AColumns.FieldByName('fdCOLUMN_PRECISION').AsInteger;
        cdsMultiSelectFields.FieldByName('fdCOLUMN_SCAL').AsInteger :=
          AColumns.FieldByName('fdCOLUMN_SCAL').AsInteger;
        cdsMultiSelectFields.FieldByName('fdCOLUMN_LENGTH').AsInteger :=
          AColumns.FieldByName('fdCOLUMN_LENGTH').AsInteger;
        cdsMultiSelectFields.Post;
      end;
      AColumns.Next;
    end;
  finally
    if AColumns.BookmarkValid(LBookmark) then AColumns.GotoBookmark(LBookmark);
    AColumns.FreeBookmark(LBookmark);
    AColumns.EnableControls;
  end;
  cdsMultiSelectFields.First;
end;

procedure TWebNormalSettingSetupUniqueFields.btOkClick(Sender: TObject);
var
  LJSON: TJSONObject;
  LSelected: string;
begin
  if FRequireRecordField and (Trim(cbField.Text) = '') then
    raise Exception.Create('请设置记录编号字段。');
  if cdsMultiSelectFields.State in dsEditModes then
    cdsMultiSelectFields.Post;
  LSelected := '';
  cdsMultiSelectFields.First;
  while not cdsMultiSelectFields.Eof do
  begin
    if cdsMultiSelectFields.FieldByName('fdSELECT').AsBoolean then
      LSelected := LSelected +
        cdsMultiSelectFields.FieldByName('fdCOLUMN_NAME').AsString + ';';
    cdsMultiSelectFields.Next;
  end;
  if LSelected = '' then
    raise Exception.Create('请至少选择一个组合唯一字段。');

  LJSON := TJSONObject.Create;
  try
    if Trim(cbField.Text) <> '' then
      LJSON.AddPair('cbField', cbField.Text);
    LJSON.AddPair('cdsMultiSelectFields', LSelected);
    FConfiguredValue := LJSON.Format(2);
  finally
    LJSON.Free;
  end;
  ModalResult := mrOk;
end;

procedure TWebNormalSettingSetupUniqueFields.gridMultiSelectFieldsClearFilters(Sender: TObject);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebNormalSettingSetupUniqueFields.gridMultiSelectFieldsColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

end.
