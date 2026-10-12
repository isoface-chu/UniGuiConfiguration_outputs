unit ugConfiguration.ListEditorDetail;

{ mtListEditor 的从表（明细）支持：计划解析 + 明细区 DFM + 明细加载脚本。
   本单元先承载"只读联动"（G1）：选中主记录时按关联字段加载明细并只读显示。
   写入（新增行/删除行/复制行、行号、从表唯一/非空、原子提交、删主记录连明细）在后续切片
   接入，接在同一个计划对象上，避免两处各解析一遍配置。

   配置来源（与 mtMasterSlave 同一套设置项语义）：
     - TWebDetailedStructure.cdsTables.Data[0]：从表名 + 别名（只支持一张从表）
     - 常规设置「关联字段」：主表字段（带别名）；「关联从表」：从表字段（带别名）
     - TWebDetailedStructure.cdsColumns.Data：从表字段（fdSELECT 勾选）、对象类型、标题
     - 常规设置「隐藏字段-从表」：只从明细区隐藏（表格列与取数都不受影响） }

interface

uses System.SysUtils, System.Classes, System.JSON, System.StrUtils;

type
  TListEditorDetailPlan = class
  private
    FFields: TStringList;    // 从表字段（不带别名，顺序＝明细区列顺序）
    FCaptions: TStringList;  // 与 FFields 对应，DFM 编码后的标题
    FTypes: TStringList;     // 对象类型（用于控件/列类型判断）
    FHidden: TStringList;    // 隐藏字段-从表（不带别名）
    FTableName: string;
    FAliasName: string;
    FDetailKey: string;      // 关联从表（从表字段，不带别名）
    FMainKey: string;        // 关联字段（主表字段，不带别名）
    FTitle: string;          // 明细区标题（取「明细标题」/从表名）
    { 写入片（从表可编辑）：配置形状沿用宿主既有设置项，语义与 mtMasterSlave 同一套 ——
      「记录编号」(3000) 是从表结构分组里的自动编号设置（cbField + 编号方式 + 前缀/后缀/补位），
      指向**从表**字段；「明细编号」(3001) 是行号列（同一主记录内 1..N，删除/复制后重排，
      不参与从表唯一）；「从表唯一」(3002) = 记录编号字段 + cdsMultiSelectFields 组合唯一；
      「从表非空」(3003) = 分号分隔字段清单。 }
    FKeyField: string;       // 记录编号.cbField（从表字段，明细自动编号/唯一身份；可空）
    FKeyType: string;        // MaxInt / Guid
    FKeyPrefix: string;
    FKeySuffix: string;
    FKeyDigits: string;      // 补位位数（0＝不补位）
    FDetailNoField: string;  // 明细编号（行号列，从表字段；可空）
    FUniqueIDField: string;  // 从表唯一.cbField（记录编号字段；可空）
    FRequiredFields: TStringList;  // 从表非空（不带别名，按配置顺序）
    FUniqueFields: TStringList;    // 从表唯一（组合唯一字段，不带别名）
  public
    constructor Create;
    destructor Destroy; override;
    function FieldOf(const AName: string): Integer;
    function IsHidden(const AName: string): Boolean;
    property Fields: TStringList read FFields;
    property Captions: TStringList read FCaptions;
    property Types: TStringList read FTypes;
    property Hidden: TStringList read FHidden;
    property TableName: string read FTableName write FTableName;
    property AliasName: string read FAliasName write FAliasName;
    property DetailKey: string read FDetailKey write FDetailKey;
    property MainKey: string read FMainKey write FMainKey;
    property Title: string read FTitle write FTitle;
    { 明细区是否需要可编辑（＝主表处于写模式）。只读时下面这些写入项必须为空，
      配置了就在解析阶段明确拒绝，避免"配了不生效"。 }
    property KeyField: string read FKeyField write FKeyField;
    property KeyType: string read FKeyType write FKeyType;
    property KeyPrefix: string read FKeyPrefix write FKeyPrefix;
    property KeySuffix: string read FKeySuffix write FKeySuffix;
    property KeyDigits: string read FKeyDigits write FKeyDigits;
    property DetailNoField: string read FDetailNoField write FDetailNoField;
    property UniqueIDField: string read FUniqueIDField write FUniqueIDField;
    property RequiredFields: TStringList read FRequiredFields;
    property UniqueFields: TStringList read FUniqueFields;
  end;

{ 解析从表配置。返回 False 表示配置的从表不合法（Reason 写明原因）。
  没有配置从表（TWebDetailedStructure.cdsTables.Data 为空）时返回 False 且 Reason 为空 —— 调用方据此
  走"单根表"的既有路径。
  AWriteMode：主表是否处于写模式。只读时不允许配置「记录编号/明细编号/从表唯一/从表非空」，
  否则会出现"配了不生效"的设置项。 }
function TryPlanListEditorDetail(Config: TJSONObject; MainFields: TStringList;
  AWriteMode: Boolean; out Plan: TListEditorDetailPlan; out Reason: string): Boolean;

{ 明细区：容器 + 表格 + 列（含标题/隐藏）。AWritable=True 时是可写网格并带明细区小工具条
  （按钮由目录项 'Detail Row Group' 勾选决定）；False 时保持批次四的只读联动版式。
  插入位置由调用方决定。 }
procedure AddListEditorDetailPanel(Lines: TStringList; const Plan: TListEditorDetailPlan;
  AWritable: Boolean; AButtons: TStrings);

{ 明细行按钮的固定顺序 / 标题 / 图标位（图标位取自 mtDetail 的 Imgs 列表）。 }
function DetailButtonOrder(const AIndex: Integer): string;
function DetailButtonCaption(const AName: string): string;
function DetailButtonIcon(const AName: string): Integer;

{ 明细数据对象（cdsDetailed/dsDetailed）：插到 dfM 中 dsMain 之后（留在窗体内）。 }
procedure AddListEditorDetailDataSets(Lines: TStringList);
procedure AddListEditorDetailDataSetLines(Lines: TStringList);

{ 明细加载脚本：例程 LEDetailLoad（按当前主记录重新取数）+ 初始化调用 + 滚动联动绑定。 }
procedure AddListEditorDetailScript(Plan: TListEditorDetailPlan; Lines, Procs, Stmts,
  Events: TStringList);

{ 明细**写入**脚本（从表可编辑）：取号 / 父键回填 / 行号重排 / 非空与当前主记录内唯一校验，
  以及明细区三按钮（新增行/删除行/复制行）的例程与事件入口。
  由写入单元插在 btSaveOnClick **之前**（FastScript 先定义后调用），调用点见 ListEditorWrite。
  生成脚本刻意避开 for..in、TBookmark 与 TStringList：用 RecNo 做行间比较最稳。 }
procedure AddListEditorDetailWriteScript(const Plan: TListEditorDetailPlan; Procs: TStrings;
  AButtons: TStrings);

{ 明细网格的 dgEditing 补回：模板末尾会把整个 DFM 的 `dgEditing, ` 剥掉（记录区的编辑走记录区控件，
  主表格不要格内编辑），但**明细行是在明细网格里直接编辑的**，剥离后宿主里没法输入。 }
procedure RestoreDetailGridEditing(var DFM: string);

{ 有从表明细时的布局（宿主 2026-09-20 指定）：gridMain = alLeft、明细区 = alClient、
  pDetailHead 高度 = 主工具条 pButtons 的高度（从 DFM 里读实际值，不写死）。 }
procedure ApplyDetailLayout(Lines: TStringList);

implementation

{ 明细行按钮的固定顺序（只发射勾选的）。 }
function DetailButtonOrder(const AIndex: Integer): string;
begin
  case AIndex of
    0: Result := 'btDetailAppend'; 1: Result := 'btDetailInsert';
    2: Result := 'btDetailDelete'; 3: Result := 'btDetailCopy';
    4: Result := 'btDetailMoveUp'; 5: Result := 'btDetailMoveDown';
    6: Result := 'btDetailClear';
  else Result := '';
  end;
end;

