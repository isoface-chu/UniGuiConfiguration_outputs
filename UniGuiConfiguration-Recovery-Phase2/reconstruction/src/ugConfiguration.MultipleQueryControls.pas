unit ugConfiguration.MultipleQueryControls;

interface

uses System.SysUtils, System.Classes, System.JSON;

procedure AddMultipleInHelpers(Code: TStrings);

type
  TMultipleQueryControl = class
  private
    FName, FKind, FCaption, FSQL: string;
    FDrop: TJSONObject;
    FHide: Boolean;
    FScale: Integer;
    function IsGrid: Boolean;
    function IsLookup: Boolean;
    function Dynamic: Boolean;
    function Option(const Key: string): string;
  public
    constructor Create(Row, Column: TJSONObject; Index: Integer);
    destructor Destroy; override;
    function Present: string;
    function ParameterValue(const OperatorName: string): string;
    procedure AddCode(Code, Events, Init: TStrings);
    procedure AddControl(Lines: TStrings; X, Y, Width, Height: Integer; LeftLayout: Boolean;
      const TextCase: string = 'Normal');
    procedure AddData(Lines: TStrings; Index: Integer);
    property Kind: string read FKind;
    property Name: string read FName;
  end;

implementation

procedure AddMultipleInHelpers(Code: TStrings);
  procedure A(const S: string);
  begin Code.Add(S); end;
begin
  A('//IN 查询沿用原版换行分隔；每行作为独立参数，逗号和分号属于值本身');
  A('procedure AppendInQuery(var SQL: string; const AField, APrefix, AText: string;');
  A('  Values: TStringList; var ParameterCount: Integer);');
  A('var L: TStringList; I, N: Integer; Names, V, P: string;');
  A('begin');
  A('  L := TStringList.Create;');
  A('  try');
  A('    L.Text := AText;');
  A('    Names := '''';');
  A('    N := 0;');
  A('    for I := 0 to L.Count - 1 do');
  A('    begin');
  A('      V := L.Strings[I];');
  A('      if Trim(V) <> '''' then');
  A('      begin');
  A('        Inc(ParameterCount);');
  A('        if ParameterCount > 900 then');
  A('          RaiseException(UGMM.LT(''查询参数超过 900 个，请减少输入值后重试。''));');
  A('        P := APrefix + ''_in'' + IntToStr(N);');
  A('        if Names <> '''' then Names := Names + '', '';');
  A('        Names := Names + '':'' + P;');
  A('        Values.Add(P + ''='' + V);');
  A('        Inc(N);');
  A('      end;');
  A('    end;');
  A('    if Names <> '''' then SQL := SQL + '' and ('' + AField + '' in ('' + Names + ''))'';');
  A('  finally');
  A('    L.Free;');
  A('  end;');
  A('end;');
  A('');
  A('//将多值查询绑定为文本参数，保留中文、单引号与前导零');
  A('procedure BindInQuery(Values: TStringList);');
  A('var I: Integer;');
  A('begin');
  A('  for I := 0 to Values.Count - 1 do');
  A('  begin');
  A('    cdsMain.ParamByName(Values.Names[I]).DataType := ftWideString;');
  A('    cdsMain.ParamByName(Values.Names[I]).Value := Values.Values[Values.Names[I]];');
  A('  end;');
  A('end;');
  A('');
end;

function Str(J: TJSONObject; const Key: string): string;
var V: TJSONValue;
begin
  Result := '';
  if J = nil then Exit;
  V := J.GetValue(Key);
  if (V <> nil) and not (V is TJSONNull) then Result := V.Value;
end;

function Yes(const V: string): Boolean;
begin Result := (V = '1') or (V = '-1') or SameText(V, 'True'); end;

{ DFM 字符串常量：ASCII 走引号包裹（内部单引号翻倍），非 ASCII 与控制字符必须写成引号**外面**的
  字符码（`#25968#25454`）。宿主 2026-09-21 反馈"查询条件生成的标题中文是乱码"——根因就是这里原先
  只做 QuotedStr：中文被当成引号里的普通文本，宿主按 DFM 文本编码解析就成了乱码。
  纯 ASCII 输入时输出与旧实现逐字符一致（不影响既有 mtMultiple 模块）。 }
