unit ugWebConfiguration.NormalSetting.SetupRecordLayout;


interface

uses
  System.SysUtils, System.Classes, System.Variants, System.JSON,
  Vcl.Controls, Data.DB, Datasnap.DBClient,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniLabel, uniEdit,
  uniComboBox, uniCheckBox, uniSpinEdit, uniBasicGrid, uniDBGrid,
  ugWebCustBaseForm, ugConfiguration.ListEditorLayout;

type
  { 记录区布局（mtListEditor 与 mtMasterSlave 共用）：配置记录区的字段集、顺序、标题、分组、
    跨列、宽度，以及位置(Top/Left)、列数与每列宽度。确认后写回常规设置的「记录区布局」项。
    字段来源固定是**主表字段**（cdsColumns）—— mtMasterSlave 的记录区就是主表。
    生成侧读法见共享单元 ugConfiguration.ListEditorLayout.ReadListEditorLayout。 }
  TWebNormalSettingSetupRecordLayout = class(TWebCustBaseForm)
    pTop: TUniContainerPanel;
    lbPosition: TUniLabel;
    cbPosition: TUniComboBox;
    lbColumns: TUniLabel;
    seColumns: TUniSpinEdit;
    lbFieldWidth: TUniLabel;
    seFieldWidth: TUniSpinEdit;
    cbShowGroups: TUniCheckBox;
    pButton: TUniContainerPanel;
    btOk: TUniButton;
    btCancel: TUniButton;
    gridLayout: TUniDBGrid;
    cdsRecordLayout: TClientDataSet;
    dsRecordLayout: TDataSource;
    procedure btOkClick(Sender: TObject);
    procedure tbUpClick(Sender: TObject);
    procedure tbDownClick(Sender: TObject);
  private
    FConfiguredValue: string;
    procedure BuildDataSet;
    procedure MoveCurrent(ADelta: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    { AColumns: 主表字段（cdsColumns）；AValue: 该设置已有的 JSON；
      ATypesetting 可选：数据结构「排版」数据集，用于首次打开时按排版顺序/标题/组别预填。 }
    procedure Prepare(AColumns, ATypesetting: TClientDataSet; const AValue: string);
    property ConfiguredValue: string read FConfiguredValue;
  end;

implementation

{$R *.dfm}

procedure AddLayoutFieldDef(ADataSet: TClientDataSet; const AName: string;
  AType: TFieldType; ASize: Integer = 0);
begin
  with ADataSet.FieldDefs.AddFieldDef do
  begin
    Name := AName;
    DataType := AType;
    Size := ASize;
  end;
end;

function LayoutJSONValue(AJSON: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if not Assigned(AJSON) then Exit;
  LValue := AJSON.GetValue(AName);
  if Assigned(LValue) then Result := LValue.Value;
end;

{ 字段名去掉表别名：生成侧也按同样的方式比较（a.FUnitCode → FUnitCode）。 }
function PlainLayoutField(const V: string): string;
begin
  Result := Trim(V);
  if Pos('.', Result) > 0 then Delete(Result, 1, Pos('.', Result));
end;

{ 字段在当前数据结构里是否可用：存在且已勾选。数据结构换表后遗留的旧字段会被丢弃，
  避免把"以前的字段"和"现在的字段"混在一张表里（宿主 2026-09-19 反馈）。 }
function LayoutFieldUsable(AColumns: TClientDataSet; const AField: string): Boolean;
var
  LBookmark: TBookmark;
  LWanted: string;
begin
  Result := False;
  if (AColumns = nil) or not AColumns.Active then Exit;
  LWanted := PlainLayoutField(AField);
  if LWanted = '' then Exit;
  LBookmark := AColumns.GetBookmark;
  try
    AColumns.First;
    while not AColumns.Eof do
    begin
      if SameText(PlainLayoutField(AColumns.FieldByName('fdCOLUMN_NAME').AsString),
        LWanted) then
        Exit(AColumns.FieldByName('fdSELECT').AsBoolean);
      AColumns.Next;
    end;
  finally
    if AColumns.BookmarkValid(LBookmark) then AColumns.GotoBookmark(LBookmark);
    AColumns.FreeBookmark(LBookmark);
  end;
end;

function LayoutRowExists(ADataSet: TClientDataSet; const AName: string): Boolean;
var
  LBookmark: TBookmark;
begin
  Result := False;
  LBookmark := ADataSet.GetBookmark;
  try
    ADataSet.First;
    while not ADataSet.Eof do
    begin
      if SameText(ADataSet.FieldByName('fdCOLUMN_NAME').AsString, AName) then Exit(True);
      ADataSet.Next;
    end;
  finally
    if ADataSet.BookmarkValid(LBookmark) then ADataSet.GotoBookmark(LBookmark);
    ADataSet.FreeBookmark(LBookmark);
  end;
end;

procedure TypesettingRowValues(ATypesetting: TClientDataSet; const AName: string;
  var ACaption, AGroup: string);
var
  LBookmark: TBookmark;
  LWanted, LCaption: string;
begin
  if (ATypesetting = nil) or not ATypesetting.Active then Exit;
  LWanted := PlainLayoutField(AName);
  LBookmark := ATypesetting.GetBookmark;
  try
    ATypesetting.First;
    while not ATypesetting.Eof do
    begin
      if SameText(PlainLayoutField(ATypesetting.FieldByName('fdCOLUMN_NAME').AsString),
        LWanted) then
      begin
        LCaption := Trim(ATypesetting.FieldByName('fdCAPTION').AsString);
        if LCaption <> '' then ACaption := LCaption;
        AGroup := Trim(ATypesetting.FieldByName('fdGROUP').AsString);
        Exit;
      end;
      ATypesetting.Next;
    end;
  finally
    if ATypesetting.BookmarkValid(LBookmark) then ATypesetting.GotoBookmark(LBookmark);
    ATypesetting.FreeBookmark(LBookmark);
  end;
end;

function ColumnObjectType(AColumns: TClientDataSet; const AName: string): string;
var
  LBookmark: TBookmark;
  LWanted: string;
begin
  Result := '';
  if (AColumns = nil) or not AColumns.Active then Exit;
  LWanted := PlainLayoutField(AName);
  LBookmark := AColumns.GetBookmark;
  try
    AColumns.First;
    while not AColumns.Eof do
    begin
      if SameText(PlainLayoutField(AColumns.FieldByName('fdCOLUMN_NAME').AsString),
        LWanted) then
        Exit(Trim(AColumns.FieldByName('fdOBJECT_TYPE').AsString));
      AColumns.Next;
    end;
  finally
    if AColumns.BookmarkValid(LBookmark) then AColumns.GotoBookmark(LBookmark);
    AColumns.FreeBookmark(LBookmark);
  end;
end;

function LayoutColumnStructure(const AName, AType: string; ASize: Integer): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('FieldName', AName);
  Result.AddPair('FieldType', AType);
  Result.AddPair('FieldSize', TJSONNumber.Create(ASize));
  Result.AddPair('FieldPrecision', TJSONNumber.Create(0));
end;

{ 生成 cdsRecordLayout 的 TableStructure/Data，与配置里其他数据集区块同一形状。 }
function BuildLayoutJSON(ADataSet: TClientDataSet): TJSONObject;
var
  LStructure, LData, LRow: TJSONObject;
  I, N: Integer;
begin
  Result := TJSONObject.Create;
  LStructure := TJSONObject.Create;
  LStructure.AddPair('0', LayoutColumnStructure('fdCOLUMN_NAME', 'ftWideString', 80));
  LStructure.AddPair('1', LayoutColumnStructure('fdCAPTION', 'ftWideString', 120));
  LStructure.AddPair('2', LayoutColumnStructure('fdGROUP', 'ftWideString', 60));
  LStructure.AddPair('3', LayoutColumnStructure('fdVISIBLE', 'ftBoolean', 0));
  LStructure.AddPair('4', LayoutColumnStructure('fdSPAN', 'ftInteger', 0));
  LStructure.AddPair('5', LayoutColumnStructure('fdWIDTH', 'ftInteger', 0));
  Result.AddPair('TableStructure', LStructure);
  LData := TJSONObject.Create;
  N := 0;
  ADataSet.DisableControls;
  try
    ADataSet.First;
    while not ADataSet.Eof do
    begin
      LRow := TJSONObject.Create;
      LRow.AddPair('fdCOLUMN_NAME', ADataSet.FieldByName('fdCOLUMN_NAME').AsString);
      LRow.AddPair('fdCAPTION', ADataSet.FieldByName('fdCAPTION').AsString);
      LRow.AddPair('fdGROUP', ADataSet.FieldByName('fdGROUP').AsString);
      if ADataSet.FieldByName('fdVISIBLE').AsBoolean then
        LRow.AddPair('fdVISIBLE', 'True')
      else
        LRow.AddPair('fdVISIBLE', 'False');
      LRow.AddPair('fdSPAN', IntToStr(ADataSet.FieldByName('fdSPAN').AsInteger));
      LRow.AddPair('fdWIDTH', IntToStr(ADataSet.FieldByName('fdWIDTH').AsInteger));
      LData.AddPair(IntToStr(N), LRow);
      Inc(N);
      ADataSet.Next;
    end;
  finally
    ADataSet.EnableControls;
  end;
  Result.AddPair('Data', LData);
end;

constructor TWebNormalSettingSetupRecordLayout.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BuildDataSet;
  cbPosition.Items.Clear;
  cbPosition.Items.Add('Top');
  cbPosition.Items.Add('Left');
end;

procedure TWebNormalSettingSetupRecordLayout.BuildDataSet;
begin
  cdsRecordLayout.Close;
  cdsRecordLayout.FieldDefs.Clear;
  AddLayoutFieldDef(cdsRecordLayout, 'fdVISIBLE', ftBoolean);
  AddLayoutFieldDef(cdsRecordLayout, 'fdCOLUMN_NAME', ftWideString, 80);
  AddLayoutFieldDef(cdsRecordLayout, 'fdOBJECT_TYPE', ftWideString, 40);
  AddLayoutFieldDef(cdsRecordLayout, 'fdCAPTION', ftWideString, 120);
  AddLayoutFieldDef(cdsRecordLayout, 'fdGROUP', ftWideString, 60);
  AddLayoutFieldDef(cdsRecordLayout, 'fdSPAN', ftInteger);
  AddLayoutFieldDef(cdsRecordLayout, 'fdWIDTH', ftInteger);
  cdsRecordLayout.CreateDataSet;
end;

procedure TWebNormalSettingSetupRecordLayout.Prepare(AColumns,
  ATypesetting: TClientDataSet; const AValue: string);
var
  LJSONValue, LChild: TJSONValue;
  LJSON, LLayout, LRows, LRow: TJSONObject;
  LBookmark: TBookmark;
  LName, LCaption, LGroup, LRowName: string;
  LI, LMaxSpan: Integer;
begin
  FConfiguredValue := AValue;
  cdsRecordLayout.DisableControls;
  try
    cdsRecordLayout.EmptyDataSet;
    cbPosition.Text := 'Top';
    seColumns.Value := 2;
    seFieldWidth.Value := 250;
    cbShowGroups.Checked := True;

    LJSONValue := nil;
    if Trim(AValue) <> '' then LJSONValue := TJSONObject.ParseJSONValue(AValue);
    try
      if LJSONValue is TJSONObject then
      begin
        LJSON := TJSONObject(LJSONValue);
        if Trim(LayoutJSONValue(LJSON, 'cbEditPosition')) <> '' then
          cbPosition.Text := Trim(LayoutJSONValue(LJSON, 'cbEditPosition'));
        if StrToIntDef(LayoutJSONValue(LJSON, 'seColumns'), 0) > 0 then
          seColumns.Value := StrToIntDef(LayoutJSONValue(LJSON, 'seColumns'), 2);
        if StrToIntDef(LayoutJSONValue(LJSON, 'seFieldWidth'), 0) > 0 then
          seFieldWidth.Value := StrToIntDef(LayoutJSONValue(LJSON, 'seFieldWidth'), 250);
        cbShowGroups.Checked :=
          not SameText(LayoutJSONValue(LJSON, 'cbShowGroups'), 'False') and
          (LayoutJSONValue(LJSON, 'cbShowGroups') <> '0');
        { 已有布局：先按它的行顺序与属性建行；未列出的已勾选字段稍后补在后面。 }
        LChild := LJSON.GetValue('cdsRecordLayout');
        if LChild is TJSONObject then
        begin
          LLayout := TJSONObject(LChild);
          LChild := LLayout.GetValue('Data');
          if LChild is TJSONObject then
          begin
            LRows := TJSONObject(LChild);
            for LI := 0 to LRows.Count - 1 do
            begin
              LChild := LRows.GetValue(IntToStr(LI));
              if not (LChild is TJSONObject) then Continue;
              LRow := TJSONObject(LChild);
              LName := PlainLayoutField(LayoutJSONValue(LRow, 'fdCOLUMN_NAME'));
              if LName = '' then Continue;
              { 数据结构已变更：旧字段（不存在或已取消勾选）不再带进来。 }
              if not LayoutFieldUsable(AColumns, LName) then Continue;
              if LayoutRowExists(cdsRecordLayout, LName) then Continue;
              cdsRecordLayout.Append;
              cdsRecordLayout.FieldByName('fdVISIBLE').AsBoolean :=
                not SameText(LayoutJSONValue(LRow, 'fdVISIBLE'), 'False') and
                (LayoutJSONValue(LRow, 'fdVISIBLE') <> '0');
              cdsRecordLayout.FieldByName('fdCOLUMN_NAME').AsString := LName;
              cdsRecordLayout.FieldByName('fdCAPTION').AsString :=
                Trim(LayoutJSONValue(LRow, 'fdCAPTION'));
              cdsRecordLayout.FieldByName('fdGROUP').AsString :=
                Trim(LayoutJSONValue(LRow, 'fdGROUP'));
              cdsRecordLayout.FieldByName('fdSPAN').AsInteger :=
                StrToIntDef(LayoutJSONValue(LRow, 'fdSPAN'), 1);
              cdsRecordLayout.FieldByName('fdWIDTH').AsInteger :=
                StrToIntDef(LayoutJSONValue(LRow, 'fdWIDTH'), 0);
              cdsRecordLayout.Post;
            end;
          end;
        end;
      end;
    finally
      LJSONValue.Free;
    end;

    { 补齐所有已勾选的主表字段；标题/组别缺省取「排版」，没有排版时按字段表。 }
    if Assigned(AColumns) and AColumns.Active then
    begin
      LBookmark := AColumns.GetBookmark;
      AColumns.DisableControls;
      try
        AColumns.First;
        while not AColumns.Eof do
        begin
          if AColumns.FieldByName('fdSELECT').AsBoolean then
          begin
            LName := PlainLayoutField(AColumns.FieldByName('fdCOLUMN_NAME').AsString);
            if not LayoutRowExists(cdsRecordLayout, LName) then
            begin
              LCaption := Trim(AColumns.FieldByName('fdCAPTION').AsString);
              LGroup := '';
              TypesettingRowValues(ATypesetting, LName, LCaption, LGroup);
              cdsRecordLayout.Append;
              cdsRecordLayout.FieldByName('fdVISIBLE').AsBoolean := True;
              cdsRecordLayout.FieldByName('fdCOLUMN_NAME').AsString := LName;
              cdsRecordLayout.FieldByName('fdOBJECT_TYPE').AsString :=
                Trim(AColumns.FieldByName('fdOBJECT_TYPE').AsString);
              cdsRecordLayout.FieldByName('fdCAPTION').AsString := LCaption;
              cdsRecordLayout.FieldByName('fdGROUP').AsString := LGroup;
              cdsRecordLayout.FieldByName('fdSPAN').AsInteger := 1;
              cdsRecordLayout.FieldByName('fdWIDTH').AsInteger := 0;
              cdsRecordLayout.Post;
            end;
          end;
          AColumns.Next;
        end;
      finally
        if AColumns.BookmarkValid(LBookmark) then AColumns.GotoBookmark(LBookmark);
        AColumns.FreeBookmark(LBookmark);
        AColumns.EnableControls;
      end;
    end;

    { 对象类型列：已有布局的行也补上，便于识别控件类型。 }
    cdsRecordLayout.First;
    while not cdsRecordLayout.Eof do
    begin
      if Trim(cdsRecordLayout.FieldByName('fdOBJECT_TYPE').AsString) = '' then
      begin
        LRowName := cdsRecordLayout.FieldByName('fdCOLUMN_NAME').AsString;
        cdsRecordLayout.Edit;
        cdsRecordLayout.FieldByName('fdOBJECT_TYPE').AsString :=
          ColumnObjectType(AColumns, LRowName);
        cdsRecordLayout.Post;
      end;
      cdsRecordLayout.Next;
    end;

    { 列数不能小于已配置的最大跨列。 }
    LMaxSpan := 1;
    cdsRecordLayout.First;
    while not cdsRecordLayout.Eof do
    begin
      if cdsRecordLayout.FieldByName('fdSPAN').AsInteger > LMaxSpan then
        LMaxSpan := cdsRecordLayout.FieldByName('fdSPAN').AsInteger;
      cdsRecordLayout.Next;
    end;
    if LMaxSpan > seColumns.Value then seColumns.Value := LMaxSpan;
    cdsRecordLayout.First;
  finally
    cdsRecordLayout.EnableControls;
  end;
end;

procedure TWebNormalSettingSetupRecordLayout.btOkClick(Sender: TObject);
var
  LJSON: TJSONObject;
  LVisible: Integer;
  LName: string;
begin
  if cdsRecordLayout.State in dsEditModes then cdsRecordLayout.Post;
  LVisible := 0;
  cdsRecordLayout.First;
  while not cdsRecordLayout.Eof do
  begin
    LName := cdsRecordLayout.FieldByName('fdCOLUMN_NAME').AsString;
    if cdsRecordLayout.FieldByName('fdVISIBLE').AsBoolean then Inc(LVisible);
    if cdsRecordLayout.FieldByName('fdSPAN').AsInteger > seColumns.Value then
      raise Exception.Create('字段 ' + LName + ' 的跨列数 ' +
        IntToStr(cdsRecordLayout.FieldByName('fdSPAN').AsInteger) +
        ' 超过记录区列数 ' + IntToStr(seColumns.Value) + '，请改小跨列数或加大列数。');
    if cdsRecordLayout.FieldByName('fdSPAN').AsInteger < 1 then
      raise Exception.Create('字段 ' + LName + ' 的跨列数至少为 1。');
    if (cdsRecordLayout.FieldByName('fdWIDTH').AsInteger > 0) and
      (cdsRecordLayout.FieldByName('fdWIDTH').AsInteger < 80) then
      raise Exception.Create('字段 ' + LName + ' 的记录区宽度 ' +
        IntToStr(cdsRecordLayout.FieldByName('fdWIDTH').AsInteger) +
        ' 无效：填 0 表示用“每列宽度”，或填 80 以上的像素值。');
    cdsRecordLayout.Next;
  end;
  if LVisible = 0 then
    raise Exception.Create('请至少保留一个记录区字段（勾选“显示”）。');
  if Trim(cbPosition.Text) = '' then
    raise Exception.Create('请选择记录区位置。');

  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('cbEditPosition', Trim(cbPosition.Text));
    LJSON.AddPair('seColumns', IntToStr(seColumns.Value));
    LJSON.AddPair('seFieldWidth', IntToStr(seFieldWidth.Value));
    if cbShowGroups.Checked then LJSON.AddPair('cbShowGroups', '-1')
    else LJSON.AddPair('cbShowGroups', '0');
    LJSON.AddPair('cdsRecordLayout', BuildLayoutJSON(cdsRecordLayout));
    FConfiguredValue := LJSON.Format(2);
  finally
    LJSON.Free;
  end;
  ModalResult := mrOk;
end;

{ 上移/下移：整行交换由 ugConfiguration.ListEditorLayout.SwapLayoutRows 完成
  （纯逻辑单元，控制台探针可测）。这里只管边界、光标与网格刷新。 }
procedure TWebNormalSettingSetupRecordLayout.MoveCurrent(ADelta: Integer);
var
  LIndex, LTarget: Integer;
begin
  if cdsRecordLayout.State in dsEditModes then cdsRecordLayout.Post;
  if cdsRecordLayout.IsEmpty then Exit;
  LIndex := cdsRecordLayout.RecNo - 1;
  LTarget := LIndex + ADelta;
  if (LTarget < 0) or (LTarget >= cdsRecordLayout.RecordCount) then Exit;
  if not SwapLayoutRows(cdsRecordLayout, LIndex, LTarget) then Exit;
  { 交换只换值、不改物理行序：把光标放回被移动的那一行（它现在在 LTarget 位置），
    便于连续上/下移；UniGUI 的 DBGrid 不保证自动重排，显式刷新。 }
  cdsRecordLayout.RecNo := LTarget + 1;
  gridLayout.Refresh;
end;

procedure TWebNormalSettingSetupRecordLayout.tbUpClick(Sender: TObject);
begin
  MoveCurrent(-1);
end;

procedure TWebNormalSettingSetupRecordLayout.tbDownClick(Sender: TObject);
begin
  MoveCurrent(1);
end;

end.
