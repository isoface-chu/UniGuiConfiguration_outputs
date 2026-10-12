unit ugWebConfiguration.NormalSetting.SetupImportFrames;


interface

uses
  System.SysUtils, System.Classes, System.Variants, System.JSON,
  Vcl.Controls, Data.DB, Datasnap.DBClient,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniEdit, uniBasicGrid, uniDBGrid,
  ugWebCustBaseForm,
  ugWebConfiguration.NormalSetting.SelectRunFrame;

type
  // 导入窗体（扩充项）：配置“导入”下拉按钮之下的子项。
  // 每行 = 序号（排序用）+ 菜单标题 + 来源查询窗体 + 允许多选开关。
  TWebNormalSettingSetupImportFrames = class(TWebCustBaseForm)
    pTop: TUniContainerPanel;
    lbCaption: TUniLabel;
    edCaption: TUniEdit;
    tbAdd: TUniButton;
    tbDelete: TUniButton;
    tbUp: TUniButton;
    tbDown: TUniButton;
    tbPick: TUniButton;
    pButton: TUniContainerPanel;
    btOk: TUniButton;
    btCancel: TUniButton;
    gridItems: TUniDBGrid;
    cdsItems: TClientDataSet;
    dsItems: TDataSource;
    procedure btOkClick(Sender: TObject);
    procedure btCancelClick(Sender: TObject);
    procedure tbAddClick(Sender: TObject);
    procedure tbDeleteClick(Sender: TObject);
    procedure tbUpClick(Sender: TObject);
    procedure tbDownClick(Sender: TObject);
    procedure tbPickClick(Sender: TObject);
    procedure edCaptionExit(Sender: TObject);
    procedure cdsItemsAfterScroll(DataSet: TDataSet);
  private
    FConfiguredValue: string;
    FSyncing: Boolean;
    procedure BuildDataSet;
    procedure SyncCaptionEdit;
    function CurrentSort: Integer;
    procedure CommitCaption;
    procedure SwapRows(ASortA, ASortB: Integer);
    procedure MoveCurrent(ADelta: Integer);
    function RowCount: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(const AValue: string);
    property ConfiguredValue: string read FConfiguredValue;
  end;

implementation

{$R *.dfm}

const
  CSortColumn = 'fdSort';
  CMultiSelectColumn = 'fdMultiSelect';

constructor TWebNormalSettingSetupImportFrames.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BuildDataSet;
end;

procedure TWebNormalSettingSetupImportFrames.BuildDataSet;
begin
  cdsItems.Close;
  cdsItems.FieldDefs.Clear;
  cdsItems.FieldDefs.Add(CSortColumn, ftInteger);
  cdsItems.FieldDefs.Add('fdCaption', ftWideString, 255);
  cdsItems.FieldDefs.Add('fdFrame', ftWideString, 255);
  cdsItems.FieldDefs.Add(CMultiSelectColumn, ftBoolean);
  cdsItems.CreateDataSet;
  // 按序号排序：上移/下移只交换序号，列表与保存顺序都由它决定。
  cdsItems.IndexFieldNames := CSortColumn;
end;

function TWebNormalSettingSetupImportFrames.RowCount: Integer;
begin
  Result := cdsItems.RecordCount;
end;

function TWebNormalSettingSetupImportFrames.CurrentSort: Integer;
begin
  Result := 0;
  if cdsItems.IsEmpty then Exit;
  Result := cdsItems.FieldByName(CSortColumn).AsInteger;
end;

procedure TWebNormalSettingSetupImportFrames.SyncCaptionEdit;
begin
  FSyncing := True;
  try
    if cdsItems.IsEmpty then
      edCaption.Text := ''
    else
      edCaption.Text := cdsItems.FieldByName('fdCaption').AsString;
  finally
    FSyncing := False;
  end;
end;

procedure TWebNormalSettingSetupImportFrames.CommitCaption;
begin
  if FSyncing or cdsItems.IsEmpty then Exit;
  if cdsItems.FieldByName('fdCaption').AsString = edCaption.Text then Exit;
  cdsItems.Edit;
  cdsItems.FieldByName('fdCaption').AsString := edCaption.Text;
  cdsItems.Post;
end;

procedure TWebNormalSettingSetupImportFrames.Prepare(const AValue: string);
var
  LRoot: TJSONValue;
  LItems: TJSONArray;
  LItem: TJSONObject;
  I: Integer;
  function ItemStr(AItem: TJSONObject; const AKey: string): string;
  var
    LValue: TJSONValue;
  begin
    Result := '';
    if not Assigned(AItem) then Exit;
    LValue := AItem.GetValue(AKey);
    if Assigned(LValue) and not (LValue is TJSONNull) then Result := LValue.Value;
  end;
