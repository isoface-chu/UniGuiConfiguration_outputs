unit ugWebConfiguration.DataStructure;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Vcl.Forms, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame, uniSplitter,
  ugWebConfigurationBase;

type
  TWebDataStructure = class(TWebConfigurationBase)
    UniLabel1: TUniLabel;
    pTables: TUniContainerPanel;
    treeTables: TUniDBTreeGrid;
    pTableButtons: TUniContainerPanel;
    btAppend: TUniButton;
    btDelete: TUniButton;
    btEditor: TUniButton;
    pColumns: TUniContainerPanel;
    pTypesetting: TUniContainerPanel;
    gridTypesetting: TUniDBGrid;
    pTypesettingButton: TUniContainerPanel;
    btDown: TUniButton;
    btUp: TUniButton;
    gridColumns: TUniDBGrid;
    UniHiddenPanel1: TUniHiddenPanel;
    edObjectType: TUniComboBox;
    UniSplitter1: TUniSplitter;
    cdsTables: TClientDataSet;
    cdsColumns: TClientDataSet;
    dsTables: TDataSource;
    dsColumns: TDataSource;
    cdsTypesetting: TClientDataSet;
    dsTypesetting: TDataSource;
    procedure btAppendClick(Sender: TObject);
    procedure btDeleteClick(Sender: TObject);
    procedure btEditorClick(Sender: TObject);
    procedure gridTypesettingColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
    procedure gridTypesettingTitleClick(Column: TUniDBGridColumn);
    procedure btDownClick(Sender: TObject);
    procedure btUpClick(Sender: TObject);
    procedure gridColumnsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure gridColumnsCellClick(Column: TUniDBGridColumn);
    procedure gridColumnsColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
    procedure gridColumnsTitleClick(Column: TUniDBGridColumn);
    procedure gridColumnsDblClick(Sender: TObject);
    procedure gridColumnsDrawColumnCell(Sender: TObject; ACol, ARow: Integer; Column: TUniDBGridColumn; Attribs: TUniCellAttribs);
    procedure cdsTablesAfterPost(DataSet: TDataSet);
    procedure cdsTablesBeforeDelete(DataSet: TDataSet);
    procedure cdsTablesAfterDelete(DataSet: TDataSet);
    procedure cdsColumnsBeforePost(DataSet: TDataSet);
    procedure cdsColumnsBeforeDelete(DataSet: TDataSet);
  private
    FColumnsSortField: string;
    FColumnsSortDescending: Boolean;
    FTypesettingSortField: string;
    FTypesettingSortDescending: Boolean;
    FEditingColumnGuid: string;
    FOpeningDropDownOptions: Boolean;
    FOpeningDataCheck: Boolean;
    procedure DefaultColumnOrder;
    procedure RepairColumnAliases;
    procedure TableSetupClose(Sender: TObject; var Action: TCloseAction);
    function NextTableAlias: string;
    function DefaultObjectType(const ATypeName: string): string;
    procedure DeleteTableData(const ATableGuid: string);
    procedure SyncCurrentColumnToTypesetting;
    procedure MoveCurrentTypesetting(ADelta: Integer);
    procedure SetDataSetSort(ADataSet: TClientDataSet; const AFieldName: string;
      ADescending: Boolean);
    procedure OpenDropDownOptions;
    procedure DropDownOptionsClose(Sender: TObject; var Action: TCloseAction);
    procedure OpenDataCheck;
    procedure DataCheckClose(Sender: TObject; var Action: TCloseAction);
  public
    procedure ShowDefaultFieldOrder;
    constructor Create(AOwner: TComponent); override;
    function CheckConfigure: Boolean; override;
    procedure LoadConfigure(AJSON: TJSONObject); override;
    procedure SaveConfigure(AJSON: TJSONObject); override;
    procedure CurrentAction(APageActionType: TPageActionType); override;
  end;

implementation

{$R *.dfm}

uses
  uniGUIApplication,
  ugWebConfiguration.DataStructure.Setup,
  ugWebConfiguration.DropDownOptions,
  ugWebConfiguration.DataCheck,
  ugConfiguration.TableAlias;

procedure AddFieldDef(ADataSet: TClientDataSet; const AName: string;
  AType: TFieldType; ASize: Integer = 0);
var
  LFieldDef: TFieldDef;
