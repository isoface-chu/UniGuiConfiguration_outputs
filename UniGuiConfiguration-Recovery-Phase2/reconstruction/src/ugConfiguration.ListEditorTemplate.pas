unit ugConfiguration.ListEditorTemplate;

interface

uses System.SysUtils, System.Classes, System.JSON;

function TryBuildListEditorTemplate(Config: TJSONObject;
  out DFM, Reason: string): Boolean;

implementation

uses ugConfiguration.MultipleTemplate, ugConfiguration.ListEditorWrite,
  ugConfiguration.ListEditorDetail, ugConfiguration.ListEditorLayout;

{ 明细行按钮（目录项 'Detail Row Group'）：由明细区工具条消费，不参与主工具条。 }
function IsDetailRowButton(const AName: string): Boolean;
begin
  Result := (AName = 'btDetailAppend') or (AName = 'btDetailInsert') or (AName = 'btDetailDelete') or
    (AName = 'btDetailCopy') or (AName = 'btDetailMoveUp') or (AName = 'btDetailMoveDown') or
    (AName = 'btDetailClear');
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

function Dec(const V: string): string;
var I, J: Integer;
begin
  Result := ''; I := 1;
  while I <= Length(V) do
  begin
    if V[I] = '''' then
    begin
      Inc(I);
      while I <= Length(V) do
      begin
        if V[I] = '''' then
        begin
          Inc(I);
          if (I > Length(V)) or (V[I] <> '''') then Break;
        end;
        Result := Result + V[I];
        Inc(I);
      end;
    end
    else if V[I] = '#' then
    begin
      Inc(I); J := I;
      while (I <= Length(V)) and CharInSet(V[I], ['0'..'9']) do Inc(I);
      if I > J then Result := Result + Char(StrToInt(Copy(V, J, I - J)));
    end
    else
      Inc(I);
  end;
end;

procedure AddListEditorPresentation(Lines: TStringList);
var I, CodeStart, FinalBegin, EventAt, ToggleAt, SampleAt: Integer;
  Sample: string;
  Extra: TStringList;
begin
  CodeStart := -1; FinalBegin := -1; EventAt := -1; ToggleAt := -1; SampleAt := -1;
  for I := 0 to Lines.Count - 1 do
  begin
    if Trim(Lines[I]) = 'Codes.Strings = (' then CodeStart := I;
    if (CodeStart >= 0) and (SampleAt < 0) and (Pos('#98', Lines[I]) > 0) then SampleAt := I;
    if (CodeStart >= 0) and SameText(Dec(Trim(Lines[I])), 'begin') then FinalBegin := I;
    if Trim(Lines[I]) = 'Events.Strings = (' then EventAt := I;
    // 放在查询与关闭之间；同窗写入按钮随后会按工具条正常排序插入。
    if Trim(Lines[I]) = 'object tabFormGroup: TUgContainerPanel' then ToggleAt := I;
  end;
  Sample := '';
  if SampleAt >= 0 then Sample := Dec(Trim(Lines[SampleAt]));
  if (CodeStart < 0) or (FinalBegin < 0) or (EventAt < 0) or (ToggleAt < 0) then
    raise Exception.CreateFmt('mtListEditor 显示模板结构不匹配：Codes=%d，Begin=%d，Events=%d，Toggle=%d，Sample=%s。',
      [CodeStart, FinalBegin, EventAt, ToggleAt, Sample]);
  Extra := TStringList.Create;
  try
    Extra.Add('    object btToggleQuery: TUgButton');
    Extra.Add('      AlignWithMargins = True'); Extra.Add('      Align = alLeft');
    Extra.Add('      Left = 72'); Extra.Add('      Top = 3');
    Extra.Add('      Width = 75'); Extra.Add('      Height = 26');
    // 查询区初始收起，避免列表刚打开时占用记录区和表格区的可用空间。
    Extra.Add('      AutoWidth = True'); Extra.Add('      Caption = ' + Enc('展开查询'));
    Extra.Add('    end');
    for I := Extra.Count - 1 downto 0 do Lines.Insert(ToggleAt, Extra[I]);

    // 通过脚本改变 Visible，让 alTop/alLeft 的容器自动释放空间；不重建数据集。
    // 例程必须放在脚本末尾的主 begin 之前，不能附加在 end. 之后。
    CodeStart := -1; FinalBegin := -1;
    for I := 0 to Lines.Count - 1 do
    begin
      if Trim(Lines[I]) = 'Codes.Strings = (' then CodeStart := I;
      if (CodeStart >= 0) and SameText(Dec(Trim(Lines[I])), 'begin') then FinalBegin := I;
    end;
    Extra.Clear;
    Extra.Add('procedure btToggleQueryOnClick(Sender: TObject);');
    Extra.Add('begin');
    Extra.Add('  pQuery.Visible := not pQuery.Visible;');
    Extra.Add('  if pQuery.Visible then btToggleQuery.Caption := UGMM.LT(''收起查询'')');
    Extra.Add('  else btToggleQuery.Caption := UGMM.LT(''展开查询'');');
    Extra.Add('end;');
    for I := Extra.Count - 1 downto 0 do
      Lines.Insert(FinalBegin, '    ' + Enc(Extra[I]));

    // 代码行插入后重新定位事件段，避免索引受字符串长度变化影响。
    EventAt := -1;
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) = 'Events.Strings = (' then begin EventAt := I; Break; end;
    Lines.Insert(EventAt + 1, '    ''btToggleQuery|<This>.OnClick:btToggleQueryOnClick''');
  finally
    Extra.Free;
  end;
end;

procedure AddInitScript(Lines: TStringList; const InitStmts, HelperProcs: TStringList);
var I, J, DefAt, CallAt: Integer;
begin
  if (InitStmts.Count = 0) and (HelperProcs.Count = 0) then Exit;
  { 初始化语句要插在基础初始化（ExecuteUgWebRunFrameOnAfterRunScript）末尾；
    这些语句用到的例程必须定义在该过程之前——FastScript 不做前向解析，
    先调用后定义会报 Undeclared identifier。结构不匹配时直接抛错，由生成诊断报出。 }
  DefAt := -1; CallAt := -1;
  for I := 0 to Lines.Count - 1 do
  begin
    if Pos('procedure ExecuteUgWebRunFrameOnAfterRunScript', Dec(Trim(Lines[I]))) = 1 then
    begin
      DefAt := I;
      for J := I + 1 to Lines.Count - 1 do
        if SameText(Dec(Trim(Lines[J])), 'end;') then
        begin
          CallAt := J;
          Break;
        end;
      Break;
    end;
  end;
  if (DefAt < 0) or (CallAt < 0) then
    raise Exception.CreateFmt('mtListEditor 初始化脚本：模板结构不匹配（Def=%d，Call=%d）。',
      [DefAt, CallAt]);
  for I := InitStmts.Count - 1 downto 0 do
    Lines.Insert(CallAt, '    ' + Enc(InitStmts[I]));
  for I := HelperProcs.Count - 1 downto 0 do
    Lines.Insert(DefAt, '    ' + Enc(HelperProcs[I]));
end;

{ lookup 控件的选项数据集：控件通过 LookupData 引用它，脚本在初始化时绑节点并打开。
  规格：名称|SQL|最大记录数|每页数量|是否分页。 }
{ 记录区字段的顺序与标题按数据结构的「排版」(cdsTypesetting) 走：
  精灵里上移/下移字段即可独立调整记录区，不必跟着表格列顺序；标题优先取排版里的
  标题，其次沿用表格列标题；没进排版的字段按原顺序补在后面。
  （这与 mtEditor 用 cdsTypesetting 决定编辑器字段顺序是同一套配置。） }
procedure OrderByTypesetting(Names, Captions: TStringList; const AStructure: TJSONObject);
var Rows, Entry: TJSONObject; I, J: Integer; Plain, Cap: string;
  NewNames, NewCaptions: TStringList;
