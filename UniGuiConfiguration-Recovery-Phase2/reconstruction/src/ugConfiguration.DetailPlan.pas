unit ugConfiguration.DetailPlan;

interface

uses System.SysUtils, System.Classes, System.JSON;

type
  // How the detail record number is produced. Only kinds with original
  // evidence for mtDetail are accepted by the template; the rest are
  // parsed so the caller can report an accurate diagnosis instead of
  // silently dropping the setting.
  TDetailNumberKind = (dnkNone, dnkGuid, dnkSequence, dnkMaxCode,
    dnkDateTimeRandom, dnkDBAutoincrement);
  // Navigation cursor kind for 录入时间 (or the key fallback).
  TDetailTimeKind = (ttkDateTime, ttkNumber, ttkText);

  TDetailPlan = class
  public
    DataNodeName: string;
    MainTable: string;
    MainAlias: string;
    DetailTable: string;
    DetailAlias: string;
    // Ordered as configured; Captions parallel Fields.
    MainFields: TStringList;
    MainCaptions: TStringList;
    MainSelected: TStringList;
    MainTypes: TStringList;
    DetailFields: TStringList;
    DetailCaptions: TStringList;
    DetailSelected: TStringList;
    DetailTypes: TStringList;
    // Detail fields edited through the popup editor frame (v<Field> vars).
    EditableFields: TStringList;
    // 关联字段 (main) / 关联从表 (detail), unqualified names.
    MainKeyField: string;
    DetailKeyField: string;
    // 录入时间 (navigation cursor) / 录入部门 (hierarchy permission), main.
    TimeField: string;
    TimeKind: TDetailTimeKind;
    DepartmentField: string;
    Scoped: Boolean;
    // 记录编号
    NumberField: string;
    NumberKind: TDetailNumberKind;
    NumberKindText: string;
    NumberPrefix: string;
    NumberSuffix: string;
    NumberDigits: Integer;
    // 从表唯一
    UniqueRecordField: string;
    UniqueCompareFields: TStringList;
    // 从表必填字段（从表非空），unqualified。
    RequiredDetailFields: TStringList;
    // Hidden columns, unqualified, per structure.
    HiddenMainFields: TStringList;
    HiddenDetailFields: TStringList;
    EditorFrame: string;
    QueryFrame: string;
    // 扩充项「导入窗体」：导入下拉的子项列表（标题 + 查询窗体 + 允许多选），
    // 用户 2026-09-14 场景（入库单选打单明细、从销售/采购订单明细引用等）。
    ImportCaptions: TStringList;
    ImportFrames: TStringList;
    ImportMultiSelect: TStringList; // 'True'/'False'，与 Captions 平行
    Buttons: TStringList;
    constructor Create;
    destructor Destroy; override;
    function HasButton(const Name: string): Boolean;
  end;

// Reason is set on every failure; Plan is nil then.
function TryReadDetailPlan(Config: TJSONObject; out Plan: TDetailPlan;
  out Reason: string): Boolean;

implementation

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
  if Assigned(V) and not (V is TJSONNull) then Result := V.Value;
end;

function ItemStr(J: TJSONObject; const Key: string): string;
var V: TJSONValue;
begin
  Result := '';
  if not Assigned(J) then Exit;
  V := J.GetValue(Key);
  if Assigned(V) and not (V is TJSONNull) then Result := V.Value;
end;

function Yes(const S: string): Boolean;
begin
  Result := SameText(S, 'True') or (S = '1') or (S = '-1');
end;

function Ident(const S: string): Boolean;
var C: Char;
begin
  Result := False;
  if S = '' then Exit;
  if not CharInSet(S[1], ['A'..'Z', 'a'..'z', '_']) then Exit;
  for C in S do
    if not CharInSet(C, ['A'..'Z', 'a'..'z', '_', '0'..'9']) then Exit;
  Result := True;
end;

function SplitSemicolon(const S: string): TStringList;
begin
  Result := TStringList.Create;
  Result.StrictDelimiter := True;
  Result.Delimiter := ';';
  Result.DelimitedText := S;
end;

constructor TDetailPlan.Create;
begin
  inherited Create;
  MainFields := TStringList.Create;
  MainCaptions := TStringList.Create;
  MainSelected := TStringList.Create;
  MainTypes := TStringList.Create;
  DetailFields := TStringList.Create;
  DetailCaptions := TStringList.Create;
  DetailSelected := TStringList.Create;
  DetailTypes := TStringList.Create;
  EditableFields := TStringList.Create;
  UniqueCompareFields := TStringList.Create;
  RequiredDetailFields := TStringList.Create;
  ImportCaptions := TStringList.Create;
  ImportFrames := TStringList.Create;
  ImportMultiSelect := TStringList.Create;
  HiddenMainFields := TStringList.Create;
  HiddenDetailFields := TStringList.Create;
  Buttons := TStringList.Create;
  Buttons.StrictDelimiter := True;
  Buttons.Delimiter := ';';