function Quoted(const V: string): string;
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

function TMultipleQueryControl.Option(const Key: string): string;
begin Result := Str(FDrop, Key); end;
function TMultipleQueryControl.IsGrid: Boolean;
begin Result := (FKind = 'gridcombobox') or (FKind = 'gridcomboboxextra'); end;
function TMultipleQueryControl.IsLookup: Boolean;
begin Result := IsGrid or (FKind = 'lookupedit') or (FKind = 'lookupeditextra'); end;
function TMultipleQueryControl.Dynamic: Boolean;
begin Result := IsGrid and Yes(Option('cbDynamicLoading')); end;

procedure AddStringStatement(Lines: TStrings; const Before, Value, After: string);
var P: Integer; Chunk: string;
begin
  Lines.Add(Before);
  P := 1;
  repeat
    Chunk := Copy(Value, P, 40);
    Inc(P, 40);
    if P <= Length(Value) then Lines.Add('    ' + Quoted(Chunk) + ' +')
    else Lines.Add('    ' + Quoted(Chunk) + After);
  until P > Length(Value);
end;

constructor TMultipleQueryControl.Create(Row, Column: TJSONObject; Index: Integer);
var V: TJSONValue; Parts: TStringList; P, N: Integer; F, O: string;
begin
  inherited Create;
  FName := 'q' + IntToStr(Index);
  FKind := LowerCase(Trim(Str(Row, 'fdObject_Type')));
  FCaption := Str(Row, 'fdCaption');
  FHide := Yes(Str(Row, 'fdHideCaption'));
  FScale := StrToIntDef(Str(Column, 'fdCOLUMN_SCAL'), 6);
  if (FScale < 0) or (FScale > 15) then FScale := 6;
  if Pos(';' + FKind + ';', ';edit;memo;number;date;time;datetime;check;combobox;' +
    'lookupedit;lookupeditextra;gridcombobox;gridcomboboxextra;') = 0 then
    raise Exception.Create('不支持的查询控件类型：' + FKind);
  if FKind = '' then raise Exception.Create('查询控件类型不能为空。');
  O := LowerCase(Trim(Str(Row, 'fdComparisonOperator')));
  if (O = 'in') and (FKind <> 'memo') and (FKind <> 'edit') then
    raise Exception.Create('in 多值查询请使用 memo（每行一个值）或 edit（单值）控件。');
  if ((FKind = 'number') or (FKind = 'date') or (FKind = 'datetime') or
    (FKind = 'time') or (FKind = 'check')) and (O = 'like') then
    raise Exception.Create('数字、日期、时间和布尔查询请使用比较运算符，不使用 like。');
  if not ((FKind = 'combobox') or IsLookup) then Exit;
  V := Row.GetValue('fdDropDownOptions');
  if V is TJSONObject then V := TJSONValue(V.Clone)
  else V := TJSONObject.ParseJSONValue(Str(Row, 'fdDropDownOptions'));
  if not (V is TJSONObject) then
  begin V.Free; raise Exception.Create('查询字段 ' + FCaption + ' 缺少下拉配置。'); end;
  FDrop := TJSONObject(V);
  if FKind = 'combobox' then
  begin
    if not SameText(Option('cbDropDownType'), 'SetText') and
      not SameText(Option('cbDropDownType'), 'SqlText') and
      not SameText(Option('cbDropDownType'), 'SqlQuery') then
      raise Exception.Create('combobox 查询支持 SetText / SqlText / SqlQuery。');
    if Yes(Option('cbDynamicLoading')) and
      not SameText(Option('cbDropDownType'), 'SqlQuery') then
      raise Exception.Create('combobox 使用一次加载选项，请关闭动态加载。');
    if (Option('edOptionDisplay') <> '') and
      not SameText(Option('cbDropDownType'), 'SqlQuery') then
      raise Exception.Create('combobox 不支持独立显示值，请使用 extra 查找控件。');
    // SqlQuery is accepted from the shared options editor. A plain combobox
    // loads the value column once; it does not have a separate display column.
    if SameText(Option('cbDropDownType'), 'SetText') then
    begin
      if Option('edOptionValue') <> '' then
        raise Exception.Create('固定选项不支持独立值映射。');
      Exit;
    end;
  end else
  begin
    if not SameText(Option('cbDropDownType'), 'SqlQuery') then
      raise Exception.Create('查找查询控件需要 SqlQuery 配置。');
    if not IsValidIdent(Option('edOptionValue')) then
      raise Exception.Create('查找查询控件需要有效的值字段。');
    if (Pos('extra', FKind) > 0) and not IsValidIdent(Option('edOptionDisplay')) then
      raise Exception.Create('extra 查找查询控件需要有效的显示字段。');
    if not TryStrToInt(Option('seMaxRecordCount'), N) or (N < 1) then
      raise Exception.Create('查找最大记录数必须为正整数。');
    if SameText(Option('cbGridPageSetting'), 'Open') then
      if not TryStrToInt(Option('sePageSize'), N) or (N < 1) or (N > 500) then
        raise Exception.Create('查找分页行数须为1到500。');
    Parts := TStringList.Create;
    try
      Parts.StrictDelimiter := True; Parts.Delimiter := ';';
      Parts.DelimitedText := Option('edOptionLookupFields');
      if Parts.Count = 0 then raise Exception.Create('查找查询控件需要检索字段。');
      if IsGrid then
      begin
        if Trim(Option('edOptionFields')) = '' then raise Exception.Create('表格下拉需要显示列。');
        Parts.DelimitedText := Parts.DelimitedText + ';' + Option('edOptionFields');
      end;
      for F in Parts do
      begin
        P := Pos('@', F);
        if P = 0 then O := Trim(F) else O := Trim(Copy(F, 1, P - 1));
        if not IsValidIdent(O) then raise Exception.Create('无效查找列：' + F);
      end;
    finally Parts.Free; end;
  end;
  FSQL := Trim(StringReplace(StringReplace(Option('mmText'), #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]));
  if (FSQL <> '') and (FSQL[Length(FSQL)] = ';') then Delete(FSQL, Length(FSQL), 1);
  if not SameText(Copy(FSQL, 1, 7), 'select ') or (Pos(';', FSQL) > 0) or
    (Pos(':', FSQL) > 0) or (Pos('--', FSQL) > 0) or (Pos('/*', FSQL) > 0) then
    raise Exception.Create('查询选项 SQL 需要无参数、无注释的单条 SELECT。');
  if (Option('edOptionValue') <> '') and not IsValidIdent(Option('edOptionValue')) then
    raise Exception.Create('无效下拉返回字段。');
end;

destructor TMultipleQueryControl.Destroy;
begin FDrop.Free; inherited; end;

function TMultipleQueryControl.Present: string;
begin
  Result := 'VarToStr(' + FName + '.Text) <> ''''';
  if FKind = 'check' then Result := FName + 'Use.Checked';
  if (FKind = 'date') or (FKind = 'datetime') then Result := FName + '.DateTime <> 0';
  if FKind = 'time' then Result := FName + 'TimeValue.Text <> ''''';
end;

function TMultipleQueryControl.ParameterValue(const OperatorName: string): string;
begin
  Result := 'AsString := VarToStr(' + FName + '.Text)';
  if OperatorName = 'like' then Result := 'AsString := ''%'' + VarToStr(' + FName + '.Text) + ''%''';
  if FKind = 'number' then Result := 'AsFloat := ' + FName + '.Value';
  if (FKind = 'date') or (FKind = 'datetime') then Result := 'AsDateTime := ' + FName + '.DateTime';
  if FKind = 'time' then Result := 'AsString := ' + FName + 'TimeValue.Text';
  if FKind = 'check' then Result := 'AsBoolean := ' + FName + '.Checked';
end;

procedure TMultipleQueryControl.AddCode(Code, Events, Init: TStrings);
var Parts: TStringList; F, SQL, DataName: string; P, I: Integer;
begin
  DataName := 'lookupQuery' + FName;
  if FKind = 'time' then
  begin
    Code.Add('procedure ' + FName + 'OnAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);');
    Code.Add('begin');
    Code.Add('  if EventName = ''queryTime'' then');
    Code.Add('    ' + FName + 'TimeValue.Text := Params.Values[''value''];');
    Code.Add('end;');
    Code.Add('');
    Events.Add(FName + '|<This>.OnAjaxEvent:' + FName + 'OnAjaxEvent');
  end;
  if not ((FKind = 'combobox') or IsLookup) then Exit;
  Parts := TStringList.Create;
  try
    if FKind = 'combobox' then
    begin
      Code.Add('//加载查询条件 ' + FName + ' 的下拉选项，保留空选项用于取消筛选');
      Code.Add('procedure Load' + FName + 'Items;');
      Code.Add('begin');
      Code.Add('  ' + FName + '.Items.Clear;');
      // Empty option lets the user clear an exact-value query.
      Code.Add('  ' + FName + '.Items.Add('''');');
      if SameText(Option('cbDropDownType'), 'SetText') then
      begin
        Parts.Text := Option('mmText');
        for F in Parts do if F <> '' then
          AddStringStatement(Code, '  ' + FName + '.Items.Add(', F, ');');
      end else
      begin
        Code.Add('  ' + DataName + '.DataNodeName := cDataNodeName;');
        Code.Add('  try');
        Code.Add('    ' + DataName + '.Open;');
        Code.Add('    ' + DataName + '.First;');
        Code.Add('    while not ' + DataName + '.Eof do');
        Code.Add('    begin');
        if Option('edOptionValue') = '' then F := DataName + '.Fields[0].AsString'
        else F := DataName + '.FieldByName(' + Quoted(Option('edOptionValue')) + ').AsString';
        Code.Add('      ' + FName + '.Items.Add(' + F + ');');
        Code.Add('      ' + DataName + '.Next;');
        Code.Add('    end;');
        Code.Add('  finally');
        Code.Add('    ' + DataName + '.Close;');
        Code.Add('  end;');
      end;
      Code.Add('end;'); Code.Add('');
      Init.Add('  Load' + FName + 'Items;');
    end else
    begin
      Init.Add('  ' + DataName + '.DataNodeName := cDataNodeName;');
      Init.Add('  ' + DataName + '.Open;');
      if Dynamic then
      begin
        Parts.StrictDelimiter := True; Parts.Delimiter := ';';
        Parts.DelimitedText := Option('edOptionLookupFields');
        SQL := 'select ug_query.* from (' + FSQL + ') ug_query where ';
        for I := 0 to Parts.Count - 1 do
        begin
          F := Trim(Parts[I]); P := Pos('@', F); if P > 0 then F := Copy(F, 1, P - 1);
          if I > 0 then SQL := SQL + ' or ';
          SQL := SQL + 'ug_query.' + F + ' like :qs' + IntToStr(I);
        end;
        Code.Add('//根据查询条件 ' + FName + ' 的输入值刷新候选数据');
        Code.Add('procedure ' + FName + 'OnExtEditValueChange(Sender: TObject; const Value: string);');
        Code.Add('begin');
        Code.Add('  ' + DataName + '.Close;');
        AddStringStatement(Code, '  ' + DataName + '.CommandText :=', SQL, ';');
        for I := 0 to Parts.Count - 1 do
          Code.Add('  ' + DataName + '.ParamByName(''qs' + IntToStr(I) + ''').AsString := ''%'' + Value + ''%'';');
        Code.Add('  ' + DataName + '.Open;');
        Code.Add('end;'); Code.Add('');
        Events.Add(FName + '|<This>.OnExtEditValueChange:' + FName + 'OnExtEditValueChange');
      end;
    end;
  finally Parts.Free; end;
end;

procedure TMultipleQueryControl.AddControl(Lines: TStrings; X, Y, Width, Height: Integer; LeftLayout: Boolean;
  const TextCase: string);
var C, F, Caption, DataName, ListName: string; Parts, Search: TStringList; P: Integer;
begin
  C := 'TUgEdit';
  if FKind = 'memo' then C := 'TUgMemo';
  if FKind = 'number' then C := 'TUgNumberEdit';
  if FKind = 'check' then C := 'TUgCheckBox';
  if FKind = 'combobox' then C := 'TUgComboBox';
  if FKind = 'lookupedit' then C := 'TUgLookupEdit';
  if FKind = 'lookupeditextra' then C := 'TUgLookupEditExtra';
  if FKind = 'gridcombobox' then C := 'TUgGridCombobox';
  if FKind = 'gridcomboboxextra' then C := 'TUgGridComboboxExtra';
  if (FKind = 'date') or (FKind = 'time') or (FKind = 'datetime') then C := 'TUgDateTimePicker';
  Lines.Add('    object ' + FName + ': ' + C);
  Lines.Add('      Left = ' + IntToStr(X)); Lines.Add('      Top = ' + IntToStr(Y));
  Lines.Add('      Width = ' + IntToStr(Width)); Lines.Add('      Height = ' + IntToStr(Height));
  if LeftLayout then
  begin
    Lines.Add('      AlignWithMargins = True'); Lines.Add('      Align = alTop');
    Lines.Add('      Margins.Left = 10'); Lines.Add('      Margins.Top = 10');
    Lines.Add('      Margins.Right = 10');
  end;
  if not FHide then Lines.Add('      FieldLabel = ' + Quoted(FCaption));
  Lines.Add('      FieldLabelAlign = laTop');
  // Extra controls are composite containers, not published ClientEvents owners.
  if (FKind <> 'time') and (Pos('extra', FKind) = 0) then
    Lines.Add('      ClientEvents.UniEvents.Strings = (' +
      Quoted('beforeInit=function(sender,config){config.ugQueryField=true;}') + ')');
  if FKind = 'edit' then Lines.Add('      Text = ''''');
  // 文本大小写只作用于普通输入框；下拉与查找控件保持返回值的原始大小写。
  if FKind = 'edit' then
  begin
    if SameText(TextCase, 'Upper') then Lines.Add('      CharCase = ecUpperCase');
    if SameText(TextCase, 'Lower') then Lines.Add('      CharCase = ecLowerCase');
  end;
  if FKind = 'check' then Lines.Add('      Caption = ' + Quoted('是'));
  if FKind = 'combobox' then begin Lines.Add('      Style = csDropDownList'); Lines.Add('      Text = '''''); end;
  if FKind = 'number' then
  begin Lines.Add('      AllowBlank = True'); Lines.Add('      DecimalPrecision = ' + IntToStr(FScale)); end;
  if C = 'TUgDateTimePicker' then
  begin
    C := 'tUniDate'; if FKind = 'time' then C := 'tUniTime'; if FKind = 'datetime' then C := 'tUniDateTime';
    Lines.Add('      Kind = ' + C); Lines.Add('      DateTime = 0');
    Lines.Add('      DateFormat = ''yyyy-MM-dd'''); Lines.Add('      TimeFormat = ''HH:mm:ss''');
    Lines.Add('      ShowBlankDate = True');
    if FKind = 'time' then
    begin
      Lines.Add('      ClientEvents.UniEvents.Strings = (' +
        Quoted('beforeInit=function(sender,config){config.ugQueryField=true;config.ugQueryTime="' + FName + '";}') + ')');
      Lines.Add('      ClientEvents.ExtEvents.Strings = (' +
        Quoted('change=function(sender){var r=sender.getRawValue(),v=sender.getValue();' +
        'var t=r===""?"":(sender.isValid()&&v?Ext.Date.format(v,"H:i:s"):"invalid");' +
        'ajaxRequest(sender,"queryTime",["value="+encodeURIComponent(t)]);}') + ')');
    end;
  end;
  if IsLookup then
  begin
    DataName := 'lookupQuery' + FName;
    Parts := TStringList.Create; Search := TStringList.Create;
    try
      Parts.StrictDelimiter := True; Parts.Delimiter := ';';
      Search.StrictDelimiter := True; Search.Delimiter := ';';
      Search.DelimitedText := Option('edOptionLookupFields');
      if IsGrid then
      begin
        Lines.Add('      GridLookupDataSet = ' + DataName);
        Lines.Add('      GridValueField = ' + Quoted(Option('edOptionValue')));
        if FKind = 'gridcomboboxextra' then
        begin
          Lines.Add('      GridDisplayField = ' + Quoted(Option('edOptionDisplay')));
          Lines.Add('      GridValueWidth = 90');
        end;
        Lines.Add('      GridLookupDataSetFilter = ' + BoolToStr(not Dynamic, True));
        Lines.Add('      GridWebOptionPaged = ' + BoolToStr(SameText(Option('cbGridPageSetting'), 'Open'), True));
        if SameText(Option('cbGridPageSetting'), 'Open') then
          Lines.Add('      GridWebOptionPageSize = ' + Option('sePageSize'));
        Parts.DelimitedText := Option('edOptionFields'); ListName := 'GridLookupFields';
      end else
      begin
        Lines.Add('      LookupData = ' + DataName);
        Lines.Add('      LookupCaption = ' + Quoted(Option('edOptionCaption')));
        Lines.Add('      LookupValueField = ' + Quoted(Option('edOptionValue')));
        if FKind = 'lookupeditextra' then
        begin Lines.Add('      LookupDisplayField = ' + Quoted(Option('edOptionDisplay'))); Lines.Add('      LookupCodeWidth = 90'); end;
        Parts.DelimitedText := Option('edOptionLookupFields'); ListName := 'LookupFields';
      end;
      Lines.Add('      ' + ListName + ' = <');
      for C in Parts do
      begin
        F := Trim(C); Caption := F; P := Pos('@', F);
        if P > 0 then begin Caption := Copy(F, P + 1, MaxInt); F := Copy(F, 1, P - 1); end;
        Lines.Add('        item');
        Lines.Add('          FieldName = ' + Quoted(F)); Lines.Add('          Caption = ' + Quoted(Caption));
        Lines.Add('          Width = 160');
        if IsGrid then
        begin
          Lines.Add('          Visible = True');
          Lines.Add('          IsLookUp = ' + BoolToStr((Search.IndexOf(F) >= 0) or (Search.IndexOf(C) >= 0), True));
        end;
        Lines.Add('        end');
      end;
      Lines.Add('      >');
    finally Search.Free; Parts.Free; end;
  end;
  Lines.Add('    end');
  if FKind = 'check' then
  begin
    Lines.Add('    object ' + FName + 'Use: TUgCheckBox');
    Lines.Add('      Left = ' + IntToStr(X)); Lines.Add('      Top = ' + IntToStr(Y + Height));
    Lines.Add('      Width = ' + IntToStr(Width)); Lines.Add('      Height = 22');
    if LeftLayout then begin Lines.Add('      Align = alTop'); Lines.Add('      AlignWithMargins = True'); end;
    Lines.Add('      Caption = ' + Quoted('启用此条件')); Lines.Add('      Checked = False'); Lines.Add('    end');
  end;
end;

procedure TMultipleQueryControl.AddData(Lines: TStrings; Index: Integer);
begin
  if FKind = 'time' then
  begin
    Lines.Add('  object ' + FName + 'TimeValue: TUgEdit');
    Lines.Add('    Visible = False'); Lines.Add('    Text = ''''');
    Lines.Add('    Left = 20'); Lines.Add('    Top = 610'); Lines.Add('  end');
  end;
  if not (IsLookup or ((FKind = 'combobox') and
    (SameText(Option('cbDropDownType'), 'SqlText') or
     SameText(Option('cbDropDownType'), 'SqlQuery')))) then Exit;
  Lines.Add('  object lookupQuery' + FName + ': TUgClientDataSet');
  Lines.Add('    Left = ' + IntToStr(20 + (Index mod 10) * 80));
  Lines.Add('    Top = ' + IntToStr(550 + (Index div 10) * 60));
  Lines.Add('    Active = False'); Lines.Add('    PageRowCount = -1');
  if IsLookup then Lines.Add('    SelectMaxRecCount = ' + Option('seMaxRecordCount'));
  if not IsGrid and SameText(Option('cbGridPageSetting'), 'Open') then
    Lines.Add('    Tag = ' + Option('sePageSize'));
  if Dynamic then Lines.Add('    CommandText = ' + Quoted('select ug_query.* from (' + FSQL + ') ug_query where 1=2'))
  else Lines.Add('    CommandText = ' + Quoted(FSQL));
  Lines.Add('  end');
end;

end.
