unit ugConfiguration.MultipleRecord;

interface
uses System.SysUtils, System.Classes;

procedure AddMultipleRecordEditor(Code, Fields: TStrings; const KeyField,
  Editor: string; const AuditFields: array of string; AutoNumber:Boolean=False; Validate:Boolean=False; JoinRefresh:Boolean=False; NewRecordInit:TStrings=nil; EditorInputFields:TStrings=nil);
procedure AddMultipleRecordImport(Code, Fields, Captions: TStrings;
  const KeyField: string; const AuditFields: array of string; AutoNumber:Boolean=False; Validate:Boolean=False; JoinRefresh:Boolean=False);
procedure AddMultipleValidation(Code,RequiredFields,UniqueFields,Fields,Captions:TStrings;
  const TableName,KeyField:string; IdentityKey:Boolean);
procedure AddMultiplePageLocator(Code:TStrings; const AliasName,KeyField:string;
  QueryCount,FilterCount:Integer; Operators:TStrings);
procedure AddMultipleAutoNumber(Code:TStrings; const TableName, KeyField,
  AutoType, Prefix, Suffix, Digits:string);
procedure AddMaxIntNumber(Code:TStrings; const TableName,KeyField:string);

implementation

procedure AddMaxIntNumber(Code:TStrings; const TableName,KeyField:string);
  procedure A(const V:string);begin Code.Add(V);end;
begin
  A('//读取根表全部数据的最大INT，不使用界面的查询、分页或过滤条件。');
  A('//空表从1开始；这里只取候选号，不占号，最终必须由数据库主键/唯一约束防重。');
  A('function GetMaxIntNumber: Integer;');
  A('var C: TUgClientDataSet; V: Variant; N: Integer;');
  A('begin');
  A('  C := TUgClientDataSet.Create(nil);');
  A('  try');
  A('    C.DataNodeName := cDataNodeName;');
  A('    C.PageRowCount := 1;');
  A('    C.CommandText := '+QuotedStr('select max('+KeyField+') as AutoIntMax from '+TableName)+';');
  A('    C.Open;');
  A('    N := 0;');
  A('    if not C.FieldByName(''AutoIntMax'').IsNull then');
  A('    begin');
  A('      V := C.FieldByName(''AutoIntMax'').AsVariant;');
  A('      if (V >= 2147483647) or (V < (-2147483647 - 1)) then');
  A('        RaiseException(UGMM.LT(''最大整数编号超出INT范围，不能继续新增。''));');
  A('      N := V;');
  A('    end;');
  A('    Result := N + 1;');
  A('  finally');
  A('    C.Free;');
  A('  end;');
  A('end;');A('');
end;

procedure AddMultiplePageLocator(Code:TStrings; const AliasName,KeyField:string;
  QueryCount,FilterCount:Integer; Operators:TStrings);
var K:Integer;
  procedure A(const S:string);
  begin Code.Add(S);end;
