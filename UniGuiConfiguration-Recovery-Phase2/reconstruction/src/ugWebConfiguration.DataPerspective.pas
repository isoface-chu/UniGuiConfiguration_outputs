unit ugWebConfiguration.DataPerspective;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Vcl.Forms, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebConfigurationBase;

type
  TWebDataPerspective = class(TWebConfigurationBase)
    pButtons: TUniContainerPanel;
    btAppend: TUniButton;
    btDelete: TUniButton;
    btEditor: TUniButton;
    btUp: TUniButton;
    btDown: TUniButton;
    UniPanel1: TUniPanel;
    gridDataPerspective: TUniDBGrid;
    cdsDataPerspective: TClientDataSet;
    dsDataPerspective: TDataSource;
    procedure btAppendClick(Sender: TObject);
    procedure btDeleteClick(Sender: TObject);
    procedure btEditorClick(Sender: TObject);
    procedure btUpClick(Sender: TObject);
    procedure btDownClick(Sender: TObject);
    procedure gridDataPerspectiveColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
    procedure cdsDataPerspectiveAfterPost(DataSet: TDataSet);
    procedure cdsDataPerspectiveAfterDelete(DataSet: TDataSet);
    procedure cdsDataPerspectiveAfterScroll(DataSet: TDataSet);
  private
    FColumns: TStringList;
    FEditingGuid: string;
    procedure CallSetup(AEdit: Boolean);
    procedure SetupClose(Sender: TObject; var Action: TCloseAction);
    procedure MoveCurrent(ADelta: Integer);
    procedure NormalizeSort;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetSourceColumns(AColumns: TClientDataSet);
    function CheckConfigure: Boolean; override;
    procedure LoadConfigure(AJSON: TJSONObject); override;
    procedure SaveConfigure(AJSON: TJSONObject); override;
    procedure CurrentAction(APageActionType: TPageActionType); override;
  end;

implementation

{$R *.dfm}

uses
  uniGUIApplication,
  ugWebConfiguration.DataPerspective.Setup;

procedure AddPerspectiveField(ADataSet: TClientDataSet; const AName: string;
  AType: TFieldType; ASize: Integer = 0);
var
  LDef: TFieldDef;
begin
  LDef := ADataSet.FieldDefs.AddFieldDef;
  LDef.Name := AName;
  LDef.DataType := AType;
  LDef.Size := ASize;
end;

constructor TWebDataPerspective.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FColumns := TStringList.Create;
  FColumns.NameValueSeparator := '=';
  cdsDataPerspective.Close;
  cdsDataPerspective.FieldDefs.Clear;
  AddPerspectiveField(cdsDataPerspective, 'fdGuid', ftWideString, 80);
  AddPerspectiveField(cdsDataPerspective, 'fdCOLUMN_NAME', ftWideString, 80);
  AddPerspectiveField(cdsDataPerspective, 'fdCOLUMN_AS', ftWideString, 80);
  AddPerspectiveField(cdsDataPerspective, 'fdCaption', ftWideString, 255);
  AddPerspectiveField(cdsDataPerspective, 'fdGroup', ftWideString, 80);
  AddPerspectiveField(cdsDataPerspective, 'fdType', ftInteger);
  AddPerspectiveField(cdsDataPerspective, 'fdDBlClickGoToDtails', ftBoolean);
  AddPerspectiveField(cdsDataPerspective, 'fdSort', ftInteger);
  cdsDataPerspective.CreateDataSet;
end;

destructor TWebDataPerspective.Destroy;
begin
  FColumns.Free;
  inherited Destroy;
end;

procedure TWebDataPerspective.SetSourceColumns(AColumns: TClientDataSet);
var
  LBookmark: TBookmark;
  LName, LCaption: string;
begin
  FColumns.Clear;
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
        LName := AColumns.FieldByName('fdCOLUMN_NAME').AsString;
        LCaption := AColumns.FieldByName('fdCAPTION').AsString;
        if (LName <> '') and (FColumns.IndexOfName(LName) < 0) then
          FColumns.Values[LName] := LCaption;
      end;
      AColumns.Next;
    end;
  finally
    if AColumns.BookmarkValid(LBookmark) then
      AColumns.GotoBookmark(LBookmark);
    AColumns.FreeBookmark(LBookmark);
    AColumns.EnableControls;
  end;