begin
  LFieldDef := ADataSet.FieldDefs.AddFieldDef;
  LFieldDef.Name := AName;
  LFieldDef.DataType := AType;
  LFieldDef.Size := ASize;
end;

procedure CreateEmptyDataSet(ADataSet: TClientDataSet);
begin
  if ADataSet.Active then
    ADataSet.Close;
  ADataSet.CreateDataSet;
end;

constructor TWebDataStructure.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  //字段元数据表保留分组及锁定列，关闭虚拟滚动，避免两侧缓存行不同步。
  //从表结构继承此设置；不影响生成模块中的业务数据表格。
  gridColumns.ClientEvents.UniEvents.Values['beforeInit'] :=
    'function beforeInit(sender, config){config.bufferedRenderer=false;}';

  cdsTables.FieldDefs.Clear;
  AddFieldDef(cdsTables, 'fdGuid', ftWideString, 64);
  AddFieldDef(cdsTables, 'fdTableName', ftWideString, 80);
  AddFieldDef(cdsTables, 'fdParent', ftWideString, 64);
  AddFieldDef(cdsTables, 'fdEpithet', ftWideString, 2);
  AddFieldDef(cdsTables, 'fdAssociationMethod', ftWideString, 20);
  AddFieldDef(cdsTables, 'fdCriteria1', ftWideString, 100);
  AddFieldDef(cdsTables, 'fdCriteria2', ftWideString, 100);
  AddFieldDef(cdsTables, 'fdCriteria3', ftWideString, 100);
  CreateEmptyDataSet(cdsTables);

  cdsColumns.FieldDefs.Clear;
  AddFieldDef(cdsColumns, 'fdRECNO', ftInteger);
  AddFieldDef(cdsColumns, 'fdTABLE_GUID', ftWideString, 64);
  AddFieldDef(cdsColumns, 'fdEpithet', ftWideString, 2);
  AddFieldDef(cdsColumns, 'fdTABLE_NAME', ftWideString, 256);
  AddFieldDef(cdsColumns, 'fdCOLUMN_NAME', ftWideString, 80);
  AddFieldDef(cdsColumns, 'fdSELECT', ftBoolean);
  AddFieldDef(cdsColumns, 'fdGROUP', ftWideString, 80);
  AddFieldDef(cdsColumns, 'fdOBJECT_TYPE', ftWideString, 80);
  AddFieldDef(cdsColumns, 'fdCOLUMN_TYPENAME', ftWideString, 80);
  AddFieldDef(cdsColumns, 'fdCOLUMN_PRECISION', ftInteger);
  AddFieldDef(cdsColumns, 'fdCOLUMN_SCAL', ftInteger);
  AddFieldDef(cdsColumns, 'fdCOLUMN_LENGTH', ftInteger);
  AddFieldDef(cdsColumns, 'fdCAPTION', ftWideString, 255);
  AddFieldDef(cdsColumns, 'fdGUID', ftWideString, 64);
  AddFieldDef(cdsColumns, 'fdDropDownOptions', ftWideString, 4000);
  AddFieldDef(cdsColumns, 'fdDataCheck', ftWideString, 4000);
  CreateEmptyDataSet(cdsColumns);

  cdsTypesetting.FieldDefs.Clear;
  AddFieldDef(cdsTypesetting, 'fdGUID', ftWideString, 64);
  AddFieldDef(cdsTypesetting, 'fdCOLUMN_NAME', ftWideString, 80);
  AddFieldDef(cdsTypesetting, 'fdCAPTION', ftWideString, 255);
  AddFieldDef(cdsTypesetting, 'fdGROUP', ftWideString, 80);
  CreateEmptyDataSet(cdsTypesetting);
  DefaultColumnOrder;
end;

procedure TWebDataStructure.btAppendClick(Sender: TObject);
var
  LSetup: TWebDataStructureSetup;
  LParentGuid, LParentAlias, LParentTable: string;
begin
  if Trim(DataNodeName) = '' then
    raise Exception.Create('请先选择数据节点。');
  LParentGuid := '';
  LParentAlias := '';
  LParentTable := '';
  if not cdsTables.IsEmpty then
  begin
    LParentGuid := cdsTables.FieldByName('fdGuid').AsString;
    LParentAlias := cdsTables.FieldByName('fdEpithet').AsString;
    LParentTable := cdsTables.FieldByName('fdTableName').AsString;
  end;
  LSetup := TWebDataStructureSetup.Create(UniApplication);
  try
    LSetup.PrepareNew(DataNodeName, NextTableAlias, LParentGuid,
      LParentAlias, LParentTable);
    LSetup.OnClose := TableSetupClose;
    LSetup.FreeOnClose := True;
    LSetup.ShowModal;
  except
    LSetup.Free;
    raise;
  end;