end;

destructor TDetailPlan.Destroy;
begin
  MainFields.Free;
  MainCaptions.Free;
  MainSelected.Free;
  MainTypes.Free;
  DetailFields.Free;
  DetailCaptions.Free;
  DetailSelected.Free;
  DetailTypes.Free;
  EditableFields.Free;
  UniqueCompareFields.Free;
  RequiredDetailFields.Free;
  ImportCaptions.Free;
  ImportFrames.Free;
  ImportMultiSelect.Free;
  HiddenMainFields.Free;
  HiddenDetailFields.Free;
  Buttons.Free;
  inherited Destroy;
end;

function TDetailPlan.HasButton(const Name: string): Boolean;
begin
  Result := Buttons.IndexOf(Name) >= 0;
end;

// Reads the cdsColumns.Data rows of one structure section, keeping only the
// fields that belong to the configured alias and appear in fdCOLUMN_NAME.
function ReadStructureColumns(Config: TJSONObject; const Section, Alias: string;
  Fields, Captions, Selected, Types: TStringList; out Reason: string): Boolean;
var
  Columns, Row: TJSONObject;
  I: Integer;
  F, Caption, Qualified: string;
  function Fail(const S: string): Boolean;
  begin
    Reason := S;
    Result := False;
  end;
begin
  Result := True;
  Reason := '';
  Columns := Obj(Obj(Obj(Config, Section), 'cdsColumns'), 'Data');
  if (Columns = nil) or (Columns.Count = 0) then
    Exit(Fail(Section + ' 缺少字段数据。'));
  for I := 0 to Columns.Count - 1 do
  begin
    Row := Obj(Columns, IntToStr(I));
    if Row = nil then Exit(Fail(Section + ' 字段数据缺少连续数字行键。'));
    Qualified := Str(Row, 'fdCOLUMN_NAME');
    if not SameText(Copy(Qualified, 1, Length(Alias) + 1), Alias + '.') then
      Exit(Fail(Section + ' 字段必须属于别名 ' + Alias + '：' + Qualified));
    F := Copy(Qualified, Length(Alias) + 2, MaxInt);
    if not Ident(F) then Exit(Fail(Section + ' 存在无效字段名：' + F));
    if Fields.IndexOf(F) >= 0 then Exit(Fail(Section + ' 字段重复：' + F));
    Fields.Add(F);
    Caption := Str(Row, 'fdCAPTION');
    if Trim(Caption) = '' then Caption := F;
    Captions.Add(Caption);
    Types.Add(Str(Row, 'fdOBJECT_TYPE'));
    if Yes(Str(Row, 'fdSELECT')) then Selected.Add(F);
  end;
end;

// Maps a configured qualified field such as a.ID to its unqualified name,
// requiring the field to exist in the selected structure columns.
function FieldOf(const Qualified, Alias: string;
  Fields: TStringList): string;
begin
  Result := '';
  if Qualified = '' then Exit;
  if not SameText(Copy(Qualified, 1, Length(Alias) + 1), Alias + '.') then Exit;
  Result := Copy(Qualified, Length(Alias) + 2, MaxInt);
  if not Ident(Result) then begin Result := ''; Exit; end;
  if Fields.IndexOf(Result) < 0 then Result := '';
end;

// Hidden fields are stored qualified with their own alias; keep only the
// unqualified names this structure owns.
procedure ReadHidden(const Raw, Alias: string; Target: TStringList);
var
  Parts: TStringList;
  I: Integer;
  F: string;
begin
  Parts := SplitSemicolon(Raw);
  try
    for I := 0 to Parts.Count - 1 do
    begin
      F := Trim(Parts[I]);
      if F = '' then Continue;
      if SameText(Copy(F, 1, Length(Alias) + 1), Alias + '.') then
        F := Copy(F, Length(Alias) + 2, MaxInt)
      else
        Continue;
      if (Ident(F)) and (Target.IndexOf(F) < 0) then Target.Add(F);
    end;
  finally
    Parts.Free;
  end;
end;

function TryReadDetailPlan(Config: TJSONObject; out Plan: TDetailPlan;
  out Reason: string): Boolean;
