unit ugWebConfiguration.NormalSetting;


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
  TWebNormalSetting = class(TWebConfigurationBase)
    gridNormalSetting: TUniDBGrid;
    pHiddenPanel: TUniHiddenPanel;
    edValue: TUniComboBox;
    cdsNormalSetting: TClientDataSet;
    dsNormalSetting: TDataSource;
    procedure gridNormalSettingKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure gridNormalSettingSelectionChange(Sender: TObject);
    procedure gridNormalSettingCellClick(Sender: TObject; ACol, ARow: Integer);
    procedure gridNormalSettingColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
    procedure gridNormalSettingDrawColumnCell(Sender: TObject; ACol, ARow: Integer; Column: TUniDBGridColumn; Attribs: TUniCellAttribs);
    procedure edValueKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edValueClick(Sender: TObject);
    procedure edValueTriggerEvent(Sender: TObject; AButtonId: Integer);
  private
    FSettings: TJSONObject;
    FOriginalSettings: TJSONObject;
    FModuleType: string;
    FSelectedButtons: string;
    FSortField: string;
    FSortDescending: Boolean;
    FEditorSetupType: string;
    FMainColumns: TClientDataSet;
    FDetailColumns: TClientDataSet;
    { 数据结构「排版」：记录区布局对话框首次打开时按它预填顺序/标题/组别。 }
    FTypesetting: TClientDataSet;
    FEditingSettingName: string;
    FOpeningFieldEditor: Boolean;
    FLoadedDocument: Boolean;
    FApplyingLoadedSettings: Boolean;
    FLoadedSettingNames: TStringList;
    FChangedSettingNames: TStringList;
    procedure AddSetting(ASort: Integer; const AGroup, AName, ACaption,
      ASetupType, ASupport, ADefault, AExplain: string;
      AAllowNull: Boolean = True);
    procedure BuildSettingCatalog;
    procedure ApplyLoadedSettings;
    function SupportsCurrentContext(const ASupport: string): Boolean;
    procedure cdsNormalSettingFilterRecord(DataSet: TDataSet;
      var Accept: Boolean);
    procedure ConfigureValueEditor;
    procedure SetDataSetSort(const AFieldName: string;
      ADescending: Boolean);
    function SourceColumnsForCurrent: TClientDataSet;
    procedure FieldEditorClose(Sender: TObject; var Action: TCloseAction);
    procedure cdsNormalSettingBeforePost(DataSet: TDataSet);
    function ExactNameExists(AList: TStringList;
      const AName: string): Boolean;
    function ExactJsonNameExists(AObject: TJSONObject;
      const AName: string): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetContext(const AModuleType, ASelectedButtons: string);
    procedure SetSourceColumns(AMainColumns, ADetailColumns,
      ATypesetting: TClientDataSet);
    function CheckConfigure: Boolean; override;
    procedure LoadConfigure(AJSON: TJSONObject); override;
    procedure SaveConfigure(AJSON: TJSONObject); override;
    procedure CurrentAction(APageActionType: TPageActionType); override;
  end;

implementation

{$R *.dfm}

uses
  uniGUIApplication,
  ugWebConfiguration.NormalSetting.SelectField,
  ugWebConfiguration.NormalSetting.MultiSelectField,
  ugWebConfiguration.NormalSetting.SetupAutoNumber,
  ugWebConfiguration.NormalSetting.SetupUniqueFields,
  ugWebConfiguration.NormalSetting.SetupImportFrames,
  ugWebConfiguration.NormalSetting.SetupRecordLayout,
  ugWebConfiguration.NormalSetting.ApprovalRules,
  ugWebConfiguration.NormalSetting.SelectRunFrame;

constructor TWebNormalSetting.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSettings := TJSONObject.Create;
  FOriginalSettings := TJSONObject.Create;
  FLoadedSettingNames := TStringList.Create;
  FChangedSettingNames := TStringList.Create;
  { 原版分组顺序为 基础设置 / 基础设置.表格 / 基础设置.字段 / 数据结构 / 从表结构；
    ExtJS 分组默认按分组名重排，这里在分组完成后用固定顺序的 sorterFn 还原。
    全部包在 try/catch 中：任何异常都不会影响分组本身。 }
  gridNormalSetting.ClientEvents.ExtEvents.Values['afterrender'] :=
    'function afterrender(grid){try{'
    + 'var o={"基础设置":1,"基础设置.表格":2,"基础设置.字段":3,"数据结构":4,"从表结构":5};'
    + 'var s=grid.getStore();if(!s)return;'
    + 'function apply(){try{var d=s.getData();if(!d||typeof d.getGrouper!=="function")return;'
    + 'var g=d.getGrouper();if(!g||!g.property)return;'
    + 'g.sorterFn=function(x,y){var i=o[x.get("fdGroup")],j=o[y.get("fdGroup")];'
    + 'if(i===undefined||i===null)i=99;if(j===undefined||j===null)j=99;return i-j;};'
    + 's.group();}catch(e){}}'
    + 'apply();s.on("load",apply);}catch(e){}}';
  cdsNormalSetting.FieldDefs.Clear;
  cdsNormalSetting.FieldDefs.Add('fdSort', ftInteger);
  cdsNormalSetting.FieldDefs.Add('fdGroup', ftWideString, 80);
  cdsNormalSetting.FieldDefs.Add('fdName', ftWideString, 120);
  cdsNormalSetting.FieldDefs.Add('fdCaption', ftWideString, 120);
  cdsNormalSetting.FieldDefs.Add('fdSetupType', ftWideString, 80);
  cdsNormalSetting.FieldDefs.Add('fdValue', ftWideString, 4000);
  cdsNormalSetting.FieldDefs.Add('fdSupportmodule', ftWideString, 255);
  cdsNormalSetting.FieldDefs.Add('fdDefault', ftWideString, 255);
  cdsNormalSetting.FieldDefs.Add('fdAllowNull', ftBoolean);
  cdsNormalSetting.FieldDefs.Add('fdExplain', ftWideString, 500);
  cdsNormalSetting.FieldDefs.Add('fdComeIntoEffect', ftBoolean);
  cdsNormalSetting.CreateDataSet;
  cdsNormalSetting.OnFilterRecord := cdsNormalSettingFilterRecord;
  BuildSettingCatalog;
  cdsNormalSetting.BeforePost := cdsNormalSettingBeforePost;
  ConfigureValueEditor;