end;

procedure TWebDataStructure.btDeleteClick(Sender: TObject);
var
  LGuid: string;
begin
  if cdsTables.IsEmpty then
    Exit;
  LGuid := cdsTables.FieldByName('fdGuid').AsString;
  DeleteTableData(LGuid);
  cdsTables.Delete;
end;

procedure TWebDataStructure.btEditorClick(Sender: TObject);
var
  LSetup: TWebDataStructureSetup;
  LGuid, LParentGuid, LParentAlias, LParentTable: string;
begin
  if cdsTables.IsEmpty then
    Exit;
  if cdsTables.State in dsEditModes then cdsTables.Post;
  LGuid := cdsTables.FieldByName('fdGuid').AsString;
  LParentGuid := cdsTables.FieldByName('fdParent').AsString;
  LParentAlias := ''; LParentTable := '';
  if LParentGuid <> '' then
  begin
    try
      if not cdsTables.Locate('fdGuid', LParentGuid, []) then
        raise Exception.Create('找不到关联父表，原配置未更改。');
      LParentAlias := cdsTables.FieldByName('fdEpithet').AsString;
      LParentTable := cdsTables.FieldByName('fdTableName').AsString;
    finally
      cdsTables.Locate('fdGuid', LGuid, []);
    end;
  end;
  LSetup := TWebDataStructureSetup.Create(UniApplication);
  try
    LSetup.PrepareEdit(DataNodeName, LParentAlias, LParentTable, cdsTables);
    LSetup.OnClose := TableSetupClose;
    LSetup.FreeOnClose := True;
    LSetup.ShowModal;
  except
    LSetup.Free;
    raise;
  end;
end;

function TWebDataStructure.NextTableAlias: string;
var
  I: Integer;
  B: TBookmark;
begin
  B:=cdsTables.GetBookmark;
  cdsTables.DisableControls;
  try
    for I:=0 to 701 do
    begin
      if I<26 then Result:=Chr(Ord('a')+I)
      else Result:=Chr(Ord('a')+(I-26) div 26)+Chr(Ord('a')+(I-26) mod 26);
      if not cdsTables.Locate('fdEpithet',Result,[loCaseInsensitive]) then Exit;
    end;
    raise Exception.Create('没有可用的数据表别名。');
  finally
    if cdsTables.BookmarkValid(B) then cdsTables.GotoBookmark(B);
    cdsTables.FreeBookmark(B);cdsTables.EnableControls;
  end;
end;

function TWebDataStructure.DefaultObjectType(const ATypeName: string): string;
var
  LType: string;
begin
  LType := UpperCase(ATypeName);
  if (Pos('BOOL', LType) > 0) or (LType = 'BIT') then
    Exit('check');
  if Pos('DATE', LType) > 0 then
  begin
    if Pos('TIME', LType) > 0 then
      Exit('datetime');
    Exit('date');
  end;
  if (Pos('INT', LType) > 0) or (Pos('NUM', LType) > 0) or
    (Pos('DEC', LType) > 0) or (Pos('FLOAT', LType) > 0) or
    (Pos('DOUBLE', LType) > 0) or (Pos('REAL', LType) > 0) then
    Exit('number');
  if (Pos('TEXT', LType) > 0) or (Pos('CLOB', LType) > 0) or
    (Pos('BLOB', LType) > 0) then
    Exit('memo');
  Result := 'edit';
end;

procedure TWebDataStructure.TableSetupClose(Sender: TObject;
  var Action: TCloseAction);
var
  LSetup: TWebDataStructureSetup;
  LColumns: TClientDataSet;
  LTableGuid, LColumnGuid, LColumnName, LCaption, LOldAlias, LNewAlias, V: string;
  TablesBefore, ColumnsBefore, TypesettingBefore: Variant;
  I: Integer;
  function RenameCriteria(const Value:string):string;
  var P:Integer; A,B:string;
  begin
    Result:=Value;
    P:=Pos(' = ',Value);
    if P=0 then Exit;
    A:=Trim(Copy(Value,1,P-1));B:=Trim(Copy(Value,P+3,MaxInt));
    if SameText(Copy(A,1,Length(LOldAlias)+1),LOldAlias+'.') then
      A:=LNewAlias+Copy(A,Length(LOldAlias)+1,MaxInt);
    if SameText(Copy(B,1,Length(LOldAlias)+1),LOldAlias+'.') then
      B:=LNewAlias+Copy(B,Length(LOldAlias)+1,MaxInt);
    Result:=A+' = '+B;
  end;