begin
  A('//复制已执行查询的参数，不读取尚未执行的新输入条件');
  A('procedure CopyLocateParameter(C: TUgClientDataSet; const AName: string);');
  A('var P: TParam;');
  A('begin');
  A('  P := cdsMain.Params.FindParam(AName);');
  A('  if P = nil then Exit;');
  A('  C.ParamByName(AName).DataType := P.DataType;');
  A('  C.ParamByName(AName).Value := P.Value;');
  A('end;');A('');
  A('//在相同查询和权限范围内计算记录所在页；仅用于生成器的记录键升序');
  A('function FindSavedRecordPage(AKey: Variant): Integer;');
  A('const KeyOrder = '+QuotedStr(' order by '+AliasName+'.'+KeyField)+';');
  A('var C: TUgClientDataSet; BaseSQL, P: string; I: Integer;');
  A('begin');
  A('  Result := -1;');
  A('  BaseSQL := cdsMain.CommandText;');
  A('  if cdsMain.PageRowCount < 1 then Exit;');
  A('  if Copy(BaseSQL, Length(BaseSQL) - Length(KeyOrder) + 1, Length(KeyOrder)) <> KeyOrder then Exit;');
  A('  BaseSQL := Copy(BaseSQL, 1, Length(BaseSQL) - Length(KeyOrder));');
  A('  C := TUgClientDataSet.Create(nil);');
  A('  try');
  A('    C.DataNodeName := cDataNodeName;');
  A('    C.PageRowCount := 1;');
  A('    C.CommandText := ''select count(*) as BeforeCount from ('' + BaseSQL');
  A('      + '+QuotedStr(') __ug_loc where __ug_loc.'+KeyField+' < :__ugLocateKey')+';');
  if QueryCount>0 then begin
    A('    for I := 0 to '+IntToStr(QueryCount-1)+' do');
    A('      CopyLocateParameter(C, ''p'' + IntToStr(I));');
  end;
  if FilterCount>0 then begin
    A('    for I := 0 to '+IntToStr(FilterCount-1)+' do');
    A('      CopyLocateParameter(C, ''gf'' + IntToStr(I));');
  end;
  for K:=0 to Operators.Count-1 do if Operators[K]='in' then begin
    A('    //复制原查询的 IN 参数，保存定位不受当前输入框改动影响');
    A('    for I := 0 to 899 do');
    A('    begin');
    A('      P := '+QuotedStr('p'+IntToStr(K)+'_in')+' + IntToStr(I);');
    A('      if cdsMain.Params.FindParam(P) = nil then Break;');
    A('      CopyLocateParameter(C, P);');
    A('    end;');
  end;
  A('    C.ParamByName(''__ugLocateKey'').Value := AKey;');
  A('    C.Open;');
  A('    Result := C.FieldByName(''BeforeCount'').AsInteger div cdsMain.PageRowCount + 1;');
  A('  finally');
  A('    C.Free;');
  A('  end;');
  A('end;');A('');
end;

procedure AddMultipleValidation(Code,RequiredFields,UniqueFields,Fields,Captions:TStrings;
  const TableName,KeyField:string; IdentityKey:Boolean);
var F,Names,Caption:string; I:Integer; DoUnique:Boolean;
  procedure A(const S:string);
  begin Code.Add(S);end;
