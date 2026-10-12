unit ugConfiguration.ReportPlan;

interface

uses System.SysUtils, System.Classes, System.JSON;

type
  TReportPlan = class
  private
    FNames, FCaptions, FExpressions, FGroups: TStringList;
    FDrillColumns, FGroupOutputs, FRawFields, FRawCaptions: TStringList;
    FHeaders, FRawHeaders, FHidden, FRawHidden: TStringList;
    FSortMode: string;
    FMove, FResize, FHide, FRowNumbers: Boolean;
    FFiltering: Boolean;
    FTypes, FRawTypes: TStringList;
  public
    property Filtering: Boolean read FFiltering;
    constructor Create(Config: TJSONObject; Fields, Sources: TStrings);
    destructor Destroy; override;
    procedure AddQuery(Code: TStrings);
    procedure ApplyColumns(Fields, Captions: TStrings);
    function HasDrilldown: Boolean;
    procedure AddDrillCode(Code: TStrings);
    procedure AddDrillEvents(Lines: TStrings);
    procedure AddDrillUI(Lines: TStrings);
    function HeaderFor(const Field: string): string;
    function Hidden(const Field: string): Boolean;
    procedure FilterSQL(Code:TStrings; Detail:Boolean);
    procedure BindFilters(Code:TStrings; Detail:Boolean);
    procedure FilterEditors(Lines:TStrings);
    function FilterEditor(const Field:string; Detail:Boolean):string;
  end;

implementation

uses System.Generics.Collections, System.Generics.Defaults,
  ugConfiguration.MultiplePresentation;

function Obj(J: TJSONObject; const Name: string): TJSONObject;
var V: TJSONValue;
begin
  Result := nil;
  if J=nil then Exit;
  V:=J.GetValue(Name);
  if V is TJSONObject then Result:=TJSONObject(V);
end;

function Str(J: TJSONObject; const Name: string): string;
var V: TJSONValue;
begin
  Result:='';
  if J=nil then Exit;
  V:=J.GetValue(Name);
  if (V<>nil) and not (V is TJSONNull) then Result:=V.Value;
end;

function Enabled(const V: string): Boolean;
begin Result:=SameText(V,'True') or (V='1') or (V='-1'); end;

constructor TReportPlan.Create(Config: TJSONObject; Fields, Sources: TStrings);
var Data, R, Settings, Cols, C: TJSONObject; Rows: TList<TJSONObject>;
  I, J, K, N, SortNo: Integer; Expr, AliasName, Kind, Fn, Arg, SQL, FieldType: string;
  Orders: TList<Integer>;