begin
  FConfiguredValue := '';
  cdsItems.DisableControls;
  try
    cdsItems.EmptyDataSet;
    if Trim(AValue) <> '' then
    begin
      LRoot := TJSONObject.ParseJSONValue(AValue);
      if not Assigned(LRoot) then
        raise Exception.Create('导入窗体配置不是有效的 JSON。');
      try
        if LRoot is TJSONArray then
          LItems := TJSONArray(LRoot)
        else if LRoot is TJSONObject then
          LItems := TJSONObject(LRoot).GetValue('items') as TJSONArray
        else
          LItems := nil;
        if not Assigned(LItems) then
          raise Exception.Create('导入窗体配置缺少 items 列表。');
        for I := 0 to LItems.Count - 1 do
        begin
          LItem := LItems.Items[I] as TJSONObject;
          if not Assigned(LItem) then Continue;
          cdsItems.Append;
          cdsItems.FieldByName(CSortColumn).AsInteger := I + 1;
          cdsItems.FieldByName('fdCaption').AsString := ItemStr(LItem, 'caption');
          cdsItems.FieldByName('fdFrame').AsString := ItemStr(LItem, 'frame');
          cdsItems.FieldByName(CMultiSelectColumn).AsBoolean :=
            (Trim(ItemStr(LItem, 'multiSelect')) = '') or SameText(ItemStr(LItem, 'multiSelect'), 'true');
          cdsItems.Post;
        end;
      finally
        LRoot.Free;
      end;
    end;
    if cdsItems.IsEmpty then
    begin
      cdsItems.Append;
      cdsItems.FieldByName(CSortColumn).AsInteger := 1;
      cdsItems.FieldByName(CMultiSelectColumn).AsBoolean := True;
      cdsItems.Post;
    end;
    cdsItems.First;
  finally
    cdsItems.EnableControls;
  end;
  SyncCaptionEdit;
end;

procedure TWebNormalSettingSetupImportFrames.btOkClick(Sender: TObject);
var
  LItems: TJSONArray;
  LItem: TJSONObject;
  LCaption, LFrame: string;
  LAny: Boolean;
begin
  CommitCaption; // 编辑框里刚输入、还没失焦的标题也要算数
  if cdsItems.State in dsEditModes then cdsItems.Post;
  LAny := False;
  LItems := TJSONArray.Create;
  try
    cdsItems.DisableControls;
    try
      cdsItems.First;
      while not cdsItems.Eof do
      begin
        LCaption := Trim(cdsItems.FieldByName('fdCaption').AsString);
        LFrame := Trim(cdsItems.FieldByName('fdFrame').AsString);
        if (LCaption = '') and (LFrame = '') then
        begin
          cdsItems.Next;
          Continue; // 整行空白视为未配置
        end;
        if LCaption = '' then
          raise Exception.Create('第 ' + IntToStr(CurrentSort) + ' 行的菜单标题不能为空。');
        if LFrame = '' then
          raise Exception.Create('第 ' + IntToStr(CurrentSort) + ' 行还没有选择查询窗体。');
        LItem := TJSONObject.Create;
        LItem.AddPair('caption', LCaption);
        LItem.AddPair('frame', LFrame);
        LItem.AddPair('multiSelect', TJSONBool.Create(cdsItems.FieldByName(CMultiSelectColumn).AsBoolean));
        LItems.AddElement(LItem);
        LAny := True;
        cdsItems.Next;
      end;
    finally
      cdsItems.EnableControls;
    end;
    if not LAny then
      FConfiguredValue := ''
    else
    begin
      LItem := TJSONObject.Create;
      try
        LItem.AddPair('items', LItems);
        LItems := nil; // 所有权交给 LItem
        FConfiguredValue := LItem.ToJSON;
      finally
        LItem.Free;
      end;
    end;
  finally
    LItems.Free;
  end;
  ModalResult := mrOk;
end;

procedure TWebNormalSettingSetupImportFrames.btCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TWebNormalSettingSetupImportFrames.tbAddClick(Sender: TObject);
var
  LMax: Integer;
