unit ugWebConfiguration.NormalSetting.SelectField;


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
  TWebNormalSettingSelectField = class(TWebCustBaseForm)
    gridSelectField: TUniDBGrid;
    pButton: TUniContainerPanel;
    btOk: TUniButton;
    pFilters: TUniHiddenPanel;
    cdsSelectField: TClientDataSet;
    dsSelectField: TDataSource;
    procedure gridSelectFieldClearFilters(Sender: TObject);
    procedure gridSelectFieldColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);
    procedure btOkClick(Sender: TObject);
  private
    FSelectedField: string;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(AColumns: TClientDataSet; const ASelectedField: string);
    property SelectedField: string read FSelectedField;
  end;

implementation

{$R *.dfm}

procedure AddSelectFieldDef(ADataSet: TClientDataSet; const AName: string;
  AType: TFieldType; ASize: Integer = 0);
var
  LDef: TFieldDef;
begin
  LDef := ADataSet.FieldDefs.AddFieldDef;
  LDef.Name := AName;
  LDef.DataType := AType;
  LDef.Size := ASize;
end;

constructor TWebNormalSettingSelectField.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  cdsSelectField.Close;
  cdsSelectField.FieldDefs.Clear;
  AddSelectFieldDef(cdsSelectField, 'fdRECNO', ftInteger);
  AddSelectFieldDef(cdsSelectField, 'fdCOLUMN_NAME', ftWideString, 80);
  AddSelectFieldDef(cdsSelectField, 'fdCAPTION', ftWideString, 255);
  AddSelectFieldDef(cdsSelectField, 'fdObject_Type', ftWideString, 80);
  AddSelectFieldDef(cdsSelectField, 'fdCOLUMN_TYPENAME', ftWideString, 80);
  AddSelectFieldDef(cdsSelectField, 'fdCOLUMN_PRECISION', ftInteger);
  AddSelectFieldDef(cdsSelectField, 'fdCOLUMN_SCAL', ftInteger);
  AddSelectFieldDef(cdsSelectField, 'fdCOLUMN_LENGTH', ftInteger);
  cdsSelectField.CreateDataSet;
end;

procedure TWebNormalSettingSelectField.Prepare(AColumns: TClientDataSet;
  const ASelectedField: string);
var
  LBookmark: TBookmark;
begin
  FSelectedField := ASelectedField;
  cdsSelectField.EmptyDataSet;
  if not Assigned(AColumns) or not AColumns.Active or AColumns.IsEmpty then
    Exit;
  LBookmark := AColumns.GetBookmark;
  AColumns.DisableControls;
  try
    AColumns.First;
    while not AColumns.Eof do
    begin
      if AColumns.FieldByName('fdSELECT').AsBoolean then
      begin
        cdsSelectField.Append;
        cdsSelectField.FieldByName('fdRECNO').AsInteger := AColumns.FieldByName('fdRECNO').AsInteger;
        cdsSelectField.FieldByName('fdCOLUMN_NAME').AsString := AColumns.FieldByName('fdCOLUMN_NAME').AsString;
        cdsSelectField.FieldByName('fdCAPTION').AsString := AColumns.FieldByName('fdCAPTION').AsString;
        cdsSelectField.FieldByName('fdObject_Type').AsString := AColumns.FieldByName('fdOBJECT_TYPE').AsString;
        cdsSelectField.FieldByName('fdCOLUMN_TYPENAME').AsString := AColumns.FieldByName('fdCOLUMN_TYPENAME').AsString;
        cdsSelectField.FieldByName('fdCOLUMN_PRECISION').AsInteger := AColumns.FieldByName('fdCOLUMN_PRECISION').AsInteger;
        cdsSelectField.FieldByName('fdCOLUMN_SCAL').AsInteger := AColumns.FieldByName('fdCOLUMN_SCAL').AsInteger;
        cdsSelectField.FieldByName('fdCOLUMN_LENGTH').AsInteger := AColumns.FieldByName('fdCOLUMN_LENGTH').AsInteger;
        cdsSelectField.Post;
      end;
      AColumns.Next;
    end;
  finally
    if AColumns.BookmarkValid(LBookmark) then AColumns.GotoBookmark(LBookmark);
    AColumns.FreeBookmark(LBookmark);
    AColumns.EnableControls;
  end;
  if not cdsSelectField.Locate('fdCOLUMN_NAME', ASelectedField, []) then cdsSelectField.First;
end;

procedure TWebNormalSettingSelectField.gridSelectFieldClearFilters(Sender: TObject);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebNormalSettingSelectField.gridSelectFieldColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebNormalSettingSelectField.btOkClick(Sender: TObject);
begin
  if cdsSelectField.IsEmpty then Exit;
  FSelectedField := cdsSelectField.FieldByName('fdCOLUMN_NAME').AsString;
  ModalResult := mrOk;
end;

end.
