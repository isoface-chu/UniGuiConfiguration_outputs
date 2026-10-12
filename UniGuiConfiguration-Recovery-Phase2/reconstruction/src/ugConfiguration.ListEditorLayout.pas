unit ugConfiguration.ListEditorLayout;

{ mtListEditor 记录区布局里与 UI 无关的纯逻辑，单独成单元是为了能在控制台探针里直接测：
   「上移/下移」必须把两行的**全部列**真正互换 —— 只写一个方向会丢行（2026-09-19 宿主实测：
   交换后 FCustName 重复、FEmpName 消失）。这里用书签定位两行、先把两边都取出来再写回，
   不依赖 RecNo 与当前排序状态。 }

interface

uses System.SysUtils, System.JSON, Data.DB, Datasnap.DBClient;

type
  { 记录区布局的一行：字段（带别名原样）、标题、分组、跨列数、单字段宽度（0 = 用"每列宽度"）。 }
  TListEditorLayoutItem = record
    Field, Caption, Group: string;
    Span, Width: Integer;
  end;

{ 读「记录区布局」（常规设置里键名就是它，值是一段 JSON 字符串，也容忍已经是 JSON 对象）。
  返回 False 且 Reason 非空表示配置非法；返回 False 且 Reason 为空表示"没有配置布局"（调用方回退到默认排版）。
  **mtListEditor 与 mtMasterSlave 共用这一份**（宿主 2026-09-22：mtMasterSlave 也要这个功能）——
  共用是为了两边的解析口径与拒绝文案完全一致，不会各写一套。 }
function ReadListEditorLayout(Config: TJSONObject;
  out Items: TArray<TListEditorLayoutItem>; out Columns, FieldWidth: Integer;
  out Position: string; out ShowGroups: Boolean; out Reason: string): Boolean;

{ 把显示顺序里第 AIndexA 行与第 AIndexB 行的全部字段值互换（0 基索引）。
  只交换字段值，不改变物理行序；返回 False 表示索引越界、数据集未打开或为空，此时数据集不动。
  交换成功后调用方可按 RecNo := AIndexA + 1 把光标放回被移动的那一行。 }
function SwapLayoutRows(ADataSet: TClientDataSet; AIndexA, AIndexB: Integer): Boolean;

implementation

function SwapLayoutRows(ADataSet: TClientDataSet; AIndexA, AIndexB: Integer): Boolean;
var
  LBookmarkA, LBookmarkB: TBookmark;
  LValuesA, LValuesB: array of Variant;
  I: Integer;
begin
  Result := False;
  if (ADataSet = nil) or not ADataSet.Active or ADataSet.IsEmpty then Exit;
  if (AIndexA = AIndexB) or (AIndexA < 0) or (AIndexB < 0) or
    (AIndexA >= ADataSet.RecordCount) or (AIndexB >= ADataSet.RecordCount) then Exit;
  ADataSet.DisableControls;
  LBookmarkA := nil;
  LBookmarkB := nil;
  try
    ADataSet.RecNo := AIndexA + 1;
    LBookmarkA := ADataSet.GetBookmark;
    ADataSet.RecNo := AIndexB + 1;
    LBookmarkB := ADataSet.GetBookmark;
    if not Assigned(LBookmarkA) or not Assigned(LBookmarkB) then Exit;
    SetLength(LValuesA, ADataSet.FieldCount);
    SetLength(LValuesB, ADataSet.FieldCount);
    { 两边都先取出来，再分别写回：任何一步失败都不会把某一行的值弄丢。 }
    ADataSet.GotoBookmark(LBookmarkA);
    for I := 0 to ADataSet.FieldCount - 1 do
      LValuesA[I] := ADataSet.Fields[I].Value;
    ADataSet.GotoBookmark(LBookmarkB);
    for I := 0 to ADataSet.FieldCount - 1 do
      LValuesB[I] := ADataSet.Fields[I].Value;

    ADataSet.GotoBookmark(LBookmarkA);
    ADataSet.Edit;
    for I := 0 to ADataSet.FieldCount - 1 do
      ADataSet.Fields[I].Value := LValuesB[I];
    ADataSet.Post;

    ADataSet.GotoBookmark(LBookmarkB);
    ADataSet.Edit;
    for I := 0 to ADataSet.FieldCount - 1 do
      ADataSet.Fields[I].Value := LValuesA[I];
    ADataSet.Post;

    { 本函数只换值、不改物理顺序；光标由调用方恢复（RecNo := AIndexA + 1 即可）。
      不在函数里用书签恢复光标：Post 之后靠书签定位在 TClientDataSet 上不可靠。 }
    Result := True;
  finally
    if Assigned(LBookmarkB) then ADataSet.FreeBookmark(LBookmarkB);
    if Assigned(LBookmarkA) then ADataSet.FreeBookmark(LBookmarkA);
    ADataSet.EnableControls;
  end;
end;

