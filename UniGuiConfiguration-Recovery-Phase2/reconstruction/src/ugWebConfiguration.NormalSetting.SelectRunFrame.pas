unit ugWebConfiguration.NormalSetting.SelectRunFrame;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebCustBaseForm, Vcl.Forms;

type
  TWebNormalSettingSelectRunFrame = class(TWebCustBaseForm)
    pButton: TUniContainerPanel;
    btOk: TUniButton;
    gridFrames: TUniDBGrid;
    pFilters: TUniHiddenPanel;
    cdsRunFrames: TClientDataSet;
    dsRunFrame: TDataSource;
    procedure btOkClick(Sender: TObject);
    procedure gridFramesColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
    procedure gridFramesClearFilters(Sender: TObject);
    procedure gridFramesColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);
    procedure gridFramesOnDblClick(Sender: TObject);
  private
    FSelectedFrame: string;
    FSortField: string;
    FSortDescending: Boolean;
    procedure BuildColumns;
    procedure ApplyFilters;
    function ColumnCaption(const AFieldName: string): string;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(const ASelectedFrame: string);
    property SelectedFrame: string read FSelectedFrame;
  end;

implementation

{$R *.dfm}

constructor TWebNormalSettingSelectRunFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  gridFrames.DataSource := dsRunFrame;
end;

procedure TWebNormalSettingSelectRunFrame.Prepare(
  const ASelectedFrame: string);
begin
  FSelectedFrame := ASelectedFrame;
  cdsRunFrames.Close;
  UGMM.GetAllRunFrameList(cdsRunFrames, 'WEB');
  BuildColumns;
  if not cdsRunFrames.Active or cdsRunFrames.IsEmpty then Exit;
  { GetWebSubForm resolves Caption. Accept legacy GUIDs for preselection only;
    confirmation converts them to the caption, cancellation changes nothing. }
  if Assigned(cdsRunFrames.FindField('Caption')) and
    cdsRunFrames.Locate('Caption', ASelectedFrame, []) then Exit;
  if Assigned(cdsRunFrames.FindField('RecordID')) and
    cdsRunFrames.Locate('RecordID', ASelectedFrame, []) then Exit;
  cdsRunFrames.First;
end;

procedure TWebNormalSettingSelectRunFrame.btOkClick(Sender: TObject);
begin
  if not cdsRunFrames.Active or cdsRunFrames.IsEmpty then
    raise Exception.Create('没有可选择的子窗体。');
  if not Assigned(cdsRunFrames.FindField('Caption')) then
    raise Exception.Create('子窗体列表缺少 Caption 字段。');
  if Trim(cdsRunFrames.FieldByName('Caption').AsString) = '' then
    raise Exception.Create('所选子窗体标题为空，请先设置标题。');
  FSelectedFrame := cdsRunFrames.FieldByName('Caption').AsString;
  ModalResult := mrOk;
end;

procedure TWebNormalSettingSelectRunFrame.gridFramesColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
const
  CIndexName = 'UgSortIndex_cdsRunFrames';
var
  LDescendingFields: string;
begin
  if not Assigned(Column) or (Column.FieldName = '') or
    not cdsRunFrames.Active or
    not Assigned(cdsRunFrames.FindField(Column.FieldName)) then Exit;
  if cdsRunFrames.State in dsEditModes then cdsRunFrames.Post;
  FSortField := Column.FieldName;
  FSortDescending := Direction;
  cdsRunFrames.IndexName := '';
  cdsRunFrames.IndexDefs.Update;
  if cdsRunFrames.IndexDefs.IndexOf(CIndexName) >= 0 then
    cdsRunFrames.DeleteIndex(CIndexName);
  if FSortDescending then LDescendingFields := FSortField
  else LDescendingFields := '';
  cdsRunFrames.AddIndex(CIndexName, FSortField, [],
    LDescendingFields, '', 0);
  cdsRunFrames.IndexDefs.Update;
  cdsRunFrames.IndexName := CIndexName;
  cdsRunFrames.First;
  gridFrames.Refresh;
end;

// 列标题：按字段名映射到原版“请选择子窗体”的四列，未知字段用字段名兜底
function TWebNormalSettingSelectRunFrame.ColumnCaption(const AFieldName: string): string;
begin
  if SameText(AFieldName, 'RecordID') or SameText(AFieldName, 'Guid') or
    SameText(AFieldName, 'Address') then Result := '模块地址'
  else if SameText(AFieldName, 'Caption') or SameText(AFieldName, 'Title') then Result := '模块标题'
  else if (Pos('GROUP', UpperCase(AFieldName)) > 0) or
    (Pos('CATEGORY', UpperCase(AFieldName)) > 0) or
    (Pos('TREE', UpperCase(AFieldName)) > 0) then Result := '分组类别'
  else if (Pos('USER', UpperCase(AFieldName)) > 0) or
    (Pos('DEVELOPER', UpperCase(AFieldName)) > 0) or
    (Pos('OWNER', UpperCase(AFieldName)) > 0) then Result := '开发用户'
  else Result := AFieldName;
