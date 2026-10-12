unit ugWebConfiguration.NormalSetting.MultiSelectField;


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
  TWebNormalSettingMultiSelectField = class(TWebCustBaseForm)
    gridMultiSelectFields: TUniDBGrid;
    pButton: TUniContainerPanel;
    btOk: TUniButton;
    pFilters: TUniHiddenPanel;
    dsMultiSelectFields: TDataSource;
    cdsMultiSelectFields: TClientDataSet;
    procedure gridMultiSelectFieldsClearFilters(Sender: TObject);
    procedure gridMultiSelectFieldsColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);
    procedure btOkClick(Sender: TObject);
  private
    FSelectedFields: string;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(AColumns: TClientDataSet; const ASelectedFields: string);
    property SelectedFields: string read FSelectedFields;
  end;

implementation

{$R *.dfm}

procedure AddMultiFieldDef(ADataSet: TClientDataSet; const AName: string;
  AType: TFieldType; ASize: Integer = 0);
var
  LDef: TFieldDef;
begin
  LDef := ADataSet.FieldDefs.AddFieldDef;
  LDef.Name := AName;
  LDef.DataType := AType;
  LDef.Size := ASize;
end;

constructor TWebNormalSettingMultiSelectField.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  cdsMultiSelectFields.Close;
  cdsMultiSelectFields.FieldDefs.Clear;
  AddMultiFieldDef(cdsMultiSelectFields, 'fdSELECT', ftBoolean);
  AddMultiFieldDef(cdsMultiSelectFields, 'fdRECNO', ftInteger);
  AddMultiFieldDef(cdsMultiSelectFields, 'fdCOLUMN_NAME', ftWideString, 80);
  AddMultiFieldDef(cdsMultiSelectFields, 'fdCAPTION', ftWideString, 255);
  AddMultiFieldDef(cdsMultiSelectFields, 'fdObject_Type', ftWideString, 80);
  AddMultiFieldDef(cdsMultiSelectFields, 'fdCOLUMN_TYPENAME', ftWideString, 80);
  AddMultiFieldDef(cdsMultiSelectFields, 'fdCOLUMN_PRECISION', ftInteger);
  AddMultiFieldDef(cdsMultiSelectFields, 'fdCOLUMN_SCAL', ftInteger);
  AddMultiFieldDef(cdsMultiSelectFields, 'fdCOLUMN_LENGTH', ftInteger);
  cdsMultiSelectFields.CreateDataSet;
end;

procedure TWebNormalSettingMultiSelectField.Prepare(AColumns: TClientDataSet;
  const ASelectedFields: string);
var
  LBookmark: TBookmark;
  LName: string;
begin
  FSelectedFields := ASelectedFields;
  cdsMultiSelectFields.EmptyDataSet;
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
        cdsMultiSelectFields.Append;
        cdsMultiSelectFields.FieldByName('fdSELECT').AsBoolean := Pos(';' + LName + ';', ';' + ASelectedFields) > 0;
        cdsMultiSelectFields.FieldByName('fdRECNO').AsInteger := AColumns.FieldByName('fdRECNO').AsInteger;
        cdsMultiSelectFields.FieldByName('fdCOLUMN_NAME').AsString := LName;
        cdsMultiSelectFields.FieldByName('fdCAPTION').AsString := AColumns.FieldByName('fdCAPTION').AsString;
        cdsMultiSelectFields.FieldByName('fdObject_Type').AsString := AColumns.FieldByName('fdOBJECT_TYPE').AsString;
        cdsMultiSelectFields.FieldByName('fdCOLUMN_TYPENAME').AsString := AColumns.FieldByName('fdCOLUMN_TYPENAME').AsString;
        cdsMultiSelectFields.FieldByName('fdCOLUMN_PRECISION').AsInteger := AColumns.FieldByName('fdCOLUMN_PRECISION').AsInteger;
        cdsMultiSelectFields.FieldByName('fdCOLUMN_SCAL').AsInteger := AColumns.FieldByName('fdCOLUMN_SCAL').AsInteger;
        cdsMultiSelectFields.FieldByName('fdCOLUMN_LENGTH').AsInteger := AColumns.FieldByName('fdCOLUMN_LENGTH').AsInteger;
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

procedure TWebNormalSettingMultiSelectField.gridMultiSelectFieldsClearFilters(Sender: TObject);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebNormalSettingMultiSelectField.gridMultiSelectFieldsColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebNormalSettingMultiSelectField.btOkClick(Sender: TObject);
begin
  FSelectedFields := '';
  if cdsMultiSelectFields.State in dsEditModes then cdsMultiSelectFields.Post;
  cdsMultiSelectFields.First;
  while not cdsMultiSelectFields.Eof do
  begin
    if cdsMultiSelectFields.FieldByName('fdSELECT').AsBoolean then
      FSelectedFields := FSelectedFields + cdsMultiSelectFields.FieldByName('fdCOLUMN_NAME').AsString + ';';
    cdsMultiSelectFields.Next;
  end;
  ModalResult := mrOk;
end;

end.
