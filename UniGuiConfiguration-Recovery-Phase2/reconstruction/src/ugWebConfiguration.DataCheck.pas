unit ugWebConfiguration.DataCheck;


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
  TWebDataCheck = class(TWebCustBaseForm)
    btOk: TUniButton;
    cbTableName: TUniComboBox;
    cbField: TUniComboBox;
    procedure btOkClick(Sender: TObject);
    procedure cbTableNameChange(Sender: TObject);
  private
    FNodeName: string;
    FConfiguredValue: string;
    procedure LoadFields(const ATableName: string);
  public
    procedure Prepare(const ANodeName, AValue: string);
    property ConfiguredValue: string read FConfiguredValue;
  end;

implementation

{$R *.dfm}

function JSONStringValue(AJSON: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if not Assigned(AJSON) then Exit;
  LValue := AJSON.GetValue(AName);
  if Assigned(LValue) then Result := LValue.Value;
end;

procedure TWebDataCheck.LoadFields(const ATableName: string);
var
  LColumns: TClientDataSet;
begin
  cbField.Items.Clear;
  cbField.Text := '';
  if (Trim(ATableName) = '') or not Assigned(UGMM) then Exit;
  LColumns := TClientDataSet.Create(nil);
  try
    UGMM.GetNodeDataColumns(FNodeName, ATableName, LColumns);
    LColumns.First;
    while not LColumns.Eof do
    begin
      cbField.Items.Add(LColumns.FieldByName('COLUMN_NAME').AsString);
      LColumns.Next;
    end;
  finally
    LColumns.Free;
  end;
end;

procedure TWebDataCheck.Prepare(const ANodeName, AValue: string);
var
  LTables: TClientDataSet;
  LJSONValue: TJSONValue;
  LJSON: TJSONObject;
  LTableName, LFieldName: string;
begin
  FNodeName := ANodeName;
  FConfiguredValue := AValue;
  LTableName := '';
  LFieldName := '';
  LJSONValue := nil;
  if Trim(AValue) <> '' then
    LJSONValue := TJSONObject.ParseJSONValue(AValue);
  try
    if LJSONValue is TJSONObject then
    begin
      LJSON := TJSONObject(LJSONValue);
      LTableName := JSONStringValue(LJSON, 'cbTableName');
      LFieldName := JSONStringValue(LJSON, 'cbField');
    end;

    cbTableName.Items.Clear;
    if Assigned(UGMM) then
    begin
      LTables := TClientDataSet.Create(nil);
      try
        UGMM.GetNodeDataTables(FNodeName, LTables);
        LTables.First;
        while not LTables.Eof do
        begin
          cbTableName.Items.Add(LTables.FieldByName('TABLE_NAME').AsString);
          LTables.Next;
        end;
      finally
        LTables.Free;
      end;
    end;
    cbTableName.Text := LTableName;
    LoadFields(LTableName);
    cbField.Text := LFieldName;
  finally
    LJSONValue.Free;
  end;
end;

procedure TWebDataCheck.btOkClick(Sender: TObject);
var
  LJSON: TJSONObject;
begin
  if Trim(cbTableName.Text) = '' then
    raise Exception.Create('请选择关联表单。');
  if Trim(cbField.Text) = '' then
    raise Exception.Create('请选择校验字段。');
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('cbTableName', cbTableName.Text);
    LJSON.AddPair('cbField', cbField.Text);
    FConfiguredValue := LJSON.ToJSON;
  finally
    LJSON.Free;
  end;
  ModalResult := mrOk;
end;

procedure TWebDataCheck.cbTableNameChange(Sender: TObject);
begin
  LoadFields(cbTableName.Text);
end;

end.