begin
  if (Names = nil) or (Captions = nil) or (Names.Count < 2) then Exit;
  Rows := nil;
  if AStructure <> nil then Rows := Obj(AStructure, 'cdsTypesetting');
  if Rows <> nil then Rows := Obj(Rows, 'Data');
  if (Rows = nil) or (Rows.Count = 0) then Exit;
  NewNames := TStringList.Create; NewCaptions := TStringList.Create;
  try
    for I := 0 to Rows.Count - 1 do
    begin
      Entry := Obj(Rows, IntToStr(I));
      if Entry = nil then Continue;
      Plain := Trim(Str(Entry, 'fdCOLUMN_NAME'));
      { 排版里存的是带表别名的限定名（a.FGridRef），表格列名是不带别名的（FGridRef）。 }
      if Pos('.', Plain) > 0 then Plain := Copy(Plain, Pos('.', Plain) + 1, MaxInt);
      if Plain = '' then Continue;
      for J := 0 to Names.Count - 1 do
      begin
        if not SameText(Dec(Names[J]), Plain) then Continue;
        if NewNames.IndexOf(Names[J]) >= 0 then Break;
        NewNames.Add(Names[J]);
        Cap := Trim(Str(Entry, 'fdCAPTION'));
        if Cap <> '' then NewCaptions.Add(Enc(Cap)) else NewCaptions.Add(Captions[J]);
        Break;
      end;
    end;
    { 未进排版的字段按原顺序补在后面，避免漏掉控件。 }
    for J := 0 to Names.Count - 1 do
      if NewNames.IndexOf(Names[J]) < 0 then
      begin
        NewNames.Add(Names[J]);
        NewCaptions.Add(Captions[J]);
      end;
    Names.Assign(NewNames); Captions.Assign(NewCaptions);
  finally
    NewNames.Free; NewCaptions.Free;
  end;
end;

{ 配置里的 edOptionFields 列出“可作为搜索列”的字段（多列下拉的 IsLookUp）。 }
function LkSearchField(const ASearch, AFieldName: string): Boolean;
var Parts: TStringList; I: Integer; V: string;
begin
  Result := False;
  if (Trim(ASearch) = '') or (Trim(AFieldName) = '') then Exit;
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True; Parts.Delimiter := ';';
    Parts.DelimitedText := ASearch;
    for I := 0 to Parts.Count - 1 do
    begin
      V := Trim(Parts[I]);
      if Pos('@', V) > 0 then V := Trim(Copy(V, 1, Pos('@', V) - 1));
      if SameText(V, AFieldName) then Exit(True);
    end;
  finally
    Parts.Free;
  end;
end;

procedure AddLookupDataSets(Lines: TStringList; const LookupSets: TStringList;
  const NodeName: string);
var I, J, At, MaxRec, PageSize, Dynamic: Integer; Specs: TStringList;
  DataName, Sql, Paged: string;
begin
  if LookupSets.Count = 0 then Exit;
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
    raise Exception.Create('mtListEditor lookup 数据集：模板结构不匹配（找不到 dsMain）。');
  Specs := TStringList.Create;
  try
    Specs.StrictDelimiter := True; Specs.Delimiter := '|';
    for I := LookupSets.Count - 1 downto 0 do
    begin
      Specs.DelimitedText := LookupSets[I];
      DataName := Specs[0];
      Sql := ''; Paged := '0'; MaxRec := 100; PageSize := 50;
      if Specs.Count > 1 then Sql := Specs[1];
      if Specs.Count > 2 then MaxRec := StrToIntDef(Specs[2], 100);
      if Specs.Count > 3 then PageSize := StrToIntDef(Specs[3], 50);
      if Specs.Count > 4 then Paged := Specs[4];
      Dynamic := 0;
      if Specs.Count > 5 then Dynamic := StrToIntDef(Specs[5], 0);
      Lines.Insert(At, '  end');
      Lines.Insert(At, '    Active = False');
      if Dynamic = 1 then
      begin
        { 动态加载：数据集只是壳，SQL 由控件的 OnExtEditValueChange 在输入时拼好再打开
          （与原版生成的 cdsaCustCode 一致：SelectMaxRecCount = 0、没有 CommandText）。
          数据节点名必须写：宿主 Open 时要按它找节点，缺了会报“节点数据库 ""不存在”。 }
        Lines.Insert(At, '    SelectMaxRecCount = 0');
        Lines.Insert(At, '    DataNodeName = ' + Q(NodeName));
      end
      else
      begin
        if Paged = '1' then Lines.Insert(At, '    Tag = ' + IntToStr(PageSize));
        Lines.Insert(At, '    PageRowCount = -1');
        Lines.Insert(At, '    SelectMaxRecCount = ' + IntToStr(MaxRec));
        Lines.Insert(At, '    CommandText = ' + Q(Sql));
        Lines.Insert(At, '    DataNodeName = ' + Q(NodeName));
      end;
      Lines.Insert(At, '  object ' + DataName + ': TUgClientDataSet');
    end;
  finally
    Specs.Free;
  end;
end;

{ 动态加载的取数例程要按驱动决定行数上限（MSSQL 用 top），驱动从数据节点名现查，
  与 cDataNodeName 同处一个 const 块（原版生成的脚本也是这个写法）。
  声明行形如 '  cDataNodeName = <节点名>;'，缩进后以变量名开头，用它区分声明与脚本里的引用。 }
procedure AddDriverConst(Lines: TStringList);
var I: Integer; S: string;
begin
  for I := 0 to Lines.Count - 1 do
  begin
    S := Trim(Dec(Trim(Lines[I])));
    { 声明有两种写法：mtMultiple 直接写 `const cDataNodeName = '...';`（同一行），
      同窗写入生成器会把常量块改写成 `const` 单独一行 + `  cDataNodeName = '...';`。
      两种都要认出来，同时排除脚本里的引用（那种行含 `:=`）。 }
    if ((Pos('cDataNodeName', S) = 1) or (Pos('const cDataNodeName', S) = 1)) and
      (Pos(':=', S) = 0) then
    begin
      Lines.Insert(I + 1, '    ' +
        Enc('cDataNodeDriver = UGMM.GetNodeNameByDriver(cDataNodeName);'));
      Exit;
    end;
  end;
  raise Exception.Create('mtListEditor 动态查找：模板结构不匹配（找不到 cDataNodeName 声明）。');
end;

{ SqlText 下拉的选项例程 + lookup 数据集的打开语句，统一进初始化脚本。 }
procedure AddListEditorInit(Lines: TStringList; const SqlLoaders, LookupSets, DynLookups: TStringList;
  ADetailPlan: TListEditorDetailPlan; ADetailEvents: TStringList);
var I, EventAt, MaxRec, k, LkAt, LkPos: Integer; Specs, Stmts, Procs, LkParts: TStringList;
  ControlName, Sql, ValueField, DataName, LkSearch, LkPart, DynSql, Emit: string;
