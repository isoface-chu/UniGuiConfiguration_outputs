unit ugWebConfiguration.FunctionButton;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame, uniTimer,
  ugWebConfigurationBase, Vcl.Forms;

type
  TWebFunctionButton = class(TWebConfigurationBase)
    Tree: TUniDBTreeGrid;
    cds: TClientDataSet;
    ds: TDataSource;
    procedure TreeDrawColumnCell(Sender: TObject; ACol, ARow: Integer; Column: TUniDBGridColumn; Attribs: TUniCellAttribs);
    procedure TreeAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);
    procedure cdsBeforePost(DataSet: TDataSet);
    procedure cdsAfterPost(DataSet: TDataSet);
  private
    FSelectedButtons: string;
    FUpdatingSelection: Boolean;
    FPendingName: string;
    FPendingSelect: Boolean;
    FSelectionTimer: TUniTimer;
    procedure SelectionTimerTick(Sender: TObject);
    procedure FlushSelection;
    procedure ApplySelection(const AName, AParent: string; ASelect: Boolean);
    procedure RebuildSelectedButtons;
    procedure UpdateGroupSelection;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetModuleType(const AModuleType: string);
    function CheckConfigure: Boolean; override;
    procedure LoadConfigure(AJSON: TJSONObject); override;
    procedure SaveConfigure(AJSON: TJSONObject); override;
    procedure CurrentAction(APageActionType: TPageActionType); override;
    property SelectedButtons: string read FSelectedButtons;
  end;

implementation

{$R *.dfm}

constructor TWebFunctionButton.Create(AOwner: TComponent);
  function DisplayName(const AName: string): string;
  const
    Names: array[0..39] of string = (
      'Annex Group', 'btAnnex', 'Append Update Group', 'btCancel', 'btSave', 'btOK',
      'Audit Group', 'btAudit', 'btRepulse', 'btUnAudit', 'Editor Group',
      'btAppend', 'btDelete', 'btEditor', 'btImport', 'Form Group', 'btClose',
      'Nonius Group', 'btFirst', 'btLast', 'btNext', 'btPrior',
      'Output Group', 'btExport', 'btPrint', 'Query Group', 'btQuery', 'Serial Group', 'btDown', 'btLeft', 'btRight','btUp',
      { 明细区行操作（宿主 2026-09-21 指定 7 个基础按钮） }
      'Detail Row Group', 'btDetailAppend', 'btDetailInsert', 'btDetailDelete', 'btDetailCopy',
      'btDetailMoveUp', 'btDetailMoveDown', 'btDetailClear');
    Captions: array[0..39] of string = (
      '附件功能', '附件', '提交功能', '撤销', '保存', '确认',
      '审核功能', '审核', '撤回', '消审', '编辑功能',
      '新增', '删除', '修改', '导入', '窗体功能', '关闭',
      '导航功能', '首笔', '末笔', '后笔', '前笔',
      '输出功能', '导出', '打印', '查询功能', '查询', '排序功能', '下移', '左移', '右移', '上移',
      '明细行功能', '新增行', '插入行', '删除行', '复制行', '上移', '下移', '清空');
  var I: Integer;
  begin
    Result := AName;
    for I := Low(Names) to High(Names) do
      if SameText(AName, Names[I]) then
        Exit(Captions[I]);
  end;
  procedure AddItem(const AName, AParent, ASupport, ASort: string);
  begin
    cds.Append;
    cds.FieldByName('fdName').AsString := AName;
    cds.FieldByName('fdParent').AsString := AParent;
    cds.FieldByName('fdDisplayName').AsString := DisplayName(AName);
    cds.FieldByName('fdCaption').AsString := DisplayName(AName);
    cds.FieldByName('fdSupportmodule').AsString := ASupport;
    cds.FieldByName('fdSort').AsString := ASort;
    cds.FieldByName('fdSelect').AsBoolean := False;
    cds.Post;
  end;
  procedure AddGroup(const AName, ASupport, ASort: string);
  begin
    AddItem(AName, '', ASupport, ASort);
  end;
