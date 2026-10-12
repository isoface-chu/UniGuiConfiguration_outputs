unit ugConfiguration.TreePlan;

interface

uses System.SysUtils, System.JSON;

type
  // Parsed contract only. No SQL execution or tree mutation in this unit.
  TTreePlan = record
    TableName, AliasName, KeyField, ParentField, OrderField, EditorFrame: string;
  end;

function TryReadTreePlan(Config: TJSONObject; out Plan: TTreePlan;
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

function Ident(const Name: string): Boolean;
var C: Char;
begin
  Result := False;
  if Name = '' then Exit;
  if not CharInSet(Name[1], ['A'..'Z', 'a'..'z', '_']) then Exit;
  for C in Name do
    if not CharInSet(C, ['A'..'Z', 'a'..'z', '_', '0'..'9']) then Exit;
  Result := True;
end;

function TryReadTreePlan(Config: TJSONObject; out Plan: TTreePlan;
  out Reason: string): Boolean;
var Tables, Columns, Settings, UniqueRule: TJSONObject;
  Parsed: TJSONValue; I: Integer;
  function Fail(const MessageText: string): Boolean;
  begin Reason := MessageText; Result := False; end;
  function Field(const Qualified: string): string;
  var N: Integer;
  begin
    Result := '';
    if not SameText(Copy(Qualified, 1, Length(Plan.AliasName) + 1), Plan.AliasName + '.') then Exit;
    Result := Copy(Qualified, Length(Plan.AliasName) + 2, MaxInt);
    if not Ident(Result) then begin Result := ''; Exit; end;
    for N := 0 to Columns.Count - 1 do
      if SameText(Str(Obj(Columns, IntToStr(N)), 'fdCOLUMN_NAME'), Qualified) then Exit;
    Result := '';
  end;
begin
  Plan := Default(TTreePlan);
  Reason := '';
  if not SameText(Str(Config, 'TWebModuletype'), 'mtTree') then Exit(Fail('模块类型不是 mtTree。'));
  Tables := Obj(Obj(Obj(Config, 'TWebDataStructure'), 'cdsTables'), 'Data');
  Columns := Obj(Obj(Obj(Config, 'TWebDataStructure'), 'cdsColumns'), 'Data');
  Settings := Obj(Config, 'TWebNormalSetting');
  if (Tables = nil) or (Columns = nil) or (Settings = nil) then Exit(Fail('树形模块缺少数据结构或常规设置。'));
  if Tables.Count <> 1 then Exit(Fail('树形模块首批仅接入单表，关联表留待后续核对。'));
  Plan.TableName := Str(Obj(Tables, '0'), 'fdTableName');
  Plan.AliasName := Str(Obj(Tables, '0'), 'fdEpithet');
  if not Ident(Plan.TableName) or not Ident(Plan.AliasName) then Exit(Fail('树形模块首批需要普通表名和合法别名。'));
  if Str(Obj(Tables, '0'), 'fdParent') <> '' then Exit(Fail('树形模块数据表必须是根表。'));
  for I := 0 to Columns.Count - 1 do
    if Obj(Columns, IntToStr(I)) = nil then Exit(Fail('树形字段数据缺少连续数字行键。'));
  Parsed := nil;
  try
    UniqueRule := Obj(Settings, '主表唯一');
    if UniqueRule = nil then begin
      Parsed := TJSONObject.ParseJSONValue(Str(Settings, '主表唯一'));
      if Parsed is TJSONObject then UniqueRule := TJSONObject(Parsed);
    end;
    Plan.KeyField := Field(Str(UniqueRule, 'cbField'));
  finally Parsed.Free; end;
  Plan.ParentField := Field(Str(Settings, '上级字段'));
  Plan.OrderField := Field(Str(Settings, '排序字段'));
  Plan.EditorFrame := Str(Settings, '编辑窗体');
  if Plan.KeyField = '' then Exit(Fail('主表唯一必须指定根表中存在的节点主键字段。'));
  if Plan.ParentField = '' then Exit(Fail('上级字段必须指定根表中存在的父节点字段。'));
  if Plan.OrderField = '' then Exit(Fail('排序字段必须指定根表中存在的节点排序字段。'));
  if SameText(Plan.KeyField, Plan.ParentField) or SameText(Plan.KeyField, Plan.OrderField) or
    SameText(Plan.ParentField, Plan.OrderField) then Exit(Fail('节点主键、上级字段与排序字段不能相同。'));
  Result := True;
end;

end.