end;

destructor TWebNormalSetting.Destroy;
begin
  FChangedSettingNames.Free;
  FLoadedSettingNames.Free;
  FOriginalSettings.Free;
  FSettings.Free;
  inherited Destroy;
end;

procedure TWebNormalSetting.cdsNormalSettingBeforePost(DataSet: TDataSet);
begin
  if FLoadedDocument and not FApplyingLoadedSettings and
    (Trim(DataSet.FieldByName('fdName').AsString) <> '') and
    not ExactNameExists(FChangedSettingNames,
      DataSet.FieldByName('fdName').AsString) then
    FChangedSettingNames.Add(DataSet.FieldByName('fdName').AsString);
end;

function TWebNormalSetting.ExactNameExists(AList: TStringList;
  const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to AList.Count - 1 do
    if AList[I] = AName then
      Exit(True);
end;

function TWebNormalSetting.ExactJsonNameExists(AObject: TJSONObject;
  const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if not Assigned(AObject) then
    Exit;
  for I := 0 to AObject.Count - 1 do
    if AObject.Pairs[I].JsonString.Value = AName then
      Exit(True);
end;

procedure TWebNormalSetting.gridNormalSettingKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = 13) and not cdsNormalSetting.IsEmpty then
  begin
    if cdsNormalSetting.State in dsEditModes then
      cdsNormalSetting.Post;
    Key := 0;
  end;
end;

procedure TWebNormalSetting.gridNormalSettingSelectionChange(Sender: TObject);
begin
  if not cdsNormalSetting.IsEmpty then
  begin
    edValue.Text := cdsNormalSetting.FieldByName('fdValue').AsString;
    ConfigureValueEditor;
  end;
end;

procedure TWebNormalSetting.gridNormalSettingCellClick(Sender: TObject; ACol, ARow: Integer);
begin
  if not cdsNormalSetting.IsEmpty then
    ConfigureValueEditor;
end;

procedure TWebNormalSetting.gridNormalSettingColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
begin
  if not Assigned(Column) or (Column.FieldName = '') then
    Exit;
  FSortField := Column.FieldName;
  FSortDescending := Direction;
  SetDataSetSort(FSortField, FSortDescending);
  { UniGUI completes the sort request and reloads when necessary itself. }
end;

procedure TWebNormalSetting.SetDataSetSort(const AFieldName: string;
  ADescending: Boolean);
const
  CIndexName = 'UgSortIndex_cdsNormalSetting';
var
  LDescendingFields, LFields: string;
begin
  if (not cdsNormalSetting.Active) or (AFieldName = '') or
    (cdsNormalSetting.FindField(AFieldName) = nil) then
    Exit;
  if cdsNormalSetting.State in dsEditModes then
    cdsNormalSetting.Post;
  { Group values are not unique. Without fdSort a Post can move a row among
    equal keys while the browser still addresses it by its previous RecNo. }
  LFields := AFieldName;
  if not SameText(AFieldName, 'fdSort') then
    LFields := LFields + ';fdSort';
  if ADescending then LDescendingFields := AFieldName
  else LDescendingFields := '';
  if (cdsNormalSetting.IndexName = CIndexName) and
    SameText(cdsNormalSetting.IndexDefs.Find(CIndexName).Fields, LFields) and
    (cdsNormalSetting.IndexDefs.Find(CIndexName).DescFields =
      LDescendingFields) then
    Exit;

  { TClientDataSet.IndexFieldNames does not understand the ':D' suffix used
    by some data-set implementations.  It treats "fdGroup:D" as a literal
    field name, which is why the grouped grid failed during the first Next. }
  cdsNormalSetting.IndexName := '';
  cdsNormalSetting.IndexDefs.Update;
  if cdsNormalSetting.IndexDefs.IndexOf(CIndexName) >= 0 then
    cdsNormalSetting.DeleteIndex(CIndexName);
  if ADescending then
    LDescendingFields := AFieldName
  else
    LDescendingFields := '';
  cdsNormalSetting.AddIndex(CIndexName, LFields, [],
    LDescendingFields, '', 0);
  cdsNormalSetting.IndexDefs.Update;
  cdsNormalSetting.IndexName := CIndexName;
end;

procedure TWebNormalSetting.gridNormalSettingDrawColumnCell(Sender: TObject; ACol, ARow: Integer; Column: TUniDBGridColumn; Attribs: TUniCellAttribs);
begin
  { Retain the DFM appearance.  The handler is preserved because the original
    frame also supplied it and UniGUI invokes it while grouped rows render. }
end;

procedure TWebNormalSetting.edValueKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = 13) and not cdsNormalSetting.IsEmpty then
  begin
    cdsNormalSetting.Edit;
    cdsNormalSetting.FieldByName('fdValue').AsString := edValue.Text;
    cdsNormalSetting.Post;
  end;
