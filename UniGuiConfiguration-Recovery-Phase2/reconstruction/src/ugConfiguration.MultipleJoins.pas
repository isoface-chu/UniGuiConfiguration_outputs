unit ugConfiguration.MultipleJoins;

interface

uses System.SysUtils, System.Classes, System.JSON;

function BuildMultipleJoins(Tables, Columns: TJSONObject; Aliases: TStrings): string;
function MultipleOutputField(const Qualified, RootAlias: string; Aliases: TStrings): string;
procedure AddMultipleJoinWrite(Code: TStrings; Tables, Columns: TJSONObject;
  Fields, Sources: TStrings; const RootAlias, JoinSQL: string);

implementation

uses System.Generics.Collections;

function S(J: TJSONObject; const Key: string): string;
var V: TJSONValue;
begin
  Result := '';
  if J = nil then Exit;
  V := J.GetValue(Key);
  if (V <> nil) and not (V is TJSONNull) then Result := V.Value;
end;

function Row(J: TJSONObject; I: Integer): TJSONObject;
var V: TJSONValue;
begin
  Result := nil;
  if J = nil then Exit;
  V := J.GetValue(IntToStr(I));
  if V is TJSONObject then Result := TJSONObject(V);
end;

function Ident(const V: string): Boolean;
var I: Integer;
begin
  Result := False;
  if V = '' then Exit;
  for I := 1 to Length(V) do
    if not CharInSet(V[I], ['a'..'z','A'..'Z','_','0'..'9']) then Exit;
  Result := not CharInSet(V[1], ['0'..'9']);
end;

function HasField(Columns: TJSONObject; const Qualified: string): Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to Columns.Count-1 do
    if SameText(S(Row(Columns,I),'fdCOLUMN_NAME'),Qualified) then Exit(True);
end;

function MultipleOutputField(const Qualified, RootAlias: string; Aliases: TStrings): string;
var P: Integer; A, F: string;
begin
  Result := '';
  P := Pos('.',Qualified);
  A := Copy(Qualified,1,P-1); F := Copy(Qualified,P+1,MaxInt);
  if not Ident(A) or not Ident(F) or (Aliases.IndexOf(A)<0) then Exit;
  if SameText(A,RootAlias) then Result := F else Result := A+F;
end;

procedure AddMultipleJoinWrite(Code: TStrings; Tables, Columns: TJSONObject;
  Fields, Sources: TStrings; const RootAlias, JoinSQL: string);
var I, J, P: Integer; V, L, RHS, Keys, Filter, SQL, RootTable: string;
  procedure A(const Text: string);
  begin Code.Add(Text); end;
  procedure QueryText(const Text: string);
  var Offset: Integer;
  begin
    A('    C.CommandText :=');
    Offset := 1;
    while Offset <= Length(Text) do begin
      if Offset+160 > Length(Text) then
        A('      '+QuotedStr(Copy(Text,Offset,160))+';')
      else A('      '+QuotedStr(Copy(Text,Offset,160))+' +');
      Inc(Offset,160);
    end;
  end;
  function IsRoot(const Source: string): Boolean;
  begin Result := SameText(Copy(Source,1,Length(RootAlias)+1),RootAlias+'.'); end;
