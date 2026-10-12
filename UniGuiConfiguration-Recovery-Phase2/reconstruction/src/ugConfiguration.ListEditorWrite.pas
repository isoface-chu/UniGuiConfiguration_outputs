unit ugConfiguration.ListEditorWrite;
interface
uses System.Classes, System.SysUtils, System.JSON, ugConfiguration.ListEditorDetail;
function AddListEditorWrite(Config:TJSONObject; Lines,Names,Captions:TStrings;
  Detail:TListEditorDetailPlan; out Reason:string):Boolean;

{ 工具栏重排（见实现里的说明）。模板在 AddListEditorPresentation 之后、写模式下调用。 }
procedure RelayoutListEditorToolbar(Config: TJSONObject; Lines: TStringList);
implementation
uses ugConfiguration.MultipleRecord, ugConfiguration.TreeScriptLayout, System.StrUtils;
function S(J:TJSONObject;const K:string):string;
var V:TJSONValue;
begin Result:='';if J=nil then Exit;V:=J.GetValue(K);if(V<>nil)and not(V is TJSONNull)then Result:=V.Value;end;
function O(J:TJSONObject;const K:string):TJSONObject;
var V:TJSONValue;
begin Result:=nil;if J=nil then Exit;V:=J.GetValue(K);if V is TJSONObject then Result:=TJSONObject(V);end;
function Selected(const V:string):Boolean;
begin Result:=SameText(V,'True')or(V='1')or(V='-1');end;
function Nested(J:TJSONObject;const K:string):TJSONObject;
var V:TJSONValue;
begin
  Result:=nil;V:=J.GetValue(K);
  if V is TJSONObject then Exit(TJSONObject(V.Clone));
  V:=TJSONObject.ParseJSONValue(S(J,K));
  if V is TJSONObject then Result:=TJSONObject(V)else V.Free;
end;
function Decode(const L:string):string;
var I,J:Integer;
begin
  Result:='';I:=1;
  while I<=Length(L)do
    if L[I]=''''then begin
      Inc(I);while I<=Length(L)do begin
        if L[I]=''''then begin Inc(I);if(I>Length(L))or(L[I]<>'''')then Break;end;
        Result:=Result+L[I];Inc(I);
      end;
    end else if L[I]='#'then begin
      Inc(I);J:=I;while(I<=Length(L))and CharInSet(L[I],['0'..'9'])do Inc(I);
      Result:=Result+Char(StrToInt(Copy(L,J,I-J)));
    end else Inc(I);
end;
function Enc(const V:string):string;
var C:Char;
begin
  Result:='';for C in V do Result:=Result+'#'+IntToStr(Ord(C));
  if Result=''then Result:='''''';
end;
function AddListEditorWrite(Config:TJSONObject; Lines,Names,Captions:TStrings;
  Detail:TListEditorDetailPlan; out Reason:string):Boolean;
var Settings,Rule,Auto,Tables,Cols,Row:TJSONObject;
  DropValue:TJSONValue;
  Fields,Labels,Required,UniqueFields,Code,Extra,Events,Kinds,NullChecks:TStringList;
  { 勾选的按钮（TWebFunctionButton）：明细区 7 个行按钮是否生成就看它（按钮目录项 'Detail Row Group'）。 }
  Buttons:TStringList;
  Key,AliasName,TableName,F,ControlName,Value,AutoType,Kind,DropText,DropType:string;
  I,J,K,X,FirstCode,LastCode,EventAt,ButtonAt,KeyIndex:Integer;
  KeyFound,IsTexty:Boolean;
  Field,Stmt:string;
  MaxIntNumber, DBAutoNumber, GuidNumber, DeleteEnabled:Boolean;
  ExportEnabled, PrintEnabled, AnnexEnabled:Boolean;
  { 导入（btImport）：把文本/电子表格批量导入**当前列表**（原版行为 g := gridMain），
    导入进来的行先进 cdsMain 未保存（暂存态），保存/撤销一起收尾。 }
  ImportOn, AuditConfigured:Boolean;
  ImportCaptions, ImportRequired:string;
  { 审计字段（录入*/修改*）与层级/行权限：语义与 mtMultiple、mtMasterSlave 一致 }
  AuditFields: array[0..5] of string;
  Hierarchy, DeptProtected, WriteModeHere: Boolean;
  { 明细写入（从表可编辑）：Detail <> nil 时才有值。 }
  HasDetail: Boolean;
  DetailTable, DetailKey, DetailAlias: string;
  DeptField, AuditValue, AF: string;
  function Fail(const Msg:string):Boolean;
  begin Reason:=Msg;Result:=False;end;
  { 该字段能否由导入的文本/电子表格填写：复选（文本表达不了真假）、自动赋值字段（保存时按规则
    覆盖，导入它没有意义）、自动编号字段（提交前由脚本赋值）都不参与。
    自动编号在本模板是必配的，所以主键总是被排除 —— 导入列＝用户真正要填的业务字段。 }
  function Importable(const AIndex:Integer):Boolean;
  var K:Integer;
  begin
    Result:=False;
    if (AIndex<0) or (AIndex>=Fields.Count) then Exit;
    if SameText(Kinds[AIndex],'check') then Exit;
    for K:=0 to 5 do
      if SameText(Fields[AIndex],AuditFields[K]) then Exit;
    if SameText(Fields[AIndex],Key) then Exit;
    Result:=True;
  end;

  function IsSimpleIdent(const V:string):Boolean;
  var K:Integer;
  begin
    Result:=False;
    if Trim(V)=''then Exit;
    for K:=1 to Length(V) do
      if not CharInSet(V[K],['A'..'Z','a'..'z','0'..'9','_'])then Exit;
    Result:=not CharInSet(V[1],['0'..'9']);
  end;
  { 审计规则顺序与 mtMultiple 一致：0..2 录入（新增时填，为空才填）、3..5 修改（保存时覆盖） }
  function AuditKeyName(const AIndex:Integer):string;
  begin
    case AIndex of
      0: Result:='录入用户';
      1: Result:='录入部门';
      2: Result:='录入时间';
      3: Result:='修改用户';
      4: Result:='修改部门';
    else Result:='修改时间';
    end;
  end;
  { 是否为主表已勾选字段：审计字段与部门字段都按这个规则校验（可以不放进记录区）。 }
  function SelectedColumn(const AField:string):Boolean;
  var N:Integer;R:TJSONObject;FN:string;
  begin
    Result:=False;
    for N:=0 to Cols.Count-1 do begin
      R:=O(Cols,IntToStr(N));FN:=S(R,'fdCOLUMN_NAME');
      if Pos('.',FN)>0 then Delete(FN,1,Pos('.',FN));
      if SameText(FN,AField)then Exit(Selected(S(R,'fdSELECT')));
    end;
  end;
  { 记录区里该字段有没有控件（决定能不能聚焦、能不能被用户手工改）。 }
  function HasControl(const AField:string):Boolean;
  var K:Integer;
  begin
    K:=Fields.IndexOf(AField);
    Result:=(K>=0);
  end;
  { 记录区没有控件的字段（如未放进记录区的自动编号主键）取提示标题：数据结构里的标题，
    找不到就退回字段名本身。 }
  function ColumnCaption(const AField:string):string;
  var N:Integer;R:TJSONObject;FN,CP:string;
  begin
    Result:=AField;
    for N:=0 to Cols.Count-1 do begin
      R:=O(Cols,IntToStr(N));FN:=S(R,'fdCOLUMN_NAME');
      if Pos('.',FN)>0 then Delete(FN,1,Pos('.',FN));
      if SameText(FN,AField)then begin
        CP:=Trim(S(R,'fdCAPTION'));
        if CP<>''then Result:=CP;
        Break;
      end;
    end;
  end;
  procedure A(const V:string);begin Extra.Add(V);end;
  { 数据结构的真实列类型名（大写），用于按类型生成赋值语句。 }
  function ColumnTypeName(const AField:string):string;
  var N:Integer;R:TJSONObject;FN:string;
  begin
    Result:='';
    for N:=0 to Cols.Count-1 do begin
      R:=O(Cols,IntToStr(N));FN:=S(R,'fdCOLUMN_NAME');
      if Pos('.',FN)>0 then Delete(FN,1,Pos('.',FN));
      if SameText(FN,AField)then Exit(UpperCase(Trim(S(R,'fdCOLUMN_TYPENAME'))));
    end;
  end;
  { 审计字段的赋值语句：用户/部门取宿主登录信息；时间按真实列类型赋值，
    避免在字符列上用 AsDateTime 抛异常（同 mtDetail 处理录入时间的做法）。 }
  function AuditAssign(const AIndex:Integer; const AField:string):string;
  var T:string;
  begin
    if (AIndex mod 3)=0 then Exit('.AsString := UGMM.Informations.Values[''UserName''];');
    if (AIndex mod 3)=1 then Exit('.AsString := UGMM.Informations.Values[''ClassName''];');
    T:=ColumnTypeName(AField);
    if (Pos('DATE',T)>0)or(Pos('TIME',T)>0)then Exit('.AsDateTime := Now;');
    if (Pos('INT',T)>0)or(Pos('NUMERIC',T)>0)or(Pos('DECIMAL',T)>0)or(Pos('NUMBER',T)>0)then
      Exit('.AsInteger := Trunc(Now);');
    Result:='.AsString := FormatDateTime(''yyyy-mm-dd hh:nn:ss'', Now);';
  end;
  { 审计填充 + 行权限复核的脚本片段。定义必须排在调用它的 btSave/btDelete 之前，
    因此在这里（Extra 的最前面）统一生成。 }
  procedure AddListEditorAudit;
  var K:Integer;Field,Stmt:string;
  begin
    { LEAuditFill **始终生成**：btSaveOnClick 里的调用是无条件的，定义若按配置条件省略，
      就会出现"调用了没定义的例程"（宿主 2026-09-19 报过 标识符未宣告: 'LEAuditFill'：
      「录入部门」的“生效”没勾选时该设置根本没写进配置，定义被跳过、调用还在）。
      没有配置任何审计字段时它就是空操作。 }
    A('//审计字段：新增时补空的录入*，每次保存刷新修改*（与 mtMultiple 同一语义）');
    A('//未配置任何审计字段时本过程为空操作（保持与 btSaveOnClick 的调用成对，避免出现未定义例程）。');
    A('procedure LEAuditFill;');
    A('begin');
    A('  if not cdsMain.Active or cdsMain.IsEmpty then Exit;');
    for K:=0 to 5 do
      if AuditFields[K]<>''then
      begin
        Field:='cdsMain.FieldByName('+QuotedStr(AuditFields[K])+')';
        Stmt:=Field+AuditAssign(K,AuditFields[K]);
        if K<3 then
        begin
          A('  //录入字段：为空才补，尊重手工填写');
          A('  if '+Field+'.IsNull or (Trim('+Field+'.AsString) = '''') then');
          A('    '+Stmt);
        end
        else
          A('  '+Stmt);
      end;
    A('end;');
    A('');
    { LECheckRowScope 的定义与全部调用都必须用同一个条件（Hierarchy）——它依赖部门字段，
      没有层级权限时既不该定义也不该调用。改动这里时务必同步 §调用点。 }
    if Hierarchy then
    begin
      A('//行权限复核：按主键回库取当前记录的部门，确认仍在可见范围内');
      A('//（空权限不放行、admin 不豁免；与查询用的 ClassName+SubClassName 同一范围）');
      A('procedure LECheckRowScope(const AAction: string);');
      A('var C: TUgClientDataSet; K: Variant; V: string; Allowed: Boolean; L: TStringList;');
      A('begin');
      A('  if not cdsMain.Active or cdsMain.IsEmpty then Exit;');
      A('  K := cdsMain.FieldByName('+QuotedStr(Key)+').AsVariant;');
      A('  if VarToStr(K) = '''' then Exit;');
      A('  Allowed := False;');
      A('  C := TUgClientDataSet.Create(nil);');
      A('  L := TStringList.Create;');
      A('  try');
      A('    C.DataNodeName := cDataNodeName;');
      A('    C.PageRowCount := -1;');
      A('    C.CommandText := '+QuotedStr('select '+DeptField+' from '+TableName+
        ' where '+Key+' = :rowKey')+';');
      A('    C.ParamByName(''rowKey'').Value := K;');
      A('    C.Open;');
      A('    if not C.IsEmpty then');
      A('    begin');
      A('      V := Trim(C.FieldByName('+QuotedStr(DeptField)+').AsString);');
      A('      L.Text := ReplaceText(UGMM.Informations.Values[''ClassName''] + '';'' +'+
        ' UGMM.Informations.Values[''SubClassName''], '';'', #13#10);');
      A('      while L.Count > 0 do');
      A('      begin');
      A('        if (V <> '''') and (Trim(L[0]) = V) then Allowed := True;');
      A('        L.Delete(0);');
      A('      end;');
      A('    end;');
      A('    if not Allowed then');
      A('      RaiseException(UGMM.LT(''您没有权限对当前数据进行'') + UGMM.LT(AAction) + UGMM.LT(''。''));');
      A('  finally');
      A('    L.Free; C.Free;');
      A('  end;');
      A('end;');
      A('');
    end;
  end;
  function ReadFields(const V:string;Dest:TStrings):Boolean;
  var P,N:string;
  begin
    Result:=False;
    for P in V.Split([';'])do if Trim(P)<>''then begin
      N:=Trim(P);if Copy(N,1,Length(AliasName)+1)<>AliasName+'.'then Exit;
      Delete(N,1,Length(AliasName)+1);if Fields.IndexOf(N)<0 then Exit;
      if Dest.IndexOf(N)<0 then Dest.Add(N);
    end;Result:=True;
  end;