end;

procedure TWebNormalSetting.edValueClick(Sender: TObject);
var
  LSetupType: string;
begin
  if cdsNormalSetting.IsEmpty then
    Exit;
  LSetupType := cdsNormalSetting.FieldByName('fdSetupType').AsString;
  { Field settings use a dedicated selector instead of combo-box Items.
    Keep ordinary combo boxes untouched here, otherwise rebuilding their
    Items from OnClick makes UniGUI close the drop-down immediately. }
  if SameText(LSetupType, 'SelectField') or
    SameText(LSetupType, 'MultiSelectField') or
    SameText(LSetupType, 'SetupAutoNumber') or
    SameText(LSetupType, 'SetupUniqueFields') or
    SameText(LSetupType, 'SetupImportFrames') or
    SameText(LSetupType, 'SetupRecordLayout') or
    SameText(LSetupType, 'ApprovalRules') or
    SameText(LSetupType, 'SelectRunFrame') then
    edValueTriggerEvent(Sender, 0);
end;

procedure TWebNormalSetting.SetSourceColumns(AMainColumns,
  ADetailColumns, ATypesetting: TClientDataSet);
begin
  FMainColumns := AMainColumns;
  FDetailColumns := ADetailColumns;
  FTypesetting := ATypesetting;
end;

function TWebNormalSetting.SourceColumnsForCurrent: TClientDataSet;
begin
  // “从表结构”分组统一引用从表字段，包含“关联从表”（原版如此）。
  Result := FMainColumns;
  if not cdsNormalSetting.IsEmpty and
    SameText(cdsNormalSetting.FieldByName('fdGroup').AsString,
      '从表结构') then
    Result := FDetailColumns;
end;

procedure TWebNormalSetting.edValueTriggerEvent(Sender: TObject;
  AButtonId: Integer);
var
  LSetupType, LValue: string;
  LColumns: TClientDataSet;
  LSelect: TWebNormalSettingSelectField;
  LMulti: TWebNormalSettingMultiSelectField;
  LAutoNumber: TWebNormalSettingSetupAutoNumber;
  LUniqueFields: TWebNormalSettingSetupUniqueFields;
  LImportFrames: TWebNormalSettingSetupImportFrames;
  LRecordLayout: TWebNormalSettingSetupRecordLayout;
  LApprovalRules: TWebNormalSettingApprovalRules;
  LRunFrame: TWebNormalSettingSelectRunFrame;
begin
  if FOpeningFieldEditor then Exit;
  if cdsNormalSetting.IsEmpty then Exit;
  if cdsNormalSetting.State in dsEditModes then cdsNormalSetting.Post;
  LSetupType := cdsNormalSetting.FieldByName('fdSetupType').AsString;
  if not SameText(LSetupType, 'SelectField') and
    not SameText(LSetupType, 'MultiSelectField') and
    not SameText(LSetupType, 'SetupAutoNumber') and
    not SameText(LSetupType, 'SetupUniqueFields') and
    not SameText(LSetupType, 'SetupImportFrames') and
    not SameText(LSetupType, 'SetupRecordLayout') and
    not SameText(LSetupType, 'ApprovalRules') and
    not SameText(LSetupType, 'SelectRunFrame') then Exit;
  LColumns := SourceColumnsForCurrent;
  if not SameText(LSetupType, 'SelectRunFrame') and
    (not Assigned(LColumns) or not LColumns.Active or LColumns.IsEmpty) then
    raise Exception.Create('请先在数据结构页选择至少一个字段。');
  FOpeningFieldEditor := True;
  FEditingSettingName := cdsNormalSetting.FieldByName('fdName').AsString;
  LValue := cdsNormalSetting.FieldByName('fdValue').AsString;
  if SameText(LSetupType, 'SelectField') then
  begin
    LSelect := TWebNormalSettingSelectField.Create(UniApplication);
    try
      LSelect.Prepare(LColumns, LValue);
      LSelect.OnClose := FieldEditorClose;
      LSelect.FreeOnClose := True;
      LSelect.ShowModal;
    except
      FOpeningFieldEditor := False;
      LSelect.Free;
      raise;
    end;
  end
  else if SameText(LSetupType, 'MultiSelectField') then
  begin
    LMulti := TWebNormalSettingMultiSelectField.Create(UniApplication);
    try
      LMulti.Prepare(LColumns, LValue);
      LMulti.OnClose := FieldEditorClose;
      LMulti.FreeOnClose := True;
      LMulti.ShowModal;
    except
      FOpeningFieldEditor := False;
      LMulti.Free;
      raise;
    end;
  end
  else if SameText(LSetupType, 'SetupAutoNumber') then
  begin
    LAutoNumber := TWebNormalSettingSetupAutoNumber.Create(UniApplication);
    try
      LAutoNumber.DataNodeName := DataNodeName;
      LAutoNumber.Prepare(LColumns, LValue, FModuleType);
      LAutoNumber.OnClose := FieldEditorClose;
      LAutoNumber.FreeOnClose := True;
      LAutoNumber.ShowModal;
    except
      FOpeningFieldEditor := False;
      LAutoNumber.Free;
      raise;
    end;
  end
  else if SameText(LSetupType, 'SetupUniqueFields') then
  begin
    LUniqueFields := TWebNormalSettingSetupUniqueFields.Create(UniApplication);
    try
      LUniqueFields.Prepare(LColumns, LValue,
        not SameText(FEditingSettingName, '从表唯一'));
      LUniqueFields.OnClose := FieldEditorClose;
      LUniqueFields.FreeOnClose := True;
      LUniqueFields.ShowModal;
    except
      FOpeningFieldEditor := False;
      LUniqueFields.Free;
      raise;
    end;
  end
  else if SameText(LSetupType, 'SetupRecordLayout') then
  begin
    LRecordLayout := TWebNormalSettingSetupRecordLayout.Create(UniApplication);
    try
      LRecordLayout.Prepare(LColumns, FTypesetting, LValue);
      LRecordLayout.OnClose := FieldEditorClose;
      LRecordLayout.FreeOnClose := True;
      LRecordLayout.ShowModal;
    except
      FOpeningFieldEditor := False;
      LRecordLayout.Free;
      raise;
    end;
  end
  else if SameText(LSetupType, 'SetupImportFrames') then
  begin
    LImportFrames := TWebNormalSettingSetupImportFrames.Create(UniApplication);
    try
      LImportFrames.Prepare(LValue);
      LImportFrames.OnClose := FieldEditorClose;
      LImportFrames.FreeOnClose := True;
      LImportFrames.ShowModal;
    except
      FOpeningFieldEditor := False;
      LImportFrames.Free;
      raise;
    end;
  end
  else if SameText(LSetupType, 'ApprovalRules') then
  begin
    LApprovalRules := TWebNormalSettingApprovalRules.Create(UniApplication);
    try
      LApprovalRules.Prepare(LColumns, LValue);
      LApprovalRules.OnClose := FieldEditorClose;
      LApprovalRules.FreeOnClose := True;
      LApprovalRules.ShowModal;
    except
      FOpeningFieldEditor := False;
      LApprovalRules.Free;
      raise;
    end;
  end
  else
  begin
    LRunFrame := TWebNormalSettingSelectRunFrame.Create(UniApplication);
    try
      LRunFrame.Prepare(LValue);
      LRunFrame.OnClose := FieldEditorClose;
      LRunFrame.FreeOnClose := True;
      LRunFrame.ShowModal;
    except
      FOpeningFieldEditor := False;
      LRunFrame.Free;
      raise;
    end;
  end;