begin
  //组合中含数据库自增主键时，唯一性由数据库键本身保证，不能比较临时 Null。
  DoUnique:=(UniqueFields.Count>0) and not (IdentityKey and (UniqueFields.IndexOf(KeyField)>=0));
  Names:='';
  for F in UniqueFields do begin
    if Names<>'' then Names:=Names+', ';
    Names:=Names+F;
  end;
  A('//统一校验最终暂存结果，不移动界面游标；异常继续中止当前操作');
  A('procedure ValidateGenericRows;');
  A('var L, D, C: TUgClientDataSet; Seen, Rows: TStringList;');
  A('  RowNo, FirstRow, NextPage: Integer; SQL, Signature, V: string;');
  A('  Replaced: Boolean;');
  A('begin');
  A('  L := TUgClientDataSet.Create(nil);');
  A('  D := TUgClientDataSet.Create(nil);');
  A('  C := TUgClientDataSet.Create(nil);');
  A('  Seen := TStringList.Create;');
  A('  Rows := TStringList.Create;');
  A('  try');
  A('    L.Data := cdsMain.Data;');
  A('    //反向修改可使变更数归零但仍保留修改行状态；无Delta时用当前快照核对自身记录');
  A('    if cdsMain.ChangeCount > 0 then D.Data := cdsMain.Delta else D.Data := cdsMain.Data;');
  A('    C.DataNodeName := cDataNodeName;');
  A('    C.PageRowCount := 100;');
  A('    L.First;');
  A('    RowNo := 0;');
  A('    while not L.Eof do');
  A('    begin');
  A('      Inc(RowNo);');
  A('      if L.UpdateStatus <> usUnmodified then');
  A('      begin');
  for F in RequiredFields do begin
    Caption:=F;
    I:=Fields.IndexOf(F);
    if (I>=0) and (Trim(Captions[I])<>'') then Caption:=Captions[I];
    if IdentityKey and SameText(F,KeyField) then
      A('        if L.UpdateStatus <> usInserted then');
    A('        if Trim(VarToStr(L.FieldByName('+QuotedStr(F)+').AsVariant)) = '''' then');
    A('          RaiseException(UGMM.LT(''第 '') + IntToStr(RowNo) + UGMM.LT('' 行：'')');
    A('            + UGMM.LT('+QuotedStr(Caption)+') + UGMM.LT('' 不能为空。''));');
  end;
  A('      end;');
  if DoUnique then begin
    A('      //长度前缀避免组合字段拼接歧义；空值参与业务唯一校验');
    A('      Signature := '''';');
    for F in UniqueFields do begin
      A('      V := UpperCase(VarToStr(L.FieldByName('+QuotedStr(F)+').AsVariant));');
      A('      Signature := Signature + IntToStr(Length(V)) + '':'' + V;');
    end;
    A('      FirstRow := Seen.IndexOf(Signature);');
    A('      if FirstRow >= 0 then');
    A('        RaiseException(UGMM.LT(''第 '') + Rows[FirstRow] + UGMM.LT('' 行与第 '')');
    A('          + IntToStr(RowNo) + UGMM.LT('+QuotedStr(' 行组合唯一字段 ['+Names+'] 重复。')+'));');
    A('      Seen.Add(Signature);');
    A('      Rows.Add(IntToStr(RowNo));');
  end;
  A('      L.Next;');
  A('    end;');
  if DoUnique then begin
    A('    //再检查数据库；已修改或删除的旧行按本批最终状态处理');
    A('    L.First;');
    A('    RowNo := 0;');
    A('    while not L.Eof do');
    A('    begin');
    A('      Inc(RowNo);');
    A('      if L.UpdateStatus <> usUnmodified then');
    A('      begin');
    A('        SQL := '+QuotedStr('select '+KeyField+' from '+TableName+' where 1 = 1')+';');
    for I:=0 to UniqueFields.Count-1 do begin
      F:=UniqueFields[I];
      A('        if L.FieldByName('+QuotedStr(F)+').IsNull then');
      A('          SQL := SQL + '+QuotedStr(' and '+F+' is null'));
      A('        else if VarToStr(L.FieldByName('+QuotedStr(F)+').AsVariant) = '''' then');
      A('          SQL := SQL + '+QuotedStr(' and ('+F+' is null or '+F+' = :unique'+IntToStr(I)+')'));
      A('        else SQL := SQL + '+QuotedStr(' and '+F+' = :unique'+IntToStr(I))+';');
    end;
    A('        C.Close;');
    A('        C.CommandText := SQL;');
    for I:=0 to UniqueFields.Count-1 do begin
      F:=UniqueFields[I];
      A('        if not L.FieldByName('+QuotedStr(F)+').IsNull then');
      A('          C.ParamByName('+QuotedStr('unique'+IntToStr(I))+').Value := L.FieldByName('+QuotedStr(F)+').AsVariant;');
    end;
    A('        C.Open;');
    A('        while True do');
    A('        begin');
    A('          while not C.Eof do');
    A('          begin');
    A('            Replaced := False;');
    A('            D.First;');
    A('            while not D.Eof do');
    A('            begin');
    A('              //Delta 包同时含修改前的原始行；记录键不允许手工修改');
    A('              if D.UpdateStatus <> usInserted then');
    A('                if D.FieldByName('+QuotedStr(KeyField)+').AsVariant = C.FieldByName('+QuotedStr(KeyField)+').AsVariant then Replaced := True;');
    A('              D.Next;');
    A('            end;');
    A('            if not Replaced then');
    A('              RaiseException(UGMM.LT(''第 '') + IntToStr(RowNo)');
    A('                + UGMM.LT('+QuotedStr(' 行组合唯一字段 ['+Names+'] 在数据库中已存在。')+'));');
    A('            C.Next;');
    A('          end;');
    A('          NextPage := C.PageIndex + 1;');
    A('          if (C.PageIndex < 1) or (NextPage > C.PageCount) then Break;');
    A('          C.PageIndex := NextPage;');
    A('        end;');
    A('      end;');
    A('      L.Next;');
    A('    end;');
  end;
  A('  finally');
  A('    Rows.Free;');
  A('    Seen.Free;');
  A('    C.Free;');
  A('    D.Free;');
  A('    L.Free;');
  A('  end;');
  A('end;');A('');
end;

procedure AddMultipleAutoNumber(Code:TStrings; const TableName, KeyField,
  AutoType, Prefix, Suffix, Digits:string);
  procedure A(const S:string);
  begin Code.Add(S);end;
begin
  A('//检查当前页及未保存记录中的编号；恢复游标，不改变编辑内容');
  A('function LocalAutoNumberExists(const AValue: string): Boolean;');
  A('var B: TBookmark;');
  A('begin');
  A('  Result := False;');
  A('  if cdsMain.IsEmpty then Exit;');
  A('  B := cdsMain.GetBookmark;');
  A('  cdsMain.DisableControls;');
  A('  try');
  A('    cdsMain.First;');
  A('    while not cdsMain.Eof do');
  A('    begin');
  A('      if UpperCase(cdsMain.FieldByName('+QuotedStr(KeyField)+').AsString) = UpperCase(AValue) then');
  A('      begin');
  A('        Result := True;');
  A('        Exit;');
  A('      end;');
  A('      cdsMain.Next;');
  A('    end;');
  A('  finally');
  A('    cdsMain.GotoBookmark(B);');
  A('    cdsMain.FreeBookmark(B);');
  A('    cdsMain.EnableControls;');
  A('  end;');
  A('end;');A('');
  A('//参照 mtMasterSlave 编号规则；后台与未保存记录均须避重');
  A('//并发最终由数据库唯一约束校验，提交失败保留暂存数据');
  A('function GetAutoNumber: string;');
  A('const');
  A('  cPrefix = '+QuotedStr(Prefix)+';');
  A('  cSuffix = '+QuotedStr(Suffix)+';');
  A('var C: TUgClientDataSet; N, Attempt: Integer;');
  A('begin');
  A('  C := TUgClientDataSet.Create(nil);');
  A('  try');
  A('    C.DataNodeName := cDataNodeName;');
  A('    C.PageRowCount := 1;');
  if SameText(AutoType,'MaxCode') then begin
    A('    C.CommandText := '+QuotedStr('select max('+KeyField+') as AutoCode from '+TableName)+';');
    A('    C.Open;');
    A('    N := StrToIntDef(ReplaceText(ReplaceText(');
    A('      C.FieldByName(''AutoCode'').AsString, cPrefix, ''''), cSuffix, ''''), 0);');
  end;
  if SameText(AutoType,'MaxCode') then A('    for Attempt := 1 to 10000 do')
  else A('    for Attempt := 1 to 10 do');
  A('    begin');
  if SameText(AutoType,'MaxCode') then begin
    A('      if N >= 2147483647 then RaiseException(''自动编号超出范围，请检查编号配置。'');');
    A('      Inc(N);');
    A('      Result := cPrefix + Format('+QuotedStr('%.'+IntToStr(StrToInt(Digits))+'d')+', [N]) + cSuffix;');
  end else if SameText(AutoType,'Guid') then
    A('      Result := UGMM.CreateGuid;')
  else begin
    A('      //毫秒时间戳加随机数，随机部分按原版规则不补零');
    A('      Result := cPrefix + FormatDateTime(''yyyyMMddhhmmsszzz'', Now)');
    A('        + IntToStr(RandomInt('+StringOfChar('9',StrToInt(Digits))+')) + cSuffix;');
  end;
  A('      if Trim(Result) = '''' then RaiseException(''生成器返回空编号。'');');
  A('      if (cdsMain.FieldByName('+QuotedStr(KeyField)+').Size > 0) and');
  A('        (Length(Result) > cdsMain.FieldByName('+QuotedStr(KeyField)+').Size) then');
  A('        RaiseException(''自动编号超过字段长度，请调整后重试。'');');
  A('      if not LocalAutoNumberExists(Result) then');
  A('      begin');
  A('        C.Close;');
  A('        C.CommandText := '+QuotedStr('select '+KeyField+' from '+TableName+' where '+KeyField+' = :occupiedKey')+';');
  A('        C.ParamByName(''occupiedKey'').Value := Result;');
  A('        C.Open;');
  A('        if C.IsEmpty then Exit;');
  A('      end;');
  A('    end;');
  A('    RaiseException(''自动编号连续占号，请检查编号规则后重试。'');');
  A('  finally');
  A('    C.Free;');
  A('  end;');
  A('end;');A('');