begin
  LSetup := TWebDataStructureSetup(Sender);
  if LSetup.ModalResult <> mrOk then
    Exit;

  if LSetup.EditingGuid <> '' then
  begin
    if not cdsTables.Locate('fdGuid', LSetup.EditingGuid, []) then
      raise Exception.Create('原数据表已不存在，未保存修改。');
    LOldAlias:=cdsTables.FieldByName('fdEpithet').AsString;
    LNewAlias:=LSetup.SelectedAlias;
    cdsTables.CheckBrowseMode;cdsColumns.CheckBrowseMode;cdsTypesetting.CheckBrowseMode;
    TablesBefore:=cdsTables.Data;ColumnsBefore:=cdsColumns.Data;TypesettingBefore:=cdsTypesetting.Data;
    cdsTables.DisableControls;cdsColumns.DisableControls;cdsTypesetting.DisableControls;
    try
    try
      cdsTables.Edit;
      cdsTables.FieldByName('fdEpithet').AsString := LNewAlias;
      cdsTables.FieldByName('fdAssociationMethod').AsString := LSetup.SelectedAssociationMethod;
      cdsTables.FieldByName('fdCriteria1').AsString := LSetup.SelectedCriteria(1);
      cdsTables.FieldByName('fdCriteria2').AsString := LSetup.SelectedCriteria(2);
      cdsTables.FieldByName('fdCriteria3').AsString := LSetup.SelectedCriteria(3);
      cdsTables.Post;
      if not SameText(LOldAlias,LNewAlias) then
      begin
        cdsTables.First;
        while not cdsTables.Eof do
        begin
          cdsTables.Edit;
          for I:=1 to 3 do
            cdsTables.FieldByName('fdCriteria'+IntToStr(I)).AsString:=
              RenameCriteria(cdsTables.FieldByName('fdCriteria'+IntToStr(I)).AsString);
          cdsTables.Post;cdsTables.Next;
        end;
      end;
      // Also repair mixed old/new prefixes left by an earlier partial rename.
      RenameTableColumns(cdsColumns,LSetup.EditingGuid,LSetup.SelectedTableName,LNewAlias);
      cdsTables.Locate('fdGuid',LSetup.EditingGuid,[]);
    except
      cdsTables.Cancel;
      cdsColumns.Cancel;cdsTypesetting.Cancel;
      cdsTables.Data:=TablesBefore;cdsColumns.Data:=ColumnsBefore;cdsTypesetting.Data:=TypesettingBefore;
      raise;
    end;
    finally
      cdsTypesetting.EnableControls;cdsColumns.EnableControls;cdsTables.EnableControls;
    end;
    DefaultColumnOrder;
    treeTables.Refresh;gridColumns.Refresh;gridTypesetting.Refresh;
    Exit;
  end;

  LTableGuid := UGMM.CreateGuid;
  cdsTables.Append;
  cdsTables.FieldByName('fdGuid').AsString := LTableGuid;
  cdsTables.FieldByName('fdTableName').AsString := LSetup.SelectedTableName;
  cdsTables.FieldByName('fdParent').AsString := LSetup.ParentGuid;
  cdsTables.FieldByName('fdEpithet').AsString := LSetup.SelectedAlias;
  if LSetup.ParentGuid <> '' then
  begin
    cdsTables.FieldByName('fdAssociationMethod').AsString :=
      LSetup.SelectedAssociationMethod;
    cdsTables.FieldByName('fdCriteria1').AsString := LSetup.SelectedCriteria(1);
    cdsTables.FieldByName('fdCriteria2').AsString := LSetup.SelectedCriteria(2);
    cdsTables.FieldByName('fdCriteria3').AsString := LSetup.SelectedCriteria(3);
  end;
  cdsTables.Post;

  LColumns := TClientDataSet.Create(nil);
  try
    UGMM.GetNodeDataColumns(DataNodeName, LSetup.SelectedTableName, LColumns);
    LColumns.First;
    while not LColumns.Eof do
    begin
      LColumnGuid := UGMM.CreateGuid;
      LColumnName := LColumns.FieldByName('COLUMN_NAME').AsString;
      LCaption := LColumns.FieldByName('COMMENTS').AsString;
      if LCaption = '' then
        LCaption := LColumnName;
      cdsColumns.Append;
      cdsColumns.FieldByName('fdRECNO').AsInteger :=
        LColumns.FieldByName('RECNO').AsInteger;
      cdsColumns.FieldByName('fdTABLE_GUID').AsString := LTableGuid;
      cdsColumns.FieldByName('fdEpithet').AsString := LSetup.SelectedAlias;
      cdsColumns.FieldByName('fdTABLE_NAME').AsString :=
        LSetup.SelectedTableName + '(' + LSetup.SelectedAlias + ')';
      cdsColumns.FieldByName('fdCOLUMN_NAME').AsString :=
        LSetup.SelectedAlias + '.' + LColumnName;
      cdsColumns.FieldByName('fdSELECT').AsBoolean := False;
      cdsColumns.FieldByName('fdOBJECT_TYPE').AsString :=
        DefaultObjectType(LColumns.FieldByName('COLUMN_TYPENAME').AsString);
      cdsColumns.FieldByName('fdCOLUMN_TYPENAME').AsString :=
        LColumns.FieldByName('COLUMN_TYPENAME').AsString;
      cdsColumns.FieldByName('fdCOLUMN_PRECISION').AsInteger :=
        LColumns.FieldByName('COLUMN_PRECISION').AsInteger;
      cdsColumns.FieldByName('fdCOLUMN_SCAL').AsInteger :=
        LColumns.FieldByName('COLUMN_SCAL').AsInteger;
      cdsColumns.FieldByName('fdCOLUMN_LENGTH').AsInteger :=
        LColumns.FieldByName('COLUMN_LENGTH').AsInteger;
      cdsColumns.FieldByName('fdCAPTION').AsString := LCaption;
      cdsColumns.FieldByName('fdGUID').AsString := LColumnGuid;
      cdsColumns.Post;
      LColumns.Next;
    end;
  finally
    LColumns.Free;
  end;
  DefaultColumnOrder;
  treeTables.Refresh;gridColumns.Refresh;gridTypesetting.Refresh;