begin
  Result:=False;Reason:='';
  Settings:=O(Config,'TWebNormalSetting');
  if Settings=nil then Exit(Fail('请配置主表唯一和自动编号。'));
  { 明细写入：HasDetail 必须**在生成任何脚本之前**定下来——LERefresh 里的明细按钮启用条件、
    提交/撤销/删除分支都要看它，而 LERefresh 生成得比保存块早（早前只在保存块前赋值，
    结果按钮状态那几行压根没生成）。 }
  HasDetail:=Detail<>nil;
  if HasDetail then
  begin
    DetailTable:=Detail.TableName;DetailKey:=Detail.DetailKey;DetailAlias:=Detail.AliasName;
  end;
  Rule:=nil;Auto:=nil;
  for I:=0 to 5 do AuditFields[I]:='';
  Fields:=TStringList.Create;Labels:=TStringList.Create;
  Required:=TStringList.Create;UniqueFields:=TStringList.Create;
  Code:=TStringList.Create;Extra:=TStringList.Create;Events:=TStringList.Create;
  Buttons:=TStringList.Create;
  Buttons.StrictDelimiter:=True;Buttons.Delimiter:=';';
  Buttons.DelimitedText:=S(Config,'TWebFunctionButton');
  Kinds:=TStringList.Create;NullChecks:=TStringList.Create;
  try
    for I:=0 to Names.Count-1 do begin Fields.Add(Decode(Names[I]));Labels.Add(Decode(Captions[I]));end;
    Tables:=O(O(O(Config,'TWebDataStructure'),'cdsTables'),'Data');
    Row:=O(Tables,'0');AliasName:=S(Row,'fdEpithet');TableName:=S(Row,'fdTableName');
    Rule:=Nested(Settings,'主表唯一');Auto:=Nested(Settings,'自动编号');
    Key:=S(Rule,'cbField');
    if Copy(Key,1,Length(AliasName)+1)<>AliasName+'.'then Exit(Fail('主表唯一必须指定当前根表主键。'));
    Delete(Key,1,Length(AliasName)+1);KeyIndex:=Fields.IndexOf(Key);
    AutoType:=S(Auto,'cbAutoNumberType');
    MaxIntNumber:=SameText(AutoType,'MaxInt');
    DBAutoNumber:=SameText(AutoType,'DBAutoincrement');
    GuidNumber:=SameText(AutoType,'Guid');
    DeleteEnabled:=Pos(';btDelete;', ';'+S(Config,'TWebFunctionButton')+';')>0;
    ExportEnabled:=Pos(';btExport;', ';'+S(Config,'TWebFunctionButton')+';')>0;
    PrintEnabled:=Pos(';btPrint;', ';'+S(Config,'TWebFunctionButton')+';')>0;
    AnnexEnabled:=Pos(';btAnnex;', ';'+S(Config,'TWebFunctionButton')+';')>0;
    if (not MaxIntNumber and not DBAutoNumber and not GuidNumber) or
       (S(Auto,'cbField')<>AliasName+'.'+Key)then
      Exit(Fail('请为主键配置数据库自增、Guid或MaxInt（最大整数+1）自动编号。'));
    if (MaxIntNumber or DBAutoNumber) and ((S(Auto,'edPrefix')<>'')or(S(Auto,'edSuffix')<>'')or
      (S(Auto,'seDigitCapacity')<>'')or(S(Auto,'cbSeqUence')<>''))then
      Exit(Fail('数据库自增和MaxInt不使用前缀、后缀、补位或序列，请重新选择编号方式。'));
    if not ReadFields(S(Settings,'非空字段'),Required)or
       not ReadFields(S(Rule,'cdsMultiSelectFields'),UniqueFields)then Exit(Fail('校验字段必须是当前可见根表字段。'));
    // 自动编号字段可以不放进记录区（隐藏主键）；它仍参与新增与唯一校验，只是没有可聚焦控件。
    // MaxInt/Guid 由脚本在提交前赋值，这里校验非空；数据库自增要等服务端回填，不能提前校验。
    if not DBAutoNumber and (Required.IndexOf(Key)<0) then Required.Add(Key);
    Value:=S(Settings,'文本类型');
    if (Value<>'') and not SameText(Value,'Normal') and not SameText(Value,'Upper') and not SameText(Value,'Lower') then
      Exit(Fail('文本类型仅支持 Normal、Upper 或 Lower。'));
    Cols:=O(O(O(Config,'TWebDataStructure'),'cdsColumns'),'Data');
    if Cols=nil then Exit(Fail('缺少字段定义。'));
    for I:=0 to Fields.Count-1 do begin Kinds.Add('');NullChecks.Add('0');end;
    KeyFound:=False;
    for I:=0 to Cols.Count-1 do begin
      Row:=O(Cols,IntToStr(I));F:=S(Row,'fdCOLUMN_NAME');
      Delete(F,1,Length(AliasName)+1);
      if not SameText(F,Key) and (Fields.IndexOf(F)<0) then Continue;
      if SameText(F,Key) and Selected(S(Row,'fdSELECT')) then KeyFound:=True;
      Kind:=LowerCase(S(Row,'fdOBJECT_TYPE'));
      if Kind=''then Kind:='edit';
      if(Fields.IndexOf(F)>=0)then Kinds[Fields.IndexOf(F)]:=Kind;
      Value:=UpperCase(S(Row,'fdCOLUMN_TYPENAME'));
      IsTexty:=(Pos('CHAR',Value)>0)or(Pos('TEXT',Value)>0)or(Pos('CLOB',Value)>0)or
        (Pos('MEMO',Value)>0)or(Value='STRING')or(Value='UNIQUEIDENTIFIER');
      // 对象类型决定记录区控件：文本、数值、备注、复选、日期时间、固定下拉、查找与多列下拉。
      if(Kind<>'edit')and(Kind<>'number')and(Kind<>'memo')and(Kind<>'check')and
        (Kind<>'date')and(Kind<>'time')and(Kind<>'datetime')and(Kind<>'combobox')and
        (Kind<>'lookupedit')and(Kind<>'lookupeditextra')and
        (Kind<>'gridcombobox')and(Kind<>'gridcomboboxextra')then
        Exit(Fail('本批同窗写入尚未接入此对象类型（'+Kind+'）：'+F+
          '；可用文本、数值、备注、复选、日期/时间、固定下拉、查找与多列下拉(值=代码)。'));
      if Kind='combobox' then begin
        DropText:='';DropType:='';
        { 精灵把下拉配置存成字符串，兼容已是 JSON 对象的情况。 }
        DropValue:=Row.GetValue('fdDropDownOptions');
        if DropValue is TJSONObject then DropValue:=TJSONValue(DropValue.Clone)
        else DropValue:=TJSONObject.ParseJSONValue(S(Row,'fdDropDownOptions'));
        if not (DropValue is TJSONObject) then
        begin
          DropValue.Free;
          Exit(Fail('字段 '+F+' 是下拉字段，但缺少有效的下拉选项 JSON。'));
        end;
        try
          DropType:=S(TJSONObject(DropValue),'cbDropDownType');
          if SameText(DropType,'SetText') then DropText:=S(TJSONObject(DropValue),'mmText')
          else if SameText(DropType,'SqlText') then begin
            { SqlText：选项由生成脚本在初始化时用单条 SELECT 取回（取第一列）。
              精灵在 SqlText 下不提供“返回字段/显示字段”，切换类型留下的旧值只忽略；
              这里只校验 SQL 形态与动态加载。 }
            if Selected(S(TJSONObject(DropValue),'cbDynamicLoading'))then
              Exit(Fail('字段 '+F+' 的 SqlText 下拉尚未接入动态加载，请关闭动态加载。'));
            DropText:=Trim(S(TJSONObject(DropValue),'mmText'));
            if not SameText(Copy(DropText,1,7),'select ')or(Pos(';',DropText)>0)or
              (Pos(':',DropText)>0)or(Pos('--',DropText)>0)or(Pos('/*',DropText)>0)then
              Exit(Fail('字段 '+F+' 的 SqlText 须为无参数、无注释的单条 SELECT。'));
          end else
            Exit(Fail('字段 '+F+' 的下拉类型 '+DropType+' 尚未接入；可用固定下拉(SetText)或 SQL 文本(SqlText)。'));
        finally
          DropValue.Free;
        end;
        if Trim(DropText)=''then
          Exit(Fail('字段 '+F+' 的下拉选项内容或 SQL 为空，请先在数据结构页配置。'));
      end;
      if Kind='number' then begin
        if not((Pos('INT',Value)>0)or(Pos('DECIMAL',Value)>0)or(Pos('NUMERIC',Value)>0)or
          (Value='FLOAT')or(Value='REAL')or(Value='DOUBLE')or(Value='MONEY')or(Value='NUMBER'))then
          Exit(Fail('字段 '+F+' 的对象类型是数值，但数据库类型是 '+Value+'，请核对。'));
      end else if Kind='check' then begin
        if not((Value='BIT')or(Value='BOOL')or(Value='BOOLEAN'))then
          Exit(Fail('字段 '+F+' 的对象类型是复选，但数据库类型是 '+Value+'，请核对。'));
      end else if(Kind='date')or(Kind='time')or(Kind='datetime')then begin
        if not((Pos('DATE',Value)>0)or(Pos('TIME',Value)>0)or(Value='TIMESTAMP'))then
          Exit(Fail('字段 '+F+' 的对象类型是日期时间，但数据库类型是 '+Value+'，请核对。'));
      end else if(Kind='lookupedit')or(Kind='lookupeditextra')or
        (Kind='gridcombobox')or(Kind='gridcomboboxextra')then begin
        { 查找字段存的是代码：字符型代码按文本判空，数值型代码按 NULL 判空。
          查找本身的配置（SqlQuery/单条 SELECT/值字段/查找列/extra 显示字段/动态加载）
          由 ugConfiguration.ListEditorTemplate 统一校验，两种模式下都会拦。 }
        { 查找与多列下拉存的是代码：字符型代码按文本判空，数值型代码按 NULL 判空。 }
        if not(IsTexty or(Value='INT')or(Value='INTEGER')or(Value='BIGINT')or
          (Value='SMALLINT')or(Value='DECIMAL')or(Value='NUMERIC')or(Value='NUMBER'))then
          Exit(Fail('字段 '+F+' 是查找/多列下拉字段，但数据库类型是 '+Value+'，请核对。'));
        if not IsTexty then NullChecks[Fields.IndexOf(F)]:='1';
      end else if not IsTexty then
        Exit(Fail('字段 '+F+' 的对象类型是 '+Kind+'，但数据库类型是 '+Value+'，请核对。'));
      if F=Key then begin
        Value:=UpperCase(S(Row,'fdCOLUMN_TYPENAME'));
        if MaxIntNumber then begin
          if(Value<>'INT')and(Value<>'INTEGER')then
            Exit(Fail('MaxInt仅支持非自增INT/INTEGER主键，不支持字符、BIGINT或小整数字段。'));
        end else if DBAutoNumber then begin
          if (Value<>'INT')and(Value<>'INTEGER')and(Value<>'BIGINT')and
             (Value<>'SMALLINT')and(Value<>'AUTOINC') then
            Exit(Fail('数据库自增主键须为整数字段，请核对真实表结构。'));
        end else if(Pos('CHAR',Value)=0)or(StrToIntDef(S(Row,'fdCOLUMN_LENGTH'),0)<36)then
          Exit(Fail('Guid主键需要至少36字符的字符字段。'));
      end;
    end;
    { 审计字段：新增时填录入*（为空才填），保存时填修改*；层级权限开启时用录入部门做行范围过滤与复核。 }
    Hierarchy:=Selected(Trim(S(Settings,'层级权限')));
    WriteModeHere:=Pos(';btSave;',';'+S(Config,'TWebFunctionButton')+';')>0;
    for I:=0 to 5 do begin
      Value:=Trim(S(Settings,AuditKeyName(I)));
      if Value=''then Continue;
      if not WriteModeHere then
        Exit(Fail('自动赋值规则需要同时启用新增/修改与保存/撤销：'+AuditKeyName(I)));
      if Copy(Value,1,Length(AliasName)+1)<>AliasName+'.'then
        Exit(Fail('自动赋值字段必须属于当前根表：'+Value));
      F:=Copy(Value,Length(AliasName)+2,MaxInt);
      if not IsSimpleIdent(F)or not SelectedColumn(F)then
        Exit(Fail('自动赋值字段必须在主表已勾选字段中：'+Value));
      if SameText(F,Key)then Exit(Fail('自动赋值不能覆盖主键：'+Value));
      for J:=0 to I-1 do
        if SameText(AuditFields[J],F)then Exit(Fail('多个自动赋值规则不能使用同一字段：'+Value));
      AuditFields[I]:=F;
    end;
    if Hierarchy and (AuditFields[1]='')then
      Exit(Fail('层级权限需要先配置“录入部门”字段（用它做行范围过滤与保存/删除复核）。'));
    DeptField:=AuditFields[1];

    if not KeyFound then Exit(Fail('主表唯一字段必须加入主表已选字段；可隐藏但不能取消选择。'));
    { 导入（btImport）的列清单：原版把两个字符串交给宿主入口 ——
      `fs` 是**列标题**（UGMM.ImportText 按表格列标题匹配，所以必须与记录区/表格标题逐字一致），
      `fe` 是**字段名**（UGMM.ImpExcel 的必填项按字段名匹配）。
      必填项取配置的「非空字段」∩ 可导入字段；没配非空字段时退回全部可导入的业务字段
      （与 mtMasterSlave 的明细导入同一套回退规则）。 }
    AuditConfigured:=False;
    for I:=0 to 5 do if AuditFields[I]<>''then AuditConfigured:=True;
    ImportOn:=Pos(';btImport;',';'+S(Config,'TWebFunctionButton')+';')>0;
    ImportCaptions:='';ImportRequired:='';
    if ImportOn then
    begin
      J:=0;
      for I:=0 to Fields.Count-1 do
        if Importable(I) then
        begin
          Inc(J);
          ImportCaptions:=ImportCaptions+Labels[I]+';';
          if Required.IndexOf(Fields[I])>=0 then ImportRequired:=ImportRequired+Fields[I]+';';
        end;
      if J=0 then
        Exit(Fail('导入至少要有一个可导入字段：复选、自动赋值（录入*/修改*）与自动编号字段不参与导入。'));
      { 非空字段如果落在"不能由导入填写"的字段上（复选/自动赋值），导入进来的行**必然**校验不通过
        （复选控件从文本只能读 True/False，且随语言环境变化），这里明确拒绝而不是让用户导完才发现。 }
      for I:=0 to Required.Count-1 do
      begin
        J:=Fields.IndexOf(Required[I]);
        if SameText(Required[I],Key) then Continue;
        if (J<0) or (not Importable(J)) then
          Exit(Fail('非空字段 '+Required[I]+' 不能由导入填写（复选或自动赋值字段），导入的行必然校验不通过：'
            + '请取消该字段的“非空字段”，或不使用导入。'));
      end;
      if ImportRequired='' then
        for I:=0 to Fields.Count-1 do
          if Importable(I) then ImportRequired:=ImportRequired+Fields[I]+';';
    end;
    FirstCode:=-1;LastCode:=-1;EventAt:=-1;ButtonAt:=-1;
    for I:=0 to Lines.Count-1 do begin
      if Trim(Lines[I])='Codes.Strings = ('then FirstCode:=I;
      if(FirstCode>=0)and(LastCode<0)and(Trim(Lines[I])=')')then LastCode:=I;
      if Trim(Lines[I])='Events.Strings = ('then EventAt:=I;
      if Trim(Lines[I])='object pButtons: TUgContainerPanel'then ButtonAt:=I;
    end;
    if(FirstCode<0)or(LastCode<0)or(EventAt<0)or(ButtonAt<0)then Exit(Fail('同窗写入模板结构不匹配。'));
    for I:=FirstCode+1 to LastCode-1 do Code.Add(Decode(Trim(Lines[I])));
    if Trim(Code[Code.Count-1])<>'end.'then Exit(Fail('脚本结束标记不匹配。'));
    Code.Delete(Code.Count-1);
    while(Code.Count>0)and(Trim(Code[Code.Count-1])='')do Code.Delete(Code.Count-1);
    if Trim(Code[Code.Count-1])<>'begin'then Exit(Fail('脚本初始化块不匹配。'));
    Code.Delete(Code.Count-1);
    for I:=0 to Code.Count-1 do
      if Pos('procedure UgWebRunFrameOnAfterRunScript(',Code[I])=1 then
        Code[I]:=StringReplace(Code[I],'UgWebRunFrameOnAfterRunScript','LEBaseInitialize',[]);
    for I:=Code.Count-1 downto 0 do
      if Trim(Code[I])='cdsMain.CommandText := SQL;' then
        Code.Insert(I-1,'  SQL := SQL + '+QuotedStr(' order by '+AliasName+'.'+Key)+';');
    Code.Insert(0,'  LEKey, LEPreviousKey: string;');
    { LEIsNew 必须**始终**声明：行权限复核要判断"是否新增记录"，而它不能只在 MaxInt/自增
      编号下才存在（Guid 编号时曾因此报 “标识符未宣告: 'LEIsNew'”，宿主 2026-09-19）。 }
    Code.Insert(0,'  LEIsNew: Boolean = False;');
    Code.Insert(0,'  LELocated: Boolean = False;');
    Code.Insert(0,'  LEInternal: Boolean = False; LEReady: Boolean = False; LEBusy: Boolean = False;');
    Code.Insert(0,'var LEState: Integer = 0;');
    if HasDetail then
      { 明细校验失败要"交回宿主显示"（不能在保存处理里弹阻塞框），用一个标记把这条路径与
        主记录校验（宿主已验收：WaitEditorError + 保持编辑态）区分开。 }
      { 必须插在 var 行**之后**（索引 1）：插到最前面会变成没有 var 关键字的声明，
        FastScript 直接报 `'BEGIN' expected`。 }
      Code.Insert(1,'  LEDetailError: Boolean = False;');
    AddMultipleValidation(Extra,Required,UniqueFields,Fields,Labels,TableName,Key,DBAutoNumber);
    if MaxIntNumber then AddMaxIntNumber(Extra,TableName,Key);
    AddListEditorAudit;
    if ExportEnabled then
    begin
      A('//导出当前表格到 Excel（沿用宿主原有的导出入口）');
      A('procedure btExportOnClick(Sender: TObject);');
      A('begin');
      { 与模块其它事件入口一致：先看自己当前是否可用（权限/状态刷新会禁用按钮，
        程序化调用也不该绕过）。 }
      A('  if not btExport.Enabled then Exit;');
      A('  if not cdsMain.Active or cdsMain.IsEmpty then');
      A('  begin');
      A('    ShowNotice(UGMM.LT(''没有可导出的数据。''));');
      A('    Exit;');
      A('  end;');
      A('  UGMM.ExpExcel(gridMain, Self.Caption, Self.Caption);');
      A('end;');
      A('');
    end;
    if AnnexEnabled then
    begin
      A('//按当前记录主键打开附件管理（沿用原版附件入口；编辑权限由工具栏按钮状态推导）');
      A('procedure btAnnexOnClick(Sender: TObject);');
      A('var CanEdit: Boolean;');
      A('begin');
      A('  if not btAnnex.Enabled then Exit;');
      A('  if not cdsMain.Active or cdsMain.IsEmpty then');
      A('  begin');
      A('    ShowNotice(UGMM.LT(''请先选择一行记录。''));');
      A('    Exit;');
      A('  end;');
      A('  CanEdit := False;');
      A('  if btEditor.Visible and btEditor.Enabled then CanEdit := True;');
      A('  if btDelete.Visible and btDelete.Enabled then CanEdit := True;');
      A('  UGMM.OpenFileManager(Self.Guid, cdsMain.FieldByName(' + QuotedStr(Key) + ').AsString,');
      A('    31457280(*空间容量*), CanEdit);');
      A('end;');
      A('');
    end;
    { 注释保持原文：未配导入的模块生成的 DFM 要与之前逐字节一致，状态 4 的说明写在导入块里。 }
    A('//同窗编辑：0浏览、1编辑、2已提交待重载、3结果待核实。');
    A('procedure LERefresh;');A('var Editing: Boolean;');A('begin');
    A('  if not LEReady then Exit;');A('  Editing := LEState = 1;');
    A('  RefreshToolbar;');
    A('  //先应用宿主已有的权限接口，再叠加当前编辑状态。');
    for F in TArray<string>.Create('btAppend','btEditor','btSave','btCancel','btClose','btQuery')do
      A('  '+F+'.Enabled := True;');
    if ImportOn then A('  btImport.Enabled := True;');
    { 输出类按钮同样先恢复权限候选状态，再按状态收敛（与 mtMultiple 一致）。 }
    if ExportEnabled then A('  btExport.Enabled := True;');
    if PrintEnabled then A('  btPrint.Enabled := True;');
    if AnnexEnabled then A('  btAnnex.Enabled := True;');
    if DeleteEnabled then A('  btDelete.Enabled := True;');
    A('  UGMM.VerifyRunFramePerm(Self);');
    A('  btAppend.Enabled := btAppend.Enabled and (LEState = 0) and cdsMain.Active;');
    if DeleteEnabled then
      A('  btDelete.Enabled := btDelete.Enabled and (LEState = 0) and cdsMain.Active and not cdsMain.IsEmpty and not LEBusy;');
    A('  btEditor.Enabled := btEditor.Enabled and (LEState = 0) and cdsMain.Active and not cdsMain.IsEmpty;');
    if ImportOn then
    begin
      { 保存/撤销在**编辑态**与**导入暂存态**都可用；撤销在暂存态是"放弃全部导入行"。 }
      A('  btSave.Enabled := btSave.Enabled and ((LEState = 1) or (LEState = 4)) and not LEBusy;');
      A('  btCancel.Enabled := btCancel.Enabled and ((LEState = 1) or (LEState = 4)) and not LEBusy;');
      { 原版对导入按钮额外调了一次按按钮的权限接口（VerifyRunFramePermAction），照抄。 }
      A('  btImport.Enabled := btImport.Enabled and UGMM.VerifyRunFramePermAction(Self, btImport.Name) and (LEState = 0) and cdsMain.Active and not LEBusy;');
    end
    else
    begin
      A('  btSave.Enabled := btSave.Enabled and Editing and not LEBusy;');
      A('  btCancel.Enabled := btCancel.Enabled and Editing and not LEBusy;');
    end;
    A('  btClose.Enabled := btClose.Enabled and not LEBusy;');
    A('  btQuery.Enabled := btQuery.Enabled and (LEState <> 1) and not LEBusy;');
    { 导出/打印/附件：只在浏览态且有数据时可用（编辑/提交态禁用）。 }
    if ExportEnabled then
      A('  btExport.Enabled := btExport.Enabled and (LEState = 0) and cdsMain.Active and not cdsMain.IsEmpty;');
    if PrintEnabled then
      A('  btPrint.Enabled := btPrint.Enabled and (LEState = 0) and cdsMain.Active and not cdsMain.IsEmpty;');
    if AnnexEnabled then
      A('  btAnnex.Enabled := btAnnex.Enabled and (LEState = 0) and cdsMain.Active and not cdsMain.IsEmpty and not LEBusy;');
    if HasDetail then
    begin
      { 明细网格只在主记录**编辑态**可编辑：浏览态必须是只读的（宿主 2026-09-20 反馈
        "非修改状态下明细表还能编辑内容"——之前只写了 DFM 初始值，没有随编辑态切换）。 }
      A('  gridDetail.ReadOnly := LEState <> 1;');
      { 明细按钮只在主记录编辑态可用：明细改动属于同一次编辑会话（保存/撤销一起生效）。
        只发**勾选的**那些；需要"有当前行"的按钮还要看 IsEmpty，上移/下移再看是否到边界。 }
      if Buttons.IndexOf('btDetailAppend') >= 0 then
        A('  btDetailAppend.Enabled := (LEState = 1) and cdsDetailed.Active and not LEBusy;');
      if Buttons.IndexOf('btDetailInsert') >= 0 then
        A('  btDetailInsert.Enabled := (LEState = 1) and cdsDetailed.Active and not LEBusy;');
      if Buttons.IndexOf('btDetailDelete') >= 0 then
        A('  btDetailDelete.Enabled := (LEState = 1) and cdsDetailed.Active and not cdsDetailed.IsEmpty and not LEBusy;');
      if Buttons.IndexOf('btDetailCopy') >= 0 then
        A('  btDetailCopy.Enabled := (LEState = 1) and cdsDetailed.Active and not cdsDetailed.IsEmpty and not LEBusy;');
      if Buttons.IndexOf('btDetailMoveUp') >= 0 then
        A('  btDetailMoveUp.Enabled := (LEState = 1) and cdsDetailed.Active and not cdsDetailed.IsEmpty and not cdsDetailed.Bof and not LEBusy;');
      if Buttons.IndexOf('btDetailMoveDown') >= 0 then
        A('  btDetailMoveDown.Enabled := (LEState = 1) and cdsDetailed.Active and not cdsDetailed.IsEmpty and not cdsDetailed.Eof and not LEBusy;');
      if Buttons.IndexOf('btDetailClear') >= 0 then
        A('  btDetailClear.Enabled := (LEState = 1) and cdsDetailed.Active and not cdsDetailed.IsEmpty and not LEBusy;');
    end;
    if ImportOn then
      { 暂存态下表格保持可用，用户能滚动查看导入进来的行（明细/编辑仍按状态只读）。 }
      A('  gridMain.Enabled := (LEState = 0) or (LEState = 4);')
    else
      A('  gridMain.Enabled := LEState = 0;');
    A('  pQuery.Enabled := LEState = 0;');
    A('  pPages.Enabled := LEState = 0;');A('  dsMain.AutoEdit := False;');
    A('  Self.IsEditor := LEState <> 0;');
    for I:=0 to Fields.Count-1 do
    begin
      { 审计字段与层级权限下的部门字段不允许手工改：编辑态也保持只读。
        部门只读沿用 mtTree 的规则——开启层级权限就保护部门归属。 }
      AF:=Fields[I];
      if SameText(AF,AuditFields[0])or SameText(AF,AuditFields[1])or
         SameText(AF,AuditFields[2])or SameText(AF,AuditFields[3])or
         SameText(AF,AuditFields[4])or SameText(AF,AuditFields[5])or
         (Hierarchy and SameText(AF,DeptField))then
        A('  leField'+IntToStr(I)+'.ReadOnly := True;')
      else
        A('  leField'+IntToStr(I)+'.ReadOnly := '+IfThen(I=KeyIndex,'True','not Editing')+';');
    end;
    A('end;');
    { LEGuard 已移除：它只在数据集事件里拦"编辑态下的滚动/关闭"，而框架自身的同步也会触发这些事件
      （误报）。改用各按钮处理里的显式状态检查，与 mtMasterSlave 一致。 }
    A('procedure LEAfterScroll(DataSet: TDataSet);');A('begin');A('  if not LEInternal then LERefresh;');A('end;');
    A('//新增和修改只切换当前数据集状态，不复制其他行的控件值。');
    A('procedure LEBeginEdit(IsNew: Boolean);');
    if MaxIntNumber then A('var N: Integer;')
    else if GuidNumber then A('var G: string;');
    A('begin');
    A('  if (LEState <> 0) or not cdsMain.Active then Exit;');
    A('  LEPreviousKey := '''';');
    A('  if not cdsMain.IsEmpty then LEPreviousKey := cdsMain.FieldByName('+QuotedStr(Key)+').AsString;');
    if MaxIntNumber then begin
      A('  //查询失败或编号用尽时，不创建半条空记录。');
      A('  if IsNew then N := GetMaxIntNumber;');
    end;
    A('  if IsNew then cdsMain.Append else begin if cdsMain.IsEmpty then Exit; cdsMain.Edit; end;');
    A('  LEState := 1;');
    A('  LEIsNew := IsNew;');
    A('  if IsNew then');A('  begin');
    if MaxIntNumber then A('    cdsMain.FieldByName('+QuotedStr(Key)+').AsInteger := N;')
    else if GuidNumber then begin
      A('    G := UGMM.CreateGuid;');
      A('    if (Length(G) = 38) and (Copy(G, 1, 1) = ''{'') then G := Copy(G, 2, 36);');
      A('    cdsMain.FieldByName('+QuotedStr(Key)+').AsString := G;');
    end;A('  end;');
    A('  LEKey := cdsMain.FieldByName('+QuotedStr(Key)+').AsString;');A('end;');
    for I:=0 to 1 do begin
      if I=0 then F:='btAppend'else F:='btEditor';
      A('procedure '+F+'OnClick(Sender: TObject);');A('begin');
      A('  LERefresh;');A('  if not '+F+'.Enabled then Exit;');A('  try');
      A('    LEBeginEdit('+BoolToStr(I=0,True)+');');
      A('  except ShowActionError(ExceptionMessage); end;');A('  LERefresh;');A('end;');
    end;
    A('//仅按提交记录的稳定键定位；扫描当前查询范围的分页，不清除筛选。');
    A('procedure LEReload;');A('var P: Integer; Found: Boolean;');A('begin');
    A('  LEInternal := True;');A('  try');
    A('    cdsMain.Close; cdsMain.Open;');
    A('    Found := cdsMain.Locate('+QuotedStr(Key)+', LEKey, 0);');
    A('    if LEKey <> '''' then');A('      for P := 1 to cdsMain.PageCount do');A('      begin');
    A('        cdsMain.PageIndex := P;');
    A('        Found := cdsMain.Locate('+QuotedStr(Key)+', LEKey, 0);');
    A('        if Found then Break;');A('      end;');
    A('    LEState := 0;');
    A('    LELocated := Found;');
    A('    UpdatePage;');
    A('  finally LEInternal := False; LERefresh; end;');A('end;');
    A('//删除或数据库未回传自增键时，只刷新当前查询范围，不按空键定位。');
    A('procedure LEReloadList;');A('begin');
    A('  LEInternal := True;');A('  try');
    A('    cdsMain.Close; cdsMain.Open;');
    A('    LEState := 0; LELocated := not cdsMain.IsEmpty;');
    A('    UpdatePage;');
    A('  finally LEInternal := False; LERefresh; end;');A('end;');
    { 导入脚本放在这里：LERefresh / LEReloadList / ValidateGenericRows 都已定义
      （FastScript 先定义后调用），而 btSaveOnClick 还在下面。 }
    if ImportOn then
    begin
      { 导入（原版行为）：文本/电子表格批量导入**当前列表**（g := gridMain），
        导入进来的行先留在 cdsMain 里未保存 —— 新增一个 LEState = 4（暂存态）：
        保存/撤销一起收尾，别的入口按状态收敛（见 LERefresh / btSaveOnClick / btCancelOnClick / LEQuery）。 }
      A('//导入 >> 文本格式或电子表格（沿用宿主的 ImportText / ImpExcel 入口，目标是当前列表）');
      A('procedure pmImportUgMenuItemsOnClick(const acaption: string);');
      A('var');
      A('  g: TUgDBGrid;');
      A('  fe, fs: String;');
      A('begin');
      A('  //赋值表格地址（导入目标＝当前列表 gridMain）');
      A('  g := gridMain;');
      A('  //赋值必填项（字段名，电子表格导入用）');
      A('  fe := ' + QuotedStr(ImportRequired) + ';');
      A('  //赋值列（记录区/表格的标题，文本导入按标题匹配列）');
      A('  fs := ' + QuotedStr(ImportCaptions) + ';');
      A('  if acaption = UGMM.LT(''文本格式'') then');
      A('  UGMM.ImportText(g, fs);');
      A('  if acaption = UGMM.LT(''电子表格'') then');
      A('  UGMM.ImpExcel(g, Self.Caption, fe);');
      A('  //导入后进入暂存态：行还没保存，保存/撤销一起收尾');
      A('  LEImportState;');
      A('end;');
      A('//导入');
      A('procedure btImportOnClick(Sender: TObject);');
      A('begin');
      A('  pmImportUgMenuItemsOnClick(UGMM.LT(''文本格式''));');
      A('end;');
      A('');
      if AuditConfigured then
      begin
        A('//导入的行逐行补审计字段（新增时补空的录入*、保存时刷新修改*，与 LEAuditFill 同一套赋值）');
        A('procedure LEImportAudit;');
        A('begin');
        A('  if not cdsMain.Active or cdsMain.IsEmpty then Exit;');
        A('  //不保存/恢复光标：本过程只在暂存保存里跑，紧接着 LEReloadList 就会重载列表');
        A('  cdsMain.DisableControls;');
        A('  try');
        A('    cdsMain.First;');
        A('    while not cdsMain.Eof do');
        A('    begin');
        A('      if cdsMain.UpdateStatus = usInserted then');
        A('      begin');
        A('        cdsMain.Edit;');
        for K:=0 to 5 do
          if AuditFields[K]<>''then
          begin
            Field:='cdsMain.FieldByName('+QuotedStr(AuditFields[K])+')';
            Stmt:=Field+AuditAssign(K,AuditFields[K]);
            if K<3 then
            begin
              A('        //录入字段：为空才补，尊重导入进来的值');
              A('        if '+Field+'.IsNull or (Trim('+Field+'.AsString) = '''') then');
              A('          '+Stmt);
            end
            else
              A('        '+Stmt);
          end;
        A('        cdsMain.Post;');
        A('      end;');
        A('      cdsMain.Next;');
        A('    end;');
        A('  finally');
        A('    cdsMain.EnableControls;');
        A('  end;');
        A('end;');
        A('');
      end;
      if MaxIntNumber or GuidNumber then
      begin
        A('//导入的行逐行补编号（只补空号；导入文本里已经写了的编号不动）');
        A('procedure LEImportNumber;');
        if MaxIntNumber then A('var N: Integer;')
        else A('var G: string;');
        A('begin');
        A('  if not cdsMain.Active or cdsMain.IsEmpty then Exit;');
        if MaxIntNumber then
        begin
          A('  //先按当前最大号取候选起点，再逐行 +1（一次取号，避免批量新增互相重号）');
          A('  N := GetMaxIntNumber;');
        end;
        A('  cdsMain.First;');
        A('  while not cdsMain.Eof do');
        A('  begin');
        if MaxIntNumber then
        begin
          A('    if (cdsMain.UpdateStatus = usInserted) and cdsMain.FieldByName('+QuotedStr(Key)+').IsNull then');
          A('    begin');
          A('      cdsMain.Edit;');
          A('      cdsMain.FieldByName('+QuotedStr(Key)+').AsInteger := N;');
          A('      cdsMain.Post;');
          A('      Inc(N);');
          A('    end;');
        end
        else
        begin
          A('    if (cdsMain.UpdateStatus = usInserted) and (Trim(cdsMain.FieldByName('+QuotedStr(Key)+').AsString) = '''') then');
          A('    begin');
          A('      G := UGMM.CreateGuid;');
          A('      if (Length(G) = 38) and (Copy(G, 1, 1) = ''{'') then G := Copy(G, 2, 36);');
          A('      cdsMain.Edit;');
          A('      cdsMain.FieldByName('+QuotedStr(Key)+').AsString := G;');
          A('      cdsMain.Post;');
          A('    end;');
        end;
        A('    cdsMain.Next;');
        A('  end;');
        A('end;');
        A('');
      end;
      A('//导入状态：把导入进来（尚未保存）的行切到暂存态；没有真的导入行就保持浏览态');
      A('procedure LEImportState;');
      A('begin');
      A('  if not cdsMain.Active then Exit;');
      A('  if cdsMain.ChangeCount <= 0 then Exit;');
      { 不在这里重载数据：LEReloadList 会 Close/Open，把刚导入的未保存行冲掉。
        导入的行本来就在 cdsMain 里，表格会自动显示；分页栏等保存后一起刷新。 }
      A('  LEState := 4;');
      A('end;');
      A('');
      A('//暂存保存：补编号/审计 → 全行校验（含行号与数据库唯一） → 提交 → 按当前查询范围刷新');
      A('procedure LEImportSave;');
      A('begin');
      A('  if not btSave.Enabled or LEBusy or (LEState <> 4) then Exit;');
      A('  LEBusy := True; LERefresh;');
      A('  LEInternal := True;');
      A('  try');
      A('    try');
      A('      if cdsMain.State in [dsEdit, dsInsert] then cdsMain.Post;');
      if MaxIntNumber or GuidNumber then A('      LEImportNumber;');
      if AuditConfigured then A('      LEImportAudit;');
      A('      ValidateGenericRows;');
      A('    except');
      A('      //校验失败：保持暂存态与全部导入行，提示里带第几行哪一列不能为空/重复');
      A('      LEInternal := False;');
      A('      WaitEditorError(ExceptionMessage);');
      A('      Exit;');
      A('    end;');
      A('    if cdsMain.ChangeCount = 0 then');
      A('    begin');
      A('      cdsMain.CancelUpdates; LEState := 0;');
      A('      ShowNotice(UGMM.LT(''数据没有变化，无需保存。''));');
      A('      Exit;');
      A('    end;');
      A('    LEState := 3; LERefresh;');
      A('    try cdsMain.SubmitUpdates;');
      A('    except');
      A('      ShowActionError(UGMM.LT(''提交结果待核实，请重新查询核对，禁止重复保存。'') + ExceptionMessage); Exit;');
      A('    end;');
      A('    LEState := 2;');
      A('    try');
      A('      LEReloadList;');
      A('      ShowNotice(UGMM.LT(''导入的数据已保存成功。''));');
      A('    except ShowActionError(UGMM.LT(''已保存成功，但刷新失败，请重新查询。'') + ExceptionMessage); end;');
      A('  finally LEInternal := False; LEBusy := False; LERefresh; end;');
      A('end;');
      A('');
    end;
    if HasDetail then
      { 明细写入例程必须定义在 btSaveOnClick **之前**（FastScript 先定义后调用）。 }
      AddListEditorDetailWriteScript(Detail, Extra, Buttons);
    A('//校验失败保持编辑；提交抛异常时不假定后台未提交。');
    A('procedure btSaveOnClick(Sender: TObject);');A('begin');
    A('  LERefresh;');
    if ImportOn then
    begin
      A('  if not btSave.Enabled or LEBusy or ((LEState <> 1) and (LEState <> 4)) then Exit;');
      A('  //导入暂存态：走"逐行补号/审计 + 全行校验 + 一次提交"的暂存保存');
      A('  if LEState = 4 then');
      A('  begin LEImportSave; Exit; end;');
    end
    else
      A('  if not btSave.Enabled or LEBusy or (LEState <> 1) then Exit;');
    if HasDetail then A('  LEDetailError := False;');
    if HasDetail then
      { 先把明细网格里正在编辑的那一行落库：本处理里要弹提示框，而宿主在"明细网格还有未提交编辑"时
        会拒绝阻塞对话框（宿主 2026-09-20 实测报 `Blocking method Execute() could not be called.`）。 }
      A('  LEDetailFlushRow;');
    A('  LEBusy := True; LERefresh;');
    A('  LEInternal := True;');A('  try');A('    try');
    if Hierarchy then
    begin
      A('      //先复核行范围：仅针对数据库中已存在的记录（新记录由审计字段按当前用户归属）');
      A('      if not LEIsNew then LECheckRowScope(''修改'');');
    end;
    A('      //审计字段在必填校验之前填充，避免把自动赋值的字段判成空');
    A('      LEAuditFill;');
    for F in Required do begin
      I:=Fields.IndexOf(F);ControlName:='leField'+IntToStr(I);
      { 必填判定按控件类型：文本/备注/固定下拉按去空格后的文本；数值、复选、日期时间、
        以及数值型代码的查找字段按 NULL（False 与 0 都是有效值，不能当成空）。 }
      Kind:='';if(I>=0)and(I<Kinds.Count)then Kind:=Kinds[I];
      if(I>=0)and(I<NullChecks.Count)and(NullChecks[I]='1')then
        A('      if cdsMain.FieldByName('+QuotedStr(F)+').IsNull then')
      else
        A('      if Trim(cdsMain.FieldByName('+QuotedStr(F)+').AsString) = '''' then');
      A('      begin');
      A('        LEInternal := False;');
      { 记录区里没有控件的字段（例如自动编号主键未放进记录区）不能引用 leFieldN，
        否则生成的脚本会指向不存在的控件；这类字段只提示，不聚焦。 }
      if I>=0 then
        A('        WaitEditorError(UGMM.LT('+QuotedStr(Labels[I])+') + UGMM.LT(''不能为空。''));')
      else
        A('        WaitEditorError(UGMM.LT('+QuotedStr(ColumnCaption(F))+') + UGMM.LT(''不能为空。''));');
      if I>=0 then
        A('        '+ControlName+'.SetFocus; Exit;')
      else
        A('        Exit;');
      A('      end;');
    end;
    if MaxIntNumber then begin
      A('      //预取号不占号；仅对新增重取，避免覆盖已有记录的主键。');
      A('      if LEIsNew then');A('      begin');
      A('        if not (cdsMain.State in [dsEdit, dsInsert]) then cdsMain.Edit;');
      A('        cdsMain.FieldByName('+QuotedStr(Key)+').AsInteger := GetMaxIntNumber;');
      A('        LEKey := cdsMain.FieldByName('+QuotedStr(Key)+').AsString;');A('      end;');
    end;
    A('      if cdsMain.State in [dsEdit, dsInsert] then cdsMain.Post;');A('      ValidateGenericRows;');
    if HasDetail then
    begin
      { 父键取主记录内存里的键值（MaxInt/Guid 提交前已知），随后非空与当前主记录内唯一校验。
        明细校验失败时打标记再抛：外层 except 据此把异常**交回宿主**显示（明细网格可能还挂着
        未提交的编辑，在保存处理里弹阻塞模态会被宿主拒绝）。 }
      A('      try');A('        LEDetailPrepare;');A('        LEDetailCheck;');
      A('      except');A('        LEDetailError := True;');A('        RaiseException(ExceptionMessage);');
      A('      end;');
    end;
    A('    except');A('      if cdsMain.Active and not cdsMain.IsEmpty then cdsMain.Edit;');
    A('      LEInternal := False;');
    if HasDetail then
    begin
      { 明细校验失败：把异常**交回宿主**显示。宿主在"明细网格还挂着未提交编辑"时拒绝阻塞对话框
        （用户 2026-09-20 实测报 `Blocking method Execute() could not be called.`），
        而同族 mtMasterSlave 的保存失败也是 RaiseException 交回宿主、由宿主标准错误框显示
        （用户截图里 `gridMain:TUgDBGrid:请先保存或撤销当前编辑。` 就是这条路）。
        主记录校验/行权限失败仍走下面的 WaitEditorError + 保持编辑态（宿主已验收行为，运行 profile 有断言）。 }
      A('      if LEDetailError then');
      A('      begin');
      A('        //明细校验失败：用 ShowActionError（非阻塞 Show），既不弹阻塞模态、也不把异常抛出去。');
      A('        //宿主在"明细网格还挂着未提交编辑"时拒绝阻塞调用；而异常抛出后框架还会再碰数据集，');
      A('        //会触发主记录守卫再弹一次"请先保存或撤销当前编辑"（宿主 2026-09-20 实测）。');
      A('        ShowActionError(ExceptionMessage);');
      A('        Exit;');
      A('      end;');
    end;
    A('      WaitEditorError(ExceptionMessage); Exit;');A('    end;');
    A('    //反向修改或未改值时不提交空变更包。');
    if HasDetail then A('    if (cdsMain.ChangeCount = 0) and (cdsDetailed.ChangeCount = 0) then')
    else A('    if cdsMain.ChangeCount = 0 then');
    A('    begin');
    A('      cdsMain.CancelUpdates; LEState := 0;');
    A('      ShowNotice(UGMM.LT(''数据没有变化，无需保存。'')); Exit;');A('    end;');
    A('    LEState := 3; LERefresh;');
    if HasDetail then A('    try UGMM.ApplyUpdatesCds(cDataNodeName,[cdsMain,cdsDetailed]);')
    else A('    try cdsMain.SubmitUpdates;');
    A('    except');
    A('      ShowActionError(UGMM.LT(''提交结果待核实，请重新查询核对，禁止重复保存。'') + ExceptionMessage); Exit;');A('    end;');
    A('    LEState := 2;');
    if DBAutoNumber then begin
      A('    //AutoUpdateRefresh 应由服务端回填新主键；未回填时不以 MAX() 猜测并发记录。');
      A('    if LEIsNew then LEKey := cdsMain.FieldByName('+QuotedStr(Key)+').AsString;');
      A('    if LEIsNew and (LEKey = '''') then');
      A('    begin');
      A('      try LEReloadList; ShowNotice(UGMM.LT(''数据已保存成功。数据库未返回自增主键，已刷新列表。''));');
      A('      except ShowActionError(UGMM.LT(''已保存成功，但刷新失败，请重新查询。'') + ExceptionMessage); end;');
      A('      Exit;');
      A('    end;');
    end;
    A('    try');A('      LEReload;');
    A('      if LELocated then ShowNotice(UGMM.LT(''数据已保存成功。''))');
    A('      else ShowNotice(UGMM.LT(''已保存成功，目标记录不在当前查询结果中。''));');
    A('    except ShowActionError(UGMM.LT(''已保存成功，但刷新失败，请重新查询。'') + ExceptionMessage); end;');
    A('  finally LEInternal := False; LEBusy := False; LERefresh; end;');A('end;');
    A('//撤销本次输入及暂存变化，并回到开始编辑前的记录。');
    A('procedure btCancelOnClick(Sender: TObject);');A('begin');
    if ImportOn then
    begin
      A('  if not btCancel.Enabled or ((LEState <> 1) and (LEState <> 4)) then Exit;');
      A('  //导入暂存态：撤销＝放弃全部导入行（尚未提交，CancelUpdates 一次清掉）');
      A('  if LEState = 4 then');
      A('  begin');
      A('    if not ConfirmAction(''是否放弃已导入但未保存的数据？'') then Exit;');
      A('    LEInternal := True;');
      A('    try');
      A('      if cdsMain.Active then cdsMain.CancelUpdates;');
      A('      LEState := 0;');
      A('      LEReloadList;');
      A('    finally LEInternal := False; end;');
      A('    Exit;');
      A('  end;');
    end
    else
      A('  if not btCancel.Enabled or (LEState <> 1) then Exit;');
    A('  if not ConfirmAction(''是否放弃当前修改？'') then Exit;');
    A('  try');A('  LEInternal := True;');A('  try');
    if HasDetail then A('    cdsDetailed.Cancel; cdsDetailed.CancelUpdates;');
    A('    cdsMain.Cancel; cdsMain.CancelUpdates;');
    A('    if LEPreviousKey <> '''' then cdsMain.Locate('+QuotedStr(Key)+', LEPreviousKey, 0);');
    A('    LEState := 0;');A('  finally LEInternal := False; LERefresh; end;');
    A('  except ShowActionError(ExceptionMessage); end;');A('end;');
    if DeleteEnabled then begin
      { 删除后的复核查询（只有配了从表、走级联删除时才生成）：宿主可能"已提交但报错"。 }
      if HasDetail then
      begin
      A('//按主键查一行是否还在（删除后复核用：宿主可能已提交但报错）');
      A('function LERecordExists(const ATable, AKeyField: string; const AKey: Variant): Boolean;');
      A('var C: TUgClientDataSet;');
      A('begin');
      A('  Result := False;');
      A('  if VarToStr(AKey) = '''' then Exit;');
      A('  C := TUgClientDataSet.Create(nil);');
      A('  try');
      A('    C.DataNodeName := cDataNodeName;');
      A('    C.PageRowCount := 1;');
      A('    C.CommandText := ''select '' + AKeyField + '' from '' + ATable + '' where '' + AKeyField + '' = :rowKey'';');
      A('    C.ParamByName(''rowKey'').Value := AKey;');
      A('    C.Open;');
      A('    Result := not C.IsEmpty;');
      A('  finally');
      A('    C.Free;');
      A('  end;');
      A('end;');
      A('');
      end;
    A('//删除当前浏览记录：确认后只提交删除变更，成功后刷新当前查询范围。');
    A('procedure btDeleteOnClick(Sender: TObject);');
    if HasDetail then
    begin
      A('var DeleteKey: Variant; SQL, Failure: string; Logs: TStringList;');
      A('begin');
      A('  DeleteKey := Null;');
      A('  if cdsMain.Active and not cdsMain.IsEmpty then');
      A('    DeleteKey := cdsMain.FieldByName(' + QuotedStr(Key) + ').AsVariant;');
    end
    else A('begin');
    A('  LERefresh;');A('  if not btDelete.Enabled or LEBusy or (LEState <> 0) then Exit;');
    if Hierarchy then
    begin
      { 权限不足按模块统一风格提示并中止，不把脚本异常抛到宿主。 }
      A('  try');
      A('    LECheckRowScope(''删除'');');
      A('  except');
      A('    ShowActionError(ExceptionMessage);');
      A('    Exit;');
      A('  end;');
    end;
    A('  if not ConfirmAction(''是否删除当前记录？'') then Exit;');
    A('  LEBusy := True; LEInternal := True; LERefresh;');A('  try');A('    try');
    if HasDetail then
    begin
      { 配了从表：同一事务删除它自己的明细再删主记录（与 mtMasterSlave 同一写法），不做其它表级联。 }
      A('      SQL := ' + QuotedStr('delete from ' + DetailTable + ' where ' + DetailKey + ' = ') +
        ' + QuotedStr(VarToStr(DeleteKey)) + #13#10 + UGMM.ExecSqlSeparator + #13#10 + ' +
        QuotedStr('delete from ' + TableName + ' where ' + Key + ' = ') + ' + QuotedStr(VarToStr(DeleteKey));');
      A('      Logs := TStringList.Create; Failure := '''';');
      A('      try');
      A('        try UGMM.ExecSql(cDataNodeName, SQL, Logs); except Failure := ExceptionMessage; end;');
      A('        if Failure <> '''' then');
      A('        begin');
      A('          //宿主可能在**已提交之后**才报错（同族 mtMasterSlave 遇到过 CANNOT ROLLBACK - NO TRANSACTION IS ACTIVE；');
      A('          //宿主 2026-09-20 实测还有 FireDACCommon260.bpl 的 Access violation，而记录其实已经删掉）：');
      A('          //失败时以数据库现状为准复核 —— 主表与从表都查不到，就算删除成功。');
      A('          if (not LERecordExists(' + QuotedStr(DetailTable) + ', ' + QuotedStr(DetailKey) + ', DeleteKey)) and');
      A('             (not LERecordExists(' + QuotedStr(TableName) + ', ' + QuotedStr(Key) + ', DeleteKey)) then');
      A('            Failure := '''';');
      A('        end;');
      A('        if Failure <> '''' then');
      A('        begin');
      A('          LEInternal := False;');
      A('          ShowActionError(UGMM.LT(''删除失败：'') + Failure); Exit;');
      A('        end;');
      A('      finally Logs.Free; end;');
      A('      LEState := 2;');
      A('      try LEReloadList; ShowNotice(UGMM.LT(''数据已删除成功。''));');
      A('      except ShowActionError(UGMM.LT(''已删除成功，但刷新失败，请重新查询。'') + ExceptionMessage); end;');
    end
    else
    begin
    A('      cdsMain.Delete;');
    A('      if cdsMain.ChangeCount = 0 then');A('      begin');
    A('        cdsMain.CancelUpdates; LEState := 0;');
    A('        ShowNotice(UGMM.LT(''数据没有变化，无需删除。'')); Exit;');A('      end;');
    A('      LEState := 3; LERefresh;');
    A('      try cdsMain.SubmitUpdates;');A('      except');
    A('        ShowActionError(UGMM.LT(''删除提交结果待核实，请重新查询核对，禁止重复删除。'') + ExceptionMessage); Exit;');A('      end;');
    A('      LEState := 2;');
    A('      try LEReloadList; ShowNotice(UGMM.LT(''数据已删除成功。''));');
    A('      except ShowActionError(UGMM.LT(''已删除成功，但刷新失败，请重新查询。'') + ExceptionMessage); end;');
    end;
    A('    except');
    A('      LEInternal := False;');A('      ShowActionError(ExceptionMessage);');A('    end;');
    A('  finally LEInternal := False; LEBusy := False; LERefresh; end;');A('end;');
    end;
    A('//浏览时执行新查询；提交后的重载保留原查询条件以核实保存结果。');
    A('procedure LEQuery(Sender: TObject);');A('begin');
    A('  if not btQuery.Enabled or (LEState = 1) then Exit;');
    if ImportOn then
    begin
      A('  //导入暂存态：查询会丢弃尚未保存的导入行，先确认再执行');
      A('  if LEState = 4 then');
      A('  begin');
      A('    if not ConfirmAction(''将放弃已导入但未保存的数据并重新查询，是否继续？'') then Exit;');
      A('    LEInternal := True;');
      A('    try');
      A('      if cdsMain.Active then cdsMain.CancelUpdates;');
      A('      LEState := 0;');
      A('      LEReload;');
      A('    finally LEInternal := False; end;');
      A('    LERefresh; Exit;');
      A('  end;');
    end;
    A('  try');A('    if LEState = 0 then btQueryOnClick(Sender)');
    A('    else if ConfirmAction(''将重新加载数据库核对结果，是否继续？'') then');A('    begin');
    A('      LEReload;');
    A('      if not LELocated then ShowNotice(UGMM.LT(''已重新加载，目标记录不在当前查询结果中，请核对数据库。''));');A('    end;');
    A('  except ShowActionError(ExceptionMessage); end;');A('  LERefresh;');A('end;');
    A('//有待处理记录时先确认，确认前不释放数据集或丢弃输入。');
    A('procedure LEClose(Sender: TObject);');A('begin');
    A('  if not btClose.Enabled then Exit;');
    A('  if (LEState <> 0) and not ConfirmAction(''存在未保存或待核实记录，是否关闭？'') then Exit;');
    A('  try');
    A('    LEInternal := True;');A('    try');
    A('      if (LEState <> 0) and cdsMain.Active then');A('      begin');
    if HasDetail then A('        cdsDetailed.Cancel; cdsDetailed.CancelUpdates;');
    A('        cdsMain.Cancel; cdsMain.CancelUpdates;');A('      end;');
    A('      LEState := 0;');A('    finally LEInternal := False; end;');
    A('    LERefresh;');A('    ExecutebtCloseOnClick(Sender);');
    A('  except ShowActionError(ExceptionMessage); end;');A('end;');
    A('//初始化后记录区始终跟随当前数据行，不调用编辑子窗体。');
    A('//运行脚本后');
    A('procedure UgWebRunFrameOnAfterRunScript(const sender: tobject);');A('begin');
    A('  LEReady := False;');A('  try');
    A('    ExecuteUgWebRunFrameOnAfterRunScript(Sender);');
    if PrintEnabled then
    begin
      { 打印沿用原版入口：把报表菜单挂到打印按钮上（与 mtMultiple 同一调用）。 }
      A('    //挂载报表菜单到打印按钮（原版打印入口）');
      A('    UGMM.AddReport(btPrint, UGMM.Informations.Values[''AllowLandingType''] <> ' + QuotedStr('系统用户;') + ', Self.Guid);');
    end;
    if ImportOn then
    begin
      { 导入按钮附加"文本格式 / 电子表格"菜单（原版 btImport.DropdownMenu := pmImport.PopupMenus）。 }
      A('    //导入按钮附加文本格式和电子表格的功能');
      A('    btImport.DropdownMenu := pmImport.PopupMenus;');
    end;
    A('    LEReady := True; LERefresh;');
    A('  except ShowActionError(ExceptionMessage); end;');A('end;');
    Code.AddStrings(Extra);Code.Add('begin');Code.Add('end.');
    FormatTreeScript(Code);
    for I:=LastCode-1 downto FirstCode+1 do Lines.Delete(I);
    for I:=Code.Count-1 downto 0 do Lines.Insert(FirstCode+1,'    '+Enc(Code[I]));
    // Indices changed; locate anchors again instead of reusing offsets.
    for I:=0 to Lines.Count-1 do begin
      Lines[I]:=StringReplace(Lines[I],'btQuery|<This>.OnClick:btQueryOnClick','btQuery|<This>.OnClick:LEQuery',[]);
      Lines[I]:=StringReplace(Lines[I],'btClose|<This>.OnClick:btCloseOnClick','btClose|<This>.OnClick:LEClose',[]);
      if Trim(Lines[I])='Events.Strings = ('then EventAt:=I;
      if Trim(Lines[I])='object pButtons: TUgContainerPanel'then ButtonAt:=I;
    end;
    for I:=Lines.Count-1 downto 0 do
      if Trim(Lines[I])='object cdsMain: TUgClientDataSet' then
        Lines.Insert(I+1,'    AutoUpdateRefresh = True');
    { 导入下拉菜单（原版 pmImport：文本格式 / 电子表格）。作为 cdsMain 的**同级对象**插在它后面，
      并补设计期坐标 —— 非可视控件不给坐标会在设计器里堆到左上角（宿主在 TUgSweetAlert 上报过）。
      它同时被 RelayoutListEditorToolbar 挂到 btImport.DropdownMenu 上。 }
    if ImportOn then
    begin
      J:=-1;
      for I:=0 to Lines.Count-1 do
        if Trim(Lines[I])='object cdsMain: TUgClientDataSet' then
        begin
          for J:=I+1 to Lines.Count-1 do
            if Lines[J]='  end' then Break;
          Break;
        end;
      if J>0 then
      begin
        { 12 行整块：先占位再按行号填，避免用临时列表（Extra 此时装的是脚本文本，不能复用）。 }
        for I:=1 to 12 do Lines.Insert(J+1,'');
        Lines[J+1] :='  object pmImport: TUgPopupMenu';
        Lines[J+2] :='    Left = 20';
        Lines[J+3] :='    Top = 550';
        Lines[J+4] :='    Items = <';
        Lines[J+5] :='      item';
        Lines[J+6] :='        Caption = '+Enc('文本格式');
        Lines[J+7] :='      end';
        Lines[J+8] :='      item';
        Lines[J+9] :='        Caption = '+Enc('电子表格');
        Lines[J+10]:='      end';
        Lines[J+11]:='    >';
        Lines[J+12]:='  end';
      end;
    end;
    { 工具栏的生成与插入都搬到了 RelayoutListEditorToolbar（由模板在 AddListEditorPresentation
      之后调用）：「展开查询」按钮是那一步插进工具条的，重排必须能看到它，否则会出现同名重复对象。
      注意：这里**不能**再插 Extra —— 上面的 Code.AddStrings(Extra) 之后 Extra 里装的是脚本文本，
      插进工具条面板会把 DFM 结构写坏（DFM 校验报 "Identifier expected"）。 }
    { **不再**给 cdsMain 挂 BeforeScroll/BeforeClose/BeforePost/BeforeDelete 守卫。
      宿主 2026-09-20 实测：在明细网格里编辑后点保存，框架会先提交明细的网格编辑并顺带碰主数据集，
      守卫在这个时机误报"请先保存或撤销当前编辑"（而且比真正的校验提示还早弹）。
      同族 mtMasterSlave 也没有这种守卫——它只在按钮处理里显式检查（if vEditing then RaiseException(...)）。
      本模板面向用户的入口本来就按状态拦住了：编辑态下 gridMain.Enabled=False、pPages.Enabled=False，
      查询/删除/关闭/新增/修改各有 LEState 检查，所以不会丢输入。 }
    if HasDetail then
    begin
      { 明细行按钮的事件绑定：只绑定**勾选的**（与生成的面板按钮一一对应）。 }
      for F in TArray<string>.Create('btDetailAppend','btDetailInsert','btDetailDelete',
        'btDetailCopy','btDetailMoveUp','btDetailMoveDown','btDetailClear')do
        if Buttons.IndexOf(F) >= 0 then
          Events.Add('    '+QuotedStr(F+'|<This>.OnClick:'+F+'OnClick'));
      { 明细数据集只挂 BeforePost（落库前补父键）。**不挂 BeforeScroll/BeforeClose 守卫**：
        明细行的编辑是直接在网格里做的，宿主实测连续点"新增行"会因未落库的插入行触发滚动而被守卫拦下
        （提示"请先提交或取消当前明细行的修改"）；同族的 mtMasterSlave 也没有这个守卫，
        它用"空白占位行当场落库"的模型避免了这个状态。 }
      Events.Add('    '+QuotedStr('cdsDetailed|<This>.BeforePost:LEDetailBeforePost'));
    end;
    Events.Add('    ''cdsMain|<This>.AfterScroll:LEAfterScroll''');
    for I:=Events.Count-1 downto 0 do Lines.Insert(EventAt+1,Events[I]);
    { 早前这里还会把 tabFormGroup/btClose 的 Left 按 X 重排一遍；现在工具条的 Left 由
      RelayoutListEditorToolbar 按原版参考件统一排，重复改会把位置写乱（而且它会在工具条之外
      再造一个同名 tabFormGroup 的 Left），所以整段去掉。 }
    for I:=Lines.Count-1 downto 0 do
      for J:=0 to Fields.Count-1 do
        if (Pos('object leField'+IntToStr(J)+': ',Trim(Lines[I]))=1) and
           (Required.IndexOf(Fields[J])>=0) then
        begin
          { 复选的标题走 Caption，用 Font.Color 标红；其余控件标 FieldLabel。 }
          Kind:='';if J<Kinds.Count then Kind:=Kinds[J];
          if Kind='check' then Lines.Insert(I+1,'      Font.Color = clRed')
          else Lines.Insert(I+1,'      FieldLabelFont.Color = clRed');
        end;
    Result:=True;
  finally
    Buttons.Free;
    Auto.Free;Rule.Free;Events.Free;Extra.Free;Code.Free;UniqueFields.Free;Required.Free;Labels.Free;Fields.Free;Kinds.Free;NullChecks.Free;
  end;