end;

procedure TWebDataPerspective.btAppendClick(Sender: TObject);
begin
  CallSetup(False);
end;

procedure TWebDataPerspective.btDeleteClick(Sender: TObject);
begin
  if cdsDataPerspective.IsEmpty then
    Exit;
  cdsDataPerspective.Delete;
  NormalizeSort;
end;

procedure TWebDataPerspective.btEditorClick(Sender: TObject);
begin
  if not cdsDataPerspective.IsEmpty then
    CallSetup(True);
end;

procedure TWebDataPerspective.btUpClick(Sender: TObject);
begin
  MoveCurrent(-1);
end;

procedure TWebDataPerspective.btDownClick(Sender: TObject);
begin
  MoveCurrent(1);
end;

procedure TWebDataPerspective.gridDataPerspectiveColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
var
  LIndexName, LDescending: string;
begin
  if (Column.FieldName = '') or
    (cdsDataPerspective.FindField(Column.FieldName) = nil) then
    Exit;
  LIndexName := 'UgPerspectiveSort';
  cdsDataPerspective.IndexName := '';
  cdsDataPerspective.IndexDefs.Update;
  if cdsDataPerspective.IndexDefs.IndexOf(LIndexName) >= 0 then
    cdsDataPerspective.DeleteIndex(LIndexName);
  if Direction then
    LDescending := Column.FieldName
  else
    LDescending := '';
  cdsDataPerspective.AddIndex(LIndexName, Column.FieldName, [],
    LDescending, '', 0);
  cdsDataPerspective.IndexName := LIndexName;
  cdsDataPerspective.First;
end;

procedure TWebDataPerspective.CallSetup(AEdit: Boolean);
var
  LSetup: TWebDataPerspectiveSetup;
  LField, LFieldAs, LCaption, LGroup: string;
  LType: Integer;
  LGoToDetails: Boolean;
begin
  if FColumns.Count = 0 then
    raise Exception.Create('请先在数据结构页选择至少一个字段。');
  FEditingGuid := '';
  LField := '';
  LFieldAs := '';
  LCaption := '';
  LGroup := '';
  LType := 0;
  LGoToDetails := False;
  if AEdit and not cdsDataPerspective.IsEmpty then
  begin
    FEditingGuid := cdsDataPerspective.FieldByName('fdGuid').AsString;
    LField := cdsDataPerspective.FieldByName('fdCOLUMN_NAME').AsString;
    LFieldAs := cdsDataPerspective.FieldByName('fdCOLUMN_AS').AsString;
    LCaption := cdsDataPerspective.FieldByName('fdCaption').AsString;
    LGroup := cdsDataPerspective.FieldByName('fdGroup').AsString;
    LType := cdsDataPerspective.FieldByName('fdType').AsInteger;
    LGoToDetails := cdsDataPerspective.FieldByName(
      'fdDBlClickGoToDtails').AsBoolean;
    if FColumns.IndexOfName(LFieldAs) < 0 then
      FColumns.Values[LFieldAs] := LCaption;
  end;
  LSetup := TWebDataPerspectiveSetup.Create(UniApplication);
  try
    LSetup.Prepare(FColumns, LField, LFieldAs, LCaption, LGroup, LType,
      LGoToDetails);
    LSetup.OnClose := SetupClose;
    LSetup.FreeOnClose := True;
    LSetup.ShowModal;
  except
    LSetup.Free;
    raise;
  end;
end;

procedure TWebDataPerspective.SetupClose(Sender: TObject;
  var Action: TCloseAction);
var
  LSetup: TWebDataPerspectiveSetup;