const
  CAllowedButtons = ';btQuery;btFirst;btPrior;btNext;btLast;btAppend;btDelete;' +
    'btEditor;btImport;btSave;btCancel;btExport;btPrint;btAnnex;btClose;';
var
  MainTables, DetailTables, Settings, Rule, Item: TJSONObject;
  Arr: TJSONArray;
  Parsed: TJSONValue;
  I, N: Integer;
  Q, Kind, FrameName: string;
  Parts: TStringList;
  function Fail(const S: string): Boolean;
  begin
    FreeAndNil(Plan);
    Reason := S;
    Result := False;
  end;
begin
  Plan := nil;
  Reason := '';
  if not SameText(Str(Config, 'TWebModuletype'), 'mtDetail') then
    Exit(Fail('模块类型不是 mtDetail。'));
  if Trim(Str(Config, 'TWebDataNodeName')) = '' then
    Exit(Fail('请选择数据节点。'));
  Settings := Obj(Config, 'TWebNormalSetting');
  if Settings = nil then Exit(Fail('mtDetail 缺少常规设置。'));

  Plan := TDetailPlan.Create;
  try
    Plan.DataNodeName := Str(Config, 'TWebDataNodeName');
    MainTables := Obj(Obj(Obj(Config, 'TWebDataStructure'), 'cdsTables'), 'Data');
    DetailTables := Obj(Obj(Obj(Config, 'TWebDetailedStructure'), 'cdsTables'), 'Data');
    if (MainTables = nil) or (DetailTables = nil) then
      Exit(Fail('mtDetail 缺少主表或从表结构。'));
    if (MainTables.Count <> 1) or (DetailTables.Count <> 1) then
      Exit(Fail('mtDetail 首批仅接入主表、从表各一张，关联表留待后续核对。'));
    Plan.MainTable := Str(Obj(MainTables, '0'), 'fdTableName');
    Plan.MainAlias := Str(Obj(MainTables, '0'), 'fdEpithet');
    Plan.DetailTable := Str(Obj(DetailTables, '0'), 'fdTableName');
    Plan.DetailAlias := Str(Obj(DetailTables, '0'), 'fdEpithet');
    if not Ident(Plan.MainTable) or not Ident(Plan.MainAlias) then
      Exit(Fail('主表需要普通表名和合法别名。'));
    if not Ident(Plan.DetailTable) or not Ident(Plan.DetailAlias) then
      Exit(Fail('从表需要普通表名和合法别名。'));
    if Str(Obj(MainTables, '0'), 'fdParent') <> '' then
      Exit(Fail('mtDetail 主表必须是根表。'));
    if Str(Obj(DetailTables, '0'), 'fdParent') <> '' then
      Exit(Fail('mtDetail 从表必须是根表。'));

    if not ReadStructureColumns(Config, 'TWebDataStructure', Plan.MainAlias,
      Plan.MainFields, Plan.MainCaptions, Plan.MainSelected, Plan.MainTypes,
      Reason) then Exit(Fail(Reason));
    if not ReadStructureColumns(Config, 'TWebDetailedStructure', Plan.DetailAlias,
      Plan.DetailFields, Plan.DetailCaptions, Plan.DetailSelected, Plan.DetailTypes,
      Reason) then Exit(Fail(Reason));
    if Plan.MainSelected.Count = 0 then Exit(Fail('请至少选择一个主表显示字段。'));
    if Plan.DetailSelected.Count = 0 then Exit(Fail('请至少选择一个从表显示字段。'));

    Plan.Buttons.DelimitedText := Str(Config, 'TWebFunctionButton');
    for I := Plan.Buttons.Count - 1 downto 0 do
    begin
      Plan.Buttons[I] := Trim(Plan.Buttons[I]);
      if Plan.Buttons[I] = '' then Plan.Buttons.Delete(I);
    end;
    for I := 0 to Plan.Buttons.Count - 1 do
      if Pos(';' + Plan.Buttons[I] + ';', CAllowedButtons) = 0 then
        Exit(Fail('mtDetail 不支持按钮 ' + Plan.Buttons[I]));

    Plan.MainKeyField := FieldOf(Str(Settings, '关联字段'), Plan.MainAlias,
      Plan.MainFields);
    if Plan.MainKeyField = '' then Exit(Fail('关联字段必须指定主表中存在的字段。'));
    Plan.DetailKeyField := FieldOf(Str(Settings, '关联从表'), Plan.DetailAlias,
      Plan.DetailFields);
    if Plan.DetailKeyField = '' then
    begin
      // mtDetail 精灵只暴露“关联字段”；从表侧取同名列，与原版同表样例一致。
      if Plan.DetailFields.IndexOf(Plan.MainKeyField) >= 0 then
        Plan.DetailKeyField := Plan.MainKeyField
      else
        Exit(Fail('关联字段 ' + Plan.MainKeyField +
          ' 在从表中没有同名列，无法确定关联从表字段。'));
    end;
    Q := Trim(Str(Settings, '录入时间'));
    if Q <> '' then
    begin
      Plan.TimeField := FieldOf(Q, Plan.MainAlias, Plan.MainFields);
      if Plan.TimeField = '' then
        Exit(Fail('录入时间必须指定主表中存在的字段。'));
    end
    else
      Plan.TimeField := Plan.MainKeyField;
    I := Plan.MainFields.IndexOf(Plan.TimeField);
    if SameText(Plan.MainTypes[I], 'datetime') then Plan.TimeKind := ttkDateTime
    else if SameText(Plan.MainTypes[I], 'number') then Plan.TimeKind := ttkNumber
    else Plan.TimeKind := ttkText;
    Plan.Scoped := Yes(Str(Settings, '层级权限'));
    if Plan.Scoped then
    begin
      Plan.DepartmentField := FieldOf(Str(Settings, '录入部门'), Plan.MainAlias,
        Plan.MainFields);
      if Plan.DepartmentField = '' then
        Exit(Fail('层级权限需要指定主表中存在的录入部门字段。'));
    end;

    // 记录编号
    Plan.NumberKind := dnkNone;
    Rule := nil;
    Parsed := nil;
    try
      Q := Str(Settings, '记录编号');
      if Trim(Q) <> '' then
      begin
        Parsed := TJSONObject.ParseJSONValue(Q);
        if Parsed is TJSONObject then Rule := TJSONObject(Parsed)
        else Exit(Fail('记录编号配置不是 JSON 对象。'));
      end;
      if Rule <> nil then
      begin
        Plan.NumberField := FieldOf(Str(Rule, 'cbField'), Plan.DetailAlias,
          Plan.DetailFields);
        Kind := Str(Rule, 'cbAutoNumberType');
        Plan.NumberKindText := Kind;
        Plan.NumberPrefix := Str(Rule, 'edPrefix');
        Plan.NumberSuffix := Str(Rule, 'edSuffix');
        Plan.NumberDigits := StrToIntDef(Str(Rule, 'seDigitCapacity'), 0);
        if SameText(Kind, 'Guid') then Plan.NumberKind := dnkGuid
        else if SameText(Kind, 'SeqUence') then Plan.NumberKind := dnkSequence
        else if SameText(Kind, 'MaxCode') then Plan.NumberKind := dnkMaxCode
        else if SameText(Kind, 'DateTimeRandom') then Plan.NumberKind := dnkDateTimeRandom
        else if SameText(Kind, 'DBAutoincrement') then Plan.NumberKind := dnkDBAutoincrement;
        if (Kind <> '') and (Plan.NumberField = '') then
          Exit(Fail('记录编号字段必须指定从表中存在的字段。'));
      end;
    finally
      Parsed.Free;
    end;

    // 从表唯一
    Rule := nil;
    Parsed := nil;
    try
      Q := Str(Settings, '从表唯一');
      if Trim(Q) <> '' then
      begin
        Parsed := TJSONObject.ParseJSONValue(Q);
        if Parsed is TJSONObject then Rule := TJSONObject(Parsed)
        else Exit(Fail('从表唯一配置不是 JSON 对象。'));
      end;
      if Rule <> nil then
      begin
        // 记录字段可省略：与原版 mtMasterSlave 一致，仅按组合字段校验。
        Q := Trim(Str(Rule, 'cbField'));
        if Q <> '' then
        begin
          Plan.UniqueRecordField := FieldOf(Q, Plan.DetailAlias, Plan.DetailFields);
          if Plan.UniqueRecordField = '' then
            Exit(Fail('从表唯一记录字段必须属于从表：' + Q));
        end
        else
          Plan.UniqueRecordField := '';
        Parts := SplitSemicolon(Str(Rule, 'cdsMultiSelectFields'));
        try
          for N := 0 to Parts.Count - 1 do
          begin
            if Trim(Parts[N]) = '' then Continue;
            Q := FieldOf(Trim(Parts[N]), Plan.DetailAlias,
              Plan.DetailFields);
            if Q = '' then Exit(Fail('从表唯一比较字段必须属于从表：' + Trim(Parts[N])));
            if Plan.UniqueCompareFields.IndexOf(Q) < 0 then
              Plan.UniqueCompareFields.Add(Q);
          end;
        finally
          Parts.Free;
        end;
        if Plan.UniqueCompareFields.Count = 0 then
          Exit(Fail('从表唯一需要至少一个比较字段。'));
      end;
    finally
      Parsed.Free;
    end;

    // 从表非空：必填字段，参照 mtMultiple，保存时按明细行号报告
    Parts := SplitSemicolon(Str(Settings, '从表非空'));
    try
      for N := 0 to Parts.Count - 1 do
      begin
        if Trim(Parts[N]) = '' then Continue;
        Q := FieldOf(Trim(Parts[N]), Plan.DetailAlias, Plan.DetailFields);
        if Q = '' then
          Exit(Fail('从表非空字段必须属于从表：' + Trim(Parts[N])));
        if Plan.RequiredDetailFields.IndexOf(Q) < 0 then
          Plan.RequiredDetailFields.Add(Q);
      end;
    finally
      Parts.Free;
    end;

    ReadHidden(Str(Settings, '隐藏字段-主表'), Plan.MainAlias, Plan.HiddenMainFields);
    ReadHidden(Str(Settings, '隐藏字段-从表'), Plan.DetailAlias, Plan.HiddenDetailFields);

    Plan.EditorFrame := Str(Settings, '编辑窗体');
    Plan.QueryFrame := Str(Settings, '查询窗体');
    // 导入窗体（列表）：每行 = 标题 + 查询窗体 + 允许多选
    Parsed := nil;
    Rule := nil;
    try
      Q := Str(Settings, '导入窗体');
      if Trim(Q) <> '' then
      begin
        Parsed := TJSONObject.ParseJSONValue(Q);
        if not (Parsed is TJSONObject) then
          Exit(Fail('导入窗体配置不是 JSON 对象。'));
        Rule := TJSONObject(Parsed);
        if not (Rule.GetValue('items') is TJSONArray) then
          Exit(Fail('导入窗体配置缺少 items 列表。'));
        Arr := TJSONArray(Rule.GetValue('items'));
        for N := 0 to Arr.Count - 1 do
        begin
          if not (Arr.Items[N] is TJSONObject) then Continue;
          Item := TJSONObject(Arr.Items[N]);
          Q := Trim(ItemStr(Item, 'caption'));
          FrameName := Trim(ItemStr(Item, 'frame'));
          if (Q = '') and (FrameName = '') then Continue;
          if Q = '' then
            Exit(Fail('导入窗体第 ' + IntToStr(N + 1) + ' 行缺少菜单标题。'));
          if FrameName = '' then
            Exit(Fail('导入窗体第 ' + IntToStr(N + 1) + ' 行缺少查询窗体。'));
          Plan.ImportCaptions.Add(Q);
          Plan.ImportFrames.Add(FrameName);
          if SameText(Trim(ItemStr(Item, 'multiSelect')), 'false') then
            Plan.ImportMultiSelect.Add('False')
          else
            Plan.ImportMultiSelect.Add('True');
        end;
      end;
    finally
      Parsed.Free;
    end;
    // 旧值回退：早期单条“引用明细=True”等于一行（标题固定、窗体=查询窗体、允许多选）
    if (Plan.ImportCaptions.Count = 0) and Yes(Str(Settings, '引用明细')) then
    begin
      if Trim(Plan.QueryFrame) = '' then
        Exit(Fail('勾选「引用明细」需要先配置查询窗体（多选来源）。'));
      Plan.ImportCaptions.Add('从查询窗体选择明细');
      Plan.ImportFrames.Add(Plan.QueryFrame);
      Plan.ImportMultiSelect.Add('True');
    end;

    // Editable detail fields feed the popup editor frame variables. The key,
    // time, department and record-number columns are filled by the module
    // itself and are not part of the editor contract.
    for I := 0 to Plan.DetailSelected.Count - 1 do
    begin
      Q := Plan.DetailSelected[I];
      if SameText(Q, Plan.DetailKeyField) then Continue;
      if SameText(Q, Plan.TimeField) then Continue;
      if (Plan.Scoped) and SameText(Q, Plan.DepartmentField) then Continue;
      if (Plan.NumberField <> '') and SameText(Q, Plan.NumberField) then Continue;
      Plan.EditableFields.Add(Q);
    end;
    Result := True;
  except
    on E: Exception do
    begin
      FreeAndNil(Plan);
      Reason := E.ClassName + ': ' + E.Message;
      Result := False;
    end;
  end;
end;

end.