end;

{ 工具栏重排（宿主 2026-09-21）：按钮顺序、图标位、组间 1px 分隔面板全部对齐原版 list editor 参考件
  （fixtures/list-editor/user-reference-20260917.dfm，与 mtDetail 同表）。
  **必须在 AddListEditorPresentation 之后调用**：「展开查询」按钮是那一步插进工具条的，
  重排要连它一起排（否则同名对象重复，宿主加载 DFM 直接报错）。
  本函数自己往 Events.Strings 写按钮事件绑定（查询/关闭/展开查询由显示模板绑定，打印由宿主挂报表菜单）。 }
procedure RelayoutListEditorToolbar(Config: TJSONObject; Lines: TStringList);
var Buttons, Extra, Events: TStringList;
  I, J, X, EventAt, ToggleIcon: Integer; F: string; DeleteOn, ExportOn, PrintOn, AnnexOn, ImportOn: Boolean;

  { 工具栏顺序/图标/分组：与原版 list editor 参考件（fixtures/list-editor/user-reference-20260917.dfm）
    和 mtDetail 同表 —— 宿主 2026-09-21 要求"布局与分隔对齐 mtDetail"。
    原版没有附件按钮，图标位 18 取自 mtDetail（两表在 16/17/23 上一致，可判定同一套图片列表）。
    「展开查询」是本模板的扩展（原版没有）：用查询图标(0)，避免猜一个索引显示成无关图标。
    导入按原版排在「修改」之后、「保存」之前，图标位 10（原版 btImport.ImageIndex = 10，
    正好对应 mtDetail 图片表里的 icon-ico_daoru_xuanzhong）。 }
  function ToolbarOrder(const AIndex: Integer): string;
  begin
    case AIndex of
      0: Result := 'btQuery'; 1: Result := 'btAppend'; 2: Result := 'btDelete';
      3: Result := 'btEditor'; 4: Result := 'btImport'; 5: Result := 'btSave';
      6: Result := 'btCancel'; 7: Result := 'btExport'; 8: Result := 'btPrint';
      9: Result := 'btAnnex'; 10: Result := 'btToggleQuery'; 11: Result := 'btClose';
    else Result := '';
    end;
  end;

  function ToolbarIcon(const AName: string): Integer;
  begin
    if AName = 'btQuery' then Result := 0
    else if AName = 'btAppend' then Result := 7
    else if AName = 'btDelete' then Result := 8
    else if AName = 'btEditor' then Result := 9
    else if AName = 'btImport' then Result := 10
    else if AName = 'btSave' then Result := 11
    else if AName = 'btCancel' then Result := 12
    else if AName = 'btExport' then Result := 16
    else if AName = 'btPrint' then Result := 17
    else if AName = 'btAnnex' then Result := 18
    { 展开查询：用 Imgs 里 icon-pingmufangda 的索引（由 EnsureToggleQueryIcon 注入到 ToggleIcon）。 }
    else if AName = 'btToggleQuery' then Result := ToggleIcon
    else Result := 23;
  end;

  function ToolbarGroup(const AName: string): string;
  begin
    if AName = 'btAppend' then Result := 'tabEditorGroup'
    else if AName = 'btSave' then Result := 'tabAppendUpdateGroup'
    else if AName = 'btExport' then Result := 'tabOutputGroup'
    else if AName = 'btAnnex' then Result := 'tabAnnexGroup'
    else if AName = 'btClose' then Result := 'tabFormGroup'
    else Result := '';
  end;

  { 组间分隔面板的名字（与原版参考件同名）。 }
  function ToolbarSeparatorName(const AIndex: Integer): string;
  begin
    case AIndex of
      0: Result := 'tabEditorGroup'; 1: Result := 'tabAppendUpdateGroup';
      2: Result := 'tabOutputGroup'; 3: Result := 'tabAnnexGroup';
      4: Result := 'tabFormGroup';
    else Result := '';
    end;
  end;

  { mtDetail 参考件（fixtures/reference/mtDetail.dfm）里 Imgs.IconText 的 27 项，顺序原样 ——
    宿主 2026-09-21 要求"mtListEditor 的 Imgs 数据直接按 mtDetail 来"，这样两边图标索引一致
    （内嵌模板里的列表只有 14 项，直接用会把 16/17/18/23 这些索引指到界外）。
    末尾再追加「展开查询」的 icon-pingmufangda（宿主指定），索引 27。 }
  function DetailIconClasses(const AIndex: Integer): string;
  const
    CList: array[0..26] of string = (
      'icon-chaxun',
      'icon-quanxuan',
      'icon-fanxuan',
      'icon-skipprevious',
      'icon-xiangzuo',
      'icon-xiangyou',
      'icon-skipnext',
      'icon-addEdge',
      'icon-shanchu1',
      'icon-xiugai1',
      'icon-ico_daoru_xuanzhong',
      'icon-baocun',
      'icon-chexiao4',
      'icon-shenhe',
      'icon-quxiaoshenhe',
      'icon-dahui',
      'icon-web-icon-',
      'icon-dayin4',
      'icon-fujian',
      'icon-bangdingpingtai',
      'icon-xiangshang',
      'icon-xiangxia',
      'icon-guanbishixin',
      'icon-guanbi3',
      'icon-gouxuan',
      'icon-cuocha_kuai',
      'icon-shezhi_2');
  begin
    if (AIndex >= 0) and (AIndex <= High(CList)) then Result := CList[AIndex]
    else Result := '';
  end;

  { 把 Imgs 的 IconText 换成 mtDetail 的图标列表（27 项）+ 追加 icon-pingmufangda，
    并返回 pingmufangda 的索引（27）。找不到 Imgs/IconText 时返回 -1（调用方退回旧图标位）。 }
  function ApplyDetailIconList: Integer;
  var I, J, First, Last, K: Integer; Indent: Integer; S: string;
  begin
    Result := -1;
    I := -1;
    for J := 0 to Lines.Count - 1 do
      if Trim(Lines[J]) = 'object Imgs: TUGIconClsList' then begin I := J; Break; end;
    if I < 0 then Exit;
    First := -1; Last := -1;
    for J := I + 1 to Lines.Count - 1 do
    begin
      if Trim(Lines[J]) = 'end' then Break;
      if Pos('IconText = ', Trim(Lines[J])) = 1 then First := J
      else if First >= 0 then Last := J;
    end;
    if First < 0 then Exit;
    if Last < First then Last := First;
    S := '';
    for K := 0 to 26 do
      S := S + '''' + 'icon iconfont ' + DetailIconClasses(K) + '''' + '#13#10';
    { 宿主 2026-09-21 提供的三个明细行图标类名，按序追加：28 复制行 / 29 插入行 / 30 清空
      （展开查询 pingmufangda 是 27）。 }
    S := S + '''' + 'icon iconfont icon-pingmufangda' + '''' + '#13#10';
    S := S + '''' + 'icon iconfont icon-fuzhi' + '''' + '#13#10';
    S := S + '''' + 'icon iconfont icon-caidanshouqi' + '''' + '#13#10';
    S := S + '''' + 'icon iconfont icon-guanbi2fill' + '''' + '#13#10';
    Indent := Length(Lines[First]) - Length(TrimLeft(Lines[First]));
    Lines[First] := StringOfChar(' ', Indent) + 'IconText = ' + S;
    for J := Last downto First + 1 do Lines.Delete(J);
    Result := 27;
  end;

  function ToolbarWidth(const AName: string): Integer;
  begin
    { 菜单型按钮（打印挂报表菜单、导入挂文本/电子表格菜单）宽 75，普通按钮 60（与原版一致）。 }
    if (AName = 'btPrint') or (AName = 'btImport') then Result := 75 else Result := 60;
  end;

  function ToolbarCaption(const AName: string): string;
  begin
    if AName = 'btQuery' then Result := '查询'
    else if AName = 'btAppend' then Result := '新增'
    else if AName = 'btDelete' then Result := '删除'
    else if AName = 'btEditor' then Result := '修改'
    else if AName = 'btImport' then Result := '导入'
    else if AName = 'btSave' then Result := '保存'
    else if AName = 'btCancel' then Result := '撤销'
    else if AName = 'btExport' then Result := '导出'
    else if AName = 'btPrint' then Result := '打印'
    else if AName = 'btAnnex' then Result := '附件'
    else if AName = 'btToggleQuery' then Result := '展开查询'
    else Result := '关闭';
  end;

  { 重排前先删掉 pButtons 里同名对象的整块（显示模板造的 + 本单元旧版造的），避免出现重复对象。
    只匹配与 object 头**同缩进**的 end，所以不会误删按钮内部的嵌套对象。 }
  procedure DropToolbarChild(const AName: string);
  var I, J, K, Indent: Integer; S: string;
  begin
    for I := 0 to Lines.Count - 1 do
    begin
      S := Trim(Lines[I]);
      if Pos('object ' + AName + ': ', S) <> 1 then Continue;
      Indent := Length(Lines[I]) - Length(TrimLeft(Lines[I]));
      J := I + 1;
      while J < Lines.Count do
      begin
        if (Trim(Lines[J]) = 'end') and
           (Length(Lines[J]) - Length(TrimLeft(Lines[J])) = Indent) then
        begin
          { TStrings.DeleteRange 在 Delphi 10.3 没有，按块长度循环删。 }
          for K := 1 to (J - I + 1) do Lines.Delete(I);
          Exit;
        end;
        Inc(J);
      end;
      Exit;
    end;
  end;

  { 组间分隔面板：与原版参考件同款（1px 宽、颜色 13093060、上下 Margins 5）。 }
  procedure EmitToolbarSeparator(const AName: string; AX: Integer);
  begin
    Extra.Add('    object ' + AName + ': TUgContainerPanel');
    Extra.Add('      AlignWithMargins = True');
    Extra.Add('      Left = ' + IntToStr(AX));
    Extra.Add('      Top = 5');
    Extra.Add('      Width = 1');
    Extra.Add('      Height = 22');
    Extra.Add('      Hint = ''''');
    Extra.Add('      Margins.Top = 5');
    Extra.Add('      Margins.Bottom = 5');
    Extra.Add('      ParentColor = False');
    Extra.Add('      Color = 13093060');
    Extra.Add('      Align = alLeft');
    Extra.Add('      TabOrder = 0');
    Extra.Add('    end');
  end;

  procedure EmitToolbarButton(const AName: string; AX: Integer);
  begin
    { 菜单型按钮：打印（宿主挂报表菜单）、导入（文本格式/电子表格菜单）。 }
    if (AName = 'btPrint') or (AName = 'btImport') then Extra.Add('    object ' + AName + ': TUgMenuButton')
    else Extra.Add('    object ' + AName + ': TUgButton');
    Extra.Add('      AlignWithMargins = True');
    Extra.Add('      Align = alLeft');
    Extra.Add('      Left = ' + IntToStr(AX));
    Extra.Add('      Top = 3');
    Extra.Add('      Width = ' + IntToStr(ToolbarWidth(AName)));
    Extra.Add('      Height = 26');
    Extra.Add('      Hint = ''''');
    { 打印由宿主在初始化时挂报表菜单、查询/关闭/展开查询由显示模板管理初始可用性，
      其余按钮等状态刷新（LERefresh）后可用。 }
    if (AName <> 'btPrint') and (AName <> 'btQuery') and (AName <> 'btClose') and
       (AName <> 'btToggleQuery') then
      Extra.Add('      Enabled = False');
    Extra.Add('      AutoWidth = True');
    Extra.Add('      Images = Imgs');
    Extra.Add('      ImageIndex = ' + IntToStr(ToolbarIcon(AName)));
    Extra.Add('      Caption = ' + Enc(ToolbarCaption(AName)));
    Extra.Add('    end');
  end;