end;

procedure TWebDataStructure.DeleteTableData(const ATableGuid: string);
var
  LColumnGuid: string;
begin
  cdsColumns.First;
  while not cdsColumns.Eof do
    if cdsColumns.FieldByName('fdTABLE_GUID').AsString = ATableGuid then
    begin
      LColumnGuid := cdsColumns.FieldByName('fdGUID').AsString;
      cdsTypesetting.First;
      while not cdsTypesetting.Eof do
        if cdsTypesetting.FieldByName('fdGUID').AsString = LColumnGuid then
          cdsTypesetting.Delete
        else
          cdsTypesetting.Next;
      cdsColumns.Delete;
    end
    else
      cdsColumns.Next;
end;

procedure TWebDataStructure.gridTypesettingColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
begin
  SetDataSetSort(cdsTypesetting, Column.FieldName, Direction);
end;

procedure TWebDataStructure.gridTypesettingTitleClick(Column: TUniDBGridColumn);
begin
  if (Column.FieldName <> 'fdCOLUMN_NAME') and
    (Column.FieldName <> 'fdCAPTION') then
    Exit;
  if SameText(FTypesettingSortField, Column.FieldName) then
    FTypesettingSortDescending := not FTypesettingSortDescending
  else
  begin
    FTypesettingSortField := Column.FieldName;
    FTypesettingSortDescending := False;
  end;
  SetDataSetSort(cdsTypesetting, FTypesettingSortField,
    FTypesettingSortDescending);
  gridTypesetting.Refresh;
end;

procedure TWebDataStructure.btDownClick(Sender: TObject);
begin
  MoveCurrentTypesetting(1);
end;

procedure TWebDataStructure.btUpClick(Sender: TObject);
begin
  MoveCurrentTypesetting(-1);
end;

procedure TWebDataStructure.MoveCurrentTypesetting(ADelta: Integer);
var
  I: Integer;
  LCurrentGuid: string;
  LCurrentValues, LAdjacentValues: array of Variant;