const
  CAllEdit = 'mtMultiple;mtTree;mtMasterSlave;mtDetail;';
  CAllOutput = 'mtMultiple;mtTree;mtReport;mtMasterSlave;mtDetail;';
begin
  inherited Create(AOwner);
  cds.FieldDefs.Clear;
  cds.FieldDefs.Add('fdImageIndex', ftInteger);
  cds.FieldDefs.Add('fdName', ftWideString, 80);
  cds.FieldDefs.Add('fdDisplayName', ftWideString, 120);
  cds.FieldDefs.Add('fdParent', ftWideString, 80);
  cds.FieldDefs.Add('fdCaption', ftWideString, 120);
  cds.FieldDefs.Add('fdSelect', ftBoolean);
  cds.FieldDefs.Add('fdShortcutkeys', ftWideString, 80);
  cds.FieldDefs.Add('fdSupportmodule', ftWideString, 255);
  cds.FieldDefs.Add('fdExplain', ftWideString, 255);
  cds.FieldDefs.Add('fdOperationassociation', ftWideString, 255);
  cds.FieldDefs.Add('fdSort', ftWideString, 32);
  cds.CreateDataSet;

  AddGroup('Query Group', 'mtMultiple;mtReport;mtMasterSlave;mtDetail;mtListEditor;', '000.000.000');
  AddItem('btQuery', 'Query Group', 'mtMultiple;mtReport;mtMasterSlave;mtDetail;mtListEditor;', '000.001.000');
  AddGroup('Nonius Group', 'mtMasterSlave;mtDetail;', '001.000.000');
  AddItem('btFirst', 'Nonius Group', 'mtMasterSlave;mtDetail;', '001.001.000');
  AddItem('btPrior', 'Nonius Group', 'mtMasterSlave;mtDetail;', '001.002.000');
  AddItem('btNext', 'Nonius Group', 'mtMasterSlave;mtDetail;', '001.003.000');
  AddItem('btLast', 'Nonius Group', 'mtMasterSlave;mtDetail;', '001.004.000');
  AddGroup('Editor Group', CAllEdit + 'mtListEditor;', '002.000.000');
  AddItem('btAppend', 'Editor Group', CAllEdit + 'mtListEditor;', '002.001.000');
  AddItem('btDelete', 'Editor Group', CAllEdit + 'mtListEditor;', '002.002.000');
  AddItem('btEditor', 'Editor Group', CAllEdit + 'mtListEditor;', '002.003.000');
  { mtListEditor 的导入：把文本/电子表格批量导入**当前列表**（原版 list editor 就是 g := gridMain），
    导入行未保存、可撤销、随保存提交。只在同窗写入下可用（只读列表下会明确拒绝）。 }
  AddItem('btImport', 'Editor Group', 'mtMultiple;mtMasterSlave;mtDetail;mtListEditor;', '002.004.000');
  AddGroup('Serial Group', 'mtTree;', '002.005.000');
  AddItem('btUp', 'Serial Group', 'mtTree;', '002.005.000');
  AddItem('btDown', 'Serial Group', 'mtTree;', '002.005.001');
  AddItem('btLeft', 'Serial Group', 'mtTree;', '002.005.002');
  AddItem('btRight', 'Serial Group', 'mtTree;', '002.005.003');
  AddGroup('Append Update Group', CAllEdit + 'mtListEditor;', '002.006.000');
  // 多选查询窗体：勾选多行后必须点“确认”提交并关闭（用户 2026-09-14 设计）
  AddItem('btOK', 'Append Update Group', 'mtMultiple;', '002.006.000');
  AddItem('btSave', 'Append Update Group', CAllEdit + 'mtListEditor;', '002.006.001');
  AddItem('btCancel', 'Append Update Group', CAllEdit + 'mtListEditor;', '002.006.002');
  { 明细行操作：mtListEditor 的明细区写入片已接通这 7 个按钮；mtMasterSlave 的明细区目前没有行按钮，
    等它的生成侧接通后再把 mtMasterSlave 加进适用列表（避免"配了不生效"）。 }
  { 明细行操作：mtListEditor 与 mtMasterSlave 的明细区都已接通这 7 个按钮（宿主 2026-09-21 指定两者都要）。 }
  AddGroup('Detail Row Group', 'mtListEditor;mtMasterSlave;', '002.007.000');
  AddItem('btDetailAppend', 'Detail Row Group', 'mtListEditor;mtMasterSlave;', '002.007.001');
  AddItem('btDetailInsert', 'Detail Row Group', 'mtListEditor;mtMasterSlave;', '002.007.002');
  AddItem('btDetailDelete', 'Detail Row Group', 'mtListEditor;mtMasterSlave;', '002.007.003');
  AddItem('btDetailCopy', 'Detail Row Group', 'mtListEditor;mtMasterSlave;', '002.007.004');
  AddItem('btDetailMoveUp', 'Detail Row Group', 'mtListEditor;mtMasterSlave;', '002.007.005');
  AddItem('btDetailMoveDown', 'Detail Row Group', 'mtListEditor;mtMasterSlave;', '002.007.006');
  AddItem('btDetailClear', 'Detail Row Group', 'mtListEditor;mtMasterSlave;', '002.007.007');
  AddGroup('Audit Group', 'mtMasterSlave;', '003.000.000');
  AddItem('btAudit', 'Audit Group', 'mtMasterSlave;', '003.001.000');
  AddItem('btUnAudit', 'Audit Group', 'mtMasterSlave;', '003.002.000');
  AddItem('btRepulse', 'Audit Group', 'mtMasterSlave;', '003.003.000');
  AddGroup('Output Group', CAllOutput + 'mtListEditor;', '004.000.000');
  AddItem('btExport', 'Output Group', 'mtMultiple;mtReport;mtDetail;mtListEditor;', '004.001.000');
  AddItem('btPrint', 'Output Group', CAllOutput + 'mtListEditor;', '004.002.000');
  AddGroup('Annex Group', CAllOutput + 'mtListEditor;', '005.000.000');
  AddItem('btAnnex', 'Annex Group', CAllOutput + 'mtListEditor;', '005.001.000');
  AddGroup('Form Group', CAllOutput + 'mtListEditor;', '006.000.000');
  AddItem('btClose', 'Form Group', CAllOutput + 'mtListEditor;', '006.001.000');
  cds.First;

  { Empty modules do not pass through LoadConfigure. Set the native tree's
    expansion state before its first data response, not only afterrender. }
  Tree.FullExpand;
  FPendingName := '';
  { Schedule ONLY after the native AutoPost has actually completed.
    A client edit callback can run before UniGUI submits the changed value. }
  FSelectionTimer := TUniTimer.Create(Self);
  FSelectionTimer.Enabled := False;
  FSelectionTimer.Interval := 1;
  FSelectionTimer.OnTimer := SelectionTimerTick;
