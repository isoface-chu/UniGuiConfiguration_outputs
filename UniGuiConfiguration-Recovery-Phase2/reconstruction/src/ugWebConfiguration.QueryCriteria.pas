unit ugWebConfiguration.QueryCriteria;


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
  TWebQueryCriteria = class(TWebConfigurationBase)
    pButtons: TUniContainerPanel;
    btAppend: TUniButton;
    btDelete: TUniButton;
    btEditor: TUniButton;
    btUp: TUniButton;
    btDown: TUniButton;
    UniPanel1: TUniPanel;
    btBatchAppend: TUniButton;
    UniPanel2: TUniPanel;
    gridQueryCriteria: TUniDBGrid;
    cdsQueryCriteria: TClientDataSet;
    dsQueryCriteria: TDataSource;
    procedure btAppendClick(Sender: TObject);
    procedure btDeleteClick(Sender: TObject);
    procedure btEditorClick(Sender: TObject);
    procedure btUpClick(Sender: TObject);
    procedure btDownClick(Sender: TObject);
    procedure btBatchAppendClick(Sender: TObject);
    procedure gridQueryCriteriaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure gridQueryCriteriaCellClick(Column: TUniDBGridColumn);
    procedure gridQueryCriteriaDblClick(Sender: TObject);
    procedure gridQueryCriteriaDrawColumnCell(Sender: TObject; ACol, ARow: Integer; Column: TUniDBGridColumn; Attribs: TUniCellAttribs);
    procedure cdsQueryCriteriaAfterPost(DataSet: TDataSet);
    procedure cdsQueryCriteriaAfterDelete(DataSet: TDataSet);
    procedure cdsQueryCriteriaAfterScroll(DataSet: TDataSet);
  private
    FColumns: TStringList;
    FBatchColumns: TClientDataSet;
    FEditingGuid: string;
    FDropGuid: string;
    FOpeningDrop: Boolean;
    procedure DropClose(Sender: TObject; var Action: TCloseAction);
    procedure CallSetup(AEdit: Boolean);
    procedure SetupClose(Sender: TObject; var Action: TCloseAction);
    procedure BatchSetupClose(Sender: TObject; var Action: TCloseAction);
    procedure AppendField(const AFieldName: string);
    procedure NormalizeSort;
    procedure MoveCurrent(ADelta: Integer);
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
  ugWebConfiguration.QueryCriteria.Setup,
  ugWebConfiguration.DropDownOptions,
  ugWebConfiguration.QueryCriteria.BatchAppend;

procedure AddCriteriaField(ADataSet: TClientDataSet; const AName: string;
  AType: TFieldType; ASize: Integer = 0);
var
  LDef: TFieldDef;
begin
  LDef := ADataSet.FieldDefs.AddFieldDef;
  LDef.Name := AName;
  LDef.DataType := AType;
  LDef.Size := ASize;
end;

function CriteriaMetadataPart(const AValue: string; AIndex: Integer): string;
var
  P, P2: Integer;
begin
  Result := '';
  P := Pos('|', AValue);
  if P = 0 then begin if AIndex = 0 then Result := AValue; Exit; end;
  if AIndex = 0 then begin Result := Copy(AValue, 1, P - 1); Exit; end;
  P2 := Pos('|', AValue, P + 1);
  if P2 = 0 then begin if AIndex = 1 then Result := Copy(AValue, P + 1, MaxInt); Exit; end;
  if AIndex = 1 then Result := Copy(AValue, P + 1, P2 - P - 1);
  if AIndex = 2 then Result := Copy(AValue, P2 + 1, MaxInt);
end;