end;

procedure AddMultipleRecordImport(Code, Fields, Captions: TStrings;
  const KeyField: string; const AuditFields: array of string; AutoNumber,Validate,JoinRefresh:Boolean);
var I:Integer; F,V,Headers:string;
  procedure A(const S:string);
  begin Code.Add(S);end;
begin
  A('//将原生文本/Excel导入暂存区转换为业务字段；整批失败时回退');
  A('procedure ImportGenericRows;');
  A('var RowNo, Imported, SavedRow: Integer; HasData: Boolean; V, Failure, CurrentField: string;');
  if AutoNumber then A('  NewKey: string;');
  A('begin');
  A('  CheckNoPendingChanges;');
  A('  if not cdsMain.Active then RaiseException(''请先查询数据。'');');
  A('  if cdsUnitImport.RecordCount > 500 then RaiseException(''每批最多导入 500 行。'');');
  A('  SavedRow := cdsMain.RecNo; RowNo := 0; Imported := 0; CurrentField := '''';');
  A('  cdsMain.DisableControls;'); A('  try'); A('    try');
  A('      cdsUnitImport.First;'); A('      while not cdsUnitImport.Eof do'); A('      begin');
  A('        Inc(RowNo); HasData := False;');
  for F in Fields do
    A('        if cdsUnitImport.FieldByName('+QuotedStr(F)+').AsString <> '''' then HasData := True;');
  A('        if HasData then'); A('        begin');
  if AutoNumber then A('          NewKey := GetAutoNumber;');
  A('          cdsMain.FieldByName('+QuotedStr(KeyField)+').ReadOnly := False;');
  A('          cdsMain.FieldByName('+QuotedStr(KeyField)+').Required := False;');
  A('          cdsMain.Append;');
  if AutoNumber then A('          cdsMain.FieldByName('+QuotedStr(KeyField)+').AsString := NewKey;')
  else A('          cdsMain.FieldByName('+QuotedStr(KeyField)+').AsVariant := Null;');
  for F in Fields do begin
    A('          CurrentField := '+QuotedStr(F)+';');
    A('          V := cdsUnitImport.FieldByName('+QuotedStr(F)+').AsString;');
    A('          if (cdsMain.FieldByName(CurrentField).DataType in [ftString, ftWideString, ftFixedChar]) or');
    A('             (cdsMain.FieldByName(CurrentField).ClassName = ''TWideStringField'') then');
    A('            if (cdsMain.FieldByName(CurrentField).Size > 0) and (Length(V) > cdsMain.FieldByName(CurrentField).Size) then');
    A('              RaiseException(''导入内容超出字段长度。'');');
    A('          if V = '''' then cdsMain.FieldByName(CurrentField).AsVariant := Null');
    A('          else cdsMain.FieldByName(CurrentField).AsString := V;');
  end;
  for I:=0 to High(AuditFields) do if AuditFields[I]<>'' then begin
    F:='cdsMain.FieldByName('+QuotedStr(AuditFields[I])+')';
    case I mod 3 of
      0:V:='.AsString := UGMM.Informations.Values[''UserName''];';
      1:V:='.AsString := UGMM.Informations.Values[''ClassName''];';
      2:V:='.AsDateTime := Now;';
    end;
    A('          '+F+V);
  end;
  if JoinRefresh then A('          RefreshMultipleJoin;');
  A('          CurrentField := ''''; cdsMain.Post; Inc(Imported);');
  A('        end;'); A('        cdsUnitImport.Next;'); A('      end;');
  if Validate then A('      ValidateGenericRows;');
  A('    except');
  A('      Failure := ExceptionMessage;');
  A('      cdsMain.Cancel;');
  A('      cdsMain.CancelUpdates;');
  A('      RaiseException(''导入失败，第 '' + IntToStr(RowNo) + '' 行，字段 ['' + CurrentField + '']：'' + Failure);');
  A('    end;'); A('  finally');
  A('    if (SavedRow > 0) and (SavedRow <= cdsMain.RecordCount) then cdsMain.RecNo := SavedRow;');
  A('    cdsMain.EnableControls; RefreshToolbar;'); A('  end;');
  A('  if Imported > 0 then ShowNotice(''导入已暂存，请点击保存提交数据库。'');');
  A('end;');A('');
  A('//使用原生导入窗口；主键和审计字段不进入导入列');
  A('procedure pmImportUgMenuItemsOnClick(const ACaption: string);');A('begin');
  A('  CheckNoPendingChanges;');
  A('  if not cdsMain.Active then RaiseException(''请先查询数据。'');');
  A('  //沿用 DFM 中的 Unicode 长文本字段定义，避免临时文本截断');
  A('  cdsUnitImport.Close;');
  A('  cdsUnitImport.CreateDataSet;');A('  try');
  Headers:='';for F in Captions do Headers:=Headers+F+';';
  A('    if ACaption = UGMM.LT(''文本格式'') then');
  A('      UGMM.ImportText(gridUnitImport, '+QuotedStr(Headers)+')');
  A('    else if ACaption = UGMM.LT(''电子表格'') then');
  A('    begin');
  A('      if not UGMM.ImpExcel(gridUnitImport, Self.Caption, '''') then Exit;');
  A('    end else Exit;');
  A('    if not cdsUnitImport.IsEmpty then ImportGenericRows;');
  A('  finally');A('    cdsUnitImport.Close;');A('  end;');A('end;');A('');
  A('//默认打开文本导入');
  A('procedure btImportOnClick(Sender: TObject);');A('begin');
  A('  pmImportUgMenuItemsOnClick(UGMM.LT(''文本格式''));');A('end;');A('');
end;

procedure AddMultipleRecordEditor(Code, Fields: TStrings; const KeyField,
  Editor: string; const AuditFields: array of string; AutoNumber,Validate,JoinRefresh:Boolean; NewRecordInit,EditorInputFields:TStrings);
var I: Integer; F, V: string;
  procedure A(const S: string);
  begin Code.Add(S); end;
begin
  A('//按 v字段名 与编辑子窗体交换 Variant 值；主键及审计字段不回写');
  A('procedure EditUnitRecord(IsNew: Boolean);');
  A('var F: TUgWebForm; RetryEditor: Boolean; EditorError: string;');
  if Validate or JoinRefresh then A('  PreviousData: Variant; PreviousRow: Integer;');
  if AutoNumber then A('  NewKey: string;');
  for I:=0 to Fields.Count-1 do A('  NewValue'+IntToStr(I)+': Variant;');
  A('begin');
  A('  if not cdsMain.Active then RaiseException(''请先查询数据。'');');
  A('  if (not IsNew) and cdsMain.IsEmpty then RaiseException(''请先选择要编辑的记录。'');');
  A('  F := TUgWebForm(UGMM.GetWebSubForm('+QuotedStr(Editor)+'));');
  A('  if F = nil then RaiseException(''无法打开编辑窗体。'');');
  A('  try');
  if EditorInputFields=nil then EditorInputFields:=Fields;
  for F in EditorInputFields do begin
    A('    if IsNew then');
    A('      TUgWebRunFrame(F.RunFrame).SetValue('+QuotedStr('v'+F)+', Null)');
    A('    else');
    A('      TUgWebRunFrame(F.RunFrame).SetValue('+QuotedStr('v'+F)+', cdsMain.FieldByName('+QuotedStr(F)+').AsVariant);');
  end;
  A('    RetryEditor := True; EditorError := '''';');
  A('    while RetryEditor do'); A('    begin');
  A('      if EditorError <> '''' then WaitEditorError(EditorError);');
  A('      EditorError := ''''; RetryEditor := False;');
  A('      //清除上次关闭结果，保留原子窗体输入');
  A('      F.ModalResult := 0;');
  A('      if F.ShowModal = mrOk then'); A('      try');
  A('        //先读取全部回传值；读取失败不改变主数据集');
  for I:=0 to Fields.Count-1 do
    A('        NewValue'+IntToStr(I)+' := TUgWebRunFrame(F.RunFrame).GetValue('+QuotedStr('v'+Fields[I])+');');
  A('        if IsNew then'); A('        begin');
  if AutoNumber then A('          NewKey := GetAutoNumber;');
  A('          cdsMain.FieldByName('+QuotedStr(KeyField)+').ReadOnly := False;');
  A('          cdsMain.FieldByName('+QuotedStr(KeyField)+').Required := False;');
  A('        end;');
  A('        //仅暂存修改；保存按钮负责统一提交');
  if Validate or JoinRefresh then begin
    A('        PreviousData := cdsMain.Data;');
    A('        PreviousRow := cdsMain.RecNo;');
  end;
  A('        if IsNew then cdsMain.Append else cdsMain.Edit;');
  A('        try');
  if AutoNumber then A('          if IsNew then cdsMain.FieldByName('+QuotedStr(KeyField)+').AsString := NewKey;')
  else A('          if IsNew then cdsMain.FieldByName('+QuotedStr(KeyField)+').AsVariant := Null;');
  if NewRecordInit<>nil then begin
    A('          if IsNew then begin');
    Code.AddStrings(NewRecordInit);
    A('          end;');
  end;
  for I:=0 to Fields.Count-1 do
    A('          cdsMain.FieldByName('+QuotedStr(Fields[I])+').AsVariant := NewValue'+IntToStr(I)+';');
  for I:=0 to High(AuditFields) do
    if AuditFields[I]<>'' then begin
      F:='cdsMain.FieldByName('+QuotedStr(AuditFields[I])+')';
      if I<3 then A('          if '+F+'.IsNull then');
      case I mod 3 of
        0: V:='.AsString := UGMM.Informations.Values[''UserName''];';
        1: V:='.AsString := UGMM.Informations.Values[''ClassName''];';
        2: V:='.AsDateTime := Now;';
      end;
      A('            '+F+V);
    end;
  if JoinRefresh then A('          RefreshMultipleJoin;');
  A('          cdsMain.Post;');
  if Validate then A('          ValidateGenericRows;');
  A('        except'); A('          cdsMain.Cancel;');
  if Validate or JoinRefresh then begin
    A('          cdsMain.Data := PreviousData;');
    A('          if (PreviousRow > 0) and (PreviousRow <= cdsMain.RecordCount) then cdsMain.RecNo := PreviousRow;');
  end;
  A('          RaiseException(ExceptionMessage);'); A('        end;');
  A('      except'); A('        RetryEditor := True;');
  A('        EditorError := ExceptionMessage;'); A('      end;');
  A('    end;');
  A('  finally'); A('    UGMM.DelWebSubForm('+QuotedStr(Editor)+');');
  A('  end;'); A('end;'); A('');
end;
end.