end;

procedure TWebNormalSetting.FieldEditorClose(Sender: TObject;
  var Action: TCloseAction);
var
  LValue: string;
begin
  FOpeningFieldEditor := False;
  if not (Sender is TUniForm) or (TUniForm(Sender).ModalResult <> mrOk) then Exit;
  if Sender is TWebNormalSettingSelectField then
    LValue := TWebNormalSettingSelectField(Sender).SelectedField
  else if Sender is TWebNormalSettingMultiSelectField then
    LValue := TWebNormalSettingMultiSelectField(Sender).SelectedFields
  else if Sender is TWebNormalSettingSetupAutoNumber then
    LValue := TWebNormalSettingSetupAutoNumber(Sender).ConfiguredValue
  else if Sender is TWebNormalSettingSetupUniqueFields then
    LValue := TWebNormalSettingSetupUniqueFields(Sender).ConfiguredValue
  else if Sender is TWebNormalSettingSetupRecordLayout then
    LValue := TWebNormalSettingSetupRecordLayout(Sender).ConfiguredValue
  else if Sender is TWebNormalSettingSetupImportFrames then
    LValue := TWebNormalSettingSetupImportFrames(Sender).ConfiguredValue
  else if Sender is TWebNormalSettingApprovalRules then
    LValue := TWebNormalSettingApprovalRules(Sender).ConfiguredValue
  else if Sender is TWebNormalSettingSelectRunFrame then
    LValue := TWebNormalSettingSelectRunFrame(Sender).SelectedFrame
  else
    Exit;
  if cdsNormalSetting.Locate('fdName', FEditingSettingName, []) then
  begin
    cdsNormalSetting.Edit;
    cdsNormalSetting.FieldByName('fdValue').AsString := LValue;
    cdsNormalSetting.Post;
    edValue.Text := LValue;
    gridNormalSetting.Refresh;
  end;
end;

procedure TWebNormalSetting.AddSetting(ASort: Integer; const AGroup, AName,
  ACaption, ASetupType, ASupport, ADefault, AExplain: string;
  AAllowNull: Boolean);
begin
  cdsNormalSetting.Append;
  cdsNormalSetting.FieldByName('fdSort').AsInteger := ASort;
  cdsNormalSetting.FieldByName('fdGroup').AsString := AGroup;
  cdsNormalSetting.FieldByName('fdName').AsString := AName;
  cdsNormalSetting.FieldByName('fdCaption').AsString := ACaption;
  cdsNormalSetting.FieldByName('fdSetupType').AsString := ASetupType;
  cdsNormalSetting.FieldByName('fdValue').AsString := ADefault;
  cdsNormalSetting.FieldByName('fdSupportmodule').AsString := ASupport;
  cdsNormalSetting.FieldByName('fdDefault').AsString := ADefault;
  cdsNormalSetting.FieldByName('fdAllowNull').AsBoolean := AAllowNull;
  cdsNormalSetting.FieldByName('fdExplain').AsString := AExplain;
  cdsNormalSetting.FieldByName('fdComeIntoEffect').AsBoolean := True;
  cdsNormalSetting.Post;
end;

procedure TWebNormalSetting.BuildSettingCatalog;
const
  CAllModules = 'mtMultiple;mtTree;mtReport;mtMasterSlave;mtDetail;mtListEditor;';
