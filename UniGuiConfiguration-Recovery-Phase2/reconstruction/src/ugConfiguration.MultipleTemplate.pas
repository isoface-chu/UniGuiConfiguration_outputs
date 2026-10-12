unit ugConfiguration.MultipleTemplate;

interface
uses System.SysUtils, System.Classes, System.JSON;
function TryBuildMultipleTemplate(Config: TJSONObject; out DFM, Reason: string): Boolean;

implementation
uses System.Generics.Collections, ugConfiguration.MultipleQueryControls,
  ugConfiguration.MultiplePresentation, ugConfiguration.MultipleRecord, ugConfiguration.MultipleJoins,
  ugConfiguration.ReportPlan;
function O(J: TJSONObject; const Key: string): TJSONObject;
var V: TJSONValue;
begin
  Result := nil;
  if J = nil then Exit;
  V := J.GetValue(Key);
  if V is TJSONObject then Result := TJSONObject(V);
end;
function S(J: TJSONObject; const Key: string): string;
var V: TJSONValue;
begin
  Result := '';
  if J = nil then Exit;
  V := J.GetValue(Key);
  if Assigned(V) and not (V is TJSONNull) then Result := V.Value;
end;
function Yes(const V: string): Boolean;
begin Result := SameText(V, 'True') or (V = '1') or (V = '-1'); end;
function DefaultTrue(const V: string): Boolean;
begin Result := not SameText(V, 'False') and (V <> '0'); end;
function Q(const V: string): string;
var C: Char;
begin
  Result := '''';
  for C in V do
    if (Ord(C) < 32) or (Ord(C) > 126) then Result := Result + '''#' + IntToStr(Ord(C)) + ''''
    else if C = '''' then Result := Result + ''''''
    else Result := Result + C;
  Result := Result + '''';
end;
function TryBuildMultipleTemplate(Config: TJSONObject; out DFM, Reason: string): Boolean;
var Tables, Columns, Queries, Row, Settings, Data: TJSONObject;
  Fields, Captions, QueryFields, QueryCaptions, Ops, Buttons, Code, Lines, HiddenFields, FilterFields: TStringList;
  I, Y, ToolbarHeight: Integer; TableName, AliasName, Field, SQL, Key, Value, SortMode, GridOptions, TextCase: string;
  WriteMode, LeftLayout, TopRowLayout, GenericWrite, GridPersonalization: Boolean;
  EditFields, ImportCaptions: TStringList;
  RecordKey, AutoType, AutoPrefix, AutoSuffix, AutoDigits: string;
  AuditKeys: TArray<string>;
  AuditFields: array[0..5] of string;
  J: Integer;
  RequiredFields, UniqueFields: TStringList;
  UniqueJSON: TJSONValue;
  CheckExpr: string;
  QueryControls: TObjectList<TMultipleQueryControl>;
  QueryEvents, QueryInit: TStringList;
  QueryColumn: TJSONObject;
  QueryControl: TMultipleQueryControl;
  LargeQuery: Boolean;
  QueryJS: string;
  LayoutY, FieldHeight, RowHeight, IndependentIndex: Integer;
  SourceFields, JoinAliases: TStringList;
  JoinSQL, SourceField: string;
  ReportMode: Boolean;
  ReportPlan: TReportPlan;
  function Reject(const Msg: string): Boolean;
  begin Reason := Msg; Result := False; end;
  procedure AddButton(const Name, Caption, Handler: string; Left: Integer);
  var IconIndex: Integer;
  begin
    if (Name = 'btPrint') or (Name = 'btImport') then Lines.Add('    object ' + Name + ': TUgMenuButton')
    else Lines.Add('    object ' + Name + ': TUgButton');
    Lines.Add('      AlignWithMargins = True');
    Lines.Add('      Align = alLeft');
    Lines.Add('      Left = ' + IntToStr(Left));
    Lines.Add('      Top = 3');
    if (Name = 'btPrint') or (Name = 'btImport') then Lines.Add('      Width = 75')
    else Lines.Add('      Width = 60');
    Lines.Add('      Height = 26'); Lines.Add('      AutoWidth = True');
    IconIndex := 0;
    if Name = 'btAppend' then IconIndex := 1
    else if Name = 'btDelete' then IconIndex := 2
    else if Name = 'btEditor' then IconIndex := 3
    else if Name = 'btImport' then IconIndex := 4
    else if Name = 'btSave' then IconIndex := 5
    else if Name = 'btCancel' then IconIndex := 6
    else if Name = 'btExport' then IconIndex := 7
    else if Name = 'btPrint' then IconIndex := 8
    else if Name = 'btClose' then IconIndex := 9
    else if Name = 'btPrior' then IconIndex := 10
    else if Name = 'btNext' then IconIndex := 11
    else if Name = 'btOK' then IconIndex := 12;
    Lines.Add('      Images = Imgs');
    Lines.Add('      ImageIndex = ' + IntToStr(IconIndex));
    if (Name <> 'btQuery') and (Name <> 'btPrint') and (Name <> 'btClose') and (Name <> 'btOK') then
      Lines.Add('      Enabled = False');
    Lines.Add('      Caption = ' + Q(Caption)); Lines.Add('    end');
  end;
  procedure AddSeparator(const Name: string);
  begin
    Lines.Add('    object ' + Name + ': TUgContainerPanel');
    Lines.Add('      AlignWithMargins = True'); Lines.Add('      Align = alLeft');
    Lines.Add('      Left = ' + IntToStr(Y)); Inc(Y, 8);
    Lines.Add('      Width = 1'); Lines.Add('      Height = 22');
    Lines.Add('      Margins.Top = 5'); Lines.Add('      Margins.Bottom = 5');
    Lines.Add('      ParentColor = False'); Lines.Add('      Color = 13093060'); Lines.Add('    end');
  end;
  procedure AddPageButton(const Name, Caption: string; X: Integer);
  begin
    Lines.Add('    object ' + Name + ': TUgButton');
    Lines.Add('      AlignWithMargins = True'); Lines.Add('      Align = alLeft');
    Lines.Add('      Left = ' + IntToStr(X)); Lines.Add('      Top = 3');
    Lines.Add('      Width = 32'); Lines.Add('      Height = 26');
    Lines.Add('      AutoWidth = False'); Lines.Add('      Caption = ' + Q(Caption));
    Lines.Add('      Enabled = False'); Lines.Add('    end');
  end;
  procedure AddCodeSection(const Title: string);
  begin
    Code.Add('');
    Code.Add('//' + Title);
  end;