begin
  Specs := TStringList.Create; Stmts := TStringList.Create; Procs := TStringList.Create;
  LkParts := TStringList.Create;
  try
    Specs.StrictDelimiter := True; Specs.Delimiter := '|';
    for I := 0 to SqlLoaders.Count - 1 do
    begin
      Specs.DelimitedText := SqlLoaders[I];
      ControlName := Specs[0];
      Sql := ''; ValueField := '';
      if Specs.Count > 1 then Sql := Specs[1];
      if Specs.Count > 2 then ValueField := Specs[2];
      Procs.Add('//SqlText 下拉：初始化时从数据库取选项（值即选项文本）');
      Procs.Add('procedure LELoadItems' + ControlName + ';');
      Procs.Add('var C: TUgClientDataSet;');
      Procs.Add('begin');
      Procs.Add('  ' + ControlName + '.Items.Clear;');
      Procs.Add('  C := TUgClientDataSet.Create(nil);');
      Procs.Add('  try');
      Procs.Add('    C.DataNodeName := cDataNodeName;');
      Procs.Add('    C.PageRowCount := -1;');
      Procs.Add('    C.CommandText := ' + QuotedStr(Sql) + ';');
      Procs.Add('    C.Open;');
      Procs.Add('    C.First;');
      Procs.Add('    while not C.Eof do');
      Procs.Add('    begin');
      if ValueField = '' then
        Procs.Add('      ' + ControlName + '.Items.Add(C.Fields[0].AsString);')
      else
        Procs.Add('      ' + ControlName + '.Items.Add(C.FieldByName(' +
          QuotedStr(ValueField) + ').AsString);');
      Procs.Add('      C.Next;');
      Procs.Add('    end;');
      Procs.Add('  finally');
      Procs.Add('    C.Free;');
      Procs.Add('  end;');
      Procs.Add('end;');
      Procs.Add('');
      Stmts.Add('  LELoadItems' + ControlName + ';');
    end;
    { lookup 控件的选项数据集由控件自己使用，脚本只负责绑节点并打开。 }
    for I := 0 to LookupSets.Count - 1 do
    begin
      Specs.DelimitedText := LookupSets[I];
      DataName := Specs[0];
      Stmts.Add('  ' + DataName + '.DataNodeName := cDataNodeName;');
      { 动态加载的壳数据集由控件事件自己打开，初始化阶段不打开它。 }
      if (Specs.Count > 5) and (Specs[5] = '1') then Continue;
      Stmts.Add('  ' + DataName + '.Open;');
    end;
    { 动态加载：按原版生成的 aCustCodeOnExtEditValueChange 同一套写法——
      输入时把配置的 SELECT 包成子查询，按控件里 IsLookUp=True 的列拼 like 条件再取数。 }
    for I := 0 to DynLookups.Count - 1 do
    begin
      Specs.DelimitedText := DynLookups[I];
      ControlName := Specs[0];
      DataName := Specs[1];
      Sql := '';
      MaxRec := 100;
      if Specs.Count > 2 then Sql := Specs[2];
      if Specs.Count > 3 then MaxRec := StrToIntDef(Specs[3], 100);
      if Specs.Count > 4 then LkSearch := Specs[4];
      { 行数上限的写法随数据节点的驱动而变：MSSQL/MSAcc 用 top N，MySQL/SQLite 等用 limit N，
        Oracle 与原版一样不加（与 DetailTemplate 的导航取数同一约定）。原版样例跑在 MySQL 上，
        照抄它的 'limit' 到 MSSQL 就是宿主报的 '"limit" 附近有语法错误'，
        所以这里不在生成期写死，而是在脚本里按 cDataNodeDriver 现算。 }
      DynSql := '  xxx.* from(' + Sql + ') xxx';
      LkParts.StrictDelimiter := True; LkParts.Delimiter := ';';
      LkParts.DelimitedText := LkSearch;
      LkAt := 0;
      for k := 0 to LkParts.Count - 1 do
      begin
        LkPart := Trim(LkParts[k]);
        if LkPart = '' then Continue;
        LkPos := Pos('@', LkPart);
        if LkPos > 0 then LkPart := Trim(Copy(LkPart, 1, LkPos - 1));
        if LkPart = '' then Continue;
        { 这里只拼到 " like "，**不能**把值的起始单引号也写进常量：
          值那一段由脚本里的 quotedstr('%' + value + '%') 提供，两边各带一个引号才是
          `like '%值%'`；常量里再带一个就变成 `like ''%值%'`，宿主报「引号不完整」。
          原版生成的写法就是 ' like ' + quotedstr(...)（见 mtMasterSlave.dfm 的取数例程）。 }
        if LkAt = 0 then DynSql := DynSql + ' where (' + '   xxx.' + LkPart + ' like '
        else DynSql := DynSql + ' or ' + '   xxx.' + LkPart + ' like ';
        Inc(LkAt);
      end;
      Procs.Add('//动态加载 ' + ControlName + ' 的下拉选项：输入时按可检索列远程取数');
      Procs.Add('procedure ' + ControlName + 'OnExtEditValueChange(sender: tobject; const value: string);');
      { 搜索列在生成期就已知（edOptionLookupFields），这里直接拼进 SQL——
        与宿主里原版控件读自身 IsLookUp 标记等价，但少一层运行时依赖，本地可断言。 }
      Procs.Add('var');
      Procs.Add('  c : TUgClientDataSet;');
      Procs.Add('begin');
      Procs.Add('  c := ' + DataName + ';');
      Procs.Add('  if c = nil then');
      Procs.Add('    Exit;');
      Procs.Add('  c.Close;');
      Emit := '  c.CommandText := ' + QuotedStr('select') +
        ' + iif((cDataNodeDriver = ''MSSQL'') or (cDataNodeDriver = ''MSAcc''), '' top ' +
        IntToStr(MaxRec) + ''', '''')' +
        ' + ' + QuotedStr(DynSql);
      if LkAt > 0 then
        Emit := Emit + ' + quotedstr(''%'' + value + ''%'') + ' + QuotedStr('      )');
      Emit := Emit +
        ' + iif((cDataNodeDriver = ''MSSQL'') or (cDataNodeDriver = ''MSAcc'') or (cDataNodeDriver = ''Ora''), '''', ''  limit ' +
        IntToStr(MaxRec) + ''');';
      Procs.Add(Emit);
      Procs.Add('  c.Open;');
      Procs.Add('end;');
      Procs.Add('');
    end;
    if DynLookups.Count > 0 then AddDriverConst(Lines);
    { 从表只读联动：例程要定义在初始化调用之前；事件绑定与动态查找同一条通道。 }
    if (ADetailPlan <> nil) then AddListEditorDetailScript(ADetailPlan, Lines, Procs, Stmts, ADetailEvents);
    AddInitScript(Lines, Stmts, Procs);
    if (ADetailEvents <> nil) and (ADetailEvents.Count > 0) then
    begin
      EventAt := -1;
      for I := 0 to Lines.Count - 1 do
        if Trim(Lines[I]) = 'Events.Strings = (' then begin EventAt := I; Break; end;
      if EventAt < 0 then
        raise Exception.Create('mtListEditor 从表：模板结构不匹配（找不到 Events.Strings）。');
      for I := ADetailEvents.Count - 1 downto 0 do Lines.Insert(EventAt + 1, ADetailEvents[I]);
    end;
    { 事件绑定写进 Events.Strings（与 btToggleQuery 同一条通道）。 }
    if DynLookups.Count > 0 then
    begin
      EventAt := -1;
      for I := 0 to Lines.Count - 1 do
        if Trim(Lines[I]) = 'Events.Strings = (' then
        begin
          EventAt := I;
          Break;
        end;
      if EventAt < 0 then
        raise Exception.Create('mtListEditor 动态查找：模板结构不匹配（找不到 Events.Strings）。');
      Specs.StrictDelimiter := True; Specs.Delimiter := '|';
      for I := DynLookups.Count - 1 downto 0 do
      begin
        Specs.DelimitedText := DynLookups[I];
        ControlName := Specs[0];
        Lines.Insert(EventAt + 1,
          '    ''' + ControlName + '|<This>.OnExtEditValueChange:' + ControlName + 'OnExtEditValueChange''');
      end;
    end;
  finally
    Specs.Free; Stmts.Free; Procs.Free; LkParts.Free;
  end;
end;

{ 记录区独立布局（可选区块 TWebListEditorSetting）：
  全局 cbEditPosition(Top/Left)、seColumns(1..3)、seFieldWidth(每列宽度)、cbShowGroups(分组标题行)；
  每字段一行 cdsRecordLayout.Data：fdCOLUMN_NAME(带别名)、fdCAPTION、fdGROUP、fdVISIBLE、fdSPAN、fdWIDTH。
  区块缺失或没有行时返回 False，调用方沿用“表格可见字段 + 排版顺序 + 两列游标”的既有行为。
  解析器与计划类型已搬到共享单元 ugConfiguration.ListEditorLayout（mtMasterSlave 也用它）。 }
function Truthy(const V: string): Boolean;
begin
  Result := SameText(V, 'True') or (V = '1') or (V = '-1');
end;

{ 去掉表别名前缀：'a.FCustCode' → 'FCustCode'。 }
function PlainField(const V: string): string;
begin
  Result := Trim(V);
  if Pos('.', Result) > 0 then Delete(Result, 1, Pos('.', Result));
end;

{ 数据结构「排版」(cdsTypesetting) 里该字段的标题；找不到返回空串。 }
function TypesettingCaptionOf(Config: TJSONObject; const AField: string): string;
var Rows, Row: TJSONObject; I: Integer; Wanted: string;
begin
  Result := '';
  Rows := Obj(Obj(Obj(Config, 'TWebDataStructure'), 'cdsTypesetting'), 'Data');
  if Rows = nil then Exit;
  Wanted := PlainField(AField);
  if Wanted = '' then Exit;
  for I := 0 to Rows.Count - 1 do
  begin
    Row := Obj(Rows, IntToStr(I));
    if Row = nil then Continue;
    if SameText(PlainField(Str(Row, 'fdCOLUMN_NAME')), Wanted) then
      Exit(Trim(Str(Row, 'fdCAPTION')));
  end;
end;

{ 记录区布局的解析与校验搬到了共享单元 ugConfiguration.ListEditorLayout（mtMasterSlave 也用它）。 }


function TryBuildListEditorTemplate(Config: TJSONObject;
  out DFM, Reason: string): Boolean;