begin
  cdsNormalSetting.DisableControls;
  try
    cdsNormalSetting.EmptyDataSet;
    // 分组与原版对齐：基础设置 / 基础设置.表格 / 基础设置.字段 / 数据结构 / 从表结构。
    AddSetting(1001, '基础设置', '编辑窗体', '编辑窗体', 'SelectRunFrame',
      'btAppend;btEditor;&&mtMultiple;mtTree;mtDetail;', '',
      '弹出编辑子窗体,进行新增修改数据.', False);
    AddSetting(1002, '基础设置', '查询窗体', '查询窗体', 'SelectRunFrame',
      'btQuery;&&mtMasterSlave;mtDetail;', '',
      '弹出查询子窗体,进行主表数据选择.', False);
    AddSetting(1003, '基础设置', '文本类型', '文本类型', 'CharCase',
      'btQuery;&&mtMultiple;mtReport;||mtEditor;||btAppend;btEditor;&&mtMasterSlave;',
      'Normal', '模块界面中录入文本大小写。', False);
    // 原版支持串为 'btDelete;&&mtMultiple;mtDetail;'（需先配删除按钮）。为支持“导入明细”
    // 需要的查询窗体多选（查询模块没有 btDelete），这里放开按钮条件：mtMultiple/mtDetail 均可配。
    AddSetting(1004, '基础设置.表格', '表格多选', '表格多选', 'Boolean',
      'mtMultiple;mtDetail;', 'True', '批量选择删除；查询窗体多选后可作为导入明细的来源', False);
    AddSetting(1005, '基础设置', '界面布局', '界面布局', 'Layout',
      'mtMultiple;mtListEditor;', 'Top', '查询条件区域显示在顶部或左侧。', False);
    AddSetting(1006, '基础设置', '层级权限', '层级权限', 'Boolean',
      'mtMultiple;mtTree;mtReport;mtMasterSlave;mtDetail;mtListEditor;', 'True',
      '数据查询层级权限: 可查看当前用户、同属部门、同属部门及下级部门', False);
    AddSetting(1007, '基础设置.表格', '表格过滤', '表格过滤', 'Boolean',
      'mtMultiple;mtReport;mtDetail;', 'True', '增加表格过滤功能', False);
    AddSetting(1008, '基础设置.表格', '表格复制', '表格复制', 'Boolean',
      'mtMultiple;mtReport;mtTree;mtMasterSlave;mtDetail;', 'True', '增加表格复制功能', False);
    // 精灵扩充项（用户 2026-09-13 提出，2026-09-14 落地）：原版无“序号”设置；
    // 勾选后表格 Options 带 dgRowNumbers，UniGUI 以 Ext RowNumberer 渲染序号列。
    { 2026-09-19：列表编辑（mtListEditor）也开放表格序号——它复用列表生成器的
      GridOptions，勾选后同样在 Options 里加 dgRowNumbers。 }
    AddSetting(1013, '基础设置.表格', '表格序号', '表格序号', 'Boolean',
      'mtMultiple;mtReport;mtTree;mtMasterSlave;mtDetail;mtListEditor;', 'False',
      '表格前增加序号列', False);
    // 精灵扩充项（用户 2026-09-14 场景：入库单选打单明细）：配置“导入”下拉的
    // 子项列表，每行 = 菜单标题 + 来源查询窗体 + 允许多选开关。
    AddSetting(1014, '基础设置.表格', '导入窗体', '导入窗体', 'SetupImportFrames',
      'mtDetail;mtMasterSlave;', '', '配置导入下拉菜单的子项（标题/查询窗体/允许多选）', False);
    AddSetting(1009, '基础设置.字段', '字段排序', '字段排序', 'SortingOptions',
      'mtMultiple;mtReport;mtDetail;', 'Normal', '增加字段排序功能', False);
    AddSetting(1010, '基础设置.字段', '字段宽度', '字段宽度', 'Boolean',
      'mtMultiple;mtReport;mtTree;mtMasterSlave;mtDetail;', 'True',
      '增加用户可自定义字段宽度【有记忆功能】', False);
    AddSetting(1011, '基础设置.字段', '字段移动', '字段移动', 'Boolean',
      'mtMultiple;mtReport;mtTree;mtMasterSlave;mtDetail;', 'True',
      '增加用户可自定义字段位置【有记忆功能】', False);
    AddSetting(1012, '基础设置.字段', '字段显隐', '字段显隐', 'Boolean',
      'mtMultiple;mtReport;mtTree;mtMasterSlave;mtDetail;', 'True',
      '增加用户可自定义字段是否隐藏【有记忆功能】', False);

    AddSetting(1015, '基础设置', '记录区布局', '记录区布局', 'SetupRecordLayout',
      { 宿主 2026-09-22：mtMasterSlave 也要记录区布局。生成侧已接通（位置/列数/列宽/字段顺序/
        标题/跨列/分组/显隐），未配置该区块时记录区保持原版三分栏逐字节不变。 }
      'mtListEditor;mtMasterSlave;', '',
      '记录区的字段集、顺序、标题、分组、跨列、宽度，以及位置/列数（不配置时按列表可见字段与排版）。');
    AddSetting(2000, '数据结构', '关联字段', '关联字段', 'SelectField',
      'mtDetail;mtMasterSlave;mtListEditor;', '', '主表与从表关联的字段,和查询窗体关联的字段', False);
    AddSetting(2001, '数据结构', '自动编号', '自动编号', 'SetupAutoNumber',
      'btAppend;btImport;&&mtMultiple;mtTree;mtMasterSlave;mtListEditor;', '',
      '设置数据库自增、最大号或 GUID 编号。');
    AddSetting(2002, '数据结构', '主表唯一', '主表唯一', 'SetupUniqueFields',
      'btAppend;btEditor;btImport;&&mtMultiple;mtMasterSlave;mtListEditor;||mtTree;', '',
      '多字段验证主表记录的唯一性。');
    AddSetting(2003, '数据结构', '编辑次数', '编辑次数', 'SelectField',
      'mtMasterSlave;', 'a.EditCount', '数据修改的次数。');
    AddSetting(2004, '数据结构', '单据日期', '单据日期', 'SelectField',
      'mtMasterSlave;', 'a.InputDate', '单据录入的日期。');
    AddSetting(2005, '数据结构', '上级字段', '上级字段', 'SelectField',
      'mtTree;', '', '树形模块的上级字段。', False);
    AddSetting(2006, '数据结构', '排序字段', '排序字段', 'SelectField',
      'mtTree;', '',
      '树形模块的排序字段。', False);
    AddSetting(2007, '数据结构', '录入部门', '录入部门', 'SelectField',
      'btQuery;btAppend;&&mtMultiple;mtTree;mtReport;mtMasterSlave;mtDetail;mtListEditor;',
      'a.CreateDepartment', '有录入数据和有报表查询的功能模块[存储录入部门]');
    AddSetting(2008, '数据结构', '录入用户', '录入用户', 'SelectField',
      'btQuery;btAppend;&&mtMultiple;mtTree;mtMasterSlave;mtListEditor;',
      'a.CreateUser', '存储录入用户。');
    AddSetting(2009, '数据结构', '录入时间', '录入时间', 'SelectField',
      'btAppend;btFirst;btPrior;btNext;btLast;&&mtMultiple;mtTree;mtMasterSlave;mtDetail;mtListEditor;',
      'a.CreateTime', '有录入数据和有报表查询的功能模块[存储录入时间]');
    AddSetting(2010, '数据结构', '修改部门', '修改部门', 'SelectField',
      'btAppend;btEditor;&&mtMultiple;mtTree;mtMasterSlave;mtListEditor;',
      'a.EditorDepartment', '存储修改部门。');
    AddSetting(2011, '数据结构', '修改用户', '修改用户', 'SelectField',
      'btAppend;btEditor;&&mtMultiple;mtTree;mtMasterSlave;mtListEditor;',
      'a.EditorUser', '存储修改用户。');
    AddSetting(2012, '数据结构', '修改时间', '修改时间', 'SelectField',
      'btAppend;btEditor;&&mtMultiple;mtTree;mtMasterSlave;mtListEditor;',
      'a.EditorTime', '存储修改时间。');
    AddSetting(2013, '数据结构', '审批规则', '审批规则', 'ApprovalRules',
      'btAudit;btUnAudit;btRepulse;&&mtMasterSlave;', '', '配置审批规则。');
    AddSetting(2014, '数据结构', '非空字段', '非空字段', 'MultiSelectField',
      'btAppend;btEditor;&&mtMasterSlave;mtMultiple;mtTree;mtListEditor;||mtEditor;', '', '模块必填字段。');
    AddSetting(2015, '数据结构', '隐藏字段-主表', '隐藏字段-主表',
      'MultiSelectField', 'mtMasterSlave;mtEditor;mtMultiple;mtTree;mtReport;mtDetail;mtListEditor;', '',
      '不在列表及顶部记录区显示；mtListEditor 的自动编号主键可隐藏但仍参与保存。', True);

    // 关联从表在原版“从表结构”中，且对 mtDetail 可见；排序键小于记录编号以保持组内顺序。
    AddSetting(2016, '从表结构', '关联从表', '关联从表', 'SelectField',
      'mtDetail;mtMasterSlave;mtListEditor;', '', '主表关联从表的字段', False);
    AddSetting(3000, '从表结构', '记录编号', '记录编号', 'SetupAutoNumber',
      'btAppend;btEditor;btImport;btSave;&&mtDetail;mtListEditor;', '',
      '可获取自动编号或用GUID编号,记录编号一般用以从表在数据库中的唯一编号', False);
    AddSetting(3001, '从表结构', '明细编号', '明细编号', 'SelectField',
      'btAppend;btEditor;btImport;&&mtMasterSlave;mtListEditor;', 'a.Line',
      '主从模块中的明细表行号。', False);
    AddSetting(3002, '从表结构', '从表唯一', '从表唯一', 'SetupUniqueFields',
      'btAppend;btEditor;btImport;btSave;&&mtMasterSlave;mtDetail;mtListEditor;', '',
      '多字段验证记录的唯一性', False);
    // 原版 mtDetail 不支持从表非空：仅 mtMasterSlave。
    AddSetting(3003, '从表结构', '从表非空', '从表非空', 'MultiSelectField',
      'btAppend;btEditor;btImport;btSave;&&mtMasterSlave;mtListEditor;', '',
      '从表必填字段。', False);
    AddSetting(3004, '从表结构', '隐藏字段-从表', '隐藏字段-从表',
      'MultiSelectField', 'mtMasterSlave;mtEditor;mtMultiple;mtTree;mtReport;mtDetail;mtListEditor;', '',
      '作用在主键字段由数据库自动编号，且无需界面显示', True);
    cdsNormalSetting.First;
  finally
    cdsNormalSetting.EnableControls;
  end;