{ 图标位：前 27 项取自 mtDetail 参考件的 Imgs 列表（新增行=7 addEdge、删除行=8 shanchu1、
  上移=20 xiangshang、下移=21 xiangxia）；插入行/复制行/清空 由宿主 2026-09-21 指定类名，
  追加在列表末尾：28 = icon-fuzhi（复制行）、29 = icon-caidanshouqi（插入行）、30 = icon-guanbi2fill（清空）。 }
function DetailButtonCaption(const AName: string): string;
begin
  if AName = 'btDetailAppend' then Result := '新增行'
  else if AName = 'btDetailInsert' then Result := '插入行'
  else if AName = 'btDetailDelete' then Result := '删除行'
  else if AName = 'btDetailCopy' then Result := '复制行'
  else if AName = 'btDetailMoveUp' then Result := '上移'
  else if AName = 'btDetailMoveDown' then Result := '下移'
  else if AName = 'btDetailClear' then Result := '清空'
  else Result := AName;
end;

function DetailButtonIcon(const AName: string): Integer;
begin
  if AName = 'btDetailAppend' then Result := 7
  else if AName = 'btDetailInsert' then Result := 29
  else if AName = 'btDetailDelete' then Result := 8
  else if AName = 'btDetailCopy' then Result := 28
  else if AName = 'btDetailMoveUp' then Result := 20
  else if AName = 'btDetailMoveDown' then Result := 21
  else if AName = 'btDetailClear' then Result := 30
  else Result := -1;
end;