var CopyConfig, Tables, Columns, ColumnRow: TJSONObject;
  Buttons, Lines, Panel, Names, Captions, DropItems, SqlLoaders, LookupSets, LkParts,
  DynLookups: TStringList;
  B, Line, FieldExpr, CaptionExpr, TextCase, ColumnName, Kind, ControlClass: string;
  SqlText, DropValueField: string;
  LkDataName, LkSql, LkValue, LkDisplay, LkCaption, LkFields, LkPart: string;
  LkMaxRec, LkPageSize, LkPaged, LkDynamic, LkAt, LkPos: Integer; LkDrop: TJSONObject;
  LkFldName, LkFldCaption, LkSearch: string;
  I, K, InsertAt, DataSourceAt, EditorHeight, FieldHeight, Column: Integer;
  ColTop: array[0..1] of Integer;
  InGrid, InColumn, VisibleColumn, WriteMode, HasDrop, SqlDrop: Boolean;
  { 记录区独立布局（可选区块）用到的状态 }
  LayoutItems: TArray<TListEditorLayoutItem>;
  Headers: TStringList;
  HasLayout, LayGroups: Boolean;
  LayColumns, LayFieldWidth, LayStep, LayRowTop, LayRowHeight, LayRowCol,
  LaySpan, LayFieldWidth2, FieldLeft, FieldTop, HeadAt: Integer;
  LayPosition, LayCurrentGroup, LayReason, PlainName: string;
  { 从表（明细）：本批先做只读联动，写入在下一批接入同一个计划对象。 }
  DetailPlan: TListEditorDetailPlan;
  DetailAvailable: Boolean;
  { 是否勾了明细行按钮（目录项 'Detail Row Group'）：它们由明细区工具条消费，不参与主工具条。 }
  HasDetailButton: Boolean;
  { 从表配置（TWebDetailedStructure.cdsTables.Data）：明细行按钮的前置条件检查用。 }
  DetailTables: TJSONObject;
  { 明细网格是否要补回 dgEditing：模板末尾会全量剥离它，可写明细区必须补回（见 RestoreDetailGridEditing）。 }
  DetailGridEditable: Boolean;
  DetailReason: string;
  DetailEvents: TStringList;
  MainPlain: TStringList;
  DetailOut: TStringList;
  function Fail(const Msg: string): Boolean;
  begin Reason := Msg; Result := False; end;
  function ColumnRowOf(const FieldName: string): TJSONObject;
  var K: Integer; N: string;
  begin
    Result := nil;
    if Columns = nil then Exit;
    for K := 0 to Columns.Count - 1 do
    begin
      ColumnRow := Obj(Columns, IntToStr(K));
      N := Str(ColumnRow, 'fdCOLUMN_NAME');
      if Pos('.', N) > 0 then Delete(N, 1, Pos('.', N));
      if SameText(N, FieldName) then Exit(ColumnRow);
    end;
  end;
  // 精灵为空时按普通文本处理，与编辑模板一致。
  function FieldKindOf(const FieldName: string): string;
  var R: TJSONObject;
  begin
    R := ColumnRowOf(FieldName);
    Result := LowerCase(Trim(Str(R, 'fdOBJECT_TYPE')));
    if Result = '' then Result := 'edit';
  end;
  // 记录区控件类：与原版生成样例一致（文本/数值/备注/复选/日期时间/固定下拉）。
  function ControlClassOf(const Kind: string): string;
  begin
    if Kind = 'number' then Result := 'TUgDBNumberEdit'
    else if Kind = 'memo' then Result := 'TUgDBMemo'
    else if Kind = 'check' then Result := 'TUgDBCheckBox'
    else if Kind = 'time' then Result := 'TUgDBTimePicker'
    else if (Kind = 'date') or (Kind = 'datetime') then
      Result := 'TUgDBDateTimePicker'
    else if Kind = 'combobox' then Result := 'TUgDBComboBox'
    else if Kind = 'lookupedit' then Result := 'TUgDBLookupEdit'
    else if Kind = 'lookupeditextra' then Result := 'TUgDBLookupEditExtra'
    else if Kind = 'gridcombobox' then Result := 'TUgDBGridCombobox'
    else if Kind = 'gridcomboboxextra' then Result := 'TUgDBGridComboboxExtra'
    else Result := 'TUgDBEdit';
  end;
  function ControlHeightOf(const Kind: string): Integer;
  begin
    if Kind = 'check' then Result := 25
    else if Kind = 'memo' then Result := 170
    else Result := 50;
  end;
  // 下拉配置：SetText 返回固定选项内容并写入 DFM；SqlText 返回 True 并给出取数 SQL，
  // 由脚本在初始化时用临时数据集把选项灌进 Items（取结果集第一列，与 mtMasterSlave 同一做法）。
  function FixedDropDownLines(const FieldName: string; Items: TStrings): Boolean;
  var R: TJSONObject; DropValue: TJSONValue; Drop: TJSONObject; Raw: string; J: Integer;
  begin
    Result := False;
    R := ColumnRowOf(FieldName);
    if R = nil then Exit;
    DropValue := R.GetValue('fdDropDownOptions');
    if DropValue is TJSONObject then DropValue := TJSONValue(DropValue.Clone)
    else DropValue := TJSONObject.ParseJSONValue(Str(R, 'fdDropDownOptions'));
    if not (DropValue is TJSONObject) then
    begin
      DropValue.Free;
      Exit;
    end;
    try
      Drop := TJSONObject(DropValue);
      if not SameText(Str(Drop, 'cbDropDownType'), 'SetText') then Exit;
      Raw := StringReplace(Str(Drop, 'mmText'), #13#10, #10, [rfReplaceAll]);
      Raw := StringReplace(Raw, #13, #10, [rfReplaceAll]);
      Items.Text := Raw;
      { 空行不是选项：只保留去空格后非空的条目。 }
      for J := Items.Count - 1 downto 0 do
        if Trim(Items[J]) = '' then Items.Delete(J);
      Result := Items.Count > 0;
    finally
      DropValue.Free;
    end;
  end;
  function DropDownField(const FieldName: string): TJSONObject;
  var R: TJSONObject; V: TJSONValue;
  begin
    Result := nil;
    R := ColumnRowOf(FieldName);
    if R = nil then Exit;
    V := R.GetValue('fdDropDownOptions');
    if V is TJSONObject then Result := TJSONObject(V.Clone)
    else
    begin
      V := TJSONObject.ParseJSONValue(Str(R, 'fdDropDownOptions'));
      if V is TJSONObject then Result := TJSONObject(V) else V.Free;
    end;
  end;
  { SqlText 下拉：返回 True 并给出取数 SQL 与返回列（空则取第一列）。 }
  function SqlTextDropDown(const FieldName: string; out Sql, ValueField: string): Boolean;
  var Drop: TJSONObject; Raw: string;
  begin
    Result := False; Sql := ''; ValueField := '';
    Drop := DropDownField(FieldName);
    if Drop = nil then Exit;
    try
      if not SameText(Str(Drop, 'cbDropDownType'), 'SqlText') then Exit;
      { 多行 SQL 的换行必须换成空格：这段 SQL 会写进脚本里的单引号字符串常量，
        常量里留真换行会让 FastScript 报 Expression expected，宿主加载脚本就失败。
        与查找字段的 SQL 用同一条归一化规则，Trim 去掉首尾空格。 }
      Raw := StringReplace(Str(Drop, 'mmText'), #13#10, ' ', [rfReplaceAll]);
      Raw := StringReplace(Raw, #13, ' ', [rfReplaceAll]);
      Raw := StringReplace(Raw, #10, ' ', [rfReplaceAll]);
      Sql := Trim(Raw);
      if Sql = '' then Exit;
      { 精灵的下拉对话框在 SqlText 下不提供“返回字段/显示字段”，切换类型时也不会清空
        之前 SqlQuery 留下的值；这里一律取结果集第一列，残留值只忽略、不报错。 }
      ValueField := '';
      Result := True;
    finally
      Drop.Free;
    end;
  end;
begin
  Result := False; DFM := ''; Reason := '';
  { 明细计划必须在**任何**退出点之前置空：下面是统一的 cleanup（DetailPlan.Free），
    而计划要落到函数后段才创建。早前它只在那里赋值，于是所有前置拒绝（只读+输出按钮、
    布局非法、未知按钮…）都会 Free 一个未初始化的指针——表面是"退出时 Access violation"，
    实质是堆被踩坏（宿主里同样危险）。 }
  DetailPlan := nil;
  if not SameText(Str(Config, 'TWebModuletype'), 'mtListEditor') then
    Exit(Fail('当前生成器仅支持 mtListEditor。'));
  Tables := Obj(Obj(Obj(Config, 'TWebDataStructure'), 'cdsTables'), 'Data');
  if (Tables = nil) or (Tables.Count <> 1) then
    Exit(Fail('mtListEditor 第一批仅支持单根表。'));
  { 记录区独立布局：区块存在但本身不合法（列数/宽度/跨列超限）时直接拒绝；
    区块缺失或没有行时 HasLayout=False，沿用“表格可见字段 + 排版顺序”。 }
  HasLayout := ReadListEditorLayout(Config, LayoutItems, LayColumns, LayFieldWidth,
    LayPosition, LayGroups, LayReason);
  if LayReason <> '' then Exit(Fail(LayReason));
  Headers := TStringList.Create;
  Buttons := TStringList.Create;
  Lines := TStringList.Create; Panel := TStringList.Create;
  Names := TStringList.Create; Captions := TStringList.Create;
  DropItems := TStringList.Create; SqlLoaders := TStringList.Create;
  LookupSets := TStringList.Create; LkParts := TStringList.Create;
  DynLookups := TStringList.Create;
  DetailEvents := TStringList.Create;
  CopyConfig := nil;
  try
    Buttons.StrictDelimiter := True; Buttons.Delimiter := ';';
    Buttons.DelimitedText := Str(Config, 'TWebFunctionButton');
    Columns := Obj(Obj(Obj(Config, 'TWebDataStructure'), 'cdsColumns'), 'Data');
    TextCase := Str(Obj(Config, 'TWebNormalSetting'), '文本类型');
    WriteMode := (Buttons.IndexOf('btAppend')>=0) or (Buttons.IndexOf('btEditor')>=0) or
      (Buttons.IndexOf('btSave')>=0) or (Buttons.IndexOf('btCancel')>=0) or
      (Buttons.IndexOf('btDelete')>=0);
    for B in Buttons do
      if (B <> '') and (B <> 'btQuery') and (B <> 'btClose') and
         (B <> 'btAppend') and (B <> 'btEditor') and (B <> 'btSave') and (B <> 'btCancel') and
         (B <> 'btDelete') and (B <> 'btExport') and (B <> 'btPrint') and
         (B <> 'btAnnex') and (B <> 'btImport') and not IsDetailRowButton(B) then
        Exit(Fail('mtListEditor 本批尚未接入此按钮，请取消：' + B));
    { 导入（btImport）：行为照原版 list editor 参考件 —— 把文本/电子表格批量导入到**当前列表**
      （原版脚本里就是 `g := gridMain`），导入进来的行先留在 cdsMain 里未保存，保存/撤销一起收尾。
      它会新增记录，所以只在同窗写入下可用（只读列表下"配了不生效"，明确拒绝而不是静默忽略）。 }
    if (Buttons.IndexOf('btImport') >= 0) and not WriteMode then
      Exit(Fail('导入会新增记录，只在同窗写入下可用：请同时启用新增、修改、保存、撤销；'
        + '只读列表不支持导入。'));
    if WriteMode then
      for B in TArray<string>.Create('btQuery','btClose','btAppend','btEditor','btSave','btCancel') do
        if Buttons.IndexOf(B)<0 then Exit(Fail('同窗写入本批必须同时启用查询、关闭、新增、修改、保存、撤销。'));
    { 明细行按钮（目录项 'Detail Row Group'）由明细区工具条消费，不参与主工具条。
      勾了它们却没配从表、或列表是只读的，都会"配了不生效"，所以在这里明确拒绝。 }
    HasDetailButton := False;
    for B in Buttons do
      if IsDetailRowButton(B) then HasDetailButton := True;
    if HasDetailButton then
    begin
      if not WriteMode then
        Exit(Fail('明细行按钮（新增行/插入行/删除行/复制行/上移/下移/清空）只在同窗写入下可用：'
          + '请同时启用新增、修改、保存、撤销。'));
      { 注意：从表配置在 TWebDetailedStructure 里，不是主表的 Tables（早前写成 Tables 导致这条拒绝不生效）。 }
      DetailTables := Obj(Obj(Obj(Config, 'TWebDetailedStructure'), 'cdsTables'), 'Data');
      if (DetailTables = nil) or (DetailTables.Count = 0) then
        Exit(Fail('明细行按钮需要先在“从表结构”里配置从表与关联字段/关联从表。'));
      if (Buttons.IndexOf('btDetailAppend') < 0) and (Buttons.IndexOf('btDetailInsert') < 0) then
        Exit(Fail('配了从表写入就至少要启用“新增行”或“插入行”，否则无法新增明细。'));
    end;
    { 导出/打印/附件本批随同窗写入的工具栏一并生成（记录区+写入脚本同一条通道）；
      只读列表下这三项还没有落点，明确拒绝而不是静默忽略。 }
    if not WriteMode then
      for B in TArray<string>.Create('btExport','btPrint','btAnnex') do
        if Buttons.IndexOf(B)>=0 then
          Exit(Fail('导出/打印/附件本批随同窗写入一起生成，请同时启用新增、修改、保存、撤销；'
            + '只读列表暂不支持这三项：' + B));
    { 审计字段（录入*/修改*）只在保存时赋值，没有写回按钮就无处落点。
      这条拒绝原先由被复用的 mtMultiple 生成器给出，但本模板要把这些设置从克隆里摘掉
      （写入侧由 ListEditorWrite 负责），摘掉之后就没人校验了 —— 于是"只读 + 配了审计字段"
      被静默接受（批次二探针 '无写按钮时审计设置未被拒绝' 抓到的正是这条）。
      「录入部门」不在此列：它在只读模式下属层级权限的查询过滤，mtMultiple 也是这么放行的。 }
    if not WriteMode then
      for B in TArray<string>.Create('录入用户','录入时间','修改用户','修改部门','修改时间') do
        if Trim(Str(Obj(Config,'TWebNormalSetting'), B)) <> '' then
          Exit(Fail('审计字段（自动赋值）需要启用新增、修改、保存、撤销：' + B));
    CopyConfig := Config.Clone as TJSONObject;
    CopyConfig.RemovePair('TWebModuletype').Free;
    CopyConfig.AddPair('TWebModuletype', 'mtMultiple');
    // 复用列表生成器时保留来源类型，供查询区采用同窗列表的紧凑横向布局。
    CopyConfig.AddPair('TWebListEditorLayout', 'True');
    { 「记录区布局」是本模板专用的常规设置项，被复用的 mtMultiple 生成器不认识它，
      会当成未实现设置拒绝（宿主报过“mtMultiple 首批尚未实现常规设置：记录区布局”）。
      生成前先从这个克隆里摘掉；原配置不动，保存时仍然保留。 }
    { 从表配置由本模板自己处理（明细区/明细脚本），被复用的 mtMultiple 生成器看到从表数据会
      直接拒绝（'mtMultiple 首批尚不支持从表配置'），所以从克隆里整块摘掉；原配置不动。 }
    CopyConfig.RemovePair('TWebDetailedStructure').Free;
    if Obj(CopyConfig,'TWebNormalSetting') <> nil then
    begin
      Obj(CopyConfig,'TWebNormalSetting').RemovePair('记录区布局').Free;
      { 审计字段由本模板的写入生成器负责（ListEditorWrite），被复用的 mtMultiple 生成器在
        只读按钮组合下会把这些设置当成“需要写回按钮”而拒绝，所以先摘掉；
        但层级权限要留下「录入部门」——mtMultiple 用它生成查询的 in 过滤，且它自己也校验这条。 }
      for B in TArray<string>.Create('录入用户','录入时间','修改用户','修改部门','修改时间') do
        Obj(CopyConfig,'TWebNormalSetting').RemovePair(B).Free;
      { 从表相关设置项同样由本模板消费（关联字段/关联从表/隐藏字段-从表，以及写入片的
        记录编号/明细编号/从表唯一/从表非空）；mtMultiple 不认识它们，会当成未实现设置拒绝
        （宿主/探针报过 "mtMultiple 首批尚未实现常规设置：记录编号"）。
        「记录编号」在本模板里是**从表结构分组**的明细自动编号（3000），不是主表的编号设置。 }
      for B in TArray<string>.Create('关联字段','关联从表','隐藏字段-从表',
        '记录编号','明细编号','从表唯一','从表非空') do
        Obj(CopyConfig,'TWebNormalSetting').RemovePair(B).Free;
      if not Truthy(Str(Obj(CopyConfig,'TWebNormalSetting'),'层级权限')) then
        Obj(CopyConfig,'TWebNormalSetting').RemovePair('录入部门').Free;
    end;
    { 这些设置只对"同窗写入"有意义，由本模板的写入生成器校验；被复用的 mtMultiple 生成器
      会按它自己的编号规则再校验一遍（只读模式下还要求写回按钮），历史上让"只读 + 配了主表唯一/
      自动编号"的配置直接生成失败。因此**始终**从克隆里摘掉，与是否写模式无关。 }
    if Obj(CopyConfig,'TWebNormalSetting')<>nil then
      for B in TArray<string>.Create('主表唯一','自动编号','非空字段','编辑窗体') do
        Obj(CopyConfig,'TWebNormalSetting').RemovePair(B).Free;
    if WriteMode then begin
      CopyConfig.RemovePair('TWebFunctionButton').Free;
      CopyConfig.AddPair('TWebFunctionButton','btQuery;btClose;');
    end;
    // Reuse the validated read-only query/paging/error boundary, never editor callbacks.
    if not TryBuildMultipleTemplate(CopyConfig, DFM, Reason) then Exit;
    Lines.Text := DFM;
    InsertAt := -1; DataSourceAt := -1;
    InGrid := False; InColumn := False;
    FieldExpr := ''; CaptionExpr := ''; VisibleColumn := True;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = 'object pPages: TUgContainerPanel' then InsertAt := I;
      if Line = 'object dsMain: TUgDataSource' then DataSourceAt := I;
      if Line = 'object gridMain: TUgDBGrid' then InGrid := True;
      if not InGrid then Continue;
      if Line = 'item' then
      begin InColumn := True; FieldExpr := ''; CaptionExpr := ''; VisibleColumn := True; end;
      if InColumn then
      begin
        if Pos('FieldName = ', Line) = 1 then FieldExpr := Copy(Line, 13, MaxInt);
        if Pos('Title.Caption = ', Line) = 1 then CaptionExpr := Copy(Line, 17, MaxInt);
        if Line = 'Visible = False' then VisibleColumn := False;
        if Line = 'end' then
        begin
          if VisibleColumn and (FieldExpr <> '') then
          begin
            Names.Add(FieldExpr);
            if CaptionExpr = '' then CaptionExpr := FieldExpr;
            Captions.Add(CaptionExpr);
          end;
          InColumn := False;
        end;
      end;
      if Line = '>' then InGrid := False;
    end;
    if (InsertAt < 0) or (DataSourceAt < 0) or (Names.Count = 0) then
      Exit(Fail('mtListEditor：没有可显示字段，或查询模板布局结构已变化。'));
    if HasLayout then
    begin
      { 独立布局：字段集/顺序/标题都按区块走，只保留可见行；标题为空时依次回退
        排版里的标题、字段名。字段必须是主表已勾选字段，且不能重复。 }
      Names.Clear; Captions.Clear;
      for I := 0 to High(LayoutItems) do
      begin
        PlainName := PlainField(LayoutItems[I].Field);
        ColumnRow := ColumnRowOf(PlainName);
        { 数据结构换表后，布局里会残留旧字段。这里按“以当前数据结构为准”丢弃它们
          （与精灵「排版」表在字段取消勾选时的同步行为一致），而不是直接报错卡住生成；
          全部丢弃后没有可用字段才拒绝，并提示重新确认布局。 }
        if (ColumnRow = nil) or not Truthy(Str(ColumnRow, 'fdSELECT')) then Continue;
        if Names.IndexOf(Q(PlainName)) >= 0 then
          Exit(Fail('记录区布局里字段重复：' + LayoutItems[I].Field));
        { 与“表格列”路径一致：字段名按 DFM 属性值写成带引号的形式（DataField = 'FUnitCode'），
          标题用 #NNN 形式，下游 ListEditorWrite 用 Decode 还原成纯文本。 }
        Names.Add(Q(PlainName));
        if LayoutItems[I].Caption <> '' then Captions.Add(Enc(LayoutItems[I].Caption))
        else
        begin
          LayCurrentGroup := TypesettingCaptionOf(Config, LayoutItems[I].Field);
          if LayCurrentGroup <> '' then Captions.Add(Enc(LayCurrentGroup))
          else Captions.Add(Enc(PlainName));
        end;
      end;
      if Names.Count = 0 then
        Exit(Fail('记录区布局里已没有可用字段（数据结构可能已变更）：请打开“记录区布局”重新确认并保存。'));
    end
    else
      OrderByTypesetting(Names, Captions, Obj(Config, 'TWebDataStructure'));
    Panel.Add('  object pListEditorFields: TUgContainerPanel');
    if SameText(LayPosition, 'Left') then
    begin
      { 记录区放表格左边：容器 alLeft，宽度按列数与列宽推导，高度交给对齐。 }
      LayStep := LayFieldWidth + 20;
      Panel.Add('    Align = alLeft');
      Panel.Add('    Width = ' + IntToStr(LayColumns * LayFieldWidth + (LayColumns - 1) * 20 + 20));
      Panel.Add('    Top = 10000');
      HeadAt := 4;
    end
    else
    begin
      LayStep := LayFieldWidth + 20;
      Panel.Add('    Align = alTop');
      Panel.Add('    Top = 10000');
      HeadAt := 3;
    end;
    { 独立布局用“整行打包”：按列号推进，跨列放不下就换行；分组变化时先占一整行放标题。
      缺省布局继续保持既有算法（两列按游标取较矮的一列），既有配置的外观不变。 }
    LayRowTop := 10; LayRowHeight := 0; LayRowCol := 0; LayCurrentGroup := '';
    ColTop[0] := 10; ColTop[1] := 10;
    for I := 0 to Names.Count - 1 do
    begin
      ColumnName := Dec(Names[I]);
      Kind := FieldKindOf(ColumnName);
      { 下拉选项只由固定下拉控件消费：其它对象类型带下拉选项说明配置不匹配，
        SqlText/SqlQuery 下拉需要额外数据集，本批不接入，都明确拒绝而不是静默忽略。 }
      HasDrop := Trim(Str(ColumnRowOf(ColumnName), 'fdDropDownOptions')) <> '';
      if HasDrop and (Kind <> 'combobox') and (Kind <> 'lookupedit') and
        (Kind <> 'lookupeditextra') and (Kind <> 'gridcombobox') and
        (Kind <> 'gridcomboboxextra') then
        Exit(Fail('字段 ' + ColumnName + ' 配置了下拉选项，但对象类型是 ' + Kind +
          '；请改成固定下拉/查找/多列下拉，或清除该字段的下拉选项。'));
      ControlClass := ControlClassOf(Kind);
      SqlDrop := False;
      if Kind = 'combobox' then
      begin
        DropItems.Clear;
        if FixedDropDownLines(ColumnName, DropItems) then
          SqlDrop := False
        else if SqlTextDropDown(ColumnName, SqlText, DropValueField) then
        begin
          { SqlText：DFM 里不写死选项，初始化时用临时数据集灌入。 }
          SqlDrop := True;
          SqlLoaders.Add('leField' + IntToStr(I) + '|' + SqlText + '|' + DropValueField);
        end
        else
          Exit(Fail('字段 ' + ColumnName +
            ' 的下拉配置无效：SetText 需要非空选项内容，SqlText 需要单条 SELECT（SqlQuery 尚未接入）。'));
      end;
      if (Kind = 'lookupedit') or (Kind = 'lookupeditextra') or
        (Kind = 'gridcombobox') or (Kind = 'gridcomboboxextra') then
      begin
        { 查找/多列下拉字段：控件通过 LookupData / GridLookupDataSet 指向一个选项数据集，值字段存代码，
          lookupeditextra 再显示名称；动态加载需要远程检索脚本，本批直接拒绝。 }
        LkDrop := DropDownField(ColumnName);
        if LkDrop = nil then
          Exit(Fail('字段 ' + ColumnName + ' 是查找字段，但缺少查找配置 JSON。'));
        try
          if not SameText(Str(LkDrop, 'cbDropDownType'), 'SqlQuery') then
            Exit(Fail('字段 ' + ColumnName + ' 的查找类型须为 SqlQuery。'));
          LkSql := Trim(StringReplace(Str(LkDrop, 'mmText'), '\r\n', ' ', [rfReplaceAll]));
          LkSql := StringReplace(LkSql, #13, ' ', [rfReplaceAll]);
          LkSql := StringReplace(LkSql, #10, ' ', [rfReplaceAll]);
          if (LkSql <> '') and (LkSql[Length(LkSql)] = ';') then
            Delete(LkSql, Length(LkSql), 1);
          LkValue := Trim(Str(LkDrop, 'edOptionValue'));
          LkDisplay := Trim(Str(LkDrop, 'edOptionDisplay'));
          LkCaption := Str(LkDrop, 'edOptionCaption');
          { 精灵对话框的标签就是语义：edOptionFields=展示字段（列，含 字段@标题），
            edOptionLookupFields=搜索字段（纯字段名，决定多列下拉里哪些列可检索）。
            早前这里取反了，导致下拉里显示英文字段名而不是配置的中文列标题。 }
          LkFields := Trim(Str(LkDrop, 'edOptionFields'));
          LkSearch := Trim(Str(LkDrop, 'edOptionLookupFields'));
          if LkFields = '' then LkFields := LkSearch;
          LkMaxRec := StrToIntDef(Str(LkDrop, 'seMaxRecordCount'), 100);
          LkPageSize := StrToIntDef(Str(LkDrop, 'sePageSize'), 50);
          LkPaged := 0;
          if SameText(Str(LkDrop, 'cbGridPageSetting'), 'Open') then LkPaged := 1;
          LkDynamic := 0;
          if SameText(Str(LkDrop, 'cbDynamicLoading'), 'True') or
            (Str(LkDrop, 'cbDynamicLoading') = '1') or
            (Str(LkDrop, 'cbDynamicLoading') = '-1') then LkDynamic := 1;
        finally
          LkDrop.Free;
        end;
        if LkSql = '' then Exit(Fail('字段 ' + ColumnName + ' 的查找 SQL 为空。'));
        if (not SameText(Copy(LkSql, 1, 7), 'select ')) or (Pos(';', LkSql) > 0) or
          (Pos(':', LkSql) > 0) or (Pos('--', LkSql) > 0) or
          (Pos('/*', LkSql) > 0) then
          Exit(Fail('字段 ' + ColumnName + ' 的查找 SQL 须为无参数、无注释的单条 SELECT。'));
        { 动态加载要靠控件自己的 OnExtEditValueChange 远程取数；只有多列下拉注册了该事件。 }
        if (LkDynamic = 1) and (Kind <> 'gridcombobox') and (Kind <> 'gridcomboboxextra') then
          Exit(Fail('字段 ' + ColumnName +
            ' 用的是查找控件，不支持动态加载；请改用多列下拉，或关闭下拉选项里的动态加载。'));
        if LkValue = '' then Exit(Fail('字段 ' + ColumnName + ' 需要指定返回值字段。'));
        if LkFields = '' then Exit(Fail('字段 ' + ColumnName + ' 需要配置查找列。'));
        if ((Kind = 'lookupeditextra') or (Kind = 'gridcomboboxextra')) and
          (LkDisplay = '') then
          Exit(Fail('字段 ' + ColumnName + ' 的 extra 查找需要显示字段。'));
        LkDataName := 'lookupLE' + ColumnName;
        LookupSets.Add(LkDataName + '|' + LkSql + '|' + IntToStr(LkMaxRec) +
          '|' + IntToStr(LkPageSize) + '|' + IntToStr(LkPaged) + '|' + IntToStr(LkDynamic));
        { 动态加载的控件名（=记录区控件名）在这里生成，供事件绑定与远程取数例程使用。 }
        if LkDynamic = 1 then
          DynLookups.Add('leField' + IntToStr(I) + '|' + LkDataName + '|' + LkSql +
            '|' + IntToStr(LkMaxRec) + '|' + LkSearch);
      end;
      FieldHeight := ControlHeightOf(Kind);
      if HasLayout then
      begin
        LaySpan := LayoutItems[I].Span;
        if LaySpan > LayColumns then LaySpan := LayColumns;
        { 跨列放不下当前行就换行 }
        if LayRowCol + LaySpan > LayColumns then
        begin
          Inc(LayRowTop, LayRowHeight + 10);
          LayRowCol := 0; LayRowHeight := 0;
        end;
        { 分组变化时先占一整行放分组标题 }
        if LayGroups and not SameText(LayoutItems[I].Group, LayCurrentGroup) then
        begin
          LayCurrentGroup := LayoutItems[I].Group;
          if LayCurrentGroup <> '' then
          begin
            { 已经排过内容才需要下移一行；第一条分组标题与字段同用 10 的上边距。 }
            if LayRowHeight > 0 then Inc(LayRowTop, LayRowHeight + 10);
            LayRowCol := 0; LayRowHeight := 0;
            Headers.Add('    object capLEGroup' + IntToStr(Headers.Count div 7) + ': TUgLabel');
            Headers.Add('      Left = 10');
            Headers.Add('      Top = ' + IntToStr(LayRowTop));
            Headers.Add('      Width = ' + IntToStr(LayColumns * LayFieldWidth + (LayColumns - 1) * 20));
            Headers.Add('      Caption = ' + Enc(LayCurrentGroup));
            Headers.Add('      Font.Style = [fsBold]');
            Headers.Add('    end');
            Inc(LayRowTop, 26);
          end;
        end;
        LayFieldWidth2 := LayFieldWidth * LaySpan + (LaySpan - 1) * 20;
        if LayoutItems[I].Width > 0 then LayFieldWidth2 := LayoutItems[I].Width;
        FieldLeft := 10 + LayRowCol * LayStep;
        FieldTop := LayRowTop;
        if FieldHeight > LayRowHeight then LayRowHeight := FieldHeight;
        Inc(LayRowCol, LaySpan);
      end
      else
      begin
        if ColTop[0] <= ColTop[1] then Column := 0 else Column := 1;
        FieldLeft := 10 + Column * 270;
        FieldTop := ColTop[Column];
        LayFieldWidth2 := 250;
        Inc(ColTop[Column], FieldHeight + 10);
      end;
      Panel.Add('    object leField' + IntToStr(I) + ': ' + ControlClass);
      Panel.Add('      Left = ' + IntToStr(FieldLeft));
      Panel.Add('      Top = ' + IntToStr(FieldTop));
      Panel.Add('      Width = ' + IntToStr(LayFieldWidth2));
      Panel.Add('      Height = ' + IntToStr(FieldHeight));
      Panel.Add('      Hint = ''''');
      Panel.Add('      DataSource = dsMain');
      Panel.Add('      DataField = ' + Names[I]);
      if Kind = 'check' then
      begin
        // 复选控件用 Caption 承载标题（与编辑模板一致），不带 FieldLabel。
        { 注意：这里的 Captions[I] **已经是 DFM 编码后的文本**（#NNN），直接拼即可；
          再套一层 Enc 会二次编码（宿主 2026-09-21 实测：探针报"复选标题应写入 Caption"、
          "标题为空时应回退到排版标题"）。查询区那个循环的标题才是明文，见下面的 FieldLabel。 }
        Panel.Add('      Caption = ' + Captions[I]);
        Panel.Add('      ParentColor = False');
        Panel.Add('      Color = clBtnFace');
      end
      else
      begin
        if Kind = 'combobox' then
        begin
          Panel.Add('      Style = csDropDownList');
          if not SqlDrop then
          begin
            Panel.Add('      Items.Strings = (');
            for K := 0 to DropItems.Count - 1 do
              Panel.Add('        ' + Enc(DropItems[K]));
            Panel.Add('      )');
          end;
        end;
        if (Kind = 'date') or (Kind = 'time') or (Kind = 'datetime') then
        begin
          { time 用宿主自己的 TUgDBTimePicker（构造时即 Kind=tUniTime 并处理空时间显示），
            与 mtMasterSlave 的记录区做法一致。 }
          if Kind = 'date' then Panel.Add('      Kind = tUniDate')
          else if Kind = 'datetime' then
          begin
            Panel.Add('      Kind = tUniDateTime');
            Panel.Add('      DateMode = dtmDateTime');
          end;
          Panel.Add('      DateTime = 0');
          Panel.Add('      DateFormat = ''yyyy-MM-dd''');
          Panel.Add('      TimeFormat = ''HH:mm:ss''');
          Panel.Add('      ShowBlankDate = True');
        end;
        if Kind = 'number' then
        begin
          Panel.Add('      SelectOnFocus = True');
          { 原版数值框固定用点号小数分隔符。 }
          Panel.Add('      DecimalSeparator = ''.''');
        end;
        { 多列下拉（gridcombobox / gridcomboboxextra）：控件带一张可展开的多列表格。
          属性名与结构按原版 mtMasterSlave 样例（GridLookupDataSet / GridValueField /
          GridLookupFields（item 里 IsLookUp 表示可搜索列）/ GridDisplayField / GridValueWidth）。 }
        if (Kind = 'gridcombobox') or (Kind = 'gridcomboboxextra') then
        begin
          Panel.Add('      GridLookupDataSet = ' + LkDataName);
          Panel.Add('      GridValueField = ' + Q(LkValue));
          if Kind = 'gridcomboboxextra' then
          begin
            Panel.Add('      GridDisplayField = ' + Q(LkDisplay));
            Panel.Add('      GridValueWidth = 120');
          end;
          { 该属性为 True 时控件自己过滤本地数据集（静态）；动态加载时为 False，
            由 OnExtEditValueChange 远程取数（原版脚本里 `if v.GridLookupDataSetFilter then Exit`）。 }
          if LkDynamic = 1 then
            Panel.Add('      GridLookupDataSetFilter = False')
          else
            Panel.Add('      GridLookupDataSetFilter = True');
          if LkPaged = 1 then
          begin
            Panel.Add('      GridWebOptionPaged = True');
            Panel.Add('      GridWebOptionPageSize = ' + IntToStr(LkPageSize));
          end
          else
            Panel.Add('      GridWebOptionPaged = False');
          Panel.Add('      GridLookupFields = <');
          LkParts.StrictDelimiter := True; LkParts.Delimiter := ';';
          LkParts.DelimitedText := LkFields;
          for LkAt := 0 to LkParts.Count - 1 do
          begin
            LkPart := Trim(LkParts[LkAt]);
            if LkPart = '' then Continue;
            LkPos := Pos('@', LkPart);
            if LkPos > 0 then
            begin
              LkFldName := Trim(Copy(LkPart, 1, LkPos - 1));
              LkFldCaption := Trim(Copy(LkPart, LkPos + 1, MaxInt));
            end
            else
            begin
              LkFldName := LkPart;
              LkFldCaption := LkPart;
            end;
            Panel.Add('        item');
            if LkSearchField(LkSearch, LkFldName) then
              Panel.Add('          IsLookUp = True')
            else
              Panel.Add('          IsLookUp = False');
            Panel.Add('          Visible = True');
            Panel.Add('          FieldName = ' + Q(LkFldName));
            Panel.Add('          Caption = ' + Enc(LkFldCaption));
            Panel.Add('          Width = 120');
            Panel.Add('        end');
          end;
          Panel.Add('      >');
          Panel.Add('      SelectOnFocus = True');
        end;
        { 查找字段：值为代码（LookupValueField），extra 再显示名称（LookupDisplayField）。 }
        if (Kind = 'lookupedit') or (Kind = 'lookupeditextra') then
        begin
          Panel.Add('      LookupData = ' + LkDataName);
          Panel.Add('      LookupCaption = ' + Enc(LkCaption));
          Panel.Add('      LookupValueField = ' + Q(LkValue));
          if Kind = 'lookupeditextra' then
          begin
            Panel.Add('      LookupDisplayField = ' + Q(LkDisplay));
            Panel.Add('      LookupCodeWidth = 100');
          end;
          Panel.Add('      LookupFields = <');
          LkParts.StrictDelimiter := True; LkParts.Delimiter := ';';
          LkParts.DelimitedText := LkFields;
          for LkAt := 0 to LkParts.Count - 1 do
          begin
            LkPart := Trim(LkParts[LkAt]);
            if LkPart = '' then Continue;
            LkPos := Pos('@', LkPart);
            if LkPos > 0 then
            begin
              LkFldName := Trim(Copy(LkPart, 1, LkPos - 1));
              LkFldCaption := Trim(Copy(LkPart, LkPos + 1, MaxInt));
            end
            else
            begin
              LkFldName := LkPart;
              LkFldCaption := LkPart;
            end;
            Panel.Add('        item');
            Panel.Add('          FieldName = ' + Q(LkFldName));
            Panel.Add('          Caption = ' + Enc(LkFldCaption));
            Panel.Add('          Width = 160');
            Panel.Add('        end');
          end;
          Panel.Add('      >');
        end;
        { 数值控件（TUgDBNumberEdit）没有 EmptyText：宿主加载 DFM 时会报
          `Property EmptyText does not exist`，因此只给有该 published 属性的类写。 }
        if (Kind = 'edit') or (Kind = 'combobox') or
          (Kind = 'date') or (Kind = 'time') or (Kind = 'datetime') then
          Panel.Add('      EmptyText = ''''');
        { 这里的 Captions[I] 同样是**已编码**文本（与上面的 Caption 同一数组），直接拼即可。
          查询区控件的乱码不在这个循环里：那是 MultipleQueryControls 的 Quoted() 只做引号包裹、
          不编码非 ASCII 造成的（宿主 2026-09-21 反馈"查询条件生成的标题中文是乱码"），已在那边修。 }
        Panel.Add('      FieldLabel = ' + Captions[I]);
        Panel.Add('      FieldLabelAlign = laTop');
        if Kind = 'edit' then
        begin
          { 文本类型只作用于普通文本输入框，不影响下拉返回码。 }
          if SameText(TextCase, 'Upper') then Panel.Add('      CharCase = ecUpperCase');
          if SameText(TextCase, 'Lower') then Panel.Add('      CharCase = ecLowerCase');
        end;
      end;
      Panel.Add('      ReadOnly = True');
      Panel.Add('    end');
    end;
    { 独立布局：把分组标题行插到面板头部之后、字段之前；高度按最后一行推导。
      缺省布局沿用旧的“两列游标”高度算法，既有配置外观不变。 }
    if HasLayout then
    begin
      if LayRowCol > 0 then EditorHeight := LayRowTop + LayRowHeight + 10
      else EditorHeight := LayRowTop + 10;
    end
    else
    begin
      EditorHeight := ColTop[0];
      if ColTop[1] > EditorHeight then EditorHeight := ColTop[1];
    end;
    if SameText(LayPosition, 'Left') then
    begin
      { alLeft 容器的高度由对齐决定，AutoScroll 交给宿主；这里只补内容宽度。 }
      for I := Headers.Count - 1 downto 0 do Panel.Insert(HeadAt, Headers[I]);
    end
    else
    begin
      if EditorHeight < 80 then EditorHeight := 80;
      if EditorHeight > 350 then EditorHeight := 350;
      Panel.Insert(2, '    Height = ' + IntToStr(EditorHeight));
      if EditorHeight >= 350 then
      begin
        Panel.Insert(3, '    AutoScroll = True');
        Panel.Insert(4, '    ScrollDirection = sdVertical');
      end;
      { 分组标题行是子对象，必须排在面板全部属性之后：无 AutoScroll 时 4 行头，
        有 AutoScroll 时是 6 行头。 }
      HeadAt := 4;
      if EditorHeight >= 350 then Inc(HeadAt, 2);
      for I := Headers.Count - 1 downto 0 do Panel.Insert(HeadAt, Headers[I]);
    end;
    Panel.Add('    object listEditorBottomLine: TUgContainerPanel');
    if SameText(LayPosition, 'Left') then
    begin
      Panel.Add('      Align = alRight'); Panel.Add('      Width = 2');
    end
    else
    begin
      Panel.Add('      Align = alBottom'); Panel.Add('      Height = 2');
    end;
    Panel.Add('      ParentColor = False'); Panel.Add('      Color = clSilver');
    Panel.Add('    end');
    Panel.Add('  end');
    Lines.Insert(DataSourceAt + 1, '    AutoEdit = False');
    { 从表：解析 + （只读联动版）明细区。写模式下的从表写入在下一批接入，
      现在明确拒绝而不是静默忽略从表配置。 }
    MainPlain := TStringList.Create;
    DetailOut := TStringList.Create;
    try
      for I := 0 to Names.Count - 1 do MainPlain.Add(Dec(Names[I]));
      DetailPlan := nil;
      DetailAvailable := False;
      if TryPlanListEditorDetail(Config, MainPlain, WriteMode, DetailPlan, DetailReason) then
      begin
        { 写模式下明细区是可编辑版式（含新增行/删除行/复制行工具条）；明细写入脚本由
          AddListEditorWrite 生成（取号/父键回填/行号/校验/原子提交/删主记录连明细）。 }
        AddListEditorDetailPanel(DetailOut, DetailPlan, WriteMode, Buttons);
        AddListEditorDetailDataSets(Lines);
        for I := DetailOut.Count - 1 downto 0 do Lines.Insert(InsertAt, DetailOut[I]);
        { 有从表：gridMain = alLeft、明细区 = alClient、头部高度对齐主工具条（宿主 2026-09-20 指定）。 }
        ApplyDetailLayout(Lines);
        DetailAvailable := True;
      end
      else if DetailReason <> '' then
        Exit(Fail(DetailReason));
    finally
      DetailOut.Free;
      MainPlain.Free;
    end;
    for I := Panel.Count - 1 downto 0 do Lines.Insert(InsertAt, Panel[I]);
    // Standalone list editor is not a record-selection dialog.
    for I := Lines.Count - 1 downto 0 do
      if Pos('gridMain|<This>.OnDblClick:', Lines[I]) > 0 then Lines.Delete(I);
    AddLookupDataSets(Lines, LookupSets, Str(Config, 'TWebDataNodeName'));
    if WriteMode and not AddListEditorWrite(Config,Lines,Names,Captions,DetailPlan,Reason) then Exit;
    AddListEditorPresentation(Lines);
    { 工具栏重排放在这里：显示模板刚把「展开查询」插进工具条，重排要连它一起排
      （早前放在写入单元里做，看不到它 → 同名对象重复，宿主加载 DFM 报错）。 }
    if WriteMode then RelayoutListEditorToolbar(Config, Lines);
    AddListEditorInit(Lines, SqlLoaders, LookupSets, DynLookups, DetailPlan, DetailEvents);
    { 明细区是否可写要在释放计划之前记下来：下面全量剥离 dgEditing 之后，明细网格还得把它补回去。 }
    DetailGridEditable := WriteMode and (DetailPlan <> nil);
    FreeAndNil(DetailPlan);
    DetailAvailable := False;
    DFM := StringReplace(Lines.Text, 'dgEditing, ', '', [rfReplaceAll]);
    { 记录区的编辑走记录区控件，所以主表格一直剥离 dgEditing；**明细区不一样**：明细行是在表格里
      直接编辑的（新增行/删除行/复制行），剥离后宿主里就没法输入了，这里只给 gridDetail 补回。 }
    if DetailGridEditable then RestoreDetailGridEditing(DFM);
    Result := True;
  finally
    DetailPlan.Free; DetailEvents.Free;
    CopyConfig.Free; Headers.Free; DynLookups.Free; LkParts.Free; LookupSets.Free; SqlLoaders.Free; DropItems.Free; Captions.Free; Names.Free; Panel.Free; Lines.Free; Buttons.Free;
    if not Result then DFM := '';
  end;
end;

end.