end;

function TWebNormalSetting.SupportsCurrentContext(
  const ASupport: string): Boolean;
var
  LClauses: TArray<string>;
  LClause, LButtons, LModules, LButton: string;
  LAndPos: Integer;
begin
  if (Trim(ASupport) = '') or (Trim(FModuleType) = '') then
    Exit(True);
  Result := False;
  LClauses := ASupport.Split(['||']);
  for LClause in LClauses do
  begin
    LAndPos := Pos('&&', LClause);
    if LAndPos > 0 then
    begin
      LButtons := Copy(LClause, 1, LAndPos - 1);
      LModules := Copy(LClause, LAndPos + 2, MaxInt);
      if Pos(';' + FModuleType + ';', ';' + LModules) = 0 then
        Continue;
      for LButton in LButtons.Split([';']) do
        if (LButton <> '') and
          (Pos(';' + LButton + ';', ';' + FSelectedButtons) > 0) then
          Exit(True);
    end
    else if Pos(';' + FModuleType + ';', ';' + LClause) > 0 then
      Exit(True);
  end;
end;

procedure TWebNormalSetting.cdsNormalSettingFilterRecord(DataSet: TDataSet;
  var Accept: Boolean);
begin
  Accept := SupportsCurrentContext(
    DataSet.FieldByName('fdSupportmodule').AsString);