begin
  CommitCaption;
  LMax := 0;
  cdsItems.DisableControls;
  try
    cdsItems.First;
    while not cdsItems.Eof do
    begin
      if cdsItems.FieldByName(CSortColumn).AsInteger > LMax then
        LMax := cdsItems.FieldByName(CSortColumn).AsInteger;
      cdsItems.Next;
    end;
  finally
    cdsItems.EnableControls;
  end;
  cdsItems.Append;
  cdsItems.FieldByName(CSortColumn).AsInteger := LMax + 1;
  cdsItems.FieldByName(CMultiSelectColumn).AsBoolean := True;
  cdsItems.Post;
  cdsItems.Locate(CSortColumn, LMax + 1, []);
  SyncCaptionEdit;
  edCaption.SetFocus;
end;

procedure TWebNormalSettingSetupImportFrames.tbDeleteClick(Sender: TObject);
var
  LSort: Integer;
begin
  CommitCaption;
  if cdsItems.IsEmpty then Exit;
  LSort := CurrentSort;
  cdsItems.Delete;
  if cdsItems.IsEmpty then
  begin
    cdsItems.Append;
    cdsItems.FieldByName(CSortColumn).AsInteger := 1;
    cdsItems.FieldByName(CMultiSelectColumn).AsBoolean := True;
    cdsItems.Post;
  end
  else if LSort > 0 then
    cdsItems.Locate(CSortColumn, LSort, []);
  SyncCaptionEdit;
end;

procedure TWebNormalSettingSetupImportFrames.SwapRows(ASortA, ASortB: Integer);
var
  LCaption: string;
  LFrame: string;
  LMulti: Boolean;
begin
  // 交换两行的内容（序号不动）：稳定、与数据集游标/索引状态无关
  cdsItems.DisableControls;
  try
    if not cdsItems.Locate(CSortColumn, ASortB, []) then Exit;
    LCaption := cdsItems.FieldByName('fdCaption').AsString;
    LFrame := cdsItems.FieldByName('fdFrame').AsString;
    LMulti := cdsItems.FieldByName(CMultiSelectColumn).AsBoolean;
    if not cdsItems.Locate(CSortColumn, ASortA, []) then Exit;
    cdsItems.Edit;
    cdsItems.FieldByName('fdCaption').AsString := LCaption;
    cdsItems.FieldByName('fdFrame').AsString := LFrame;
    cdsItems.FieldByName(CMultiSelectColumn).AsBoolean := LMulti;
    cdsItems.Post;
  finally
    cdsItems.EnableControls;
  end;
end;

procedure TWebNormalSettingSetupImportFrames.MoveCurrent(ADelta: Integer);
var
  LSort, LTarget: Integer;
  LCaption: string;
  LFrame: string;
  LMulti: Boolean;
begin
  CommitCaption;
  if cdsItems.IsEmpty then Exit;
  LSort := CurrentSort;
  if LSort <= 0 then Exit;
  LTarget := LSort + ADelta;
  if (LTarget < 1) or (LTarget > RowCount) then Exit;
  // 目标行的内容与当前行互换
  SwapRows(LSort, LTarget);
  cdsItems.Locate(CSortColumn, LTarget, []);
  SyncCaptionEdit;
end;

procedure TWebNormalSettingSetupImportFrames.tbUpClick(Sender: TObject);
begin
  MoveCurrent(-1);
end;

procedure TWebNormalSettingSetupImportFrames.tbDownClick(Sender: TObject);
begin
  MoveCurrent(1);
end;

procedure TWebNormalSettingSetupImportFrames.tbPickClick(Sender: TObject);
var
  LPicker: TWebNormalSettingSelectRunFrame;
begin
  CommitCaption;
  if cdsItems.IsEmpty then Exit;
  LPicker := TWebNormalSettingSelectRunFrame.Create(UniApplication);
  try
    LPicker.Prepare(cdsItems.FieldByName('fdFrame').AsString);
    if LPicker.ShowModal = mrOk then
    begin
      cdsItems.Edit;
      cdsItems.FieldByName('fdFrame').AsString := LPicker.SelectedFrame;
      cdsItems.Post;
    end;
  finally
    LPicker.Free;
  end;
end;

procedure TWebNormalSettingSetupImportFrames.edCaptionExit(Sender: TObject);
begin
  // 只在失焦时提交一次：避免逐键刷新（loading data 闪烁/卡顿）
  CommitCaption;
  gridItems.Refresh;
end;

procedure TWebNormalSettingSetupImportFrames.cdsItemsAfterScroll(DataSet: TDataSet);
begin
  SyncCaptionEdit;
end;

end.