constructor TWebQueryCriteria.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FColumns := TStringList.Create;
  // Temporary field snapshot, never part of the persisted configuration.
  FBatchColumns := TClientDataSet.Create(nil);
  FColumns.NameValueSeparator := '=';
  cdsQueryCriteria.Close;
  cdsQueryCriteria.FieldDefs.Clear;
  AddCriteriaField(cdsQueryCriteria, 'fdGuid', ftWideString, 80);
  AddCriteriaField(cdsQueryCriteria, 'fdColumn_name', ftWideString, 80);
  AddCriteriaField(cdsQueryCriteria, 'fdCaption', ftWideString, 255);
  AddCriteriaField(cdsQueryCriteria, 'fdIndePendence', ftBoolean);
  AddCriteriaField(cdsQueryCriteria, 'fdHideCaption', ftBoolean);
  AddCriteriaField(cdsQueryCriteria, 'fdComparisonOperator', ftWideString, 10);
  AddCriteriaField(cdsQueryCriteria, 'fdObject_Type', ftWideString, 20);
  AddCriteriaField(cdsQueryCriteria, 'fdDropDownOptions', ftWideString, 4000);
  AddCriteriaField(cdsQueryCriteria, 'fdSort', ftInteger);
  cdsQueryCriteria.CreateDataSet;
end;

destructor TWebQueryCriteria.Destroy;
begin
  FBatchColumns.Free;
  FColumns.Free;
  inherited Destroy;
end;

procedure TWebQueryCriteria.SetSourceColumns(AColumns: TClientDataSet);
var
  LBookmark: TBookmark;
  LName, LCaption, LObjectType, LDropDown: string;
begin
  FColumns.Clear;
  FBatchColumns.Close;
  if not Assigned(AColumns) or not AColumns.Active or AColumns.IsEmpty then
    Exit;
  FBatchColumns.Data := AColumns.Data;
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
        LObjectType := AColumns.FieldByName('fdOBJECT_TYPE').AsString;
        LDropDown := AColumns.FieldByName('fdDropDownOptions').AsString;
        if (LName <> '') and (FColumns.IndexOfName(LName) < 0) then
          FColumns.Values[LName] := LCaption + '|' + LObjectType + '|' +
            LDropDown;
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

procedure TWebQueryCriteria.btAppendClick(Sender: TObject);
begin
  CallSetup(False);
end;

procedure TWebQueryCriteria.btDeleteClick(Sender: TObject);
begin
  if cdsQueryCriteria.IsEmpty then
    Exit;
  cdsQueryCriteria.Delete;
  NormalizeSort;
end;

procedure TWebQueryCriteria.btEditorClick(Sender: TObject);
begin
  if not cdsQueryCriteria.IsEmpty then
    CallSetup(True);
end;

procedure TWebQueryCriteria.btUpClick(Sender: TObject);
begin
  MoveCurrent(-1);
end;

procedure TWebQueryCriteria.btDownClick(Sender: TObject);
begin
  MoveCurrent(1);
end;

procedure TWebQueryCriteria.btBatchAppendClick(Sender: TObject);
var
  LSetup: TWebQueryCriteriaBatchAppend;
begin
  if FColumns.Count = 0 then
    raise Exception.Create('请先在数据结构页选择至少一个字段。');
  LSetup := TWebQueryCriteriaBatchAppend.Create(UniApplication);
  try
    LSetup.Prepare(FBatchColumns);
    LSetup.OnClose := BatchSetupClose;
    LSetup.FreeOnClose := True;
    LSetup.ShowModal;
  except
    LSetup.Free;
    raise;
  end;
end;

procedure TWebQueryCriteria.BatchSetupClose(Sender: TObject; var Action: TCloseAction);
var
  LSetup: TWebQueryCriteriaBatchAppend;
  N: string;
begin
  LSetup := TWebQueryCriteriaBatchAppend(Sender);
  if LSetup.ModalResult <> mrOk then Exit;
  LSetup.cdsColumns.First;
  while not LSetup.cdsColumns.Eof do
  begin
    if LSetup.cdsColumns.FieldByName('fdSELECT').AsBoolean then
    begin
      cdsQueryCriteria.Append;
      cdsQueryCriteria.FieldByName('fdGuid').AsString := UGMM.CreateGuid;
      for N in TArray<string>.Create('fdColumn_name', 'fdCaption', 'fdIndePendence',
        'fdHideCaption', 'fdComparisonOperator', 'fdObject_Type', 'fdDropDownOptions') do
        cdsQueryCriteria.FieldByName(N).Value := LSetup.cdsColumns.FieldByName(N).Value;
      cdsQueryCriteria.FieldByName('fdSort').AsInteger := cdsQueryCriteria.RecordCount + 1;
      cdsQueryCriteria.Post;
    end;
    LSetup.cdsColumns.Next;
  end;
  NormalizeSort;
  gridQueryCriteria.Refresh;