begin
  inherited Create;
  FNames:=TStringList.Create; FCaptions:=TStringList.Create;
  FExpressions:=TStringList.Create; FGroups:=TStringList.Create;
  FDrillColumns:=TStringList.Create; FGroupOutputs:=TStringList.Create;
  FRawFields:=TStringList.Create; FRawCaptions:=TStringList.Create;
  FHeaders:=TStringList.Create; FHidden:=TStringList.Create; FRawHidden:=TStringList.Create;
  FRawHeaders:=TStringList.Create;
  FTypes:=TStringList.Create; FRawTypes:=TStringList.Create;
  FRawFields.Assign(Fields);
  Settings:=Obj(Config,'TWebNormalSetting');
  FFiltering:=Enabled(Str(Settings,'表格过滤'));
  FSortMode:=Str(Settings,'字段排序');
  FMove:=Enabled(Str(Settings,'字段移动')); FResize:=Enabled(Str(Settings,'字段宽度'));
  FHide:=Enabled(Str(Settings,'字段显隐'));
  FRowNumbers:=Enabled(Str(Settings,'表格序号'));
  for Expr in Str(Settings,'隐藏字段-主表').Split([';']) do begin
    J:=Sources.IndexOf(Trim(Expr));
    if J>=0 then FRawHidden.Add(Fields[J]);
  end;
  Data:=Obj(Obj(Obj(Config,'TWebDataPerspective'),'cdsDataPerspective'),'Data');
  if (Data=nil) or (Data.Count=0) then
    raise Exception.Create('请在数据透视页配置分组字段或统计字段。');
  Cols:=Obj(Obj(Obj(Config,'TWebDataStructure'),'cdsColumns'),'Data');
  Rows:=TList<TJSONObject>.Create; Orders:=TList<Integer>.Create;
  try
    for I:=0 to Data.Count-1 do begin
      R:=Obj(Data,IntToStr(I));
      if R=nil then raise Exception.Create('数据透视缺少数字行键。');
      if not TryStrToInt(Str(R,'fdSort'),SortNo) or (SortNo<1) or Orders.Contains(SortNo) then
        raise Exception.Create('数据透视序号必须是互不重复的正整数。');
      Orders.Add(SortNo); Rows.Add(R);
    end;
    Rows.Sort(TComparer<TJSONObject>.Construct(
      function(const A,B:TJSONObject):Integer
      begin
        if StrToInt(Str(A,'fdSort'))<StrToInt(Str(B,'fdSort')) then Result:=-1
        else if StrToInt(Str(A,'fdSort'))>StrToInt(Str(B,'fdSort')) then Result:=1
        else Result:=0;
      end));
    for R in Rows do begin
      FHeaders.Add(Str(R,'fdGroup'));
      AliasName:=Trim(Str(R,'fdCOLUMN_AS'));
      J:=Sources.IndexOf(AliasName);
      if J>=0 then AliasName:=StringReplace(AliasName,'.','',[])
      else if not IsValidIdent(AliasName) then
        raise Exception.Create('非法统计字段别名：'+AliasName);
      if FNames.IndexOf(AliasName)>=0 then raise Exception.Create('统计输出字段别名重复：'+AliasName);
      Expr:=Trim(Str(R,'fdCOLUMN_NAME')); Kind:=Str(R,'fdType');
      FieldType:='VARCHAR';
      for K:=0 to Cols.Count-1 do begin
        C:=Obj(Cols,IntToStr(K));
        if SameText(Str(C,'fdCOLUMN_NAME'),Expr) then FieldType:=UpperCase(Str(C,'fdCOLUMN_TYPENAME'));
      end;
      J:=Sources.IndexOf(Expr);
      if Kind='0' then begin
        if J<0 then raise Exception.Create('分组字段必须是已选择的数据结构字段：'+Expr);
        SQL:='rpt.'+Fields[J];
        if FRawHidden.IndexOf(Fields[J])>=0 then FHidden.Add(AliasName);
        if FGroups.IndexOf(SQL)<0 then begin FGroups.Add(SQL); FGroupOutputs.Add(AliasName); end;
      end else if Kind='1' then begin
        N:=Pos('(',Expr);
        if (N<2) or (Copy(Expr,Length(Expr),1)<>')') then
          raise Exception.Create('统计表达式请使用 SUM/COUNT/AVG/MIN/MAX(字段)。');
        Fn:=UpperCase(Trim(Copy(Expr,1,N-1)));
        FieldType:='DECIMAL';
        if Fn='COUNT' then FieldType:='BIGINT';
        Arg:=Trim(Copy(Expr,N+1,Length(Expr)-N-1));
        if (Fn<>'SUM') and (Fn<>'COUNT') and (Fn<>'AVG') and (Fn<>'MIN') and (Fn<>'MAX') then
          raise Exception.Create('不支持的统计函数：'+Fn);
        J:=Sources.IndexOf(Arg);
        if (Fn='COUNT') and ((Arg='1') or (Arg='*')) then SQL:=Fn+'('+Arg+')'
        else begin
          if J<0 then raise Exception.Create('统计字段必须是已选择的数据结构字段：'+Arg);
          if (Fn='MIN') or (Fn='MAX') then
            for K:=0 to Cols.Count-1 do begin
              C:=Obj(Cols,IntToStr(K));
              if SameText(Str(C,'fdCOLUMN_NAME'),Arg) then FieldType:=UpperCase(Str(C,'fdCOLUMN_TYPENAME'));
            end;
          if (Fn='SUM') or (Fn='AVG') then begin
            FieldType:='';
            for K:=0 to Cols.Count-1 do begin
              C:=Obj(Cols,IntToStr(K));
              if SameText(Str(C,'fdCOLUMN_NAME'),Arg) then FieldType:=UpperCase(Str(C,'fdCOLUMN_TYPENAME'));
            end;
            if (Pos('INT',FieldType)=0) and (Pos('DECIMAL',FieldType)=0) and
              (Pos('NUMERIC',FieldType)=0) and (Pos('NUMBER',FieldType)=0) and
              (Pos('FLOAT',FieldType)=0) and (Pos('DOUBLE',FieldType)=0) and
              (Pos('REAL',FieldType)=0) and (Pos('MONEY',FieldType)=0) and
              (Pos('BCD',FieldType)=0) and (Pos('CURRENCY',FieldType)=0) then
              raise Exception.Create('SUM/AVG 需要数值字段：'+Arg);
          end;
          if Fn='AVG' then FieldType:='DECIMAL';
          SQL:=Fn+'(rpt.'+Fields[J]+')';
        end;
      end else raise Exception.Create('未知数据透视类型：'+Kind);
      FNames.Add(AliasName); FExpressions.Add(SQL);
      FTypes.Add(FieldType);
      if Enabled(Str(R,'fdDBlClickGoToDtails')) then begin
        if Kind<>'1' then raise Exception.Create('仅统计列可配置双击查看明细。');
        FDrillColumns.Add(AliasName);
      end;
      Expr:=Str(R,'fdCaption'); if Expr='' then Expr:=AliasName;
      FCaptions.Add(Expr);
    end;
    for I:=0 to Sources.Count-1 do begin
      Expr:=Sources[I];
      FRawHeaders.Add('');
      FieldType:='VARCHAR';
      for K:=0 to Cols.Count-1 do begin
        C:=Obj(Cols,IntToStr(K));
        if SameText(Str(C,'fdCOLUMN_NAME'),Sources[I]) then begin
          Expr:=Str(C,'fdCAPTION'); FieldType:=UpperCase(Str(C,'fdCOLUMN_TYPENAME'));
          FRawHeaders[I]:=Str(C,'fdGROUP'); Break;
        end;
      end;
      if Expr='' then Expr:=FRawFields[I];
      FRawCaptions.Add(Expr);
      FRawTypes.Add(FieldType);
    end;
  finally Orders.Free; Rows.Free; end;