end;

// 用户 2026-09-14：选择子窗体表格只保留“分组类别 + 模块标题”两列，全部明细不分页，
// 默认按 分组类别 + 模块标题 排序。
procedure TWebNormalSettingSelectRunFrame.BuildColumns;
var
  I: Integer;
  LField: TField;
  LColumn: TUniDBGridColumn;
  LEditor: TUniEdit;
  LGroupField, LTitleField: string;
begin
  gridFrames.Columns.Clear;
  if not cdsRunFrames.Active then Exit;
  LGroupField := '';
  LTitleField := '';
  for I := 0 to cdsRunFrames.FieldCount - 1 do
  begin
    LField := cdsRunFrames.Fields[I];
    if (LTitleField = '') and (SameText(LField.FieldName, 'Caption') or
      SameText(LField.FieldName, 'Title')) then LTitleField := LField.FieldName
    else if (LGroupField = '') and ((Pos('GROUP', UpperCase(LField.FieldName)) > 0) or
      (Pos('CATEGORY', UpperCase(LField.FieldName)) > 0) or
      (Pos('TREE', UpperCase(LField.FieldName)) > 0)) then LGroupField := LField.FieldName;
  end;
  if (LTitleField = '') and (cdsRunFrames.FieldCount > 1) then
    LTitleField := cdsRunFrames.Fields[1].FieldName;
  for I := 0 to 1 do
  begin
    if I = 0 then LField := cdsRunFrames.FindField(LGroupField)
    else LField := cdsRunFrames.FindField(LTitleField);
    if not Assigned(LField) then Continue;
    LColumn := TUniDBGridColumn(gridFrames.Columns.Add);
    LColumn.FieldName := LField.FieldName;
    if I = 0 then
    begin
      LColumn.Title.Caption := '分组类别';
      LColumn.Width := 200;
    end
    else
    begin
      LColumn.Title.Caption := '模块标题';
      LColumn.Width := 320;
    end;
    LColumn.ReadOnly := True;
    LEditor := TUniEdit.Create(Self);
    LEditor.Parent := pFilters; // 过滤编辑器必须挂到隐藏面板
    LEditor.Name := 'e' + LField.FieldName + 'Frame';
    LEditor.EmptyText := LColumn.Title.Caption + '...';
    LEditor.CharEOL := #13;
    LColumn.Filtering.Enabled := True;
    LColumn.Filtering.Editor := LEditor;
  end;
  // 默认排序：分组类别 + 模块标题
  cdsRunFrames.IndexName := '';
  if (LGroupField <> '') and (LTitleField <> '') then
    cdsRunFrames.IndexFieldNames := LGroupField + ';' + LTitleField
  else if LTitleField <> '' then
    cdsRunFrames.IndexFieldNames := LTitleField
  else
    cdsRunFrames.IndexFieldNames := '';
end;

procedure TWebNormalSettingSelectRunFrame.ApplyFilters;
var
  I: Integer;
  LValue: Variant;
  LFilter: string;
begin
  if not cdsRunFrames.Active then Exit;
  if cdsRunFrames.State in dsEditModes then cdsRunFrames.Post;
  LFilter := '';
  for I := 0 to gridFrames.Columns.Count - 1 do
  begin
    LValue := gridFrames.Columns[I].Filtering.VarValue;
    if gridFrames.Columns[I].Filtering.Enabled and (Trim(VarToStr(LValue)) <> '') then
    begin
      if LFilter <> '' then LFilter := LFilter + ' and ';
      LFilter := LFilter + gridFrames.Columns[I].FieldName + ' LIKE ' +
        QuotedStr('%' + VarToStr(LValue) + '%');
    end;
  end;
  cdsRunFrames.Filtered := False;
  cdsRunFrames.Filter := LFilter;
  cdsRunFrames.Filtered := LFilter <> '';
  if not cdsRunFrames.IsEmpty then cdsRunFrames.First;
end;

procedure TWebNormalSettingSelectRunFrame.gridFramesClearFilters(Sender: TObject);
begin
  ApplyFilters;
end;

procedure TWebNormalSettingSelectRunFrame.gridFramesColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);
begin
  ApplyFilters;
end;

procedure TWebNormalSettingSelectRunFrame.gridFramesOnDblClick(Sender: TObject);
begin
  if cdsRunFrames.Active and not cdsRunFrames.IsEmpty then
    btOkClick(nil);
end;

end.