end;

procedure TWebNormalSetting.SetContext(const AModuleType,
  ASelectedButtons: string);
begin
  { Checkbox edits do not change applicability. Do not refilter or move the
    current row when the wizard supplies the same context again. }
  if (FModuleType = AModuleType) and (FSelectedButtons = ASelectedButtons) then
    Exit;
  if cdsNormalSetting.State in dsEditModes then
  begin
    { A bound UniGUI editor can leave the current row in edit state merely by
      being initialized. The save-time flush is not proof of a user change;
      suppress change tracking for this passive Post. Real UI AutoPost events
      have already passed through BeforePost outside this guard. }
    FApplyingLoadedSettings := True;
    try
      cdsNormalSetting.Post;
    finally
      FApplyingLoadedSettings := False;
    end;
  end;
  FModuleType := AModuleType;
  FSelectedButtons := ASelectedButtons;
  cdsNormalSetting.Filtered := False;
  cdsNormalSetting.Filtered := Trim(FModuleType) <> '';
  cdsNormalSetting.First;
  FEditorSetupType := '';
  ConfigureValueEditor;
  gridNormalSetting.Refresh;
end;

procedure TWebNormalSetting.ConfigureValueEditor;
var
  LSetupType: string;
begin
  if cdsNormalSetting.IsEmpty then
  begin
    FEditorSetupType := '';
    edValue.Items.Clear;
    Exit;
  end;
  LSetupType := cdsNormalSetting.FieldByName('fdSetupType').AsString;
  if SameText(FEditorSetupType, LSetupType) then
    Exit;
  FEditorSetupType := LSetupType;
  edValue.Items.BeginUpdate;
  try
    edValue.Items.Clear;
    if SameText(LSetupType, 'Boolean') then
    begin
      edValue.Items.Add('True');
      edValue.Items.Add('False');
    end
    else if SameText(LSetupType, 'CharCase') then
    begin
      edValue.Items.Add('Normal');
      edValue.Items.Add('Upper');
      edValue.Items.Add('Lower');
    end
    else if SameText(LSetupType, 'Layout') then
    begin
      edValue.Items.Add('Top');
      edValue.Items.Add('Left');
    end
    else if SameText(LSetupType, 'SortingOptions') then
    begin
      edValue.Items.Add('Normal');
      edValue.Items.Add('ColumnSort');
      edValue.Items.Add('MultiColumnSort');
    end;
  finally
    edValue.Items.EndUpdate;
  end;
end;

procedure TWebNormalSetting.ApplyLoadedSettings;
var
  I, LSort: Integer;
  LName: string;
begin
  FApplyingLoadedSettings := True;
  cdsNormalSetting.DisableControls;
  try
    cdsNormalSetting.Filtered := False;
    cdsNormalSetting.First;
    while not cdsNormalSetting.Eof do
    begin
      LName := cdsNormalSetting.FieldByName('fdName').AsString;
      cdsNormalSetting.Edit;
      if Assigned(FSettings.GetValue(LName)) then
      begin
        cdsNormalSetting.FieldByName('fdValue').AsString :=
          FSettings.GetValue(LName).Value;
        cdsNormalSetting.FieldByName('fdComeIntoEffect').AsBoolean := True;
      end
      else
      begin
        cdsNormalSetting.FieldByName('fdValue').AsString :=
          cdsNormalSetting.FieldByName('fdDefault').AsString;
        { Loading an existing document must not activate settings which were
          absent from that document. New configurations still retain the
          catalog defaults established by BuildSettingCatalog because they do
          not pass through ApplyLoadedSettings. }
        cdsNormalSetting.FieldByName('fdComeIntoEffect').AsBoolean := False;
      end;
      cdsNormalSetting.Post;
      cdsNormalSetting.Next;
    end;

    LSort := 9000;
    for I := 0 to FSettings.Count - 1 do
    begin
      LName := FSettings.Pairs[I].JsonString.Value;
      if not cdsNormalSetting.Locate('fdName', LName, []) then
      begin
        AddSetting(LSort, '兼容设置', LName, LName, 'Text', '',
          FSettings.Pairs[I].JsonValue.Value, '从已有 JSON 保留的扩展设置。');
        Inc(LSort);
      end;
    end;
    cdsNormalSetting.Filtered := Trim(FModuleType) <> '';
    cdsNormalSetting.First;
    FEditorSetupType := '';
    ConfigureValueEditor;
  finally
    cdsNormalSetting.EnableControls;
    FApplyingLoadedSettings := False;
  end;
end;

function TWebNormalSetting.CheckConfigure: Boolean;
var
  LBookmark: TBookmark;