end;

destructor TReportPlan.Destroy;
begin
  FHeaders.Free; FHidden.Free; FRawHidden.Free;
  FRawHeaders.Free;
  FTypes.Free; FRawTypes.Free;
  FRawCaptions.Free; FRawFields.Free; FGroupOutputs.Free; FDrillColumns.Free;
  FGroups.Free; FExpressions.Free; FCaptions.Free; FNames.Free;
  inherited Destroy;
end;

procedure TReportPlan.AddQuery(Code: TStrings);
var I:Integer; Prefix,Suffix:string;
begin
  if HasDrilldown then Code.Add('  ReportPendingSQL := SQL;');
  Code.Add('  //先按查询条件与权限筛选原始记录，再分组统计；所有输入继续使用参数');
  Prefix:='select ';
  for I:=0 to FNames.Count-1 do begin
    if I>0 then Prefix:=Prefix+', ';
    Prefix:=Prefix+FExpressions[I]+' as '+FNames[I];
  end;
  Prefix:=Prefix+' from (';
  Code.Add('  SQL :=');
  I:=1;
  while I<=Length(Prefix) do begin
    Code.Add('    '+QuotedStr(Copy(Prefix,I,140))+' +'); Inc(I,140);
  end;
  Code.Add('    SQL + '') rpt'';');
  if FGroups.Count>0 then begin
    Suffix:=' group by ';
    for I:=0 to FGroups.Count-1 do begin
      if I>0 then Suffix:=Suffix+', '; Suffix:=Suffix+FGroups[I];
    end;
    Code.Add('  SQL := SQL + '+QuotedStr(Suffix)+';');
  end;
  //稳定分页：分组列组合唯一，无分组的总计只有一行。
  FilterSQL(Code,False);
  if FGroups.Count>0 then begin
    Suffix:=' order by ';
    for I:=0 to FGroups.Count-1 do begin
      if I>0 then Suffix:=Suffix+', '; Suffix:=Suffix+FGroupOutputs[I];
    end;
    Code.Add('  SQL := SQL + '+QuotedStr(Suffix)+';');
  end;
end;

procedure TReportPlan.ApplyColumns(Fields, Captions: TStrings);
begin Fields.Assign(FNames); Captions.Assign(FCaptions); end;

function TReportPlan.HasDrilldown: Boolean;
begin Result:=FDrillColumns.Count>0; end;

function TReportPlan.HeaderFor(const Field: string): string;
var I:Integer;
begin I:=FNames.IndexOf(Field); Result:=''; if I>=0 then Result:=FHeaders[I]; end;

function TReportPlan.Hidden(const Field: string): Boolean;
begin Result:=FHidden.IndexOf(Field)>=0; end;

{$I ugConfiguration.ReportDrilldown.inc}
{$I ugConfiguration.ReportFilters.inc}

end.