function Obj(J: TJSONObject; const Key: string): TJSONObject;
var V: TJSONValue;
begin
  Result := nil;
  if J = nil then Exit;
  V := J.GetValue(Key);
  if V is TJSONObject then Result := TJSONObject(V);
end;

function Str(J: TJSONObject; const Key: string): string;
var V: TJSONValue;
begin
  Result := '';
  if J = nil then Exit;
  V := J.GetValue(Key);
  if (V <> nil) and not (V is TJSONNull) then Result := V.Value;
end;

function ReadListEditorLayout(Config: TJSONObject;
  out Items: TArray<TListEditorLayoutItem>; out Columns, FieldWidth: Integer;
  out Position: string; out ShowGroups: Boolean; out Reason: string): Boolean;
var Block, Owned, Rows, Row, Settings: TJSONObject; Value: TJSONValue;
  I, N: Integer; V: string; Item: TListEditorLayoutItem;
begin
  Result := False; Reason := ''; Items := nil; Block := nil; Owned := nil;
  Columns := 2; FieldWidth := 250; Position := 'Top'; ShowGroups := True;
  { 精灵把这一项存在常规设置里（键名「记录区布局」），值本身是一段 JSON 字符串；
    同时容忍值已经是 JSON 对象的情况（手工写的配置）。 }
  Settings := Obj(Config, 'TWebNormalSetting');
  if Settings = nil then Exit;
  Value := Settings.GetValue('记录区布局');
  if Value = nil then Exit;
  if Value is TJSONObject then Block := TJSONObject(Value)
  else if Trim(Value.Value) <> '' then
  begin
    Owned := TJSONObject(TJSONObject.ParseJSONValue(Value.Value));
    if Owned = nil then
    begin
      Reason := '记录区布局的值不是合法的 JSON。';
      Exit;
    end;
    Block := Owned;
  end;
  if Block = nil then Exit;
  try
    Position := Trim(Str(Block, 'cbEditPosition'));
    if Position = '' then Position := 'Top';
    if not SameText(Position, 'Top') and not SameText(Position, 'Left') then
    begin
      Reason := '记录区位置只支持 Top 或 Left：' + Position;
      Exit;
    end;
    V := Trim(Str(Block, 'seColumns'));
    if V <> '' then Columns := StrToIntDef(V, 2);
    if (Columns < 1) or (Columns > 3) then
    begin
      Reason := '记录区列数只支持 1..3 列：' + V;
      Exit;
    end;
    V := Trim(Str(Block, 'seFieldWidth'));
    if V <> '' then FieldWidth := StrToIntDef(V, 250);
    if (FieldWidth < 80) or (FieldWidth > 800) then
    begin
      Reason := '记录区每列宽度须在 80..800 之间：' + V;
      Exit;
    end;
    V := Trim(Str(Block, 'cbShowGroups'));
    ShowGroups := not SameText(V, 'False') and (V <> '0');
    Rows := Obj(Obj(Block, 'cdsRecordLayout'), 'Data');
    if (Rows = nil) or (Rows.Count = 0) then Exit;
    N := 0;
    for I := 0 to Rows.Count - 1 do
    begin
      Row := Obj(Rows, IntToStr(I));
      if Row = nil then Continue;
      Item.Field := Trim(Str(Row, 'fdCOLUMN_NAME'));
      if Item.Field = '' then Continue;
      { fdVISIBLE 缺省视为显示，只有明确写 False/0 才算隐藏。 }
      V := Trim(Str(Row, 'fdVISIBLE'));
      if SameText(V, 'False') or (V = '0') then Continue;
      Item.Caption := Trim(Str(Row, 'fdCAPTION'));
      Item.Group := Trim(Str(Row, 'fdGROUP'));
      Item.Span := StrToIntDef(Trim(Str(Row, 'fdSPAN')), 1);
      if Item.Span < 1 then Item.Span := 1;
      if Item.Span > Columns then
      begin
        Reason := '字段 ' + Item.Field + ' 的跨列数 ' + IntToStr(Item.Span) +
          ' 超过记录区列数 ' + IntToStr(Columns) + '。';
        Exit;
      end;
      Item.Width := StrToIntDef(Trim(Str(Row, 'fdWIDTH')), 0);
      if (Item.Width > 0) and (Item.Width < 80) then
      begin
        Reason := '字段 ' + Item.Field + ' 的记录区宽度 ' + IntToStr(Item.Width) +
          ' 无效：填 0 表示用“每列宽度”，或填 80 以上的像素值。';
        Exit;
      end;
      SetLength(Items, N + 1);
      Items[N] := Item;
      Inc(N);
    end;
    { 区块里有行就算“显式布局”（哪怕全部隐藏）：这样才能对“全都隐藏了”给出明确拒绝，
      而不是悄悄回退到表格字段。真正没有行时才回退。 }
    Result := True;
  finally
    Owned.Free;
  end;
end;
end.