end;

procedure TWebQueryCriteria.gridQueryCriteriaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebQueryCriteria.gridQueryCriteriaCellClick(Column: TUniDBGridColumn);
var F: TWebDropDownOptions; K: string;
begin
  if (Column = nil) or not SameText(Column.FieldName, 'fdDropDownOptions') or
    FOpeningDrop or cdsQueryCriteria.IsEmpty then Exit;
  K := LowerCase(cdsQueryCriteria.FieldByName('fdObject_Type').AsString);
  if (Pos('combobox', K) = 0) and (Pos('lookupedit', K) = 0) then Exit;
  if cdsQueryCriteria.State in dsEditModes then cdsQueryCriteria.Post;
  FDropGuid := cdsQueryCriteria.FieldByName('fdGuid').AsString;
  FOpeningDrop := True;
  F := TWebDropDownOptions.Create(UniApplication);
  try
    F.DataNodeName := DataNodeName;
    F.Prepare(K, cdsQueryCriteria.FieldByName('fdCaption').AsString,
      cdsQueryCriteria.FieldByName('fdDropDownOptions').AsString);
    F.OnClose := DropClose;
    F.FreeOnClose := True;
    F.ShowModal;
  except
    FOpeningDrop := False; F.Free; raise;
  end;
end;

procedure TWebQueryCriteria.DropClose(Sender: TObject; var Action: TCloseAction);
begin
  FOpeningDrop := False;
  if TWebDropDownOptions(Sender).ModalResult <> mrOk then Exit;
  if cdsQueryCriteria.Locate('fdGuid', FDropGuid, []) then
  begin
    cdsQueryCriteria.Edit;
    cdsQueryCriteria.FieldByName('fdDropDownOptions').AsString := TWebDropDownOptions(Sender).ConfiguredValue;
    cdsQueryCriteria.Post;
    gridQueryCriteria.Refresh;
  end;
end;

procedure TWebQueryCriteria.gridQueryCriteriaDblClick(Sender: TObject);
begin
  if FOpeningDrop then Exit;
  btEditorClick(Sender);
end;

procedure TWebQueryCriteria.gridQueryCriteriaDrawColumnCell(Sender: TObject; ACol, ARow: Integer; Column: TUniDBGridColumn; Attribs: TUniCellAttribs);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebQueryCriteria.CallSetup(AEdit: Boolean);
var
  LSetup: TWebQueryCriteriaSetup;
  LFieldName, LCaption, LObjectType, LOperator: string;
  LIndependence, LHideCaption: Boolean;
begin
  if FColumns.Count = 0 then
    raise Exception.Create('请先在数据结构页选择至少一个字段。');
  FEditingGuid := '';
  LFieldName := '';
  LCaption := '';
  LObjectType := '';
  LOperator := '';
  LIndependence := False;
  LHideCaption := False;
  if AEdit and not cdsQueryCriteria.IsEmpty then
  begin
    FEditingGuid := cdsQueryCriteria.FieldByName('fdGuid').AsString;
    LFieldName := cdsQueryCriteria.FieldByName('fdColumn_name').AsString;
    LCaption := cdsQueryCriteria.FieldByName('fdCaption').AsString;
    LObjectType := cdsQueryCriteria.FieldByName('fdObject_Type').AsString;
    LOperator := cdsQueryCriteria.FieldByName(
      'fdComparisonOperator').AsString;
    LIndependence := cdsQueryCriteria.FieldByName(
      'fdIndePendence').AsBoolean;
    LHideCaption := cdsQueryCriteria.FieldByName('fdHideCaption').AsBoolean;
    if FColumns.IndexOfName(LFieldName) < 0 then
      FColumns.Values[LFieldName] := LCaption + '|' + LObjectType + '|';
  end;
  LSetup := TWebQueryCriteriaSetup.Create(UniApplication);
  try
    LSetup.Prepare(FColumns, LFieldName, LCaption, LObjectType, LOperator,
      LIndependence, LHideCaption);
    LSetup.OnClose := SetupClose;
    LSetup.FreeOnClose := True;
    LSetup.ShowModal;
  except
    LSetup.Free;
    raise;
  end;