begin
  if (not cdsTypesetting.Active) or cdsTypesetting.IsEmpty or
    (ADelta = 0) then
    Exit;
  if cdsTypesetting.State in dsEditModes then
    cdsTypesetting.Post;
  LCurrentGuid := cdsTypesetting.FieldByName('fdGUID').AsString;
  if Pos('UgSortIndex_', cdsTypesetting.IndexName) = 1 then
  begin
    cdsTypesetting.IndexName := '';
    if LCurrentGuid <> '' then
      cdsTypesetting.Locate('fdGUID', LCurrentGuid, []);
  end;
  if ((ADelta < 0) and (cdsTypesetting.RecNo <= 1)) or
    ((ADelta > 0) and (cdsTypesetting.RecNo >= cdsTypesetting.RecordCount)) then
    Exit;

  SetLength(LCurrentValues, cdsTypesetting.FieldCount);
  SetLength(LAdjacentValues, cdsTypesetting.FieldCount);
  for I := 0 to cdsTypesetting.FieldCount - 1 do
    LCurrentValues[I] := cdsTypesetting.Fields[I].Value;

  if ADelta < 0 then
    cdsTypesetting.Prior
  else
    cdsTypesetting.Next;
  for I := 0 to cdsTypesetting.FieldCount - 1 do
    LAdjacentValues[I] := cdsTypesetting.Fields[I].Value;

  cdsTypesetting.Edit;
  for I := 0 to cdsTypesetting.FieldCount - 1 do
    cdsTypesetting.Fields[I].Value := LCurrentValues[I];
  cdsTypesetting.Post;

  if ADelta < 0 then
    cdsTypesetting.Next
  else
    cdsTypesetting.Prior;
  cdsTypesetting.Edit;
  for I := 0 to cdsTypesetting.FieldCount - 1 do
    cdsTypesetting.Fields[I].Value := LAdjacentValues[I];
  cdsTypesetting.Post;

  if ADelta < 0 then
    cdsTypesetting.Prior
  else
    cdsTypesetting.Next;
  gridTypesetting.Refresh;
end;

procedure TWebDataStructure.gridColumnsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebDataStructure.gridColumnsCellClick(Column: TUniDBGridColumn);
begin
  { UniGUI 1.90.0.1567 resolves CurrCol itself and passes the actual column. }
  if not Assigned(Column) then Exit;
  if SameText(Column.FieldName, 'fdDropDownOptions') then
    OpenDropDownOptions
  else if SameText(Column.FieldName, 'fdDataCheck') then
    OpenDataCheck;
end;

procedure TWebDataStructure.gridColumnsColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
begin
  { 数据结构页保持固定列顺序：排序回调不改数据集顺序，只恢复默认字段顺序。 }
  ShowDefaultFieldOrder;
end;

procedure TWebDataStructure.gridColumnsTitleClick(Column: TUniDBGridColumn);
begin
  ShowDefaultFieldOrder;
end;

procedure TWebDataStructure.SetDataSetSort(ADataSet: TClientDataSet;
  const AFieldName: string; ADescending: Boolean);
var
  LDescendingFields, LIndexName: string;
begin
  if (not ADataSet.Active) or (AFieldName = '') or
    (ADataSet.FindField(AFieldName) = nil) then
    Exit;
  if ADataSet.State in dsEditModes then
    ADataSet.Post;

  LIndexName := 'UgSortIndex_' + ADataSet.Name;
  ADataSet.IndexName := '';
  ADataSet.IndexDefs.Update;
  if ADataSet.IndexDefs.IndexOf(LIndexName) >= 0 then
    ADataSet.DeleteIndex(LIndexName);
  if ADescending then
    LDescendingFields := AFieldName
  else
    LDescendingFields := '';
  ADataSet.AddIndex(LIndexName, AFieldName, [], LDescendingFields, '', 0);
  ADataSet.IndexDefs.Update;
  ADataSet.IndexName := LIndexName;
  ADataSet.First;
end;

procedure TWebDataStructure.gridColumnsDblClick(Sender: TObject);
begin
  { Kept for DFM compatibility; opening is handled by the precise client
    dataIndex event so a double click cannot create two modal forms. }
end;

procedure TWebDataStructure.OpenDropDownOptions;
var
  LObjectType: string;
  LForm: TWebDropDownOptions;