end;

procedure TWebFunctionButton.TreeDrawColumnCell(Sender: TObject; ACol, ARow: Integer; Column: TUniDBGridColumn; Attribs: TUniCellAttribs);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebFunctionButton.TreeAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);
begin
  if SameText(EventName, '_post') then
  begin
    Tree.RefreshCurrentRow(True);
    FlushSelection;
  end;
end;

procedure TWebFunctionButton.cdsBeforePost(DataSet: TDataSet);
begin
  { 原版 cds 的 BeforePost 挂在同一个数据集上，其实现未在 DFM/字符串里保留下来；
    按钮行的字段值在本单元里都是显式赋值的，这里只保留事件挂点。 }
end;

procedure TWebFunctionButton.cdsAfterPost(DataSet: TDataSet);
begin
  { Only capture here. Apply the cascade in the separate _post request. }
  if not FUpdatingSelection then
  begin
    FPendingName := DataSet.FieldByName('fdName').AsString;
    FPendingSelect := DataSet.FieldByName('fdSelect').AsBoolean;
    if Assigned(FSelectionTimer) then FSelectionTimer.Enabled := True;
  end;
end;

procedure TWebFunctionButton.SelectionTimerTick(Sender: TObject);
begin
  FSelectionTimer.Enabled := False;
  FlushSelection;