end;

procedure TWebQueryCriteria.SetupClose(Sender: TObject;
  var Action: TCloseAction);
var
  LSetup: TWebQueryCriteriaSetup;
  LMetadata, LOptions: string;
begin
  LSetup := TWebQueryCriteriaSetup(Sender);
  if LSetup.ModalResult <> mrOk then
    Exit;
  if (FEditingGuid <> '') and
    cdsQueryCriteria.Locate('fdGuid', FEditingGuid, []) then
  begin
    if SameText(cdsQueryCriteria.FieldByName('fdColumn_name').AsString, LSetup.FieldName) and
      SameText(cdsQueryCriteria.FieldByName('fdObject_Type').AsString, LSetup.ObjectType) then
      LOptions := cdsQueryCriteria.FieldByName('fdDropDownOptions').AsString;
    cdsQueryCriteria.Edit;
  end
  else
  begin
    cdsQueryCriteria.Append;
    cdsQueryCriteria.FieldByName('fdGuid').AsString := UGMM.CreateGuid;
    cdsQueryCriteria.FieldByName('fdSort').AsInteger :=
      cdsQueryCriteria.RecordCount + 1;
  end;
  LMetadata := FColumns.Values[LSetup.FieldName];
  if LOptions = '' then LOptions := CriteriaMetadataPart(LMetadata, 2);
  cdsQueryCriteria.FieldByName('fdColumn_name').AsString := LSetup.FieldName;
  cdsQueryCriteria.FieldByName('fdCaption').AsString := LSetup.CaptionText;
  cdsQueryCriteria.FieldByName('fdIndePendence').AsBoolean :=
    LSetup.Independence;
  cdsQueryCriteria.FieldByName('fdHideCaption').AsBoolean :=
    LSetup.HideCaption;
  cdsQueryCriteria.FieldByName('fdComparisonOperator').AsString :=
    LSetup.ComparisonOperator;
  cdsQueryCriteria.FieldByName('fdObject_Type').AsString :=
    LSetup.ObjectType;
  cdsQueryCriteria.FieldByName('fdDropDownOptions').AsString :=
    LOptions;
  cdsQueryCriteria.Post;
  NormalizeSort;
  gridQueryCriteria.Refresh;
end;

procedure TWebQueryCriteria.AppendField(const AFieldName: string);
var
  LMetadata, LObjectType, LOperator: string;
begin
  { 批量勾选字段：同一字段只保留一条查询条件，重复追加直接忽略。 }
  if AFieldName = '' then
    Exit;
  if cdsQueryCriteria.Active and
    cdsQueryCriteria.Locate('fdColumn_name', AFieldName, []) then
    Exit;
  LMetadata := FColumns.Values[AFieldName];
  LObjectType := CriteriaMetadataPart(LMetadata, 1);
  if LObjectType = '' then
    LObjectType := 'edit';
  if (LObjectType = 'edit') or (LObjectType = 'memo') then
    LOperator := 'like'
  else
    LOperator := '=';
  cdsQueryCriteria.Append;
  cdsQueryCriteria.FieldByName('fdGuid').AsString := UGMM.CreateGuid;
  cdsQueryCriteria.FieldByName('fdColumn_name').AsString := AFieldName;
  cdsQueryCriteria.FieldByName('fdCaption').AsString :=
    CriteriaMetadataPart(LMetadata, 0);
  cdsQueryCriteria.FieldByName('fdIndePendence').AsBoolean := False;
  cdsQueryCriteria.FieldByName('fdHideCaption').AsBoolean := False;
  cdsQueryCriteria.FieldByName('fdComparisonOperator').AsString := LOperator;
  cdsQueryCriteria.FieldByName('fdObject_Type').AsString := LObjectType;
  cdsQueryCriteria.FieldByName('fdDropDownOptions').AsString :=
    CriteriaMetadataPart(LMetadata, 2);
  cdsQueryCriteria.FieldByName('fdSort').AsInteger :=
    cdsQueryCriteria.RecordCount + 1;
  cdsQueryCriteria.Post;