begin
  RootTable := S(Row(Tables,0),'fdTableName');
  //宿主按真实主表字段名写回；包括未勾选字段在内都不能与关联输出同名。
  for I := 0 to Fields.Count-1 do
    if not IsRoot(Sources[I]) and HasField(Columns,RootAlias+'.'+Fields[I]) then
      raise Exception.Create('关联输出字段与基础表字段冲突：'+Fields[I]);
  for I := 1 to Tables.Count-1 do
    for J := 1 to 3 do begin
      V := S(Row(Tables,I),'fdCriteria'+IntToStr(J));
      if Trim(V)='' then Continue;
      L := Trim(Copy(V,1,Pos('=',V)-1));
      if IsRoot(L) and (Sources.IndexOf(L)<0) then
        raise Exception.Create('关联写回需要选择基础表关联键：'+L);
    end;
  A('//核对真实主表字段和关联唯一性，避免关联展示列误写或主表行重复展开');
  A('procedure CheckMultipleJoin;');
  A('var C: TUgClientDataSet; I: Integer;'); A('begin');
  A('  C := TUgClientDataSet.Create(nil);'); A('  try');
  A('    C.DataNodeName := cDataNodeName;'); A('    C.PageRowCount := 1;');
  A('    C.CommandText := '+QuotedStr('select * from '+RootTable+' where 1 = 2')+';');
  A('    C.Open;');
  for I := 0 to Fields.Count-1 do if not IsRoot(Sources[I]) then begin
    A('    for I := 0 to C.FieldCount - 1 do');
    A('      if UpperCase(C.Fields[I].FieldName) = '+QuotedStr(UpperCase(Fields[I]))+' then');
    A('        RaiseException(UGMM.LT('+QuotedStr('关联输出字段与基础表字段冲突：'+Fields[I])+'));');
  end;
  for I := 1 to Tables.Count-1 do begin
    Keys := ''; Filter := '';
    for J := 1 to 3 do begin
      V := S(Row(Tables,I),'fdCriteria'+IntToStr(J));
      if Trim(V)='' then Continue;
      RHS := Trim(Copy(V,Pos('=',V)+1,MaxInt));
      RHS := Copy(RHS,Pos('.',RHS)+1,MaxInt);
      if Keys<>'' then begin Keys:=Keys+', '; Filter:=Filter+' and '; end;
      Keys:=Keys+RHS; Filter:=Filter+RHS+' is not null';
    end;
    A('    C.Close;');
    QueryText('select '+Keys+' from '+S(Row(Tables,I),'fdTableName')+
      ' where '+Filter+' group by '+Keys+' having count(*) > 1');
    A('    C.Open;');
    A('    if not C.IsEmpty then');
    A('      RaiseException(UGMM.LT('+QuotedStr('关联表 ['+S(Row(Tables,I),'fdTableName')+
      '] 匹配字段 ['+Keys+'] 存在重复，请先检查关联数据。')+'));');
  end;
  A('  finally'); A('    C.Free;'); A('  end;'); A('end;'); A('');
  A('//按当前暂存值回显完整关联链；不重开主数据集，不写入关联表');
  A('procedure RefreshMultipleJoin;');
  A('var C: TUgClientDataSet; F: TField; WasReadOnly: Boolean;');
  A('begin'); A('  C := TUgClientDataSet.Create(nil);'); A('  try');
  A('    C.DataNodeName := cDataNodeName;'); A('    C.PageRowCount := 2;');
  SQL := 'select '; P := 0;
  for I := 0 to Fields.Count-1 do if not IsRoot(Sources[I]) then begin
    if P>0 then SQL:=SQL+', '; Inc(P);
    SQL:=SQL+Sources[I]+' as '+Fields[I];
  end;
  if P=0 then SQL:=SQL+'1 as JoinMatch';
  SQL:=SQL+' from (select '; P:=0;
  for I:=0 to Fields.Count-1 do if IsRoot(Sources[I]) then begin
    if P>0 then SQL:=SQL+', '; Inc(P);
    SQL:=SQL+':joinKey'+IntToStr(I)+' as '+Fields[I];
  end;
  SQL:=SQL+') '+RootAlias+JoinSQL;
  QueryText(SQL);
  for I:=0 to Fields.Count-1 do if IsRoot(Sources[I]) then begin
    A('    C.ParamByName('+QuotedStr('joinKey'+IntToStr(I))+').DataType := cdsMain.FieldByName('+QuotedStr(Fields[I])+').DataType;');
    A('    C.ParamByName('+QuotedStr('joinKey'+IntToStr(I))+').Value := cdsMain.FieldByName('+QuotedStr(Fields[I])+').AsVariant;');
  end;
  A('    C.Open;'); A('    if C.RecordCount > 1 then');
  A('      RaiseException(UGMM.LT(''关联链存在多个匹配结果，请检查各关联表的组合匹配字段。''));');
  for I:=0 to Fields.Count-1 do if not IsRoot(Sources[I]) then begin
    A('    F := cdsMain.FieldByName('+QuotedStr(Fields[I])+');');
    A('    WasReadOnly := F.ReadOnly;'); A('    F.ReadOnly := False;'); A('    try');
    A('      if C.IsEmpty then F.AsVariant := Null');
    A('      else F.AsVariant := C.FieldByName('+QuotedStr(Fields[I])+').AsVariant;');
    A('    finally'); A('      F.ReadOnly := WasReadOnly;'); A('    end;');
  end;
  A('  finally'); A('    C.Free;'); A('  end;'); A('end;'); A('');