end;

procedure TWebFunctionButton.FlushSelection;
var LName: string; LSelected: Boolean;
begin
  if FUpdatingSelection then Exit;
  if cds.State in dsEditModes then cds.Post;
  if Assigned(FSelectionTimer) then FSelectionTimer.Enabled := False;
  LName := FPendingName;
  LSelected := FPendingSelect;
  FPendingName := '';
  if LName <> '' then ApplySelection(LName, '', LSelected);
end;

procedure TWebFunctionButton.ApplySelection(const AName, AParent: string;
  ASelect: Boolean);
var
  LBookmark: TBookmark;
  LGroupName, LParentName: string;
  LSelect, LAnySelected, LHasChildren: Boolean;
begin
  if FUpdatingSelection or (AName = '') then
    Exit;

  LGroupName := AName;
  LParentName := AParent;
  LSelect := ASelect;
  LBookmark := cds.GetBookmark;
  FUpdatingSelection := True;
  cds.DisableControls;
  try
    { Locate by the immutable tree id.  This also makes the operation
      independent of whichever row the grid left current. }
    if not cds.Locate('fdName', LGroupName, []) then Exit;
    LParentName := cds.FieldByName('fdParent').AsString;
    if cds.FieldByName('fdSelect').AsBoolean <> LSelect then
    begin
      cds.Edit;
      cds.FieldByName('fdSelect').AsBoolean := LSelect;
      cds.Post;
      Tree.RefreshCurrentRow(False);
    end;
    if LGroupName.EndsWith(' Group') then
    begin
      cds.First;
      while not cds.Eof do
      begin
        if SameText(cds.FieldByName('fdParent').AsString, LGroupName) and
          (cds.FieldByName('fdSelect').AsBoolean <> LSelect) then
        begin
          cds.Edit;
          cds.FieldByName('fdSelect').AsBoolean := LSelect;
          cds.Post;
          Tree.RefreshCurrentRow(False);
        end;
        cds.Next;
      end;
    end
    else if LParentName <> '' then
    begin
      LAnySelected := False;
      LHasChildren := False;
      cds.First;
      while not cds.Eof do
      begin
        if SameText(cds.FieldByName('fdParent').AsString, LParentName) then
        begin
          LHasChildren := True;
          if cds.FieldByName('fdSelect').AsBoolean then
            LAnySelected := True;
        end;
        cds.Next;
      end;
      if LHasChildren and cds.Locate('fdName', LParentName, []) and
        (cds.FieldByName('fdSelect').AsBoolean <> LAnySelected) then
      begin
        cds.Edit;
        cds.FieldByName('fdSelect').AsBoolean := LAnySelected;
        cds.Post;
        Tree.RefreshCurrentRow(False);
      end;
    end;
  finally
    if cds.BookmarkValid(LBookmark) then
      cds.GotoBookmark(LBookmark);
    cds.FreeBookmark(LBookmark);
    FUpdatingSelection := False;
    cds.EnableControls;
  end;
  RebuildSelectedButtons;
end;

procedure TWebFunctionButton.RebuildSelectedButtons;
var
  LBookmark: TBookmark;
begin
  FSelectedButtons := '';
  LBookmark := cds.GetBookmark;
  cds.DisableControls;
  try
    cds.First;
    while not cds.Eof do
    begin
      if cds.FieldByName('fdSelect').AsBoolean and
        not cds.FieldByName('fdName').AsString.EndsWith(' Group') then
        FSelectedButtons := FSelectedButtons +
          cds.FieldByName('fdName').AsString + ';';
      cds.Next;
    end;
  finally
    if cds.BookmarkValid(LBookmark) then
      cds.GotoBookmark(LBookmark);
    cds.FreeBookmark(LBookmark);
    cds.EnableControls;
  end;
end;

procedure TWebFunctionButton.UpdateGroupSelection;
var
  LBookmark: TBookmark;
  LGroupBookmark: TBookmark;
  LGroupName: string;
  LAnySelected, LHasChildren: Boolean;