end;

procedure TWebQueryCriteria.NormalizeSort;
var
  I: Integer;
begin
  if not cdsQueryCriteria.Active then
    Exit;
  cdsQueryCriteria.IndexName := 'cdsQueryCriteriaIndex1';
  I := 1;
  cdsQueryCriteria.First;
  while not cdsQueryCriteria.Eof do
  begin
    if cdsQueryCriteria.FieldByName('fdSort').AsInteger <> I then
    begin
      cdsQueryCriteria.Edit;
      cdsQueryCriteria.FieldByName('fdSort').AsInteger := I;
      cdsQueryCriteria.Post;
    end;
    Inc(I);
    cdsQueryCriteria.Next;
  end;
  cdsQueryCriteria.First;
end;

procedure TWebQueryCriteria.MoveCurrent(ADelta: Integer);
var
  LGuid: string;
  LSort, LOtherSort: Integer;
begin
  if cdsQueryCriteria.IsEmpty or (ADelta = 0) then
    Exit;
  LGuid := cdsQueryCriteria.FieldByName('fdGuid').AsString;
  NormalizeSort;
  if not cdsQueryCriteria.Locate('fdGuid', LGuid, []) then
    Exit;
  LSort := cdsQueryCriteria.FieldByName('fdSort').AsInteger;
  if ((ADelta < 0) and (cdsQueryCriteria.RecNo <= 1)) or
    ((ADelta > 0) and
      (cdsQueryCriteria.RecNo >= cdsQueryCriteria.RecordCount)) then
    Exit;
  if ADelta < 0 then
    cdsQueryCriteria.Prior
  else
    cdsQueryCriteria.Next;
  LOtherSort := cdsQueryCriteria.FieldByName('fdSort').AsInteger;
  cdsQueryCriteria.Edit;
  cdsQueryCriteria.FieldByName('fdSort').AsInteger := LSort;
  cdsQueryCriteria.Post;
  if cdsQueryCriteria.Locate('fdGuid', LGuid, []) then
  begin
    cdsQueryCriteria.Edit;
    cdsQueryCriteria.FieldByName('fdSort').AsInteger := LOtherSort;
    cdsQueryCriteria.Post;
  end;
  cdsQueryCriteria.IndexName := '';
  cdsQueryCriteria.IndexName := 'cdsQueryCriteriaIndex1';
  cdsQueryCriteria.Locate('fdGuid', LGuid, []);
  gridQueryCriteria.Refresh;
end;

procedure TWebQueryCriteria.cdsQueryCriteriaAfterPost(DataSet: TDataSet);
begin
end;

procedure TWebQueryCriteria.cdsQueryCriteriaAfterDelete(DataSet: TDataSet);
begin
end;

procedure TWebQueryCriteria.cdsQueryCriteriaAfterScroll(DataSet: TDataSet);
begin
end;

function TWebQueryCriteria.CheckConfigure: Boolean;
begin
  Result := inherited CheckConfigure;
end;

procedure TWebQueryCriteria.LoadConfigure(AJSON: TJSONObject);
begin
  inherited LoadConfigure(AJSON);
  NormalizeSort;
end;

procedure TWebQueryCriteria.SaveConfigure(AJSON: TJSONObject);
begin
  inherited SaveConfigure(AJSON);
end;

procedure TWebQueryCriteria.CurrentAction(APageActionType: TPageActionType);
begin
  inherited CurrentAction(APageActionType);
end;

end.