begin
  if FOpeningDropDownOptions or cdsColumns.IsEmpty then Exit;
  LObjectType := cdsColumns.FieldByName('fdOBJECT_TYPE').AsString;
  if (Pos('combobox', LowerCase(LObjectType)) = 0) and
    (Pos('lookupedit', LowerCase(LObjectType)) = 0) then Exit;
  if cdsColumns.State in dsEditModes then cdsColumns.Post;
  FEditingColumnGuid := cdsColumns.FieldByName('fdGUID').AsString;
  FOpeningDropDownOptions := True;
  LForm := TWebDropDownOptions.Create(UniApplication);
  try
    LForm.DataNodeName := DataNodeName;
    LForm.Prepare(LObjectType,
      cdsColumns.FieldByName('fdCAPTION').AsString,
      cdsColumns.FieldByName('fdDropDownOptions').AsString);
    LForm.OnClose := DropDownOptionsClose;
    LForm.FreeOnClose := True;
    LForm.ShowModal;
  except
    FOpeningDropDownOptions := False;
    LForm.Free;
    raise;
  end;
end;

procedure TWebDataStructure.DropDownOptionsClose(Sender: TObject;
  var Action: TCloseAction);
begin
  FOpeningDropDownOptions := False;
  if not (Sender is TWebDropDownOptions) or
    (TWebDropDownOptions(Sender).ModalResult <> mrOk) then Exit;
  if cdsColumns.Locate('fdGUID', FEditingColumnGuid, []) then
  begin
    cdsColumns.Edit;
    cdsColumns.FieldByName('fdDropDownOptions').AsString :=
      TWebDropDownOptions(Sender).ConfiguredValue;
    cdsColumns.Post;
    gridColumns.Refresh;
  end;
end;

procedure TWebDataStructure.OpenDataCheck;
var
  LForm: TWebDataCheck;
begin
  if FOpeningDataCheck or cdsColumns.IsEmpty then Exit;
  if cdsColumns.State in dsEditModes then cdsColumns.Post;
  FEditingColumnGuid := cdsColumns.FieldByName('fdGUID').AsString;
  FOpeningDataCheck := True;
  LForm := TWebDataCheck.Create(UniApplication);
  try
    LForm.DataNodeName := DataNodeName;
    LForm.Prepare(DataNodeName,
      cdsColumns.FieldByName('fdDataCheck').AsString);
    LForm.OnClose := DataCheckClose;
    LForm.FreeOnClose := True;
    LForm.ShowModal;
  except
    FOpeningDataCheck := False;
    LForm.Free;
    raise;
  end;
end;

procedure TWebDataStructure.DataCheckClose(Sender: TObject;
  var Action: TCloseAction);
begin
  FOpeningDataCheck := False;
  if not (Sender is TWebDataCheck) or
    (TWebDataCheck(Sender).ModalResult <> mrOk) then Exit;
  if cdsColumns.Locate('fdGUID', FEditingColumnGuid, []) then
  begin
    cdsColumns.Edit;
    cdsColumns.FieldByName('fdDataCheck').AsString :=
      TWebDataCheck(Sender).ConfiguredValue;
    cdsColumns.Post;
    gridColumns.Refresh;
  end;
end;

procedure TWebDataStructure.gridColumnsDrawColumnCell(Sender: TObject; ACol, ARow: Integer; Column: TUniDBGridColumn; Attribs: TUniCellAttribs);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebDataStructure.cdsTablesAfterPost(DataSet: TDataSet);
begin
end;

procedure TWebDataStructure.cdsTablesBeforeDelete(DataSet: TDataSet);
begin
end;

procedure TWebDataStructure.cdsTablesAfterDelete(DataSet: TDataSet);
begin
end;

procedure TWebDataStructure.cdsColumnsBeforePost(DataSet: TDataSet);
begin
  if Trim(cdsColumns.FieldByName('fdGUID').AsString) = '' then
    cdsColumns.FieldByName('fdGUID').AsString := UGMM.CreateGuid;
  if Trim(cdsColumns.FieldByName('fdCAPTION').AsString) = '' then
    cdsColumns.FieldByName('fdCAPTION').AsString :=
      cdsColumns.FieldByName('fdCOLUMN_NAME').AsString;
  if Trim(cdsColumns.FieldByName('fdOBJECT_TYPE').AsString) = '' then
    cdsColumns.FieldByName('fdOBJECT_TYPE').AsString :=
      DefaultObjectType(cdsColumns.FieldByName('fdCOLUMN_TYPENAME').AsString);
  SyncCurrentColumnToTypesetting;