begin
  if cds.IsEmpty then
    Exit;
  LBookmark := cds.GetBookmark;
  FUpdatingSelection := True;
  try
    cds.First;
    while not cds.Eof do
    begin
      if cds.FieldByName('fdName').AsString.EndsWith(' Group') then
      begin
        LGroupBookmark := cds.GetBookmark;
        LGroupName := cds.FieldByName('fdName').AsString;
        LAnySelected := False;
        LHasChildren := False;
        cds.First;
        while not cds.Eof do
        begin
          if SameText(cds.FieldByName('fdParent').AsString, LGroupName) then
          begin
            LHasChildren := True;
            if cds.FieldByName('fdSelect').AsBoolean then
              LAnySelected := True;
          end;
          cds.Next;
        end;
        if cds.BookmarkValid(LGroupBookmark) then
        begin
          cds.GotoBookmark(LGroupBookmark);
          if cds.FieldByName('fdSelect').AsBoolean <>
            (LHasChildren and LAnySelected) then
          begin
            cds.Edit;
            cds.FieldByName('fdSelect').AsBoolean :=
              LHasChildren and LAnySelected;
            cds.Post;
          end;
        end;
        cds.FreeBookmark(LGroupBookmark);
      end;
      cds.Next;
    end;
  finally
    if cds.BookmarkValid(LBookmark) then
      cds.GotoBookmark(LBookmark);
    cds.FreeBookmark(LBookmark);
    FUpdatingSelection := False;
  end;
end;

procedure TWebFunctionButton.SetModuleType(const AModuleType: string);
begin
  FlushSelection;
  cds.Filtered := False;
  if Trim(AModuleType) <> '' then
  begin
    cds.Filter := 'fdSupportmodule LIKE ''%' + AModuleType + '%''';
    cds.Filtered := True;
  end
  else
    cds.Filter := '';
  UpdateGroupSelection;
  RebuildSelectedButtons;
  cds.First;
  Tree.Refresh;
  Tree.FullExpand;
end;

function TWebFunctionButton.CheckConfigure: Boolean;
begin
  Result := inherited CheckConfigure;
end;

procedure TWebFunctionButton.LoadConfigure(AJSON: TJSONObject);
var
  LValue: TJSONValue;
  LButtons: string;
begin
  LValue := AJSON.GetValue('TWebFunctionButton');
  if Assigned(LValue) and not (LValue is TJSONNull) then
    FSelectedButtons := LValue.Value
  else
    FSelectedButtons := '';
  LButtons := FSelectedButtons;
  cds.DisableControls;
  cds.AfterPost := nil;
  try
    cds.First;
    while not cds.Eof do
    begin
      cds.Edit;
      cds.FieldByName('fdSelect').AsBoolean :=
        Pos(';' + cds.FieldByName('fdName').AsString + ';',
          ';' + LButtons) > 0;
      cds.Post;
      cds.Next;
    end;
  finally
    cds.AfterPost := cdsAfterPost;
    cds.EnableControls;
  end;
  FSelectedButtons := LButtons;
  FPendingName := '';
  if Assigned(FSelectionTimer) then FSelectionTimer.Enabled := False;
  UpdateGroupSelection;
  Tree.FullExpand;
end;

procedure TWebFunctionButton.SaveConfigure(AJSON: TJSONObject);
var
  LPair: TJSONPair;
begin
  { Checkbox AutoPost and the auxiliary _post callback are not guaranteed to
    finish in the same browser request.  The data set is authoritative when
    the wizard saves, so rebuild the scalar value directly from its leaf rows. }
  FlushSelection;
  RebuildSelectedButtons;
  LPair := AJSON.RemovePair('TWebFunctionButton');
  LPair.Free;
  AJSON.AddPair('TWebFunctionButton', FSelectedButtons);
end;

procedure TWebFunctionButton.CurrentAction(APageActionType: TPageActionType);
begin
  inherited CurrentAction(APageActionType);
  Tree.FullExpand;
end;

end.