begin
  LSetup := TWebDataPerspectiveSetup(Sender);
  if LSetup.ModalResult <> mrOk then
    Exit;
  if (FEditingGuid <> '') and
    cdsDataPerspective.Locate('fdGuid', FEditingGuid, []) then
    cdsDataPerspective.Edit
  else
  begin
    cdsDataPerspective.Append;
    cdsDataPerspective.FieldByName('fdGuid').AsString := UGMM.CreateGuid;
    cdsDataPerspective.FieldByName('fdSort').AsInteger :=
      cdsDataPerspective.RecordCount + 1;
  end;
  cdsDataPerspective.FieldByName('fdCOLUMN_NAME').AsString :=
    LSetup.SelectedField;
  cdsDataPerspective.FieldByName('fdCOLUMN_AS').AsString :=
    LSetup.SelectedFieldAs;
  cdsDataPerspective.FieldByName('fdCaption').AsString :=
    LSetup.SelectedCaption;
  cdsDataPerspective.FieldByName('fdGroup').AsString :=
    LSetup.SelectedGroup;
  cdsDataPerspective.FieldByName('fdType').AsInteger := LSetup.SelectedType;
  cdsDataPerspective.FieldByName('fdDBlClickGoToDtails').AsBoolean :=
    LSetup.GoToDetails;
  cdsDataPerspective.Post;
  NormalizeSort;
  gridDataPerspective.Refresh;
end;

procedure TWebDataPerspective.NormalizeSort;
var
  I: Integer;
begin
  if not cdsDataPerspective.Active then
    Exit;
  cdsDataPerspective.IndexName := 'cdsDataPerspectiveIndex1';
  I := 1;
  cdsDataPerspective.First;
  while not cdsDataPerspective.Eof do
  begin
    if cdsDataPerspective.FieldByName('fdSort').AsInteger <> I then
    begin
      cdsDataPerspective.Edit;
      cdsDataPerspective.FieldByName('fdSort').AsInteger := I;
      cdsDataPerspective.Post;
    end;
    Inc(I);
    cdsDataPerspective.Next;
  end;
  cdsDataPerspective.First;
end;

procedure TWebDataPerspective.MoveCurrent(ADelta: Integer);
var
  LGuid: string;
  LSort, LOtherSort: Integer;
begin
  if cdsDataPerspective.IsEmpty or (ADelta = 0) then
    Exit;
  LGuid := cdsDataPerspective.FieldByName('fdGuid').AsString;
  NormalizeSort;
  if not cdsDataPerspective.Locate('fdGuid', LGuid, []) then
    Exit;
  LSort := cdsDataPerspective.FieldByName('fdSort').AsInteger;
  if ((ADelta < 0) and (cdsDataPerspective.RecNo <= 1)) or
    ((ADelta > 0) and
      (cdsDataPerspective.RecNo >= cdsDataPerspective.RecordCount)) then
    Exit;
  if ADelta < 0 then
    cdsDataPerspective.Prior
  else
    cdsDataPerspective.Next;
  LOtherSort := cdsDataPerspective.FieldByName('fdSort').AsInteger;
  cdsDataPerspective.Edit;
  cdsDataPerspective.FieldByName('fdSort').AsInteger := LSort;
  cdsDataPerspective.Post;
  if cdsDataPerspective.Locate('fdGuid', LGuid, []) then
  begin
    cdsDataPerspective.Edit;
    cdsDataPerspective.FieldByName('fdSort').AsInteger := LOtherSort;
    cdsDataPerspective.Post;
  end;
  cdsDataPerspective.IndexName := '';
  cdsDataPerspective.IndexName := 'cdsDataPerspectiveIndex1';
  cdsDataPerspective.Locate('fdGuid', LGuid, []);
  gridDataPerspective.Refresh;
end;

procedure TWebDataPerspective.cdsDataPerspectiveAfterPost(DataSet: TDataSet);
begin
end;

procedure TWebDataPerspective.cdsDataPerspectiveAfterDelete(DataSet: TDataSet);
begin
end;

procedure TWebDataPerspective.cdsDataPerspectiveAfterScroll(DataSet: TDataSet);
begin
end;

function TWebDataPerspective.CheckConfigure: Boolean;
begin
  Result := inherited CheckConfigure;
end;

procedure TWebDataPerspective.LoadConfigure(AJSON: TJSONObject);
begin
  inherited LoadConfigure(AJSON);
  NormalizeSort;
end;

procedure TWebDataPerspective.SaveConfigure(AJSON: TJSONObject);
begin
  inherited SaveConfigure(AJSON);
end;

procedure TWebDataPerspective.CurrentAction(APageActionType: TPageActionType);
begin
  inherited CurrentAction(APageActionType);
end;

end.