end;

procedure TWebDataStructure.cdsColumnsBeforeDelete(DataSet: TDataSet);
var
  LGuid: string;
begin
  if not cdsTypesetting.Active then
    Exit;
  LGuid := cdsColumns.FieldByName('fdGUID').AsString;
  if (LGuid <> '') and cdsTypesetting.Locate('fdGUID', LGuid, []) then
    cdsTypesetting.Delete;
end;

procedure TWebDataStructure.SyncCurrentColumnToTypesetting;
var
  LGuid: string;
begin
  if (not cdsColumns.Active) or cdsColumns.IsEmpty or
    (not cdsTypesetting.Active) then
    Exit;

  LGuid := cdsColumns.FieldByName('fdGUID').AsString;
  if LGuid = '' then
    Exit;

  if cdsColumns.FieldByName('fdSELECT').AsBoolean then
  begin
    if cdsTypesetting.Locate('fdGUID', LGuid, []) then
      cdsTypesetting.Edit
    else
      cdsTypesetting.Append;
    cdsTypesetting.FieldByName('fdGUID').AsString := LGuid;
    cdsTypesetting.FieldByName('fdCOLUMN_NAME').AsString :=
      cdsColumns.FieldByName('fdCOLUMN_NAME').AsString;
    cdsTypesetting.FieldByName('fdCAPTION').AsString :=
      cdsColumns.FieldByName('fdCAPTION').AsString;
    cdsTypesetting.FieldByName('fdGROUP').AsString :=
      cdsColumns.FieldByName('fdGROUP').AsString;
    cdsTypesetting.Post;
  end
  else if cdsTypesetting.Locate('fdGUID', LGuid, []) then
    cdsTypesetting.Delete;
end;

function TWebDataStructure.CheckConfigure: Boolean;
begin
  Result := inherited CheckConfigure;
end;

procedure TWebDataStructure.DefaultColumnOrder;
begin
  if cdsColumns.Active then
  begin
    cdsColumns.IndexName:='';
    cdsColumns.IndexFieldNames:='fdEpithet;fdRECNO';
    FColumnsSortField:='';FColumnsSortDescending:=False;
  end;
end;

procedure TWebDataStructure.ShowDefaultFieldOrder;
begin
  DefaultColumnOrder;
  gridColumns.Refresh;
end;

procedure TWebDataStructure.RepairColumnAliases;
var
  B:TBookmark;
  ColumnsBefore,TypesettingBefore:Variant;
begin
  if not cdsTables.Active or not cdsColumns.Active or not cdsTypesetting.Active then Exit;
  cdsColumns.CheckBrowseMode;cdsTypesetting.CheckBrowseMode;
  ColumnsBefore:=cdsColumns.Data;TypesettingBefore:=cdsTypesetting.Data;
  B:=cdsTables.GetBookmark;
  cdsTables.DisableControls;cdsColumns.DisableControls;cdsTypesetting.DisableControls;
  try
    try
      cdsTables.First;
      while not cdsTables.Eof do
      begin
        RenameTableColumns(cdsColumns,cdsTables.FieldByName('fdGuid').AsString,
          cdsTables.FieldByName('fdTableName').AsString,
          cdsTables.FieldByName('fdEpithet').AsString);
        cdsTables.Next;
      end;
    except
      cdsColumns.Cancel;cdsTypesetting.Cancel;
      cdsColumns.Data:=ColumnsBefore;cdsTypesetting.Data:=TypesettingBefore;
      raise;
    end;
  finally
    if cdsTables.BookmarkValid(B) then cdsTables.GotoBookmark(B);
    cdsTables.FreeBookmark(B);
    cdsTypesetting.EnableControls;cdsColumns.EnableControls;cdsTables.EnableControls;
  end;
end;

procedure TWebDataStructure.LoadConfigure(AJSON: TJSONObject);
begin
  inherited LoadConfigure(AJSON);
  RepairColumnAliases;
  DefaultColumnOrder;
end;

procedure TWebDataStructure.SaveConfigure(AJSON: TJSONObject);
begin
  inherited SaveConfigure(AJSON);
end;

procedure TWebDataStructure.CurrentAction(APageActionType: TPageActionType);
begin
  inherited CurrentAction(APageActionType);
end;

end.