begin
  Result := inherited CheckConfigure;
  if not Result then
    Exit;
  LBookmark := cdsNormalSetting.GetBookmark;
  cdsNormalSetting.DisableControls;
  try
    cdsNormalSetting.First;
    while not cdsNormalSetting.Eof do
    begin
      if cdsNormalSetting.FieldByName('fdComeIntoEffect').AsBoolean and
        not cdsNormalSetting.FieldByName('fdAllowNull').AsBoolean and
        (Trim(cdsNormalSetting.FieldByName('fdValue').AsString) = '') then
        Exit(False);
      cdsNormalSetting.Next;
    end;
  finally
    if cdsNormalSetting.BookmarkValid(LBookmark) then
      cdsNormalSetting.GotoBookmark(LBookmark);
    cdsNormalSetting.FreeBookmark(LBookmark);
    cdsNormalSetting.EnableControls;
  end;
end;

procedure TWebNormalSetting.LoadConfigure(AJSON: TJSONObject);
var
  I: Integer;
  LValue: TJSONValue;
begin
  LValue := AJSON.GetValue('TWebNormalSetting');
  FSettings.Free;
  if LValue is TJSONObject then
    FSettings := TJSONObject.ParseJSONValue(LValue.ToJSON) as TJSONObject
  else
    FSettings := TJSONObject.Create;
  FOriginalSettings.Free;
  FOriginalSettings := TJSONObject.ParseJSONValue(FSettings.ToJSON)
    as TJSONObject;
  FLoadedDocument := True;
  FLoadedSettingNames.Clear;
  FChangedSettingNames.Clear;
  for I := 0 to FSettings.Count - 1 do
    FLoadedSettingNames.Add(FSettings.Pairs[I].JsonString.Value);
  ApplyLoadedSettings;
end;

procedure TWebNormalSetting.SaveConfigure(AJSON: TJSONObject);
var
  I: Integer;
  LPair: TJSONPair;
  LWasFiltered: Boolean;
begin
  if cdsNormalSetting.State in dsEditModes then
  begin
    { A bound UniGUI editor can leave the current row in edit state merely by
      being initialized. Do not treat this save-time flush as a user edit. }
    FApplyingLoadedSettings := True;
    try
      cdsNormalSetting.Post;
    finally
      FApplyingLoadedSettings := False;
    end;
  end;
  { Before the module page has been committed there is no valid applicability
    context.  Preserve the loaded object instead of accidentally emitting the
    complete catalog during the earlier wizard steps. }
  if Trim(FModuleType) = '' then
  begin
    LPair := AJSON.RemovePair('TWebNormalSetting');
    LPair.Free;
    AJSON.AddPair('TWebNormalSetting',
      TJSONObject.ParseJSONValue(FSettings.ToJSON));
    Exit;
  end;
  if not Assigned(FSettings) then
    FSettings := TJSONObject.Create;
  cdsNormalSetting.DisableControls;
  LWasFiltered := cdsNormalSetting.Filtered;
  try
    cdsNormalSetting.Filtered := False;
    cdsNormalSetting.First;
    while not cdsNormalSetting.Eof do
    begin
      { Update only catalog keys owned by this wizard. Unknown settings loaded
        from a newer host/DLL remain in FSettings and survive the round trip. }
      LPair := FSettings.RemovePair(
        cdsNormalSetting.FieldByName('fdName').AsString);
      LPair.Free;
      if cdsNormalSetting.FieldByName('fdComeIntoEffect').AsBoolean and
        (not FLoadedDocument or
         ExactNameExists(FLoadedSettingNames,
           cdsNormalSetting.FieldByName('fdName').AsString) or
         (ExactNameExists(FChangedSettingNames,
           cdsNormalSetting.FieldByName('fdName').AsString) and
          (Trim(cdsNormalSetting.FieldByName('fdValue').AsString) <> ''))) and
        SupportsCurrentContext(
          cdsNormalSetting.FieldByName('fdSupportmodule').AsString) then
        FSettings.AddPair(cdsNormalSetting.FieldByName('fdName').AsString,
          cdsNormalSetting.FieldByName('fdValue').AsString);
      cdsNormalSetting.Next;
    end;
  finally
    cdsNormalSetting.Filtered := LWasFiltered;
    cdsNormalSetting.EnableControls;
  end;
  { The UniGUI grid can submit a freshly displayed empty editor as an active
    value even when the user did not touch it.  Enforce compatibility at the
    document boundary using the immutable object loaded from ConfigStream:
    an empty setting which did not exist there is a no-op and must not be
    introduced.  Existing keys may still be explicitly cleared, and genuine
    new field selections are non-empty. }
  if FLoadedDocument then
    for I := FSettings.Count - 1 downto 0 do
      if (Trim(FSettings.Pairs[I].JsonValue.Value) = '') and
        (((SameText(FModuleType, 'mtReport') or
           SameText(FModuleType, 'mtTree')) and
          (FSettings.Pairs[I].JsonString.Value = '隐藏字段-主表')) or
         not ExactJsonNameExists(FOriginalSettings,
           FSettings.Pairs[I].JsonString.Value)) then
      begin
        LPair := FSettings.RemovePair(
          FSettings.Pairs[I].JsonString.Value);
        LPair.Free;
      end;
  LPair := AJSON.RemovePair('TWebNormalSetting');
  LPair.Free;
  AJSON.AddPair('TWebNormalSetting',
    TJSONObject.ParseJSONValue(FSettings.ToJSON));
end;

procedure TWebNormalSetting.CurrentAction(APageActionType: TPageActionType);
begin
  inherited CurrentAction(APageActionType);
end;

end.
