unit ugConfiguration.EditTemplate;

interface

uses System.SysUtils, System.Classes, System.JSON;

function TryBuildEditTemplate(AConfig: TJSONObject; const ATemplate: string;
  out ADFM: string): Boolean; overload;
function TryBuildEditTemplate(AConfig: TJSONObject; const ATemplate: string;
  out ADFM, AReason: string): Boolean; overload;

implementation

function Obj(AObject: TJSONObject; const AKey: string): TJSONObject;
var V: TJSONValue;
begin
  Result := nil;
  if not Assigned(AObject) then Exit;
  V := AObject.GetValue(AKey);
  if V is TJSONObject then Result := TJSONObject(V);
end;

function Str(AObject: TJSONObject; const AKey: string): string;
var V: TJSONValue;
begin
  Result := '';
  if not Assigned(AObject) then Exit;
  V := AObject.GetValue(AKey);
  if Assigned(V) and not (V is TJSONNull) then Result := V.Value;
end;

function DFMString(const S: string): string;
var C: Char;
begin
  { ObjectTextToBinary can interpret unmarked bytes using the system code
    page. Emit ASCII DFM syntax, as the recovered templates do, so every
    UTF-16 code unit survives independent of the machine code page. }
  Result := '''';
  for C in S do
    if (Ord(C) < 32) or (Ord(C) > 126) then
      Result := Result + '''#' + IntToStr(Ord(C)) + ''''
    else if C = '''' then
      Result := Result + ''''''
    else
      Result := Result + C;
  Result := Result + '''';
end;

function IsGrid(const S: string): Boolean;
begin
  Result := (S = 'gridcombobox') or (S = 'gridcomboboxextra');
end;

function DynamicGrid(Drop: TJSONObject): Boolean;
begin
  Result := (Str(Drop, 'cbDynamicLoading') = '-1') or
    (Str(Drop, 'cbDynamicLoading') = '1') or
    SameText(Str(Drop, 'cbDynamicLoading'), 'True');
end;

function GridSQL(Drop: TJSONObject): string;
begin
  Result := Trim(StringReplace(Str(Drop, 'mmText'), '\r\n', ' ', [rfReplaceAll]));
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  if (Result <> '') and (Result[Length(Result)] = ';') then
    Delete(Result, Length(Result), 1);
end;

function GridSearchField(Drop: TJSONObject; const Field: string): Boolean;
var Fields: TStringList; S: string; P: Integer;
begin
  Result := False;
  Fields := TStringList.Create;
  try
    Fields.StrictDelimiter := True; Fields.Delimiter := ';';
    Fields.DelimitedText := Str(Drop, 'edOptionLookupFields');
    for S in Fields do
    begin
      P := Pos('@', S);
      if P = 0 then P := Length(S) + 1;
      if SameText(Trim(Copy(S, 1, P - 1)), Field) then Exit(True);
    end;
  finally Fields.Free; end;
end;

function TryBuildEditTemplate(AConfig: TJSONObject; const ATemplate: string;
  out ADFM: string): Boolean;
var Reason: string;
begin
  Result := TryBuildEditTemplate(AConfig, ATemplate, ADFM, Reason);
end;

function TryBuildEditTemplate(AConfig: TJSONObject; const ATemplate: string;
  out ADFM, AReason: string): Boolean;
const
  // 原版 mtEditor 编辑面板：列优先、每列最多 6 行；单元格 200 宽，列步进 210
  // （含 360 宽控件的列取 370），行步进 = 上一个控件高 + 10，行基准 60。
  CEditorMaxRows = 6;
  CEditorColumnStep = 210;
  CEditorColumnWide = 370;
  CEditorRowStep = 60;
var
  Rows, Cols, Row, Col, Structure: TJSONObject;
  Names, Vars, Captions, Used, Lines, Code, Controls, Hidden, HiddenVars: TStringList;
  Columns, Required, ObjectTypes, Scales, Options, Items, SqlCombos: TStringList;
  I, J, First, Last, Section, FieldHeight, FieldWidth, Scale: Integer;
  ItemsPerColumn, ColCount, CurCol, ColCursor, ColLeft, ColWidthSum, PanelContent,
    PanelHeight, FrameWidth: Integer;
  CurColWide: Boolean;
  Column, ControlName, VariableName, S, ObjectType, ClassName: string;
  DropValue: TJSONValue;
  Drop: TJSONObject;
  HasTime: Boolean;
  TimeClickJS, LookupDataName, LookupSQL, LookupField, LookupCaption: string;
  LookupParts: TStringList;
  function Reject(const Reason: string): Boolean;
  begin
    AReason := Reason;
    Result := False;
  end;
  procedure ReplaceBlock(AFirst, ALast: Integer; NewLines: TStrings);
  var K: Integer;
  begin
    for K := ALast - 1 downto AFirst do Lines.Delete(K);
    for K := NewLines.Count - 1 downto 0 do Lines.Insert(AFirst, NewLines[K]);
  end;