begin
  Buttons := TStringList.Create; Extra := TStringList.Create; Events := TStringList.Create;
  try
    Buttons.StrictDelimiter := True; Buttons.Delimiter := ';';
    Buttons.DelimitedText := S(Config, 'TWebFunctionButton');
    DeleteOn := Buttons.IndexOf('btDelete') >= 0;
    ExportOn := Buttons.IndexOf('btExport') >= 0;
    PrintOn := Buttons.IndexOf('btPrint') >= 0;
    AnnexOn := Buttons.IndexOf('btAnnex') >= 0;
    ImportOn := Buttons.IndexOf('btImport') >= 0;
    { 「展开查询」的图标：先确保 Imgs 里有 icon-pingmufangda（宿主指定），拿到它的索引。 }
    ToggleIcon := ApplyDetailIconList;
    { 先删掉这些按钮与分隔面板的旧对象（显示模板造的 + 上一版造的），再按原版顺序/图标/分组重排。
      分隔面板必须一起删：显示模板里已有一个 tabFormGroup，不删就会同名重复
      （宿主加载 DFM 报 "A component named tabFormGroup already exists"）。 }
    for I := 0 to 11 do DropToolbarChild(ToolbarOrder(I));
    for I := 0 to 4 do DropToolbarChild(ToolbarSeparatorName(I));
    X := 3;
    for I := 0 to 11 do
    begin
      F := ToolbarOrder(I);
      if F = 'btDelete' then if not DeleteOn then Continue;
      if F = 'btExport' then if not ExportOn then Continue;
      if F = 'btPrint' then if not PrintOn then Continue;
      if F = 'btAnnex' then if not AnnexOn then Continue;
      if F = 'btImport' then if not ImportOn then Continue;
      if ToolbarGroup(F) <> '' then
      begin
        EmitToolbarSeparator(ToolbarGroup(F), X);
        Inc(X, 7);
      end;
      EmitToolbarButton(F, X);
      Inc(X, ToolbarWidth(F) + 6);
      { 查询/关闭/展开查询的事件由显示模板绑定；打印由宿主挂报表菜单；其余是本单元的入口。
        导入按钮的 OnClick 同样绑在本单元，它的下拉菜单（pmImport）额外绑 UgMenuItemsOnClick。 }
      if (F <> 'btPrint') and (F <> 'btQuery') and (F <> 'btClose') and (F <> 'btToggleQuery') then
        Events.Add('    ' + QuotedStr(F + '|<This>.OnClick:' + F + 'OnClick'));
      if F = 'btImport' then
        Events.Add('    ' + QuotedStr('pmImport|<This>.UgMenuItemsOnClick:pmImportUgMenuItemsOnClick'));
    end;
    { 插到工具条面板的第一个子控件之前。 }
    J := -1;
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) = 'object pButtons: TUgContainerPanel' then
      begin
        J := I + 1;
        while (J < Lines.Count) and (Pos('object ', Trim(Lines[J])) <> 1) do Inc(J);
        Break;
      end;
    if J < 0 then Exit;
    for I := Extra.Count - 1 downto 0 do Lines.Insert(J, Extra[I]);
    { 事件绑定写进 Events.Strings。 }
    EventAt := -1;
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) = 'Events.Strings = (' then begin EventAt := I; Break; end;
    if EventAt < 0 then Exit;
    for I := Events.Count - 1 downto 0 do Lines.Insert(EventAt + 1, Events[I]);
  finally
    Events.Free; Extra.Free; Buttons.Free;
  end;
end;


end.