begin
  Result := False; DFM := ''; Reason := '';
  IndependentIndex := -1;
  AuditKeys := TArray<string>.Create('录入用户','录入部门','录入时间','修改用户','修改部门','修改时间');
  for I := 0 to 5 do AuditFields[I] := '';
  ReportMode := SameText(S(Config,'TWebModuletype'),'mtReport');
  ReportPlan := nil;
  if not ReportMode and not SameText(S(Config, 'TWebModuletype'), 'mtMultiple') then Exit(Reject('模块类型不是 mtMultiple 或 mtReport。'));
  Tables := O(O(Config, 'TWebDataStructure'), 'cdsTables'); Tables := O(Tables, 'Data');
  Columns := O(O(O(Config, 'TWebDataStructure'), 'cdsColumns'), 'Data');
  Queries := O(O(O(Config, 'TWebQueryCriteria'), 'cdsQueryCriteria'), 'Data');
  Settings := O(Config, 'TWebNormalSetting');
  Value := S(Settings, '界面布局');
  if (Value <> '') and not SameText(Value,'Top') and not SameText(Value,'Left') then
    Exit(Reject('未知界面布局：' + Value));
  LeftLayout := SameText(Value,'Left');
  // 同窗列表的顶部查询区按行横向排布，避免少量条件仍占用旧模板的整列高度。
  TopRowLayout := (not LeftLayout) and SameText(S(Config, 'TWebListEditorLayout'), 'True');
  SortMode := S(Settings, '字段排序');
  if SameText(SortMode, 'False') or (SortMode = '0') then SortMode := '';
  if (SortMode <> '') and not SameText(SortMode, 'Normal') and
    not SameText(SortMode, 'ColumnSort') and not SameText(SortMode, 'MultiColumnSort') then
    Exit(Reject('未知表格排序方式：' + SortMode));
  if (Tables = nil) or (Tables.Count < 1) or (Columns = nil) then
    Exit(Reject('mtMultiple 需要主表及字段配置。'));
  Row := O(Tables, '0'); TableName := S(Row, 'fdTableName'); AliasName := S(Row, 'fdEpithet');
  GenericWrite := not SameText(TableName,'Z_Unit');
  RecordKey := 'ID';
  AutoType := 'DBAutoincrement';
  TextCase := 'Normal';
  if not IsValidIdent(TableName) or not IsValidIdent(AliasName) or (S(Row, 'fdParent') <> '') then
    Exit(Reject('主表名及别名须为简单标识符，暂不支持关联表。'));
  if Yes(S(Config, 'TWebDataNodeNamecbAddCatalogName')) or Yes(S(Config, 'TWebDataNodeNamecbAddSchemaName')) then
    Exit(Reject('mtMultiple 首批尚不支持目录/Schema 前缀。'));
  Data := O(O(O(Config, 'TWebDataPerspective'), 'cdsDataPerspective'), 'Data');
  if not ReportMode and (Data <> nil) and (Data.Count > 0) then Exit(Reject('mtMultiple 不实现数据透视，请使用 mtReport。'));
  for Key in TArray<string>.Create('cdsTables','cdsColumns','cdsTypesetting') do
  begin
    Data := O(O(O(Config, 'TWebDetailedStructure'), Key), 'Data');
    if (Data <> nil) and (Data.Count > 0) then Exit(Reject('mtMultiple 首批尚不支持从表配置。'));
  end;
  if Settings <> nil then
    for I := 0 to Settings.Count - 1 do
    begin
      Key := Settings.Pairs[I].JsonString.Value; Value := Settings.Pairs[I].JsonValue.Value;
      if (Value = '') or SameText(Value, 'False') or (Value = '0') then Continue;
      if Key = '文本类型' then
      begin
        TextCase := Trim(Value);
        if SameText(TextCase, 'Normal') or
           (SameText(S(Config, 'TWebListEditorLayout'), 'True') and
            (SameText(TextCase, 'Upper') or SameText(TextCase, 'Lower'))) then Continue;
      end;
      if Key = '界面布局' then Continue;
      if Key = '隐藏字段-主表' then Continue;
      if Key = '字段排序' then Continue;
      if Key = '编辑窗体' then Continue;
      if (Key = '自动编号') and GenericWrite then Continue;
      if (Key = '非空字段') or (Key = '主表唯一') then Continue;
      if (Key = '录入用户') or (Key = '录入部门') or (Key = '录入时间') or
        (Key = '修改用户') or (Key = '修改部门') or (Key = '修改时间') then Continue;
      if (Key = '表格过滤') and Yes(Value) then Continue;
      if (Key = '层级权限') and Yes(Value) then Continue;
      if ((Key = '字段宽度') or (Key = '字段移动') or (Key = '字段显隐') or
          (Key = '表格多选') or (Key = '表格复制') or (Key = '表格序号')) and Yes(Value) then Continue;
      Exit(Reject('mtMultiple 首批尚未实现常规设置：' + Key + '。请勿用于带权限或写回规则的正式模块。'));
    end;
  Fields := TStringList.Create; Captions := TStringList.Create;
  QueryFields := TStringList.Create; QueryCaptions := TStringList.Create; Ops := TStringList.Create;
  Buttons := TStringList.Create; Code := TStringList.Create; Lines := TStringList.Create;
  HiddenFields := TStringList.Create;
  FilterFields := TStringList.Create;
  RequiredFields := TStringList.Create; UniqueFields := TStringList.Create;
  EditFields := TStringList.Create;
  ImportCaptions := TStringList.Create;
  QueryControls := TObjectList<TMultipleQueryControl>.Create(True);
  QueryEvents := TStringList.Create; QueryInit := TStringList.Create;
  SourceFields := TStringList.Create; JoinAliases := TStringList.Create;
  LargeQuery := False;
  try
    try JoinSQL := BuildMultipleJoins(Tables,Columns,JoinAliases);
    except on E:Exception do Exit(Reject(E.Message));end;
    Fields.CaseSensitive := False;
    HiddenFields.CaseSensitive := False;
    HiddenFields.StrictDelimiter := True; HiddenFields.Delimiter := ';';
    HiddenFields.DelimitedText := S(Settings, '隐藏字段-主表');
    for I := HiddenFields.Count - 1 downto 0 do
    begin
      Field := Trim(HiddenFields[I]);
      if Field = '' then begin HiddenFields.Delete(I); Continue; end;
      Value := MultipleOutputField(Field,AliasName,JoinAliases);
      if not IsValidIdent(Value) then Exit(Reject('非法隐藏字段：' + Field));
      Y := 0;
      while Y < Columns.Count do
      begin
        if SameText(S(O(Columns, IntToStr(Y)), 'fdCOLUMN_NAME'), Field) then Break;
        Inc(Y);
      end;
      if Y = Columns.Count then Exit(Reject('隐藏字段不存在于主表配置：' + Field));
      HiddenFields[I] := Value;
    end;
    Buttons.StrictDelimiter := True; Buttons.Delimiter := ';';
    Buttons.DelimitedText := S(Config, 'TWebFunctionButton');
    WriteMode := (Buttons.IndexOf('btAppend') >= 0) or (Buttons.IndexOf('btEditor') >= 0) or
      (Buttons.IndexOf('btSave') >= 0) or (Buttons.IndexOf('btCancel') >= 0) or (Buttons.IndexOf('btDelete') >= 0) or
      (Buttons.IndexOf('btImport') >= 0);
    if ReportMode and WriteMode then Exit(Reject('mtReport 是只读统计报表，不能配置新增、修改、删除、导入或保存按钮。'));
    GridPersonalization := Yes(S(Settings, '字段宽度')) or Yes(S(Settings, '字段移动')) or Yes(S(Settings, '字段显隐'));
    if Tables.Count>1 then GenericWrite := True;
    for Key in Buttons do
      if (Key <> '') and (Key <> 'btQuery') and (Key <> 'btClose') and
        (Key <> 'btAppend') and (Key <> 'btEditor') and (Key <> 'btSave') and (Key <> 'btCancel') and (Key <> 'btDelete') and
        (Key <> 'btExport') and (Key <> 'btPrint') and (Key <> 'btImport') and (Key <> 'btOK') and
        not (ReportMode and (Key = 'btAnnex')) then
        Exit(Reject('mtMultiple 尚不支持按钮：' + Key));
    if WriteMode then
    begin
      if GenericWrite then begin
        UniqueJSON:=TJSONObject.ParseJSONValue(S(Settings,'自动编号'));
        try
          if not (UniqueJSON is TJSONObject) then
            Exit(Reject('通用单表写回须明确配置自动编号字段和编号方式。'));
          AutoType:=Trim(S(TJSONObject(UniqueJSON),'cbAutoNumberType'));
          if not SameText(AutoType,'DBAutoincrement') and not SameText(AutoType,'MaxCode') and
             not SameText(AutoType,'Guid') and not SameText(AutoType,'DateTimeRandom') then
            Exit(Reject('mtMultiple 自动编号支持 DBAutoincrement、MaxCode、Guid、DateTimeRandom；SeqUence 尚未接入。'));
          AutoPrefix:=S(TJSONObject(UniqueJSON),'edPrefix');
          AutoSuffix:=S(TJSONObject(UniqueJSON),'edSuffix');
          AutoDigits:=S(TJSONObject(UniqueJSON),'seDigitCapacity');
          if SameText(AutoType,'MaxCode') or SameText(AutoType,'DateTimeRandom') then
            if (StrToIntDef(AutoDigits,0)<1) or (StrToIntDef(AutoDigits,0)>9) then
              Exit(Reject('自动编号位数必须为1到9。'));
          Value:=S(TJSONObject(UniqueJSON),'cbField');
          if not SameText(Copy(Value,1,Length(AliasName)+1),AliasName+'.') then
            Exit(Reject('自动编号主键别名与主表不匹配。'));
          RecordKey:=Copy(Value,Length(AliasName)+2,MaxInt);
          if not IsValidIdent(RecordKey) then Exit(Reject('无效的自动编号字段。'));
        finally UniqueJSON.Free; end;
      end;
      if (Buttons.IndexOf('btSave') < 0) or (Buttons.IndexOf('btCancel') < 0) then
        Exit(Reject('新增/编辑必须同时配置保存和撤销按钮。'));
      if Trim(S(Settings, '编辑窗体')) = '' then Exit(Reject('请先选择包含 v字段名 变量的编辑窗体。'));
    end;
    if Buttons.IndexOf('btQuery') < 0 then Exit(Reject('请选中查询按钮。'));
    for I := 0 to Columns.Count - 1 do
    begin
      Row := O(Columns, IntToStr(I));
      if Row = nil then Exit(Reject('主表字段缺少数字行键。'));
      if not Yes(S(Row, 'fdSELECT')) then Continue;
      Field := S(Row, 'fdCOLUMN_NAME');
      SourceField := Field;
      Field := MultipleOutputField(Field,AliasName,JoinAliases);
      if not IsValidIdent(Field) or (Fields.IndexOf(Field) >= 0) then Exit(Reject('非法或重复字段：' + Field));
      if (S(Row, 'fdDropDownOptions') <> '') or (S(Row, 'fdDataCheck') <> '') then
      begin
        { 同窗列表编辑（TWebListEditorLayout）的固定下拉由顶部记录区控件消费，
          网格仍是只读文本列，因此这里放行下拉；数据校验仍未接入任何布局。
          下拉类型与选项由 ugConfiguration.ListEditorTemplate 负责校验。 }
        if (S(Row, 'fdDataCheck') <> '') or
          not SameText(S(Config, 'TWebListEditorLayout'), 'True') then
          Exit(Reject('mtMultiple 首批只读网格尚不支持字段下拉/数据校验。'));
      end;
      Fields.Add(Field); Captions.Add(S(Row, 'fdCAPTION'));
      SourceFields.Add(SourceField);
      Key := UpperCase(Trim(S(Row, 'fdCOLUMN_TYPENAME')));
      if not ReportMode and Yes(S(Settings, '表格过滤')) and
        ((Key = 'VARCHAR') or (Key = 'NVARCHAR') or (Key = 'CHAR') or
         (Key = 'NCHAR') or (Key = 'VARCHAR2') or (Key = 'NVARCHAR2') or
         (Key = 'CHARACTER VARYING') or (Key = 'TEXT') or (Key = 'NTEXT') or
         (Key = 'STRING') or (Key = 'WIDESTRING')) then FilterFields.Add(Field);
    end;
    if Fields.Count = 0 then Exit(Reject('请至少选择一个主表字段。'));
    RequiredFields.StrictDelimiter := True; RequiredFields.Delimiter := ';';
    UniqueFields.StrictDelimiter := True; UniqueFields.Delimiter := ';';
    RequiredFields.DelimitedText := S(Settings,'非空字段');
    if Trim(S(Settings,'主表唯一')) <> '' then
    begin
      UniqueJSON := TJSONObject.ParseJSONValue(S(Settings,'主表唯一'));
      try
        if not (UniqueJSON is TJSONObject) then Exit(Reject('主表唯一配置不是有效 JSON 对象。'));
        if (Trim(S(TJSONObject(UniqueJSON),'cbField'))<>'') and
           not SameText(S(TJSONObject(UniqueJSON),'cbField'),AliasName+'.'+RecordKey) then
          Exit(Reject('主表唯一的记录编号必须与配置的记录键一致。'));
        UniqueFields.DelimitedText := S(TJSONObject(UniqueJSON),'cdsMultiSelectFields');
        if UniqueFields.Count = 0 then Exit(Reject('请至少选择一个组合唯一字段。'));
      finally UniqueJSON.Free;end;
    end;
    for I := RequiredFields.Count-1 downto 0 do
    begin
      Value := Trim(RequiredFields[I]);
      if Value = '' then begin RequiredFields.Delete(I);Continue;end;
      if GenericWrite then begin
        if not SameText(Copy(Value,1,Length(AliasName)+1),AliasName+'.') or
           (Fields.IndexOf(Copy(Value,Length(AliasName)+2,MaxInt))<0) then
          Exit(Reject('非空字段必须是已选择的主表字段：'+Value));
      end else if not SameText(Value,AliasName+'.Name') and not SameText(Value,AliasName+'.ReMark') then
        Exit(Reject('本轮非空校验仅支持 Name、ReMark。'));
      RequiredFields[I] := Copy(Value,Length(AliasName)+2,MaxInt);
    end;
    for I := UniqueFields.Count-1 downto 0 do
    begin
      Value := Trim(UniqueFields[I]);
      if Value = '' then begin UniqueFields.Delete(I);Continue;end;
      if GenericWrite then begin
        if not SameText(Copy(Value,1,Length(AliasName)+1),AliasName+'.') or
           (Fields.IndexOf(Copy(Value,Length(AliasName)+2,MaxInt))<0) then
          Exit(Reject('唯一字段必须是已选择的主表字段：'+Value));
      end else if not SameText(Value,AliasName+'.Name') and not SameText(Value,AliasName+'.ReMark') then
        Exit(Reject('本轮组合唯一仅支持 Name、ReMark。'));
      UniqueFields[I] := Copy(Value,Length(AliasName)+2,MaxInt);
    end;
    if (Trim(S(Settings,'主表唯一')) <> '') and (UniqueFields.Count = 0) then
      Exit(Reject('请至少选择一个组合唯一字段。'));
    if ((RequiredFields.Count > 0) or (UniqueFields.Count > 0)) and not WriteMode then
      Exit(Reject('非空/唯一校验需要启用写回按钮。'));
    for I := 0 to 5 do
    begin
      Value := Trim(S(Settings, AuditKeys[I]));
      if Value = '' then Continue;
      if not WriteMode and not ((I = 1) and (ReportMode or Yes(S(Settings, '层级权限')))) then
        Exit(Reject('自动赋值规则需要启用新增/编辑及保存/撤销：' + AuditKeys[I]));
      if not SameText(Copy(Value, 1, Length(AliasName)+1), AliasName+'.') then
        Exit(Reject('自动赋值字段别名错误：' + Value));
      Field := Copy(Value, Length(AliasName)+2, MaxInt);
      if ReportMode and (I=1) then
      begin
        J:=0;
        while J<Columns.Count do begin
          if SameText(S(O(Columns,IntToStr(J)),'fdCOLUMN_NAME'),Value) then Break;
          Inc(J);
        end;
        if not IsValidIdent(Field) or (J=Columns.Count) then
          Exit(Reject('层级权限部门字段不存在：'+Value));
        AuditFields[I]:=Field;
        Continue;
      end;
      if not IsValidIdent(Field) or (Fields.IndexOf(Field) < 0) then
        Exit(Reject('自动赋值字段必须在已选主表字段中：' + Value));
      if SameText(Field,RecordKey) or ((not GenericWrite) and
        (SameText(Field,'Name') or SameText(Field,'ReMark'))) then
        Exit(Reject('自动赋值不能覆盖主键或编辑字段：' + Value));
      for J := 0 to I-1 do
        if SameText(AuditFields[J],Field) then Exit(Reject('多个自动赋值规则不能使用同一字段：' + Value));
      AuditFields[I] := Field;
    end;
    if Yes(S(Settings, '层级权限')) and (AuditFields[1] = '') then
      Exit(Reject('层级权限需要先配置“录入部门”字段。'));
    if WriteMode and GenericWrite then begin
      if Fields.IndexOf(RecordKey)<0 then Exit(Reject('必须选择配置的自动编号字段：'+RecordKey));
      Value:='';
      for I:=0 to Columns.Count-1 do
        if SameText(S(O(Columns,IntToStr(I)),'fdCOLUMN_NAME'),AliasName+'.'+RecordKey) then
          Value:=UpperCase(S(O(Columns,IntToStr(I)),'fdCOLUMN_TYPENAME'));
      if SameText(AutoType,'DBAutoincrement') and
         (Value<>'INT') and (Value<>'INTEGER') and (Value<>'BIGINT') and
         (Value<>'SMALLINT') and (Value<>'AUTOINC') then
        Exit(Reject('数据库自增主键须为整数字段，请核对真实表结构。'));
      if not SameText(AutoType,'DBAutoincrement') then
        if (Value<>'VARCHAR') and (Value<>'NVARCHAR') and (Value<>'CHAR') and
           (Value<>'NCHAR') and (Value<>'STRING') and (Value<>'WIDESTRING') then
          Exit(Reject('MaxCode、Guid、DateTimeRandom 需要字符串编号字段；数据库自增整数字段请保留 DBAutoincrement。'));
      for Field in Fields do begin
        if not SameText(SourceFields[Fields.IndexOf(Field)],AliasName+'.'+Field) then Continue;
        if SameText(Field,RecordKey) then Continue;
        J:=0;
        while (J<6) and not SameText(Field,AuditFields[J]) do Inc(J);
        if J=6 then EditFields.Add(Field);
      end;
      if EditFields.Count=0 then Exit(Reject('请至少选择一个可编辑业务字段。'));
    end;
    if WriteMode and (Tables.Count>1) then
    begin
      try
        AddMultipleJoinWrite(Code,Tables,Columns,Fields,SourceFields,AliasName,JoinSQL);
      except
        on E: Exception do Exit(Reject(E.Message));
      end;
    end;
    if Yes(S(Settings, '层级权限')) then
    begin
      AddCodeSection('生成当前部门及下级部门查询列表');
      Code.Add('function GetSubClassName: string;');
      Code.Add('var L: TStringList;'); Code.Add('begin');
      Code.Add('  L := TStringList.Create;'); Code.Add('  try');
      Code.Add('    L.Text := ReplaceText(UGMM.Informations.Values[''ClassName''] + UGMM.Informations.Values[''SubClassName''], '';'', #13#10);');
      Code.Add('    Result := '''';'); Code.Add('    while L.Count > 0 do'); Code.Add('    begin');
      Code.Add('      if Trim(L[0]) <> '''' then Result := Result + iif(Result = '''', '''', '','') + QuotedStr(Trim(L[0]));');
      Code.Add('      L.Delete(0);'); Code.Add('    end;');
      Code.Add('    if Result = '''' then Result := QuotedStr(''__NO_DEPARTMENT__'');');
      Code.Add('    Result := ''('' + Result + '')'';');
      Code.Add('  finally');
      Code.Add('    L.Free;');
      Code.Add('  end;');
      Code.Add('end;');
    end;
    AddCodeSection('定义分页运行状态');
    Code.Add('var PagingBusy: Boolean = False; PagingStarted: Int64 = 0;');
    AddCodeSection('根据数据集和编辑状态刷新工具栏按钮');
    Code.Add('procedure RefreshToolbar;');
    Code.Add('var Opened, HasRows, Dirty: Boolean;'); Code.Add('begin');
    Code.Add('  //先恢复全部权限候选状态');
    for Key in Buttons do
      if Key <> '' then Code.Add('  ' + Key + '.Enabled := True;');
    Code.Add('  btFirst.Enabled := True; btPrior.Enabled := True; btLast.Enabled := True; btNext.Enabled := True;');
    Code.Add('  edCurrentPage.Enabled := True; cbLinesperPage.Enabled := True;');
    Code.Add('  //应用宿主模块权限');
    Code.Add('  UGMM.VerifyRunFramePerm(Self);');
    Code.Add('  //再根据数据集和未保存状态限制按钮');
    Code.Add('  Opened := cdsMain.Active;');
    Code.Add('  HasRows := False;');
    Code.Add('  Dirty := False;');
    Code.Add('  if Opened then');
    Code.Add('  begin');
    Code.Add('    HasRows := not cdsMain.IsEmpty;');
    Code.Add('    Dirty := cdsMain.ChangeCount > 0;');
    Code.Add('  end;');
    for Key in Buttons do
    begin
      if (Key='btSave') or (Key='btCancel') then Value := 'Opened and Dirty'
      //通用单表新增只追加暂存记录，不清空已有修改；允许连续录入。
      else if (Key='btAppend') and GenericWrite then Value := 'Opened'
      else if (Key='btAppend') or (Key='btImport') or (Key='btExport') then Value := 'Opened and not Dirty'
      else if (Key='btEditor') or (Key='btDelete') then Value := 'HasRows and not Dirty'
      else if (Key='btQuery') or (Key='btPrint') or (Key='btClose') or (Key='btAnnex') then Value := 'not Dirty'
      else Continue;
      Code.Add('  ' + Key + '.Enabled := ' + Key + '.Enabled and (' + Value + ');');
    end;
    Code.Add('  btFirst.Enabled := btFirst.Enabled and Opened and not Dirty and (cdsMain.PageIndex > 1);');
    Code.Add('  btPrior.Enabled := btPrior.Enabled and Opened and not Dirty and (cdsMain.PageIndex > 1);');
    Code.Add('  btLast.Enabled := btLast.Enabled and Opened and not Dirty and (cdsMain.PageIndex < cdsMain.PageCount);');
    Code.Add('  btNext.Enabled := btNext.Enabled and Opened and not Dirty and (cdsMain.PageIndex < cdsMain.PageCount);');
    Code.Add('  edCurrentPage.Enabled := edCurrentPage.Enabled and Opened and not Dirty and (cdsMain.PageCount > 0);');
    Code.Add('  cbLinesperPage.Enabled := cbLinesperPage.Enabled and not Dirty;');
    Code.Add('end;');
    AddCodeSection('同步分页按钮、页码和统计信息');
    Code.Add('procedure SyncPaging;'); Code.Add('begin');
    Code.Add('  PagingBusy := True;'); Code.Add('  try');
    Code.Add('    edCurrentPage.Text := IntToStr(cdsMain.PageIndex);');
    Code.Add('    cbLinesperPage.Text := IntToStr(cdsMain.PageRowCount);');
    Code.Add('    btFirst.Enabled := cdsMain.Active and (cdsMain.PageIndex > 1);');
    Code.Add('    btLast.Enabled := cdsMain.Active and (cdsMain.PageIndex < cdsMain.PageCount);');
    Code.Add('    edCurrentPage.Enabled := cdsMain.Active and (cdsMain.PageCount > 0);');
    Code.Add('    capPagingInfo.Caption := Format(' + QuotedStr('共 %s 行, %s 页,每页 %s 行,耗时:%s ms') + ', [IntToStr(cdsMain.TotalRecordCount), IntToStr(cdsMain.PageCount), IntToStr(cdsMain.PageRowCount), IntToStr(UGMM.GetTickCount - PagingStarted)]);');
    Code.Add('  finally');
    Code.Add('    PagingBusy := False;');
    Code.Add('  end;');
    Code.Add('end;');
    if WriteMode then
    begin
      if not GenericWrite then begin
      AddCodeSection('验证主表非空和唯一规则');
      Code.Add('procedure ValidateUnitRecord(IsNew: Boolean; NewName, NewRemark: Variant);');
      Code.Add('var SavedRow: Integer; CurrentID: Variant; SQL: string;'); Code.Add('begin');
      for Field in RequiredFields do
      begin
        if SameText(Field,'Name') then Value := 'NewName' else Value := 'NewRemark';
        if Field = RequiredFields[0] then Code.Add('  //验证必填字段');
        Key:=Field;
        if Fields.IndexOf(Field)>=0 then
          if Trim(Captions[Fields.IndexOf(Field)])<>'' then Key:=Captions[Fields.IndexOf(Field)];
        Code.Add('  if Trim(VarToStr(' + Value + ')) = '''' then RaiseException(' + QuotedStr(Key)+' + '+QuotedStr(' 不能为空。') + ');');
      end;
      if UniqueFields.Count > 0 then
      begin
        Code.Add('  //检查当前已加载数据中的组合唯一值');
        Code.Add('  SavedRow := cdsMain.RecNo; CurrentID := Null;');
        Code.Add('  if not IsNew then CurrentID := cdsMain.FieldByName(''ID'').AsVariant;');
        Code.Add('  cdsMain.DisableControls;'); Code.Add('  try'); Code.Add('    cdsMain.First;');
        Code.Add('    while not cdsMain.Eof do'); Code.Add('    begin');
        CheckExpr := '';
        for Field in UniqueFields do
        begin
          if SameText(Field,'Name') then Value := 'NewName' else Value := 'NewRemark';
          if CheckExpr <> '' then CheckExpr := CheckExpr + ' and ';
          CheckExpr := CheckExpr + '(UpperCase(VarToStr(cdsMain.FieldByName('+QuotedStr(Field)+').AsVariant)) = UpperCase(VarToStr('+Value+')))';
        end;
        Code.Add('      if (IsNew or (cdsMain.RecNo <> SavedRow)) and ('+CheckExpr+') then');
        Code.Add('        RaiseException('+QuotedStr('当前列表中已有相同的组合唯一字段。')+');');
        Code.Add('      cdsMain.Next;'); Code.Add('    end;'); Code.Add('  finally');
        Code.Add('    if SavedRow > 0 then cdsMain.RecNo := SavedRow;');
        Code.Add('    cdsMain.EnableControls;'); Code.Add('  end;');
        Code.Add('  //检查后台数据库中的组合唯一值');
        Code.Add('  SQL := ''select ID from Z_Unit where 1 = 1'';');
        for I := 0 to UniqueFields.Count-1 do
        begin
          Field := UniqueFields[I];
          if SameText(Field,'Name') then Value := 'NewName' else Value := 'NewRemark';
          Code.Add('  if VarToStr('+Value+') = '''' then SQL := SQL + '+QuotedStr(' and ('+Field+' is null or '+Field+' = '''')') );
          Code.Add('  else SQL := SQL + '+QuotedStr(' and '+Field+' = :uq'+IntToStr(I))+';');
        end;
        Code.Add('  if CurrentID <> Null then SQL := SQL + '' and ID <> :excludeID'';');
        Code.Add('  cdsUnique.Close;'); Code.Add('  cdsUnique.CommandText := SQL;');
        for I := 0 to UniqueFields.Count-1 do
        begin
          if SameText(UniqueFields[I],'Name') then Value := 'NewName' else Value := 'NewRemark';
          Code.Add('  if VarToStr('+Value+') <> '''' then cdsUnique.ParamByName(''uq'+IntToStr(I)+''').AsString := VarToStr('+Value+');');
        end;
        Code.Add('  if CurrentID <> Null then cdsUnique.ParamByName(''excludeID'').Value := CurrentID;');
        Code.Add('  cdsUnique.DataNodeName := cDataNodeName;');
        Code.Add('  try');Code.Add('    cdsUnique.Open;');
        Code.Add('    if not cdsUnique.IsEmpty then RaiseException('+QuotedStr('数据库中已有相同的组合唯一字段。')+');');
        Code.Add('  finally');Code.Add('    cdsUnique.Close;');Code.Add('  end;');
      end;
      Code.Add('end;');
      if (Fields.IndexOf('ID') < 0) or (Fields.IndexOf('Name') < 0) or (Fields.IndexOf('ReMark') < 0) then
        Exit(Reject('Z_Unit 写回必须选择 ID、Name、ReMark；ID 不从编辑窗体写入。'));
      for Field in Fields do
        if not SameText(Field, 'ID') and not SameText(Field, 'Name') and not SameText(Field, 'ReMark') then
        begin
          Y := 0;
          while (Y < 6) and not SameText(Field,AuditFields[Y]) do Inc(Y);
          if Y = 6 then Exit(Reject('额外字段必须配置对应的录入/修改自动赋值规则：' + Field));
        end;
      end;
    end;
    if Queries <> nil then
      for I := 0 to Queries.Count - 1 do
      begin
        Row := O(Queries, IntToStr(I));
        if Row = nil then Exit(Reject('查询条件缺少数字行键。'));
        if Yes(S(Row, 'fdIndePendence')) then begin
          if IndependentIndex >= 0 then
            Exit(Reject('当前支持一条独立查询条件；多个独立条件的优先级尚待核对。'));
          IndependentIndex := I;
        end;
        Field := S(Row, 'fdColumn_name');
        SourceField := Field;
        Field := MultipleOutputField(Field,AliasName,JoinAliases);
        if Fields.IndexOf(Field) < 0 then Exit(Reject('查询字段须在已选主表字段中。'));
        Key := LowerCase(Trim(S(Row, 'fdComparisonOperator')));
        if (Key <> '=') and (Key <> '<>') and (Key <> '>') and
          (Key <> '>=') and (Key <> '<') and (Key <> '<=') and (Key <> 'like') and (Key <> 'in') then
          Exit(Reject('mtMultiple 查询运算符支持 =、<>、>、>=、<、<=、like、in。'));
        QueryFields.Add(Field); QueryCaptions.Add(S(Row, 'fdCaption')); Ops.Add(Key);
        QueryColumn := nil;
        for J := 0 to Columns.Count - 1 do
          if SameText(S(O(Columns, IntToStr(J)), 'fdCOLUMN_NAME'), SourceField) then
            QueryColumn := O(Columns, IntToStr(J));
        try
          QueryControl := TMultipleQueryControl.Create(Row, QueryColumn, I);
        except on E: Exception do Exit(Reject(E.Message)); end;
        QueryControls.Add(QueryControl);
        LargeQuery := LargeQuery or (QueryControl.Kind <> 'edit');
        QueryControl.AddCode(Code, QueryEvents, QueryInit);
      end;
    if ReportMode then
    begin
      try
        ReportPlan := TReportPlan.Create(Config,Fields,SourceFields);
      except on E: Exception do Exit(Reject(E.Message)); end;
    end;
    SQL := 'select ';
    for I := 0 to Fields.Count - 1 do
    begin
      if I > 0 then SQL := SQL + ', ';
      SQL := SQL + SourceFields[I];
      if not SameText(SourceFields[I],AliasName+'.'+Fields[I]) then
        SQL := SQL+' as '+Fields[I];
    end;
    SQL := SQL + ' from ' + TableName + ' ' + AliasName + JoinSQL + ' where 1 = 1';
    Code.Insert(0, 'const cDataNodeName = ' + QuotedStr(S(Config, 'TWebDataNodeName')) + ';');
    Code.Insert(0, '//定义全局常量');
    Code.Insert(2, '');
    if WriteMode then
    begin
      AddCodeSection('检查是否存在未保存的数据');
      Code.Add('procedure CheckNoPendingChanges;'); Code.Add('begin');
      Code.Add('  if cdsMain.ChangeCount > 0 then RaiseException(' + QuotedStr('有未保存数据，请先保存或撤销。') + ');'); Code.Add('end;');
      AddCodeSection('打开编辑窗体并暂存新增或修改数据');
      if GenericWrite then
      begin
        if (RequiredFields.Count>0) or (UniqueFields.Count>0) then
          AddMultipleValidation(Code,RequiredFields,UniqueFields,Fields,Captions,TableName,RecordKey,
            SameText(AutoType,'DBAutoincrement'));
        if not SameText(AutoType,'DBAutoincrement') then
          AddMultipleAutoNumber(Code,TableName,RecordKey,AutoType,AutoPrefix,AutoSuffix,AutoDigits);
        AddMultipleRecordEditor(Code,EditFields,RecordKey,S(Settings,'编辑窗体'),AuditFields,
          not SameText(AutoType,'DBAutoincrement'),(RequiredFields.Count>0) or (UniqueFields.Count>0),Tables.Count>1);
      end
      else begin
      Code.Add('procedure EditUnitRecord(IsNew: Boolean);');
      Code.Add('var');
      Code.Add('  F: TUgWebForm;');
      Code.Add('  NewName, NewRemark: Variant;');
      Code.Add('  RetryEditor: Boolean;');
      Code.Add('  EditorError: String;');
      Code.Add('begin');
      Code.Add('  if not cdsMain.Active then RaiseException(' + QuotedStr('请先查询数据。') + ');');
      Code.Add('  if (not IsNew) and cdsMain.IsEmpty then RaiseException(' + QuotedStr('请先选择要编辑的记录。') + ');');
      Code.Add('  //按配置的窗体标题打开编辑模块');
      Code.Add('  F := TUgWebForm(UGMM.GetWebSubForm(' + QuotedStr(S(Settings, '编辑窗体')) + '));');
      Code.Add('  if F = nil then RaiseException(' + QuotedStr('无法打开编辑窗体。') + ');');
      Code.Add('  try');
      Code.Add('    if IsNew then'); Code.Add('    begin');
      Code.Add('      TUgWebRunFrame(F.RunFrame).SetValue(''vName'', Null);');
      Code.Add('      TUgWebRunFrame(F.RunFrame).SetValue(''vReMark'', Null);');
      Code.Add('    end else'); Code.Add('    begin');
      Code.Add('      TUgWebRunFrame(F.RunFrame).SetValue(''vName'', cdsMain.FieldByName(''Name'').AsVariant);');
      Code.Add('      TUgWebRunFrame(F.RunFrame).SetValue(''vReMark'', cdsMain.FieldByName(''ReMark'').AsVariant);');
      Code.Add('    end;');
      Code.Add('    //校验失败时保留同一个编辑窗体和用户输入，允许修改后重试');
      Code.Add('    RetryEditor := True;');
      Code.Add('    EditorError := '''';');
      Code.Add('    while RetryEditor do');
      Code.Add('    begin');
      Code.Add('      if EditorError <> '''' then');
      Code.Add('        WaitEditorError(EditorError);');
      Code.Add('      EditorError := '''';');
      Code.Add('      RetryEditor := False;');
      Code.Add('      F.ModalResult := 0;');
      Code.Add('      if F.ShowModal = mrOk then');
      Code.Add('      try');
      Code.Add('        //读取子窗体回传值并执行校验');
      Code.Add('        NewName := TUgWebRunFrame(F.RunFrame).GetValue(''vName'');');
      Code.Add('        NewRemark := TUgWebRunFrame(F.RunFrame).GetValue(''vReMark'');');
      Code.Add('        ValidateUnitRecord(IsNew, NewName, NewRemark);');
      Code.Add('        if IsNew then'); Code.Add('        begin');
      Code.Add('          cdsMain.FieldByName(''ID'').ReadOnly := False;');
      Code.Add('          cdsMain.FieldByName(''ID'').Required := False;'); Code.Add('        end;');
      Code.Add('        //只暂存到主数据集，点击保存后才提交数据库');
      Code.Add('        if IsNew then cdsMain.Append else cdsMain.Edit;');
      Code.Add('        try');
      Code.Add('          if IsNew then cdsMain.FieldByName(''ID'').AsVariant := Null;');
      Code.Add('          cdsMain.FieldByName(''Name'').AsVariant := NewName;');
      Code.Add('          cdsMain.FieldByName(''ReMark'').AsVariant := NewRemark;');
      for I := 0 to 5 do
        if AuditFields[I] <> '' then
        begin
          Field := 'cdsMain.FieldByName(' + QuotedStr(AuditFields[I]) + ')';
          if I < 3 then Code.Add('          if ' + Field + '.IsNull then');
          case I mod 3 of
            0: Value := '.AsString := UGMM.Informations.Values[''UserName''];';
            1: Value := '.AsString := UGMM.Informations.Values[''ClassName''];';
            2: Value := '.AsDateTime := Now;';
          end;
          Code.Add('            ' + Field + Value);
        end;
      Code.Add('          cdsMain.Post;');
      Code.Add('        except');
      Code.Add('          cdsMain.Cancel;');
      Code.Add('          RaiseException(ExceptionMessage);');
      Code.Add('        end;');
      Code.Add('      except');
      Code.Add('        RetryEditor := True;');
      Code.Add('        EditorError := ExceptionMessage;');
      Code.Add('      end;');
      Code.Add('    end;');
      Code.Add('  finally');
      Code.Add('    UGMM.DelWebSubForm(' + QuotedStr(S(Settings, '编辑窗体')) + ');');
      Code.Add('  end;'); Code.Add('end;');
      end;
      AddCodeSection('新增');
      Code.Add('procedure btAppendOnClick(Sender: TObject);');
      Code.Add('begin');
      Code.Add('  try');
      Code.Add('    EditUnitRecord(True);');
      Code.Add('  finally');
      Code.Add('    RefreshToolbar;');
      Code.Add('  end;');
      Code.Add('end;');
      AddCodeSection('修改');
      Code.Add('procedure btEditorOnClick(Sender: TObject);');
      Code.Add('begin');
      Code.Add('  try');
      Code.Add('    EditUnitRecord(False);');
      Code.Add('  finally');
      Code.Add('    RefreshToolbar;');
      Code.Add('  end;');
      Code.Add('end;');
      AddCodeSection('删除');
      Code.Add('procedure btDeleteOnClick(Sender: TObject);');
      Code.Add('var DeleteCount, SavedRow: Integer; PreviousData: Variant;');
      Code.Add('begin');
      Code.Add('  if not cdsMain.Active then RaiseException(' + QuotedStr('请先查询数据。') + ');');
      Code.Add('  if cdsMain.IsEmpty then RaiseException(' + QuotedStr('没有可删除的记录。') + ');');
      Code.Add('  DeleteCount := 1;');
      if Yes(S(Settings,'表格多选')) then
        Code.Add('  if gridMain.SelectedRows.Count > 0 then DeleteCount := gridMain.SelectedRows.Count;');
      Code.Add('  if not ConfirmAction(UGMM.LT(''是否暂存删除选中的 '') + IntToStr(DeleteCount)');
      Code.Add('    + UGMM.LT('' 条记录？点击保存后才会从数据库删除。'')) then Exit;');
      Code.Add('  PreviousData := cdsMain.Data;');
      Code.Add('  SavedRow := cdsMain.RecNo;');
      Code.Add('  cdsMain.DisableControls;');
      Code.Add('  try');
      Code.Add('    try');
      if Yes(S(Settings,'表格多选')) then begin
        Code.Add('      if gridMain.SelectedRows.Count > 0 then gridMain.SelectedRows.Delete');
        Code.Add('      else cdsMain.Delete;');
      end else Code.Add('      cdsMain.Delete;');
      Code.Add('    except');
      Code.Add('      cdsMain.Data := PreviousData;');
      Code.Add('      if (SavedRow > 0) and (SavedRow <= cdsMain.RecordCount) then cdsMain.RecNo := SavedRow;');
      Code.Add('      RaiseException(ExceptionMessage);');
      Code.Add('    end;');
      Code.Add('  finally');
      Code.Add('    cdsMain.EnableControls;');
      Code.Add('    RefreshToolbar;');
      Code.Add('  end;'); Code.Add('end;');
      AddCodeSection('校验并提交主表修改');
      AddMultiplePageLocator(Code,AliasName,RecordKey,QueryFields.Count,FilterFields.Count,Ops);
      Code.Add('procedure SaveMainChanges(Sender: TObject);');
      Code.Add('var SavedRow, SavedPage, SearchPage: Integer;');
      Code.Add('  SavedKey, SavedData: Variant; Found: Boolean;');
      Code.Add('begin');
      Code.Add('  if not cdsMain.Active then Exit;');
      Code.Add('  if cdsMain.ChangeCount = 0 then Exit;');
      if Tables.Count>1 then Code.Add('  CheckMultipleJoin;');
      if GenericWrite and ((RequiredFields.Count>0) or (UniqueFields.Count>0)) then
        Code.Add('  ValidateGenericRows;');
      if not GenericWrite then begin
      Code.Add('  //提交前逐条复核所有修改记录');
      Code.Add('  SavedRow := cdsMain.RecNo;');
      Code.Add('  cdsMain.DisableControls;');
      Code.Add('  try');Code.Add('    cdsMain.First;');Code.Add('    while not cdsMain.Eof do');Code.Add('    begin');
      if not GenericWrite then begin
        Code.Add('      if cdsMain.UpdateStatus <> usUnmodified then');
        Code.Add('        ValidateUnitRecord(False, cdsMain.FieldByName(''Name'').AsVariant, cdsMain.FieldByName(''ReMark'').AsVariant);');
      end;
      Code.Add('      cdsMain.Next;');Code.Add('    end;');Code.Add('  finally');
      Code.Add('    if SavedRow > 0 then cdsMain.RecNo := SavedRow;');
      Code.Add('    cdsMain.EnableControls;');
      Code.Add('  end;');
      end else Code.Add('  //数据库约束在提交时最终校验；失败仍保留待保存数据');
      Code.Add('  //保留当前页和完整暂存包；提交失败时撤回自增字段的临时回填');
      Code.Add('  SavedPage := cdsMain.PageIndex;');
      Code.Add('  SavedRow := cdsMain.RecNo;');
      Code.Add('  SavedData := cdsMain.Data;');
      Code.Add('  try');
      Code.Add('    cdsMain.SubmitUpdates;');
      Code.Add('  except');
      Code.Add('    cdsMain.Data := SavedData;');
      Code.Add('    if (SavedRow > 0) and (SavedRow <= cdsMain.RecordCount) then cdsMain.RecNo := SavedRow;');
      Code.Add('    RaiseException(ExceptionMessage);');
      Code.Add('  end;');
      Code.Add('  //保存成功后重新查询并同步分页状态');
      Code.Add('  try');
      Code.Add('    cdsMain.DisableControls;');
      Code.Add('    try');
      Code.Add('    //使用提交回填的真实主键；不使用最大编号推测新增记录');
      Code.Add('    SavedKey := Null;');
      Code.Add('    if not cdsMain.IsEmpty then SavedKey := cdsMain.FieldByName('+QuotedStr(RecordKey)+').AsVariant;');
      Code.Add('    PagingStarted := UGMM.GetTickCount;');
      Code.Add('    cdsMain.Close;'); Code.Add('    cdsMain.ClearPageInformation;'); Code.Add('    cdsMain.Open;');
      Code.Add('    //保持查询及权限条件，先恢复原页，再跨页查找目标主键');
      Code.Add('    if SavedPage > cdsMain.PageCount then SavedPage := cdsMain.PageCount;');
      Code.Add('    if SavedPage < 1 then SavedPage := 1;');
      Code.Add('    if (SavedPage > 1) and (SavedPage <= cdsMain.PageCount) then cdsMain.PageIndex := SavedPage;');
      Code.Add('    Found := False;');
      Code.Add('    if SavedKey <> Null then');
      Code.Add('    begin');
      Code.Add('      Found := cdsMain.Locate('+QuotedStr(RecordKey)+', SavedKey, 0);');
      Code.Add('      SearchPage := -1;');
      Code.Add('      if not Found then SearchPage := FindSavedRecordPage(SavedKey);');
      Code.Add('      if (not Found) and (SearchPage > 0) then');
      Code.Add('      begin');
      Code.Add('        if SearchPage <= cdsMain.PageCount then');
      Code.Add('        begin');
      Code.Add('          cdsMain.PageIndex := SearchPage;');
      Code.Add('          Found := cdsMain.Locate('+QuotedStr(RecordKey)+', SavedKey, 0);');
      Code.Add('        end;');
      Code.Add('      end;');
      Code.Add('      //手工改变查询排序的脚本仍使用兼容查找；标准查询不扫描所有页');
      Code.Add('      if SearchPage = -1 then');
      Code.Add('      begin');
      Code.Add('      SearchPage := 1;');
      Code.Add('      while (not Found) and (SearchPage <= cdsMain.PageCount) do');
      Code.Add('      begin');
      Code.Add('        if SearchPage <> SavedPage then');
      Code.Add('        begin');
      Code.Add('          cdsMain.PageIndex := SearchPage;');
      Code.Add('          Found := cdsMain.Locate('+QuotedStr(RecordKey)+', SavedKey, 0);');
      Code.Add('        end;');
      Code.Add('        Inc(SearchPage);');
      Code.Add('      end;');
      Code.Add('      end;');
      Code.Add('      if (not Found) and (SavedPage <= cdsMain.PageCount) then cdsMain.PageIndex := SavedPage;');
      Code.Add('    end;');
      Code.Add('    capPage.Caption := IntToStr(cdsMain.PageIndex) + '' / '' + IntToStr(cdsMain.PageCount);');
      Code.Add('    SyncPaging;');
      Code.Add('    btPrior.Enabled := cdsMain.Active and (cdsMain.PageIndex > 1);');
      Code.Add('    btNext.Enabled := cdsMain.Active and (cdsMain.PageIndex < cdsMain.PageCount);');
      Code.Add('    finally');
      Code.Add('      cdsMain.EnableControls;');
      Code.Add('    end;');
      Code.Add('  except');
      Code.Add('    RaiseException(' + QuotedStr('数据已保存，但重新查询失败，请勿重复新增：') + ' + ExceptionMessage);');
      Code.Add('  end;');
      Code.Add('  if (SavedKey <> Null) and (not Found) then');
      Code.Add('    ShowMessage('+QuotedStr('数据已保存成功，但当前查询条件或权限范围内未找到目标记录。')+')');
      Code.Add('  else if SavedKey = Null then');
      Code.Add('    ShowMessage('+QuotedStr('数据已保存成功，未取得目标主键，已刷新列表。')+')');
      Code.Add('  else ShowMessage(' + QuotedStr('数据保存成功。') + ');'); Code.Add('end;');
      AddCodeSection('保存');
      Code.Add('procedure btSaveOnClick(Sender: TObject);');
      Code.Add('begin');
      Code.Add('  try');
      Code.Add('    SaveMainChanges(Sender);');
      Code.Add('  finally');
      Code.Add('    RefreshToolbar;');
      Code.Add('  end;');
      Code.Add('end;');
      AddCodeSection('撤销全部未保存修改');
      Code.Add('procedure btCancelOnClick(Sender: TObject);'); Code.Add('begin');
      Code.Add('  if not cdsMain.Active then Exit;');
      Code.Add('  if cdsMain.ChangeCount = 0 then Exit;');
      Code.Add('  if not ConfirmAction(' + QuotedStr('是否撤销全部未保存修改？') + ') then Exit;');
      Code.Add('  cdsMain.CancelUpdates;'); Code.Add('  RefreshToolbar;'); Code.Add('end;');
    end;
    if (Buttons.IndexOf('btImport') >= 0) and GenericWrite then begin
      for Field in EditFields do ImportCaptions.Add(Captions[Fields.IndexOf(Field)]);
      AddMultipleRecordImport(Code,EditFields,ImportCaptions,RecordKey,AuditFields,
        not SameText(AutoType,'DBAutoincrement'),(RequiredFields.Count>0) or (UniqueFields.Count>0),Tables.Count>1);
    end;
    if (Buttons.IndexOf('btImport') >= 0) and not GenericWrite then
    begin
      AddCodeSection('校验文本数据并暂存导入记录');
      Code.Add('procedure ImportUnitText(const AText: string);');
      Code.Add('var Rows: TStringList; RowIndex, TabIndex, Imported, SavedRow: Integer; RowText, NewName, NewRemark, Failure: string;');
      Code.Add('begin');
      Code.Add('  CheckNoPendingChanges;');
      Code.Add('  if not cdsMain.Active then RaiseException(' + QuotedStr('请先查询数据。') + ');');
      Code.Add('  if Trim(AText) = '''' then RaiseException(' + QuotedStr('请粘贴 Name、ReMark 两列数据，不含表头。') + ');');
      Code.Add('  Rows := TStringList.Create;');
      Code.Add('  try');
      Code.Add('    Rows.Text := AText;');
      Code.Add('    if Rows.Count > 500 then RaiseException(' + QuotedStr('每批最多导入 500 行。') + ');');
      Code.Add('    SavedRow := cdsMain.RecNo; Imported := 0; RowIndex := 0;');
      Code.Add('    cdsMain.DisableControls;');
      Code.Add('    try');
      Code.Add('      try');
      Code.Add('        for RowIndex := 0 to Rows.Count - 1 do');
      Code.Add('        begin');
      Code.Add('          RowText := Rows.Strings[RowIndex];');
      Code.Add('          if (Trim(RowText) <> '''') or (Pos(Chr(9), RowText) > 0) then');
      Code.Add('          begin');
      Code.Add('            TabIndex := Pos(Chr(9), RowText);');
      Code.Add('            if TabIndex = 0 then RaiseException(' + QuotedStr('需要两列，以制表符分隔；备注可为空。') + ');');
      Code.Add('            NewName := Copy(RowText, 1, TabIndex - 1);');
      Code.Add('            NewRemark := Copy(RowText, TabIndex + 1, Length(RowText));');
      Code.Add('            if Pos(Chr(9), NewRemark) > 0 then RaiseException(' + QuotedStr('只能导入 Name、ReMark 两列。') + ');');
      Code.Add('            if (UpperCase(Trim(NewName)) = ''NAME'') and (UpperCase(Trim(NewRemark)) = ''REMARK'') then');
      Code.Add('              RaiseException(' + QuotedStr('请去掉 Name、ReMark 表头。') + ');');
      Code.Add('            if (cdsMain.FieldByName(''Name'').Size > 0) and (Length(NewName) > cdsMain.FieldByName(''Name'').Size) then');
      Code.Add('              RaiseException(' + QuotedStr('Name 超出字段长度。') + ');');
      Code.Add('            if (cdsMain.FieldByName(''ReMark'').Size > 0) and (Length(NewRemark) > cdsMain.FieldByName(''ReMark'').Size) then');
      Code.Add('              RaiseException(' + QuotedStr('ReMark 超出字段长度。') + ');');
      Code.Add('            ValidateUnitRecord(True, NewName, NewRemark);');
      Code.Add('            cdsMain.FieldByName(''ID'').ReadOnly := False;');
      Code.Add('            cdsMain.FieldByName(''ID'').Required := False;');
      Code.Add('            cdsMain.Append;');
      Code.Add('            cdsMain.FieldByName(''ID'').AsVariant := Null;');
      Code.Add('            cdsMain.FieldByName(''Name'').AsString := NewName;');
      Code.Add('            cdsMain.FieldByName(''ReMark'').AsString := NewRemark;');
      for I := 0 to 5 do
        if AuditFields[I] <> '' then
        begin
          Field := 'cdsMain.FieldByName(' + QuotedStr(AuditFields[I]) + ')';
          case I mod 3 of
            0: Value := '.AsString := UGMM.Informations.Values[''UserName''];';
            1: Value := '.AsString := UGMM.Informations.Values[''ClassName''];';
            2: Value := '.AsDateTime := Now;';
          end;
          Code.Add('            ' + Field + Value);
        end;
      Code.Add('            cdsMain.Post;');
      Code.Add('            Imported := Imported + 1;');
      Code.Add('          end;');
      Code.Add('        end;');
      Code.Add('      except');
      Code.Add('        Failure := ExceptionMessage;');
      Code.Add('        cdsMain.Cancel; cdsMain.CancelUpdates;');
      Code.Add('        if SavedRow > 0 then cdsMain.RecNo := SavedRow;');
      Code.Add('        RaiseException(' + QuotedStr('导入第 ') + ' + IntToStr(RowIndex + 1) + ' + QuotedStr(' 行失败，本批已回退：') + ' + Failure);');
      Code.Add('      end;');
      Code.Add('    finally');
      Code.Add('      cdsMain.EnableControls;');
      Code.Add('    end;');
      Code.Add('    ShowMessage(' + QuotedStr('已暂存导入 ') + ' + IntToStr(Imported) + ' + QuotedStr(' 条。请点击保存写入数据库，或撤销本批导入。') + ');');
      Code.Add('  finally');
      Code.Add('    Rows.Free;');
      Code.Add('    RefreshToolbar;');
      Code.Add('  end;');
      Code.Add('end;');
    end;
    if SameText(SortMode, 'ColumnSort') or SameText(SortMode, 'MultiColumnSort') then
    begin
      AddCodeSection('设置当前页数据排序');
      Code.Add('procedure SortLoadedPage(const Fields, DescFields: string);');
      Code.Add('begin');
      Code.Add('  if not cdsMain.Active then Exit;');
      Code.Add('  cdsMain.IndexName := '''';');
      Code.Add('  cdsMain.IndexDefs.Update;');
      Code.Add('  if cdsMain.IndexDefs.IndexOf(''UgMultipleSort'') >= 0 then cdsMain.DeleteIndex(''UgMultipleSort'');');
      Code.Add('  if Fields <> '''' then');
      Code.Add('  begin');
      Code.Add('    cdsMain.AddIndex(''UgMultipleSort'', Fields, 0, DescFields, '''', 0);');
      Code.Add('    cdsMain.IndexName := ''UgMultipleSort'';');
      Code.Add('  end;');
      Code.Add('  cdsMain.First;'); Code.Add('end;');
      if SameText(SortMode, 'ColumnSort') then
      begin
        AddCodeSection('主表单列排序');
        Code.Add('procedure gridMainOnColumnSort(Column: TUniDBGridColumn; Direction: Boolean);');
        Code.Add('begin');
        Code.Add('  if Direction then SortLoadedPage(Column.FieldName, Column.FieldName)');
        Code.Add('  else SortLoadedPage(Column.FieldName, '''');'); Code.Add('end;');
      end
      else
      begin
        AddCodeSection('主表多列排序');
        Code.Add('procedure gridMainOnMultiColumnSort(Columns: TUniDBGridColumnArr; Directions: TUniSortDirections);');
        Code.Add('begin'); Code.Add('  SortLoadedPage(Columns, Directions);'); Code.Add('end;');
      end;
    end;
    AddCodeSection('更新分页栏和工具栏状态');
    Code.Add('procedure UpdatePage;'); Code.Add('begin');
    Code.Add('  SyncPaging;');
    Code.Add('  capPage.Caption := IntToStr(cdsMain.PageIndex) + '' / '' + IntToStr(cdsMain.PageCount);');
    Code.Add('  btPrior.Enabled := cdsMain.Active and (cdsMain.PageIndex > 1);');
    Code.Add('  btNext.Enabled := cdsMain.Active and (cdsMain.PageIndex < cdsMain.PageCount);');
    Code.Add('  RefreshToolbar;');
    Code.Add('end;');
    AddCodeSection('查询主表数据');
    if ReportPlan<>nil then ReportPlan.AddDrillCode(Code);
    if Ops.IndexOf('in')>=0 then AddMultipleInHelpers(Code);
    Code.Add('procedure btQueryLoad(Sender: TObject);'); Code.Add('var SQL: string;');
    if IndependentIndex>=0 then Code.Add('  IndependentQuery: Boolean;');
    if Ops.IndexOf('in')>=0 then Code.Add('  InValues: TStringList; ParameterCount: Integer;');
    Code.Add('begin');
    if WriteMode then Code.Add('  CheckNoPendingChanges;');
    if WriteMode and (Tables.Count>1) then Code.Add('  CheckMultipleJoin;');
    if (ReportPlan<>nil) and ReportPlan.HasDrilldown then begin
      Code.Add('  ReportReady := False;');
      Code.Add('  cdsReportDetail.Close; cdsReportSnapshot.Close;');
      if ReportPlan.Filtering then Code.Add('  cdsReportDetailSource.CommandText := '''';');
      Code.Add('  reportPages.ActivePage := reportSummaryPage;');
      Code.Add('  SyncReportDetail;');
    end;
    if IndependentIndex>=0 then begin
      Code.Add('  //独立条件有值时优先使用；为空时恢复普通查询条件');
      QueryControl := QueryControls[IndependentIndex];
      if (QueryControl.Kind='edit') or (QueryControl.Kind='memo') then
        Code.Add('  IndependentQuery := Trim(VarToStr('+QueryControl.Name+'.Text)) <> '''';')
      else Code.Add('  IndependentQuery := '+QueryControl.Present+';');
    end;
    if Ops.IndexOf('in')>=0 then begin
      Code.Add('  InValues := TStringList.Create;');
      Code.Add('  try');
      Code.Add('    ParameterCount := 0;');
    end;
    Code.Add('  PagingStarted := UGMM.GetTickCount;');
    Code.Add('  //组合基础SQL、查询条件、表格过滤和层级权限');
    for I:=0 to QueryControls.Count-1 do if QueryControls[I].Kind = 'time' then begin
      Value := '';
      if (IndependentIndex>=0) and (I<>IndependentIndex) then Value := '(not IndependentQuery) and ';
      Code.Add('  if '+Value+'(' + QueryControls[I].Name + 'TimeValue.Text = ''invalid'') then ' +
        'RaiseException(UGMM.LT(''请输入有效时间。''));');
    end;
    Code.Add('  SQL := ' + QuotedStr(SQL) + ';');
    for I := 0 to QueryFields.Count - 1 do begin
      if IndependentIndex>=0 then begin
        if I=IndependentIndex then Code.Add('  if IndependentQuery then')
        else Code.Add('  if not IndependentQuery then');
        Code.Add('  begin');
      end;
      if Ops[I]='in' then
        Code.Add('  AppendInQuery(SQL, '+QuotedStr(SourceFields[Fields.IndexOf(QueryFields[I])])+', '+QuotedStr('p'+IntToStr(I))+', VarToStr('+QueryControls[I].Name+'.Text), InValues, ParameterCount);')
      else begin
        Code.Add('  if ' + QueryControls[I].Present + ' then SQL := SQL + ' + QuotedStr(' and ' + SourceFields[Fields.IndexOf(QueryFields[I])] + ' ' + Ops[I] + ' :p' + IntToStr(I)) + ';');
        if Ops.IndexOf('in')>=0 then Code.Add('  if '+QueryControls[I].Present+' then Inc(ParameterCount);');
      end;
      if IndependentIndex>=0 then Code.Add('  end;');
    end;
    for I := 0 to FilterFields.Count - 1 do begin
      Code.Add('  if VarToStr(filter' + IntToStr(I) + '.Text) <> '''' then SQL := SQL + ' + QuotedStr(' and ' + SourceFields[Fields.IndexOf(FilterFields[I])] + ' like :gf' + IntToStr(I)) + ';');
      if Ops.IndexOf('in')>=0 then Code.Add('  if VarToStr(filter'+IntToStr(I)+'.Text) <> '''' then Inc(ParameterCount);');
    end;
    if Ops.IndexOf('in')>=0 then begin
      Code.Add('  if ParameterCount > 900 then');
      Code.Add('    RaiseException(UGMM.LT(''查询参数超过 900 个，请减少输入值后重试。''));');
    end;
    if Yes(S(Settings, '层级权限')) then
      Code.Add('  SQL := SQL + ' + QuotedStr(' and ' + AliasName + '.' + AuditFields[1] + ' in ') + ' + GetSubClassName;');
    if WriteMode then begin
      Code.Add('  //使用记录键稳定排序，使分页与保存定位保持同一顺序');
      Code.Add('  SQL := SQL + '+QuotedStr(' order by '+AliasName+'.'+RecordKey)+';');
    end;
    if ReportPlan<>nil then ReportPlan.AddQuery(Code);
    Code.Add('  cdsMain.Close;'); Code.Add('  cdsMain.CommandText := SQL;');
    Code.Add('  //使用参数传递用户输入');
    for I := 0 to QueryFields.Count - 1 do
    begin
      if Ops[I]='in' then Continue;
      Value := '';
      if IndependentIndex>=0 then
        if I=IndependentIndex then Value := 'IndependentQuery and '
        else Value := '(not IndependentQuery) and ';
      Code.Add('  if '+Value+'(' + QueryControls[I].Present + ') then');
      Code.Add('    cdsMain.ParamByName(''p' + IntToStr(I) + ''').' + QueryControls[I].ParameterValue(Ops[I]) + ';');
    end;
    for I := 0 to FilterFields.Count - 1 do
      Code.Add('  if VarToStr(filter' + IntToStr(I) + '.Text) <> '''' then cdsMain.ParamByName(''gf' + IntToStr(I) + ''').AsString := ''%'' + VarToStr(filter' + IntToStr(I) + '.Text) + ''%'';');
    if ReportPlan<>nil then ReportPlan.BindFilters(Code,False);
    if Ops.IndexOf('in')>=0 then Code.Add('  BindInQuery(InValues);');
    Code.Add('  //从第一页打开查询结果');
    Code.Add('  cdsMain.ClearPageInformation;'); Code.Add('  cdsMain.PageRowCount := StrToIntDef(cbLinesperPage.Text,50);'); Code.Add('  cdsMain.Open;');
    if (ReportPlan<>nil) and ReportPlan.HasDrilldown then begin
      Code.Add('  //仅成功查询后更新快照；保留条件参数类型及权限筛选 SQL');
      Code.Add('  PrepareReportParams(cdsReportSnapshot, cdsMain.Params, ReportPendingSQL);');
      Code.Add('  ReportReady := True;');
    end;
    Code.Add('  UpdatePage;');
    if Ops.IndexOf('in')>=0 then begin
      Code.Add('  finally'); Code.Add('    InValues.Free;'); Code.Add('  end;');
    end;
    Code.Add('end;');
    AddCodeSection('查询');
    Code.Add('procedure btQueryOnClick(Sender: TObject);');
    Code.Add('begin');
    Code.Add('  try');
    Code.Add('    btQueryLoad(Sender);');
    Code.Add('  finally');
    Code.Add('    RefreshToolbar;');
    Code.Add('  end;');
    Code.Add('end;');
    if LargeQuery then
    begin
      Code.Add('procedure btQueryOnAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);');
      Code.Add('begin');
      Code.Add('  if EventName <> ''queryWithTimes'' then Exit;');
      for QueryControl in QueryControls do if QueryControl.Kind = 'time' then
        Code.Add('  ' + QueryControl.Name + 'TimeValue.Text := Params.Values[''' + QueryControl.Name + '''];');
      Code.Add('  btQueryOnClick(Sender);'); Code.Add('end;');
      QueryEvents.Add('btQuery|<This>.OnAjaxEvent:btQueryOnAjaxEvent');
    end;
    if FilterFields.Count > 0 then
    begin
      AddCodeSection('主表列过滤');
      Code.Add('procedure gridMainOnColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);');
      Code.Add('begin'); Code.Add('  btQueryOnClick(Sender);'); Code.Add('end;');
      AddCodeSection('清除主表过滤条件');
      Code.Add('procedure gridMainOnClearFilters(Sender: TObject);'); Code.Add('begin');
      for I := 0 to FilterFields.Count - 1 do Code.Add('  filter' + IntToStr(I) + '.Text := '''';');
      Code.Add('  btQueryOnClick(Sender);'); Code.Add('end;');
    end;
    if ReportMode and Yes(S(Settings,'表格过滤')) then begin
      Code.Add('//汇总过滤在聚合之后执行，保留原查询和权限条件');
      Code.Add('procedure gridMainOnColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);');
      Code.Add('begin btQueryOnClick(Sender); end;');
      Code.Add('procedure gridMainOnClearFilters(Sender: TObject);');
      Code.Add('begin');
      // Output aliases differ from raw fields; emit resets from editor names.
      ReportPlan.ApplyColumns(EditFields,ImportCaptions);
      for Field in EditFields do Code.Add('  '+ReportPlan.FilterEditor(Field,False)+'.Text := '''';');
      Code.Add('  btQueryOnClick(Sender);'); Code.Add('end;');
    end;
    AddCodeSection('上一页');
    Code.Add('procedure btPriorOnClick(Sender: TObject);'); Code.Add('begin');
    if WriteMode then Code.Add('  CheckNoPendingChanges;');
    Code.Add('  PagingStarted := UGMM.GetTickCount;');
    Code.Add('  if cdsMain.Active and (cdsMain.PageIndex > 1) then cdsMain.PageIndex := cdsMain.PageIndex - 1;');
    Code.Add('  UpdatePage;'); Code.Add('end;');
    AddCodeSection('下一页');
    Code.Add('procedure btNextOnClick(Sender: TObject);'); Code.Add('begin');
    if WriteMode then Code.Add('  CheckNoPendingChanges;');
    Code.Add('  PagingStarted := UGMM.GetTickCount;');
    Code.Add('  if cdsMain.Active and (cdsMain.PageIndex < cdsMain.PageCount) then cdsMain.PageIndex := cdsMain.PageIndex + 1;');
    Code.Add('  UpdatePage;'); Code.Add('end;');
    AddCodeSection('跳转到指定页');
    Code.Add('procedure GoToPage(Target: Integer);'); Code.Add('begin');
    Code.Add('  if PagingBusy then Exit;');
    Code.Add('  try');
    if WriteMode then Code.Add('    CheckNoPendingChanges;');
    Code.Add('    PagingStarted := UGMM.GetTickCount;');
    Code.Add('    if cdsMain.Active and (Target >= 1) and (Target <= cdsMain.PageCount) then cdsMain.PageIndex := Target;');
    Code.Add('  finally');
    Code.Add('    UpdatePage;');
    Code.Add('  end;');
    Code.Add('end;');
    AddCodeSection('第一页');
    Code.Add('procedure btFirstOnClick(Sender: TObject);');
    Code.Add('begin');
    Code.Add('  GoToPage(1);');
    Code.Add('end;');
    AddCodeSection('最后一页');
    Code.Add('procedure btLastOnClick(Sender: TObject);');
    Code.Add('begin');
    Code.Add('  GoToPage(cdsMain.PageCount);');
    Code.Add('end;');
    AddCodeSection('输入页码跳转');
    Code.Add('procedure edCurrentPageOnChange(Sender: TObject);');
    Code.Add('begin');
    Code.Add('  if PagingBusy then Exit;');
    Code.Add('  if StrToIntDef(edCurrentPage.Text,-1) = cdsMain.PageIndex then Exit;');
    Code.Add('  GoToPage(StrToIntDef(edCurrentPage.Text,-1));'); Code.Add('end;');
    AddCodeSection('设置每页行数');
    Code.Add('procedure cbLinesperPageOnChange(Sender: TObject);'); Code.Add('var Size: Integer;'); Code.Add('begin');
    Code.Add('  if PagingBusy then Exit;');
    Code.Add('  Size := StrToIntDef(cbLinesperPage.Text,50);');
    Code.Add('  if Size = cdsMain.PageRowCount then Exit;');
    Code.Add('  try');
    if WriteMode then Code.Add('    CheckNoPendingChanges;');
    Code.Add('    if (Size < 1) or (Size > 5000) then Exit;');
    Code.Add('    PagingStarted := UGMM.GetTickCount;');
    Code.Add('    if cdsMain.Active then');
    Code.Add('    begin');
    Code.Add('      cdsMain.Close; cdsMain.ClearPageInformation; cdsMain.PageRowCount := Size; cdsMain.Open;');
    Code.Add('    end else cdsMain.PageRowCount := Size;');
    Code.Add('  finally');
    Code.Add('    UpdatePage;');
    Code.Add('  end;');
    Code.Add('end;');
    if Buttons.IndexOf('btOK') >= 0 then
    begin
      AddCodeSection('确认');
      Code.Add('procedure btOkOnClick(Sender: TObject);'); Code.Add('begin');
      if Yes(S(Settings, '表格多选')) then
      begin
        Code.Add('  //多选查询窗体：必须勾选至少一条明细，确认后返回调用方');
        Code.Add('  if gridMain.SelectedRows.Count = 0 then');
        Code.Add('    RaiseException(UGMM.LT(''请先勾选要提交的明细。''));');
      end;
      Code.Add('  if Self.Parent is TUniForm then');
      Code.Add('  TUniForm(Self.Parent).ModalResult := mrOk;');
      Code.Add('end;');
    end;
    AddCodeSection('关闭');
    Code.Add('procedure btCloseOnClick(Sender: TObject);'); Code.Add('begin');
    if WriteMode then Code.Add('  CheckNoPendingChanges;');
    Code.Add('  if Self.Parent is TUniForm then TUniForm(Self.Parent).Close;');
    Code.Add('  if Self.Parent is TUniTabSheet then TUniTabSheet(Self.Parent).Close;'); Code.Add('end;');
    if Buttons.IndexOf('btExport') >= 0 then
    begin
      AddCodeSection('导出当前表格');
      Code.Add('procedure btExportOnClick(Sender: TObject);'); Code.Add('begin');
      if WriteMode then Code.Add('  CheckNoPendingChanges;');
      if (ReportPlan<>nil) and ReportPlan.HasDrilldown then begin
        Code.Add('  if reportPages.ActivePage = reportDetailPage then');
        Code.Add('  begin');
        Code.Add('    if not cdsReportDetail.Active then RaiseException(UGMM.LT(''请先双击统计列查询明细。''));');
        Code.Add('    UGMM.ExpExcel(gridReportDetail, Self.Caption, Self.Caption);');
        Code.Add('    Exit;'); Code.Add('  end;');
      end;
      Code.Add('  if not cdsMain.Active then RaiseException(' + QuotedStr('请先查询数据。') + ');');
      Code.Add('  UGMM.ExpExcel(gridMain, Self.Caption, Self.Caption);'); Code.Add('end;');
    end;
    if ReportMode and (Buttons.IndexOf('btAnnex')>=0) then begin
      AddCodeSection('模块级报表附件，与原版按模块 GUID 关联');
      Code.Add('procedure btAnnexOnClick(Sender: TObject);'); Code.Add('begin');
      Code.Add('  UGMM.OpenFileManager(Self.Guid, '''', 31457280, True);'); Code.Add('end;');
    end;
    if (Buttons.IndexOf('btImport') >= 0) and not GenericWrite then
    begin
      AddCodeSection('导入文本格式或电子表格');
      Code.Add('procedure pmImportUgMenuItemsOnClick(const ACaption: string);');
      Code.Add('var Rows: TStringList; A, B: string;'); Code.Add('begin');
      Code.Add('  CheckNoPendingChanges;');
      Code.Add('  if not cdsMain.Active then RaiseException(' + QuotedStr('请先查询数据。') + ');');
      Code.Add('  cdsUnitImport.Close;');
      Code.Add('  cdsUnitImport.FieldDefs.Clear;');
      Code.Add('  cdsUnitImport.FieldDefs.Add(''Name'', ftWideString, 4096, False);');
      Code.Add('  cdsUnitImport.FieldDefs.Add(''ReMark'', ftWideString, 4096, False);');
      Code.Add('  cdsUnitImport.CreateDataSet;');
      Code.Add('  Rows := TStringList.Create;'); Code.Add('  try');
      Code.Add('    if ACaption = UGMM.LT(' + QuotedStr('文本格式') + ') then');
      Code.Add('      UGMM.ImportText(gridUnitImport, ' + QuotedStr(Captions[Fields.IndexOf('Name')]+';'+Captions[Fields.IndexOf('ReMark')]+';') + ');');
      Code.Add('    if ACaption = UGMM.LT(' + QuotedStr('电子表格') + ') then');
      Code.Add('      UGMM.ImpExcel(gridUnitImport, Self.Caption, ' + QuotedStr(RequiredFields.DelimitedText) + ');');
      Code.Add('    cdsUnitImport.First;');
      Code.Add('    while not cdsUnitImport.Eof do'); Code.Add('    begin');
      Code.Add('      A := cdsUnitImport.FieldByName(''Name'').AsString; B := cdsUnitImport.FieldByName(''ReMark'').AsString;');
      Code.Add('      if (Pos(Chr(9), A+B)>0) or (Pos(Chr(10), A+B)>0) or (Pos(Chr(13), A+B)>0) then');
      Code.Add('        RaiseException(' + QuotedStr('暂不支持单元格内换行或Tab。') + ');');
      Code.Add('      Rows.Add(A + Chr(9) + B);');
      Code.Add('      cdsUnitImport.Next;');
      Code.Add('    end;');
      Code.Add('    if Rows.Count > 0 then ImportUnitText(Rows.Text);');
      Code.Add('  finally');
      Code.Add('    Rows.Free;');
      Code.Add('    cdsUnitImport.Close;');
      Code.Add('  end;');
      Code.Add('end;');
      AddCodeSection('默认打开文本导入');
      Code.Add('procedure btImportOnClick(Sender: TObject);'); Code.Add('begin');
      Code.Add('  pmImportUgMenuItemsOnClick(UGMM.LT(' + QuotedStr('文本格式') + '));'); Code.Add('end;');
    end;
    if GridPersonalization then
    begin
      AddCodeSection('保存与加载当前用户的表格列设置');
      Code.Add('function ReadIni(filename,Section,Ident:String;Const Default:String = ''''):String;');
      Code.Add('var');
      Code.Add('  i : TIniFile;');
      Code.Add('begin');
      Code.Add('  i := TIniFile.create(filename);');
      Code.Add('  try');
      Code.Add('    Result := i.readstring(Section,Ident,Default)');
      Code.Add('  finally');
      Code.Add('    i.Free;');
      Code.Add('  end;');
      Code.Add('end;');
      Code.Add('procedure WriteIni(filename,section,Ident,Values:String);');
      Code.Add('var');
      Code.Add('  i:TIniFile;');
      Code.Add('begin');
      Code.Add('  i:=TIniFile.Create(filename);');
      Code.Add('  try');
      Code.Add('    i.WriteString(section,Ident,Values);');
      Code.Add('  finally');
      Code.Add('    i.Free;');
      Code.Add('  end;');
      Code.Add('end;');
      Code.Add('procedure SaveGridUserSettings(aGrid : TUgDBGrid; aName:String);');
      Code.Add('var');
      Code.Add('  i : Integer;');
      Code.Add('  j : TJSONObject;');
      Code.Add('  v : TJSONArray;');
      Code.Add('  c : TJSONObject;');
      Code.Add('  s : String;');
      Code.Add('begin');
      Code.Add('  try');
      Code.Add('  j := TJSONObject.Create;');
      Code.Add('    v := TJSONArray.Create;');
      Code.Add('    j.AddPair(''name'',aName);');
      Code.Add('    j.AddPair(''date'',now);');
      Code.Add('    j.AddPair(''columns'',v);');
      Code.Add('    for i := 0 to aGrid.Columns.Count - 1 do');
      Code.Add('    begin');
      Code.Add('      c := TJSONObject.Create;');
      Code.Add('      v.AddJSONObject(c);');
      Code.Add('      c.AddPair(''index'',aGrid.Columns[i].index);');
      Code.Add('      c.AddPair(''fieldName'',aGrid.Columns[i].fieldName);');
      Code.Add('      c.AddPair(''titleCaption'',aGrid.Columns[i].Title.caption);');
      Code.Add('      c.AddPair(''visible'',aGrid.Columns[i].visible);');
      Code.Add('      c.AddPair(''width'',aGrid.Columns[i].width);');
      Code.Add('    end;');
      Code.Add('    s := ''..\UserSettings\'' + Self.Guid + ''\'';');
      Code.Add('    CheckDirectory(s);');
      Code.Add('    WriteIni(s + UGMM.Informations.Values[''UserName''] + ''.ini'', aGrid.ClassName, aName, j.ToString);');
      Code.Add('  finally');
      Code.Add('    j.Free;');
      Code.Add('  end;');
      Code.Add('end;');
      Code.Add('procedure LoadGridUserSettings(aGrid : TUgDBGrid; aName:String);');
      Code.Add('var');
      Code.Add('  s : string;');
      Code.Add('  i : Integer;');
      Code.Add('  j : TJSONObject;');
      Code.Add('  v : TJSONValue;');
      Code.Add('  a : TJSONArray;');
      Code.Add('  c : TUniBaseDBGridColumn;');
      Code.Add('begin');
      Code.Add('  s := ''..\UserSettings\'' + Self.Guid + ''\'' + UGMM.Informations.Values[''UserName''] + ''.ini'';');
      Code.Add('  if not FileExists(s) then');
      Code.Add('  exit;');
      Code.Add('  j := TJSONObject.Create;');
      Code.Add('  try');
      Code.Add('    v := j.ParseJSONValue(ReadIni(s, aGrid.ClassName, aName, ''{}''), false, false);');
      Code.Add('    if v.FindValue(''columns'') = nil then');
      Code.Add('    exit;');
      Code.Add('    a := TJSONArray(v.FindValue(''columns''));');
      Code.Add('    for i := 0 to a.Count - 1 do');
      Code.Add('    if (a.A[i].FindValue(''fieldName'') <> nil)');
      Code.Add('    and(aGrid.ColumnByName(a.A[i].FindValue(''fieldName'').Value) <> nil) then');
      Code.Add('    begin');
      Code.Add('      c         := aGrid.ColumnByName(a.A[i].FindValue(''fieldName'').Value);');
      Code.Add('      c.Index   := StrToIntDef(a.A[i].FindValue(''index'').Value, c.Index);');
      Code.Add('      c.Width   := StrToIntDef(a.A[i].FindValue(''width'').Value, c.Width);');
      Code.Add('      c.Visible := StrToBoolDef(a.A[i].FindValue(''visible'').Value, c.Visible);');
      Code.Add('    end;');
      Code.Add('  finally');
      Code.Add('    j.Free;');
      Code.Add('    v.Free;');
      Code.Add('  end;');
      Code.Add('end;');
      Code.Add('Procedure gridMainOnAjaxEvent(sender: tcomponent;eventname: string;params: tunistrings);');
      Code.Add('begin');
      Code.Add('  if eventname in [''columnhide'',''columnshow'',''columnresize'',''columnmove''] then');
      Code.Add('  SaveGridUserSettings(TUgDBGrid(sender), Sender.Name);');
      Code.Add('end;');
    end;
    if (not WriteMode) and (not ReportMode) then
    begin
      AddCodeSection('只读列表双击返回选中行');
      Code.Add('procedure gridMainOnDblClick(sender: tobject);');
      Code.Add('begin');
      Code.Add('  if cdsMain.IsEmpty then');
      Code.Add('  Exit;');
      if Yes(S(Settings, '表格多选')) then
      begin
        Code.Add('  //本窗体是“多选”查询窗体：双击只定位当前行，勾选后点“确认”提交并关闭');
        Code.Add('  Exit;');
      end;
      Code.Add('  if Self.Parent is TUniForm then');
      Code.Add('  TUniForm(Self.Parent).ModalResult := mrOk;');
      Code.Add('end;');
    end;
    AddCodeSection('运行脚本后初始化模块');
    Code.Add('procedure UgWebRunFrameOnAfterRunScript(const sender: tobject);');
    Code.Add('begin');
    Code.Add('  //数据集绑定节点库');
    Code.Add('  cdsMain.DataNodeName := cDataNodeName;');
    if (ReportPlan<>nil) and ReportPlan.HasDrilldown then
      Code.Add('  cdsReportDetail.DataNodeName := cDataNodeName;');
    Code.Add('  //翻译界面并验证模块权限');
    Code.Add('  UGMM.LC(Self);'); Code.Add('  UGMM.VerifyRunFramePerm(Self);');
    Code.AddStrings(QueryInit);
    if DefaultTrue(S(Settings, '表格复制')) then
    begin
      Code.Add('  //表格允许拖选文字并复制');
      Code.Add('  gridMain.ClientEvents.UniEvents.Values[''beforeInit''] := ''function beforeInit(sender, config){ config.viewConfig.enableTextSelection = true; }'';');
    end;
    if Buttons.IndexOf('btImport') >= 0 then
    begin
      Code.Add('  //导入按钮附加文本格式和电子表格菜单');
      Code.Add('  btImport.DropdownMenu := pmImport.PopupMenus;');
    end;
    if Buttons.IndexOf('btPrint') >= 0 then
    begin
      Code.Add('  //加载模块打印功能');
      Code.Add('  UGMM.AddReport(btPrint, UGMM.Informations.Values[''AllowLandingType''] <> ' + QuotedStr('系统用户;') + ', Self.Guid);');
    end;
    Code.Add('  //初始化分页按钮状态');
    Code.Add('  btPrior.Enabled := False;'); Code.Add('  btNext.Enabled := False;');
    Code.Add('  //按默认条件加载数据，复用查询入口的权限与异常提示');
    Code.Add('  if btQuery.Enabled then btQueryOnClick(Sender);');
    if GridPersonalization then
      Code.Add('  LoadGridUserSettings(gridMain, gridMain.Name);');
    Code.Add('end;');
    Code.Add('');
    { TUgWebRunFrame.LoadScript inserts Events before a standalone End. line. }
    Code.Add('begin');
    Code.Add('end.');
    if ReportPlan<>nil then ReportPlan.ApplyColumns(Fields,Captions);
    Lines.Add('object UgWebRunFrame: TUgWebRunFrame');
    if LargeQuery then Lines.Add('  Width = 1270') else Lines.Add('  Width = 900');
    Lines.Add('  Height = 650'); Lines.Add('  SyntaxType = ''PascalScript''');
    if LargeQuery then Lines.Add('  ClientEvents.UniEvents.Strings = (' +
      Q('beforeInit=function(sender,config){config.ugQueryRoot=true;}') + ')');
    Lines.Add('  Events.Strings = (');
    if ReportPlan<>nil then ReportPlan.AddDrillEvents(Lines);
    if ReportMode and Yes(S(Settings,'表格过滤')) then begin
      Lines.Add('    ''gridMain|<This>.OnColumnFilter:gridMainOnColumnFilter''');
      Lines.Add('    ''gridMain|<This>.OnClearFilters:gridMainOnClearFilters''');
    end;
    for Value in QueryEvents do Lines.Add('    ' + Q(Value));
    if Buttons.IndexOf('btImport') >= 0 then
    begin
      Lines.Add('    ''btImport|<This>.OnClick:btImportOnClick''');
      Lines.Add('    ''pmImport|<This>.UgMenuItemsOnClick:pmImportUgMenuItemsOnClick''');
    end;
    if Buttons.IndexOf('btExport') >= 0 then Lines.Add('    ''btExport|<This>.OnClick:btExportOnClick''');
    if ReportMode and (Buttons.IndexOf('btAnnex')>=0) then Lines.Add('    ''btAnnex|<This>.OnClick:btAnnexOnClick''');
    if WriteMode then
      for Key in TArray<string>.Create('btAppend','btEditor','btDelete','btSave','btCancel') do
        if Buttons.IndexOf(Key) >= 0 then Lines.Add('    ' + Q(Key + '|<This>.OnClick:' + Key + 'OnClick'));
    if FilterFields.Count > 0 then
    begin
      Lines.Add('    ''gridMain|<This>.OnColumnFilter:gridMainOnColumnFilter''');
      Lines.Add('    ''gridMain|<This>.OnClearFilters:gridMainOnClearFilters''');
    end;
    if SameText(SortMode, 'ColumnSort') then
      Lines.Add('    ''gridMain|<This>.OnColumnSort:gridMainOnColumnSort''');
    if SameText(SortMode, 'MultiColumnSort') then
      Lines.Add('    ''gridMain|<This>.OnMultiColumnSort:gridMainOnMultiColumnSort''');
    if (not WriteMode) and (not ReportMode) then
      Lines.Add('    ''gridMain|<This>.OnDblClick:gridMainOnDblClick''');
    if GridPersonalization then
      Lines.Add('    ''gridMain|<This>.OnAjaxEvent:gridMainOnAjaxEvent''');
    Lines.Add('    ''Self|<This>.OnAfterRunScript:UgWebRunFrameOnAfterRunScript''');
    if not LargeQuery then Lines.Add('    ''btQuery|<This>.OnClick:btQueryOnClick''');
    Lines.Add('    ''btPrior|<This>.OnClick:btPriorOnClick''');
    Lines.Add('    ''btFirst|<This>.OnClick:btFirstOnClick''');
    Lines.Add('    ''btLast|<This>.OnClick:btLastOnClick''');
    Lines.Add('    ''edCurrentPage|<This>.OnChange:edCurrentPageOnChange''');
    Lines.Add('    ''cbLinesperPage|<This>.OnChange:cbLinesperPageOnChange''');
    Lines.Add('    ''btNext|<This>.OnClick:btNextOnClick''');
    if Buttons.IndexOf('btOK') >= 0 then Lines.Add('    ''btOK|<This>.OnClick:btOkOnClick''');
    if Buttons.IndexOf('btClose') >= 0 then Lines.Add('    ''btClose|<This>.OnClick:btCloseOnClick''');
    Lines.Add('  )'); Lines.Add('  Codes.Strings = (');
    for Value in Code do Lines.Add('    ' + Q(Value)); Lines.Add('  )');
    ToolbarHeight := 33;
    Lines.Add('  object pButtons: TUgContainerPanel'); Lines.Add('    Align = alTop'); Lines.Add('    Height = ' + IntToStr(ToolbarHeight));
    AddButton('btQuery', '查询', 'btQueryOnClick', 8);
    if LargeQuery then
    begin
      QueryJS := 'click=function(sender){var root=sender.up(''[ugQueryRoot]''),c,r,v,p=[];if(!root)return false;';
      QueryJS := QueryJS + 'var fields=root.query("[ugQueryField]"),i;' +
        'for(i=0;i<fields.length;i++){c=fields[i];if(c.isValid&&!c.isValid()){c.focus();return false;}}';
      for QueryControl in QueryControls do if QueryControl.Kind = 'time' then
      begin
        QueryJS := QueryJS + 'c=root.down(''[ugQueryTime="' + QueryControl.Name + '"]'');if(!c)return false;' +
          'r=c.getRawValue();v=c.getValue();if(r!==""&&(!c.isValid()||!v)){c.focus();return false;}' +
          'p.push("' + QueryControl.Name + '="+encodeURIComponent(r===""?"":Ext.Date.format(v,"H:i:s")));';
      end;
      QueryJS := QueryJS + 'ajaxRequest(sender,"queryWithTimes",p);return false;}';
      Lines.Insert(Lines.Count - 1, '      ClientEvents.ExtEvents.Strings = (' + Q(QueryJS) + ')');
    end;
    Y := 116;
    if WriteMode then
    begin
      AddSeparator('tabEditorGroup');
      for Key in TArray<string>.Create('btAppend','btDelete','btEditor','btImport','btSave','btCancel') do
        if Buttons.IndexOf(Key) >= 0 then
        begin
          if Key = 'btSave' then AddSeparator('tabAppendUpdateGroup');
          if Key = 'btAppend' then Value := '新增'
          else if Key = 'btEditor' then Value := '修改'
          else if Key = 'btImport' then Value := '导入'
          else if Key = 'btDelete' then Value := '删除'
          else if Key = 'btSave' then Value := '保存' else Value := '撤销';
          AddButton(Key, Value, Key + 'OnClick', Y); Inc(Y,108);
        end;
    end;
    if Buttons.IndexOf('btOK') >= 0 then
    begin
      if (Buttons.IndexOf('btSave') < 0) and (Buttons.IndexOf('btCancel') < 0) then
        AddSeparator('tabAppendUpdateGroup');
      AddButton('btOK', '确认', 'btOkOnClick', Y);
      Inc(Y,108);
    end;
    if (Buttons.IndexOf('btExport') >= 0) or (Buttons.IndexOf('btPrint') >= 0) then AddSeparator('tabOutputGroup');
    if Buttons.IndexOf('btExport') >= 0 then begin AddButton('btExport', '导出', 'btExportOnClick', Y); Inc(Y,108); end;
    if Buttons.IndexOf('btPrint') >= 0 then begin AddButton('btPrint', '打印', '', Y); Inc(Y,108); end;
    if ReportMode and (Buttons.IndexOf('btAnnex')>=0) then begin AddSeparator('tabAnnexGroup'); AddButton('btAnnex','附件','btAnnexOnClick',Y); Inc(Y,108); end;
    if Buttons.IndexOf('btClose') >= 0 then begin AddSeparator('tabFormGroup'); AddButton('btClose', '关闭', 'btCloseOnClick', Y); end;
    Lines.Add('    object toolbarLine: TUgContainerPanel');
    Lines.Add('      Align = alBottom'); Lines.Add('      Height = 1');
    Lines.Add('      ParentColor = False'); Lines.Add('      Color = 13093060'); Lines.Add('    end');
    Lines.Add('  end');
    Lines.Add('  object pQuery: TUgContainerPanel'); Lines.Add('    Top = ' + IntToStr(ToolbarHeight));
    if LeftLayout then
    begin
      Lines.Add('    Align = alLeft'); Lines.Add('    Width = 220');
      if not SameText(S(Config, 'TWebListEditorLayout'), 'True') then
      begin
        Lines.Add('    AutoScroll = True'); Lines.Add('    ScrollDirection = sdVertical');
      end;
    end
    else Lines.Add('    Align = alTop');
    if SameText(S(Config, 'TWebListEditorLayout'), 'True') then
      Lines.Add('    Visible = False');
    Y := 10; LayoutY := 10; RowHeight := 0;
    for I := 0 to QueryControls.Count - 1 do
    begin
      if QueryControls[I].Kind = 'memo' then FieldHeight := 170 else FieldHeight := 50;
      if QueryControls[I].Kind = 'check' then Inc(FieldHeight, 22);
      if TopRowLayout then
      begin
        if (I > 0) and (I mod 3 = 0) then
        begin
          Inc(LayoutY, RowHeight + 10);
          RowHeight := 0;
        end;
        if FieldHeight > RowHeight then RowHeight := FieldHeight;
      end
      else
      begin
        if (not LeftLayout) and (I mod 3 = 0) then LayoutY := 10;
        Inc(LayoutY, FieldHeight + 10);
        if LayoutY > Y then Y := LayoutY;
      end;
    end;
    if TopRowLayout then Y := LayoutY + RowHeight + 10;
    if TopRowLayout then
    begin
      if Y < 70 then Y := 70;
    end
    else if (not LeftLayout) and (Y < 190) then Y := 190;
    if LeftLayout then Lines.Add('    Height = ' + IntToStr(650-ToolbarHeight))
    else Lines.Add('    Height = ' + IntToStr(Y));
    // 同窗列表将查询控件和边线拆分为独立子面板：收缩 pQuery 时整体释放空间，
    // 控件本身不再与分隔线争夺布局区域。
    if SameText(S(Config, 'TWebListEditorLayout'), 'True') then
    begin
      Lines.Add('    object pQueryContent: TUgContainerPanel');
      Lines.Add('      Align = alClient');
      if LeftLayout then begin
        Lines.Add('      AutoScroll = True'); Lines.Add('      ScrollDirection = sdVertical');
      end;
    end;
    LayoutY := 10; RowHeight := 0;
    for I := 0 to QueryFields.Count - 1 do
    begin
      if QueryControls[I].Kind = 'memo' then FieldHeight := 170 else FieldHeight := 50;
      if QueryControls[I].Kind = 'check' then Inc(FieldHeight, 22);
      if TopRowLayout then
      begin
        if (I > 0) and (I mod 3 = 0) then
        begin
          Inc(LayoutY, RowHeight + 10);
          RowHeight := 0;
        end;
        QueryControls[I].AddControl(Lines, 10 + (I mod 3) * 210, LayoutY, 200, FieldHeight, False, TextCase);
        if FieldHeight > RowHeight then RowHeight := FieldHeight;
      end
      else
      begin
        if (not LeftLayout) and (I mod 3 = 0) then LayoutY := 10;
        if LeftLayout then QueryControls[I].AddControl(Lines, 10, LayoutY, 200, FieldHeight, True, TextCase)
        else QueryControls[I].AddControl(Lines, 10 + (I div 3) * 210, LayoutY, 200, FieldHeight, False, TextCase);
        Inc(LayoutY, FieldHeight + 10);
      end;
    end;
    if SameText(S(Config, 'TWebListEditorLayout'), 'True') then Lines.Add('    end');
    if TopRowLayout then
    begin
      Lines.Add('    object pQueryDivider: TUgContainerPanel');
      Lines.Add('      Align = alBottom'); Lines.Add('      Height = 2');
      Lines.Add('      ParentColor = False'); Lines.Add('      Color = clSilver'); Lines.Add('    end');
    end
    else if not LeftLayout then
    begin
      Lines.Add('    object queryBottomLine: TUgContainerPanel');
      Lines.Add('      Align = alBottom'); Lines.Add('      Height = 1');
      Lines.Add('      ParentColor = False'); Lines.Add('      Color = 13093060'); Lines.Add('    end');
    end;
    if LeftLayout and SameText(S(Config, 'TWebListEditorLayout'), 'True') then
    begin
      Lines.Add('    object pQueryDivider: TUgContainerPanel');
      Lines.Add('      Align = alRight'); Lines.Add('      Width = 2');
      Lines.Add('      ParentColor = False'); Lines.Add('      Color = clSilver'); Lines.Add('    end');
    end;
    Lines.Add('  end');
    if Buttons.IndexOf('btImport') >= 0 then
    begin
      Lines.Add('  object pmImport: TUgPopupMenu'); Lines.Add('    Items = <');
      for Value in TArray<string>.Create('文本格式','电子表格') do
      begin Lines.Add('      item'); Lines.Add('        Caption = '+Q(Value)); Lines.Add('      end');end;
      Lines.Add('    >'); Lines.Add('  end');
      { A full DB grid needs a normal visual parent during DFM loading.
        Keep staging out of the layout without using a hidden editor host. }
      Lines.Add('  object pUnitImport: TUgContainerPanel');
      Lines.Add('    Width = 320'); Lines.Add('    Height = 120');
      Lines.Add('    Visible = False');
      Lines.Add('    object gridUnitImport: TUgDBGrid'); Lines.Add('      DataSource = dsUnitImport');
      Lines.Add('      Width = 300'); Lines.Add('      Height = 100');
      Lines.Add('      Visible = False');
      Lines.Add('      Columns = <');
      if not GenericWrite then begin
        EditFields.Clear; EditFields.Add('Name'); EditFields.Add('ReMark');
      end;
      for Key in EditFields do
      begin
        Lines.Add('        item'); Lines.Add('          FieldName = '+Q(Key));
        Lines.Add('          Title.Caption = '+Q(Captions[Fields.IndexOf(Key)])); Lines.Add('        end');
      end;
      Lines.Add('      >');
      Lines.Add('    end'); Lines.Add('  end');
      Lines.Add('  object cdsUnitImport: TUgClientDataSet');
      Lines.Add('    StoreDefs = True'); Lines.Add('    FieldDefs = <');
      for Key in EditFields do
      begin
        Lines.Add('      item'); Lines.Add('        Name = '+Q(Key));
        if GenericWrite then Lines.Add('        DataType = ftWideMemo')
        else begin Lines.Add('        DataType = ftWideString'); Lines.Add('        Size = 4096'); end;
        Lines.Add('      end');
      end;
      Lines.Add('    >'); Lines.Add('  end');
      Lines.Add('  object dsUnitImport: TUgDataSource'); Lines.Add('    DataSet = cdsUnitImport'); Lines.Add('  end');
    end;
    if LeftLayout then
    begin
      Lines.Add('  object pGridLayout: TUgContainerPanel');
      Lines.Add('    Left = 220'); Lines.Add('    Top = ' + IntToStr(ToolbarHeight));
      Lines.Add('    Width = 680'); Lines.Add('    Height = '+IntToStr(650-ToolbarHeight));
      Lines.Add('    Align = alClient');
    end;
    if (ReportPlan<>nil) and ReportPlan.HasDrilldown then begin
      Lines.Add('  object reportPages: TUgPageControl'); Lines.Add('    Align = alClient');
      Lines.Add('    ActivePage = reportSummaryPage');
      Lines.Add('    object reportSummaryPage: TUniTabSheet'); Lines.Add('      Caption = '+Q('汇总'));
    end;
    Lines.Add('  object pPages: TUgContainerPanel'); Lines.Add('    Align = alBottom'); Lines.Add('    Height = 32');
    AddPageButton('btFirst','<<',3); AddPageButton('btPrior','<',41);
    Lines.Add('    object edCurrentPage: TUgEdit');
    Lines.Add('      AlignWithMargins = True'); Lines.Add('      Align = alLeft');
    Lines.Add('      Left = 79'); Lines.Add('      Top = 3');
    Lines.Add('      Width = 75'); Lines.Add('      Height = 26');
    Lines.Add('      Text = ''1'''); Lines.Add('      Enabled = False'); Lines.Add('    end');
    AddPageButton('btNext','>',160); AddPageButton('btLast','>>',198);
    Lines.Add('    object cbLinesperPage: TUgComboBox');
    Lines.Add('      AlignWithMargins = True'); Lines.Add('      Align = alLeft');
    Lines.Add('      Left = 236'); Lines.Add('      Top = 3');
    Lines.Add('      Width = 75'); Lines.Add('      Height = 26');
    Lines.Add('      Style = csDropDownList'); Lines.Add('      Text = ''50''');
    Lines.Add('      Items.Strings = (');
    for Value in TArray<string>.Create('30','50','100','200','300','400','500','1000','2000','3000','4000','5000') do Lines.Add('        ' + Q(Value));
    Lines.Add('      )'); Lines.Add('      ItemIndex = 1'); Lines.Add('    end');
    Lines.Add('    object capPagingInfo: TUgLabel');
    Lines.Add('      AlignWithMargins = True'); Lines.Add('      Align = alLeft');
    Lines.Add('      Left = 317'); Lines.Add('      Top = 3'); Lines.Add('      Height = 26');
    Lines.Add('      Caption = ' + Q('共 ? 行, ? 页,每页 50 行,耗时:? ms')); Lines.Add('    end');
    Lines.Add('    object capPage: TUniLabel'); Lines.Add('      Left = 230'); Lines.Add('      Top = 9');
    Lines.Add('      Visible = False');
    Lines.Add('      Caption = ''- / -'''); Lines.Add('    end'); Lines.Add('  end');
    Lines.Add('  object gridMain: TUgDBGrid'); Lines.Add('    Align = alClient'); Lines.Add('    DataSource = dsMain');
    GridOptions := 'dgEditing, dgTitles, dgIndicator, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow';
    if Yes(S(Settings, '表格序号')) then GridOptions := GridOptions + ', dgRowNumbers';
    // 原版默认关闭表格多选：未勾选“表格多选”时不生成复选与多选。
    if Yes(S(Settings, '表格多选')) then GridOptions := GridOptions + ', dgCheckSelect, dgMultiSelect';
    if Yes(S(Settings, '字段宽度')) then GridOptions := GridOptions + ', dgColumnResize';
    if Yes(S(Settings, '字段移动')) then GridOptions := GridOptions + ', dgColumnMove';
    Lines.Add('    ReadOnly = True'); Lines.Add('    Options = [' + GridOptions + ']');
    Lines.Add('    LoadMask.Message = ''Loading data...''');
    Lines.Add('    StoreUserSettings = False');
    Lines.Add('    MultiColumnSort = ' + BoolToStr(SameText(SortMode, 'MultiColumnSort'), True));
    Lines.Add('    WebOptions.Paged = False'); Lines.Add('    Columns = <');
    for I := 0 to Fields.Count - 1 do
    begin
      Lines.Add('      item'); Lines.Add('        FieldName = ' + Q(Fields[I]));
      Lines.Add('        Title.Caption = ' + Q(Captions[I])); Lines.Add('        Width = 120');
      if ReportPlan<>nil then begin
        if ReportPlan.HeaderFor(Fields[I])<>'' then Lines.Add('        GroupHeader = '+Q(ReportPlan.HeaderFor(Fields[I])));
        if ReportPlan.Hidden(Fields[I]) then Lines.Add('        Visible = False');
        Value:=ReportPlan.FilterEditor(Fields[I],False);
        if Value<>'' then begin Lines.Add('        Filtering.Enabled = True'); Lines.Add('        Filtering.Editor = '+Value); end;
      end;
      Lines.Add('        Sortable = ' + BoolToStr(SameText(SortMode, 'ColumnSort') or SameText(SortMode, 'MultiColumnSort'), True));
      Lines.Add('        Menu.ColumnHideable = ' + BoolToStr(Yes(S(Settings, '字段显隐')), True));
      Y := FilterFields.IndexOf(Fields[I]);
      if Y >= 0 then
      begin
        Lines.Add('        Filtering.Enabled = True');
        Lines.Add('        Filtering.Editor = filter' + IntToStr(Y));
      end;
      if HiddenFields.IndexOf(Fields[I]) >= 0 then Lines.Add('        Visible = False');
      Lines.Add('        ReadOnly = True'); Lines.Add('      end');
    end;
    Lines.Add('    >'); Lines.Add('  end');
    if (ReportPlan<>nil) and ReportPlan.HasDrilldown then begin
      Lines.Add('    end');
      ReportPlan.AddDrillUI(Lines);
      Lines.Add('  end');
    end;
    if LeftLayout then Lines.Add('  end');
    if FilterFields.Count > 0 then
    begin
      Lines.Add('  object pFilterEditors: TUgHiddenPanel');
      for I := 0 to FilterFields.Count - 1 do
      begin
        Lines.Add('    object filter' + IntToStr(I) + ': TUgEdit');
        Lines.Add('      Text = '''''); Lines.Add('      CharEOL = #13');
        Lines.Add('      EmptyText = ' + Q('包含...')); Lines.Add('    end');
      end;
      Lines.Add('  end');
    end;
    if ReportPlan<>nil then ReportPlan.FilterEditors(Lines);
    Lines.Add('  object Imgs: TUGIconClsList');
    Lines.Add('    IconText = ' + Q('icon iconfont icon-chaxun'#13#10 +
      'icon iconfont icon-addEdge'#13#10 + 'icon iconfont icon-shanchu1'#13#10 +
      'icon iconfont icon-xiugai1'#13#10 + 'icon iconfont icon-ico_daoru_xuanzhong'#13#10 +
      'icon iconfont icon-baocun'#13#10 + 'icon iconfont icon-chexiao4'#13#10 +
      'icon iconfont icon-web-icon-'#13#10 + 'icon iconfont icon-dayin4'#13#10 +
      'icon iconfont icon-guanbi3'#13#10 + 'icon iconfont icon-xiangzuo'#13#10 +
      'icon iconfont icon-xiangyou'#13#10 + 'icon iconfont icon-gouxuan'#13#10));
    Lines.Add('  end');
    Lines.Add('  object cdsMain: TUgClientDataSet'); Lines.Add('    Active = False');
    if WriteMode then Lines.Add('    AutoUpdateRefresh = True');
    Lines.Add('    PageRowCount = 50'); Lines.Add('  end');
    if UniqueFields.Count > 0 then
    begin
      Lines.Add('  object cdsUnique: TUgClientDataSet'); Lines.Add('    Active = False'); Lines.Add('  end');
    end;
    Lines.Add('  object dsMain: TUgDataSource'); Lines.Add('    DataSet = cdsMain'); Lines.Add('  end');
    if (ReportPlan<>nil) and ReportPlan.HasDrilldown then begin
      Lines.Add('  object cdsReportSnapshot: TUgClientDataSet'); Lines.Add('    Active = False'); Lines.Add('  end');
      if Yes(S(Settings,'表格过滤')) then begin
        Lines.Add('  object cdsReportDetailSource: TUgClientDataSet'); Lines.Add('    Active = False'); Lines.Add('  end');
      end;
      Lines.Add('  object cdsReportDetail: TUgClientDataSet'); Lines.Add('    Active = False'); Lines.Add('    PageRowCount = 50'); Lines.Add('  end');
      Lines.Add('  object dsReportDetail: TUgDataSource'); Lines.Add('    DataSet = cdsReportDetail'); Lines.Add('  end');
    end;
    for I := 0 to QueryControls.Count - 1 do QueryControls[I].AddData(Lines, I);
    Lines.Add('end');
    ApplyMultiplePresentation(Code, Lines);
    DFM := Lines.Text; Result := True;
  finally
    ReportPlan.Free;
    SourceFields.Free; JoinAliases.Free;
    QueryInit.Free; QueryEvents.Free; QueryControls.Free;
    ImportCaptions.Free; EditFields.Free; UniqueFields.Free; RequiredFields.Free; FilterFields.Free; HiddenFields.Free; Lines.Free; Code.Free; Buttons.Free; Ops.Free; QueryCaptions.Free; QueryFields.Free; Captions.Free; Fields.Free;
  end;
end;
end.