begin
  Result := False;
  ADFM := '';
  AReason := '';
  if not SameText(Str(AConfig, 'TWebModuletype'), 'mtEditor') then
    Exit(Reject('当前动态生成仅支持 mtEditor，实际模块类型：' + Str(AConfig, 'TWebModuletype')));
  Structure := Obj(AConfig, 'TWebDataStructure');
  Rows := Obj(Obj(Structure, 'cdsTypesetting'), 'Data');
  Cols := Obj(Obj(Structure, 'cdsColumns'), 'Data');
  if not Assigned(Rows) or not Assigned(Cols) then
    Exit(Reject('缺少字段或排版数据集 Data，请先配置数据结构。'));
  if (Rows.Count = 0) or (Rows.Count > (MaxInt - 42) div 180) then
    Exit(Reject('排版字段数量无效：' + IntToStr(Rows.Count)));
  Names := TStringList.Create;
  Vars := TStringList.Create;
  Captions := TStringList.Create;
  Used := TStringList.Create;
  Lines := TStringList.Create;
  Code := TStringList.Create;
  Controls := TStringList.Create;
  Columns := TStringList.Create;
  Required := TStringList.Create;
  ObjectTypes := TStringList.Create;
  Scales := TStringList.Create;
  Options := TStringList.Create;
  Items := TStringList.Create;
  SqlCombos := TStringList.Create;
  Hidden := TStringList.Create; HiddenVars := TStringList.Create;
  try
    Hidden.StrictDelimiter := True; Hidden.Delimiter := ';'; Hidden.QuoteChar := #0;
    Hidden.DelimitedText := Str(Obj(AConfig, 'TWebNormalSetting'), '隐藏字段-主表');
    for I := 0 to Hidden.Count - 1 do Hidden[I] := Trim(Hidden[I]);
    Columns.CaseSensitive := False;
    Required.CaseSensitive := False;
    Required.StrictDelimiter := True;
    Required.Delimiter := ';';
    Required.QuoteChar := #0;
    Required.DelimitedText := Str(Obj(AConfig, 'TWebNormalSetting'), '非空字段');
    for I := Required.Count - 1 downto 0 do
    begin
      Required[I] := Trim(Required[I]);
      if Required[I] = '' then Required.Delete(I);
    end;
    Used.CaseSensitive := False;
    Used.CommaText := 'UgWebRunFrame,pButtons,pEditControls,lbEditControls,btOk,btCancel,Imgs,errorAlert';
    for I := 0 to Rows.Count - 1 do
    begin
      { Dataset row keys, not JSON member insertion order, define layout. }
      Row := Obj(Rows, IntToStr(I));
      if not Assigned(Row) then Exit(Reject('排版数据缺少数字行键：' + IntToStr(I)));
      Column := Str(Row, 'fdCOLUMN_NAME');
      if (Pos('.', Column) <> 2) or (Length(Column) < 3) then
        Exit(Reject('字段需采用单字符表别名，如 a.Name：' + Column));
      ControlName := Copy(Column, 1, 1) + Copy(Column, 3, MaxInt);
      VariableName := 'v' + Copy(Column, 3, MaxInt);
      if not IsValidIdent(ControlName) or not IsValidIdent(VariableName) then
        Exit(Reject('字段不能转换为合法控件/变量名称：' + Column));
      if SameText(ControlName, VariableName) or
        (Used.IndexOf(ControlName) >= 0) or (Used.IndexOf(VariableName) >= 0) then
        Exit(Reject('字段的控件名或变量名冲突：' + Column));
      Used.Add(ControlName);
      Used.Add(VariableName);
      if Hidden.IndexOf(Column) >= 0 then
      begin
        HiddenVars.Add(VariableName);
        Continue;
      end;
      ObjectType := '';
      Col := nil;
      for J := 0 to Cols.Count - 1 do
      begin
        Col := Obj(Cols, IntToStr(J));
        if SameText(Str(Col, 'fdCOLUMN_NAME'), Column) then
        begin
          ObjectType := LowerCase(Str(Col, 'fdOBJECT_TYPE'));
          Break;
        end;
      end;
      if (ObjectType <> 'edit') and (ObjectType <> 'memo') and
        (ObjectType <> 'date') and (ObjectType <> 'time') and
        (ObjectType <> 'datetime') and (ObjectType <> 'number') and
        (ObjectType <> 'check') and (ObjectType <> 'combobox') and
        (ObjectType <> 'lookupedit') and (ObjectType <> 'lookupeditextra') and
        not IsGrid(ObjectType) then
        Exit(Reject('字段 ' + Column + ' 的对象类型尚不支持或未匹配：[' + ObjectType + ']'));
      Scale := 0;
      if ObjectType = 'number' then
      begin
        S := Str(Col, 'fdCOLUMN_SCAL');
        if S <> '' then
          if not TryStrToInt(S, Scale) then
            Exit(Reject('字段 ' + Column + ' 的数值位数不是整数：' + S));
        if (Scale < 0) or (Scale > 15) then
          Exit(Reject('字段 ' + Column + ' 的数值位数须为 0～15：' + S));
      end;
      Scales.Add(IntToStr(Scale));
      S := '';
      if ObjectType = 'combobox' then
      begin
        DropValue := Col.GetValue('fdDropDownOptions');
        if DropValue is TJSONObject then DropValue := TJSONValue(DropValue.Clone)
        else DropValue := TJSONObject.ParseJSONValue(Str(Col, 'fdDropDownOptions'));
        try
          if not (DropValue is TJSONObject) then
            Exit(Reject('字段 ' + Column + ' 缺少有效下拉选项 JSON。'));
          Drop := TJSONObject(DropValue);
          if not SameText(Str(Drop, 'cbDropDownType'), 'SetText') and
            not SameText(Str(Drop, 'cbDropDownType'), 'SqlText') then
            Exit(Reject('字段 ' + Column + ' 的下拉类型须为 SetText 或 SqlText。'));
          if (Str(Drop, 'cbDynamicLoading') <> '') and
            (Str(Drop, 'cbDynamicLoading') <> '0') and
            not SameText(Str(Drop, 'cbDynamicLoading'), 'False') then
            Exit(Reject('字段 ' + Column + ' 的动态下拉加载尚未支持。'));
          if SameText(Str(Drop, 'cbDropDownType'), 'SqlText') then
          begin
            if not IsValidIdent(Str(Drop, 'edOptionValue')) then
              Exit(Reject('字段 ' + Column + ' 的 SqlText 需要有效返回字段。'));
            LookupSQL := GridSQL(Drop);
            if not SameText(Copy(LookupSQL, 1, 7), 'select ') or
              (Pos(';', LookupSQL) > 0) or (Pos(':', LookupSQL) > 0) or
              (Pos('--', LookupSQL) > 0) or (Pos('/*', LookupSQL) > 0) then
              Exit(Reject('SqlText 首轮仅支持无参数、无注释的单条 SELECT。'));
            if Str(Drop, 'edOptionDisplay') <> '' then
              Exit(Reject('SqlText 暂不支持独立显示字段映射。'));
            LookupDataName := 'ugComboData' + ControlName;
            if Used.IndexOf(LookupDataName) >= 0 then Exit(Reject('下拉数据集名称冲突。'));
            Used.Add(LookupDataName);
            SqlCombos.Add(ControlName);
            S := Drop.ToJSON;
          end
          else
          begin
          if (Str(Drop, 'edOptionValue') <> '') or
            (Str(Drop, 'edOptionDisplay') <> '') then
            Exit(Reject('字段 ' + Column + ' 的下拉显示值/实际值映射尚未支持。'));
          S := Str(Drop, 'mmText');
          if Trim(S) = '' then Exit(Reject('字段 ' + Column + ' 的固定下拉选项内容为空。'));
          end;
        finally DropValue.Free; end;
      end;
      Options.Add(S);
      if (ObjectType = 'lookupedit') or (ObjectType = 'lookupeditextra') or IsGrid(ObjectType) then
      begin
        DropValue := Col.GetValue('fdDropDownOptions');
        if DropValue is TJSONObject then DropValue := TJSONValue(DropValue.Clone)
        else DropValue := TJSONObject.ParseJSONValue(Str(Col, 'fdDropDownOptions'));
        try
          if not (DropValue is TJSONObject) then
            Exit(Reject('字段 ' + Column + ' 缺少查找配置。'));
          Drop := TJSONObject(DropValue);
          if not SameText(Str(Drop, 'cbDropDownType'), 'SqlQuery') then
            Exit(Reject('字段 ' + Column + ' 的 lookupedit 目前仅支持 SqlQuery。'));
          if not SameText(Str(Drop, 'cbGridPageSetting'), 'Close') and
            not SameText(Str(Drop, 'cbGridPageSetting'), 'Open') then
            Exit(Reject('字段 ' + Column + ' 的 lookup 分页设置须为 Open 或 Close。'));
          if SameText(Str(Drop, 'cbGridPageSetting'), 'Open') then
            if not TryStrToInt(Str(Drop, 'sePageSize'), Scale) or (Scale < 1) or (Scale > 500) then
              Exit(Reject('字段 ' + Column + ' 的查找每页数量须为 1 到 500。'));
          if (Trim(Str(Drop, 'mmText')) = '') or
            not IsValidIdent(Str(Drop, 'edOptionValue')) or
            (Trim(Str(Drop, 'edOptionLookupFields')) = '') then
            Exit(Reject('字段 ' + Column + ' 需要 SQL、有效值字段和列表列。'));
          if ((ObjectType = 'lookupeditextra') or (ObjectType = 'gridcomboboxextra')) and
            not IsValidIdent(Str(Drop, 'edOptionDisplay')) then
            Exit(Reject('字段 ' + Column + ' 的 lookupeditextra 需要有效的显示字段。'));
          if not TryStrToInt(Str(Drop, 'seMaxRecordCount'), Scale) or (Scale < 1) then
            Exit(Reject('字段 ' + Column + ' 的最大记录数须为正整数。'));
          if IsGrid(ObjectType) then
          begin
            if Trim(Str(Drop, 'edOptionFields')) = '' then
              Exit(Reject('表格下拉需要配置显示列。'));
            LookupSQL := GridSQL(Drop);
            if (not SameText(Copy(LookupSQL, 1, 7), 'select ')) or
              (Pos(';', LookupSQL) > 0) or (Pos(':', LookupSQL) > 0) or
              (Pos('--', LookupSQL) > 0) or (Pos('/*', LookupSQL) > 0) or
              (Pos('ORDER BY', UpperCase(LookupSQL)) > 0) then
              Exit(Reject('表格下拉目前需要无参数、无 ORDER BY 的单条 SELECT。'));
          end;
          LookupDataName := 'ugLookupData' + ControlName;
          if Used.IndexOf(LookupDataName) >= 0 then Exit(Reject('查找数据集名称冲突。'));
          Used.Add(LookupDataName);
          Options[Options.Count - 1] := Drop.ToJSON;
        finally DropValue.Free; end;
      end;
      ObjectTypes.Add(ObjectType);
      Columns.Add(Column);
      Names.Add(ControlName);
      Vars.Add(VariableName);
      Captions.Add(Str(Row, 'fdCAPTION'));
    end;
    { Never silently omit a configured rule for an absent/unrendered field. }
    for I := 0 to Required.Count - 1 do
      if (Columns.IndexOf(Required[I]) < 0) and (Hidden.IndexOf(Required[I]) < 0) then
        Exit(Reject('非空字段不在当前排版字段中：' + Required[I]));

    Lines.Text := ATemplate;
    First := Lines.IndexOf('    ''Var''');
    Last := Lines.IndexOf('    ''function GetInSqlText(AFieldName,AText: String): String;''');
    if (First < 0) or (Last <= First) then
      raise Exception.Create('编辑器模板脚本边界不匹配。');
    HasTime := ObjectTypes.IndexOf('time') >= 0;
    Code.Add('//编辑输入与返回变量；确认成功后由调用模块读取，取消不提交');
    Code.Add('Var');
    Code.Add('  EditorErrorField: Integer = -1;');
    Code.Add('  EditorInitialized: Boolean = False;');
    Code.Add('  EditorLoaded: Boolean = False;');
    Code.Add('  EditorCanConfirm: Boolean = False;');
    for I := 0 to Names.Count - 1 do Code.Add('  ' + Vars[I] + ' : Variant = Null;');
    for I := 0 to HiddenVars.Count - 1 do Code.Add('  ' + HiddenVars[I] + ' : Variant = Null;');
    Code.Add('//提示关闭后再定位首个校验失败字段，避免焦点被提示框接管');
    Code.Add('procedure RestoreEditorErrorFocus;');
    Code.Add('var FieldIndex: Integer;');
    Code.Add('begin');
    Code.Add('  FieldIndex := EditorErrorField;');
    Code.Add('  EditorErrorField := -1;');
    for I := 0 to Names.Count - 1 do
      if Required.IndexOf(Columns[I]) >= 0 then
      begin
        Code.Add('  if FieldIndex = ' + IntToStr(I) + ' then');
        Code.Add('    if ' + Names[I] + '.Enabled and ' + Names[I] + '.Visible then');
        Code.Add('      ' + Names[I] + '.SetFocus;');
      end;
    Code.Add('end;');
    Code.Add('procedure errorAlertOnConfirm(Sender: TObject);');
    Code.Add('begin');
    Code.Add('  RestoreEditorErrorFocus;');
    Code.Add('end;');
    Code.Add('procedure errorAlertOnDismiss(Sender: TObject; const Reason: TDismissType);');
    Code.Add('begin');
    Code.Add('  RestoreEditorErrorFocus;');
    Code.Add('end;');
    Code.Add('//仅在编辑事件边界显示错误；不关闭窗体，也不提交未通过校验的数据');
    Code.Add('procedure ShowEditorError(const AMessage: string);');
    Code.Add('begin');
    Code.Add('  errorAlert.TitleText := UGMM.LT(''请修改后重试'');');
    Code.Add('  errorAlert.ConfirmButtonText := UGMM.LT(''确定'');');
    Code.Add('  errorAlert.Show(AMessage);');
    Code.Add('end;');
    for I := 0 to Names.Count - 1 do
      if SqlCombos.IndexOf(Names[I]) >= 0 then
      begin
        Drop := TJSONObject.ParseJSONValue(Options[I]) as TJSONObject;
        try
          LookupDataName := 'ugComboData' + Names[I];
          Code.Add('procedure Load' + Names[I] + 'Items;');
          Code.Add('begin');
          Code.Add('  ' + LookupDataName + '.Close;');
          Code.Add('  ' + LookupDataName + '.CommandText := ' + QuotedStr(GridSQL(Drop)) + ';');
          Code.Add('  try');
          Code.Add('    ' + LookupDataName + '.Open;');
          Code.Add('    ' + Names[I] + '.Items.Clear;');
          Code.Add('    ' + LookupDataName + '.First;');
          Code.Add('    while not ' + LookupDataName + '.Eof do');
          Code.Add('    begin');
          Code.Add('      ' + Names[I] + '.Items.Add(' + LookupDataName + '.FieldByName(' + QuotedStr(Str(Drop, 'edOptionValue')) + ').AsString);');
          Code.Add('      ' + LookupDataName + '.Next;');
          Code.Add('    end;');
          Code.Add('    ' + LookupDataName + '.EmptyDataSet;');
          Code.Add('  finally');
          Code.Add('    ' + LookupDataName + '.Close;');
          Code.Add('  end;');
          Code.Add('end;');
        finally Drop.Free; end;
      end;
    for I := 0 to Names.Count - 1 do
      if IsGrid(ObjectTypes[I]) then
      begin
        Drop := TJSONObject.ParseJSONValue(Options[I]) as TJSONObject;
        LookupParts := TStringList.Create;
        try
          if not DynamicGrid(Drop) then Continue;
          Code.Add('Procedure ' + Names[I] + 'OnExtEditValueChange(Sender: TObject; const Value: string);');
          Code.Add('var LookupFailure: string;');
          Code.Add('begin');
          Code.Add('  if not EditorInitialized or not EditorLoaded then Exit;');
          Code.Add('  EditorErrorField := -1;');
          Code.Add('  try');
          LookupDataName := 'ugLookupData' + Names[I];
          Code.Add('  ' + LookupDataName + '.Close;');
          LookupParts.StrictDelimiter := True;
          LookupParts.Delimiter := ';';
          LookupParts.DelimitedText := Str(Drop, 'edOptionLookupFields');
          LookupSQL := 'select ug_grid.* from (' + GridSQL(Drop) + ') ug_grid where ';
          for J := 0 to LookupParts.Count - 1 do
          begin
            LookupField := Trim(LookupParts[J]);
            Section := Pos('@', LookupField);
            if Section > 0 then LookupField := Copy(LookupField, 1, Section - 1);
            if not IsValidIdent(LookupField) then Exit(Reject('无效动态查询字段：' + LookupField));
            if J > 0 then LookupSQL := LookupSQL + ' or ';
            LookupSQL := LookupSQL + 'ug_grid.' + LookupField + ' like :ug_grid_search' + IntToStr(J);
          end;
          Code.Add('  ' + LookupDataName + '.CommandText := ' + QuotedStr(LookupSQL) + ';');
          { Unique names avoid duplicate-parameter binding in the provider.
            ParamByName/AsString are present in the existing FastScript RTTI. }
          for J := 0 to LookupParts.Count - 1 do
            Code.Add('  ' + LookupDataName + '.ParamByName(''ug_grid_search' + IntToStr(J) + ''').AsString := ''%'' + Value + ''%'';');
          Code.Add('  ' + LookupDataName + '.Open;');
          Code.Add('  except');
          Code.Add('    LookupFailure := ExceptionMessage;');
          Code.Add('    try');
          Code.Add('      ' + LookupDataName + '.Close;');
          Code.Add('    finally');
          Code.Add('      ShowEditorError(LookupFailure);');
          Code.Add('    end;');
          Code.Add('  end;');
          Code.Add('end;');
        finally LookupParts.Free; Drop.Free; end;
      end;
    Code.Add('//显示编辑窗体：加载候选并回填调用方传入的值，最后定位首个可编辑字段');
    Code.Add('Procedure UgWebRunFrameOnShow(Sender: TObject);');
    Code.Add('begin');
    Code.Add('  EditorErrorField := -1;');
    Code.Add('  EditorLoaded := False;');
    Code.Add('  btOk.Enabled := False;');
    Code.Add('  if not EditorInitialized then Exit;');
    Code.Add('  try');
    for I := 0 to Names.Count - 1 do
    begin
      if (ObjectTypes[I] = 'lookupedit') or (ObjectTypes[I] = 'lookupeditextra') or IsGrid(ObjectTypes[I]) then
      begin
        Code.Add('  ugLookupData' + Names[I] + '.Close;');
        if IsGrid(ObjectTypes[I]) then
        begin
          Drop := TJSONObject.ParseJSONValue(Options[I]) as TJSONObject;
          try
            LookupSQL := GridSQL(Drop);
            if DynamicGrid(Drop) then LookupSQL := 'select ug_grid.* from (' + LookupSQL + ') ug_grid where 1 = 2';
            Code.Add('  ugLookupData' + Names[I] + '.CommandText := ' + QuotedStr(LookupSQL) + ';');
          finally Drop.Free; end;
        end;
        Code.Add('  ugLookupData' + Names[I] + '.Open;');
      end;
      if ObjectTypes[I] = 'check' then
        Code.Add('  ' + Names[I] + '.Checked := iif(' + Vars[I] + ' = null, False, ' + Vars[I] + ');')
      else if ObjectTypes[I] = 'number' then
      begin
        Code.Add('  if ' + Vars[I] + ' = null then');
        Code.Add('    ' + Names[I] + '.Clear');
        Code.Add('  else ' + Names[I] + '.Value := ' + Vars[I] + ';');
      end
      else if (ObjectTypes[I] = 'date') or (ObjectTypes[I] = 'time') or
        (ObjectTypes[I] = 'datetime') then
      begin
        Code.Add('  ' + Names[I] + '.DateTime := iif(' + Vars[I] + ' = null, 0, ' + Vars[I] + ');');
      end
      else
        Code.Add('  ' + Names[I] + '.Text := iif(' + Vars[I] + ' = null, '''', ' + Vars[I] + ');');
    end;
    for I := 0 to Names.Count - 1 do
    begin
      if I = 0 then S := '  if ' else S := '  else if ';
      Code.Add(S + Names[I] + '.Enabled then');
      S := '    ' + Names[I] + '.SetFocus';
      if I = Names.Count - 1 then S := S + ';';
      Code.Add(S);
    end;
    Code.Add('end;');
    Code.Insert(Code.Count - 1, '  EditorLoaded := True;');
    Code.Insert(Code.Count - 1, '  btOk.Enabled := EditorCanConfirm;');
    Code.Insert(Code.Count - 1, '  except');
    Code.Insert(Code.Count - 1, '    ShowEditorError(ExceptionMessage);');
    Code.Insert(Code.Count - 1, '  end;');
    Code.Add('//确认编辑：读取控件值并检查非空规则，全部通过后才返回 mrOk');
    if HasTime then
    begin
      Code.Add('Procedure btOkOnAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);');
      Code.Add('var TimeSeconds: Integer;');
    end
    else Code.Add('Procedure btOkOnClick(Sender: TObject);');
    Code.Add('begin');
    Code.Add('  if not EditorInitialized or not EditorLoaded or not EditorCanConfirm then Exit;');
    Code.Add('  EditorErrorField := -1;');
    Code.Add('  try');
    if HasTime then
    begin
      Code.Add('  if EventName = ''ug-time-error'' then');
      Code.Add('    RaiseException(UGMM.LT(''时间控件未初始化，请重新打开模块。''));');
      Code.Add('  if EventName <> ''ug-time-submit'' then Exit;');
      for I := 0 to Names.Count - 1 do
        if ObjectTypes[I] = 'time' then
        begin
          Code.Add('  if Params.Values[''ug_time_' + Names[I] + '''] = '''' then');
          Code.Add('    RaiseException(UGMM.LT(''时间提交数据缺失，请重新打开模块。''));');
        end;
    end;
    for I := 0 to Names.Count - 1 do
    begin
      if ObjectTypes[I] = 'check' then
        Code.Add('  ' + Vars[I] + ' := ' + Names[I] + '.Checked;')
      else if ObjectTypes[I] = 'number' then
      begin
        { Inherited Text may be registered before the TCaption alias in FastScript.
          Normalize the getter result without confusing numeric zero with blank. }
        Code.Add('  if VarToStr(' + Names[I] + '.Text) = '''' then');
        Code.Add('    ' + Vars[I] + ' := Null');
        Code.Add('  else ' + Vars[I] + ' := ' + Names[I] + '.Value;');
      end
      else if ObjectTypes[I] = 'time' then
      begin
        { The server Text/RemoteValue cannot distinguish cleared time from zero
          in the host. Consume an explicit blank marker or seconds since midnight
          captured by the button in the SAME request as this submit handler. }
        Code.Add('  if Params.Values[''ug_time_' + Names[I] + '''] = ''blank'' then');
        Code.Add('    ' + Vars[I] + ' := Null');
        Code.Add('  else');
        Code.Add('  begin');
        Code.Add('    TimeSeconds := StrToInt(Params.Values[''ug_time_' + Names[I] + ''']);');
        Code.Add('    if (TimeSeconds < 0) or (TimeSeconds > 86399) then');
        Code.Add('      RaiseException(UGMM.LT(''无效时间。''));');
        Code.Add('    ' + Vars[I] + ' := TimeSeconds / 86400;');
        Code.Add('  end;');
      end
      else if (ObjectTypes[I] = 'date') or
        (ObjectTypes[I] = 'datetime') then
      begin
        Code.Add('  if Trunc(' + Names[I] + '.DateTime) = 0 then');
        Code.Add('    ' + Vars[I] + ' := Null');
        Code.Add('  else ' + Vars[I] + ' := ' + Names[I] + '.DateTime;');
      end
      else Code.Add('  ' + Vars[I] + ' := ' + Names[I] + '.Text;');
    end;
    { Validate in layout order; repeated rule entries generate only one check.
      Keep the recovered empty-string semantics (do not trim user input). }
    for I := 0 to Names.Count - 1 do
      if Required.IndexOf(Columns[I]) >= 0 then
      begin
        Code.Add('  if VarToStr(' + Vars[I] + ') = '''' then');
        Code.Add('  begin');
        Code.Add('    EditorErrorField := ' + IntToStr(I) + ';');
        Code.Add('    RaiseException(' + Names[I] + '.FieldLabel + UGMM.LT(''不能为空''));');
        Code.Add('  end;');
      end;
    Code.Add('  if Self.Parent is TUniForm then');
    Code.Add('    TUniForm(Self.Parent).ModalResult := mrOk;');
    Code.Add('  except');
    Code.Add('    ShowEditorError(ExceptionMessage);');
    Code.Add('  end;');
    Code.Add('end;');
    Code.Add('//取消编辑：返回 mrCancel，由调用方放弃本次编辑');
    Code.Add('Procedure btCancelOnClick(Sender: TObject);');
    Code.Add('begin');
    Code.Add('  EditorErrorField := -1;');
    Code.Add('  if Self.Parent is TUniForm then');
    Code.Add('    TUniForm(Self.Parent).ModalResult := mrCancel;');
    Code.Add('end;');
    for I := 0 to Code.Count - 1 do Code[I] := '    ' + DFMString(Code[I]);
    ReplaceBlock(First, Last, Code);
    J := Lines.IndexOf('  Events.Strings = (');
    if J < 0 then raise Exception.Create('编辑提示事件边界不匹配。');
    Lines.Insert(J + 1, '    ''errorAlert|<This>.OnConfirm:errorAlertOnConfirm''');
    Lines.Insert(J + 2, '    ''errorAlert|<This>.OnDismiss:errorAlertOnDismiss''');
    // Keep permission-adjusted button state; a failed initialization must never
    // enable submission or continue into data loading when the form is shown.
    begin
      J := Lines.IndexOf('    ''procedure UgWebRunFrameOnAfterRunScript(const sender: tobject);''');
      if J < 0 then raise Exception.Create('编辑初始化事件边界不匹配。');
      First := J;
      while (J < Lines.Count) and (Lines[J] <> '    ''begin''') do Inc(J);
      if J = Lines.Count then raise Exception.Create('编辑初始化开始边界不匹配。');
      Lines.Insert(J + 1, '    ' + DFMString('  EditorInitialized := False; EditorLoaded := False; EditorCanConfirm := False;'));
      Lines.Insert(J + 2, '    ' + DFMString('  try'));
      J := First;
      while (J < Lines.Count) and (Lines[J] <> '    ''end;''') do Inc(J);
      if J = Lines.Count then raise Exception.Create('编辑初始化结束边界不匹配。');
      Code.Clear;
      for I := 0 to SqlCombos.Count - 1 do Code.Add('  Load' + SqlCombos[I] + 'Items;');
      Code.Add('  EditorCanConfirm := btOk.Enabled;');
      Code.Add('  EditorInitialized := True;');
      Code.Add('  except');
      Code.Add('    btOk.Enabled := False;');
      Code.Add('    pEditControls.Enabled := False;');
      Code.Add('    ShowEditorError(ExceptionMessage);');
      Code.Add('  end;');
      for I := Code.Count - 1 downto 0 do Lines.Insert(J, '    ' + DFMString(Code[I]));
    end;
    for I := 0 to Names.Count - 1 do
      if IsGrid(ObjectTypes[I]) then
      begin
        Drop := TJSONObject.ParseJSONValue(Options[I]) as TJSONObject;
        try
          if DynamicGrid(Drop) then
          begin
            J := Lines.IndexOf('  Events.Strings = (');
            if J < 0 then raise Exception.Create('表格下拉事件边界不匹配。');
            Lines.Insert(J + 1, '    ' + DFMString(Names[I] + '|<This>.OnExtEditValueChange:' + Names[I] + 'OnExtEditValueChange'));
          end;
        finally Drop.Free; end;
      end;
    if HasTime then
    begin
      I := Lines.IndexOf('    ''btOk|<This>.OnClick:btOkOnClick''');
      if I < 0 then raise Exception.Create('时间提交按钮事件边界不匹配。');
      Lines[I] := '    ''btOk|<This>.OnAjaxEvent:btOkOnAjaxEvent''';
      Lines.Insert(1, '  ClientEvents.UniEvents.Strings = (' +
        DFMString('beforeInit=function beforeInit(sender, config){config.ugTimeSubmitRoot=true;}') + ')');
      TimeClickJS := 'click=function click(sender, e, eOpts){' +
        'var root=sender.up(''[ugTimeSubmitRoot]''),p=[],c,v,r;' +
        'if(!root){ajaxRequest(sender,''ug-time-error'',[]);return;}';
      for I := 0 to Names.Count - 1 do
        if ObjectTypes[I] = 'time' then
          TimeClickJS := TimeClickJS +
            'c=root.down(''[ugTimeKey="' + Names[I] + '"]'');' +
            'if(!c){ajaxRequest(sender,''ug-time-error'',[]);return;}' +
            'r=c.getRawValue();v=c.getValue();' +
            'if(r!==''''&&(!c.isValid()||!v||isNaN(v.getTime()))){c.focus();return;}' +
            'p.push(''ug_time_' + Names[I] + '=''+(r===''''?''blank'':' +
            'String(v.getHours()*3600+v.getMinutes()*60+v.getSeconds())));';
      TimeClickJS := TimeClickJS + 'ajaxRequest(sender,''ug-time-submit'',p);}';
      I := Lines.IndexOf('    object btOk: TUgButton');
      if I < 0 then raise Exception.Create('时间提交按钮控件边界不匹配。');
      Lines.Insert(I + 1, '      ClientEvents.ExtEvents.Strings = (' + DFMString(TimeClickJS) + ')');
    end;
    for I := 0 to Lines.Count - 1 do
      if Pos('    ''  cDataNodeName   = ', Lines[I]) = 1 then
        Lines[I] := '    ' + DFMString('  cDataNodeName   = ' +
          QuotedStr(Str(AConfig, 'TWebDataNodeName')) + ';');

    First := Lines.IndexOf('    object aName: TUgEdit');
    Last := First;
    while (Last >= 0) and (Last < Lines.Count) and (Lines[Last] <> '  end') do Inc(Last);
    if (First < 0) or (Last >= Lines.Count) then
      raise Exception.Create('编辑器模板控件边界不匹配。');
    { 列优先排布：每列最多 CEditorMaxRows 个字段，填满一列再开右一列；
      行步进按控件实际高度（check 25、memo 170、其余 50）+ 10；
      面板高/线框宽由内容推导（高 = 10 + 各列内容高最大值，宽 = 10 + Σ 列宽）。 }
    if Names.Count > 0 then
    begin
      ColCount := (Names.Count + CEditorMaxRows - 1) div CEditorMaxRows;
      ItemsPerColumn := (Names.Count + ColCount - 1) div ColCount;
    end
    else
      ItemsPerColumn := CEditorMaxRows;
    CurCol := -1; ColCursor := 10; ColLeft := 10; ColWidthSum := 0;
    PanelContent := 0; CurColWide := False;
    for I := 0 to Names.Count - 1 do
    begin
      if (I div ItemsPerColumn) <> CurCol then
      begin
        if CurCol >= 0 then
        begin
          if CurColWide then Inc(ColWidthSum, CEditorColumnWide)
          else Inc(ColWidthSum, CEditorColumnStep);
        end;
        CurCol := I div ItemsPerColumn;
        ColLeft := 10 + ColWidthSum;
        ColCursor := 10;
        CurColWide := False;
      end;
      if ObjectTypes[I] = 'memo' then
      begin
        Controls.Add('    object ' + Names[I] + ': TUgMemo');
        FieldHeight := 170; { Same default as the recovered memo DFM. }
      end
      else
      begin
        ClassName := 'TUgEdit';
        if ObjectTypes[I] = 'number' then ClassName := 'TUgNumberEdit';
        if ObjectTypes[I] = 'check' then ClassName := 'TUgCheckBox';
        if ObjectTypes[I] = 'combobox' then ClassName := 'TUgComboBox';
        if ObjectTypes[I] = 'lookupedit' then ClassName := 'TUgLookupEdit';
        if ObjectTypes[I] = 'lookupeditextra' then ClassName := 'TUgLookupEditExtra';
        if ObjectTypes[I] = 'gridcombobox' then ClassName := 'TUgGridCombobox';
        if ObjectTypes[I] = 'gridcomboboxextra' then ClassName := 'TUgGridComboboxExtra';
        if (ObjectTypes[I] = 'date') or (ObjectTypes[I] = 'time') or
          (ObjectTypes[I] = 'datetime') then ClassName := 'TUgDateTimePicker';
        Controls.Add('    object ' + Names[I] + ': ' + ClassName);
        if ObjectTypes[I] = 'check' then FieldHeight := 25
        else FieldHeight := 50;
      end;
      Controls.Add('      Left = ' + IntToStr(ColLeft));
      { 原版编辑器的复选框比行游标低 5px（行游标仍按“上一控件高 + 10”前进）。 }
      if ObjectTypes[I] = 'check' then
        Controls.Add('      Top = ' + IntToStr(ColCursor + 5))
      else
        Controls.Add('      Top = ' + IntToStr(ColCursor));
      if (ObjectTypes[I] = 'lookupeditextra') or (ObjectTypes[I] = 'gridcomboboxextra') then FieldWidth := 360
      else FieldWidth := 200;
      if FieldWidth = 360 then CurColWide := True;
      Controls.Add('      Width = ' + IntToStr(FieldWidth));
      Controls.Add('      Height = ' + IntToStr(FieldHeight));
      Controls.Add('      Hint = ' + DFMString(''));
      if IsGrid(ObjectTypes[I]) then
      begin
        Drop := TJSONObject.ParseJSONValue(Options[I]) as TJSONObject;
        LookupParts := TStringList.Create;
        try
          Controls.Add('      GridLookupDataSet = ugLookupData' + Names[I]);
          Controls.Add('      GridValueField = ' + DFMString(Str(Drop, 'edOptionValue')));
          if ObjectTypes[I] = 'gridcomboboxextra' then
          begin
            Controls.Add('      GridDisplayField = ' + DFMString(Str(Drop, 'edOptionDisplay')));
            Controls.Add('      GridValueWidth = 120');
          end;
          Controls.Add('      GridLookupDataSetFilter = ' + BoolToStr(not DynamicGrid(Drop), True));
          Controls.Add('      GridWebOptionPaged = ' + BoolToStr(SameText(Str(Drop, 'cbGridPageSetting'), 'Open'), True));
          if SameText(Str(Drop, 'cbGridPageSetting'), 'Open') then
            Controls.Add('      GridWebOptionPageSize = ' + IntToStr(StrToInt(Str(Drop, 'sePageSize'))));
          LookupParts.StrictDelimiter := True;
          LookupParts.Delimiter := ';';
          LookupParts.DelimitedText := Str(Drop, 'edOptionFields');
          Controls.Add('      GridLookupFields = <');
          for J := 0 to LookupParts.Count - 1 do
          begin
            LookupField := Trim(LookupParts[J]); LookupCaption := LookupField;
            Section := Pos('@', LookupField);
            if Section > 0 then
            begin
              LookupCaption := Copy(LookupField, Section + 1, MaxInt);
              LookupField := Copy(LookupField, 1, Section - 1);
            end;
            if not IsValidIdent(LookupField) then Exit(Reject('无效表格下拉字段：' + LookupField));
            Controls.Add('        item');
            Controls.Add('          IsLookUp = ' + BoolToStr(GridSearchField(Drop, LookupField), True));
            Controls.Add('          Visible = True');
            Controls.Add('          FieldName = ' + DFMString(LookupField));
            Controls.Add('          Caption = ' + DFMString(LookupCaption));
            Controls.Add('          Width = 160');
            Controls.Add('        end');
          end;
          Controls.Add('      >');
        finally LookupParts.Free; Drop.Free; end;
      end;
      if (ObjectTypes[I] = 'lookupedit') or (ObjectTypes[I] = 'lookupeditextra') then
      begin
        Drop := TJSONObject.ParseJSONValue(Options[I]) as TJSONObject;
        LookupParts := TStringList.Create;
        try
          Controls.Add('      LookupData = ugLookupData' + Names[I]);
          Controls.Add('      LookupCaption = ' + DFMString(Str(Drop, 'edOptionCaption')));
          Controls.Add('      LookupValueField = ' + DFMString(Str(Drop, 'edOptionValue')));
          if ObjectTypes[I] = 'lookupeditextra' then
          begin
            Controls.Add('      LookupDisplayField = ' + DFMString(Str(Drop, 'edOptionDisplay')));
            Controls.Add('      LookupCodeWidth = 120');
          end;
          LookupParts.StrictDelimiter := True;
          LookupParts.Delimiter := ';';
          { 列（含 字段@标题）取 展示字段(edOptionFields)，为空时回退到 搜索字段。 }
          LookupParts.DelimitedText := Str(Drop, 'edOptionFields');
          if Trim(LookupParts.DelimitedText) = '' then
            LookupParts.DelimitedText := Str(Drop, 'edOptionLookupFields');
          Controls.Add('      LookupFields = <');
          for J := 0 to LookupParts.Count - 1 do
          begin
            S := Trim(LookupParts[J]);
            if S = '' then Continue;
            Section := Pos('@', S);
            LookupField := S; LookupCaption := S;
            if Section > 0 then
            begin
              LookupField := Copy(S, 1, Section - 1);
              LookupCaption := Copy(S, Section + 1, MaxInt);
            end;
            if not IsValidIdent(LookupField) then
              Exit(Reject('无效查找列字段：' + LookupField));
            Controls.Add('        item');
            Controls.Add('          FieldName = ' + DFMString(LookupField));
            Controls.Add('          Caption = ' + DFMString(LookupCaption));
            Controls.Add('          Width = 160');
            Controls.Add('        end');
          end;
          Controls.Add('      >');
        finally LookupParts.Free; Drop.Free; end;
      end;
      if ObjectTypes[I] = 'time' then
        Controls.Add('      ClientEvents.UniEvents.Strings = (' +
          DFMString('beforeInit=function beforeInit(sender, config){config.ugTimeKey="' + Names[I] + '";}') + ')');
      { TUniMemo.Text is public for scripts, not published for DFM streaming.
        Leave its initially empty Lines at the constructor default. }
      if ObjectTypes[I] = 'edit' then
        Controls.Add('      Text = ''''');
      if ObjectTypes[I] = 'number' then
      begin
        { 原版数字框带 DecimalSeparator；AllowBlank/DecimalPrecision 为本实现既有功能，保留。 }
        Controls.Add('      DecimalSeparator = ''.''');
        Controls.Add('      AllowBlank = True');
        Controls.Add('      DecimalPrecision = ' + Scales[I]);
      end;
      if (ObjectTypes[I] = 'date') or (ObjectTypes[I] = 'time') or
        (ObjectTypes[I] = 'datetime') then
      begin
        S := 'tUniDate';
        if ObjectTypes[I] = 'time' then S := 'tUniTime';
        if ObjectTypes[I] = 'datetime' then S := 'tUniDateTime';
        Controls.Add('      Kind = ' + S);
        Controls.Add('      DateTime = 0');
        Controls.Add('      DateFormat = ''yyyy-MM-dd''');
        Controls.Add('      TimeFormat = ''HH:mm:ss''');
        Controls.Add('      ShowBlankDate = True');
      end;
      if ObjectTypes[I] = 'check' then
        { 用户 2026-09-14：check 控件用 Caption 承载精灵配置的标题，FieldLabel 置空。 }
        Controls.Add('      Caption = ' + DFMString(Captions[I]));
      if (ObjectTypes[I] = 'combobox') and (SqlCombos.IndexOf(Names[I]) < 0) then
      begin
        Items.Text := Options[I];
        Controls.Add('      Style = csDropDownList');
        Controls.Add('      Items.Strings = (');
        for J := 0 to Items.Count - 1 do
          Controls.Add('        ' + DFMString(Items[J]));
        Controls.Add('      )');
      end;
      Controls.Add('      TabOrder = ' + IntToStr(I + 1));
      if ObjectTypes[I] = 'check' then
      begin
        { 用户 2026-09-14：check 的标题走 Caption，FieldLabel 必须为空；
          对齐仍按用户要求写 laLeft（uniGUI 默认值，FieldLabel 为空时不影响外观）。 }
        Controls.Add('      FieldLabel = ' + DFMString(''));
        Controls.Add('      FieldLabelAlign = laLeft');
      end
      else
      begin
        Controls.Add('      FieldLabel = ' + DFMString(Captions[I]));
        { 其余类型保持原版编辑器的 laTop。 }
        Controls.Add('      FieldLabelAlign = laTop');
      end;
      if Required.IndexOf(Columns[I]) >= 0 then
        { 原版编辑器必填标签色为 6889153（$00691EC1），非 clRed。 }
        Controls.Add('      FieldLabelFont.Color = 6889153');
      if (ObjectTypes[I] = 'edit') or (ObjectTypes[I] = 'memo') or
        (ObjectTypes[I] = 'number') or (ObjectTypes[I] = 'combobox') then
        Controls.Add('      SelectOnFocus = True');
      Controls.Add('    end');
      Inc(ColCursor, FieldHeight + 10);
      if ColCursor - 10 > PanelContent then PanelContent := ColCursor - 10;
    end;
    if CurCol >= 0 then
    begin
      if CurColWide then Inc(ColWidthSum, CEditorColumnWide)
      else Inc(ColWidthSum, CEditorColumnStep);
    end;
    PanelHeight := 10 + PanelContent;
    FrameWidth := 10 + ColWidthSum;
    ReplaceBlock(First, Last, Controls);
    Controls.Clear;
    Controls.Add('  object errorAlert: TUgSweetAlert');
    Controls.Add('    Left = 20');
    Controls.Add('    Top = ' + IntToStr(PanelHeight + 60));
    Controls.Add('    AlertType = atError');
    Controls.Add('    ShowConfirmButton = True');
    Controls.Add('    ShowCancelButton = False');
    Controls.Add('  end');
    for I := 0 to SqlCombos.Count - 1 do
    begin
      Controls.Add('  object ugComboData' + SqlCombos[I] + ': TUgClientDataSet');
      Controls.Add('    DataNodeName = ' + DFMString(Str(AConfig, 'TWebDataNodeName')));
      Controls.Add('    PageRowCount = -1');
      Controls.Add('    Active = False');
      Controls.Add('  end');
    end;
    for I := 0 to Names.Count - 1 do
      if (ObjectTypes[I] = 'lookupedit') or (ObjectTypes[I] = 'lookupeditextra') or IsGrid(ObjectTypes[I]) then
      begin
        Drop := TJSONObject.ParseJSONValue(Options[I]) as TJSONObject;
        try
          LookupSQL := Str(Drop, 'mmText');
          { The wizard persists memo line breaks as literal escape sequences. }
          LookupSQL := StringReplace(LookupSQL, '\r\n', sLineBreak, [rfReplaceAll]);
          if IsGrid(ObjectTypes[I]) then
          begin
            LookupSQL := GridSQL(Drop);
            if DynamicGrid(Drop) then LookupSQL := 'select ug_grid.* from (' + LookupSQL + ') ug_grid where 1 = 2';
          end;
          Controls.Add('  object ugLookupData' + Names[I] + ': TUgClientDataSet');
          Controls.Add('    DataNodeName = ' + DFMString(Str(AConfig, 'TWebDataNodeName')));
          Controls.Add('    CommandText = ' + DFMString(LookupSQL));
          Controls.Add('    SelectMaxRecCount = ' + Str(Drop, 'seMaxRecordCount'));
          Controls.Add('    PageRowCount = -1');
          { Tag is an opt-in contract with the rebuilt host lookup pager.
            Do not activate native dataset pagination/counting on initial load. }
          if not IsGrid(ObjectTypes[I]) and SameText(Str(Drop, 'cbGridPageSetting'), 'Open') then
            Controls.Add('    Tag = ' + IntToStr(StrToInt(Str(Drop, 'sePageSize'))));
          Controls.Add('    Active = False');
          Controls.Add('  end');
        finally Drop.Free; end;
      end;
    Last := Lines.Count - 1;
    while (Last >= 0) and (Trim(Lines[Last]) = '') do Dec(Last);
    if Lines[Last] <> 'end' then raise Exception.Create('模板根结束标记不匹配。');
    ReplaceBlock(Last, Last, Controls);
    Section := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      if Lines[I] = '  object pButtons: TUgContainerPanel' then Section := 1;
      if Lines[I] = '  object pEditControls: TUgContainerPanel' then Section := 2;
      if Lines[I] = '    object lbEditControls: TUgContainerPanel' then Section := 3;
      if (Section = 0) and (Lines[I] = '  Height = 162') then
        Lines[I] := '  Height = ' + IntToStr(PanelHeight + 32);
      if (Section = 0) and (Lines[I] = '  Width = 220') then
        Lines[I] := '  Width = ' + IntToStr(FrameWidth);
      if (Section = 1) and (Lines[I] = '    Top = 130') then
        Lines[I] := '    Top = ' + IntToStr(PanelHeight);
      { pButtons 内按钮为 alRight：模板按 220 宽排的设计期 Left 需随线框宽度平移。 }
      if (Section = 1) and (Copy(Lines[I], 1, 13) = '      Left = ') then
        Lines[I] := '      Left = ' + IntToStr(StrToInt(Copy(Lines[I], 14, MaxInt)) + (FrameWidth - 220));
      if (Section = 1) and (Lines[I] = '    Width = 220') then
        Lines[I] := '    Width = ' + IntToStr(FrameWidth);
      if (Section = 2) and (Lines[I] = '    Height = 130') then
        Lines[I] := '    Height = ' + IntToStr(PanelHeight);
      if (Section = 2) and (Lines[I] = '    Width = 220') then
        Lines[I] := '    Width = ' + IntToStr(FrameWidth);
      if (Section = 3) and (Lines[I] = '      Top = 129') then
        Lines[I] := '      Top = ' + IntToStr(PanelHeight - 1);
      if (Section = 3) and (Lines[I] = '      Width = 220') then
        Lines[I] := '      Width = ' + IntToStr(FrameWidth);
    end;
    ADFM := Lines.Text;
    Result := True;
  finally
    HiddenVars.Free; Hidden.Free;
    SqlCombos.Free; Items.Free; Options.Free; Scales.Free;
    ObjectTypes.Free; Required.Free; Columns.Free;
    Controls.Free; Code.Free; Lines.Free; Used.Free;
    Captions.Free; Vars.Free; Names.Free;
  end;
end;

end.