end;

function BuildMultipleJoins(Tables, Columns: TJSONObject; Aliases: TStrings): string;
var Ordered: TList<TJSONObject>; R, P, C: TJSONObject;
  I,J,K,N,X: Integer; Added: Boolean; A,PA,V,L,RHS,Clause,Pair: string;
  Pairs,Ids: TStringList;
begin
  Result := ''; Aliases.Clear;
  Ordered := TList<TJSONObject>.Create;
  Pairs := TStringList.Create; Ids := TStringList.Create;
  try
    R := Row(Tables,0);
    if (R=nil) or (S(R,'fdParent')<>'') then raise Exception.Create('关联查询必须有一张根主表。');
    Ordered.Add(R);
    for I:=0 to Tables.Count-1 do begin
      C:=Row(Tables,I);
      if C=nil then raise Exception.Create('关联表配置缺少数字行键。');
      A:=S(C,'fdEpithet');
      if not Ident(A) or not Ident(S(C,'fdTableName')) then
        raise Exception.Create('关联表名及别名须为简单标识符。');
      if Aliases.IndexOf(A)>=0 then raise Exception.Create('关联表别名不能重复。');
      Aliases.Add(A);
      if Tables.Count>1 then begin
        V:=S(C,'fdGuid');
        if (V='') or (Ids.IndexOf(V)>=0) then raise Exception.Create('关联表GUID不能为空或重复。');
        Ids.Add(V);
      end;
    end;
    while Ordered.Count<Tables.Count do begin
      Added:=False;
      for I:=1 to Tables.Count-1 do begin
        C:=Row(Tables,I);
        if Ordered.Contains(C) then Continue;
        for J:=0 to Ordered.Count-1 do
          if SameText(S(C,'fdParent'),S(Ordered[J],'fdGuid')) then begin
            Ordered.Add(C);Added:=True;Break;
          end;
      end;
      if not Added then raise Exception.Create('关联表父级不存在或存在循环关联。');
    end;
    for I:=1 to Ordered.Count-1 do begin
      C:=Ordered[I];P:=nil;
      for J:=0 to I-1 do
        if SameText(S(C,'fdParent'),S(Ordered[J],'fdGuid')) then P:=Ordered[J];
      A:=S(C,'fdEpithet');PA:=S(P,'fdEpithet');
      if not SameText(Trim(S(C,'fdAssociationMethod')),'left join') then
        raise Exception.Create('关联查询当前支持 LEFT JOIN，与 mtMasterSlave 的已实现规则一致。');
      Clause:='';N:=0;Pairs.Clear;
      for K:=1 to 3 do begin
        V:=Trim(S(C,'fdCriteria'+IntToStr(K)));
        if V='' then Continue;
        if N<>K-1 then raise Exception.Create('关联条件须从第一组开始连续填写。');
        X:=Pos('=',V);L:=Trim(Copy(V,1,X-1));RHS:=Trim(Copy(V,X+1,MaxInt));
        if (X=0) or not SameText(Copy(L,1,Length(PA)+1),PA+'.') or
          not SameText(Copy(RHS,1,Length(A)+1),A+'.') or
          not Ident(Copy(L,Length(PA)+2,MaxInt)) or not Ident(Copy(RHS,Length(A)+2,MaxInt)) or
          not HasField(Columns,L) or not HasField(Columns,RHS) then
          raise Exception.Create('关联条件须为有效的父表字段 = 当前关联表字段。');
        Pair:=L+' = '+RHS;
        if Pairs.IndexOf(Pair)>=0 then raise Exception.Create('关联条件不能重复。');
        Pairs.Add(Pair);Inc(N);
        if Clause<>'' then Clause:=Clause+' and ';
        Clause:=Clause+Pair;
      end;
      if N=0 then raise Exception.Create('关联表必须填写第一组匹配条件。');
      Result:=Result+' left join '+S(C,'fdTableName')+' '+A+' on '+Clause;
    end;
  finally Ids.Free;Pairs.Free;Ordered.Free;end;
end;

end.