{ DFM **属性值**里的非 ASCII 文本：必须写成引号**外面**的字符码（`#26126#32454`）。
  若写成 `'#26126#32454'`，宿主会把 `#26126` 当普通文本显示出来（宿主 2026-09-20 实测：
  明细区列标题显示成 #26126#32454#…）。工程里其它单元的中文标题都用这种写法。 }
function Enc(const V: string): string;
var C: Char;
begin
  Result := '';
  for C in V do Result := Result + '#' + IntToStr(Ord(C));
  if Result = '' then Result := #39#39;
end;

{ DFM 字符串常量：ASCII 走引号包裹（内部单引号翻倍）；非 ASCII 必须写成引号**外面**的
  字符码（`#26126`）。写成 `'#26126'` 会让宿主把 `#26126` 当普通文本显示出来
  （宿主 2026-09-20 实测：明细区列标题显示成 #26126#32454…）。
  纯 ASCII 输入时输出与旧实现逐字符一致，不会改变既有生成结果。 }
function Q(const V: string): string;
var C: Char; Open: Boolean;
begin
  Result := ''; Open := False;
  for C in V do
    if (Ord(C) < 32) or (Ord(C) > 126) then
    begin
      if Open then begin Result := Result + #39; Open := False; end;
      Result := Result + '#' + IntToStr(Ord(C));
    end
    else
    begin
      if not Open then begin Result := Result + #39; Open := True; end;
      if C = #39 then Result := Result + #39#39 else Result := Result + C;
    end;
  if Open then Result := Result + #39;
  if Result = '' then Result := #39#39;
end;


function Obj(J: TJSONObject; const K: string): TJSONObject;
var V: TJSONValue;
begin
  Result := nil;
  if J = nil then Exit;
  V := J.GetValue(K);
  if V is TJSONObject then Result := TJSONObject(V);
end;

function Str(J: TJSONObject; const K: string): string;
var V: TJSONValue;
begin
  Result := '';
  if J = nil then Exit;
  V := J.GetValue(K);
  if (V <> nil) and not (V is TJSONNull) then Result := V.Value;
end;

function Yes(const V: string): Boolean;
begin
  Result := SameText(V, 'True') or (V = '1') or (V = '-1');
end;

{ 解析 JSON 对象文本；不是对象/不是合法 JSON 时返回 nil（不抛异常，释放非对象的结果）。 }
function ParseObj(const V: string): TJSONObject;
var J: TJSONValue;
begin
  Result := nil;
  if Trim(V) = '' then Exit;
  J := TJSONObject.ParseJSONValue(V);
  if J = nil then Exit;
  if J is TJSONObject then Result := TJSONObject(J) else J.Free;
end;

{ 去掉表别名前缀：'b.FItemCode' → 'FItemCode'。 }
function Plain(const V: string): string;
begin
  Result := Trim(V);
  if Pos('.', Result) > 0 then Delete(Result, 1, Pos('.', Result));
end;

constructor TListEditorDetailPlan.Create;
begin
  inherited Create;
  FFields := TStringList.Create; FCaptions := TStringList.Create;
  FTypes := TStringList.Create; FHidden := TStringList.Create;
  FRequiredFields := TStringList.Create; FUniqueFields := TStringList.Create;
  FTitle := '明细';
end;

destructor TListEditorDetailPlan.Destroy;
begin
  FUniqueFields.Free; FRequiredFields.Free;
  FHidden.Free; FTypes.Free; FCaptions.Free; FFields.Free;
  inherited Destroy;
end;

function TListEditorDetailPlan.FieldOf(const AName: string): Integer;
begin
  Result := FFields.IndexOf(Plain(AName));
end;

function TListEditorDetailPlan.IsHidden(const AName: string): Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to FHidden.Count - 1 do
    if SameText(Plain(FHidden[I]), Plain(AName)) then Exit(True);
end;

function TryPlanListEditorDetail(Config: TJSONObject; MainFields: TStringList;
  AWriteMode: Boolean; out Plan: TListEditorDetailPlan; out Reason: string): Boolean;
var Tables, Columns, Row, Settings, KeyJSON, UniqueJSON, AutoJSON: TJSONObject;
  HiddenText, MainKeyText, DetailKeyText, KeyText, DetailNoText, UniqueText,
  RequiredText, AutoText: string;
  HiddenParts, Parts: TStringList;
  I, N: Integer; Name, Cap: string;

  { 任何失败路径统一从这里返回：计划与两个临时清单一起释放（只 FreeAndNil(Plan) 会漏掉后者）。 }
  procedure Release;
  begin
    FreeAndNil(Parts); FreeAndNil(HiddenParts); FreeAndNil(Plan);
  end;

  { 成功路径只收临时清单：**计划要交给调用方**（早期版本在这里连 Plan 一起 FreeAndNil，
    调用方拿到的是悬空指针——探针立刻 AV）。 }
  procedure ReleaseTemps;
  begin
    FreeAndNil(Parts); FreeAndNil(HiddenParts);
  end;

begin
  Result := False; Reason := ''; Plan := nil;
  if Config = nil then Exit;
  Tables := Obj(Obj(Obj(Config, 'TWebDetailedStructure'), 'cdsTables'), 'Data');
  Columns := Obj(Obj(Obj(Config, 'TWebDetailedStructure'), 'cdsColumns'), 'Data');
  if (Tables = nil) or (Tables.Count = 0) then Exit;   // 没有从表：走单根表路径
  if (Columns = nil) or (Columns.Count = 0) then
  begin
    Reason := '已配置从表，但还没有选择从表字段。';
    Exit;
  end;
  if Tables.Count > 1 then
  begin
    Reason := 'mtListEditor 只支持一张从表（当前配置了 ' + IntToStr(Tables.Count) + ' 张）。';
    Exit;
  end;
  Settings := Obj(Config, 'TWebNormalSetting');
  HiddenParts := TStringList.Create;
  Parts := TStringList.Create;
  Parts.StrictDelimiter := True; Parts.Delimiter := ';';
  Row := Obj(Tables, '0');
  Plan := TListEditorDetailPlan.Create;
  Plan.TableName := Trim(Str(Row, 'fdTableName'));
  Plan.AliasName := Trim(Str(Row, 'fdEpithet'));
  if (Plan.TableName = '') or (Plan.AliasName = '') then
  begin
    Reason := '从表必须指定表名与别名。';
    Release;
    Exit;
  end;
  MainKeyText := Trim(Str(Settings, '关联字段'));
  DetailKeyText := Trim(Str(Settings, '关联从表'));
  if (MainKeyText = '') or (DetailKeyText = '') then
  begin
    Reason := '配置了从表就必须同时指定「关联字段」（主表字段）与「关联从表」（从表字段）。';
    Release;
    Exit;
  end;
  Plan.MainKey := Plain(MainKeyText);
  Plan.DetailKey := Plain(DetailKeyText);
  { 关联字段必须是主表字段（外部传入的主表字段清单，已去掉别名）。 }
  N := -1;
  for I := 0 to MainFields.Count - 1 do
    if SameText(Plain(MainFields[I]), Plan.MainKey) then begin N := I; Break; end;
  if N < 0 then
  begin
    Reason := '「关联字段」必须是主表字段：' + MainKeyText;
    Release;
    Exit;
  end;
  { 从表字段：勾选的都进明细区（隐藏字段只从明细区隐藏）。 }
  HiddenText := Str(Settings, '隐藏字段-从表');
  for I := 0 to Columns.Count - 1 do
  begin
    Row := Obj(Columns, IntToStr(I));
    if Row = nil then Continue;
    if not Yes(Str(Row, 'fdSELECT')) then Continue;
    Name := Plain(Str(Row, 'fdCOLUMN_NAME'));
    if Name = '' then Continue;
    if Plan.FieldOf(Name) >= 0 then Continue;
    Cap := Trim(Str(Row, 'fdCAPTION'));
    if Cap = '' then Cap := Name;
    Plan.Fields.Add(Name);
    Plan.Captions.Add(Cap);           // 纯文本，写出 DFM 时再编码
    Plan.Types.Add(LowerCase(Trim(Str(Row, 'fdOBJECT_TYPE'))));
    { 隐藏字段-从表 里存的是带别名的名字（b.FItemNote），比较前要去掉别名。 }
    if HiddenText <> '' then
    begin
      HiddenParts.StrictDelimiter := True; HiddenParts.Delimiter := ';';
      HiddenParts.DelimitedText := HiddenText;
      for N := 0 to HiddenParts.Count - 1 do
        if SameText(Plain(HiddenParts[N]), Name) then
        begin
          Plan.Hidden.Add(Name);
          Break;
        end;
    end;
  end;
  if Plan.Fields.Count = 0 then
  begin
    Reason := '从表没有任何已勾选字段。';
    Release;
    Exit;
  end;
  if Plan.FieldOf(Plan.DetailKey) < 0 then
  begin
    Reason := '「关联从表」必须是已勾选的从表字段：' + DetailKeyText;
    Release;
    Exit;
  end;
  { 主键为数据库自增时**写模式**不能配从表：明细行必须在提交前带上父键，而自增主键由服务端在提交后
    才回填，两者无法在一次原子提交里同时成立（旁证：mtMasterSlave 完全没有 DBAutoincrement）。
    只读联动不受此限：加载明细只需要当前主记录的键值，而那个值得到了（批次四已宿主验收的组合
    里就可能含自增主键）——所以这条只在 AWriteMode 下生效，不把既有只读模块判死。 }
  AutoText := Trim(Str(Settings, '自动编号'));
  if AWriteMode and (AutoText <> '') then
  begin
    AutoJSON := ParseObj(AutoText);
    try
      if (AutoJSON <> nil) and SameText(Trim(Str(AutoJSON, 'cbAutoNumberType')), 'DBAutoincrement') then
      begin
        Reason := '主键使用数据库自增时不能配置从表写入：明细必须在提交前带上父键，才能与主记录一次原子提交；'
          + '请把自动编号改为 MaxInt 或 Guid。';
        Release;
        Exit;
      end;
    finally
      AutoJSON.Free;
    end;
  end;
  { 写入项（记录编号/明细编号/从表唯一/从表非空）：只读列表下配置了会被静默忽略，
    这里直接拒绝，避免"配了不生效"。 }
  KeyText := Trim(Str(Settings, '记录编号'));
  DetailNoText := Trim(Str(Settings, '明细编号'));
  UniqueText := Trim(Str(Settings, '从表唯一'));
  RequiredText := Trim(Str(Settings, '从表非空'));
  if (not AWriteMode) and ((KeyText <> '') or (DetailNoText <> '') or
    (UniqueText <> '') or (RequiredText <> '')) then
  begin
    if KeyText <> '' then Name := '记录编号'
    else if DetailNoText <> '' then Name := '明细编号'
    else if UniqueText <> '' then Name := '从表唯一'
    else Name := '从表非空';
    Reason := '只读列表不能配置「' + Name + '」：它只在明细写入（新增行/删除行/复制行）时生效；'
      + '请同时启用新增、修改、保存、撤销，或取消该设置。';
    Release;
    Exit;
  end;
  { 记录编号＝明细行的自动编号（从表结构分组内的 3000，指向从表字段）。 }
  if KeyText <> '' then
  begin
    KeyJSON := ParseObj(KeyText);
    try
      if KeyJSON = nil then
      begin
        Reason := '「记录编号」配置不是有效 JSON 对象。';
        Release;
        Exit;
      end;
      KeyText := Trim(Str(KeyJSON, 'cbField'));
      Plan.KeyField := Plain(KeyText);
      if (Plan.KeyField = '') or (Plan.FieldOf(Plan.KeyField) < 0) then
      begin
        Reason := '「记录编号」必须指定一个已勾选的从表字段：' + KeyText;
        Release;
        Exit;
      end;
      Plan.KeyType := Trim(Str(KeyJSON, 'cbAutoNumberType'));
      Plan.KeyPrefix := Str(KeyJSON, 'edPrefix');
      Plan.KeySuffix := Str(KeyJSON, 'edSuffix');
      Plan.KeyDigits := Trim(Str(KeyJSON, 'seDigitCapacity'));
      if SameText(Plan.KeyType, 'DBAutoincrement') then
      begin
        Reason := '明细「记录编号」不支持数据库自增（DBAutoincrement）：明细必须在提交前拿到编号'
          + '才能与主记录一次原子提交；请改用 MaxInt 或 Guid。';
        Release;
        Exit;
      end;
      if not (SameText(Plan.KeyType, 'MaxInt') or SameText(Plan.KeyType, 'Guid')) then
      begin
        Reason := '明细「记录编号」当前支持 MaxInt（最大整数+1）与 Guid；' + KeyText
          + ' 的编号方式「' + Plan.KeyType + '」尚未实现，请改用两者之一。';
        Release;
        Exit;
      end;
      N := Plan.FieldOf(Plan.KeyField);
      if SameText(Plan.KeyType, 'MaxInt') and
         ((N < 0) or not SameText(Plan.Types[N], 'number')) then
      begin
        Reason := 'MaxInt 明细编号需要数值型从表字段：' + KeyText;
        Release;
        Exit;
      end;
      N := StrToIntDef(Plan.KeyDigits, 0);
      if (Plan.KeyDigits <> '') and ((N < 0) or (N > 30)) then
      begin
        Reason := '明细编号补位位数必须为 0（不补位）到 30。';
        Release;
        Exit;
      end;
    finally
      KeyJSON.Free;
    end;
  end;
  { 明细编号＝行号列（同一主记录内 1..N；不参与从表唯一）。 }
  if DetailNoText <> '' then
  begin
    Plan.DetailNoField := Plain(DetailNoText);
    if Plan.FieldOf(Plan.DetailNoField) < 0 then
    begin
      Reason := '「明细编号」必须是已勾选的从表字段：' + DetailNoText;
      Release;
      Exit;
    end;
    if SameText(Plan.DetailNoField, Plan.DetailKey) then
    begin
      Reason := '「明细编号」不能与「关联从表」用同一字段：行号与父键语义不同。';
      Release;
      Exit;
    end;
    if SameText(Plan.DetailNoField, Plan.KeyField) then
    begin
      Reason := '「明细编号」（行号）不能与「记录编号」（明细自动编号）用同一字段。';
      Release;
      Exit;
    end;
    N := Plan.FieldOf(Plan.DetailNoField);
    if (N >= 0) and not SameText(Plan.Types[N], 'number') then
    begin
      Reason := '「明细编号」是行号列，需要数值型从表字段：' + DetailNoText;
      Release;
      Exit;
    end;
  end;
  { 从表非空：分号分隔的字段清单（与 mtMasterSlave 同一形状）。 }
  if RequiredText <> '' then
  begin
    Parts.DelimitedText := RequiredText;
    for I := 0 to Parts.Count - 1 do
    begin
      Name := Plain(Parts[I]);
      if Name = '' then Continue;
      if Plan.FieldOf(Name) < 0 then
      begin
        Reason := '「从表非空」字段必须是已勾选的从表字段：' + Parts[I];
        Release;
        Exit;
      end;
      if Plan.RequiredFields.IndexOf(Name) < 0 then Plan.RequiredFields.Add(Name);
    end;
    if Plan.RequiredFields.Count = 0 then
    begin
      Reason := '「从表非空」没有有效字段。';
      Release;
      Exit;
    end;
  end;
  { 从表唯一：记录编号字段 + cdsMultiSelectFields 组合唯一，在当前主记录范围内比较。 }
  if UniqueText <> '' then
  begin
    UniqueJSON := ParseObj(UniqueText);
    try
      if UniqueJSON = nil then
      begin
        Reason := '「从表唯一」配置不是有效 JSON 对象。';
        Release;
        Exit;
      end;
      Plan.UniqueIDField := Plain(Trim(Str(UniqueJSON, 'cbField')));
      Parts.DelimitedText := Str(UniqueJSON, 'cdsMultiSelectFields');
      for I := 0 to Parts.Count - 1 do
      begin
        Name := Plain(Parts[I]);
        if Name = '' then Continue;
        if Plan.FieldOf(Name) < 0 then
        begin
          Reason := '「从表唯一」字段必须是已勾选的从表字段：' + Parts[I];
          Release;
          Exit;
        end;
        { 行号与父键在同一条主记录内是恒定值，放进唯一组合等于没校验 —— 明确拒绝而不是静默忽略。 }
        if SameText(Name, Plan.DetailNoField) then
        begin
          Reason := '「从表唯一」不能包含「明细编号」（行号）：行号在删除/复制后重排，'
            + '且不参与唯一校验。';
          Release;
          Exit;
        end;
        if SameText(Name, Plan.DetailKey) then
        begin
          Reason := '「从表唯一」不能包含「关联从表」（父键）：同一主记录内父键恒等，'
            + '放进唯一组合等于没有校验。';
          Release;
          Exit;
        end;
        if Plan.UniqueFields.IndexOf(Name) < 0 then Plan.UniqueFields.Add(Name);
      end;
      if Plan.UniqueFields.Count = 0 then
      begin
        Reason := '「从表唯一」请至少选择一个组合唯一字段。';
        Release;
        Exit;
      end;
    finally
      UniqueJSON.Free;
    end;
  end;
  Result := True;
  ReleaseTemps;
end;

procedure AddListEditorDetailDataSets(Lines: TStringList);
var At, I, J: Integer; Block: TStringList;
begin
  { 明细数据集必须**插在窗体内部**（dsMain 之后），不能追加到 Lines 末尾——
    追加到末尾会落到窗体 end 之后，等于对象不属于窗体，脚本就报 `标识符未宣告: 'cdsDetailed'`
    （宿主 2026-09-20 实测；而"按行扫描 object 就注册"的编译闸门正好抓不到这种位置错误）。 }
  At := -1;
  for I := 0 to Lines.Count - 1 do
    if Trim(Lines[I]) = 'object dsMain: TUgDataSource' then
    begin
      for J := I + 1 to Lines.Count - 1 do
        if Trim(Lines[J]) = 'end' then
        begin
          At := J + 1;
          Break;
        end;
      Break;
    end;
  if At < 0 then
    raise Exception.Create('mtListEditor 从表：模板结构不匹配（找不到 dsMain），无法插入明细数据集。');
  Block := TStringList.Create;
  try
    AddListEditorDetailDataSetLines(Block);
    for I := Block.Count - 1 downto 0 do Lines.Insert(At, Block[I]);
  finally
    Block.Free;
  end;
end;

procedure AddListEditorDetailDataSetLines(Lines: TStringList);
begin
  { 明细数据集：SQL 由脚本按当前主记录赋值（见 LEDetailLoad），这里只声明对象。 }
  Lines.Add('  object cdsDetailed: TUgClientDataSet');
  Lines.Add('    Aggregates = <>');
  Lines.Add('    Params = <>');
  Lines.Add('    Left = 220');
  Lines.Add('    Top = 556');
  Lines.Add('    PageRowCount = -1');
  Lines.Add('    Active = False');
  Lines.Add('  end');
  Lines.Add('  object dsDetailed: TUgDataSource');
  Lines.Add('    DataSet = cdsDetailed');
  Lines.Add('    Left = 300');
  Lines.Add('    Top = 556');
  Lines.Add('  end');
end;

procedure AddListEditorDetailPanel(Lines: TStringList; const Plan: TListEditorDetailPlan;
  AWritable: Boolean; AButtons: TStrings);
var Panel, Options: TStringList; I, K, Height, BarTop, BtnX: Integer; Btn: string;
begin
  Panel := TStringList.Create;
  try
    { 明细区：记录区下方（alTop），表格占满容器；高度按行数留出可视区（滚动条交给网格）。
      可写时多一条明细区小工具条（新增行/删除行/复制行），表格去掉只读并启用 dgEditing。 }
    if AWritable then Height := 200 else Height := 160;
    BarTop := 26;
    Panel.Add('  object pListEditorDetail: TUgContainerPanel');
    { 明细区布局按宿主 2026-09-20 的指定：**有从表明细时** gridMain = alLeft、明细区 = alClient
      （占右侧剩余空间）；不再生成标题标签 capListEditorDetail（标题由列标题表达）；
      pDetailHead 的高度与主工具条 pButtons 一致 —— 由模板生成后从 DFM 读实际值回填
      （见 ApplyDetailLayout），不写死。没有从表时模板不调用它，gridMain 保持 alClient。 }
    Panel.Add('    Align = alClient');
    Panel.Add('    Width = 480');
    Panel.Add('    Height = ' + IntToStr(Height));
    Panel.Add('    object pDetailHead: TUgContainerPanel');
    Panel.Add('      Align = alTop');
    Panel.Add('      Height = 33');
    if AWritable then
    begin
      { 明细区按钮放在头部容器里的小工具条中（与主工具条同构：AlLeft + 固定宽高）。
        只发射**勾选的**（目录项 'Detail Row Group'），顺序固定、带 mtDetail 的图标位；
        一个都没勾就不发工具条（头部只剩标题）。容器宽度按按钮数算（每个 68）。 }
      BtnX := 0;
      for K := 0 to 6 do
        if (DetailButtonOrder(K) <> '') and (AButtons.IndexOf(DetailButtonOrder(K)) >= 0) then
          Inc(BtnX, 68);
      if BtnX > 0 then
      begin
        Panel.Add('      object pDetailBar: TUgContainerPanel');
        Panel.Add('        Align = alLeft');
        { 容器宽度必须按按钮的**实际占位**算：按钮是 AlignWithMargins，除 Width 外还要吃左右边距
          （各 3），再加一点余量 —— 早前只按 68/个算，第 7 个（清空）被裁掉一角（宿主 2026-09-21 反馈）。 }
        Panel.Add('        Width = ' + IntToStr(BtnX + (BtnX div 68) * 6 + 8));
        Panel.Add('        Height = 22');
        BtnX := 0;
        for K := 0 to 6 do
        begin
          Btn := DetailButtonOrder(K);
          if (Btn = '') or (AButtons.IndexOf(Btn) < 0) then Continue;
          Panel.Add('        object ' + Btn + ': TUgButton');
          Panel.Add('          Align = alLeft');
          Panel.Add('          Left = ' + IntToStr(BtnX));
          Panel.Add('          Width = 64');
          Panel.Add('          Height = 22');
          Panel.Add('          AlignWithMargins = True');
          { 显式写边距（各 3）：容器宽度就是按 64+3+3 算的，不依赖默认值。 }
          Panel.Add('          Margins.Left = 3');
          Panel.Add('          Margins.Right = 3');
          Panel.Add('          Images = Imgs');
          Panel.Add('          ImageIndex = ' + IntToStr(DetailButtonIcon(Btn)));
          Panel.Add('          Caption = ' + Enc(DetailButtonCaption(Btn)));
          Panel.Add('        end');
          Inc(BtnX, 68);
        end;
        Panel.Add('      end');
      end;
    end;
    Panel.Add('    end');
    Panel.Add('    object gridDetail: TUgDBGrid');
    Panel.Add('      Left = 0');
    Panel.Add('      Top = ' + IntToStr(BarTop));
    Panel.Add('      Width = 480');
    Panel.Add('      Height = ' + IntToStr(Height - BarTop - 8));
    Panel.Add('      AlignWithMargins = True');
    Panel.Add('      Align = alClient');
    Panel.Add('      DataSource = dsDetailed');
    if not AWritable then Panel.Add('      ReadOnly = True');
    Options := TStringList.Create;
    try
      Options.Add('dgTitles');
      Options.Add('dgIndicator');
      Options.Add('dgColLines');
      Options.Add('dgRowLines');
      Options.Add('dgRowSelect');
      Options.Add('dgConfirmDelete');
      Options.Add('dgAutoRefreshRow');
      { 可写网格必须带 dgEditing（只读网格不带）。提交时的 dgEditing, 前缀由模板统一剥离，
        这里写出来是为了让"可写/只读"在 DFM 上可判读。 }
      if AWritable then Options.Insert(0, 'dgEditing');
      Panel.Add('      Options = [' + string.Join(', ', Options.ToStringArray) + ']');
    finally
      Options.Free;
    end;
    Panel.Add('      LoadMask.Message = ' + Q('Loading data...'));
    Panel.Add('      StoreUserSettings = False');
    Panel.Add('      MultiColumnSort = False');
    Panel.Add('      WebOptions.Paged = False');
    Panel.Add('      Columns = <');
    for I := 0 to Plan.Fields.Count - 1 do
    begin
      Panel.Add('        item');
      Panel.Add('          FieldName = ' + Q(Plan.Fields[I]));
      Panel.Add('          Title.Caption = ' + Enc(Plan.Captions[I]));
      Panel.Add('          Width = 120');
      Panel.Add('          Sortable = False');
      Panel.Add('          Menu.ColumnHideable = False');
      if Plan.IsHidden(Plan.Fields[I]) then Panel.Add('          Visible = False');
      Panel.Add('        end');
    end;
    Panel.Add('      >');
    Panel.Add('    end');
    Panel.Add('  end');
    { 这里是"追加"，必须正序：倒序只适用于在固定下标处插入。 }
    for I := 0 to Panel.Count - 1 do Lines.Add(Panel[I]);
  finally
    Panel.Free;
  end;
end;

procedure AddListEditorDetailScript(Plan: TListEditorDetailPlan; Lines, Procs, Stmts,
  Events: TStringList);

  function SelectList: string;
  var I: Integer;
  begin
    Result := '';
    for I := 0 to Plan.Fields.Count - 1 do
    begin
      if I > 0 then Result := Result + ', ';
      Result := Result + Plan.AliasName + '.' + Plan.Fields[I];
    end;
  end;

begin
  { 按当前主记录取明细：主键为空（没有当前行）时直接清空，不发查询。 }
  Procs.Add('//按当前主记录加载明细（只读联动）');
  Procs.Add('procedure LEDetailLoad;');
  Procs.Add('var C: TUgClientDataSet; K: Variant;');
  Procs.Add('begin');
  Procs.Add('  C := cdsDetailed;');
  Procs.Add('  if C = nil then Exit;');
  Procs.Add('  K := Null;');
  Procs.Add('  if cdsMain.Active and not cdsMain.IsEmpty then');
  Procs.Add('    K := cdsMain.FieldByName(' + QuotedStr(Plan.MainKey) + ').AsVariant;');
  Procs.Add('  C.Close;');
  Procs.Add('  if VarToStr(K) = '''' then Exit;');
  Procs.Add('  C.DataNodeName := cDataNodeName;');
  Procs.Add('  C.CommandText := ' + QuotedStr('select ' + SelectList + ' from ' +
    Plan.TableName + ' ' + Plan.AliasName + ' where ' + Plan.AliasName + '.' +
    Plan.DetailKey + ' = :masterKey') + ';');
  Procs.Add('  C.ParamByName(''masterKey'').Value := K;');
  Procs.Add('  C.Open;');
  Procs.Add('end;');
  Procs.Add('');
  { 主记录滚动/重载后联动；初始化末尾也调用一次，避免首行不触发 AfterScroll 时不显示明细。 }
  Procs.Add('procedure LEDetailRefresh(DataSet: TDataSet);');
  Procs.Add('begin');
  { 明细**有未提交改动时不要重载**。宿主 2026-09-20 实测：明细校验失败弹完提示后，框架会再同步
    一次主数据集 → AfterScroll → 无条件重载明细，把用户刚新增/编辑的行刷回原值；编辑会话中明细区
    属于用户，不能这样刷掉。
    判据用 ChangeCount 而不是 LEInternal/LEState：那两个全局量只在**写模式**下声明，
    只读模块（本单元同样会生成明细联动）引用它们会编译不过（编译闸门抓到过）。 }
  Procs.Add('  if cdsDetailed.Active and (cdsDetailed.ChangeCount > 0) then Exit;');
  Procs.Add('  LEDetailLoad;');
  Procs.Add('end;');
  Procs.Add('');
  Stmts.Add('  LEDetailLoad;');
  Events.Add('    ' + QuotedStr('cdsMain|<This>.AfterScroll:LEDetailRefresh'));
end;

procedure AddListEditorDetailWriteScript(const Plan: TListEditorDetailPlan; Procs: TStrings;
  AButtons: TStrings);
var I: Integer; F, Cap, VarList, Cond, DataChecks, Emit: string;
  KeyField, NoField, Parent, MainKey, DetailTable, DetailAlias: string;
  IsGuid: Boolean;

  procedure A(const V: string);
  begin
    Procs.Add(V);
  end;

  { MaxInt 取号：读明细表的最大编号 +1。Guid 模式不生成这个函数，避免"定义了没人用"。 }
  procedure EmitMaxKey;
  begin
    A('//明细取号：读明细表的最大编号 +1（保存前统一取一次，避免批量新增时互相重号）');
    A('//只取候选号，不占号；最终必须由数据库主键/唯一约束防重。');
    A('function LEDetailGetMaxKey: Integer;');
    A('var C: TUgClientDataSet; V: Variant; N: Integer;');
    A('begin');
    A('  C := TUgClientDataSet.Create(nil);');
    A('  try');
    A('    C.DataNodeName := cDataNodeName;');
    A('    C.PageRowCount := 1;');
    A('    C.CommandText := ' + QuotedStr('select max(' + DetailAlias + '.' + KeyField +
      ') as DetailMax from ' + DetailTable + ' ' + DetailAlias) + ';');
    A('    C.Open;');
    A('    N := 0;');
    A('    if not C.FieldByName(''DetailMax'').IsNull then');
    A('    begin');
    A('      V := C.FieldByName(''DetailMax'').AsVariant;');
    A('      if (V >= 2147483647) or (V < (-2147483647 - 1)) then');
    A('        RaiseException(UGMM.LT(''明细编号超出INT范围，不能继续新增。''));');
    A('      N := V;');
    A('    end;');
    A('    Result := N + 1;');
    A('  finally');
    A('    C.Free;');
    A('  end;');
    A('end;');
    A('');
  end;

begin
  KeyField := Plan.KeyField;
  NoField := Plan.DetailNoField;
  Parent := Plan.DetailKey;
  MainKey := Plan.MainKey;
  DetailTable := Plan.TableName;
  DetailAlias := Plan.AliasName;
  IsGuid := SameText(Plan.KeyType, 'Guid');

  if (KeyField <> '') and not IsGuid then EmitMaxKey;

  { 空白占位行的判据：任一业务字段有内容（编号/行号/父键不算）。与 mtMasterSlave 的
    DetailRowHasData 同一套语义 —— 空行是"待录入的占位行"，不是错误数据。 }
  DataChecks := '';
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    DataChecks := DataChecks + '  if Trim(cdsDetailed.FieldByName(' + QuotedStr(F) +
      ').AsString) <> '''' then Result := True;' + sLineBreak;
  end;
  A('//当前明细行是否含业务数据（编号/行号/父键不算）：空行是待录入的占位行');
  A('function LEDetailRowHasData: Boolean;');
  A('begin');
  A('  Result := False;');
  if DataChecks <> '' then
    for I := 0 to Plan.Fields.Count - 1 do
    begin
      F := Plan.Fields[I];
      if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
      A('  if Trim(cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsString) <> '''' then Result := True;');
    end;
  A('end;');
  A('');

  if NoField <> '' then
  begin
    A('//行号重排（同一主记录内 1..N；行号不参与从表唯一校验）');
    A('procedure LEDetailRenumber;');
    A('var L: Integer;');
    A('begin');
    A('  if not cdsDetailed.Active then Exit;');
    A('  L := 0;');
    A('  cdsDetailed.DisableControls;');
    A('  try');
    A('    cdsDetailed.First;');
    A('    while not cdsDetailed.Eof do');
    A('    begin');
    A('      Inc(L);');
    A('      if cdsDetailed.FieldByName(' + QuotedStr(NoField) + ').AsInteger <> L then');
    A('      begin');
    A('        cdsDetailed.Edit;');
    A('        cdsDetailed.FieldByName(' + QuotedStr(NoField) + ').AsInteger := L;');
    A('        cdsDetailed.Post;');
    A('      end;');
    A('      cdsDetailed.Next;');
    A('    end;');
    A('  finally');
    A('    cdsDetailed.EnableControls;');
    A('  end;');
    A('end;');
    A('');
  end;

  { 新增行：空白占位行**当场落库到数据集**（与 mtMasterSlave 的空白明细行同一做法）。
    刻意不留在 dsInsert 状态：宿主实测"保存时提交一条从未落库的插入行"会报
    `Blocking method Execute() could not be called.`（服务端提交插入行需要客户端同步），
    而且未落库的插入行会让连续点"新增行"被守卫拦下。 }
  A('//新增行：空白占位行当场落库（不留在未提交的插入态）');
  A('procedure LEDetailAppendRow;');
  if NoField <> '' then A('var L: Integer;');
  A('begin');
  A('  if not cdsDetailed.Active then Exit;');
  A('  cdsDetailed.DisableControls;');
  A('  try');
  if NoField <> '' then
  begin
    A('    //行号取当前最大行号 +1，不依赖排序或索引');
    A('    L := 0;');
    A('    cdsDetailed.First;');
    A('    while not cdsDetailed.Eof do');
    A('    begin');
    A('      if cdsDetailed.FieldByName(' + QuotedStr(NoField) + ').AsInteger > L then');
    A('        L := cdsDetailed.FieldByName(' + QuotedStr(NoField) + ').AsInteger;');
    A('      cdsDetailed.Next;');
    A('    end;');
  end;
  A('    cdsDetailed.Append;');
  A('    if cdsMain.Active and not cdsMain.IsEmpty then');
  A('      cdsDetailed.FieldByName(' + QuotedStr(Parent) + ').AsString := cdsMain.FieldByName(' +
    QuotedStr(MainKey) + ').AsString;');
  if NoField <> '' then
    A('    cdsDetailed.FieldByName(' + QuotedStr(NoField) + ').AsInteger := L + 1;');
  A('    cdsDetailed.Post;');
  A('  finally');
  A('    cdsDetailed.EnableControls;');
  A('  end;');
  A('  gridDetail.SetFocus;');
  A('end;');
  A('');

  { 复制行：复制可见业务字段（编号与行号重新取）。 }
  VarList := '';
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    if VarList <> '' then VarList := VarList + ', ';
    VarList := VarList + 'C' + IntToStr(I);
  end;
  A('//复制行：复制可见业务字段；编号重新取、行号重排');
  A('procedure LEDetailCopyRow;');
  if VarList <> '' then A('var ' + VarList + ': Variant;');
  A('begin');
  A('  if not cdsDetailed.Active or cdsDetailed.IsEmpty then Exit;');
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    A('  C' + IntToStr(I) + ' := cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsVariant;');
  end;
  A('  LEDetailAppendRow;');
  A('  cdsDetailed.Edit;');
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    A('  cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsVariant := C' + IntToStr(I) + ';');
  end;
  A('  cdsDetailed.Post;');
  if NoField <> '' then A('  LEDetailRenumber;');
  A('end;');
  A('');

  A('//插入行：在当前行**之前**插入一条空白占位行（当场落库），行号随后重排');
  A('procedure LEDetailInsertRow;');
  A('begin');
  A('  if not cdsDetailed.Active then Exit;');
  A('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Post;');
  A('  if cdsDetailed.IsEmpty then');
  A('  begin');
  A('    //空表时没有"当前行"可插，等价于新增一行（不调用 LEDetailAppendRow：它在后面才定义，');
  A('    //FastScript 要求先定义后调用）');
  A('    cdsDetailed.Append;');
  A('    if cdsMain.Active and not cdsMain.IsEmpty then');
  A('      cdsDetailed.FieldByName(' + QuotedStr(Parent) + ').AsString := cdsMain.FieldByName(' +
    QuotedStr(MainKey) + ').AsString;');
  A('    cdsDetailed.Post;');
  A('    gridDetail.SetFocus;');
  A('    Exit;');
  A('  end;');
  A('  cdsDetailed.DisableControls;');
  A('  try');
  A('    cdsDetailed.Insert;');
  A('    if cdsMain.Active and not cdsMain.IsEmpty then');
  A('      cdsDetailed.FieldByName(' + QuotedStr(Parent) + ').AsString := cdsMain.FieldByName(' +
    QuotedStr(MainKey) + ').AsString;');
  A('    cdsDetailed.Post;');
  A('  finally');
  A('    cdsDetailed.EnableControls;');
  A('  end;');
  A('  gridDetail.SetFocus;');
  A('end;');
  A('');
  A('//上移/下移：与相邻行**交换业务字段值**（编号与父键留在原位，行号随后重排）');
  A('procedure LEDetailMoveUpRow;');
  if VarList <> '' then A('var ' + VarList + ': Variant;');
  if VarList <> '' then A('    ' + StringReplace(VarList, 'C', 'D', [rfReplaceAll]) + ': Variant;');
  A('begin');
  A('  if not cdsDetailed.Active or cdsDetailed.IsEmpty then Exit;');
  A('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Post;');
  A('  if cdsDetailed.Bof then Exit;');
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    A('  C' + IntToStr(I) + ' := cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsVariant;');
  end;
  A('  cdsDetailed.Prior;');
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    A('  D' + IntToStr(I) + ' := cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsVariant;');
  end;
  A('  cdsDetailed.Edit;');
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    A('  cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsVariant := C' + IntToStr(I) + ';');
  end;
  A('  cdsDetailed.Post;');
  A('  cdsDetailed.Next;');
  A('  cdsDetailed.Edit;');
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    A('  cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsVariant := D' + IntToStr(I) + ';');
  end;
  A('  cdsDetailed.Post;');
  if NoField <> '' then A('  LEDetailRenumber;');
  A('end;');
  A('');
  A('procedure LEDetailMoveDownRow;');
  if VarList <> '' then A('var ' + VarList + ': Variant;');
  if VarList <> '' then A('    ' + StringReplace(VarList, 'C', 'D', [rfReplaceAll]) + ': Variant;');
  A('begin');
  A('  if not cdsDetailed.Active or cdsDetailed.IsEmpty then Exit;');
  A('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Post;');
  A('  if cdsDetailed.Eof then Exit;');
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    A('  C' + IntToStr(I) + ' := cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsVariant;');
  end;
  A('  cdsDetailed.Next;');
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    A('  D' + IntToStr(I) + ' := cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsVariant;');
  end;
  A('  cdsDetailed.Edit;');
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    A('  cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsVariant := C' + IntToStr(I) + ';');
  end;
  A('  cdsDetailed.Post;');
  A('  cdsDetailed.Prior;');
  A('  cdsDetailed.Edit;');
  for I := 0 to Plan.Fields.Count - 1 do
  begin
    F := Plan.Fields[I];
    if SameText(F, KeyField) or SameText(F, NoField) or SameText(F, Parent) then Continue;
    if Plan.IsHidden(F) then Continue;
    A('  cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsVariant := D' + IntToStr(I) + ';');
  end;
  A('  cdsDetailed.Post;');
  if NoField <> '' then A('  LEDetailRenumber;');
  A('end;');
  A('');
  A('//清空：删掉当前主记录的全部明细行（保存时才真正落库删除，与主记录一次原子提交）');
  A('procedure LEDetailClearRows;');
  A('begin');
  A('  if not cdsDetailed.Active or cdsDetailed.IsEmpty then Exit;');
  A('  if not ConfirmAction(''是否清空当前主记录的全部明细行？'') then Exit;');
  A('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Cancel;');
  A('  cdsDetailed.DisableControls;');
  A('  try');
  A('    cdsDetailed.First;');
  A('    while not cdsDetailed.Eof do cdsDetailed.Delete;');
  A('  finally');
  A('    cdsDetailed.EnableControls;');
  A('  end;');
  A('end;');
  A('');
  A('//删除行（删除后重排行号）');
  A('procedure LEDetailDeleteRow;');
  A('begin');
  A('  if not cdsDetailed.Active or cdsDetailed.IsEmpty then Exit;');
  A('  if not ConfirmAction(''是否删除当前明细行？'') then Exit;');
  A('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Cancel;');
  A('  if cdsDetailed.IsEmpty then Exit;');
  A('  cdsDetailed.Delete;');
  if NoField <> '' then A('  LEDetailRenumber;');
  A('end;');
  A('');
  { 7 个按钮的入口：只发射**勾选的**（每个入口引用自己的按钮控件，未勾选就不能发射，
    否则脚本引用不存在的控件编译不过）。入口内部一律先看 Enabled（与其它入口一致），
    动作之后重算按钮可用性（宿主 2026-09-20 反馈：新增一行后删除/复制仍是灰的）。 }
  for I := 0 to 6 do
  begin
    F := DetailButtonOrder(I);
    if (F = '') or (AButtons.IndexOf(F) < 0) then Continue;
    if F = 'btDetailAppend' then Emit := 'LEDetailAppendRow'
    else if F = 'btDetailInsert' then Emit := 'LEDetailInsertRow'
    else if F = 'btDetailDelete' then Emit := 'LEDetailDeleteRow'
    else if F = 'btDetailCopy' then Emit := 'LEDetailCopyRow'
    else if F = 'btDetailMoveUp' then Emit := 'LEDetailMoveUpRow'
    else if F = 'btDetailMoveDown' then Emit := 'LEDetailMoveDownRow'
    else Emit := 'LEDetailClearRows';
    A('procedure ' + F + 'OnClick(Sender: TObject);');
    A('begin');
    A('  if not ' + F + '.Enabled then Exit;');
    A('  ' + Emit + ';');
    A('  LERefresh;');
    A('end;');
    A('');
  end;

  { 先把明细网格里"正在编辑的那一行"落库。宿主在**明细网格还有未提交编辑**时不允许弹阻塞对话框
    （宿主 2026-09-20 实测：保存时校验失败报 `Blocking method Execute() could not be called.`，
    因为保存处理里要弹提示框，而客户端那边还挂着一个未提交的网格编辑）。 }
  A('//把明细网格里正在编辑的那一行先落库（保存处理里要弹提示框，宿主不允许带着未提交编辑弹阻塞框）');
  A('procedure LEDetailFlushRow;');
  A('begin');
  A('  if not cdsDetailed.Active then Exit;');
  A('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Post;');
  A('end;');
  A('');

  { 保存前：补父键/编号/行号，丢弃空白占位行；配了从表非空且没有有效明细时明确提示。 }
  A('//保存前统一处理明细：补齐父键、自动编号、行号，并丢弃空白占位行');
  A('//父键取主记录内存中的键值：MaxInt/Guid 主键提交前已知；自增主键 + 从表已在配置解析时拒绝。');
  A('procedure LEDetailPrepare;');
  A('var K: string; N, L, Valid: Integer; Changed: Boolean;');
  A('begin');
  A('  if not cdsDetailed.Active then Exit;');
  A('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Post;');
  A('  K := '''';');
  A('  if cdsMain.Active and not cdsMain.IsEmpty then');
  A('    K := cdsMain.FieldByName(' + QuotedStr(MainKey) + ').AsString;');
  A('  if K = '''' then');
  A('    RaiseException(UGMM.LT(''主记录还没有编号，无法保存明细。''));');
  if (KeyField <> '') and not IsGuid then A('  N := LEDetailGetMaxKey;')
  else A('  N := 0;');
  A('  L := 0;');
  A('  Valid := 0;');
  A('  cdsDetailed.DisableControls;');
  A('  try');
  A('    cdsDetailed.First;');
  A('    while not cdsDetailed.Eof do');
  A('    begin');
  A('      Inc(L);');
  A('      if LEDetailRowHasData then');
  A('      begin');
  A('        Inc(Valid);');
  A('        Changed := False;');
  A('        if cdsDetailed.FieldByName(' + QuotedStr(Parent) + ').AsString <> K then');
  A('        begin');
  A('          Changed := True; cdsDetailed.Edit;');
  A('          cdsDetailed.FieldByName(' + QuotedStr(Parent) + ').AsString := K;');
  A('        end;');
  if KeyField <> '' then
  begin
    A('        if Trim(cdsDetailed.FieldByName(' + QuotedStr(KeyField) + ').AsString) = '''' then');
    A('        begin');
    A('          if not Changed then begin Changed := True; cdsDetailed.Edit; end;');
    if IsGuid then
      A('          cdsDetailed.FieldByName(' + QuotedStr(KeyField) + ').AsString := UGMM.CreateGuid;')
    else
    begin
      A('          cdsDetailed.FieldByName(' + QuotedStr(KeyField) + ').AsInteger := N;');
      A('          Inc(N);');
    end;
    A('        end;');
  end;
  if NoField <> '' then
  begin
    A('        if cdsDetailed.FieldByName(' + QuotedStr(NoField) + ').AsInteger <> L then');
    A('        begin');
    A('          if not Changed then begin Changed := True; cdsDetailed.Edit; end;');
    A('          cdsDetailed.FieldByName(' + QuotedStr(NoField) + ').AsInteger := L;');
    A('        end;');
  end;
  A('        if Changed then cdsDetailed.Post;');
  A('        cdsDetailed.Next;');
  A('      end');
  A('      else');
  A('      begin');
  A('        //空白占位行：只丢弃本次会话新增/改动的，已存在且未动过的行保持原样');
  A('        if cdsDetailed.UpdateStatus in [usInserted, usModified] then cdsDetailed.Delete');
  A('        else cdsDetailed.Next;');
  A('      end;');
  A('    end;');
  if NoField <> '' then A('    LEDetailRenumber;');
  A('  finally');
  A('    cdsDetailed.EnableControls;');
  A('  end;');
  if Plan.RequiredFields.Count > 0 then
  begin
    A('  if Valid = 0 then');
    A('    RaiseException(UGMM.LT(''请录入至少一条有效明细。''));');
  end;
  A('  cdsDetailed.First;');
  A('end;');
  A('');

  { 校验：只对**有内容的行**校验（与 mtMasterSlave 一致），非空与组合唯一都报明细行号。 }
  if (Plan.RequiredFields.Count > 0) or (Plan.UniqueFields.Count > 0) then
  begin
    A('//明细校验：只校验有内容的行；非空与组合唯一都报明细行号');
    A('//组合唯一在当前主记录内比较（明细数据集只加载当前主记录的明细），');
    A('//跨用户的并发重复由数据库唯一约束兜底。');
    A('procedure LEDetailCheck;');
    Cond := 'var L, I: Integer; K, V, Values: string; Keys, Rows: TStringList;';
    A(Cond);
    A('begin');
    A('  if not cdsDetailed.Active or cdsDetailed.IsEmpty then Exit;');
    A('  Keys := TStringList.Create;');
    A('  Rows := TStringList.Create;');
    A('  cdsDetailed.DisableControls;');
    A('  try');
    A('    cdsDetailed.First;');
    A('    L := 0;');
    A('    while not cdsDetailed.Eof do');
    A('    begin');
    A('      Inc(L);');
    A('      if LEDetailRowHasData then');
    A('      begin');
    for I := 0 to Plan.RequiredFields.Count - 1 do
    begin
      F := Plan.RequiredFields[I];
      Cap := Plan.Captions[Plan.FieldOf(F)];
      A('        if Trim(cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsString) = '''' then');
      A('          RaiseException(UGMM.LT(''第'') + IntToStr(L) + UGMM.LT(''行明细的'') + UGMM.LT(' +
        QuotedStr(Cap) + ') + UGMM.LT(''不能为空。''));');
    end;
    if Plan.UniqueFields.Count > 0 then
    begin
      A('        K := ''''; Values := '''';');
      for I := 0 to Plan.UniqueFields.Count - 1 do
      begin
        F := Plan.UniqueFields[I];
        Cap := Plan.Captions[Plan.FieldOf(F)];
        A('        V := Trim(cdsDetailed.FieldByName(' + QuotedStr(F) + ').AsString);');
        A('        K := K + IntToStr(Length(V)) + '':'' + V + ''|'';');
        A('        if Values <> '''' then Values := Values + '', '';');
        A('        Values := Values + UGMM.LT(' + QuotedStr(Cap) + ') + ''='' + V;');
      end;
      A('        I := Keys.IndexOf(K);');
      A('        if I >= 0 then');
      A('          RaiseException(UGMM.LT(''第'') + IntToStr(L) + UGMM.LT(''行明细的组合唯一字段 ['') + Values +');
      A('            UGMM.LT(''] 与第 '') + Rows[I] + UGMM.LT('' 行重复，请修改后重试。''));');
      A('        Keys.Add(K);');
      A('        Rows.Add(IntToStr(L));');
    end;
    A('      end;');
    A('      cdsDetailed.Next;');
    A('    end;');
    A('    cdsDetailed.First;');
    A('  finally');
    A('    cdsDetailed.EnableControls;');
    A('    Rows.Free; Keys.Free;');
    A('  end;');
    A('end;');
    A('');
  end;

  A('//明细行落库前补父键：主记录键值此刻已在内存里（MaxInt/Guid 提交前已知）');
  A('procedure LEDetailBeforePost(DataSet: TDataSet);');
  A('begin');
  A('  if not (cdsDetailed.State in [dsEdit, dsInsert]) then Exit;');
  A('  if Trim(cdsDetailed.FieldByName(' + QuotedStr(Parent) + ').AsString) <> '''' then Exit;');
  A('  if cdsMain.Active and not cdsMain.IsEmpty then');
  A('    cdsDetailed.FieldByName(' + QuotedStr(Parent) + ').AsString := cdsMain.FieldByName(' +
    QuotedStr(MainKey) + ').AsString;');
  A('end;');
  A('');
end;

procedure RestoreDetailGridEditing(var DFM: string);
var P: Integer;
begin
  P := Pos('object gridDetail: TUgDBGrid', DFM);
  if P = 0 then Exit;
  P := PosEx('Options = [', DFM, P);
  if P = 0 then Exit;
  P := P + Length('Options = [');
  DFM := Copy(DFM, 1, P - 1) + 'dgEditing, ' + Copy(DFM, P, MaxInt);
end;



procedure ApplyDetailLayout(Lines: TStringList);

  { 把某个对象块里第一条匹配前缀的属性行替换成新值，保留原缩进。 }
  function ReplaceProp(const AHeader, APropPrefix, ANewValue: string): Boolean;
  var I, J, Indent: Integer; S: string;
  begin
    Result := False;
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) = AHeader then
      begin
        for J := I + 1 to Lines.Count - 1 do
        begin
          S := Trim(Lines[J]);
          if S = 'end' then Break;
          if Pos(APropPrefix, S) = 1 then
          begin
            Indent := Length(Lines[J]) - Length(TrimLeft(Lines[J]));
            Lines[J] := StringOfChar(' ', Indent) + ANewValue;
            Exit(True);
          end;
        end;
        Exit;
      end;
  end;

  { 读某个对象块里某条属性行的值。 }
  function ReadProp(const AHeader, APropPrefix: string): string;
  var I, J: Integer; S: string;
  begin
    Result := '';
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) = AHeader then
      begin
        for J := I + 1 to Lines.Count - 1 do
        begin
          S := Trim(Lines[J]);
          if S = 'end' then Break;
          if Pos(APropPrefix, S) = 1 then
            Exit(Trim(Copy(S, Length(APropPrefix) + 1, MaxInt)));
        end;
        Exit;
      end;
  end;

  { 往对象块的 Options = [ ... ] 里补一个选项（已有就不动）。 }
  procedure AddOption(const AHeader, AOption: string);
  var I, J, Indent: Integer; S: string;
  begin
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) = AHeader then
      begin
        for J := I + 1 to Lines.Count - 1 do
        begin
          S := Trim(Lines[J]);
          if S = 'end' then Break;
          if Pos('Options = [', S) = 1 then
          begin
            if Pos(AOption, S) = 0 then
            begin
              Indent := Length(Lines[J]) - Length(TrimLeft(Lines[J]));
              Lines[J] := StringOfChar(' ', Indent) + 'Options = [' + AOption + ', ' +
                Copy(S, Length('Options = [') + 1, MaxInt);
            end;
            Exit;
          end;
        end;
        Exit;
      end;
  end;

  { 读某个对象块的 Height 值。 }
  function ReadHeight(const AHeader: string): Integer;
  var I, J: Integer; S: string;
  begin
    Result := 0;
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) = AHeader then
      begin
        for J := I + 1 to Lines.Count - 1 do
        begin
          S := Trim(Lines[J]);
          if S = 'end' then Break;
          if Pos('Height = ', S) = 1 then
            Exit(StrToIntDef(Trim(Copy(S, Length('Height = ') + 1, MaxInt)), 0));
        end;
        Exit;
      end;
  end;

var H: Integer;
begin
  { 明细区占右侧剩余空间，主表格靠左。 }
  ReplaceProp('object gridMain: TUgDBGrid', 'Align = ', 'Align = alLeft');
  ReplaceProp('object pListEditorDetail: TUgContainerPanel', 'Align = ', 'Align = alClient');
  { 头部高度跟随主工具条（宿主指定"保持与 pButtons 的 Height 一致"）。 }
  H := ReadHeight('object pButtons: TUgContainerPanel');
  if H > 0 then
    ReplaceProp('object pDetailHead: TUgContainerPanel', 'Height = ', 'Height = ' + IntToStr(H));
  { 表格序号（常规配置）：宿主 2026-09-21 要求"窗体上所有的表格都开启序号属性" ——
    主表格开了 dgRowNumbers 时，明细表格也开（镜像主表格的实际取值，不另读配置，保证一致）。 }
  if Pos('dgRowNumbers', ReadProp('object gridMain: TUgDBGrid', 'Options = ')) > 0 then
    AddOption('object gridDetail: TUgDBGrid', 'dgRowNumbers');
end;


end.
