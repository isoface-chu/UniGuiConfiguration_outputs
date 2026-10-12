unit ugConfiguration.MasterSlaveTemplate;

interface
uses System.SysUtils, System.Classes, System.JSON, System.Generics.Collections;
function TryBuildMasterSlaveTemplate(Config: TJSONObject; out DFM, Reason: string;
  const NodeCatalog: string = ''; const NodeSchema: string = ''): Boolean;

implementation

{ 记录区布局的解析/校验与 mtListEditor 共用一份（宿主 2026-09-22 要求 mtMasterSlave 也有该功能）：
  共用同一个单元才不会两边各写一套、拒绝文案不一致。 }
uses ugConfiguration.ListEditorLayout;

type
  TDetailJoinSpec = record
    TableName, AliasName, ParentAlias: string;
    KeyCount: Integer;
    BaseKeys, OtherKeys: array[0..2] of string;
  end;

function O(J:TJSONObject;const K:string):TJSONObject;
var V:TJSONValue;
begin Result:=nil;if J=nil then Exit;V:=J.GetValue(K);if V is TJSONObject then Result:=TJSONObject(V);end;
function S(J:TJSONObject;const K:string):string;
var V:TJSONValue;
begin Result:='';if J=nil then Exit;V:=J.GetValue(K);if Assigned(V) and not(V is TJSONNull) then Result:=V.Value;end;
function Yes(const V:string):Boolean;
begin Result:=SameText(V,'True')or(V='1')or(V='-1');end;
function Ident(const V:string):Boolean;
var I:Integer;
begin
  Result:=(V<>'')and CharInSet(V[1],['A'..'Z','a'..'z','_']);
  for I:=2 to Length(V) do Result:=Result and CharInSet(V[I],['A'..'Z','a'..'z','0'..'9','_']);
end;
function ImportFrameItemStr(AItem:TJSONObject;const AKey:string):string;
var V:TJSONValue;
begin
  Result:='';
  if not Assigned(AItem)then Exit;
  V:=AItem.GetValue(AKey);
  if Assigned(V)and not(V is TJSONNull)then Result:=V.Value;
end;

function Q(const V:string):string;
var C:Char;
begin
  Result:='''';
  for C in V do
    if(Ord(C)<32)or(Ord(C)>126)then Result:=Result+'''#'+IntToStr(Ord(C))+''''
    else if C='''' then Result:=Result+'''''' else Result:=Result+C;
  Result:=Result+'''';
end;
function FieldPart(const V,AliasName:string):string;
begin
  Result:='';
  if SameText(Copy(V,1,Length(AliasName)+1),AliasName+'.') then
    Result:=Copy(V,Length(AliasName)+2,MaxInt);
end;
function IsGridType(const V:string):Boolean;
begin Result:=SameText(V,'gridcombobox')or SameText(V,'gridcomboboxextra');end;
function IsLookupType(const V:string):Boolean;
begin Result:=SameText(V,'lookupedit')or SameText(V,'lookupeditextra')or IsGridType(V);end;
function DynamicLookup(Drop:TJSONObject):Boolean;
var V:string;
begin V:=S(Drop,'cbDynamicLoading');Result:=(V='-1')or(V='1')or SameText(V,'True');end;
function LookupSQL(Drop:TJSONObject):string;
begin
  Result:=Trim(StringReplace(S(Drop,'mmText'),'\r\n',' ',[rfReplaceAll]));
  Result:=StringReplace(Result,#13,' ',[rfReplaceAll]);Result:=StringReplace(Result,#10,' ',[rfReplaceAll]);
  if(Result<>'')and(Result[Length(Result)]=';')then Delete(Result,Length(Result),1);
end;
function LookupSearchField(Drop:TJSONObject;const FieldName:string):Boolean;
var L:TStringList;V:string;P:Integer;
begin
  Result:=False;L:=TStringList.Create;try L.StrictDelimiter:=True;L.Delimiter:=';';L.DelimitedText:=S(Drop,'edOptionLookupFields');
    for V in L do begin P:=Pos('@',V);if P=0 then P:=Length(V)+1;if SameText(Trim(Copy(V,1,P-1)),FieldName)then Exit(True);end;
  finally L.Free;end;
end;

function TryBuildMasterSlaveTemplate(Config:TJSONObject;out DFM,Reason:string;
  const NodeCatalog,NodeSchema:string):Boolean;
{ 明细行按钮（目录项 'Detail Row Group'）也在这里放行：它们由明细区工具条消费，不参与主工具条
  （宿主 2026-09-21 要求 mtMasterSlave 的明细区与 mtListEditor 一样有这 7 个按钮）。 }
const AllowedButtons=';btQuery;btFirst;btPrior;btNext;btLast;btAppend;btDelete;btEditor;btImport;btSave;btCancel;' +
  'btAudit;btUnAudit;btRepulse;btPrint;btAnnex;btClose;' +
  'btDetailAppend;btDetailInsert;btDetailDelete;btDetailCopy;btDetailMoveUp;btDetailMoveDown;btDetailClear;';
var MT,DT,MC,DC,Settings,Row:TJSONObject;
  MainFields,MainCaptions,MainTypes,MainOptions,DetailFields,DetailCaptions,DetailTypes,DetailOptions,Buttons,Code,Lines,RequiredMain,RequiredDetail,UniqueMain,UniqueDetail,HiddenMain,HiddenDetail,
  CheckDetailFields,CheckDetailCaptions,CheckTables,CheckSourceFields,JoinFields,JoinCaptions,MainDisplayOrder,DetailDisplayOrder:TStringList;
  ImportFrameCaptions,ImportFrameNames,ImportFrameMulti:TStringList;
  AutoJSON,MainUniqueJSON,DetailUniqueJSON,ApprovalJSON,CheckJSON:TJSONValue;
  Joins: array of TDetailJoinSpec;
  OrderedTables:TList<TJSONObject>;
  ParentRow,Candidate:TJSONObject;
  HasChain,AddedTable:Boolean;
  RootKeys:TStringList;
  JoinFieldAliases: TStringList;
  JoinIndex, ConditionIndex: Integer;
  JoinFilter, JoinColumns, JoinTrigger, JoinReady, JoinParam: string;
  MainTable,DetailTable,MAlias,DAlias,MainKey,DetailKey,OrderField,DeptField,QueryFrame,V,K,SQLMain,SQLDetail,
  DetailLine,CreateDept,CreateUser,CreateTime,EditDept,EditUser,EditTime,EditCount,
  DocumentDate,JoinTable,JoinAlias,JoinBaseKey,JoinOtherKey,JoinClause,
  AutoField,AutoType,AutoPrefix,AutoDigits,AutoSuffix,UniqueRecordField,
  UniqueMainLabel,UniqueDetailLabel,StatusField,CorrespondingField,CheckType,
  AuditDept,AuditUser,AuditTime,RepulseDept,RepulseUser,RepulseTime,RepulseRemark,
  ImportRequired,ImportCaptions,GridOptions,ObjectType,OptionText,LookupDataName:string;
  { 明细行按钮名（绑定时循环用）。 }
  DetailRowBtn:string;
  I,J,X,Y,MainHeight,FieldHeight:Integer; Pair:TJSONPair;WriteMode,ApprovalMode,GridPersonalization:Boolean;DropValue:TJSONValue;Drop:TJSONObject;
  { 记录区布局（mtListEditor 同款可选区块）：解析结果 + 排版游标 + 算好的每个控件坐标。
    未配置布局时 HasLayout=False，所有布局分支都不执行，记录区保持原版三分栏。 }
  LayoutItems:TArray<TListEditorLayoutItem>;
  LayOrder,LayTemp:TStringList;
  HasLayout,LayGroups:Boolean;
  LayColumns,LayFieldWidth,LayStep,LayRowTop,LayRowHeight,LayRowCol,LaySpan,LayWidth,LayIndex:Integer;
  LayPosition,LayReason,LayField,LayCaptionText:string;
  LayPosX,LayPosY,LayPosW,LayPosH:TArray<Integer>;
  ImportFramesJSON:TJSONValue;ImportFramesArray:TJSONArray;ImportFrameItem:TJSONObject;
  function RequiredMessage(const FieldName, AliasName: string;
    Fields, Captions: TStrings; Columns: TJSONObject): string;
  var N: Integer; Caption: string; Entry: TJSONObject;
  begin
    Caption := '';
    N := Fields.IndexOf(FieldName);
    if N >= 0 then Caption := Captions[N];
    if (Trim(Caption) = '') and Assigned(Columns) then
      for N := 0 to Columns.Count - 1 do begin
        Entry := O(Columns, IntToStr(N));
        if SameText(S(Entry, 'fdCOLUMN_NAME'), AliasName + '.' + FieldName) then begin
          Caption := S(Entry, 'fdCAPTION'); Break;
        end;
      end;
    if Trim(Caption) = '' then Caption := FieldName;
    // LocalizeNoticeText translates the caption and shared suffix separately.
    Result := QuotedStr(Caption) + ' + ' + QuotedStr(' 不能为空。');
  end;
  function DetailOutputName(const QualifiedName:string):string;
  var N:Integer; F:string;
  begin
    Result:=FieldPart(QualifiedName,DAlias);
    if Result<>'' then Exit;
    for N:=0 to High(Joins) do
    begin
      F:=FieldPart(QualifiedName,Joins[N].AliasName);
      if F<>'' then Exit(Joins[N].AliasName+F);
    end;
  end;
  procedure OrderDisplayFields(const Section: string; Available, Ordered: TStringList);
  var
    Rows, Entry: TJSONObject;
    N, Index: Integer;
    Name: string;
  begin
    Ordered.Clear;
    Rows := O(O(O(Config, Section), 'cdsTypesetting'), 'Data');
    if Rows <> nil then
      for N := 0 to Rows.Count - 1 do
      begin
        Entry := O(Rows, IntToStr(N));
        Name := S(Entry, 'fdCOLUMN_NAME');
        Index := Available.IndexOf(Name);
        // Old or partial configurations may contain stale/repeated rows.
        // They must never duplicate controls or discard selected fields.
        if (Index >= 0) and (Ordered.IndexOf(Available[Index]) < 0) then
          Ordered.Add(Available[Index]);
      end;
    for N := 0 to Available.Count - 1 do
      if Ordered.IndexOf(Available[N]) < 0 then Ordered.Add(Available[N]);
  end;
  procedure OrderDetailColumns;
  var
    Blocks, Names, Block: TStringList;
    StartPos, EndPos, N, K: Integer;
    FieldName: string;
  begin
    StartPos := Lines.IndexOf('  object gridDetailed: TUgDBGrid');
    while (StartPos < Lines.Count) and (Lines[StartPos] <> '    Columns = <') do Inc(StartPos);
    Inc(StartPos);
    EndPos := StartPos;
    Blocks := TStringList.Create;
    Names := TStringList.Create;
    Block := TStringList.Create;
    try
      while (EndPos < Lines.Count) and (Lines[EndPos] <> '    >') do
      begin
        Block.Clear;
        Block.Add(Lines[EndPos]); Inc(EndPos);
        while (EndPos < Lines.Count) and (Lines[EndPos] <> '      end') do
        begin
          if Pos('        FieldName = ', Lines[EndPos]) = 1 then
            Names.Add(Copy(Lines[EndPos], 22, Length(Lines[EndPos]) - 22));
          Block.Add(Lines[EndPos]); Inc(EndPos);
        end;
        Block.Add('      end'); Inc(EndPos);
        Blocks.Add(Block.Text);
      end;
      for N := EndPos - 1 downto StartPos do Lines.Delete(N);
      for N := DetailDisplayOrder.Count - 1 downto 0 do
      begin
        FieldName := DetailOutputName(DetailDisplayOrder[N]);
        K := Names.IndexOf(FieldName);
        if K < 0 then raise Exception.Create('Detail display column not found: ' + FieldName);
        Block.Text := Blocks[K];
        for K := Block.Count - 1 downto 0 do Lines.Insert(StartPos, Block[K]);
      end;
    finally
      Block.Free; Names.Free; Blocks.Free;
    end;
  end;
  function MainFieldHeight(const AType:string):Integer;
  begin
    if SameText(AType,'memo')then Result:=170 else Result:=50;
  end;
  { ===== 记录区布局（可选区块）辅助 =====
    布局行按**主字段名**（去掉别名）匹配，大小写不敏感；找不到返回 -1/空串/缺省值。
    下标一律先判 -1 再取值 —— 布局里可能有"当前数据结构里已不存在"的字段行，
    直接用 MainTypes[IndexOf(...)] 这种写法在 -1 时会读越界地址（生成器 AV 的根因）。 }
  function LayRowOf(const AField:string):Integer;
  var N:Integer; F:string;
  begin
    Result:=-1;
    if not HasLayout then Exit;
    for N:=0 to High(LayoutItems) do
    begin
      F:=FieldPart(LayoutItems[N].Field,MAlias);
      { 容忍手工写的、不带表别名的布局行。 }
      if F='' then F:=Trim(LayoutItems[N].Field);
      if SameText(F,AField) then Exit(N);
    end;
  end;
  function LayCaptionOf(const AField:string):string;
  var N:Integer;
  begin
    Result:='';
    N:=LayRowOf(AField);
    if N>=0 then Result:=Trim(LayoutItems[N].Caption);
  end;
  function LaySpanOf(const AField:string):Integer;
  var N:Integer;
  begin
    Result:=1;
    N:=LayRowOf(AField);
    if N<0 then Exit;
    Result:=LayoutItems[N].Span;
    if Result<1 then Result:=1;
    if Result>LayColumns then Result:=LayColumns;
  end;
  function LayWidthOf(const AField:string):Integer;
  var N:Integer;
  begin
    Result:=0;
    N:=LayRowOf(AField);
    if N>=0 then Result:=LayoutItems[N].Width;
  end;
  function LayGroupOf(const AField:string):string;
  var N:Integer;
  begin
    Result:='';
    N:=LayRowOf(AField);
    if N>=0 then Result:=Trim(LayoutItems[N].Group);
  end;
  function Reject(const M:string):Boolean;begin Reason:=M;Result:=False;end;

  function ResolveTableName(var AName:string):Boolean;
  var Parts:TArray<string>; Part,Prefix:string;
  begin
    Result:=False;
    Parts:=AName.Split(['.']);
    if (Length(Parts)<1)or(Length(Parts)>3)then Exit;
    for Part in Parts do if not Ident(Part)then Exit;
    // Explicit qualified names remain authoritative; never duplicate prefixes.
    if Length(Parts)>1 then Exit(True);
    Prefix:='';
    if Yes(S(Config,'TWebDataNodeNamecbAddCatalogName'))then
      Prefix:=Trim(NodeCatalog)+'.';
    if Yes(S(Config,'TWebDataNodeNamecbAddSchemaName'))then
      Prefix:=Prefix+Trim(NodeSchema)+'.';
    AName:=Prefix+AName;
    Result:=True;
  end;
  procedure GroupMainControls;
  var
    Groups, FieldGroups, Blocks, Block, Output: TStringList;
    N, G, K, StartPos, P, Index, HeightAt, Count, RowHeight, RowTop, GroupTop, H,
    GrpCols, GrpStep, GrpCol, GrpSpan, GrpPanelW: Integer;
    Name, GroupName, LastGroup: string;
    GrpHidden: Boolean;
    R: TJSONObject;
  begin
    Groups:=TStringList.Create; FieldGroups:=TStringList.Create;
    Blocks:=TStringList.Create; Block:=TStringList.Create; Output:=TStringList.Create;
    try
      { 未配布局时列数/步进保持原样（4 列、210 步进，逐字节不变）；配了布局就按布局的
        列数与每列宽度排版。分组来源：配了布局用布局的 fdGROUP，否则仍按数据结构「列」。 }
      if HasLayout then begin GrpCols:=LayColumns; GrpStep:=LayFieldWidth+20;
        GrpPanelW:=LayColumns*LayFieldWidth+(LayColumns-1)*20+20; end
      else begin GrpCols:=4; GrpStep:=210; GrpPanelW:=860; end;
      Groups.Add('');
      LastGroup:='';
      for N:=0 to MainDisplayOrder.Count-1 do
      begin
        Name:=FieldPart(MainDisplayOrder[N],MAlias);
        if HasLayout then
        begin
          if LayGroups then GroupName:=LayGroupOf(Name) else GroupName:='';
          { 布局里没显示的字段照常生成控件，但得有所属分组框：挂到最后一个可见分组，
            免得为它多出一个只有隐藏控件的空分组（看起来是个空条）。 }
          if (GroupName='')and LayGroups and (LayRowOf(Name)<0) then GroupName:=LastGroup;
        end
        else
        begin
          GroupName:='';
          for K:=0 to MC.Count-1 do
          begin
            R:=O(MC,IntToStr(K));
            if SameText(S(R,'fdCOLUMN_NAME'),MainDisplayOrder[N]) then
            begin GroupName:=Trim(S(R,'fdGROUP')); Break; end;
          end;
        end;
        FieldGroups.Add(GroupName);
        if GroupName<>'' then LastGroup:=GroupName;
        if Groups.IndexOf(GroupName)<0 then Groups.Add(GroupName);
      end;
      if Groups.Count=1 then Exit; // Byte-for-byte legacy layout when ungrouped.
      StartPos:=Lines.IndexOf('  object pMain: TUgContainerPanel');
      P:=StartPos+1;
      while P<Lines.Count do
      begin
        if Copy(Lines[P],1,11)='    object ' then
        begin
          Block.Clear;
          repeat Block.Add(Lines[P]); Inc(P); until Lines[P]='    end';
          Block.Add(Lines[P]);
          { 记录区里除了字段控件，还有原版就有的 1px 分隔线（lbEditControls）——分组重排要跳过它，
            否则"控件数 = 字段数"的校验会失败（补回分隔线后暴露；宿主 2026-09-21）。 }
          if Pos('    object lbEditControls:', Block[0])<>1 then Blocks.Add(Block.Text);
        end;
        if Lines[P]='  end' then Break;
        Inc(P);
      end;
      if Blocks.Count<>MainDisplayOrder.Count then raise Exception.Create('Main group control count mismatch');
      for N:=P downto StartPos do Lines.Delete(N);
      Output.Add('  object pMain: TUgScrollBox');
      if HasLayout and SameText(LayPosition,'Left') then
      begin
        Output.Add('    Align = alLeft');
        Output.Add('    Width = '+IntToStr(GrpPanelW));
        Output.Add('    Height = 300');
      end
      else
      begin
        Output.Add('    Align = alTop');Output.Add('    Height = 300');
      end;
      { 高度行的下标随上面的分支变化（Top：Align/Height；Left：Align/Width/Height），
        下面按内容高度收窄时用这个下标，不再写死。 }
      HeightAt:=Output.Count-1;
      GroupTop:=0;
      for G:=0 to Groups.Count-1 do
      begin
        if FieldGroups.IndexOf(Groups[G])<0 then Continue;
        Output.Add('    object pMainGroup'+IntToStr(G)+': TUgContainerPanel');
        Output.Add('      Left = 0');Output.Add('      Top = '+IntToStr(GroupTop));
        Output.Add('      Width = '+IntToStr(GrpPanelW));
        Index:=Output.Count; Output.Add('      Height = 0');
        RowTop:=10;RowHeight:=0;Count:=0;GrpCol:=0;
        if Groups[G]<>'' then
        begin
          Output.Add('      object capMainGroup'+IntToStr(G)+': TUgLabel');
          Output.Add('        Left = 10');Output.Add('        Top = 4');
          Output.Add('        Caption = '+Q(Groups[G]));
          Output.Add('        Font.Style = [fsBold]');Output.Add('      end');
          RowTop:=32;
        end;
        for N:=0 to MainDisplayOrder.Count-1 do
          if SameText(FieldGroups[N],Groups[G]) then
          begin
            Name:=FieldPart(MainDisplayOrder[N],MAlias);
            K:=MainFields.IndexOf(Name);
            { 下标 -1 必须先挡：MainTypes[-1] 会读到越界地址（上次生成器 AV 的根因之一）。 }
            if K<0 then Continue;
            GrpSpan:=1;GrpHidden:=False;
            if HasLayout then
            begin
              GrpHidden:=LayRowOf(MainFields[K])<0;
              GrpSpan:=LaySpanOf(MainFields[K]);
            end;
            if HasLayout then
            begin
              if (not GrpHidden)and(GrpCol>0)and(GrpCol+GrpSpan>GrpCols) then
              begin Inc(RowTop,RowHeight+10);RowHeight:=0;GrpCol:=0;end;
            end
            else if (Count>0)and(Count mod 4=0)then
            begin Inc(RowTop,RowHeight+10);RowHeight:=0;GrpCol:=0;end;
            H:=MainFieldHeight(MainTypes[K]);
            { 隐藏字段不占格子、也不参与行高（它本来就看不见），否则分组框会为它白白变高。 }
            if (not GrpHidden)and(H>RowHeight) then RowHeight:=H;
            Block.Text:=Blocks[N];
            for K:=0 to Block.Count-1 do
              if Copy(Block[K],1,13)='      Left = ' then Block[K]:='      Left = '+IntToStr(10+GrpCol*GrpStep)
              else if Copy(Block[K],1,12)='      Top = ' then Block[K]:='      Top = '+IntToStr(RowTop);
            for K:=0 to Block.Count-1 do Output.Add('  '+Block[K]);
            if not GrpHidden then Inc(GrpCol,GrpSpan);
            Inc(Count);
          end;
        H:=RowTop+RowHeight+10;
        Output[Index]:='      Height = '+IntToStr(H);
        Output.Add('    end');Inc(GroupTop,H+8);
      end;
      if GroupTop<300 then Output[HeightAt]:='    Height = '+IntToStr(GroupTop);
      { 重建 pMain 时把原版那条 1px 分隔线补回。注意：分组后 pMain 是 **TUgScrollBox**，
        `Align = alBottom` 贴的是**视口**底部（内容比视口高时会跑到中间，宿主 2026-09-21 截图反馈
        "记录区分隔线并没有在记录区最底下"），所以这里按**内容高度**绝对定位，让线紧贴最后一个分组下面。
        记录区在左边（布局 Left）时这条线是竖线，与未分组路径一致。 }
      Output.Add('    object lbEditControls: TUgContainerPanel');
      if HasLayout and SameText(LayPosition,'Left') then
      begin
        Output.Add('      Align = alRight');
        Output.Add('      Width = 1');
      end
      else
      begin
        Output.Add('      Left = 0');
        Output.Add('      Top = '+IntToStr(GroupTop));
        Output.Add('      Width = 860');
        Output.Add('      Height = 1');
      end;
      Output.Add('      Hint = '+QuotedStr(''));
      Output.Add('      ParentColor = False');
      Output.Add('      Color = 13093060');
      Output.Add('    end');
      Output.Add('  end');
      for N:=Output.Count-1 downto 0 do Lines.Insert(StartPos,Output[N]);
    finally Output.Free;Block.Free;Blocks.Free;FieldGroups.Free;Groups.Free;end;
  end;
  function HasColumn(C:TJSONObject;const AliasName,FieldName:string):Boolean;
  var N:Integer;R:TJSONObject;
  begin Result:=False;for N:=0 to C.Count-1 do begin R:=O(C,IntToStr(N));if SameText(FieldPart(S(R,'fdCOLUMN_NAME'),AliasName),FieldName)then Exit(True);end;end;
  function DetailGroup(const AField:string):string;
  var N:Integer;R:TJSONObject;
  begin
    Result:='';
    for N:=0 to DC.Count-1 do begin R:=O(DC,IntToStr(N));
      if SameText(S(R,'fdCOLUMN_NAME'),AField)then Exit(S(R,'fdGROUP'));
    end;
  end;
  procedure AddButton(const N,C:string;L:Integer);
  var IconIndex: Integer;
  begin
    if SameText(N,'btAppend')or SameText(N,'btImport')or SameText(N,'btPrint')then Lines.Add('    object '+N+': TUgMenuButton')else Lines.Add('    object '+N+': TUgButton');
    Lines.Add('      AlignWithMargins = True');
    Lines.Add('      Align = alLeft');
    Lines.Add('      Left = '+IntToStr(L));Lines.Add('      Top = 3');
    if SameText(N,'btAppend')or SameText(N,'btImport')or SameText(N,'btPrint')then Lines.Add('      Width = 75')else Lines.Add('      Width = 60');
    Lines.Add('      Height = 26');Lines.Add('      AutoWidth = True');
    IconIndex:=0;
    if SameText(N,'btFirst')then IconIndex:=3
    else if SameText(N,'btPrior')then IconIndex:=4
    else if SameText(N,'btNext')then IconIndex:=5
    else if SameText(N,'btLast')then IconIndex:=6
    else if SameText(N,'btAppend')then IconIndex:=7
    else if SameText(N,'btDelete')then IconIndex:=8
    else if SameText(N,'btEditor')then IconIndex:=9
    else if SameText(N,'btImport')then IconIndex:=10
    else if SameText(N,'btSave')then IconIndex:=11
    else if SameText(N,'btCancel')then IconIndex:=12
    else if SameText(N,'btAudit')then IconIndex:=13
    else if SameText(N,'btUnAudit')then IconIndex:=14
    else if SameText(N,'btRepulse')then IconIndex:=15
    else if SameText(N,'btPrint')then IconIndex:=17
    else if SameText(N,'btAnnex')then IconIndex:=18
    else if SameText(N,'btClose')then IconIndex:=23;
    Lines.Add('      Images = Imgs');
    Lines.Add('      ImageIndex = '+IntToStr(IconIndex));
    Lines.Add('      Caption = '+Q(C));Lines.Add('    end');
  end;
  procedure AddSeparator(const N:string;var L:Integer);
  begin
    Lines.Add('    object '+N+': TUgContainerPanel');
    Lines.Add('      AlignWithMargins = True');
    Lines.Add('      Align = alLeft');
    Lines.Add('      Left = '+IntToStr(L));
    Lines.Add('      Top = 5');
    Lines.Add('      Width = 1');
    Lines.Add('      Height = 22');
    Lines.Add('      Margins.Top = 5');
    Lines.Add('      Margins.Bottom = 5');
    Lines.Add('      ParentColor = False');
    Lines.Add('      Color = 13093060');
    Lines.Add('    end');
    Inc(L,7);
  end;
  procedure AddCode(const V:string);
  var
    Parts: TStringList;
    I, StartPos, BaseCount: Integer;
    InString: Boolean;
    Part, BaseIndent, Trimmed: string;
    procedure EmitPart(const APart, AIndent: string);
    var
      T, L, Tail, TailLower: string;
      P, ElsePos: Integer;
    begin
      T := Trim(APart);
      if T = '' then
        Exit;
      L := LowerCase(T);

      if Copy(L, 1, 6) = 'begin ' then
      begin
        Code.Add(AIndent + 'begin');
        EmitPart(Copy(T, 7, MaxInt), AIndent + '  ');
        Exit;
      end;
      if Copy(L, 1, 4) = 'try ' then
      begin
        Code.Add(AIndent + 'try');
        EmitPart(Copy(T, 5, MaxInt), AIndent + '  ');
        Exit;
      end;
      if Copy(L, 1, 8) = 'finally ' then
      begin
        Code.Add(AIndent + 'finally');
        EmitPart(Copy(T, 9, MaxInt), AIndent + '  ');
        Exit;
      end;
      if Copy(L, 1, 7) = 'except ' then
      begin
        Code.Add(AIndent + 'except');
        EmitPart(Copy(T, 8, MaxInt), AIndent + '  ');
        Exit;
      end;
      if Copy(L, 1, 15) = 'end else begin ' then
      begin
        Code.Add(AIndent + 'end else');
        Code.Add(AIndent + 'begin');
        EmitPart(Copy(T, 16, MaxInt), AIndent + '  ');
        Exit;
      end;
      if Copy(L, 1, 9) = 'end else ' then
      begin
        Code.Add(AIndent + 'end else');
        EmitPart(Copy(T, 10, MaxInt), AIndent + '  ');
        Exit;
      end;

      P := Pos('do begin', L);
      if P > 0 then
      begin
        Code.Add(AIndent + Copy(T, 1, P + Length('do') - 1));
        Code.Add(AIndent + 'begin');
        EmitPart(Copy(T, P + Length('do begin'), MaxInt), AIndent + '  ');
        Exit;
      end;
      P := Pos('then begin', L);
      if P > 0 then
      begin
        Code.Add(AIndent + Copy(T, 1, P + Length('then') - 1));
        Code.Add(AIndent + 'begin');
        EmitPart(Copy(T, P + Length('then begin'), MaxInt), AIndent + '  ');
        Exit;
      end;
      P := Pos('else begin', L);
      if P > 0 then
      begin
        EmitPart(Copy(T, 1, P + Length('else') - 1), AIndent);
        Code.Add(AIndent + 'begin');
        EmitPart(Copy(T, P + Length('else begin'), MaxInt), AIndent + '  ');
        Exit;
      end;

      if Copy(L, 1, 2) = 'if' then
      begin
        P := Pos('then ', L);
        if P > 0 then
        begin
          Code.Add(AIndent + Copy(T, 1, P + Length('then') - 1));
          Tail := Trim(Copy(T, P + Length('then '), MaxInt));
          TailLower := LowerCase(Tail);
          ElsePos := Pos(' else ', TailLower);
          if ElsePos > 0 then
          begin
            EmitPart(Copy(Tail, 1, ElsePos - 1), AIndent + '  ');
            Code.Add(AIndent + 'else');
            EmitPart(Copy(Tail, ElsePos + Length(' else '), MaxInt), AIndent + '  ');
          end
          else if (Length(TailLower) >= 5) and
            (Copy(TailLower, Length(TailLower) - 4, 5) = ' else') then
          begin
            EmitPart(Copy(Tail, 1, Length(Tail) - 5), AIndent + '  ');
            Code.Add(AIndent + 'else');
          end
          else
            EmitPart(Tail, AIndent + '  ');
          Exit;
        end;
      end;

      Code.Add(AIndent + T);
    end;
  begin
    if V = '' then
    begin
      Code.Add('');
      Exit;
    end;

    Parts := TStringList.Create;
    try
      StartPos := 1;
      InString := False;
      I := 1;
      while I <= Length(V) do
      begin
        if V[I] = '''' then
        begin
          if InString and (I < Length(V)) and (V[I + 1] = '''') then
            Inc(I)
          else
            InString := not InString;
        end
        else if (V[I] = ';') and (not InString) then
        begin
          Parts.Add(Copy(V, StartPos, I - StartPos + 1));
          StartPos := I + 1;
        end;
        Inc(I);
      end;
      if StartPos <= Length(V) then
        Parts.Add(Copy(V, StartPos, MaxInt));

      if Parts.Count = 0 then
      begin
        Code.Add(V);
        Exit;
      end;

      BaseCount := 0;
      while (BaseCount < Length(V)) and (V[BaseCount + 1] = ' ') do
        Inc(BaseCount);
      BaseIndent := StringOfChar(' ', BaseCount);

      Trimmed := TrimLeft(Parts[0]);
      if SameText(Copy(Trimmed, 1, 4), 'var ') then
      begin
        Code.Add(BaseIndent + 'var');
        Part := Trim(Copy(Trimmed, 5, MaxInt));
        if Part <> '' then
          EmitPart(Part, BaseIndent + '  ');
        for I := 1 to Parts.Count - 1 do
        begin
          Part := Trim(Parts[I]);
          if Part <> '' then
            EmitPart(Part, BaseIndent + '  ');
        end;
      end
      else
        for I := 0 to Parts.Count - 1 do
        begin
          Part := Trim(Parts[I]);
          if Part <> '' then
          begin
            EmitPart(Part, BaseIndent);
          end;
        end;
    finally
      Parts.Free;
    end;
  end;

  { 明细行按钮名（目录项 'Detail Row Group'）—— 与 EmitDetailRowBar/EmitDetailRowOps 的常量表一致。 }
  function DetailRowButtonName(const AIndex: Integer): string;
  begin
    case AIndex of
      0: Result := 'btDetailAppend'; 1: Result := 'btDetailInsert';
      2: Result := 'btDetailDelete'; 3: Result := 'btDetailCopy';
      4: Result := 'btDetailMoveUp'; 5: Result := 'btDetailMoveDown';
      6: Result := 'btDetailClear';
    else Result := '';
    end;
  end;

  { 把宿主 2026-09-21 指定的图标追加进 Imgs（TUGIconClsList.IconText，换行分隔）：
    icon-pingmufangda（展开查询用，本模板没有该按钮，但保持两边列表一致）、
    icon-fuzhi（复制行）、icon-caidanshouqi（插入行）、icon-guanbi2fill（清空）。
    追加在末尾，既有索引不动；mtMasterSlave 与 mtDetail/mtMultiple 的基础列表本来就逐项一致（各 27 项），
    所以两个模板追加后的索引也一致。 }
  procedure EnsureDetailIcons;
  const
    CNew: array[0..3] of string = ('icon-pingmufangda', 'icon-fuzhi',
      'icon-caidanshouqi', 'icon-guanbi2fill');
  var
    I, J, Last: Integer; S: string;
  begin
    I := -1;
    for J := 0 to Lines.Count - 1 do
      if Trim(Lines[J]) = 'object Imgs: TUGIconClsList' then begin I := J; Break; end;
    if I < 0 then Exit;
    Last := -1; S := '';
    for J := I + 1 to Lines.Count - 1 do
    begin
      if Trim(Lines[J]) = 'end' then Break;
      if Pos('IconText = ', Trim(Lines[J])) = 1 then begin Last := J; S := S + Lines[J]; Continue; end;
      if Last >= 0 then begin Last := J; S := S + Lines[J]; end;
    end;
    if Last < 0 then Exit;
    for I := 0 to 3 do
      if Pos(CNew[I], S) = 0 then
        Lines[Last] := Lines[Last] + '''' + 'icon iconfont ' + CNew[I] + '''' + '#13#10';
  end;

  { 明细区行按钮（目录项 'Detail Row Group'）：宿主 2026-09-21 要求与 mtListEditor 一致。
    mtMasterSlave 的记录区是 alTop、明细网格 gridDetailed 是 alClient，所以工具条也做成 alTop，
    插在 gridDetailed 之前（Top 排在记录区之后、网格之上）。按钮只发**勾选的**。 }
  { 明细行操作（宿主 2026-09-21）：追加/插入/删除/复制/上移/下移/清空 + 7 个入口。
    沿用 mtMasterSlave 的模型：空白占位行当场落库、DetailRowHasData 判"空行"、
    RenumberDetails 排行号、父键（关联从表）当场补齐。只发勾选的按钮。 }
  procedure EmitDetailRowOps;
  const
    COrder: array[0..6] of string = ('btDetailAppend', 'btDetailInsert', 'btDetailDelete',
      'btDetailCopy', 'btDetailMoveUp', 'btDetailMoveDown', 'btDetailClear');
    CHandlers: array[0..6] of string = ('AppendDetailOneRow', 'InsertDetailOneRow',
      'DeleteDetailRow', 'CopyDetailRow', 'MoveDetailUpRow', 'MoveDetailDownRow', 'ClearDetailRows');
  var
    I, K: Integer;
    F, Caps, VarsC, VarsD: string;
  begin
    Caps := '';
    VarsC := '';
    VarsD := '';
    for I := 0 to DetailFields.Count - 1 do
    begin
      if SameText(DetailFields[I], DetailKey) or SameText(DetailFields[I], DetailLine) then Continue;
      if Caps <> '' then Caps := Caps + ', ';
      Caps := Caps + 'C' + IntToStr(I);
      if VarsC <> '' then VarsC := VarsC + ', ';
      VarsC := VarsC + 'C' + IntToStr(I);
      if VarsD <> '' then VarsD := VarsD + ', ';
      VarsD := VarsD + 'D' + IntToStr(I);
    end;

    AddCode('//明细行：追加一条空白占位行（项次连续、父键当场补齐）');
    AddCode('procedure AppendDetailOneRow;');
    AddCode('var NextLine: Integer;');
    AddCode('begin');
    AddCode('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Post;');
    if DetailLine <> '' then
    begin
      AddCode('  cdsDetailed.IndexFieldNames := '''';');
      AddCode('  NextLine := 1;');
      AddCode('  cdsDetailed.Last;');
      AddCode('  if not cdsDetailed.IsEmpty then');
      AddCode('    NextLine := cdsDetailed.FieldByName(' + QuotedStr(DetailLine) + ').AsInteger + 1;');
    end
    else AddCode('  NextLine := cdsDetailed.RecordCount + 1;');
    AddCode('  cdsDetailed.Append;');
    if DetailLine <> '' then
      AddCode('  cdsDetailed.FieldByName(' + QuotedStr(DetailLine) + ').AsInteger := NextLine;');
    AddCode('  cdsDetailed.FieldByName(' + QuotedStr(DetailKey) + ').AsVariant := cdsMain.FieldByName(' +
      QuotedStr(MainKey) + ').AsVariant;');
    AddCode('  cdsDetailed.Post;');
    AddCode('  gridDetailed.SetFocus;');
    AddCode('end;');
    AddCode('');
    AddCode('//明细行：在当前行之前插入一条空白占位行');
    AddCode('procedure InsertDetailOneRow;');
    AddCode('begin');
    AddCode('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Post;');
    AddCode('  if cdsDetailed.IsEmpty then');
    AddCode('  begin');
    AddCode('    AppendDetailOneRow;');
    AddCode('    Exit;');
    AddCode('  end;');
    AddCode('  cdsDetailed.Insert;');
    AddCode('  cdsDetailed.FieldByName(' + QuotedStr(DetailKey) + ').AsVariant := cdsMain.FieldByName(' +
      QuotedStr(MainKey) + ').AsVariant;');
    AddCode('  cdsDetailed.Post;');
    if DetailLine <> '' then AddCode('  RenumberDetails;');
    AddCode('  gridDetailed.SetFocus;');
    AddCode('end;');
    AddCode('');
    AddCode('//明细行：删除当前行');
    AddCode('procedure DeleteDetailRow;');
    AddCode('begin');
    AddCode('  if (not cdsDetailed.Active) or cdsDetailed.IsEmpty then Exit;');
    AddCode('  if not ConfirmAction(''是否删除当前明细行？'') then Exit;');
    AddCode('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Cancel;');
    AddCode('  if cdsDetailed.IsEmpty then Exit;');
    AddCode('  cdsDetailed.Delete;');
    if DetailLine <> '' then AddCode('  RenumberDetails;');
    AddCode('end;');
    AddCode('');
    AddCode('//明细行：复制当前行的业务字段（项次重新排）');
    AddCode('procedure CopyDetailRow;');
    if VarsC <> '' then AddCode('var ' + VarsC + ': Variant;');
    AddCode('begin');
    AddCode('  if (not cdsDetailed.Active) or cdsDetailed.IsEmpty then Exit;');
    AddCode('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Post;');
    for I := 0 to DetailFields.Count - 1 do
    begin
      if SameText(DetailFields[I], DetailKey) or SameText(DetailFields[I], DetailLine) then Continue;
      AddCode('  C' + IntToStr(I) + ' := cdsDetailed.FieldByName(' + QuotedStr(DetailFields[I]) + ').AsVariant;');
    end;
    AddCode('  AppendDetailOneRow;');
    AddCode('  cdsDetailed.Edit;');
    for I := 0 to DetailFields.Count - 1 do
    begin
      if SameText(DetailFields[I], DetailKey) or SameText(DetailFields[I], DetailLine) then Continue;
      AddCode('  cdsDetailed.FieldByName(' + QuotedStr(DetailFields[I]) + ').AsVariant := C' + IntToStr(I) + ';');
    end;
    AddCode('  cdsDetailed.Post;');
    if DetailLine <> '' then AddCode('  RenumberDetails;');
    AddCode('end;');
    AddCode('');
    for K := 4 to 5 do
    begin
      if K = 4 then AddCode('//明细行：与上一行交换业务字段值（项次留在原位，随后重排）')
      else AddCode('//明细行：与下一行交换业务字段值');
      if K = 4 then AddCode('procedure MoveDetailUpRow;') else AddCode('procedure MoveDetailDownRow;');
      { var 列表必须写成一条合法声明（'var A, B: Variant;'）—— 写成 'var A; B: Variant;' 会编译不过
        （宿主脚本编译闸门报 ';' expected）。两组变量名合并成一条。 }
      if (VarsC <> '') and (VarsD <> '') then AddCode('var ' + VarsC + ', ' + VarsD + ': Variant;')
      else if VarsC <> '' then AddCode('var ' + VarsC + ': Variant;')
      else if VarsD <> '' then AddCode('var ' + VarsD + ': Variant;');
      AddCode('begin');
      AddCode('  if (not cdsDetailed.Active) or cdsDetailed.IsEmpty then Exit;');
      AddCode('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Post;');
      if K = 4 then AddCode('  if cdsDetailed.Bof then Exit;') else AddCode('  if cdsDetailed.Eof then Exit;');
      for I := 0 to DetailFields.Count - 1 do
      begin
        if SameText(DetailFields[I], DetailKey) or SameText(DetailFields[I], DetailLine) then Continue;
        AddCode('  C' + IntToStr(I) + ' := cdsDetailed.FieldByName(' + QuotedStr(DetailFields[I]) + ').AsVariant;');
      end;
      if K = 4 then AddCode('  cdsDetailed.Prior;') else AddCode('  cdsDetailed.Next;');
      for I := 0 to DetailFields.Count - 1 do
      begin
        if SameText(DetailFields[I], DetailKey) or SameText(DetailFields[I], DetailLine) then Continue;
        AddCode('  D' + IntToStr(I) + ' := cdsDetailed.FieldByName(' + QuotedStr(DetailFields[I]) + ').AsVariant;');
      end;
      AddCode('  cdsDetailed.Edit;');
      for I := 0 to DetailFields.Count - 1 do
      begin
        if SameText(DetailFields[I], DetailKey) or SameText(DetailFields[I], DetailLine) then Continue;
        AddCode('  cdsDetailed.FieldByName(' + QuotedStr(DetailFields[I]) + ').AsVariant := C' + IntToStr(I) + ';');
      end;
      AddCode('  cdsDetailed.Post;');
      if K = 4 then AddCode('  cdsDetailed.Next;') else AddCode('  cdsDetailed.Prior;');
      AddCode('  cdsDetailed.Edit;');
      for I := 0 to DetailFields.Count - 1 do
      begin
        if SameText(DetailFields[I], DetailKey) or SameText(DetailFields[I], DetailLine) then Continue;
        AddCode('  cdsDetailed.FieldByName(' + QuotedStr(DetailFields[I]) + ').AsVariant := D' + IntToStr(I) + ';');
      end;
      AddCode('  cdsDetailed.Post;');
      if DetailLine <> '' then AddCode('  RenumberDetails;');
      AddCode('end;');
      AddCode('');
    end;
    AddCode('//明细行：清空当前主单的全部明细行（保存时才真正落库删除）');
    AddCode('procedure ClearDetailRows;');
    AddCode('begin');
    AddCode('  if (not cdsDetailed.Active) or cdsDetailed.IsEmpty then Exit;');
    AddCode('  if not ConfirmAction(''是否清空当前主单的全部明细行？'') then Exit;');
    AddCode('  if cdsDetailed.State in [dsEdit, dsInsert] then cdsDetailed.Cancel;');
    AddCode('  cdsDetailed.DisableControls;');
    AddCode('  try');
    AddCode('    cdsDetailed.First;');
    AddCode('    while not cdsDetailed.Eof do cdsDetailed.Delete;');
    AddCode('  finally');
    AddCode('    cdsDetailed.EnableControls;');
    AddCode('  end;');
    AddCode('end;');
    AddCode('');
    for I := 0 to 6 do
    begin
      if Buttons.IndexOf(COrder[I]) < 0 then Continue;
      AddCode('procedure ' + COrder[I] + 'OnClick(Sender: TObject);');
      AddCode('begin');
      AddCode('  if not ' + COrder[I] + '.Enabled then Exit;');
      AddCode('  ' + CHandlers[I] + ';');
      AddCode('  SetEditState(vEditing);');
      AddCode('end;');
      AddCode('');
    end;
  end;

  procedure EmitDetailRowBar;
  const
    COrder: array[0..6] of string = ('btDetailAppend', 'btDetailInsert', 'btDetailDelete',
      'btDetailCopy', 'btDetailMoveUp', 'btDetailMoveDown', 'btDetailClear');
    CCaps: array[0..6] of string = ('新增行', '插入行', '删除行', '复制行', '上移', '下移', '清空');
    { 图标位与 mtListEditor 完全一致：新增7(addEdge)/删除8(shanchu1)/上移20(xiangshang)/下移21(xiangxia)
      取自 mtDetail 的列表；插入行29(caidanshouqi)/复制行28(fuzhi)/清空30(guanbi2fill) 是宿主 2026-09-21
      指定的类名，由 EnsureDetailIcons 追加在列表末尾。 }
    CIcons: array[0..6] of Integer = (7, 29, 8, 28, 20, 21, 30);
  var
    I, J, At, X, Count, BarHeight: Integer;
    Bar: TStringList;
  begin
    Count := 0;
    for I := 0 to 6 do
      if Buttons.IndexOf(COrder[I]) >= 0 then Inc(Count);
    if Count = 0 then Exit;
    At := Lines.IndexOf('  object gridDetailed: TUgDBGrid');
    if At < 0 then Exit;
    Bar := TStringList.Create;
    try
      { 高度与主工具条（pToolbar）保持一致（宿主 2026-09-21 反馈：明细工具条比主控件区矮一截）；
        底部同样加一条 1px 分隔线，与工具栏/记录区的风格一致。 }
      BarHeight := 33;
      for J := 0 to Lines.Count - 1 do
        if Trim(Lines[J]) = 'object pToolbar: TUgContainerPanel' then
        begin
          for I := J + 1 to Lines.Count - 1 do
          begin
            if Trim(Lines[I]) = 'end' then Break;
            if Pos('Height = ', Trim(Lines[I])) = 1 then
            begin
              BarHeight := StrToIntDef(Trim(Copy(Trim(Lines[I]), Length('Height = ') + 1, MaxInt)), 33);
              Break;
            end;
          end;
          Break;
        end;
      Bar.Add('  object pDetailBar: TUgContainerPanel');
      Bar.Add('    Align = alTop');
      Bar.Add('    Top = 190');
      Bar.Add('    Height = ' + IntToStr(BarHeight));
      { 宽度按按钮实际占位算（64 + 左右边距各 3），再留点余量，避免最后一个被裁掉。 }
      Bar.Add('    Width = ' + IntToStr(Count * 70 + 8));
      X := 3;
      for I := 0 to 6 do
      begin
        if Buttons.IndexOf(COrder[I]) < 0 then Continue;
        Bar.Add('    object ' + COrder[I] + ': TUgButton');
        Bar.Add('      Align = alLeft');
        Bar.Add('      Left = ' + IntToStr(X));
        Inc(X, 70);
        Bar.Add('      Top = 3');
        Bar.Add('      Width = 64');
        Bar.Add('      Height = 24');
        Bar.Add('      AlignWithMargins = True');
        Bar.Add('      Margins.Left = 3');
        Bar.Add('      Margins.Right = 3');
        Bar.Add('      Images = Imgs');
        Bar.Add('      ImageIndex = ' + IntToStr(CIcons[I]));
        Bar.Add('      Caption = ' + Q(CCaps[I]));
        Bar.Add('    end');
      end;
      Bar.Add('    object detailBarLine: TUgContainerPanel');
      Bar.Add('      Align = alBottom');
      Bar.Add('      Top = ' + IntToStr(BarHeight - 1));
      Bar.Add('      Width = 1270');
      Bar.Add('      Height = 1');
      Bar.Add('      Hint = ' + QuotedStr(''));
      Bar.Add('      ParentColor = False');
      Bar.Add('      Color = 13093060');
      Bar.Add('    end');
      Bar.Add('  end');
      for I := Bar.Count - 1 downto 0 do Lines.Insert(At, Bar[I]);
    finally
      Bar.Free;
    end;
  end;
  procedure AddActionBoundary(const Handler: string; IsMenu: Boolean); forward;
  function ActionHandler(const Handler: string): string; forward;
  procedure LocalizeNoticeText;
  var N,P,J,Depth,Start:Integer; T,R,Token:string;
  begin
    // Translate message literals, not nested field names or runtime values.
    for N:=0 to Code.Count-1 do begin
      T:=Code[N];R:='';P:=1;Depth:=0;
      if Copy(Trim(T),1,2)='//' then Continue;
      while P<=Length(T) do begin
        if (Depth=0)and((Copy(T,P,15)='RaiseException(')or(Copy(T,P,11)='ShowNotice('))then begin
          if Copy(T,P,15)='RaiseException(' then J:=15 else J:=11;
          R:=R+Copy(T,P,J);Inc(P,J);Depth:=1;Continue;
        end;
        if T[P]='''' then begin
          Start:=P;Inc(P);
          while P<=Length(T) do begin
            if T[P]='''' then begin
              if(P<Length(T))and(T[P+1]='''')then Inc(P,2)
              else begin Inc(P);Break;end;
            end else Inc(P);
          end;
          Token:=Copy(T,Start,P-Start);
          if Depth=1 then R:=R+'UGMM.LT('+Token+')' else R:=R+Token;
          Continue;
        end;
        if Depth>0 then begin
          if T[P]='(' then Inc(Depth);
          if T[P]=')' then Dec(Depth);
        end;
        R:=R+T[P];Inc(P);
      end;
      Code[N]:=R;
    end;
  end;

  procedure AddActionBoundary(const Handler: string; IsMenu: Boolean);
  var Argument, T, R, Token, Caption: string; N, P, First: Integer;
  begin
    // Rename only executable identifiers. Preserve SQL, translated messages
    // and comments, and let internal calls propagate failures to the entry.
    for N:=0 to Code.Count-1 do begin
      T:=Code[N]; R:=''; P:=1;
      while P<=Length(T) do begin
        First:=P;
        if Copy(T,P,2)='//' then begin
          R:=R+Copy(T,P,MaxInt); Break;
        end;
        if T[P]='''' then begin
          Inc(P);
          while P<=Length(T) do
            if T[P]='''' then begin
              Inc(P);
              if (P<=Length(T)) and (T[P]='''') then Inc(P)
              else Break;
            end else Inc(P);
        end else if CharInSet(T[P],['A'..'Z','a'..'z','_']) then begin
          Inc(P);
          while (P<=Length(T)) and CharInSet(T[P],['A'..'Z','a'..'z','_','0'..'9']) do Inc(P);
          Token:=Copy(T,First,P-First);
          if SameText(Token,Handler) then begin
            R:=R+'Execute'+Handler; Continue;
          end;
        end else Inc(P);
        R:=R+Copy(T,First,P-First);
      end;
      Code[N]:=R;
    end;
    Caption:=Handler;
    if Handler='btQueryOnClick' then Caption:='查询并选择权限范围内的主单';
    if Handler='btFirstOnClick' then Caption:='显示权限范围内首笔主单';
    if Handler='btPriorOnClick' then Caption:='显示权限范围内上笔主单';
    if Handler='btNextOnClick' then Caption:='显示权限范围内下笔主单';
    if Handler='btLastOnClick' then Caption:='显示权限范围内末笔主单';
    if Handler='btAppendOnClick' then Caption:='新增主单并准备明细录入';
    if Handler='pmAppendUgMenuItemsOnClick' then Caption:='处理新增菜单及单据复制';
    if Handler='btDeleteOnClick' then Caption:='确认后删除当前主单及明细';
    if Handler='btEditorOnClick' then Caption:='检查当前主单并进入修改状态';
    if Handler='btImportOnClick' then Caption:='打开明细文本导入';
    if Handler='pmImportUgMenuItemsOnClick' then Caption:='按菜单选择导入文本或电子表格';
    if Handler='btSaveOnClick' then Caption:='校验并保存主从数据，区分提交失败与刷新失败';
    if Handler='btCancelOnClick' then Caption:='撤销本次编辑并恢复浏览状态';
    if Handler='btAuditOnClick' then Caption:='校验审批权限并审核当前主单';
    if Handler='btUnAuditOnClick' then Caption:='校验审批权限并消审当前主单';
    if Handler='btRepulseOnClick' then Caption:='校验审批权限并撤回当前主单';
    if Handler='btAnnexOnClick' then Caption:='打开当前主单的附件管理';
    if Handler='btCloseOnClick' then Caption:='检查未保存内容并关闭模块';
    AddCode('//'+Caption+'；事件失败时统一显示提示');
    AddCode('//内部校验异常会中止后续操作，不在业务过程之间吞掉异常');
    if IsMenu then begin
      AddCode('procedure '+Handler+'(const ACaption: string);');
      Argument:='ACaption';
    end else begin
      AddCode('procedure '+Handler+'(Sender: TObject);');
      Argument:='Sender';
    end;
    AddCode('begin');
    AddCode('  vRequiredFocus := '''';');
    AddCode('  try');
    AddCode('    Execute'+Handler+'('+Argument+');');
    AddCode('  except');
    AddCode('    ShowActionError(ExceptionMessage);');
    AddCode('  end;');
    AddCode('end;');
    AddCode('');
  end;
  function ActionHandler(const Handler: string): string;
  begin
    Result:=Handler;
  end;

  procedure FormatCodeIndentation;
  var
    Formatted: TStringList;
    I, IndentLevel, OutputIndent: Integer;
    T, L: string;
    InDeclaration, PendingSingleStatement: Boolean;
  begin
    Formatted := TStringList.Create;
    try
      IndentLevel := 0;
      InDeclaration := False;
      PendingSingleStatement := False;
      for I := 0 to Code.Count - 1 do
      begin
        T := Trim(Code[I]);
        if T = '' then
        begin
          Formatted.Add('');
          Continue;
        end;
        L := LowerCase(T);

        if (L = 'var') or (L = 'const') or
          (Copy(L, 1, 10) = 'procedure ') or
          (Copy(L, 1, 9) = 'function ') then
          InDeclaration := False;
        if L = 'begin' then
          InDeclaration := False;

        if (Copy(L, 1, 3) = 'end') or (Copy(L, 1, 5) = 'until') or
          (L = 'finally') or (L = 'except') then
          if IndentLevel > 0 then
            Dec(IndentLevel);

        OutputIndent := IndentLevel;
        if InDeclaration then
          Inc(OutputIndent);
        if PendingSingleStatement and (L <> 'begin') then
          Inc(OutputIndent);
        Formatted.Add(StringOfChar(' ', OutputIndent * 2) + T);
        PendingSingleStatement := False;

        if (L = 'var') or (L = 'const') then
          InDeclaration := True
        else if L = 'begin' then
        begin
          InDeclaration := False;
          Inc(IndentLevel);
        end
        else if (L = 'try') or (L = 'repeat') then
          Inc(IndentLevel)
        else if (L = 'finally') or (L = 'except') then
          Inc(IndentLevel);

        if ((Length(L) >= 5) and (Copy(L, Length(L) - 4, 5) = ' then')) or
          ((Length(L) >= 3) and (Copy(L, Length(L) - 2, 3) = ' do')) or
          (L = 'else') or
          ((Length(L) >= 5) and (Copy(L, Length(L) - 4, 5) = ' else')) or
          ((Length(L) >= 4) and (Copy(L, Length(L) - 3, 4) = ' and')) or
          ((Length(L) >= 3) and (Copy(L, Length(L) - 2, 3) = ' or')) or
          (L[Length(L)] = '+') then
          PendingSingleStatement := True;
      end;
      Code.Assign(Formatted);
    finally
      Formatted.Free;
    end;
  end;
  procedure WrapCodeLines;
  const
    LineWidth = 110;
    LiteralWidth = 64;
  var
    Wrapped: TStringList;
    Line, Expanded, Literal, Prefix, Rest: string;
    Row, P, N, Cut, Candidate, Indent: Integer;
    InString: Boolean;
  begin
    Wrapped := TStringList.Create;
    try
      for Row := 0 to Code.Count - 1 do
      begin
        Line := Code[Row];
        if (Length(Line) <= LineWidth) or
          (Copy(TrimLeft(Line), 1, 2) = '//') then
        begin
          Wrapped.Add(Line);
          Continue;
        end;
        // Decode complete Pascal literals before splitting: doubled quotes and
        // SQL whitespace must survive exactly, including trailing spaces.
        Expanded := '';
        P := 1;
        while P <= Length(Line) do
        begin
          if Line[P] <> '''' then
          begin
            Expanded := Expanded + Line[P];
            Inc(P);
            Continue;
          end;
          Inc(P);
          Literal := '';
          while P <= Length(Line) do
          begin
            if Line[P] = '''' then
            begin
              Inc(P);
              if (P > Length(Line)) or (Line[P] <> '''') then Break;
            end;
            Literal := Literal + Line[P];
            Inc(P);
          end;
          while Length(Literal) > LiteralWidth do
          begin
            Cut := LiteralWidth;
            for N := LiteralWidth downto 1 do
              if Literal[N] = ' ' then
              begin
                Cut := N;
                Break;
              end;
            Expanded := Expanded + QuotedStr(Copy(Literal, 1, Cut)) + ' + ';
            Delete(Literal, 1, Cut);
          end;
          Expanded := Expanded + QuotedStr(Literal);
        end;
        Indent := Length(Line) - Length(TrimLeft(Line));
        Prefix := StringOfChar(' ', Indent + 2);
        Rest := Expanded;
        while Length(Rest) > LineWidth do
        begin
          InString := False;
          Candidate := 0;
          P := 1;
          while P <= Length(Rest) do
          begin
            if Rest[P] = '''' then
            begin
              if InString and (P < Length(Rest)) and (Rest[P + 1] = '''') then
                Inc(P)
              else
                InString := not InString;
            end
            else if not InString and (P > Length(Prefix)) and
              (Rest[P] in [' ', '+', ',', '(', ')']) then
            begin
              if P <= LineWidth then Candidate := P
              else
              begin
                if Candidate = 0 then Candidate := P;
                Break;
              end;
            end;
            Inc(P);
          end;
          if Candidate = 0 then Break;
          Wrapped.Add(TrimRight(Copy(Rest, 1, Candidate)));
          Rest := Prefix + TrimLeft(Copy(Rest, Candidate + 1, MaxInt));
        end;
        Wrapped.Add(Rest);
      end;
      Code.Assign(Wrapped);
    finally
      Wrapped.Free;
    end;
  end;
  function MainControlClass(const AType:string):string;
  begin
    Result:='TUgDBEdit';if SameText(AType,'number')then Result:='TUgDBNumberEdit';if SameText(AType,'date')or SameText(AType,'datetime')then Result:='TUgDBDateTimePicker';
    if SameText(AType,'time')then Result:='TUgDBTimePicker';
    if SameText(AType,'memo')then Result:='TUgDBMemo';
    if SameText(AType,'combobox')then Result:='TUgDBComboBox';
    if SameText(AType,'check')then Result:='TUgDBCheckBox';
    if SameText(AType,'lookupedit')then Result:='TUgDBLookupEdit';if SameText(AType,'lookupeditextra')then Result:='TUgDBLookupEditExtra';
    if SameText(AType,'gridcombobox')then Result:='TUgDBGridCombobox';if SameText(AType,'gridcomboboxextra')then Result:='TUgDBGridComboboxExtra';
  end;
  function DetailEditorClass(const AType:string):string;
  begin
    Result:='';if SameText(AType,'time')or SameText(AType,'date')or SameText(AType,'datetime')then Result:='TUgDateTimePicker';
    if SameText(AType,'memo')then Result:='TUgMemo';
    if SameText(AType,'combobox')then Result:='TUgComboBox';
    if SameText(AType,'check')then Result:='TUgCheckBox';
    if SameText(AType,'lookupedit')then Result:='TUgLookupEdit';if SameText(AType,'lookupeditextra')then Result:='TUgLookupEditExtra';
    if SameText(AType,'gridcombobox')then Result:='TUgGridCombobox';if SameText(AType,'gridcomboboxextra')then Result:='TUgGridComboboxExtra';
  end;
  function DetailPopup(const AType:string):Boolean;
  begin
    Result:=SameText(AType,'lookupedit')or SameText(AType,'lookupeditextra')or
      SameText(AType,'gridcomboboxextra');
  end;
  function CheckCombo(const AOption:string):Boolean;
  var J:TJSONValue;D:TJSONObject;SQL:string;
  begin
    Result:=False;J:=TJSONObject.ParseJSONValue(AOption);
    try
      if not(J is TJSONObject)then Exit(Reject('combobox 缺少有效下拉选项 JSON。'));
      D:=TJSONObject(J);
      if not SameText(S(D,'cbDropDownType'),'SetText')and not SameText(S(D,'cbDropDownType'),'SqlText')then Exit(Reject('combobox 下拉类型须为 SetText 或 SqlText，不支持 SqlQuery。'));
      if Yes(S(D,'cbDynamicLoading'))then Exit(Reject('combobox 暂不支持动态加载。'));
      { 精灵的下拉对话框在 SetText/SqlText 下不提供“显示字段/返回字段”，切换下拉类型时
        也不会清空之前 SqlQuery 留下的值；这些残留只忽略，不作为配置依据（SqlText 取第一列）。 }
      if SameText(S(D,'cbDropDownType'),'SqlText')then begin
        SQL:=LookupSQL(D);
        if not SameText(Copy(SQL,1,7),'select ')or(Pos(';',SQL)>0)or(Pos(':',SQL)>0)or(Pos('--',SQL)>0)or(Pos('/*',SQL)>0)then Exit(Reject('combobox SqlText 须为无参数、无注释的单条 SELECT。'));
      end else if Trim(S(D,'mmText'))='' then Exit(Reject('combobox 固定选项不能为空。'));
      Result:=True;
    finally J.Free;end;
  end;
  procedure AddComboCode(const Name,Options:string);
  var J:TJSONValue;D:TJSONObject;Items:TStringList;Item:string;
  begin
    J:=TJSONObject.ParseJSONValue(Options);Items:=TStringList.Create;
    try
      D:=TJSONObject(J);AddCode('//加载普通下拉选项：'+Name);
      AddCode('procedure Load'+Name+'Items;');
      if SameText(S(D,'cbDropDownType'),'SqlText')then AddCode('var C:TUgClientDataSet;');
      AddCode('begin');AddCode('  '+Name+'.Items.Clear;');
      if SameText(S(D,'cbDropDownType'),'SqlText')then begin
        AddCode('  C:=TUgClientDataSet.Create(nil);');AddCode('  try');
        AddCode('    C.DataNodeName:=cDataNodeName;');AddCode('    C.PageRowCount:=-1;');
        AddCode('    C.CommandText:='+QuotedStr(LookupSQL(D))+';');AddCode('    C.Open;');
        AddCode('    C.First;');
        AddCode('    while not C.Eof do');AddCode('    begin');
        AddCode('      '+Name+'.Items.Add(C.Fields[0].AsString);');
        AddCode('      C.Next;');AddCode('    end;');AddCode('  finally C.Free; end;');
      end else begin
        Items.Text:=StringReplace(StringReplace(S(D,'mmText'),'\r\n',#13#10,[rfReplaceAll]),'\n',#10,[rfReplaceAll]);
        for Item in Items do AddCode('  '+Name+'.Items.Add('+QuotedStr(Item)+');');
      end;
      AddCode('end;');AddCode('');
    finally Items.Free;J.Free;end;
  end;
  procedure AddLookupProperties(const AType,AOption,ADataName:string);
  var JV:TJSONValue;D:TJSONObject;Parts:TStringList;N,AtPos:Integer;F,C:string;
  begin
    JV:=TJSONObject.ParseJSONValue(AOption);Parts:=TStringList.Create;try D:=TJSONObject(JV);
      if IsGridType(AType)then begin
        Lines.Add('      GridLookupDataSet = '+ADataName);Lines.Add('      GridValueField = '+Q(S(D,'edOptionValue')));
        if SameText(AType,'gridcomboboxextra')then begin Lines.Add('      GridDisplayField = '+Q(S(D,'edOptionDisplay')));Lines.Add('      GridValueWidth = 120');end;
        Lines.Add('      GridLookupDataSetFilter = '+BoolToStr(not DynamicLookup(D),True));Lines.Add('      GridWebOptionPaged = '+BoolToStr(SameText(S(D,'cbGridPageSetting'),'Open'),True));
        if SameText(S(D,'cbGridPageSetting'),'Open')then Lines.Add('      GridWebOptionPageSize = '+IntToStr(StrToIntDef(S(D,'sePageSize'),50)));
        Parts.StrictDelimiter:=True;Parts.Delimiter:=';';Parts.DelimitedText:=S(D,'edOptionFields');Lines.Add('      GridLookupFields = <');
        for N:=0 to Parts.Count-1 do begin F:=Trim(Parts[N]);C:=F;AtPos:=Pos('@',F);if AtPos>0 then begin C:=Copy(F,AtPos+1,MaxInt);F:=Copy(F,1,AtPos-1);end;Lines.Add('        item');Lines.Add('          IsLookUp = '+BoolToStr(LookupSearchField(D,F),True));Lines.Add('          Visible = True');Lines.Add('          FieldName = '+Q(F));Lines.Add('          Caption = '+Q(C));Lines.Add('          Width = 160');Lines.Add('        end');end;Lines.Add('      >');
      end else begin
        Lines.Add('      LookupData = '+ADataName);Lines.Add('      LookupCaption = '+Q(S(D,'edOptionCaption')));Lines.Add('      LookupValueField = '+Q(S(D,'edOptionValue')));
        if SameText(AType,'lookupeditextra')then begin Lines.Add('      LookupDisplayField = '+Q(S(D,'edOptionDisplay')));Lines.Add('      LookupCodeWidth = 120');end;
        { 与表格下拉一致：列（含 字段@标题）取自 edOptionFields（展示字段），
          为空时回退到 edOptionLookupFields，兼容旧配置。 }
        Parts.StrictDelimiter:=True;Parts.Delimiter:=';';
        Parts.DelimitedText:=S(D,'edOptionFields');
        if Trim(Parts.DelimitedText)=''then Parts.DelimitedText:=S(D,'edOptionLookupFields');
        Lines.Add('      LookupFields = <');
        for N:=0 to Parts.Count-1 do begin F:=Trim(Parts[N]);if F='' then Continue;C:=F;AtPos:=Pos('@',F);if AtPos>0 then begin C:=Copy(F,AtPos+1,MaxInt);F:=Copy(F,1,AtPos-1);end;Lines.Add('        item');Lines.Add('          FieldName = '+Q(F));Lines.Add('          Caption = '+Q(C));Lines.Add('          Width = 160');Lines.Add('        end');end;Lines.Add('      >');
      end;
    finally Parts.Free;JV.Free;end;
  end;
  procedure AddDynamicLookupCode(const AControl,ADataName,AOption:string;ARefocus:Boolean);
  var JV:TJSONValue;D:TJSONObject;Parts:TStringList;N,AtPos,Count,MaxRows:Integer;F,Expr:string;
  begin
    JV:=TJSONObject.ParseJSONValue(AOption);Parts:=TStringList.Create;try D:=TJSONObject(JV);if not DynamicLookup(D)then Exit;
      MaxRows:=StrToIntDef(S(D,'seMaxRecordCount'),100);if MaxRows<1 then MaxRows:=100;
      { 行数上限随驱动：MSSQL/MSAcc 用 top N，MySQL/SQLite 等用 limit N，Oracle 不加
        （与 DetailTemplate 同一约定）。原版样例跑在 MySQL 上，照抄 'limit' 到 MSSQL
        会报 '"limit" 附近有语法错误'，所以在脚本里按 cDataNodeDriver 现算。 }
      Expr:=QuotedStr('select')+'+iif((cDataNodeDriver = '+QuotedStr('MSSQL')+') or (cDataNodeDriver = '+QuotedStr('MSAcc')+'), '+QuotedStr(' top '+IntToStr(MaxRows))+', '+QuotedStr('')+')';
      Expr:=Expr+'+'+QuotedStr(' ug_grid.* from ('+LookupSQL(D)+') ug_grid where (');Count:=0;
      Parts.StrictDelimiter:=True;Parts.Delimiter:=';';Parts.DelimitedText:=S(D,'edOptionLookupFields');
      for N:=0 to Parts.Count-1 do begin F:=Trim(Parts[N]);AtPos:=Pos('@',F);if AtPos>0 then F:=Copy(F,1,AtPos-1);if not Ident(F)then Continue;if Count>0 then Expr:=Expr+'+'+QuotedStr(' or ');Expr:=Expr+'+'+QuotedStr('ug_grid.'+F+' like ')+'+'+QuotedStr('''%''+Value+''%''');Inc(Count);end;
      Expr:=Expr+'+'+QuotedStr(')')+'+iif((cDataNodeDriver = '+QuotedStr('MSSQL')+') or (cDataNodeDriver = '+QuotedStr('MSAcc')+') or (cDataNodeDriver = '+QuotedStr('Ora')+'), '+QuotedStr('')+', '+QuotedStr('  limit '+IntToStr(MaxRows))+')';
      if ARefocus then begin
        Expr:=StringReplace(Expr,'+Value+','+SearchValue+',[rfReplaceAll]);
        AddCode('//展开明细候选列表时，不沿用上次的搜索值');
        AddCode('procedure '+AControl+'OnExpand(Sender: TObject);');
        AddCode('begin');
        AddCode('  vDetailLookupOpening := '+QuotedStr(AControl)+';');
        AddCode('end;');
        AddCode('');
      end;
      AddCode('//动态加载 '+AControl+' 的查找数据');
      AddCode('procedure '+AControl+'OnExtEditValueChange(Sender: TObject;const Value:String);');
      AddCode('var');
      AddCode('  C: TUgClientDataSet;');
      if ARefocus then AddCode('  SearchValue: String;');
      AddCode('begin');
      if ARefocus then begin
        AddCode('  SearchValue := Value;');
        AddCode('  if vDetailLookupOpening = '+QuotedStr(AControl)+' then');
        AddCode('    SearchValue := '''';');
        AddCode('  vDetailLookupOpening := '''';');
      end;
      AddCode('  C := '+ADataName+';');
      AddCode('  C.DataNodeName := cDataNodeName;');
      AddCode('  C.Close;');
      if ARefocus then begin
        AddCode('  C.Filtered := False;');
        AddCode('  C.Filter := '''';');
      end;
      AddCode('  C.CommandText := '+Expr+';');
      AddCode('  C.Open;');
      if ARefocus then AddCode('  '+AControl+'.SetFocus;');
      AddCode('end;');
      AddCode('');
    finally Parts.Free;JV.Free;end;
  end;
begin
  Result:=False;DFM:='';Reason:='';
  if not SameText(S(Config,'TWebModuletype'),'mtMasterSlave')then Exit(Reject('模块类型不是 mtMasterSlave。'));
  Buttons:=TStringList.Create;MainFields:=TStringList.Create;MainCaptions:=TStringList.Create;MainTypes:=TStringList.Create;MainOptions:=TStringList.Create;
  DetailFields:=TStringList.Create;DetailCaptions:=TStringList.Create;DetailTypes:=TStringList.Create;DetailOptions:=TStringList.Create;Code:=TStringList.Create;Lines:=TStringList.Create;
  RequiredMain:=TStringList.Create;RequiredDetail:=TStringList.Create;UniqueMain:=TStringList.Create;UniqueDetail:=TStringList.Create;
  ImportFrameCaptions:=TStringList.Create;ImportFrameNames:=TStringList.Create;ImportFrameMulti:=TStringList.Create;
  HiddenMain:=TStringList.Create;HiddenDetail:=TStringList.Create;
  CheckDetailFields:=TStringList.Create;CheckDetailCaptions:=TStringList.Create;
  CheckTables:=TStringList.Create;CheckSourceFields:=TStringList.Create;
  JoinFields:=TStringList.Create;JoinCaptions:=TStringList.Create;
  JoinFieldAliases:=TStringList.Create;
  OrderedTables:=TList<TJSONObject>.Create;
  RootKeys:=TStringList.Create;
  HasChain:=False;
  MainDisplayOrder:=TStringList.Create;DetailDisplayOrder:=TStringList.Create;
  LayOrder:=TStringList.Create;LayTemp:=nil;HasLayout:=False;
  JoinTable:='';JoinAlias:='';JoinClause:='';
  AutoJSON:=nil;MainUniqueJSON:=nil;DetailUniqueJSON:=nil;ApprovalJSON:=nil;CheckJSON:=nil;DropValue:=nil;
  try
    Buttons.StrictDelimiter:=True;Buttons.Delimiter:=';';Buttons.DelimitedText:=S(Config,'TWebFunctionButton');
    for V in Buttons do if(V<>'')and(Pos(';'+V+';',AllowedButtons)=0)then Exit(Reject('mtMasterSlave 当前阶段尚未实现按钮：'+V));
    Settings:=O(Config,'TWebNormalSetting');
    if Yes(S(Config,'TWebDataNodeNamecbAddCatalogName'))and not Ident(Trim(NodeCatalog))then
      Exit(Reject('已勾选添加数据库名，但节点未提供有效的简单数据库名；文件路径不能作为SQL前缀。请检查节点配置或取消勾选。'));
    if Yes(S(Config,'TWebDataNodeNamecbAddSchemaName'))and not Ident(Trim(NodeSchema))then
      Exit(Reject('已勾选添加Schema，但节点未提供有效的简单Schema名称。请检查节点配置或取消勾选。'));
    ApprovalMode:=(Buttons.IndexOf('btAudit')>=0)or(Buttons.IndexOf('btUnAudit')>=0)or(Buttons.IndexOf('btRepulse')>=0)or(Trim(S(Settings,'审批规则'))<>'');
    WriteMode:=(Buttons.IndexOf('btAppend')>=0)or(Buttons.IndexOf('btDelete')>=0)or(Buttons.IndexOf('btEditor')>=0)or(Buttons.IndexOf('btSave')>=0)or(Buttons.IndexOf('btCancel')>=0)or ApprovalMode;
    if((Buttons.IndexOf('btAppend')>=0)or(Buttons.IndexOf('btEditor')>=0))and
      ((Buttons.IndexOf('btSave')<0)or(Buttons.IndexOf('btCancel')<0))then
      Exit(Reject('新增或修改需要同时启用保存和撤销按钮。'));
    if((Buttons.IndexOf('btSave')>=0)or(Buttons.IndexOf('btCancel')>=0)or(Buttons.IndexOf('btImport')>=0))and
      (Buttons.IndexOf('btAppend')<0)and(Buttons.IndexOf('btEditor')<0)then
      Exit(Reject('保存、撤销和明细导入需要至少启用新增或修改按钮。'));
    MT:=O(O(O(Config,'TWebDataStructure'),'cdsTables'),'Data');
    DT:=O(O(O(Config,'TWebDetailedStructure'),'cdsTables'),'Data');
    MC:=O(O(O(Config,'TWebDataStructure'),'cdsColumns'),'Data');
    DC:=O(O(O(Config,'TWebDetailedStructure'),'cdsColumns'),'Data');
    if(MT=nil)or(MT.Count<>1)or(DT=nil)or(DT.Count<1)or(MC=nil)or(DC=nil)then Exit(Reject('需要一张主表、一张明细基础表；辅助表须直接LEFT JOIN到明细基础表。'));
    Row:=O(MT,'0');MainTable:=S(Row,'fdTableName');MAlias:=S(Row,'fdEpithet');
    Row:=O(DT,'0');DetailTable:=S(Row,'fdTableName');DAlias:=S(Row,'fdEpithet');
    if not ResolveTableName(MainTable)or not Ident(MAlias)or not ResolveTableName(DetailTable)or not Ident(DAlias)then Exit(Reject('主从表名须由1至3段简单标识符组成，别名须为简单标识符。'));
    SetLength(Joins,DT.Count-1);
    OrderedTables.Add(O(DT,'0'));
    for I:=0 to DT.Count-1 do begin
      if S(O(DT,IntToStr(I)),'fdGuid')='' then Exit(Reject('关联表缺少GUID。'));
      for J:=0 to I-1 do
        if SameText(S(O(DT,IntToStr(I)),'fdGuid'),S(O(DT,IntToStr(J)),'fdGuid'))then
          Exit(Reject('关联表GUID不能重复。'));
    end;
    while OrderedTables.Count<DT.Count do begin
      AddedTable:=False;
      for I:=1 to DT.Count-1 do begin
        Candidate:=O(DT,IntToStr(I));
        if OrderedTables.Contains(Candidate) then Continue;
        for J:=0 to OrderedTables.Count-1 do
          if SameText(S(Candidate,'fdParent'),S(OrderedTables[J],'fdGuid'))then begin
            OrderedTables.Add(Candidate);AddedTable:=True;Break;
          end;
      end;
      if not AddedTable then Exit(Reject('关联表父级不存在或存在循环关联。'));
    end;
    for JoinIndex:=0 to High(Joins) do begin
      Row:=OrderedTables[JoinIndex+1];JoinTable:=S(Row,'fdTableName');JoinAlias:=S(Row,'fdEpithet');
      ParentRow:=nil;
      for J:=0 to JoinIndex do
        if SameText(S(Row,'fdParent'),S(OrderedTables[J],'fdGuid')) then ParentRow:=OrderedTables[J];
      Joins[JoinIndex].ParentAlias:=S(ParentRow,'fdEpithet');
      if not SameText(Joins[JoinIndex].ParentAlias,DAlias)then HasChain:=True;
      for J:=0 to JoinIndex-1 do
        if SameText(Joins[J].AliasName,JoinAlias) then Exit(Reject('明细关联表别名不能重复。'));
      if not ResolveTableName(JoinTable)or not Ident(JoinAlias)or SameText(JoinAlias,DAlias)or
        not SameText(Trim(S(Row,'fdAssociationMethod')),'left join')then
        Exit(Reject('明细关联仅支持有效别名和LEFT JOIN。'));
      Joins[JoinIndex].TableName:=JoinTable;
      Joins[JoinIndex].AliasName:=JoinAlias;
      JoinFilter:='';
      for ConditionIndex:=0 to 2 do begin
      V:=Trim(S(Row,'fdCriteria'+IntToStr(ConditionIndex+1)));
      if V='' then begin
        if ConditionIndex=0 then Exit(Reject('明细关联必须填写第一组条件。'));
        Continue;
      end;
      if Joins[JoinIndex].KeyCount<>ConditionIndex then Exit(Reject('关联条件须从第一组开始连续填写。'));
      X:=Pos('=',V);
      if X=0 then Exit(Reject('明细关联条件须为明细字段 = 关联字段。'));
      JoinBaseKey:=FieldPart(Trim(Copy(V,1,X-1)),Joins[JoinIndex].ParentAlias);
      JoinOtherKey:=FieldPart(Trim(Copy(V,X+1,MaxInt)),JoinAlias);
      if not Ident(JoinBaseKey)or not Ident(JoinOtherKey)or
        not HasColumn(DC,Joins[JoinIndex].ParentAlias,JoinBaseKey)or not HasColumn(DC,JoinAlias,JoinOtherKey)then
        Exit(Reject('明细关联条件须为有效的父表字段 = 当前关联表字段。'));
      if SameText(Joins[JoinIndex].ParentAlias,DAlias)and(RootKeys.IndexOf(JoinBaseKey)<0) then RootKeys.Add(JoinBaseKey);
      for J:=0 to ConditionIndex-1 do
        if SameText(Joins[JoinIndex].BaseKeys[J],JoinBaseKey) and
          SameText(Joins[JoinIndex].OtherKeys[J],JoinOtherKey)then Exit(Reject('关联条件不能重复。'));
      Joins[JoinIndex].BaseKeys[ConditionIndex]:=JoinBaseKey;
      Joins[JoinIndex].OtherKeys[ConditionIndex]:=JoinOtherKey;
      Inc(Joins[JoinIndex].KeyCount);
      if JoinFilter<>'' then JoinFilter:=JoinFilter+' and ';
      JoinFilter:=JoinFilter+Joins[JoinIndex].ParentAlias+'.'+JoinBaseKey+' = '+JoinAlias+'.'+JoinOtherKey;
      end;
      JoinClause:=JoinClause+' left join '+JoinTable+' '+JoinAlias+' on '+JoinFilter;
    end;
    Settings:=O(Config,'TWebNormalSetting');QueryFrame:=Trim(S(Settings,'查询窗体'));
    MainKey:=FieldPart(Trim(S(Settings,'关联字段')),MAlias);DetailKey:=FieldPart(Trim(S(Settings,'关联从表')),DAlias);
    OrderField:=FieldPart(Trim(S(Settings,'录入时间')),MAlias);DeptField:=FieldPart(Trim(S(Settings,'录入部门')),MAlias);
    DetailLine:=FieldPart(Trim(S(Settings,'明细编号')),DAlias);
    CreateDept:=FieldPart(Trim(S(Settings,'录入部门')),MAlias);CreateUser:=FieldPart(Trim(S(Settings,'录入用户')),MAlias);CreateTime:=FieldPart(Trim(S(Settings,'录入时间')),MAlias);
    EditDept:=FieldPart(Trim(S(Settings,'修改部门')),MAlias);EditUser:=FieldPart(Trim(S(Settings,'修改用户')),MAlias);EditTime:=FieldPart(Trim(S(Settings,'修改时间')),MAlias);
    EditCount:=FieldPart(Trim(S(Settings,'编辑次数')),MAlias);
    DocumentDate:=FieldPart(Trim(S(Settings,'单据日期')),MAlias);
    if(Buttons.IndexOf('btQuery')>=0)and not Ident(QueryFrame)then Exit(Reject('启用查询按钮时请配置有效的查询窗体标题。'));
    if not Ident(MainKey)or not HasColumn(MC,MAlias,MainKey)then Exit(Reject('关联字段必须属于主表。'));
    if not Ident(DetailKey)or not HasColumn(DC,DAlias,DetailKey)then Exit(Reject('关联从表必须属于从表。'));
    if OrderField='' then OrderField:=MainKey;
    if not Ident(OrderField)or not HasColumn(MC,MAlias,OrderField)then Exit(Reject('导航字段必须是已配置的主表录入时间字段。'));
    if Yes(S(Settings,'层级权限'))and(not Ident(DeptField)or not HasColumn(MC,MAlias,DeptField))then Exit(Reject('层级权限需要有效的录入部门字段。'));
    if(CreateDept<>'')and(not Ident(CreateDept)or not HasColumn(MC,MAlias,CreateDept))then Exit(Reject('录入部门字段必须属于主表。'));
    if(CreateUser<>'')and(not Ident(CreateUser)or not HasColumn(MC,MAlias,CreateUser))then Exit(Reject('录入用户字段必须属于主表。'));
    if(CreateTime<>'')and(not Ident(CreateTime)or not HasColumn(MC,MAlias,CreateTime))then Exit(Reject('录入时间字段必须属于主表。'));
    if(EditDept<>'')and(not Ident(EditDept)or not HasColumn(MC,MAlias,EditDept))then Exit(Reject('修改部门字段必须属于主表。'));
    if(EditUser<>'')and(not Ident(EditUser)or not HasColumn(MC,MAlias,EditUser))then Exit(Reject('修改用户字段必须属于主表。'));
    if(EditTime<>'')and(not Ident(EditTime)or not HasColumn(MC,MAlias,EditTime))then Exit(Reject('修改时间字段必须属于主表。'));
    if(EditCount<>'')and(not Ident(EditCount)or not HasColumn(MC,MAlias,EditCount))then Exit(Reject('编辑次数字段必须属于主表。'));
    if(DocumentDate<>'')and(not Ident(DocumentDate)or not HasColumn(MC,MAlias,DocumentDate))then Exit(Reject('单据日期字段必须属于主表。'));
    V:=Trim(S(Settings,'文本类型'));
    if(V<>'')and not SameText(V,'Normal')and not SameText(V,'Upper')and not SameText(V,'Lower')then
      Exit(Reject('文本类型须为Normal、Upper或Lower。'));
    for Pair in Settings do begin K:=Pair.JsonString.Value;V:=S(Settings,K);
      if(V='')or SameText(V,'False')or(V='0')or SameText(V,'Normal')then Continue;
      if(K='查询窗体')or(K='关联字段')or(K='关联从表')or(K='录入时间')or(K='录入部门')or(K='录入用户')or(K='修改部门')or(K='修改用户')or(K='修改时间')or(K='编辑次数')or(K='明细编号')or(K='非空字段')or(K='从表非空')or(K='自动编号')or(K='主表唯一')or(K='从表唯一')or(K='审批规则')or(K='单据日期')or(K='层级权限')or
        (K='文本类型')or(K='表格复制')or(K='表格序号')or(K='导入窗体')or(K='字段宽度')or(K='字段移动')or(K='字段显隐')or(K='隐藏字段-主表')or(K='隐藏字段-从表')or(K='记录区布局')then Continue;
      Exit(Reject('mtMasterSlave 当前阶段尚未实现常规设置：'+K));
    end;
    for I:=0 to MC.Count-1 do begin
      Row:=O(MC,IntToStr(I));if not Yes(S(Row,'fdSELECT'))then Continue;V:=FieldPart(S(Row,'fdCOLUMN_NAME'),MAlias);if not Ident(V)then Exit(Reject('主表字段别名错误。'));
      ObjectType:=LowerCase(Trim(S(Row,'fdOBJECT_TYPE')));if ObjectType='' then ObjectType:='edit';
      if ObjectType='checkbox' then ObjectType:='check';
      if(ObjectType<>'edit')and(ObjectType<>'memo')and(ObjectType<>'combobox')and(ObjectType<>'check')and(ObjectType<>'number')and(ObjectType<>'time')and(ObjectType<>'date')and(ObjectType<>'datetime')and(ObjectType<>'lookupedit')and(ObjectType<>'lookupeditextra')and not IsGridType(ObjectType)then Exit(Reject('主表字段 '+V+' 的对象类型尚未支持：'+ObjectType));
      OptionText:='';if IsLookupType(ObjectType)then begin
        DropValue:=TJSONObject.ParseJSONValue(S(Row,'fdDropDownOptions'));try if not(DropValue is TJSONObject)then Exit(Reject('主表字段 '+V+' 缺少有效下拉选项 JSON。'));Drop:=TJSONObject(DropValue);
          if not SameText(S(Drop,'cbDropDownType'),'SqlQuery')then Exit(Reject('主表字段 '+V+' 的查找类型须为 SqlQuery。'));
          K:=LookupSQL(Drop);if(not SameText(Copy(K,1,7),'select '))or(Pos(';',K)>0)or(Pos(':',K)>0)or(Pos('--',K)>0)or(Pos('/*',K)>0)then Exit(Reject('主表字段 '+V+' 的查找 SQL 须为无参数、无注释的单条 SELECT。'));
          if not Ident(S(Drop,'edOptionValue'))or(Trim(S(Drop,'edOptionLookupFields'))='')then Exit(Reject('主表字段 '+V+' 需要有效值字段和查找列。'));
          if((ObjectType='lookupeditextra')or(ObjectType='gridcomboboxextra'))and not Ident(S(Drop,'edOptionDisplay'))then Exit(Reject('主表字段 '+V+' 的 extra 类型需要有效显示字段。'));
          if IsGridType(ObjectType)and(Trim(S(Drop,'edOptionFields'))='')then Exit(Reject('主表字段 '+V+' 的表格下拉需要显示列。'));
          OptionText:=Drop.ToJSON;
        finally FreeAndNil(DropValue);end;
      end;
      MainFields.Add(V);MainCaptions.Add(S(Row,'fdCAPTION'));MainTypes.Add(ObjectType);MainOptions.Add(OptionText);
      if ObjectType='combobox' then begin OptionText:=S(Row,'fdDropDownOptions');if not CheckCombo(OptionText)then Exit(False);MainOptions[MainOptions.Count-1]:=OptionText;end;
    end;
    for I:=0 to DC.Count-1 do begin
      Row:=O(DC,IntToStr(I));V:=FieldPart(S(Row,'fdCOLUMN_NAME'),DAlias);
      JoinAlias:='';
      for J:=0 to High(Joins) do
        if FieldPart(S(Row,'fdCOLUMN_NAME'),Joins[J].AliasName)<>'' then JoinAlias:=Joins[J].AliasName;
      if JoinAlias<>'' then begin
        if Yes(S(Row,'fdSELECT'))then begin
          K:=FieldPart(S(Row,'fdCOLUMN_NAME'),JoinAlias);
          if not Ident(K)or HasColumn(DC,DAlias,JoinAlias+K)then
            Exit(Reject('关联列名称无效或与明细字段重名。'));
          for J:=0 to JoinFields.Count-1 do
            if SameText(JoinFieldAliases[J]+JoinFields[J],JoinAlias+K)then
              Exit(Reject('关联列输出名称重复，请调整表别名。'));
          JoinFields.Add(K);JoinFieldAliases.Add(JoinAlias);JoinCaptions.Add(S(Row,'fdCAPTION'));
        end;
        Continue;
      end;
      if Yes(S(Row,'fdSELECT'))then begin
        if not Ident(V)then Exit(Reject('从表字段别名错误。'));ObjectType:=LowerCase(Trim(S(Row,'fdOBJECT_TYPE')));if ObjectType='' then ObjectType:='edit';
        if ObjectType='checkbox' then ObjectType:='check';
        if(ObjectType<>'edit')and(ObjectType<>'memo')and(ObjectType<>'combobox')and(ObjectType<>'check')and(ObjectType<>'number')and(ObjectType<>'time')and(ObjectType<>'date')and(ObjectType<>'datetime')and(ObjectType<>'lookupedit')and(ObjectType<>'lookupeditextra')and not IsGridType(ObjectType)then Exit(Reject('从表字段 '+V+' 的对象类型尚未支持：'+ObjectType));
        OptionText:='';if IsLookupType(ObjectType)then begin
          DropValue:=TJSONObject.ParseJSONValue(S(Row,'fdDropDownOptions'));try if not(DropValue is TJSONObject)then Exit(Reject('从表字段 '+V+' 缺少有效下拉选项 JSON。'));Drop:=TJSONObject(DropValue);
            if not SameText(S(Drop,'cbDropDownType'),'SqlQuery')then Exit(Reject('从表字段 '+V+' 的查找类型须为 SqlQuery。'));
            K:=LookupSQL(Drop);if(not SameText(Copy(K,1,7),'select '))or(Pos(';',K)>0)or(Pos(':',K)>0)or(Pos('--',K)>0)or(Pos('/*',K)>0)then Exit(Reject('从表字段 '+V+' 的查找 SQL 须为无参数、无注释的单条 SELECT。'));
            if not Ident(S(Drop,'edOptionValue'))or(Trim(S(Drop,'edOptionLookupFields'))='')then Exit(Reject('从表字段 '+V+' 需要有效值字段和查找列。'));
            if((ObjectType='lookupeditextra')or(ObjectType='gridcomboboxextra'))and not Ident(S(Drop,'edOptionDisplay'))then Exit(Reject('从表字段 '+V+' 的 extra 类型需要有效显示字段。'));
            if IsGridType(ObjectType)and(Trim(S(Drop,'edOptionFields'))='')then Exit(Reject('从表字段 '+V+' 的表格下拉需要显示列。'));
            OptionText:=Drop.ToJSON;
          finally FreeAndNil(DropValue);end;
        end;
        DetailFields.Add(V);DetailCaptions.Add(S(Row,'fdCAPTION'));DetailTypes.Add(ObjectType);DetailOptions.Add(OptionText);
        if ObjectType='combobox' then begin OptionText:=S(Row,'fdDropDownOptions');if not CheckCombo(OptionText)then Exit(False);DetailOptions[DetailOptions.Count-1]:=OptionText;end;
      end;
      if Trim(S(Row,'fdDataCheck'))<>'' then begin
        if not Ident(V)then Exit(Reject('从表数据校验字段别名错误。'));
        CheckJSON:=TJSONObject.ParseJSONValue(S(Row,'fdDataCheck'));
        if not(CheckJSON is TJSONObject)then Exit(Reject('从表数据校验配置不是有效 JSON 对象。'));
        K:=Trim(S(TJSONObject(CheckJSON),'cbTableName'));
        SQLMain:=Trim(S(TJSONObject(CheckJSON),'cbField'));
        if not Ident(K)or not Ident(SQLMain)then Exit(Reject('从表数据校验仅支持简单表名和字段名。'));
        CheckDetailFields.Add(V);CheckDetailCaptions.Add(S(Row,'fdCAPTION'));
        CheckTables.Add(K);CheckSourceFields.Add(SQLMain);
        FreeAndNil(CheckJSON);
      end;
    end;
    if(MainFields.Count=0)or(DetailFields.Count=0)then Exit(Reject('主表和从表都必须选择显示字段。'));
    // Display ordering is separate from SQL, validation and writeback ordering.
    Lines.Clear;
    for I:=0 to MainFields.Count-1 do Lines.Add(MAlias+'.'+MainFields[I]);
    OrderDisplayFields('TWebDataStructure',Lines,MainDisplayOrder);
    Lines.Clear;
    for I:=0 to DetailFields.Count-1 do Lines.Add(DAlias+'.'+DetailFields[I]);
    for I:=0 to JoinFields.Count-1 do Lines.Add(JoinFieldAliases[I]+'.'+JoinFields[I]);
    OrderDisplayFields('TWebDetailedStructure',Lines,DetailDisplayOrder);
    Lines.Clear;
    HiddenMain.StrictDelimiter:=True;HiddenMain.Delimiter:=';';HiddenMain.DelimitedText:=S(Settings,'隐藏字段-主表');
    for I:=HiddenMain.Count-1 downto 0 do begin V:=FieldPart(Trim(HiddenMain[I]),MAlias);if V='' then HiddenMain.Delete(I)else if not Ident(V)or not HasColumn(MC,MAlias,V)then Exit(Reject('隐藏字段-主表必须属于主表。'))else HiddenMain[I]:=V;end;
    HiddenDetail.StrictDelimiter:=True;HiddenDetail.Delimiter:=';';HiddenDetail.DelimitedText:=S(Settings,'隐藏字段-从表');
    for I:=HiddenDetail.Count-1 downto 0 do begin V:=FieldPart(Trim(HiddenDetail[I]),DAlias);if V='' then HiddenDetail.Delete(I)else if not Ident(V)or not HasColumn(DC,DAlias,V)then Exit(Reject('隐藏字段-从表必须属于从表。'))else HiddenDetail[I]:=V;end;
    { 记录区布局（可选区块，键名「记录区布局」）：解析、校验与拒绝文案和 mtListEditor 完全共用
      ugConfiguration.ListEditorLayout。**未配置时 HasLayout=False，下面所有布局分支都不走**，
      记录区保持原版三分栏（已验收版式逐字节不变）。 }
    HasLayout:=False;
    if Settings<>nil then
    begin
      HasLayout:=ReadListEditorLayout(Config,LayoutItems,LayColumns,LayFieldWidth,
        LayPosition,LayGroups,LayReason);
      if LayReason<>'' then Exit(Reject(LayReason));
    end;
    if HasLayout then
    begin
      { 布局行逐一映射到主表**已勾选**字段：别名去掉后必须命中 MainFields，否则按"以当前数据结构
        为准"丢弃（与 mtListEditor 一致，换表后残留的旧字段不该卡住生成），全部丢弃后才拒绝。 }
      LayOrder.Clear;
      for I:=0 to High(LayoutItems) do
      begin
        LayField:=FieldPart(LayoutItems[I].Field,MAlias);
        if LayField='' then LayField:=Trim(LayoutItems[I].Field);
        LayIndex:=MainFields.IndexOf(LayField);
        if LayIndex<0 then Continue;
        if LayOrder.IndexOf(MainFields[LayIndex])>=0 then
          Exit(Reject('记录区布局里字段重复：'+LayoutItems[I].Field));
        LayOrder.Add(MainFields[LayIndex]);
      end;
      if LayOrder.Count=0 then
        Exit(Reject('记录区布局里已没有可用字段（数据结构可能已变更）：请打开“记录区布局”重新确认并保存。'));
      { 显示顺序：布局里可见的字段按布局行序排在前，布局里没显示的（fdVISIBLE=False）或没列进布局的
        主字段接在后面 —— 它们**照常生成控件、只是 Visible=False**。mtMasterSlave 的脚本里
        a<字段> 被多处引用（SetEditState 的 ReadOnly 循环、combobox 的 Loada<字段>Items、动态查找
        事件绑定、必填聚焦、导入/审批路径），少生成一个控件就是"标识符未宣告"。 }
      LayTemp:=TStringList.Create;
      try
        for I:=0 to LayOrder.Count-1 do LayTemp.Add(MAlias+'.'+LayOrder[I]);
        for I:=0 to MainDisplayOrder.Count-1 do
          if LayOrder.IndexOf(FieldPart(MainDisplayOrder[I],MAlias))<0 then
            LayTemp.Add(MainDisplayOrder[I]);
        MainDisplayOrder.Assign(LayTemp);
      finally
        LayTemp.Free;
      end;
    end;
    GridPersonalization:=Yes(S(Settings,'字段宽度'))or Yes(S(Settings,'字段移动'))or Yes(S(Settings,'字段显隐'));
    RequiredMain.StrictDelimiter:=True;RequiredMain.Delimiter:=';';RequiredMain.DelimitedText:=S(Settings,'非空字段');
    for I:=RequiredMain.Count-1 downto 0 do begin V:=FieldPart(Trim(RequiredMain[I]),MAlias);if V='' then RequiredMain.Delete(I) else if not Ident(V)or not HasColumn(MC,MAlias,V)then Exit(Reject('主表非空字段必须属于主表。')) else RequiredMain[I]:=V;end;
    RequiredDetail.StrictDelimiter:=True;RequiredDetail.Delimiter:=';';RequiredDetail.DelimitedText:=S(Settings,'从表非空');
    for I:=RequiredDetail.Count-1 downto 0 do begin V:=FieldPart(Trim(RequiredDetail[I]),DAlias);if V='' then RequiredDetail.Delete(I) else if not Ident(V)or not HasColumn(DC,DAlias,V)then Exit(Reject('从表非空字段必须属于从表。')) else RequiredDetail[I]:=V;end;
    if DetailLine<>'' then if not Ident(DetailLine)or not HasColumn(DC,DAlias,DetailLine)then Exit(Reject('明细编号必须属于从表。'));
    if(JoinTable<>'')and(DetailLine='')then Exit(Reject('明细关联写回需要配置明细编号。'));
    ImportRequired:='';ImportCaptions:='';
    for I:=0 to RequiredDetail.Count-1 do if(not SameText(RequiredDetail[I],DetailKey))and(not SameText(RequiredDetail[I],DetailLine))then ImportRequired:=ImportRequired+RequiredDetail[I]+';';
    for I:=0 to DetailFields.Count-1 do if(not SameText(DetailFields[I],DetailKey))and(not SameText(DetailFields[I],DetailLine))then ImportCaptions:=ImportCaptions+DetailCaptions[I]+';';
    if ImportRequired='' then for I:=0 to DetailFields.Count-1 do if(not SameText(DetailFields[I],DetailKey))and(not SameText(DetailFields[I],DetailLine))then ImportRequired:=ImportRequired+DetailFields[I]+';';
    if(Buttons.IndexOf('btImport')>=0)and(ImportCaptions='')then Exit(Reject('主从明细导入至少需要一个可编辑的从表业务字段。'));
    // 导入窗体（扩充项）：导入下拉的子项列表 = 标题 + 来源查询窗体 + 允许多选
    ImportFrameCaptions.Clear;ImportFrameNames.Clear;ImportFrameMulti.Clear;
    if Trim(S(Settings,'导入窗体'))<>'' then begin
      ImportFramesJSON:=TJSONObject.ParseJSONValue(S(Settings,'导入窗体'));
      if not(ImportFramesJSON is TJSONObject)then Exit(Reject('导入窗体配置不是 JSON 对象。'));
      if not(TJSONObject(ImportFramesJSON).GetValue('items') is TJSONArray)then Exit(Reject('导入窗体配置缺少 items 列表。'));
      ImportFramesArray:=TJSONArray(TJSONObject(ImportFramesJSON).GetValue('items'));
      for I:=0 to ImportFramesArray.Count-1 do begin
        if not(ImportFramesArray.Items[I] is TJSONObject)then Continue;
        ImportFrameItem:=TJSONObject(ImportFramesArray.Items[I]);
        V:=Trim(ImportFrameItemStr(ImportFrameItem,'caption'));
        K:=Trim(ImportFrameItemStr(ImportFrameItem,'frame'));
        if(V='')and(K='')then Continue;
        if V='' then Exit(Reject('导入窗体第 '+IntToStr(I+1)+' 行缺少菜单标题。'));
        if K='' then Exit(Reject('导入窗体第 '+IntToStr(I+1)+' 行缺少查询窗体。'));
        ImportFrameCaptions.Add(V);ImportFrameNames.Add(K);
        if SameText(Trim(ImportFrameItemStr(ImportFrameItem,'multiSelect')),'false')then ImportFrameMulti.Add('False')else ImportFrameMulti.Add('True');
      end;
    end;
    if(ImportFrameCaptions.Count>0)and(Buttons.IndexOf('btImport')<0)then Exit(Reject('配置「导入窗体」需要启用导入按钮（入口在导入下拉菜单中）。'));
    if Trim(S(Settings,'自动编号'))<>'' then begin
      if not WriteMode then Exit(Reject('自动编号需要启用主从写回按钮。'));
      AutoJSON:=TJSONObject.ParseJSONValue(S(Settings,'自动编号'));
      if not(AutoJSON is TJSONObject)then Exit(Reject('自动编号配置不是有效 JSON 对象。'));
      AutoField:=FieldPart(Trim(S(TJSONObject(AutoJSON),'cbField')),MAlias);AutoType:=Trim(S(TJSONObject(AutoJSON),'cbAutoNumberType'));
      AutoPrefix:=S(TJSONObject(AutoJSON),'edPrefix');AutoDigits:=Trim(S(TJSONObject(AutoJSON),'seDigitCapacity'));AutoSuffix:=S(TJSONObject(AutoJSON),'edSuffix');
      if not Ident(AutoField)or not HasColumn(MC,MAlias,AutoField)then Exit(Reject('自动编号字段必须属于主表。'));
      if not SameText(AutoField,MainKey)then Exit(Reject('mtMasterSlave 本批自动编号字段必须与主表关联字段一致。'));
      if not SameText(AutoType,'MaxCode')and not SameText(AutoType,'Guid')and
        not SameText(AutoType,'DateTimeRandom')then
        Exit(Reject('mtMasterSlave 自动编号当前支持 MaxCode、Guid、DateTimeRandom；其余规则尚未实现。'));
      if SameText(AutoType,'DateTimeRandom')then begin
        I:=StrToIntDef(AutoDigits,0);
        if(I<1)or(I>9)then
          Exit(Reject('DateTimeRandom 编号位数必须为1到9；宿主 RandomInt 使用32位整数。'));
        AutoDigits:=IntToStr(I);
      end;
      if SameText(AutoType,'MaxCode')then begin
        I:=StrToIntDef(AutoDigits,0);
        if(I<1)or(I>30)then Exit(Reject('MaxCode 编号位数必须为 1 到 30。'));
      end;
    end;
    if Trim(S(Settings,'主表唯一'))<>'' then begin
      if not WriteMode then Exit(Reject('主表唯一校验需要启用主从写回按钮。'));
      MainUniqueJSON:=TJSONObject.ParseJSONValue(S(Settings,'主表唯一'));
      if not(MainUniqueJSON is TJSONObject)then Exit(Reject('主表唯一配置不是有效 JSON 对象。'));
      UniqueRecordField:=FieldPart(Trim(S(TJSONObject(MainUniqueJSON),'cbField')),MAlias);
      if not Ident(UniqueRecordField)or not HasColumn(MC,MAlias,UniqueRecordField)then Exit(Reject('主表唯一的记录编号字段必须属于主表。'));
      if not SameText(UniqueRecordField,MainKey)then Exit(Reject('mtMasterSlave 本批主表唯一的记录编号字段必须与主表关联字段一致。'));
      UniqueMain.StrictDelimiter:=True;UniqueMain.Delimiter:=';';UniqueMain.DelimitedText:=S(TJSONObject(MainUniqueJSON),'cdsMultiSelectFields');
      for I:=UniqueMain.Count-1 downto 0 do begin V:=FieldPart(Trim(UniqueMain[I]),MAlias);if V='' then UniqueMain.Delete(I)else if not Ident(V)or not HasColumn(MC,MAlias,V)then Exit(Reject('主表组合唯一字段必须属于主表。'))else UniqueMain[I]:=V;end;
      if UniqueMain.Count=0 then Exit(Reject('请至少配置一个主表组合唯一字段。'));
      for I:=0 to UniqueMain.Count-1 do begin if UniqueMainLabel<>'' then UniqueMainLabel:=UniqueMainLabel+', ';UniqueMainLabel:=UniqueMainLabel+UniqueMain[I];end;
    end;
    if Trim(S(Settings,'从表唯一'))<>'' then begin
      if not WriteMode then Exit(Reject('从表唯一校验需要启用主从写回按钮。'));
      DetailUniqueJSON:=TJSONObject.ParseJSONValue(S(Settings,'从表唯一'));
      if not(DetailUniqueJSON is TJSONObject)then Exit(Reject('从表唯一配置不是有效 JSON 对象。'));
      UniqueDetail.StrictDelimiter:=True;UniqueDetail.Delimiter:=';';UniqueDetail.DelimitedText:=S(TJSONObject(DetailUniqueJSON),'cdsMultiSelectFields');
      for I:=UniqueDetail.Count-1 downto 0 do begin V:=FieldPart(Trim(UniqueDetail[I]),DAlias);if V='' then UniqueDetail.Delete(I)else if not Ident(V)or not HasColumn(DC,DAlias,V)then Exit(Reject('从表组合唯一字段必须属于从表。'))else UniqueDetail[I]:=V;end;
      if UniqueDetail.Count=0 then Exit(Reject('请至少配置一个从表组合唯一字段。'));
      for I:=0 to UniqueDetail.Count-1 do begin if UniqueDetailLabel<>'' then UniqueDetailLabel:=UniqueDetailLabel+', ';UniqueDetailLabel:=UniqueDetailLabel+UniqueDetail[I];end;
    end;
    if ApprovalMode then begin
      ApprovalJSON:=TJSONObject.ParseJSONValue(S(Settings,'审批规则'));
      if not(ApprovalJSON is TJSONObject)then Exit(Reject('审核、消审和撤回需要有效的审批规则。'));
      StatusField:=FieldPart(Trim(S(TJSONObject(ApprovalJSON),'cbDataStatus')),MAlias);
      CorrespondingField:=FieldPart(Trim(S(TJSONObject(ApprovalJSON),'cbCorresponding')),MAlias);
      CheckType:=Trim(S(TJSONObject(ApprovalJSON),'cbCheckType'));
      AuditDept:=FieldPart(Trim(S(TJSONObject(ApprovalJSON),'cbAuditDepartment')),MAlias);
      AuditUser:=FieldPart(Trim(S(TJSONObject(ApprovalJSON),'cbAuditUser')),MAlias);
      AuditTime:=FieldPart(Trim(S(TJSONObject(ApprovalJSON),'cbAuditTime')),MAlias);
      RepulseDept:=FieldPart(Trim(S(TJSONObject(ApprovalJSON),'cbRepulseDepartment')),MAlias);
      RepulseUser:=FieldPart(Trim(S(TJSONObject(ApprovalJSON),'cbRepulseUser')),MAlias);
      RepulseTime:=FieldPart(Trim(S(TJSONObject(ApprovalJSON),'cbRepulseTime')),MAlias);
      RepulseRemark:=FieldPart(Trim(S(TJSONObject(ApprovalJSON),'cbRepulseRemark')),MAlias);
      if(CheckType<>'0')and(CheckType<>'1')and(CheckType<>'2')then
        Exit(Reject('mtMasterSlave 审批校验类型须为0（当前部门）、1（UserName校验）或2（下属部门）。'));
      if not Ident(StatusField)or not HasColumn(MC,MAlias,StatusField)then Exit(Reject('审批状态字段必须属于主表。'));
      if not Ident(CorrespondingField)or not HasColumn(MC,MAlias,CorrespondingField)then Exit(Reject('审批对应字段必须属于主表。'));
      if (Trim(S(TJSONObject(ApprovalJSON),'cbAuditDepartment'))<>'')and
        (not Ident(AuditDept)or not HasColumn(MC,MAlias,AuditDept))then Exit(Reject('审批部门字段必须属于主表。'));
      if (Trim(S(TJSONObject(ApprovalJSON),'cbAuditUser'))<>'')and
        (not Ident(AuditUser)or not HasColumn(MC,MAlias,AuditUser))then Exit(Reject('审批用户字段必须属于主表。'));
      if (Trim(S(TJSONObject(ApprovalJSON),'cbAuditTime'))<>'')and
        (not Ident(AuditTime)or not HasColumn(MC,MAlias,AuditTime))then Exit(Reject('审批时间字段必须属于主表。'));
      if (Trim(S(TJSONObject(ApprovalJSON),'cbRepulseDepartment'))<>'')and
        (not Ident(RepulseDept)or not HasColumn(MC,MAlias,RepulseDept))then Exit(Reject('撤回部门字段必须属于主表。'));
      if (Trim(S(TJSONObject(ApprovalJSON),'cbRepulseUser'))<>'')and
        (not Ident(RepulseUser)or not HasColumn(MC,MAlias,RepulseUser))then Exit(Reject('撤回用户字段必须属于主表。'));
      if (Trim(S(TJSONObject(ApprovalJSON),'cbRepulseTime'))<>'')and
        (not Ident(RepulseTime)or not HasColumn(MC,MAlias,RepulseTime))then Exit(Reject('撤回时间字段必须属于主表。'));
      if (Trim(S(TJSONObject(ApprovalJSON),'cbRepulseRemark'))<>'')and
        (not Ident(RepulseRemark)or not HasColumn(MC,MAlias,RepulseRemark))then Exit(Reject('撤回备注字段必须属于主表。'));
    end;
    SQLMain:='select ';for I:=0 to MainFields.Count-1 do begin if I>0 then SQLMain:=SQLMain+', ';SQLMain:=SQLMain+MAlias+'.'+MainFields[I];end;
    if MainFields.IndexOf(MainKey)<0 then SQLMain:=SQLMain+', '+MAlias+'.'+MainKey;
    if MainFields.IndexOf(OrderField)<0 then SQLMain:=SQLMain+', '+MAlias+'.'+OrderField;
    if Yes(S(Settings,'层级权限'))and(MainFields.IndexOf(DeptField)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+DeptField;
    for I:=0 to RequiredMain.Count-1 do if MainFields.IndexOf(RequiredMain[I])<0 then SQLMain:=SQLMain+', '+MAlias+'.'+RequiredMain[I];
    if(CreateDept<>'')and(MainFields.IndexOf(CreateDept)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+CreateDept;
    if(CreateUser<>'')and(MainFields.IndexOf(CreateUser)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+CreateUser;
    if(CreateTime<>'')and(MainFields.IndexOf(CreateTime)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+CreateTime;
    if(EditDept<>'')and(MainFields.IndexOf(EditDept)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+EditDept;
    if(EditUser<>'')and(MainFields.IndexOf(EditUser)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+EditUser;
    if(EditTime<>'')and(MainFields.IndexOf(EditTime)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+EditTime;
    if(EditCount<>'')and(MainFields.IndexOf(EditCount)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+EditCount;
    if(DocumentDate<>'')and(MainFields.IndexOf(DocumentDate)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+DocumentDate;
    if ApprovalMode then begin
      if MainFields.IndexOf(StatusField)<0 then SQLMain:=SQLMain+', '+MAlias+'.'+StatusField;
      if MainFields.IndexOf(CorrespondingField)<0 then SQLMain:=SQLMain+', '+MAlias+'.'+CorrespondingField;
      if (AuditDept<>'')and(MainFields.IndexOf(AuditDept)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+AuditDept;
      if (AuditUser<>'')and(MainFields.IndexOf(AuditUser)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+AuditUser;
      if (AuditTime<>'')and(MainFields.IndexOf(AuditTime)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+AuditTime;
      if (RepulseDept<>'')and(MainFields.IndexOf(RepulseDept)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+RepulseDept;
      if (RepulseUser<>'')and(MainFields.IndexOf(RepulseUser)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+RepulseUser;
      if (RepulseTime<>'')and(MainFields.IndexOf(RepulseTime)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+RepulseTime;
      if (RepulseRemark<>'')and(MainFields.IndexOf(RepulseRemark)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+RepulseRemark;
    end;
    for I:=0 to UniqueMain.Count-1 do if MainFields.IndexOf(UniqueMain[I])<0 then SQLMain:=SQLMain+', '+MAlias+'.'+UniqueMain[I];
    if(AutoField<>'')and(MainFields.IndexOf(AutoField)<0)then SQLMain:=SQLMain+', '+MAlias+'.'+AutoField;
    SQLMain:=SQLMain+' from '+MainTable+' '+MAlias;
    SQLDetail:='select ';for I:=0 to DetailFields.Count-1 do begin if I>0 then SQLDetail:=SQLDetail+', ';SQLDetail:=SQLDetail+DAlias+'.'+DetailFields[I];end;
    if DetailFields.IndexOf(DetailKey)<0 then SQLDetail:=SQLDetail+', '+DAlias+'.'+DetailKey;
    if(DetailLine<>'')and(DetailFields.IndexOf(DetailLine)<0)then SQLDetail:=SQLDetail+', '+DAlias+'.'+DetailLine;
    for I:=0 to CheckDetailFields.Count-1 do if DetailFields.IndexOf(CheckDetailFields[I])<0 then SQLDetail:=SQLDetail+', '+DAlias+'.'+CheckDetailFields[I];
    for I:=0 to RequiredDetail.Count-1 do if DetailFields.IndexOf(RequiredDetail[I])<0 then SQLDetail:=SQLDetail+', '+DAlias+'.'+RequiredDetail[I];
    for I:=0 to UniqueDetail.Count-1 do if DetailFields.IndexOf(UniqueDetail[I])<0 then SQLDetail:=SQLDetail+', '+DAlias+'.'+UniqueDetail[I];
    for JoinIndex:=0 to High(Joins) do
      if SameText(Joins[JoinIndex].ParentAlias,DAlias) then
      for ConditionIndex:=0 to Joins[JoinIndex].KeyCount-1 do begin
        V:=DAlias+'.'+Joins[JoinIndex].BaseKeys[ConditionIndex];
        if Pos(V+',',SQLDetail+',')=0 then SQLDetail:=SQLDetail+', '+V;
      end;
    for I:=0 to JoinFields.Count-1 do SQLDetail:=SQLDetail+', '+JoinFieldAliases[I]+'.'+JoinFields[I]+' as '+JoinFieldAliases[I]+JoinFields[I];
    SQLDetail:=SQLDetail+' from '+DetailTable+' '+DAlias+JoinClause;
    AddCode('//定义全局常量');AddCode('const');AddCode('  cDataNodeName = '+QuotedStr(S(Config,'TWebDataNodeName'))+';');AddCode('  cDataNodeDriver = UGMM.GetNodeNameByDriver(cDataNodeName);');AddCode('  cQueryFrame = '+QuotedStr(QueryFrame)+';');AddCode('');
    AddCode('var');
    AddCode('  vDetailLookupOpening: String;');
    if WriteMode then begin
      AddCode('//定义主从编辑状态');
      AddCode('  vEditing: Boolean;');
      AddCode('  vRequiredFocus: String;');
      AddCode('  vIsNew: Boolean;');
      AddCode('  vEditCountApplied: Boolean;');
      AddCode('  vOriginalKey: Variant;');
      if EditCount<>'' then AddCode('  vOriginalEditCount: Integer;');
      AddCode('');
      AddCode('//保存宿主授予的工具栏按钮权限，避免状态切换时重新放宽按钮');
      for I:=0 to Buttons.Count-1 do
        if Buttons[I]<>'' then
          AddCode('  vPerm'+Copy(Buttons[I],3,Length(Buttons[I]))+': Boolean;');
      AddCode('');
    end;
    if WriteMode then begin
      AddCode('//使用非阻塞SweetAlert显示普通提示，不承担确认或异常控制流');
      AddCode('procedure ShowNotice(const AMessage: string);');
      AddCode('begin');
      AddCode('  noticeAlert.TitleText := UGMM.LT(''提示'');');
      AddCode('  noticeAlert.ConfirmButtonText := UGMM.LT(''确定'');');
      AddCode('  noticeAlert.Show(AMessage);');
      AddCode('end;');AddCode('');
      AddCode('//同步确认：取消、ESC或关闭均不继续业务操作');
      AddCode('function ConfirmAction(const AMessage: string): Boolean;');
      AddCode('begin');
      AddCode('  confirmAlert.TitleText := UGMM.LT(''请确认'');');
      AddCode('  confirmAlert.Text := UGMM.LT(AMessage);');
      AddCode('  confirmAlert.ConfirmButtonText := UGMM.LT(''确定'');');
      AddCode('  confirmAlert.CancelButtonText := UGMM.LT(''取消'');');
      AddCode('  Result := confirmAlert.Execute;');
      AddCode('end;');AddCode('');
      AddCode('//只有确认才回填输入值，取消保留调用方原值');
      AddCode('function InputAction(const APrompt: string; var AValue: string): Boolean;');
      AddCode('begin');
      AddCode('  inputAlert.TitleText := UGMM.LT(''请输入'');');
      AddCode('  inputAlert.Text := UGMM.LT(APrompt);');
      AddCode('  inputAlert.InputValue := AValue;');
      AddCode('  inputAlert.ConfirmButtonText := UGMM.LT(''确定'');');
      AddCode('  inputAlert.CancelButtonText := UGMM.LT(''取消'');');
      AddCode('  Result := inputAlert.Execute;');
      AddCode('  if Result then AValue := inputAlert.InputResult;');
      AddCode('end;');AddCode('');
    end;
    if GridPersonalization then begin
      AddCode('//读取 INI 配置信息');AddCode('function ReadIni(FileName,Section,Ident,Default:String):String;');
      AddCode('var Ini:TIniFile;');AddCode('begin');AddCode('  Ini:=TIniFile.Create(FileName); try Result:=Ini.ReadString(Section,Ident,Default); finally Ini.Free; end;');AddCode('end;');AddCode('');
      AddCode('//写入 INI 配置信息');AddCode('procedure WriteIni(FileName,Section,Ident,Value:String);');
      AddCode('var Ini:TIniFile;');AddCode('begin');AddCode('  Ini:=TIniFile.Create(FileName); try Ini.WriteString(Section,Ident,Value); finally Ini.Free; end;');AddCode('end;');AddCode('');
      AddCode('//保存当前用户的明细表格列宽、顺序和显隐状态');AddCode('procedure SaveGridUserSettings(AGrid:TUgDBGrid;const AName:String);');
      AddCode('var L:TStringList; C:TUniBaseDBGridColumn; Dir,VisibleText:String;');AddCode('begin');AddCode('  L:=TStringList.Create; try');
      for I:=0 to DetailFields.Count+JoinFields.Count-1 do begin
        if I<DetailFields.Count then V:=DetailFields[I] else V:=JoinFieldAliases[I-DetailFields.Count]+JoinFields[I-DetailFields.Count];
        AddCode('    C:=AGrid.ColumnByName('+QuotedStr(V)+'); if C<>nil then begin if C.Visible then VisibleText:=''True'' else VisibleText:=''False''; L.Values['+QuotedStr(V)+']:=IntToStr(C.Index)+'',''+IntToStr(C.Width)+'',''+VisibleText; end;');
      end;
      AddCode('    Dir:=''..\UserSettings\''+Self.Guid+''\''; CheckDirectory(Dir);');
      AddCode('    WriteIni(Dir+UGMM.Informations.Values[''UserName'']+''.ini'',AGrid.ClassName,AName,''v2|''+L.CommaText);');
      AddCode('  finally L.Free; end;');AddCode('end;');AddCode('');
      AddCode('//重新打开模块时恢复当前用户的明细表格设置');AddCode('procedure LoadGridUserSettings(AGrid:TUgDBGrid;const AName:String);');
      AddCode('var L,P,Names,Order:TStringList; C:TUniBaseDBGridColumn; FileName,Stored:String; I,N,Position:Integer;');AddCode('begin');
      AddCode('  FileName:=''..\UserSettings\''+Self.Guid+''\''+UGMM.Informations.Values[''UserName'']+''.ini''; if not FileExists(FileName) then Exit;');
      AddCode('  L:=TStringList.Create; P:=TStringList.Create; Names:=TStringList.Create; Order:=TStringList.Create;');
      AddCode('  try');
      AddCode('    Stored:=ReadIni(FileName,AGrid.ClassName,AName,'''');');
      AddCode('    if Copy(Stored,1,3)=''v2|'' then L.CommaText:=Copy(Stored,4,Length(Stored)) else L.Text:=Stored;');
      // Use current default order only as a fallback for new or unsaved columns.
      for I:=0 to DetailDisplayOrder.Count-1 do begin
        V:=FieldPart(DetailDisplayOrder[I],DAlias);
        if V='' then V:=DetailOutputName(DetailDisplayOrder[I]);
        AddCode('    Names.Add('+QuotedStr(V)+');');
      end;
      AddCode('    for I:=0 to Names.Count-1 do');AddCode('    begin');
      AddCode('      C:=AGrid.ColumnByName(Names[I]); P.CommaText:=L.Values[Names[I]];');
      AddCode('      if (C<>nil) and (P.Count>=3) then');AddCode('      begin');
      if Yes(S(Settings,'字段宽度'))then AddCode('        N:=StrToIntDef(P[1],C.Width); if N>0 then C.Width:=N;');
      if Yes(S(Settings,'字段显隐'))then AddCode('        if SameText(P[2],''True'') or SameText(P[2],''False'') then C.Visible:=SameText(P[2],''True'');');
      AddCode('      end;');AddCode('    end;');
      if Yes(S(Settings,'字段移动'))then begin
        AddCode('    //先按保存位置建立完整顺序，再依次移动，避免列索引互相挤动');
        AddCode('    for Position:=0 to Names.Count-1 do');
        AddCode('      for I:=0 to Names.Count-1 do');AddCode('      begin');
        AddCode('        P.CommaText:=L.Values[Names[I]];');
        AddCode('        if P.Count>=3 then');
        AddCode('          if StrToIntDef(P[0],-1)=Position then Order.Add(Names[I]);');
        AddCode('      end;');
        AddCode('    for I:=0 to Names.Count-1 do if Order.IndexOf(Names[I])<0 then Order.Add(Names[I]);');
        AddCode('    for I:=0 to Order.Count-1 do');AddCode('    begin');
        AddCode('      C:=AGrid.ColumnByName(Order[I]); if C<>nil then C.Index:=I;');AddCode('    end;');
      end;
      AddCode('  finally Order.Free; Names.Free; P.Free; L.Free; end;');AddCode('end;');AddCode('');
      AddCode('//列宽、顺序或显隐变化后立即保存');AddCode('procedure gridDetailedOnAjaxEvent(Sender:TComponent;EventName:String;Params:TUniStrings);');AddCode('begin');
      AddCode('  if EventName in [''columnhide'',''columnshow'',''columnresize'',''columnmove''] then SaveGridUserSettings(TUgDBGrid(Sender),gridDetailed.Name);');
      AddCode('end;');AddCode('');
    end;
    if Yes(S(Settings,'层级权限'))then begin AddCode('//获取当前部门及下级部门');AddCode('function GetSubClassName: string;');AddCode('var L:TStringList;');AddCode('begin');AddCode('  L:=TStringList.Create; try');AddCode('    L.Text:=ReplaceText(UGMM.Informations.Values[''ClassName'']+UGMM.Informations.Values[''SubClassName''],'';'',#13#10);');AddCode('    Result:=''''; while L.Count>0 do begin if Trim(L[0])<>'''' then Result:=Result+iif(Result='''','''','','')+QuotedStr(Trim(L[0])); L.Delete(0); end;');AddCode('    if Result='''' then Result:=QuotedStr(''__NO_DEPARTMENT__''); Result:=''(''+Result+'')'';');AddCode('  finally L.Free; end;');AddCode('end;');AddCode('');end;
    AddCode('//检查单号是否已被后台明细占用，不删除任何遗留数据');
    AddCode('function DetailRecordExists(AKey:Variant):Boolean;');
    AddCode('var C:TUgClientDataSet;');AddCode('begin');
    AddCode('  C:=TUgClientDataSet.Create(nil);');AddCode('  try');
    AddCode('    C.DataNodeName:=cDataNodeName;');
    AddCode('    C.CommandText:='+QuotedStr('select '+DetailKey+' from '+DetailTable+' where '+DetailKey+' = :occupiedKey')+';');
    AddCode('    C.ParamByName(''occupiedKey'').Value:=AKey;');
    AddCode('    C.PageRowCount:=1; C.Open; Result:=not C.IsEmpty;');
    AddCode('  finally C.Free; end;');AddCode('end;');AddCode('');
    if (AutoField<>'')and(SameText(AutoType,'Guid')or SameText(AutoType,'DateTimeRandom'))then begin
      if SameText(AutoType,'Guid')then
        AddCode('//使用宿主原版 GUID 生成器；同时避让主单和遗留明细占号')
      else
        AddCode('//原版 DateTimeRandom：毫秒时间戳加不补零的随机数；避让主从占号');
      AddCode('function GetAutoNumber:String;');
      if SameText(AutoType,'DateTimeRandom')then begin
        AddCode('const');
        AddCode('  cPrefix='+QuotedStr(AutoPrefix)+';');
        AddCode('  cDigitCapacity='+QuotedStr(AutoDigits)+';');
        AddCode('  cSuffix='+QuotedStr(AutoSuffix)+';');
      end;
      AddCode('var');
      AddCode('  C:TUgClientDataSet;');
      AddCode('  Attempt:Integer;');
      AddCode('begin');
      AddCode('  if not (cdsMain.FieldByName('+QuotedStr(AutoField)+').DataType in');
      AddCode('    [ftString,ftWideString,ftFixedChar]) then');
      AddCode('    RaiseException(''自动编号需要字符串字段。'');');
      AddCode('  if not (cdsDetailed.FieldByName('+QuotedStr(DetailKey)+').DataType in');
      AddCode('    [ftString,ftWideString,ftFixedChar]) then');
      AddCode('    RaiseException(''自动编号的明细关联字段需要字符串类型。'');');
      AddCode('  C:=TUgClientDataSet.Create(nil);');
      AddCode('  try');
      AddCode('    C.DataNodeName:=cDataNodeName;');
      AddCode('    C.PageRowCount:=1;');
      AddCode('    for Attempt:=1 to 10 do');
      AddCode('    begin');
      if SameText(AutoType,'Guid')then AddCode('      Result:=UGMM.CreateGuid;')
      else AddCode('      Result:=cPrefix+FormatDateTime(''yyyyMMddhhmmsszzz'',Now)+IntToStr(RandomInt('+StringOfChar('9',StrToInt(AutoDigits))+'))+cSuffix;');
      AddCode('      if Trim(Result)='''' then RaiseException(''生成器返回空编号。'');');
      AddCode('      if (cdsMain.FieldByName('+QuotedStr(AutoField)+').Size>0) and');
      AddCode('        (Length(Result)>cdsMain.FieldByName('+QuotedStr(AutoField)+').Size) then');
      AddCode('        RaiseException(''自动编号超过字段长度，请调整字段长度后重试。'');');
      AddCode('      if (cdsDetailed.FieldByName('+QuotedStr(DetailKey)+').Size>0) and');
      AddCode('        (Length(Result)>cdsDetailed.FieldByName('+QuotedStr(DetailKey)+').Size) then');
      AddCode('        RaiseException(''自动编号超过明细关联字段长度，请调整后重试。'');');
      AddCode('      C.Close;');
      AddCode('      C.CommandText:='+QuotedStr('select '+MainKey+' from '+MainTable+' where '+MainKey+' = :occupiedKey')+';');
      AddCode('      C.ParamByName(''occupiedKey'').Value:=Result;');
      AddCode('      C.Open;');
      AddCode('      if C.IsEmpty and (not DetailRecordExists(Result)) then Exit;');
      AddCode('    end;');
      AddCode('    RaiseException(''自动编号连续占号，请检查编号生成器后重试。'');');
      AddCode('  finally');
      AddCode('    C.Free;');
      AddCode('  end;');
      AddCode('end;');
      AddCode('');
    end else if AutoField<>'' then begin
      AddCode('//按原版 MaxCode 规则取得下一张主单编号');AddCode('function GetAutoNumber:String;');AddCode('const');
      AddCode('  cPrefix='+QuotedStr(AutoPrefix)+';');AddCode('  cDigitCapacity='+QuotedStr(AutoDigits)+';');AddCode('  cSuffix='+QuotedStr(AutoSuffix)+';');
      AddCode('var C:TUgClientDataSet; N:Integer;');AddCode('begin');AddCode('  C:=TUgClientDataSet.Create(nil); try');AddCode('    C.DataNodeName:=cDataNodeName;');
      AddCode('    C.CommandText:='+QuotedStr('select max('+MAlias+'.'+AutoField+') as AutoCode from '+MainTable+' '+MAlias)+'; C.Open;');
      AddCode('    N:=0; if not C.IsEmpty then N:=StrToIntDef(ReplaceText(ReplaceText(C.FieldByName(''AutoCode'').AsString,cPrefix,''''),cSuffix,''''),0);');
      AddCode('    if N>=2147483647 then RaiseException(''自动编号超出范围，请检查编号配置。'');');
      AddCode('    Result:=cPrefix+Format('+QuotedStr('%.'+AutoDigits+'d')+',[N+1])+cSuffix;');
      if SameText(AutoField,MainKey) then begin
        AddCode('    //主表删除后仍可能有旧明细，跳过两表中任一已占用的候选号');
        AddCode('    while True do');AddCode('    begin');
        AddCode('      C.Close;');
        AddCode('      C.CommandText:='+QuotedStr('select '+MainKey+' from '+MainTable+' where '+MainKey+' = :occupiedKey')+';');
        AddCode('      C.ParamByName(''occupiedKey'').Value:=Result;');
        AddCode('      C.PageRowCount:=1; C.Open;');
        AddCode('      if C.IsEmpty and (not DetailRecordExists(Result)) then Break;');
        AddCode('      if N>=2147483646 then RaiseException(''自动编号超出范围，请检查编号配置。'');');
        AddCode('      Inc(N);');
        AddCode('      Result:=cPrefix+Format('+QuotedStr('%.'+AutoDigits+'d')+',[N+1])+cSuffix;');
        AddCode('    end;');
      end;
      AddCode('  finally C.Free; end;');AddCode('end;');AddCode('');
    end;
    if UniqueMain.Count>0 then begin
      AddCode('//检查后台主表组合唯一值，修改时排除当前主单');AddCode('procedure CheckMainUnique;');AddCode('var C:TUgClientDataSet; SQL,FieldValues:String;');AddCode('begin');
      AddCode('  FieldValues:='''';');
      for I:=0 to UniqueMain.Count-1 do AddCode('  if FieldValues<>'''' then FieldValues:=FieldValues+'+QuotedStr(', ')+'; FieldValues:=FieldValues+'+QuotedStr(UniqueMain[I]+'=')+'+VarToStr(cdsMain.FieldByName('+QuotedStr(UniqueMain[I])+').AsVariant);');
      AddCode('  SQL:='+QuotedStr('select '+MAlias+'.'+UniqueRecordField+' from '+MainTable+' '+MAlias+' where 1 = 1')+';');
      for I:=0 to UniqueMain.Count-1 do begin
        AddCode('  if cdsMain.FieldByName('+QuotedStr(UniqueMain[I])+').IsNull or(Trim(VarToStr(cdsMain.FieldByName('+QuotedStr(UniqueMain[I])+').AsVariant))='''') then SQL:=SQL+'+QuotedStr(' and '+MAlias+'.'+UniqueMain[I]+' is null')+' else SQL:=SQL+'+QuotedStr(' and '+MAlias+'.'+UniqueMain[I]+' = :mainUnique'+IntToStr(I))+';');
      end;
      AddCode('  if not vIsNew then SQL:=SQL+'+QuotedStr(' and '+MAlias+'.'+UniqueRecordField+' <> :mainUniqueOld')+';');
      AddCode('  C:=TUgClientDataSet.Create(nil); try C.DataNodeName:=cDataNodeName; C.CommandText:=SQL;');
      for I:=0 to UniqueMain.Count-1 do AddCode('    if (not cdsMain.FieldByName('+QuotedStr(UniqueMain[I])+').IsNull)and(Trim(VarToStr(cdsMain.FieldByName('+QuotedStr(UniqueMain[I])+').AsVariant))<>'''')then C.ParamByName(''mainUnique'+IntToStr(I)+''').Value:=cdsMain.FieldByName('+QuotedStr(UniqueMain[I])+').AsVariant;');
      AddCode('    if not vIsNew then C.ParamByName(''mainUniqueOld'').Value:=vOriginalKey;');
      AddCode('    C.Open; if not C.IsEmpty then RaiseException(''保存失败：主表组合唯一字段 [''+FieldValues+''] 已存在，请修改后重试！'');');AddCode('  finally C.Free; end;');AddCode('end;');AddCode('');
    end;
    if WriteMode and(EditCount<>'')then begin
      AddCode('//读取后台主单版本；用于修改、保存和删除前的并发复核');AddCode('function ReadCurrentEditCount(const AKey:Variant;var AExists:Boolean):Integer;');
      AddCode('var C:TUgClientDataSet;');AddCode('begin');AddCode('  Result:=0; AExists:=False; C:=TUgClientDataSet.Create(nil); try');
      AddCode('    C.DataNodeName:=cDataNodeName; C.CommandText:='+QuotedStr('select '+MAlias+'.'+EditCount+' from '+MainTable+' '+MAlias+' where '+MAlias+'.'+MainKey+' = :versionKey')+';');
      AddCode('    C.ParamByName(''versionKey'').Value:=AKey; C.PageRowCount:=1; C.Open; AExists:=not C.IsEmpty;');
      AddCode('    if AExists then Result:=C.FieldByName('+QuotedStr(EditCount)+').AsInteger;');AddCode('  finally C.Free; end;');AddCode('end;');AddCode('');
      AddCode('//发现并发删除或修改时中止操作，并保留当前编辑内容');AddCode('procedure CheckCurrentVersion;');AddCode('var Exists:Boolean; CurrentVersion:Integer;');AddCode('begin');
      AddCode('  CurrentVersion:=ReadCurrentEditCount(vOriginalKey,Exists);');
      AddCode('  if not Exists then RaiseException(''当前主单已被其他用户删除，请撤销后重新查询。'');');
      AddCode('  if CurrentVersion<>vOriginalEditCount then RaiseException(''当前主单已被其他用户修改，请撤销后重新查询。'');');AddCode('end;');AddCode('');
    end;
    if WriteMode then begin
      AddCode('//确认主单是否仍存在；用于识别 SQLite 提交后伪回滚错误');AddCode('function MainRecordExists(const AKey:Variant):Boolean;');
      AddCode('var C:TUgClientDataSet;');AddCode('begin');AddCode('  C:=TUgClientDataSet.Create(nil); try C.DataNodeName:=cDataNodeName;');
      AddCode('    C.CommandText:='+QuotedStr('select '+MAlias+'.'+MainKey+' from '+MainTable+' '+MAlias+' where '+MAlias+'.'+MainKey+' = :existsKey')+'; C.ParamByName(''existsKey'').Value:=AKey; C.PageRowCount:=1; C.Open; Result:=not C.IsEmpty;');
      AddCode('  finally C.Free; end;');AddCode('end;');AddCode('');
    end;
    if WriteMode then begin
      AddCode('//只在初始化时读取一次宿主按钮权限');
      AddCode('procedure CaptureButtonPermissions;');
      AddCode('begin');
      AddCode('  Self.IsEditor := False;');
      AddCode('  UGMM.VerifyRunFramePerm(Self);');
      for I:=0 to Buttons.Count-1 do
        if Buttons[I]<>'' then
          AddCode('  vPerm'+Copy(Buttons[I],3,Length(Buttons[I]))+' := '+Buttons[I]+'.Enabled;');
      AddCode('end;');
      AddCode('');

      AddCode('//按原版业务规则和初始化时保存的宿主权限刷新工具栏状态');
      AddCode('procedure SetEditState(AEditing: Boolean);');
      AddCode('var');
      AddCode('  HasRecord: Boolean;');
      if ApprovalMode then AddCode('  ApprovalStatus: String;');
      AddCode('begin');
      AddCode('  vEditing := AEditing;');
      AddCode('  if AEditing then');
      AddCode('  begin');
      for I:=0 to DetailFields.Count-1 do if IsLookupType(DetailTypes[I])then begin
        DropValue:=TJSONObject.ParseJSONValue(DetailOptions[I]);
        try
          AddCode('    lookupDetail'+DetailFields[I]+'.Close;');
          AddCode('    lookupDetail'+DetailFields[I]+'.Filtered := False;');
          AddCode('    lookupDetail'+DetailFields[I]+'.Filter := '''';');
          AddCode('    lookupDetail'+DetailFields[I]+'.DataNodeName := cDataNodeName;');
          AddCode('    lookupDetail'+DetailFields[I]+'.CommandText := '+QuotedStr(LookupSQL(TJSONObject(DropValue)))+';');
          AddCode('    lookupDetail'+DetailFields[I]+'.Open;');
        finally FreeAndNil(DropValue);end;
      end;
      AddCode('  end;');
      AddCode('  HasRecord := cdsMain.Active and (not cdsMain.IsEmpty);');
      if ApprovalMode then begin
        AddCode('  ApprovalStatus := '''';');
        AddCode('  if HasRecord then');
        AddCode('    ApprovalStatus := Trim(cdsMain.FieldByName('+QuotedStr(StatusField)+').AsString);');
      end;
      AddCode('  dsMain.AutoEdit:=AEditing; dsDetailed.AutoEdit:=AEditing; gridDetailed.ReadOnly:=not AEditing;');
      for I:=0 to MainFields.Count-1 do
        if SameText(MainFields[I],CreateDept)or SameText(MainFields[I],CreateUser)or SameText(MainFields[I],CreateTime)or
          SameText(MainFields[I],EditDept)or SameText(MainFields[I],EditUser)or SameText(MainFields[I],EditTime)or SameText(MainFields[I],EditCount)or
          (ApprovalMode and(SameText(MainFields[I],StatusField)or SameText(MainFields[I],AuditDept)or SameText(MainFields[I],AuditUser)or SameText(MainFields[I],AuditTime)or SameText(MainFields[I],RepulseDept)or SameText(MainFields[I],RepulseUser)or SameText(MainFields[I],RepulseTime)or SameText(MainFields[I],RepulseRemark)))then
          AddCode('  a'+MainFields[I]+'.ReadOnly:=True;')
        else if SameText(MainFields[I],MainKey)then AddCode('  a'+MainFields[I]+'.ReadOnly:=(not AEditing)or(not vIsNew);')
        else AddCode('  a'+MainFields[I]+'.ReadOnly:=not AEditing;');
      if Buttons.IndexOf('btQuery')>=0 then AddCode('  btQuery.Enabled := vPermQuery and (not AEditing);');
      if Buttons.IndexOf('btFirst')>=0 then AddCode('  btFirst.Enabled := vPermFirst and (not AEditing) and HasRecord;');
      if Buttons.IndexOf('btPrior')>=0 then AddCode('  btPrior.Enabled := vPermPrior and (not AEditing) and HasRecord;');
      if Buttons.IndexOf('btNext')>=0 then AddCode('  btNext.Enabled := vPermNext and (not AEditing) and HasRecord;');
      if Buttons.IndexOf('btLast')>=0 then AddCode('  btLast.Enabled := vPermLast and (not AEditing) and HasRecord;');
      if Buttons.IndexOf('btClose')>=0 then AddCode('  btClose.Enabled := vPermClose and (not AEditing);');
      if Buttons.IndexOf('btImport')>=0 then AddCode('  btImport.Enabled := vPermImport and AEditing;');
      if Buttons.IndexOf('btPrint')>=0 then AddCode('  btPrint.Enabled := vPermPrint and (not AEditing) and HasRecord;');
      if Buttons.IndexOf('btAnnex')>=0 then AddCode('  btAnnex.Enabled := vPermAnnex and (not AEditing) and HasRecord;');
      { 明细区行按钮（目录项 'Detail Row Group'）：只在编辑态可用；需要"有当前行"的按钮再看 IsEmpty，
        上移/下移再看是否到边界（宿主 2026-09-21 要求与 mtListEditor 一致）。 }
      if Buttons.IndexOf('btDetailAppend')>=0 then AddCode('  btDetailAppend.Enabled := AEditing;');
      if Buttons.IndexOf('btDetailInsert')>=0 then AddCode('  btDetailInsert.Enabled := AEditing;');
      if Buttons.IndexOf('btDetailDelete')>=0 then AddCode('  btDetailDelete.Enabled := AEditing and cdsDetailed.Active and (not cdsDetailed.IsEmpty);');
      if Buttons.IndexOf('btDetailCopy')>=0 then AddCode('  btDetailCopy.Enabled := AEditing and cdsDetailed.Active and (not cdsDetailed.IsEmpty);');
      if Buttons.IndexOf('btDetailMoveUp')>=0 then AddCode('  btDetailMoveUp.Enabled := AEditing and cdsDetailed.Active and (not cdsDetailed.IsEmpty) and (not cdsDetailed.Bof);');
      if Buttons.IndexOf('btDetailMoveDown')>=0 then AddCode('  btDetailMoveDown.Enabled := AEditing and cdsDetailed.Active and (not cdsDetailed.IsEmpty) and (not cdsDetailed.Eof);');
      if Buttons.IndexOf('btDetailClear')>=0 then AddCode('  btDetailClear.Enabled := AEditing and cdsDetailed.Active and (not cdsDetailed.IsEmpty);');
      if Buttons.IndexOf('btAppend')>=0 then AddCode('  btAppend.Enabled := vPermAppend and (not AEditing);');
      if ApprovalMode then begin
        if Buttons.IndexOf('btEditor')>=0 then begin
        AddCode('  btEditor.Enabled := vPermEditor and (not AEditing) and HasRecord and');
        AddCode('    (SameText(ApprovalStatus, ''PendingReview'') or SameText(ApprovalStatus, ''Returned''));');
        end;
        if Buttons.IndexOf('btDelete')>=0 then begin
        AddCode('  btDelete.Enabled := vPermDelete and (not AEditing) and HasRecord and');
        AddCode('    (SameText(ApprovalStatus, ''PendingReview'') or SameText(ApprovalStatus, ''Returned''));');
        end;
        if Buttons.IndexOf('btAudit')>=0 then begin
        AddCode('  btAudit.Enabled := vPermAudit and (not AEditing) and HasRecord and');
        AddCode('    SameText(ApprovalStatus, ''PendingReview'');');
        end;
        if Buttons.IndexOf('btUnAudit')>=0 then begin
        AddCode('  btUnAudit.Enabled := vPermUnAudit and (not AEditing) and HasRecord and');
        AddCode('    SameText(ApprovalStatus, ''Reviewed'');');
        end;
        if Buttons.IndexOf('btRepulse')>=0 then begin
        AddCode('  btRepulse.Enabled := vPermRepulse and (not AEditing) and HasRecord and');
        AddCode('    SameText(ApprovalStatus, ''PendingReview'');');
        end;
      end else begin
        if Buttons.IndexOf('btEditor')>=0 then AddCode('  btEditor.Enabled := vPermEditor and (not AEditing) and HasRecord;');
        if Buttons.IndexOf('btDelete')>=0 then AddCode('  btDelete.Enabled := vPermDelete and (not AEditing) and HasRecord;');
      end;
      if Buttons.IndexOf('btSave')>=0 then AddCode('  btSave.Enabled := vPermSave and (AEditing or (cdsMain.ChangeCount > 0));');
      if Buttons.IndexOf('btCancel')>=0 then AddCode('  btCancel.Enabled := vPermCancel and (AEditing or (cdsMain.ChangeCount > 0));');
      AddCode('');
      AddCode('  Self.IsEditor := AEditing or (cdsMain.ChangeCount > 0);');
      AddCode('end;');
      AddCode('');
    end;
    AddCode('//纯时间显示；数据库字段须为时间或日期时间，不能绑定数值计数器');
    AddCode('procedure ConfigureTimeFields;');
    AddCode('begin');
    for I:=0 to MainFields.Count-1 do
      if MainTypes[I]='time' then begin
        AddCode('  if not (cdsMain.FieldByName('+QuotedStr(MainFields[I])+') is TDateTimeField) then');
        AddCode('    RaiseException('+QuotedStr('time 控件需要时间或日期时间字段：'+MainFields[I])+');');
        AddCode('  TDateTimeField(cdsMain.FieldByName('+QuotedStr(MainFields[I])+')).DisplayFormat := ''hh:nn:ss'';');
      end;
    for I:=0 to DetailFields.Count-1 do
      if DetailTypes[I]='time' then begin
        AddCode('  if not (cdsDetailed.FieldByName('+QuotedStr(DetailFields[I])+') is TDateTimeField) then');
        AddCode('    RaiseException('+QuotedStr('明细 time 控件需要时间或日期时间字段：'+DetailFields[I])+');');
        AddCode('  TDateTimeField(cdsDetailed.FieldByName('+QuotedStr(DetailFields[I])+')).DisplayFormat := ''hh:nn:ss'';');
      end;
    AddCode('end;');
    AddCode('');
    if JoinTable<>'' then begin
      AddCode('//拒绝关联键重复，避免一条明细被展开为多行后重复写回');
      AddCode('procedure CheckDetailJoin;');AddCode('var C:TUgClientDataSet;');AddCode('begin');
      AddCode('  C:=TUgClientDataSet.Create(nil);');AddCode('  try');
      AddCode('    C.DataNodeName:=cDataNodeName; C.PageRowCount:=1;');
      for JoinIndex:=0 to High(Joins) do begin
        JoinTable:=Joins[JoinIndex].TableName;
        JoinColumns:='';JoinFilter:='';
        for ConditionIndex:=0 to Joins[JoinIndex].KeyCount-1 do begin
          JoinOtherKey:=Joins[JoinIndex].OtherKeys[ConditionIndex];
          if JoinColumns<>'' then begin JoinColumns:=JoinColumns+',';JoinFilter:=JoinFilter+' and ';end;
          JoinColumns:=JoinColumns+JoinOtherKey;
          JoinFilter:=JoinFilter+JoinOtherKey+' is not null';
        end;
        AddCode('    C.Close;');
        AddCode('    C.CommandText:='+QuotedStr('select '+JoinColumns+' from '+JoinTable+' where '+JoinFilter+' group by '+JoinColumns+' having count(*) > 1')+';');
        AddCode('    C.Open;');
        AddCode('    if not C.IsEmpty then RaiseException('+QuotedStr('关联表 ['+JoinTable+' / '+Joins[JoinIndex].AliasName+'] 匹配字段 ['+JoinColumns+'] 存在重复，请先检查关联数据。')+');');
      end;
      AddCode('  finally C.Free; end;');AddCode('end;');AddCode('');
    end;
    if WriteMode and (JoinFields.Count>0) and HasChain then begin
      AddCode('//基础关联键变化后按完整LEFT JOIN链回显；不移动或重开明细数据集');
      AddCode('procedure DetailJoinKeyChanged(Sender: TObject; Field:TField);');
      AddCode('var C:TUgClientDataSet; F:TField; WasReadOnly:Boolean;');
      AddCode('begin');AddCode('  if Field=nil then Exit;');
      V:='';
      for I:=0 to RootKeys.Count-1 do begin
        if V<>'' then V:=V+' and ';
        V:=V+'(Field.FieldName<>'+QuotedStr(RootKeys[I])+')';
      end;
      AddCode('  if '+V+' then Exit;');
      AddCode('  if not (cdsDetailed.State in [dsEdit,dsInsert]) then Exit;');
      AddCode('  C:=TUgClientDataSet.Create(nil);');AddCode('  try');
      AddCode('    C.DataNodeName:=cDataNodeName;');AddCode('    C.PageRowCount:=2;');
      V:='select ';
      for I:=0 to JoinFields.Count-1 do begin
        if I>0 then V:=V+', ';
        V:=V+JoinFieldAliases[I]+'.'+JoinFields[I]+' as '+JoinFieldAliases[I]+JoinFields[I];
      end;
      V:=V+' from (select ';
      for I:=0 to RootKeys.Count-1 do begin
        if I>0 then V:=V+', ';
        V:=V+':chainKey'+IntToStr(I)+' as '+RootKeys[I];
      end;
      V:=V+') '+DAlias+JoinClause;
      AddCode('    C.CommandText:='+QuotedStr(V)+';');
      for I:=0 to RootKeys.Count-1 do begin
        AddCode('    if Trim(cdsDetailed.FieldByName('+QuotedStr(RootKeys[I])+').AsString)='''' then');
        AddCode('      C.ParamByName('+QuotedStr('chainKey'+IntToStr(I))+').Value:=Null');
        AddCode('    else C.ParamByName('+QuotedStr('chainKey'+IntToStr(I))+').Value:=cdsDetailed.FieldByName('+QuotedStr(RootKeys[I])+').AsVariant;');
      end;
      AddCode('    C.Open;');AddCode('    if C.RecordCount>1 then');
      AddCode('      RaiseException(''关联链存在多个匹配结果，请检查各关联表的组合匹配字段。'');');
      for I:=0 to JoinFields.Count-1 do begin
        V:=QuotedStr(JoinFieldAliases[I]+JoinFields[I]);
        AddCode('    F:=cdsDetailed.FieldByName('+V+');');
        AddCode('    WasReadOnly:=F.ReadOnly; F.ReadOnly:=False;');
        AddCode('    try');AddCode('      if C.IsEmpty then F.AsVariant:=Null');
        AddCode('      else F.AsVariant:=C.FieldByName('+V+').AsVariant;');
        AddCode('    finally F.ReadOnly:=WasReadOnly; end;');
      end;
      AddCode('  finally C.Free; end;');AddCode('end;');AddCode('');
    end;
    if WriteMode and (JoinFields.Count>0) and not HasChain then begin
      AddCode('//物料关联键提交到当前行时回显，只更新内存关联列，不移动明细游标');
      AddCode('procedure DetailJoinKeyChanged(Sender: TObject; Field:TField);');
      AddCode('var C:TUgClientDataSet; F:TField; WasReadOnly:Boolean;');
      AddCode('begin');
      AddCode('  if Field=nil then Exit;');
      V:='';
      for JoinIndex:=0 to High(Joins) do
      for ConditionIndex:=0 to Joins[JoinIndex].KeyCount-1 do begin
        if V<>'' then V:=V+' and ';
        V:=V+'(Field.FieldName<>'+QuotedStr(Joins[JoinIndex].BaseKeys[ConditionIndex])+')';
      end;
      AddCode('  if '+V+' then Exit;');
      AddCode('  if not (cdsDetailed.State in [dsEdit,dsInsert]) then Exit;');
      AddCode('  C:=TUgClientDataSet.Create(nil);');
      AddCode('  try');
      AddCode('    C.DataNodeName:=cDataNodeName;');
      AddCode('    C.PageRowCount:=2;');
      for JoinIndex:=0 to High(Joins) do begin
      JoinAlias:=Joins[JoinIndex].AliasName;
      V:='';
      for I:=0 to JoinFields.Count-1 do
        if SameText(JoinFieldAliases[I],JoinAlias) then begin
          if V<>'' then V:=V+',';
          V:=V+JoinFields[I];
        end;
      if V='' then Continue;
      JoinTrigger:='';JoinReady:='';JoinFilter:='';
      for ConditionIndex:=0 to Joins[JoinIndex].KeyCount-1 do begin
        if JoinTrigger<>'' then begin JoinTrigger:=JoinTrigger+' or ';JoinReady:=JoinReady+' and ';JoinFilter:=JoinFilter+' and ';end;
        JoinBaseKey:=Joins[JoinIndex].BaseKeys[ConditionIndex];
        JoinTrigger:=JoinTrigger+'(Field.FieldName='+QuotedStr(JoinBaseKey)+')';
        JoinReady:=JoinReady+'(Trim(cdsDetailed.FieldByName('+QuotedStr(JoinBaseKey)+').AsString)<>'''')';
        JoinParam:='joinValue';if ConditionIndex>0 then JoinParam:=JoinParam+IntToStr(ConditionIndex+1);
        JoinFilter:=JoinFilter+Joins[JoinIndex].OtherKeys[ConditionIndex]+' = :'+JoinParam;
      end;
      AddCode('    if '+JoinTrigger+' then');
      AddCode('    begin');
      AddCode('    C.Close;');
      V:='select '+V+' from '+Joins[JoinIndex].TableName+' where '+JoinFilter;
      AddCode('    C.CommandText:='+QuotedStr(V)+';');
      for ConditionIndex:=0 to Joins[JoinIndex].KeyCount-1 do begin
        JoinParam:='joinValue';if ConditionIndex>0 then JoinParam:=JoinParam+IntToStr(ConditionIndex+1);
        AddCode('    C.ParamByName('+QuotedStr(JoinParam)+').Value:=cdsDetailed.FieldByName('+QuotedStr(Joins[JoinIndex].BaseKeys[ConditionIndex])+').AsVariant;');
      end;
      AddCode('    if '+JoinReady+' then');
      AddCode('    begin');
      AddCode('      C.Open;');
      AddCode('      if C.RecordCount>1 then');
      AddCode('        RaiseException(''关联字段存在多个匹配记录，请检查关联数据。'');');
      AddCode('    end;');
      for I:=0 to JoinFields.Count-1 do if SameText(JoinFieldAliases[I],JoinAlias) then begin
        AddCode('    F:=cdsDetailed.FieldByName('+QuotedStr(JoinFieldAliases[I]+JoinFields[I])+');');
        AddCode('    WasReadOnly:=F.ReadOnly;');
        AddCode('    F.ReadOnly:=False;');
        AddCode('    try');
        AddCode('      if not C.Active then F.AsVariant:=Null');
        AddCode('      else if C.IsEmpty then F.AsVariant:=Null');
        AddCode('      else F.AsVariant:=C.FieldByName('+QuotedStr(JoinFields[I])+').AsVariant;');
        AddCode('    finally F.ReadOnly:=WasReadOnly; end;');
      end;
      AddCode('    end;');
      end;
      AddCode('  finally C.Free; end;');
      AddCode('end;');AddCode('');
    end;
    AddCode('//按关联字段打开主单和明细');AddCode('procedure OpenRecord(const AKey: Variant);');AddCode('var SQL:String;');AddCode('begin');
    if JoinTable<>'' then AddCode('  CheckDetailJoin;');
    AddCode('  cdsMain.Close; SQL := '+QuotedStr(SQLMain+' where '+MAlias+'.'+MainKey+' = :masterKey')+';');
    if Yes(S(Settings,'层级权限'))then AddCode('  SQL:=SQL+'+QuotedStr(' and '+MAlias+'.'+DeptField+' in ')+'+GetSubClassName;');
    AddCode('  cdsMain.CommandText:=SQL; cdsMain.ParamByName(''masterKey'').Value:=AKey; cdsMain.Open;');
    AddCode('  cdsDetailed.Close;');
    if WriteMode then AddCode('  if cdsMain.IsEmpty then begin vIsNew:=False; vEditCountApplied:=False; SetEditState(False); Exit; end;')
    else AddCode('  if cdsMain.IsEmpty then Exit;');
    if DetailLine<>'' then begin
      AddCode('  cdsDetailed.CommandText := '+QuotedStr(SQLDetail+' where '+DAlias+'.'+DetailKey+' = :detailKey order by '+DAlias+'.'+DetailLine)+';');
      AddCode('  cdsDetailed.ParamByName(''detailKey'').Value:=AKey; cdsDetailed.Open; cdsDetailed.IndexFieldNames:='+QuotedStr(DetailLine)+';');
    end else begin
      AddCode('  cdsDetailed.CommandText := '+QuotedStr(SQLDetail+' where '+DAlias+'.'+DetailKey+' = :detailKey')+';');
      AddCode('  cdsDetailed.ParamByName(''detailKey'').Value:=AKey; cdsDetailed.Open;');
    end;
    AddCode('  ConfigureTimeFields;');
    if WriteMode then begin AddCode('  vIsNew:=False; vEditCountApplied:=False; vOriginalKey:=AKey;');if EditCount<>'' then AddCode('  vOriginalEditCount:=cdsMain.FieldByName('+QuotedStr(EditCount)+').AsInteger;');AddCode('  SetEditState(False);');end;
    AddCode('end;');AddCode('');
    if WriteMode and(EditCount<>'')then begin
      AddCode('//浏览状态操作没有待保存内容；发现并发变化时立即重载数据库最新状态');AddCode('procedure CheckBrowseVersion;');
      AddCode('var Exists:Boolean; CurrentVersion:Integer; CurrentKey:Variant;');AddCode('begin');
      AddCode('  CurrentKey:=vOriginalKey; CurrentVersion:=ReadCurrentEditCount(CurrentKey,Exists);');
      AddCode('  if not Exists then begin OpenRecord(CurrentKey); RaiseException(''当前主单已被其他用户删除，界面已刷新。''); end;');
      AddCode('  if CurrentVersion<>vOriginalEditCount then begin OpenRecord(CurrentKey); RaiseException(''当前主单已被其他用户修改，界面已刷新。''); end;');
      AddCode('end;');AddCode('');
    end;
    if Buttons.IndexOf('btQuery')>=0 then begin
    AddCode('//查询窗体选择主单');AddCode('procedure btQueryOnClick(Sender: TObject);');AddCode('var F:TUniForm; D:TClientDataSet;');AddCode('begin');
    if WriteMode then AddCode('  if vEditing then RaiseException(''有未保存数据，请先保存或撤销。'');');
    AddCode('  F:=UGMM.GetWebSubForm(cQueryFrame);');AddCode('  if F=nil then RaiseException(''无法打开查询窗体。'');');AddCode('  F.Caption:=UGMM.LT(cQueryFrame);');AddCode('  if F.ShowModal=mrOk then begin D:=TClientDataSet(TUgWebForm(F).RunFrame.FindComponent(''cdsMain'')); if(D<>nil)and(not D.IsEmpty)then OpenRecord(D.FieldByName('+QuotedStr(MainKey)+').AsVariant); end;');AddCode('end;');AddCode('');
    end;
    AddCode('//首笔、前笔、后笔、末笔导航');AddCode('procedure NavigateRecord(ADirection:Integer);');AddCode('var C:TUgClientDataSet; SQL:String;');AddCode('begin');
    if WriteMode then AddCode('  if vEditing then RaiseException(''有未保存数据，请先保存或撤销。'');');
    AddCode('  C:=TUgClientDataSet.Create(nil); try C.DataNodeName:=cDataNodeName; SQL:='+QuotedStr('select '+MAlias+'.'+MainKey+', '+MAlias+'.'+OrderField+' from '+MainTable+' '+MAlias+' where 1 = 1')+';');
    if Yes(S(Settings,'层级权限'))then AddCode('    SQL:=SQL+'+QuotedStr(' and '+MAlias+'.'+DeptField+' in ')+'+GetSubClassName;');
    AddCode('    if(ADirection=2)and cdsMain.Active and(not cdsMain.IsEmpty)then SQL:=SQL+'+QuotedStr(' and '+MAlias+'.'+OrderField+' < :nav order by '+MAlias+'.'+OrderField+' desc')+' else');AddCode('    if(ADirection=3)and cdsMain.Active and(not cdsMain.IsEmpty)then SQL:=SQL+'+QuotedStr(' and '+MAlias+'.'+OrderField+' > :nav order by '+MAlias+'.'+OrderField)+' else');AddCode('    if ADirection=4 then SQL:=SQL+'+QuotedStr(' order by '+MAlias+'.'+OrderField+' desc')+' else SQL:=SQL+'+QuotedStr(' order by '+MAlias+'.'+OrderField)+';');AddCode('    C.CommandText:=SQL; C.PageRowCount:=1;');AddCode('    if ((ADirection=2)or(ADirection=3)) and cdsMain.Active and(not cdsMain.IsEmpty) then C.ParamByName(''nav'').Value:=cdsMain.FieldByName('+QuotedStr(OrderField)+').AsVariant;');AddCode('    C.Open; if not C.IsEmpty then OpenRecord(C.FieldByName('+QuotedStr(MainKey)+').AsVariant) else');
    if WriteMode then AddCode('    if (ADirection=1)or(ADirection=4) then begin cdsDetailed.Close; cdsMain.Close; SetEditState(False); end;')
    else AddCode('    if (ADirection=1)or(ADirection=4) then begin cdsDetailed.Close; cdsMain.Close; end;');
    AddCode('  finally C.Free; end;');AddCode('end;');AddCode('');
    AddCode('procedure btFirstOnClick(Sender: TObject); begin NavigateRecord(1); end;');AddCode('procedure btPriorOnClick(Sender: TObject); begin NavigateRecord(2); end;');AddCode('procedure btNextOnClick(Sender: TObject); begin NavigateRecord(3); end;');AddCode('procedure btLastOnClick(Sender: TObject); begin NavigateRecord(4); end;');AddCode('');
    if WriteMode then begin
      AddCode('//判断当前明细行是否包含业务数据');AddCode('function DetailRowHasData:Boolean;');AddCode('begin');AddCode('  Result:=False;');
      for I:=0 to DetailFields.Count-1 do if(not SameText(DetailFields[I],DetailKey))and(not SameText(DetailFields[I],DetailLine))then AddCode('  if (not cdsDetailed.FieldByName('+QuotedStr(DetailFields[I])+').IsNull)and(Trim(VarToStr(cdsDetailed.FieldByName('+QuotedStr(DetailFields[I])+').AsVariant))<>'''')then Result:=True;');
      AddCode('end;');AddCode('');
      AddCode('//补充空白明细行并立即显示连续项次');AddCode('procedure AppendDetailBlankRows;');AddCode('var I,NextLine:Integer;');AddCode('begin');
      if DetailLine<>'' then AddCode('  cdsDetailed.IndexFieldNames:='+QuotedStr(DetailLine)+'; if cdsDetailed.IsEmpty then NextLine:=1 else begin cdsDetailed.Last; NextLine:=cdsDetailed.FieldByName('+QuotedStr(DetailLine)+').AsInteger+1; end;')
      else AddCode('  NextLine:=cdsDetailed.RecordCount+1;');
      AddCode('  for I:=1 to 5 do begin cdsDetailed.Append;');
      if DetailLine<>'' then AddCode('    cdsDetailed.FieldByName('+QuotedStr(DetailLine)+').AsInteger:=NextLine;');
      AddCode('    cdsDetailed.FieldByName('+QuotedStr(DetailKey)+').AsVariant:=cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant;');
      AddCode('    cdsDetailed.Post; Inc(NextLine); end; cdsDetailed.First;');AddCode('end;');AddCode('');
      if DetailLine<>'' then begin
        AddCode('//临时解除项次索引后按当前物理顺序连续编号，兼容导入记录的空白或重复项次');AddCode('procedure RenumberDetails;');
        AddCode('var I:Integer;');AddCode('begin');AddCode('  cdsDetailed.IndexFieldNames:=''''; I:=1; cdsDetailed.First;');
        AddCode('  while not cdsDetailed.Eof do begin if DetailRowHasData then begin cdsDetailed.Edit; cdsDetailed.FieldByName('+QuotedStr(DetailLine)+').AsInteger:=I; cdsDetailed.Post; Inc(I); end; cdsDetailed.Next; end;');
        AddCode('  cdsDetailed.IndexFieldNames:='+QuotedStr(DetailLine)+'; cdsDetailed.First;');AddCode('end;');AddCode('');
      end;
      { 明细行操作必须发在 RenumberDetails **之外**（它在 DetailLine 为空时根本不生成），
        早前把调用插到了那个 if 块内部，生成的脚本变成例程套例程（编译闸门报 ';' expected）。 }
      EmitDetailRowOps;
      AddCode('//新增主单');AddCode('procedure btAppendOnClick(Sender: TObject);');AddCode('begin');AddCode('  if vEditing then RaiseException(''有未保存数据，请先保存或撤销。'');');
      if Buttons.IndexOf('btAppend')>=0 then AddCode('  if not btAppend.Visible or not btAppend.Enabled then RaiseException(''当前不允许新增单据。'');');
      AddCode('  cdsMain.Close; cdsMain.CommandText:='+QuotedStr(SQLMain+' where 1 = 2')+'; cdsMain.Open;');
      AddCode('  cdsDetailed.Close; cdsDetailed.CommandText:='+QuotedStr(SQLDetail+' where 1 = 2')+'; cdsDetailed.Open;');
      AddCode('  ConfigureTimeFields;');
      AddCode('  cdsMain.Append; vIsNew:=True; vEditCountApplied:=False; vOriginalKey:=Null;');
      if CreateDept<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(CreateDept)+').AsString:=UGMM.Informations.Values[''ClassName''];');
      if CreateUser<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(CreateUser)+').AsString:=UGMM.Informations.Values[''UserName''];');
      if CreateTime<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(CreateTime)+').AsDateTime:=Now;');
      if DocumentDate<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(DocumentDate)+').AsDateTime:=Trunc(Now);');
      if EditCount<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(EditCount)+').AsInteger:=0;');
      if ApprovalMode then AddCode('  cdsMain.FieldByName('+QuotedStr(StatusField)+').AsString:=''PendingReview'';');
      AddCode('  AppendDetailBlankRows; SetEditState(True);');AddCode('end;');AddCode('');
      if Buttons.IndexOf('btAppend')>=0 then begin
        AddCode('//新增菜单：复制当前单据业务内容，不复制编号及审计状态');
        AddCode('procedure pmAppendUgMenuItemsOnClick(const ACaption: string);');
        AddCode('var M,D:TUgClientDataSet; HasData:Boolean;');
        AddCode('begin');
        AddCode('  if vEditing then RaiseException(''有未保存数据，请先保存或撤销。'');');
        AddCode('  if not btAppend.Visible or not btAppend.Enabled then RaiseException(''当前不允许新增单据。'');');
        AddCode('  if ACaption=UGMM.LT(''空白'') then begin btAppendOnClick(nil); Exit; end;');
        AddCode('  if ACaption<>UGMM.LT(''复制'') then Exit;');
        AddCode('  if (not cdsMain.Active) or cdsMain.IsEmpty then begin btAppendOnClick(nil); Exit; end;');
        AddCode('  M:=nil; D:=nil;');AddCode('  try');
        AddCode('    M:=TUgClientDataSet.Create(nil); M.DataNodeName:=cDataNodeName;');
        AddCode('    D:=TUgClientDataSet.Create(nil); D.DataNodeName:=cDataNodeName;');
        AddCode('    M.Data:=cdsMain.Data; D.Data:=cdsDetailed.Data; M.First; D.First;');
        AddCode('    btAppendOnClick(nil);');
        for I:=0 to MainFields.Count-1 do begin
          V:=MainFields[I];
          if SameText(V,MainKey)or SameText(V,AutoField)or SameText(V,EditCount)or
            SameText(V,CreateDept)or SameText(V,CreateUser)or SameText(V,CreateTime)or
            SameText(V,EditDept)or SameText(V,EditUser)or SameText(V,EditTime)or
            SameText(V,StatusField)or SameText(V,AuditDept)or SameText(V,AuditUser)or
            SameText(V,AuditTime)or SameText(V,RepulseDept)or SameText(V,RepulseUser)or
            SameText(V,RepulseTime)or SameText(V,RepulseRemark)then Continue;
          AddCode('    cdsMain.FieldByName('+QuotedStr(V)+').AsVariant:=M.FieldByName('+QuotedStr(V)+').AsVariant;');
        end;
        if AutoField<>'' then AddCode('    cdsMain.FieldByName('+QuotedStr(AutoField)+').AsString:=GetAutoNumber;');
        AddCode('    cdsDetailed.EmptyDataSet;');
        AddCode('    while not D.Eof do');AddCode('    begin');AddCode('      HasData:=False;');
        for I:=0 to DetailFields.Count-1 do if not SameText(DetailFields[I],DetailKey)and not SameText(DetailFields[I],DetailLine)then
          AddCode('      if Trim(VarToStr(D.FieldByName('+QuotedStr(DetailFields[I])+').AsVariant))<>'''' then HasData:=True;');
        AddCode('      if HasData then');AddCode('      begin');AddCode('        cdsDetailed.Append;');
        for I:=0 to DetailFields.Count-1 do if not SameText(DetailFields[I],DetailKey)and not SameText(DetailFields[I],DetailLine)then
          AddCode('        cdsDetailed.FieldByName('+QuotedStr(DetailFields[I])+').AsVariant:=D.FieldByName('+QuotedStr(DetailFields[I])+').AsVariant;');
        AddCode('        cdsDetailed.FieldByName('+QuotedStr(DetailKey)+').AsVariant:=cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant;');
        AddCode('        cdsDetailed.Post;');AddCode('      end;');AddCode('      D.Next;');AddCode('    end;');
        if DetailLine<>'' then AddCode('    RenumberDetails;');
        AddCode('    AppendDetailBlankRows;');AddCode('  finally');AddCode('    D.Free; M.Free;');AddCode('  end;');AddCode('end;');AddCode('');
      end;
      AddCode('//修改当前主单');AddCode('procedure btEditorOnClick(Sender: TObject);');AddCode('begin');AddCode('  if vEditing then RaiseException(''有未保存数据，请先保存或撤销。'');');AddCode('  if(not cdsMain.Active)or cdsMain.IsEmpty then RaiseException(''请先选择要修改的主单。'');');AddCode('  vOriginalKey:=cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant; vIsNew:=False; vEditCountApplied:=False;');if EditCount<>'' then begin AddCode('  vOriginalEditCount:=cdsMain.FieldByName('+QuotedStr(EditCount)+').AsInteger; CheckBrowseVersion;');end;AddCode('  cdsMain.Edit;');if ApprovalMode then AddCode('  cdsMain.FieldByName('+QuotedStr(StatusField)+').AsString:=''PendingReview'';');AddCode('  AppendDetailBlankRows; SetEditState(True);');AddCode('end;');AddCode('');
      AddCode('//主表保存前统一写入录入、修改信息和编辑次数');AddCode('procedure cdsMainBeforePost(DataSet:TDataSet);');AddCode('begin');AddCode('  if not vEditing then Exit;');
      if AutoField<>'' then AddCode('  if DataSet.FieldByName('+QuotedStr(AutoField)+').IsNull or(Trim(VarToStr(DataSet.FieldByName('+QuotedStr(AutoField)+').AsVariant))='''')then DataSet.FieldByName('+QuotedStr(AutoField)+').AsString:=GetAutoNumber;');
      if CreateDept<>'' then AddCode('  if DataSet.FieldByName('+QuotedStr(CreateDept)+').IsNull then DataSet.FieldByName('+QuotedStr(CreateDept)+').AsString:=UGMM.Informations.Values[''ClassName''];');
      if CreateUser<>'' then AddCode('  if DataSet.FieldByName('+QuotedStr(CreateUser)+').IsNull then DataSet.FieldByName('+QuotedStr(CreateUser)+').AsString:=UGMM.Informations.Values[''UserName''];');
      if CreateTime<>'' then AddCode('  if DataSet.FieldByName('+QuotedStr(CreateTime)+').IsNull then DataSet.FieldByName('+QuotedStr(CreateTime)+').AsDateTime:=Now;');
      if EditDept<>'' then AddCode('  DataSet.FieldByName('+QuotedStr(EditDept)+').AsString:=UGMM.Informations.Values[''ClassName''];');
      if EditUser<>'' then AddCode('  DataSet.FieldByName('+QuotedStr(EditUser)+').AsString:=UGMM.Informations.Values[''UserName''];');
      if EditTime<>'' then AddCode('  DataSet.FieldByName('+QuotedStr(EditTime)+').AsDateTime:=Now;');
      if EditCount<>'' then AddCode('  if not vEditCountApplied then begin DataSet.FieldByName('+QuotedStr(EditCount)+').AsInteger:=DataSet.FieldByName('+QuotedStr(EditCount)+').AsInteger+1; vEditCountApplied:=True; end;');
      AddCode('end;');AddCode('');
      AddCode('//主表自动编号生成后，先同步到有效明细，再执行从表非空、唯一性和引用校验');AddCode('procedure SyncDetailKeys;');
      AddCode('begin');AddCode('  if cdsDetailed.State in [dsEdit,dsInsert] then cdsDetailed.Post; cdsDetailed.First;');
      AddCode('  while not cdsDetailed.Eof do begin if DetailRowHasData then begin cdsDetailed.Edit; cdsDetailed.FieldByName('+QuotedStr(DetailKey)+').AsVariant:=cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant; cdsDetailed.Post; end; cdsDetailed.Next; end; cdsDetailed.First;');
      AddCode('end;');AddCode('');
      AddCode('//先只读校验全部明细；校验失败时保留空白占位行供用户继续录入');AddCode('procedure PrepareDetails;');AddCode('var ValidCount:Integer;');AddCode('begin');AddCode('  if cdsDetailed.State in [dsEdit,dsInsert] then cdsDetailed.Post; ValidCount:=0; cdsDetailed.First;');AddCode('  while not cdsDetailed.Eof do begin');AddCode('    if DetailRowHasData then begin');
      for I:=0 to RequiredDetail.Count-1 do AddCode('      if cdsDetailed.FieldByName('+QuotedStr(RequiredDetail[I])+').IsNull or(Trim(VarToStr(cdsDetailed.FieldByName('+QuotedStr(RequiredDetail[I])+').AsVariant))='''')then begin vRequiredFocus:=''detail''; RaiseException('+RequiredMessage(RequiredDetail[I],DAlias,DetailFields,DetailCaptions,DC)+'); end;');
      AddCode('      Inc(ValidCount); end; cdsDetailed.Next; end; cdsDetailed.First;');
      if RequiredDetail.Count>0 then AddCode('  if ValidCount=0 then RaiseException(''请录入至少一条有效明细。'');');
      AddCode('  cdsDetailed.First;');AddCode('  while not cdsDetailed.Eof do');AddCode('  begin');AddCode('    if not DetailRowHasData then begin if cdsDetailed.UpdateStatus in [usInserted,usModified] then cdsDetailed.Delete else cdsDetailed.Next; end else begin');
      AddCode('      cdsDetailed.Edit; cdsDetailed.FieldByName('+QuotedStr(DetailKey)+').AsVariant:=cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant;');
      AddCode('      cdsDetailed.Post; cdsDetailed.Next; end;');AddCode('  end;');
      if DetailLine<>'' then AddCode('  RenumberDetails;') else AddCode('  cdsDetailed.First;');
      AddCode('end;');AddCode('');
      if Buttons.IndexOf('btImport')>=0 then begin
        AddCode('//导入完成后移除旧空占位行、立即生成连续项次，再补充新的可编辑空白行');AddCode('procedure RefreshImportedDetails;');AddCode('begin');
        AddCode('  if cdsDetailed.State in [dsEdit,dsInsert] then cdsDetailed.Post; cdsDetailed.IndexFieldNames:=''''; cdsDetailed.First;');
        AddCode('  while not cdsDetailed.Eof do begin if not DetailRowHasData then cdsDetailed.Delete else cdsDetailed.Next; end;');
        if DetailLine<>'' then AddCode('  RenumberDetails;');
        AddCode('  AppendDetailBlankRows;');AddCode('end;');AddCode('');
      end;
      if UniqueDetail.Count>0 then begin
        AddCode('//检查当前主单内的从表组合唯一值，并报告首行和重复行');AddCode('procedure CheckDetailUnique;');AddCode('var L,Rows:TStringList; K,V,FieldValues:String; B:TBookmark; RowNo,DuplicateIndex:Integer;');AddCode('begin');
        AddCode('  if cdsDetailed.IsEmpty then Exit;');AddCode('  L:=TStringList.Create; Rows:=TStringList.Create; B:=cdsDetailed.GetBookmark; cdsDetailed.DisableControls; try cdsDetailed.First; RowNo:=0;');
        AddCode('    while not cdsDetailed.Eof do begin Inc(RowNo); if DetailRowHasData then begin K:=''''; FieldValues:='''';');
        for I:=0 to UniqueDetail.Count-1 do begin
          AddCode('      V:=VarToStr(cdsDetailed.FieldByName('+QuotedStr(UniqueDetail[I])+').AsVariant); K:=K+IntToStr(Length(V))+'+QuotedStr(':')+'+V+'+QuotedStr('|')+';');
          AddCode('      if FieldValues<>'''' then FieldValues:=FieldValues+'+QuotedStr(', ')+'; FieldValues:=FieldValues+'+QuotedStr(UniqueDetail[I]+'=')+'+V;');
        end;
        AddCode('      DuplicateIndex:=L.IndexOf(K); if DuplicateIndex>=0 then RaiseException(''保存失败：明细第 ''+IntToStr(RowNo)+'' 行组合唯一字段 [''+FieldValues+''] 与第 ''+Rows[DuplicateIndex]+'' 行重复，请修改后重试！'');');
        AddCode('      L.Add(K); Rows.Add(IntToStr(RowNo)); end; cdsDetailed.Next; end;');
        AddCode('  finally cdsDetailed.GotoBookmark(B); cdsDetailed.FreeBookmark(B); cdsDetailed.EnableControls; Rows.Free; L.Free; end;');AddCode('end;');AddCode('');
      end;
      if CheckDetailFields.Count>0 then begin
        AddCode('//按配置校验从表引用数据，并报告字段、值和明细行号');
        AddCode('procedure CheckDetailData;');
        AddCode('var');
        AddCode('  C: TUgClientDataSet;');
        AddCode('  B: TBookmark;');
        AddCode('  RowNo: Integer;');
        AddCode('  V: String;');
        AddCode('begin');
        AddCode('  if cdsDetailed.IsEmpty then');
        AddCode('    Exit;');
        AddCode('');
        AddCode('  C := TUgClientDataSet.Create(nil);');
        AddCode('  C.DataNodeName := cDataNodeName;');
        AddCode('  B := cdsDetailed.GetBookmark;');
        AddCode('  cdsDetailed.DisableControls;');
        AddCode('  try');
        AddCode('    cdsDetailed.First;');
        AddCode('    RowNo := 0;');
        AddCode('    while not cdsDetailed.Eof do');
        AddCode('    begin');
        AddCode('      Inc(RowNo);');
        for I:=0 to CheckDetailFields.Count-1 do begin
          AddCode('      V := Trim(VarToStr(cdsDetailed.FieldByName('+QuotedStr(CheckDetailFields[I])+').AsVariant));');
          AddCode('      if V <> '''' then');
          AddCode('      begin');
          AddCode('        C.Close;');
          AddCode('        C.CommandText := '+QuotedStr('select '+CheckSourceFields[I]+' from '+CheckTables[I]+' where '+CheckSourceFields[I]+' = :checkValue')+';');
          AddCode('        C.ParamByName(''checkValue'').Value := cdsDetailed.FieldByName('+QuotedStr(CheckDetailFields[I])+').AsVariant;');
          AddCode('        C.PageRowCount := 1;');
          AddCode('        C.Open;');
          AddCode('        if C.IsEmpty then');
          // Escape configured titles as Pascal literals, never interpolate them
          // inside an already quoted script fragment. Keep field keys unchanged.
          AddCode('          RaiseException(''保存失败：明细第 '' + IntToStr(RowNo) + '' 行字段 ['' +');
          AddCode('            UGMM.LT('+QuotedStr(CheckDetailCaptions[I])+') + '' / '' + VarToStr('+QuotedStr(CheckDetailFields[I])+') + ''] 的值 ['' + V + ''] 不存在。'');');
          AddCode('      end;');
        end;
        AddCode('      cdsDetailed.Next;');
        AddCode('    end;');
        AddCode('  finally');
        AddCode('    cdsDetailed.GotoBookmark(B);');
        AddCode('    cdsDetailed.FreeBookmark(B);');
        AddCode('    cdsDetailed.EnableControls;');
        AddCode('    C.Free;');
        AddCode('  end;');
        AddCode('end;');
        AddCode('');
      end;
      AddCode('//唯一字段交换时，在同一事务内替换当前单据明细，避免逐行更新的中间冲突');
      AddCode('procedure SubmitMasterDetail;');
      AddCode('var');
      AddCode('  ReplaceDetails: Boolean;');
      AddCode('  OldRows, NewRows: TUgClientDataSet;');
      AddCode('  I: Integer;');
      AddCode('  F: TField;');
      AddCode('begin');
      if JoinTable<>'' then begin AddCode('  CheckDetailJoin;');AddCode('  ReplaceDetails := True;');end
      else AddCode('  ReplaceDetails := False;');
      if (UniqueDetail.Count>0)and(DetailLine<>'')then begin
        AddCode('  cdsDetailed.First;');
        AddCode('  while not cdsDetailed.Eof do');
        AddCode('  begin');
        AddCode('    if cdsDetailed.UpdateStatus = usModified then');
        AddCode('    begin');
        for I:=0 to UniqueDetail.Count-1 do
          AddCode('      if VarToStr(cdsDetailed.FieldByName('+QuotedStr(UniqueDetail[I])+').OldValue) <> VarToStr(cdsDetailed.FieldByName('+QuotedStr(UniqueDetail[I])+').AsVariant) then ReplaceDetails := True;');
        AddCode('    end;');
        AddCode('    cdsDetailed.Next;');
        AddCode('  end;');
      end;
      AddCode('  if not ReplaceDetails then');
      AddCode('  begin');
      AddCode('    UGMM.ApplyUpdatesCds(cDataNodeName,[cdsMain,cdsDetailed]);');
      AddCode('    Exit;');
      AddCode('  end;');
      AddCode('  OldRows := TUgClientDataSet.Create(nil);');
      AddCode('  NewRows := TUgClientDataSet.Create(nil);');
      AddCode('  try');
      AddCode('    OldRows.DataNodeName := cDataNodeName;');
      AddCode('    OldRows.PageRowCount := -1;');
      AddCode('    OldRows.CommandText := '+QuotedStr('select * from '+DetailTable+' where '+DetailKey+' = :detailKey')+';');
      AddCode('    OldRows.ParamByName(''detailKey'').Value := cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant;');
      AddCode('    OldRows.Open;');
      AddCode('    NewRows.DataNodeName := cDataNodeName;');
      AddCode('    NewRows.CommandText := '+QuotedStr('select * from '+DetailTable+' where 1 = 2')+';');
      AddCode('    NewRows.Open;');
      AddCode('    cdsDetailed.First;');
      AddCode('    while not cdsDetailed.Eof do');
      AddCode('    begin');
      AddCode('      NewRows.Append;');
      if DetailLine<>'' then begin
        AddCode('      if cdsDetailed.UpdateStatus <> usInserted then');
        AddCode('      begin');
        AddCode('        if not OldRows.Locate('+QuotedStr(DetailLine)+',cdsDetailed.FieldByName('+QuotedStr(DetailLine)+').OldValue,0) then');
        AddCode('          RaiseException(''原明细已变化，请撤销后重新查询。'');');
        AddCode('        for I := 0 to OldRows.FieldCount - 1 do');
        AddCode('          if (not OldRows.Fields[I].ReadOnly) and (OldRows.Fields[I].FieldName <> ''virtualFieldClientDataSetRowID'') then');
        AddCode('            NewRows.FieldByName(OldRows.Fields[I].FieldName).AsVariant := OldRows.Fields[I].AsVariant;');
        AddCode('      end;');
      end;
      AddCode('      for I := 0 to cdsDetailed.FieldCount - 1 do');
      AddCode('      begin');
      V:='(cdsDetailed.Fields[I].FieldName <> ''virtualFieldClientDataSetRowID'')';
      for X:=0 to JoinFields.Count-1 do V:=V+' and (cdsDetailed.Fields[I].FieldName <> '+QuotedStr(JoinFieldAliases[X]+JoinFields[X])+')';
      AddCode('        if '+V+' then');
      AddCode('        begin');
      AddCode('          F := NewRows.FieldByName(cdsDetailed.Fields[I].FieldName);');
      AddCode('          if not F.ReadOnly then F.AsVariant := cdsDetailed.Fields[I].AsVariant;');
      AddCode('        end;');
      AddCode('      end;');
      AddCode('      NewRows.Post;');
      AddCode('      cdsDetailed.Next;');
      AddCode('    end;');
      AddCode('    OldRows.First;');
      AddCode('    while not OldRows.Eof do OldRows.Delete;');
      AddCode('    UGMM.ApplyUpdatesCds(cDataNodeName,[cdsMain,OldRows,NewRows]);');
      AddCode('  finally');
      AddCode('    NewRows.Free;');
      AddCode('    OldRows.Free;');
      AddCode('  end;');
      AddCode('end;');
      AddCode('');
      AddCode('//保存主表和从表修改');AddCode('procedure btSaveOnClick(Sender: TObject);');AddCode('var SavedKey:Variant; Failure:String;');AddCode('begin');AddCode('  if not vEditing then Exit;');AddCode('  try');if EditCount<>'' then AddCode('    if not vIsNew then CheckCurrentVersion;');AddCode('    if cdsMain.State in [dsEdit,dsInsert] then cdsMain.Post;');
      AddCode('    if cdsMain.FieldByName('+QuotedStr(MainKey)+').IsNull or(Trim(VarToStr(cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant))='''')then begin vRequiredFocus:='+QuotedStr('main:'+MainKey)+'; RaiseException('+RequiredMessage(MainKey,MAlias,MainFields,MainCaptions,MC)+'); end;');
      for I:=0 to RequiredMain.Count-1 do if not SameText(RequiredMain[I],MainKey)then AddCode('    if cdsMain.FieldByName('+QuotedStr(RequiredMain[I])+').IsNull or(Trim(VarToStr(cdsMain.FieldByName('+QuotedStr(RequiredMain[I])+').AsVariant))='''')then begin vRequiredFocus:='+QuotedStr('main:'+RequiredMain[I])+'; RaiseException('+RequiredMessage(RequiredMain[I],MAlias,MainFields,MainCaptions,MC)+'); end;');
      if UniqueMain.Count>0 then AddCode('    CheckMainUnique;');
      AddCode('    SyncDetailKeys;');
      AddCode('    if vIsNew and DetailRecordExists(cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant) then');
      AddCode('      RaiseException(''保存失败：单号 [''+VarToStr(cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant)+''] 已有后台明细，可能是遗留数据，请更换单号或由管理员核查；旧明细未删除。'');');
      if UniqueDetail.Count>0 then AddCode('    CheckDetailUnique;');if CheckDetailFields.Count>0 then AddCode('    CheckDetailData;');AddCode('    PrepareDetails;');
      AddCode('    cdsMain.Edit; cdsMain.Post; SavedKey:=cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant;');AddCode('    SubmitMasterDetail;');AddCode('  except');AddCode('    Failure:=ExceptionMessage; SetEditState(True);');
      if UniqueMain.Count>0 then AddCode('    if(Pos(''UNIQUE'',UpperCase(Failure))>0)and(Pos('+QuotedStr(UpperCase(Copy(MainTable,LastDelimiter('.',MainTable)+1,MaxInt)))+',UpperCase(Failure))>0)then RaiseException('+QuotedStr('保存失败：主表组合唯一字段 ['+UniqueMainLabel+'] 已存在，请修改后重试！')+');');
      if UniqueDetail.Count>0 then AddCode('    if(Pos(''UNIQUE'',UpperCase(Failure))>0)and(Pos('+QuotedStr(UpperCase(Copy(DetailTable,LastDelimiter('.',DetailTable)+1,MaxInt)))+',UpperCase(Failure))>0)then RaiseException('+QuotedStr('保存失败：明细组合唯一字段 ['+UniqueDetailLabel+'] 存在重复，请修改后重试！')+');');
      AddCode('    RaiseException(Failure);');AddCode('  end;');
      AddCode('  //提交已经成功；后续刷新失败不得回到待保存状态');
      AddCode('  vEditing:=False;');
      AddCode('  vIsNew:=False;');
      AddCode('  vEditCountApplied:=False;');
      AddCode('  vOriginalKey:=SavedKey;');
      AddCode('  try');
      AddCode('    OpenRecord(SavedKey);');
      AddCode('  except');
      AddCode('    Failure:=ExceptionMessage;');
      AddCode('    //清除可能只加载了一半的主从显示，防止再次提交旧缓存');
      AddCode('    cdsDetailed.Close;');
      AddCode('    cdsMain.Close;');
      AddCode('    SetEditState(False);');
      AddCode('    ShowNotice(''单据 [''+VarToStr(SavedKey)+''] 已保存成功，但界面刷新失败。请重新查询，不要重复保存。''+#13#10+Failure);');
      AddCode('    Exit;');
      AddCode('  end;');
      AddCode('  ShowNotice(''数据保存成功。'');');
      AddCode('end;');AddCode('');
      AddCode('//撤销本次主从编辑；新增撤销后显示权限范围内的最后一张单据');
      AddCode('procedure btCancelOnClick(Sender: TObject);');
      AddCode('begin');
      AddCode('  if not vEditing then Exit;');
      AddCode('  if not ConfirmAction(''是否撤销全部未保存修改？'') then Exit;');
      AddCode('  if vIsNew then');
      AddCode('  begin');
      AddCode('    cdsDetailed.Close;');
      AddCode('    cdsMain.Close;');
      AddCode('    vIsNew:=False;');
      AddCode('    vEditCountApplied:=False;');
      AddCode('    SetEditState(False);');
      AddCode('    NavigateRecord(4);');
      AddCode('  end');
      AddCode('  else OpenRecord(vOriginalKey);');
      AddCode('end;');AddCode('');
      if ApprovalMode then begin
        if CheckType='0' then
          AddCode('//审批校验类型0：对应字段与当前部门ClassName比较，适用于审核、消审和撤回')
        else if CheckType='2' then
          AddCode('//审批校验类型2：按分号边界匹配SubClassName，不额外加入当前部门')
        else AddCode('//审批校验类型1：对应字段与当前UserName比较，适用于审核、消审和撤回');
        AddCode('procedure CheckApprovalOwner(const AAction:String);');AddCode('begin');
        if CheckType='0' then V:='ClassName' else V:='UserName';
        if CheckType='2' then
          AddCode('  if Pos('';''+cdsMain.FieldByName('+QuotedStr(CorrespondingField)+').AsString+'';'',UGMM.Informations.Values[''SubClassName''])=0 then')
        else
          AddCode('  if cdsMain.FieldByName('+QuotedStr(CorrespondingField)+').AsString<>UGMM.Informations.Values['+QuotedStr(V)+'] then');
        AddCode('    RaiseException(''您没有权限对当前数据进行''+UGMM.LT(AAction)+''。'');');
        AddCode('end;');AddCode('');
        AddCode('//审核');AddCode('procedure btAuditOnClick(Sender: TObject);');AddCode('var SavedKey:Variant; Failure:String;');AddCode('begin');
        AddCode('  if vEditing then RaiseException(''请先保存或撤销当前修改。'');');AddCode('  if(not cdsMain.Active)or cdsMain.IsEmpty then RaiseException(''没有可审核的主单。'');');
        AddCode('  if cdsMain.FieldByName('+QuotedStr(StatusField)+').AsString<>''PendingReview'' then RaiseException(''当前数据状态不允许审核。'');');AddCode('  if not ConfirmAction(''是否对数据进行审核？'') then Exit;');AddCode('  CheckApprovalOwner(''审核'');');
        if EditCount<>'' then AddCode('  CheckBrowseVersion;');
        AddCode('  SavedKey:=cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant; cdsMain.Edit; cdsMain.FieldByName('+QuotedStr(StatusField)+').AsString:=''Reviewed'';');
        if AuditDept<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(AuditDept)+').AsString:=UGMM.Informations.Values[''ClassName''];');
        if AuditUser<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(AuditUser)+').AsString:=UGMM.Informations.Values[''UserName''];');
        if AuditTime<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(AuditTime)+').AsDateTime:=Now;');
        if EditCount<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(EditCount)+').AsInteger:=cdsMain.FieldByName('+QuotedStr(EditCount)+').AsInteger+1;');
        AddCode('  cdsMain.Post; try UGMM.ApplyUpdatesCds(cDataNodeName,[cdsMain]); except Failure:=ExceptionMessage; OpenRecord(SavedKey); RaiseException(Failure); end; OpenRecord(SavedKey);');AddCode('end;');AddCode('');
        AddCode('//消审');AddCode('procedure btUnAuditOnClick(Sender: TObject);');AddCode('var SavedKey:Variant; Failure:String;');AddCode('begin');
        AddCode('  if vEditing then RaiseException(''请先保存或撤销当前修改。'');');AddCode('  if(not cdsMain.Active)or cdsMain.IsEmpty then RaiseException(''没有可消审的主单。'');');
        AddCode('  if cdsMain.FieldByName('+QuotedStr(StatusField)+').AsString<>''Reviewed'' then RaiseException(''当前数据状态不允许消审。'');');AddCode('  if not ConfirmAction(''是否对数据进行消审？'') then Exit;');AddCode('  CheckApprovalOwner(''消审'');');
        if EditCount<>'' then AddCode('  CheckBrowseVersion;');
        AddCode('  SavedKey:=cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant; cdsMain.Edit; cdsMain.FieldByName('+QuotedStr(StatusField)+').AsString:=''PendingReview'';');
        if AuditDept<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(AuditDept)+').AsVariant:=Null;');
        if AuditUser<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(AuditUser)+').AsVariant:=Null;');
        if AuditTime<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(AuditTime)+').AsVariant:=Null;');
        if EditCount<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(EditCount)+').AsInteger:=cdsMain.FieldByName('+QuotedStr(EditCount)+').AsInteger+1;');
        AddCode('  cdsMain.Post; try UGMM.ApplyUpdatesCds(cDataNodeName,[cdsMain]); except Failure:=ExceptionMessage; OpenRecord(SavedKey); RaiseException(Failure); end; OpenRecord(SavedKey);');AddCode('end;');AddCode('');
        AddCode('//撤回');AddCode('procedure btRepulseOnClick(Sender: TObject);');AddCode('var SavedKey:Variant; Failure,Remark:String;');AddCode('begin');
        AddCode('  if vEditing then RaiseException(''请先保存或撤销当前修改。'');');AddCode('  if(not cdsMain.Active)or cdsMain.IsEmpty then RaiseException(''没有可撤回的主单。'');');
        AddCode('  if cdsMain.FieldByName('+QuotedStr(StatusField)+').AsString<>''PendingReview'' then RaiseException(''当前数据状态不允许撤回。'');');
        AddCode('  CheckApprovalOwner(''撤回'');');
        if RepulseRemark<>'' then
          AddCode('  Remark:=''''; if not InputAction(''请输入撤回备注'',Remark) then Exit;')
        else
          AddCode('  if not ConfirmAction(''是否对数据进行撤回？'') then Exit;');
        if EditCount<>'' then AddCode('  CheckBrowseVersion;');
        AddCode('  SavedKey:=cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant; cdsMain.Edit; cdsMain.FieldByName('+QuotedStr(StatusField)+').AsString:=''Returned'';');
        if RepulseDept<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(RepulseDept)+').AsString:=UGMM.Informations.Values[''ClassName''];');
        if RepulseUser<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(RepulseUser)+').AsString:=UGMM.Informations.Values[''UserName''];');
        if RepulseTime<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(RepulseTime)+').AsDateTime:=Now;');
        if RepulseRemark<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(RepulseRemark)+').AsString:=Remark;');
        if EditCount<>'' then AddCode('  cdsMain.FieldByName('+QuotedStr(EditCount)+').AsInteger:=cdsMain.FieldByName('+QuotedStr(EditCount)+').AsInteger+1;');
        AddCode('  cdsMain.Post; try UGMM.ApplyUpdatesCds(cDataNodeName,[cdsMain]); except Failure:=ExceptionMessage; OpenRecord(SavedKey); RaiseException(Failure); end; OpenRecord(SavedKey);');AddCode('end;');AddCode('');
      end;
      AddCode('//按关联字段事务删除整组数据，兼容历史明细复合主键中存在 NULL 的记录');AddCode('procedure btDeleteOnClick(Sender: TObject);');
      AddCode('var DeleteKey:Variant; SQL,Failure:String; Logs:TStringList;');AddCode('begin');
      AddCode('  if vEditing then RaiseException(''有未保存数据，请先保存或撤销。'');');AddCode('  if(not cdsMain.Active)or cdsMain.IsEmpty then RaiseException(''没有可删除的主单。'');');
      AddCode('  DeleteKey:=cdsMain.FieldByName('+QuotedStr(MainKey)+').AsVariant; vOriginalKey:=DeleteKey;');if EditCount<>'' then AddCode('  vOriginalEditCount:=cdsMain.FieldByName('+QuotedStr(EditCount)+').AsInteger; CheckBrowseVersion;');
      AddCode('  if not ConfirmAction(''是否删除当前主单及全部明细？'') then Exit;');
      if EditCount<>'' then AddCode('  CheckBrowseVersion;');
      AddCode('  SQL:='+QuotedStr('delete from '+DetailTable+' where '+DetailKey+' = ')+'+QuotedStr(VarToStr(DeleteKey))+#13#10+UGMM.ExecSqlSeparator+#13#10+'+QuotedStr('delete from '+MainTable+' where '+MainKey+' = ')+'+QuotedStr(VarToStr(DeleteKey));');
      AddCode('  Logs:=TStringList.Create; Failure:=''''; try');
      AddCode('    try UGMM.ExecSql(cDataNodeName,SQL,Logs); except Failure:=ExceptionMessage; end;');
      AddCode('    if (Failure<>'''')and(Pos(''CANNOT ROLLBACK - NO TRANSACTION IS ACTIVE'',UpperCase(Failure))>0)and(not MainRecordExists(DeleteKey))and(not DetailRecordExists(DeleteKey)) then Failure:='''';');
      AddCode('    if Failure<>'''' then RaiseException(''删除失败：''+Failure);');
      AddCode('    if MainRecordExists(DeleteKey) or DetailRecordExists(DeleteKey) then');
      AddCode('      RaiseException(''删除后仍检测到主表或明细记录，请重新查询并核查；未执行额外清理。'');');
      AddCode('  finally Logs.Free; end;');
      AddCode('  cdsDetailed.Close; cdsMain.Close; NavigateRecord(4); ShowNotice(''数据删除成功。'');');AddCode('end;');AddCode('');
      if Buttons.IndexOf('btImport')>=0 then begin
        AddCode('//导入从表文本或电子表格；关联字段和明细序号在保存前统一补齐');AddCode('procedure pmImportUgMenuItemsOnClick(const ACaption:String);');AddCode('begin');
        AddCode('  if not vEditing then RaiseException(''请先新增或修改主单，再导入明细。'');');
        AddCode('  if ACaption=UGMM.LT(''文本格式'') then UGMM.ImportText(gridDetailed,'+QuotedStr(ImportCaptions)+');');
        AddCode('  if ACaption=UGMM.LT(''电子表格'') then UGMM.ImpExcel(gridDetailed,Self.Caption,'+QuotedStr(ImportRequired)+');');
        for I:=0 to ImportFrameCaptions.Count-1 do
          AddCode('  if ACaption=UGMM.LT('+QuotedStr(ImportFrameCaptions[I])+') then QuoteDetailsFromQuery('+QuotedStr(ImportFrameNames[I])+', '+ImportFrameMulti[I]+');');
        AddCode('  RefreshImportedDetails;');
        AddCode('end;');AddCode('');
        AddCode('//默认打开文本导入');AddCode('procedure btImportOnClick(Sender: TObject);');AddCode('begin pmImportUgMenuItemsOnClick(UGMM.LT(''文本格式'')); end;');AddCode('');
        if ImportFrameCaptions.Count>0 then begin
          AddCode('//引用明细：把来源查询窗体的记录逐条追加到从表（扩充项，关联字段/明细编号由保存前准备补齐）');
          AddCode('procedure QuoteDetailsFromQuery(const AFrame: string; const AMultiSelect: Boolean);');
          AddCode('var');
          AddCode('  F : TUgWebForm;');
          AddCode('  g : TUgDBGrid;');
          AddCode('  s : TUgClientDataSet;');
          AddCode('  bm, cb : TBookmark;');
          AddCode('  i, n, nFound : Integer;');
          AddCode('  v : Variant;');
          AddCode('  LSkips : TStringList;');
          AddCode('begin');
          AddCode('  if not vEditing then RaiseException(''请先新增或修改主单，再导入明细。'');');
          AddCode('  F := TUgWebForm(UGMM.GetWebSubForm(AFrame));');
          AddCode('  try');
          AddCode('    F.Caption := UGMM.LT(AFrame);');
          AddCode('    //以模态窗体打开来源查询窗体：查询并勾选后点确定，再读取选择');
          AddCode('    if F.ShowModal <> mrOK then');
          AddCode('      Exit;');
          AddCode('    g := TUgDBGrid(F.RunFrame.FindComponent(''gridMain''));');
          AddCode('    s := TUgClientDataSet(F.RunFrame.FindComponent(''cdsMain''));');
          AddCode('    if (g = nil) or (s = nil) then');
          AddCode('      RaiseException(UGMM.LT(''查询窗体尚未就绪，请先查询出要引用的记录。''));');
          AddCode('    if not s.Active then');
          AddCode('      RaiseException(UGMM.LT(''查询窗体尚未就绪，请先查询出要引用的记录。''));');
          AddCode('    n := g.SelectedRows.Count;');
          AddCode('    if AMultiSelect then');
          AddCode('    begin');
          AddCode('      if n = 0 then');
          AddCode('        RaiseException(UGMM.LT(''请先选择要引用的明细记录。''));');
          AddCode('    end');
          AddCode('    else');
          AddCode('      n := 1;');
          AddCode('    //来源与从表明细没有任何同名字段时不予引用，避免追加空行');
          AddCode('    nFound := 0;');
          for I:=0 to DetailFields.Count-1 do
            if(not SameText(DetailFields[I],DetailKey))and(not SameText(DetailFields[I],DetailLine))then begin
              AddCode('    try');
              AddCode('      v := s.FieldByName('+QuotedStr(DetailFields[I])+').AsVariant;');
              AddCode('      Inc(nFound);');
              AddCode('    except');
              AddCode('    end;');
            end;
          AddCode('    if nFound = 0 then');
          AddCode('      RaiseException(UGMM.LT(''来源记录与从表明细没有同名字段，无法引用，请检查字段命名。''));');
          AddCode('    bm := s.GetBookmark;');
          AddCode('    LSkips := TStringList.Create;');
          AddCode('    s.DisableControls;');
          AddCode('    try');
          AddCode('      for i := 0 to n - 1 do');
          AddCode('      begin');
          AddCode('        if AMultiSelect then');
          AddCode('        begin');
          AddCode('          cb := g.SelectedRows[i];');
          AddCode('          s.GotoBookmark(cb);');
          AddCode('        end;');
          AddCode('        cdsDetailed.Append;');
          for I:=0 to DetailFields.Count-1 do
            if(not SameText(DetailFields[I],DetailKey))and(not SameText(DetailFields[I],DetailLine))then begin
              AddCode('        try');
              AddCode('          cdsDetailed.FieldByName('+QuotedStr(DetailFields[I])+').AsVariant := s.FieldByName('+QuotedStr(DetailFields[I])+').AsVariant;');
              AddCode('        except');
              AddCode('          LSkips.Add('+QuotedStr(DetailCaptions[I])+');');
              AddCode('        end;');
            end;
          AddCode('        cdsDetailed.Post;');
          AddCode('      end;');
          AddCode('    //回报要读 LSkips，必须放在释放它的 finally 之前');
          AddCode('    if LSkips.Count > 0 then');
          AddCode('      ShowNotice(UGMM.LT(''已引用 '') + IntToStr(n) + UGMM.LT('' 条明细；来源中无同名列、未复制的字段：'') + LSkips.CommaText)');
          AddCode('    else');
          AddCode('      ShowNotice(UGMM.LT(''已引用 '') + IntToStr(n) + UGMM.LT('' 条明细。''));');
          AddCode('    finally');
          AddCode('      s.GotoBookmark(bm);');
          AddCode('      s.FreeBookmark(bm);');
          AddCode('      s.EnableControls;');
          AddCode('      LSkips.Free;');
          AddCode('    end;');
          if UniqueDetail.Count>0 then AddCode('    CheckDetailUnique;');
          AddCode('  finally');
          AddCode('    UGMM.DelWebSubForm(AFrame);');
          AddCode('  end;');
          AddCode('end;');AddCode('');
        end;
      end;
    end;
    if Buttons.IndexOf('btAnnex')>=0 then begin
      AddCode('//按当前主单编号打开附件管理');AddCode('procedure btAnnexOnClick(Sender: TObject);');AddCode('var CanEdit:Boolean;');AddCode('begin');
      AddCode('  if(not cdsMain.Active)or cdsMain.IsEmpty then RaiseException(''请先选择主单。''); CanEdit:=False;');
      if Buttons.IndexOf('btDelete')>=0 then AddCode('  if btDelete.Visible and btDelete.Enabled then CanEdit:=True;');
      if Buttons.IndexOf('btEditor')>=0 then AddCode('  if btEditor.Visible and btEditor.Enabled then CanEdit:=True;');
      if Buttons.IndexOf('btAudit')>=0 then AddCode('  if btAudit.Visible and btAudit.Enabled then CanEdit:=True;');
      if Buttons.IndexOf('btUnAudit')>=0 then AddCode('  if btUnAudit.Visible and btUnAudit.Enabled then CanEdit:=True;');
      if Buttons.IndexOf('btRepulse')>=0 then AddCode('  if btRepulse.Visible and btRepulse.Enabled then CanEdit:=True;');
      AddCode('  UGMM.OpenFileManager(Self.Guid,cdsMain.FieldByName('+QuotedStr(MainKey)+').AsString,31457280,CanEdit);');
      AddCode('end;');AddCode('');
    end;
    for I:=0 to MainFields.Count-1 do if IsGridType(MainTypes[I])then AddDynamicLookupCode('a'+MainFields[I],'lookupMain'+MainFields[I],MainOptions[I],False);
    for I:=0 to DetailFields.Count-1 do if IsGridType(DetailTypes[I])then AddDynamicLookupCode('grid_a'+DetailFields[I],'lookupDetail'+DetailFields[I],DetailOptions[I],True);
    AddCode('//关闭');AddCode('procedure btCloseOnClick(Sender: TObject);');AddCode('begin');
    if WriteMode then AddCode('  if vEditing then RaiseException(''有未保存数据，请先保存或撤销。'');');
    AddCode('  if Self.Parent is TUniForm then TUniForm(Self.Parent).Close; if Self.Parent is TUniTabSheet then TUniTabSheet(Self.Parent).Close;');AddCode('end;');AddCode('');
    for I:=0 to MainFields.Count-1 do if MainTypes[I]='combobox' then AddComboCode('a'+MainFields[I],MainOptions[I]);
    for I:=0 to DetailFields.Count-1 do if DetailTypes[I]='combobox' then AddComboCode('grid_a'+DetailFields[I],DetailOptions[I]);
    AddCode('//运行脚本后');
    AddCode('procedure UgWebRunFrameOnAfterRunScript(const sender: tobject);');
    AddCode('begin');
    AddCode('  cdsMain.DataNodeName := cDataNodeName;');
    AddCode('  cdsDetailed.DataNodeName := cDataNodeName;');
    for I:=0 to MainFields.Count-1 do if MainTypes[I]='combobox' then AddCode('  Loada'+MainFields[I]+'Items;');
    for I:=0 to DetailFields.Count-1 do if DetailTypes[I]='combobox' then AddCode('  Loadgrid_a'+DetailFields[I]+'Items;');
    if WriteMode then begin
      AddCode('  vEditing := False;');
      AddCode('  vIsNew := False;');
      AddCode('  vEditCountApplied := False;');
      AddCode('  vOriginalKey := Null;');
      if EditCount<>'' then AddCode('  vOriginalEditCount := 0;');
    end;
    AddCode('  UGMM.LC(Self);');
    if WriteMode then begin
      AddCode('  CaptureButtonPermissions;');
      AddCode('  SetEditState(False);');
    end else AddCode('  UGMM.VerifyRunFramePerm(Self);');
    if Yes(S(Settings,'表格复制'))then AddCode('  gridDetailed.ClientEvents.UniEvents.Values[''beforeInit'']:=''function beforeInit(sender, config){ config.viewConfig.enableTextSelection = true; }'';');
    if Buttons.IndexOf('btImport')>=0 then AddCode('  btImport.DropdownMenu:=pmImport.PopupMenus;');
    if Buttons.IndexOf('btAppend')>=0 then AddCode('  btAppend.DropdownMenu:=pmAppend.PopupMenus;');
    if Buttons.IndexOf('btPrint')>=0 then AddCode('  UGMM.AddReport(btPrint,UGMM.Informations.Values[''AllowLandingType'']<>''系统用户;'',Self.Guid);');
    if GridPersonalization then AddCode('  LoadGridUserSettings(gridDetailed,gridDetailed.Name);');
    for I:=0 to MainFields.Count-1 do if IsLookupType(MainTypes[I])then begin
      AddCode('  lookupMain'+MainFields[I]+'.DataNodeName := cDataNodeName;');
      AddCode('  lookupMain'+MainFields[I]+'.Open;');
    end;
    for I:=0 to DetailFields.Count-1 do if IsLookupType(DetailTypes[I])then begin
      AddCode('  lookupDetail'+DetailFields[I]+'.DataNodeName := cDataNodeName;');
      AddCode('  lookupDetail'+DetailFields[I]+'.Open;');
    end;
    AddCode('  NavigateRecord(4);');AddCode('end;');AddCode('');
    if WriteMode then begin
      AddCode('//提示关闭后恢复必填字段焦点；明细保留失败行，不退回第一行');
      AddCode('procedure RestoreRequiredFocus;');
      AddCode('var Target: String;');
      AddCode('begin');
      AddCode('  Target := vRequiredFocus; vRequiredFocus := '''';');
      AddCode('  if not vEditing then Exit;');
      for I:=0 to MainFields.Count-1 do
        if (RequiredMain.IndexOf(MainFields[I])>=0) or SameText(MainFields[I],MainKey) then begin
          if HiddenMain.IndexOf(MainFields[I])>=0 then Continue;
          AddCode('  if Target = '+QuotedStr('main:'+MainFields[I])+' then');
          AddCode('    if a'+MainFields[I]+'.Enabled and a'+MainFields[I]+'.Visible then a'+MainFields[I]+'.SetFocus;');
        end;
      AddCode('  if Target = ''detail'' then');
      AddCode('    if gridDetailed.Enabled and gridDetailed.Visible then gridDetailed.SetFocus;');
      AddCode('end;');
      AddCode('procedure errorAlertOnConfirm(Sender: TObject);');
      AddCode('begin RestoreRequiredFocus; end;');
      AddCode('procedure errorAlertOnDismiss(Sender: TObject; const Reason: TDismissType);');
      AddCode('begin RestoreRequiredFocus; end;');
      AddCode('//操作入口统一显示异常，内部校验仍通过异常中止当前操作');
      AddCode('procedure ShowActionError(const AMessage: string);');
      AddCode('begin');
      AddCode('  errorAlert.TitleText := UGMM.LT(''操作未完成'');');
      AddCode('  errorAlert.ConfirmButtonText := UGMM.LT(''确定'');');
      AddCode('  errorAlert.Show(AMessage);');
      AddCode('end;');
      AddCode('');
      if Buttons.IndexOf('btQuery')>=0 then AddActionBoundary('btQueryOnClick',False);
      if Buttons.IndexOf('btFirst')>=0 then AddActionBoundary('btFirstOnClick',False);
      if Buttons.IndexOf('btPrior')>=0 then AddActionBoundary('btPriorOnClick',False);
      if Buttons.IndexOf('btNext')>=0 then AddActionBoundary('btNextOnClick',False);
      if Buttons.IndexOf('btLast')>=0 then AddActionBoundary('btLastOnClick',False);
      if Buttons.IndexOf('btAppend')>=0 then begin
        AddActionBoundary('btAppendOnClick',False);
        AddActionBoundary('pmAppendUgMenuItemsOnClick',True);
      end;
      if Buttons.IndexOf('btDelete')>=0 then AddActionBoundary('btDeleteOnClick',False);
      if Buttons.IndexOf('btEditor')>=0 then AddActionBoundary('btEditorOnClick',False);
      if Buttons.IndexOf('btImport')>=0 then begin
        AddActionBoundary('btImportOnClick',False);
        AddActionBoundary('pmImportUgMenuItemsOnClick',True);
      end;
      if Buttons.IndexOf('btSave')>=0 then AddActionBoundary('btSaveOnClick',False);
      if Buttons.IndexOf('btCancel')>=0 then AddActionBoundary('btCancelOnClick',False);
      if Buttons.IndexOf('btAudit')>=0 then AddActionBoundary('btAuditOnClick',False);
      if Buttons.IndexOf('btUnAudit')>=0 then AddActionBoundary('btUnAuditOnClick',False);
      if Buttons.IndexOf('btRepulse')>=0 then AddActionBoundary('btRepulseOnClick',False);
      if Buttons.IndexOf('btAnnex')>=0 then AddActionBoundary('btAnnexOnClick',False);
      if Buttons.IndexOf('btClose')>=0 then AddActionBoundary('btCloseOnClick',False);
    end;
    AddCode('begin');AddCode('end.');
    LocalizeNoticeText;
    FormatCodeIndentation;
    WrapCodeLines;
    Lines.Add('object UgWebRunFrame: TUgWebRunFrame');Lines.Add('  Width = 1270');Lines.Add('  Height = 650');Lines.Add('  SyntaxType = ''PascalScript''');Lines.Add('  Events.Strings = (');
    if WriteMode then begin
      Lines.Add('    ''errorAlert|<This>.OnConfirm:errorAlertOnConfirm''');
      Lines.Add('    ''errorAlert|<This>.OnDismiss:errorAlertOnDismiss''');
    end;
    if Buttons.IndexOf('btQuery')>=0 then Lines.Add('    ''btQuery|<This>.OnClick:'+ActionHandler('btQueryOnClick')+'''');
    if Buttons.IndexOf('btFirst')>=0 then Lines.Add('    ''btFirst|<This>.OnClick:'+ActionHandler('btFirstOnClick')+'''');
    if Buttons.IndexOf('btPrior')>=0 then Lines.Add('    ''btPrior|<This>.OnClick:'+ActionHandler('btPriorOnClick')+'''');
    if Buttons.IndexOf('btNext')>=0 then Lines.Add('    ''btNext|<This>.OnClick:'+ActionHandler('btNextOnClick')+'''');
    if Buttons.IndexOf('btLast')>=0 then Lines.Add('    ''btLast|<This>.OnClick:'+ActionHandler('btLastOnClick')+'''');
    { 明细区行按钮：只绑勾选的（与生成的按钮一一对应）。行操作不改审批状态，直接绑原始入口。 }
    for I := 0 to 6 do
    begin
      DetailRowBtn := DetailRowButtonName(I);
      if (DetailRowBtn <> '') and (Buttons.IndexOf(DetailRowBtn) >= 0) then
        Lines.Add('    ''' + DetailRowBtn + '|<This>.OnClick:' + DetailRowBtn + 'OnClick''');
    end;
    if Buttons.IndexOf('btAppend')>=0 then Lines.Add('    ''btAppend|<This>.OnClick:'+ActionHandler('btAppendOnClick')+'''');
    if Buttons.IndexOf('btAppend')>=0 then Lines.Add('    ''pmAppend|<This>.UgMenuItemsOnClick:'+ActionHandler('pmAppendUgMenuItemsOnClick')+'''');
    if Buttons.IndexOf('btDelete')>=0 then Lines.Add('    ''btDelete|<This>.OnClick:'+ActionHandler('btDeleteOnClick')+'''');
    if Buttons.IndexOf('btEditor')>=0 then Lines.Add('    ''btEditor|<This>.OnClick:'+ActionHandler('btEditorOnClick')+'''');
    if Buttons.IndexOf('btImport')>=0 then begin Lines.Add('    ''btImport|<This>.OnClick:'+ActionHandler('btImportOnClick')+'''');Lines.Add('    ''pmImport|<This>.UgMenuItemsOnClick:'+ActionHandler('pmImportUgMenuItemsOnClick')+'''');end;
    if Buttons.IndexOf('btSave')>=0 then Lines.Add('    ''btSave|<This>.OnClick:'+ActionHandler('btSaveOnClick')+'''');
    if Buttons.IndexOf('btCancel')>=0 then Lines.Add('    ''btCancel|<This>.OnClick:'+ActionHandler('btCancelOnClick')+'''');
    if Buttons.IndexOf('btAudit')>=0 then Lines.Add('    ''btAudit|<This>.OnClick:'+ActionHandler('btAuditOnClick')+'''');
    if Buttons.IndexOf('btUnAudit')>=0 then Lines.Add('    ''btUnAudit|<This>.OnClick:'+ActionHandler('btUnAuditOnClick')+'''');
    if Buttons.IndexOf('btRepulse')>=0 then Lines.Add('    ''btRepulse|<This>.OnClick:'+ActionHandler('btRepulseOnClick')+'''');
    if Buttons.IndexOf('btAnnex')>=0 then Lines.Add('    ''btAnnex|<This>.OnClick:'+ActionHandler('btAnnexOnClick')+'''');
    if Buttons.IndexOf('btClose')>=0 then Lines.Add('    ''btClose|<This>.OnClick:'+ActionHandler('btCloseOnClick')+'''');
    if WriteMode then Lines.Add('    ''cdsMain|<This>.BeforePost:cdsMainBeforePost''');
    if WriteMode and (JoinFields.Count>0) then Lines.Add('    ''dsDetailed|<This>.OnDataChange:DetailJoinKeyChanged''');
    if GridPersonalization then Lines.Add('    ''gridDetailed|<This>.OnAjaxEvent:gridDetailedOnAjaxEvent''');
    for I:=0 to MainFields.Count-1 do if IsGridType(MainTypes[I])then begin DropValue:=TJSONObject.ParseJSONValue(MainOptions[I]);try if DynamicLookup(TJSONObject(DropValue))then Lines.Add('    ''a'+MainFields[I]+'|<This>.OnExtEditValueChange:a'+MainFields[I]+'OnExtEditValueChange''');finally FreeAndNil(DropValue);end;end;
    for I:=0 to DetailFields.Count-1 do if IsGridType(DetailTypes[I])then begin
      DropValue:=TJSONObject.ParseJSONValue(DetailOptions[I]);
      try
        if DynamicLookup(TJSONObject(DropValue))then begin
          Lines.Add('    ''grid_a'+DetailFields[I]+'|<This>.OnExpand:grid_a'+DetailFields[I]+'OnExpand''');
          Lines.Add('    ''grid_a'+DetailFields[I]+'|<This>.OnExtEditValueChange:grid_a'+DetailFields[I]+'OnExtEditValueChange''');
        end;
      finally FreeAndNil(DropValue);end;
    end;
    Lines.Add('    ''Self|<This>.OnAfterRunScript:UgWebRunFrameOnAfterRunScript'')');Lines.Add('  Codes.Strings = (');for V in Code do Lines.Add('    '+Q(V));Lines.Add('  )');
    Lines.Add('  object pToolbar: TUgContainerPanel');Lines.Add('    Align = alTop');Lines.Add('    Height = 33');X:=5;
    if Buttons.IndexOf('btQuery')>=0 then begin AddButton('btQuery','查询',X);Inc(X,65);AddSeparator('tabQueryGroup',X);end;
    if Buttons.IndexOf('btFirst')>=0 then begin AddButton('btFirst','首笔',X);Inc(X,65);end;
    if Buttons.IndexOf('btPrior')>=0 then begin AddButton('btPrior','前笔',X);Inc(X,65);end;
    if Buttons.IndexOf('btNext')>=0 then begin AddButton('btNext','后笔',X);Inc(X,65);end;
    if Buttons.IndexOf('btLast')>=0 then begin AddButton('btLast','末笔',X);Inc(X,65);AddSeparator('tabNavigateGroup',X);end;
    if Buttons.IndexOf('btAppend')>=0 then begin AddButton('btAppend','新增',X);Inc(X,80);end;
    if Buttons.IndexOf('btDelete')>=0 then begin AddButton('btDelete','删除',X);Inc(X,65);end;
    if Buttons.IndexOf('btEditor')>=0 then begin AddButton('btEditor','修改',X);Inc(X,65);end;
    if Buttons.IndexOf('btImport')>=0 then begin AddButton('btImport','导入',X);Inc(X,80);AddSeparator('tabEditGroup',X);end;
    if Buttons.IndexOf('btSave')>=0 then begin AddButton('btSave','保存',X);Inc(X,65);end;
    if Buttons.IndexOf('btCancel')>=0 then begin AddButton('btCancel','撤销',X);Inc(X,65);AddSeparator('tabSaveGroup',X);end;
    if Buttons.IndexOf('btAudit')>=0 then begin AddButton('btAudit','审核',X);Inc(X,65);end;
    if Buttons.IndexOf('btUnAudit')>=0 then begin AddButton('btUnAudit','消审',X);Inc(X,65);end;
    if Buttons.IndexOf('btRepulse')>=0 then begin AddButton('btRepulse','撤回',X);Inc(X,65);AddSeparator('tabApprovalGroup',X);end;
    if Buttons.IndexOf('btPrint')>=0 then begin AddButton('btPrint','打印',X);Inc(X,80);AddSeparator('tabPrintGroup',X);end;
    if Buttons.IndexOf('btAnnex')>=0 then begin AddButton('btAnnex','附件',X);Inc(X,65);AddSeparator('tabAnnexGroup',X);end;
    if Buttons.IndexOf('btClose')>=0 then AddButton('btClose','关闭',X);
    { 工具栏底部的 1px 分隔线（原版 mtMasterSlave 里叫 topline，生成器早前把它丢了）。 }
    Lines.Add('    object topline: TUgContainerPanel');
    Lines.Add('      Align = alBottom');
    Lines.Add('      Top = 32');
    Lines.Add('      Width = 1270');
    Lines.Add('      Height = 1');
    Lines.Add('      Hint = ' + QuotedStr(''));
    Lines.Add('      ParentColor = False');
    Lines.Add('      Color = 13093060');
    Lines.Add('    end');
    Lines.Add('  end');
    if Buttons.IndexOf('btImport')>=0 then begin Lines.Add('  object pmImport: TUgPopupMenu');Lines.Add('    Items = <');Lines.Add('      item');Lines.Add('        Caption = '+Q('文本格式'));Lines.Add('      end');Lines.Add('      item');Lines.Add('        Caption = '+Q('电子表格'));Lines.Add('      end');for I:=0 to ImportFrameCaptions.Count-1 do begin Lines.Add('      item');Lines.Add('        Caption = '+Q(ImportFrameCaptions[I]));Lines.Add('      end');end;Lines.Add('    >');Lines.Add('  end');end;
    if Buttons.IndexOf('btAppend')>=0 then begin
      Lines.Add('  object pmAppend: TUgPopupMenu');Lines.Add('    Items = <');
      Lines.Add('      item');Lines.Add('        Caption = '+Q('空白'));Lines.Add('      end');
      Lines.Add('      item');Lines.Add('        Caption = '+Q('复制'));Lines.Add('      end');
      Lines.Add('    >');Lines.Add('  end');
    end;
    MainHeight:=190;Y:=10;
    if HasLayout then
    begin
      { 记录区独立布局：按布局的列数/列宽打包（跨列放不下就换行），逐字段算好 Left/Top/Width/Height，
        高度取最后一行；位置 Top 时容器用 alTop，Left 时用 alLeft（宽度按列数推导）。
        memo 仍占 170、其余 50，与未配布局时同一套规则。 }
      LayStep:=LayFieldWidth+20;
      LayRowTop:=10;LayRowHeight:=0;LayRowCol:=0;
      SetLength(LayPosX,MainDisplayOrder.Count);SetLength(LayPosY,MainDisplayOrder.Count);
      SetLength(LayPosW,MainDisplayOrder.Count);SetLength(LayPosH,MainDisplayOrder.Count);
      for J:=0 to MainDisplayOrder.Count-1 do
      begin
        I:=MainFields.IndexOf(FieldPart(MainDisplayOrder[J],MAlias));
        if I<0 then Continue;
        if LayRowOf(MainFields[I])<0 then
        begin
          { 布局里没显示的字段不占格子：它照常生成控件（Visible=False），先记下高度，
            等可见区高度算出来再把它放到可见区下面（Y 用负数占位，下面统一改写）。 }
          LayWidth:=LayWidthOf(MainFields[I]);
          if LayWidth<=0 then LayWidth:=LayFieldWidth;
          LayPosX[J]:=10;LayPosY[J]:=-1;LayPosW[J]:=LayWidth;
          LayPosH[J]:=MainFieldHeight(MainTypes[I]);
          Continue;
        end;
        LaySpan:=LaySpanOf(MainFields[I]);
        if LayRowCol+LaySpan>LayColumns then
        begin
          Inc(LayRowTop,LayRowHeight+10);LayRowCol:=0;LayRowHeight:=0;
        end;
        FieldHeight:=MainFieldHeight(MainTypes[I]);
        LayPosX[J]:=10+LayRowCol*LayStep;
        LayPosY[J]:=LayRowTop;
        { 单字段宽度（fdWIDTH）优先；填 0 用"每列宽度"，跨列时按跨的列数加列距。 }
        LayPosW[J]:=LayFieldWidth*LaySpan+(LaySpan-1)*20;
        LayWidth:=LayWidthOf(MainFields[I]);
        if LayWidth>0 then LayPosW[J]:=LayWidth;
        LayPosH[J]:=FieldHeight;
        if FieldHeight>LayRowHeight then LayRowHeight:=FieldHeight;
        Inc(LayRowCol,LaySpan);
      end;
      if LayRowCol>0 then MainHeight:=LayRowTop+LayRowHeight+10 else MainHeight:=LayRowTop+10;
      for J:=0 to MainDisplayOrder.Count-1 do
        if LayPosY[J]<0 then LayPosY[J]:=MainHeight;
    end
    else
    begin
      for J:=0 to MainDisplayOrder.Count-1 do begin
        I:=MainFields.IndexOf(FieldPart(MainDisplayOrder[J],MAlias));
        if J mod 3=0 then Y:=10;
        if SameText(MainTypes[I],'memo')then Inc(Y,180)else Inc(Y,60);
        if Y>MainHeight then MainHeight:=Y;
      end;
    end;
    Lines.Add('  object pMain: TUgContainerPanel');
    if HasLayout and SameText(LayPosition,'Left') then
    begin
      Lines.Add('    Align = alLeft');
      Lines.Add('    Width = '+IntToStr(LayColumns*LayFieldWidth+(LayColumns-1)*20+20));
    end
    else
    begin
      Lines.Add('    Align = alTop');
      Lines.Add('    Height = '+IntToStr(MainHeight));
    end;
    for J:=0 to MainDisplayOrder.Count-1 do begin
      I:=MainFields.IndexOf(FieldPart(MainDisplayOrder[J],MAlias));
      { 布局里可能残留当前数据结构已经没有的字段行；MainDisplayOrder 本来就是按 MainFields
        构造的，这里只是把"下标的 -1"挡在取值之前（下标 -1 会读越界地址，生成器 AV 的根因）。 }
      if I<0 then Continue;
      if HasLayout then
      begin
        X:=LayPosX[J];Y:=LayPosY[J];LayWidth:=LayPosW[J];FieldHeight:=LayPosH[J];
      end
      else
      begin
        X:=10+(J div 3)*210;if J mod 3=0 then Y:=10;
        if SameText(MainTypes[I],'memo')then FieldHeight:=170 else FieldHeight:=50;
        LayWidth:=200;
      end;
      Lines.Add('    object a'+MainFields[I]+': '+MainControlClass(MainTypes[I]));Lines.Add('      Left = '+IntToStr(X));Lines.Add('      Top = '+IntToStr(Y));
      Lines.Add('      Width = '+IntToStr(LayWidth));Lines.Add('      Height = '+IntToStr(FieldHeight));Inc(Y,FieldHeight+10);
      // Preserve lookup keys: only ordinary text edits follow module CharCase.
      if SameText(MainTypes[I],'edit')then begin
        if SameText(Trim(S(Settings,'文本类型')),'Upper')then Lines.Add('      CharCase = ecUpperCase');
        if SameText(Trim(S(Settings,'文本类型')),'Lower')then Lines.Add('      CharCase = ecLowerCase');
      end;
      if IsLookupType(MainTypes[I])then begin LookupDataName:='lookupMain'+MainFields[I];AddLookupProperties(MainTypes[I],MainOptions[I],LookupDataName);end;
      if MainTypes[I]='check' then begin Lines.Add('      Caption = ''''');Lines.Add('      ValueChecked = ''1''');Lines.Add('      ValueUnchecked = ''0''');end;
      if SameText(MainTypes[I],'time')or SameText(MainTypes[I],'date')or SameText(MainTypes[I],'datetime')then begin if SameText(MainTypes[I],'datetime')then Lines.Add('      Kind = tUniDateTime')else if SameText(MainTypes[I],'time')then Lines.Add('      Kind = tUniTime')else Lines.Add('      Kind = tUniDate');Lines.Add('      DateTime = 0');Lines.Add('      DateFormat = ''yyyy-MM-dd''');Lines.Add('      TimeFormat = ''HH:mm:ss''');Lines.Add('      ShowBlankDate = True');end;
      Lines.Add('      DataField = '+QuotedStr(MainFields[I]));Lines.Add('      DataSource = dsMain');Lines.Add('      ReadOnly = True');
      { 标题：布局里写了就用布局的，否则沿用数据结构「列」的标题（未配布局时逐字节同原样）。 }
      LayCaptionText:='';
      if HasLayout then LayCaptionText:=LayCaptionOf(MainFields[I]);
      if LayCaptionText='' then LayCaptionText:=MainCaptions[I];
      Lines.Add('      FieldLabel = '+Q(LayCaptionText));Lines.Add('      FieldLabelAlign = laTop');
      if RequiredMain.IndexOf(MainFields[I]) >= 0 then
        Lines.Add('      FieldLabelFont.Color = clRed');
      if HiddenMain.IndexOf(MainFields[I])>=0 then Lines.Add('      Visible = False')
      else begin
        { 布局里没显示（fdVISIBLE=False）或没列进布局的字段：**控件照常生成、只是 Visible=False**。
          不能改成"不生成控件" —— 脚本里 SetEditState 的 ReadOnly 循环、Loada<字段>Items、
          动态查找事件、必填聚焦、导入/审批路径都会引用 a<字段>，少一个就是"标识符未宣告"。 }
        if HasLayout and (LayRowOf(MainFields[I])<0) then Lines.Add('      Visible = False');
      end;
      Lines.Add('    end');
    end;
    { 记录区底部的 1px 分隔线（原版 mtMasterSlave 里叫 lbEditControls，生成器早前把它丢了）——
      宿主 2026-09-21 反馈"工具栏、记录区、表格没有线条分隔，原版是有分隔线的"。 }
    Lines.Add('    object lbEditControls: TUgContainerPanel');
    if HasLayout and SameText(LayPosition,'Left') then
    begin
      { 记录区在左边时，这条线是记录区与表格之间的**竖线**（宽度 1px，高度由对齐决定），
        与 mtListEditor 的 Left 布局同一做法。 }
      Lines.Add('      Align = alRight');
      Lines.Add('      Width = 1');
    end
    else
    begin
      Lines.Add('      Align = alBottom');
      Lines.Add('      Top = ' + IntToStr(MainHeight - 1));
      Lines.Add('      Width = 1270');
      Lines.Add('      Height = 1');
    end;
    Lines.Add('      Hint = ' + QuotedStr(''));
    Lines.Add('      ParentColor = False');
    Lines.Add('      Color = 13093060');
    Lines.Add('    end');
    Lines.Add('  end');
    GroupMainControls;
    GridOptions:='dgEditing, dgTitles, dgIndicator, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow';if Yes(S(Settings,'表格序号'))then GridOptions:=GridOptions+', dgRowNumbers';if Yes(S(Settings,'字段宽度'))then GridOptions:=GridOptions+', dgColumnResize';if Yes(S(Settings,'字段移动'))then GridOptions:=GridOptions+', dgColumnMove';
    Lines.Add('  object gridDetailed: TUgDBGrid');
    Lines.Add('    Align = alClient');
    Lines.Add('    DataSource = dsDetailed');
    Lines.Add('    ReadOnly = True');
    Lines.Add('    Options = ['+GridOptions+']');
    Lines.Add('    WebOptions.Paged = False');
    Lines.Add('    Columns = <');for I:=0 to DetailFields.Count-1 do begin Lines.Add('      item');
    Lines.Add('        FieldName = '+QuotedStr(DetailFields[I]));
    Lines.Add('        Title.Caption = '+Q(DetailCaptions[I]));
    if RequiredDetail.IndexOf(DetailFields[I]) >= 0 then
      Lines.Add('        Title.Font.Color = clRed');
    V:=DetailGroup(DAlias+'.'+DetailFields[I]);if V<>'' then Lines.Add('        GroupHeader = '+Q(V));
    Lines.Add('        Width = 120');
    Lines.Add('        Menu.ColumnHideable = '+BoolToStr(Yes(S(Settings,'字段显隐')),True));if HiddenDetail.IndexOf(DetailFields[I])>=0 then Lines.Add('        Visible = False');if(DetailEditorClass(DetailTypes[I])<>'')and not DetailPopup(DetailTypes[I])then Lines.Add('        Editor = grid_a'+DetailFields[I]);if DetailPopup(DetailTypes[I])or(not WriteMode)or SameText(DetailFields[I],DetailKey)or SameText(DetailFields[I],DetailLine)then Lines.Add('        ReadOnly = True');
    Lines.Add('      end');end;
    for I:=0 to JoinFields.Count-1 do begin
      Lines.Add('      item');Lines.Add('        FieldName = '+QuotedStr(JoinFieldAliases[I]+JoinFields[I]));
      Lines.Add('        Title.Caption = '+Q(JoinCaptions[I]));Lines.Add('        Width = 120');
      Lines.Add('        ReadOnly = True');
      V:=DetailGroup(JoinFieldAliases[I]+'.'+JoinFields[I]);if V<>'' then Lines.Add('        GroupHeader = '+Q(V));
      Lines.Add('      end');
    end;
    Lines.Add('    >');
    Lines.Add('  end');
    OrderDetailColumns;
    EmitDetailRowBar;
    Lines.Add('  object pHiddenEditors: TUgHiddenPanel');
    // Match the original design-time hidden container without changing ownership.
    Lines.Add('    Left = 1100');
    Lines.Add('    Top = 384');
    Lines.Add('    Width = 160');
    Lines.Add('    Height = 256');
    Lines.Add('    Visible = True');
    for I:=0 to DetailFields.Count-1 do if DetailEditorClass(DetailTypes[I])<>'' then begin
      Lines.Add('    object grid_a'+DetailFields[I]+': '+DetailEditorClass(DetailTypes[I]));Lines.Add('      Left = 10');Lines.Add('      Top = '+IntToStr(10+I*30));Lines.Add('      Width = 180');Lines.Add('      Height = 25');
      // Detail lookup editors retain their default case to preserve returned keys.
      if IsLookupType(DetailTypes[I])then begin LookupDataName:='lookupDetail'+DetailFields[I];AddLookupProperties(DetailTypes[I],DetailOptions[I],LookupDataName);end;
      if DetailTypes[I]='check' then Lines.Add('      Caption = ''''');
      if SameText(DetailTypes[I],'time')or SameText(DetailTypes[I],'date')or SameText(DetailTypes[I],'datetime')then begin if SameText(DetailTypes[I],'datetime')then Lines.Add('      Kind = tUniDateTime')else if SameText(DetailTypes[I],'time')then Lines.Add('      Kind = tUniTime')else Lines.Add('      Kind = tUniDate');Lines.Add('      DateTime = 0');Lines.Add('      DateFormat = ''yyyy-MM-dd''');Lines.Add('      TimeFormat = ''HH:mm:ss''');Lines.Add('      ShowBlankDate = True');end;
      Lines.Add('    end');
    end;Lines.Add('  end');
    for I:=0 to DetailFields.Count-1 do if IsLookupType(DetailTypes[I])then begin
      Lines.Add('  object detailLookupBridge'+DetailFields[I]+': TConfigurationDetailLookupBridge');
      Lines.Add('    Grid = gridDetailed');
      Lines.Add('    Editor = grid_a'+DetailFields[I]);
      Lines.Add('    FieldName = '+QuotedStr(DetailFields[I]));
      Lines.Add('    Editable = '+BoolToStr(WriteMode and not SameText(DetailFields[I],DetailKey) and not SameText(DetailFields[I],DetailLine),True));
      Lines.Add('  end');
    end;
    Lines.Add('  object Imgs: TUGIconClsList');
    Lines.Add('    IconText = '+Q('icon iconfont icon-chaxun'#13#10+
      'icon iconfont icon-quanxuan'#13#10+'icon iconfont icon-fanxuan'#13#10+
      'icon iconfont icon-skipprevious'#13#10+'icon iconfont icon-xiangzuo'#13#10+
      'icon iconfont icon-xiangyou'#13#10+'icon iconfont icon-skipnext'#13#10+
      'icon iconfont icon-addEdge'#13#10+'icon iconfont icon-shanchu1'#13#10+
      'icon iconfont icon-xiugai1'#13#10+'icon iconfont icon-ico_daoru_xuanzhong'#13#10+
      'icon iconfont icon-baocun'#13#10+'icon iconfont icon-chexiao4'#13#10+
      'icon iconfont icon-shenhe'#13#10+'icon iconfont icon-quxiaoshenhe'#13#10+
      'icon iconfont icon-dahui'#13#10+'icon iconfont icon-web-icon-'#13#10+
      'icon iconfont icon-dayin4'#13#10+'icon iconfont icon-fujian'#13#10+
      'icon iconfont icon-bangdingpingtai'#13#10+'icon iconfont icon-xiangshang'#13#10+
      'icon iconfont icon-xiangxia'#13#10+'icon iconfont icon-guanbishixin'#13#10+
      'icon iconfont icon-guanbi3'#13#10+'icon iconfont icon-gouxuan'#13#10+
      'icon iconfont icon-cuocha_kuai'#13#10+'icon iconfont icon-shezhi_2'#13#10));
    Lines.Add('  end');
    Lines.Add('  object cdsMain: TUgClientDataSet');Lines.Add('    Aggregates = <>');Lines.Add('    Params = <>');Lines.Add('  end');Lines.Add('  object dsMain: TUgDataSource');Lines.Add('    DataSet = cdsMain');Lines.Add('  end');Lines.Add('  object cdsDetailed: TUgClientDataSet');Lines.Add('    Aggregates = <>');Lines.Add('    Params = <>');Lines.Add('  end');Lines.Add('  object dsDetailed: TUgDataSource');Lines.Add('    DataSet = cdsDetailed');Lines.Add('  end');
    for I:=0 to MainFields.Count-1 do if IsLookupType(MainTypes[I])then begin DropValue:=TJSONObject.ParseJSONValue(MainOptions[I]);try Drop:=TJSONObject(DropValue);K:=LookupSQL(Drop);if IsGridType(MainTypes[I])and DynamicLookup(Drop)then K:='select ug_grid.* from ('+K+') ug_grid where 1 = 2';Lines.Add('  object lookupMain'+MainFields[I]+': TUgClientDataSet');Lines.Add('    DataNodeName = '+Q(S(Config,'TWebDataNodeName')));Lines.Add('    CommandText = '+Q(K));Lines.Add('    SelectMaxRecCount = '+IntToStr(StrToIntDef(S(Drop,'seMaxRecordCount'),100)));Lines.Add('    PageRowCount = -1');if(not IsGridType(MainTypes[I]))and SameText(S(Drop,'cbGridPageSetting'),'Open')then Lines.Add('    Tag = '+IntToStr(StrToIntDef(S(Drop,'sePageSize'),50)));Lines.Add('    Active = False');Lines.Add('  end');finally FreeAndNil(DropValue);end;end;
    for I:=0 to DetailFields.Count-1 do if IsLookupType(DetailTypes[I])then begin DropValue:=TJSONObject.ParseJSONValue(DetailOptions[I]);try Drop:=TJSONObject(DropValue);K:=LookupSQL(Drop);if IsGridType(DetailTypes[I])and DynamicLookup(Drop)then K:='select ug_grid.* from ('+K+') ug_grid where 1 = 2';Lines.Add('  object lookupDetail'+DetailFields[I]+': TUgClientDataSet');Lines.Add('    DataNodeName = '+Q(S(Config,'TWebDataNodeName')));Lines.Add('    CommandText = '+Q(K));Lines.Add('    SelectMaxRecCount = '+IntToStr(StrToIntDef(S(Drop,'seMaxRecordCount'),100)));Lines.Add('    PageRowCount = -1');if(not IsGridType(DetailTypes[I]))and SameText(S(Drop,'cbGridPageSetting'),'Open')then Lines.Add('    Tag = '+IntToStr(StrToIntDef(S(Drop,'sePageSize'),50)));Lines.Add('    Active = False');Lines.Add('  end');finally FreeAndNil(DropValue);end;end;
    if WriteMode then begin
      Lines.Add('  object noticeAlert: TUgSweetAlert');
      Lines.Add('    AlertType = atInfo');
      Lines.Add('    ShowConfirmButton = True');
      Lines.Add('    ShowCancelButton = False');
      Lines.Add('  end');
      Lines.Add('  object confirmAlert: TUgSweetAlert');
      Lines.Add('    AlertType = atQuestion');
      Lines.Add('    ShowConfirmButton = True');
      Lines.Add('    ShowCancelButton = True');
      Lines.Add('    FocusCancel = True');
      Lines.Add('    AllowOutsideClick = False');
      Lines.Add('    AllowEscapeKey = True');
      Lines.Add('  end');
      Lines.Add('  object inputAlert: TUgSweetAlert');
      Lines.Add('    AlertType = atQuestion');
      Lines.Add('    InputType = ItTextArea');
      Lines.Add('    InputAutoTrim = False');
      Lines.Add('    ShowConfirmButton = True');
      Lines.Add('    ShowCancelButton = True');
      Lines.Add('    AllowOutsideClick = False');
      Lines.Add('    AllowEscapeKey = True');
      Lines.Add('  end');
      Lines.Add('  object errorAlert: TUgSweetAlert');
      Lines.Add('    AlertType = atError');
      Lines.Add('    ShowConfirmButton = True');
      Lines.Add('    ShowCancelButton = False');
      Lines.Add('  end');
    end;
    Lines.Add('end');
    // Design-time positions: match original 80px spacing, wrap after 12 icons.
    X:=0;I:=0;
    while I<Lines.Count do begin
      V:=Lines[I];
      if(Copy(V,1,9)='  object ')and
        ((Pos(': TUgClientDataSet',V)>0)or(Pos(': TUgDataSource',V)>0)or
         (Pos(': TUgPopupMenu',V)>0)or(Pos(': TUGIconClsList',V)>0)or
         (Pos(': TConfigurationDetailLookupBridge',V)>0)or(Pos(': TUgSweetAlert',V)>0))then begin
        Lines.Insert(I+1,'    Left = '+IntToStr(20+(X mod 12)*80));
        Lines.Insert(I+2,'    Top = '+IntToStr(550+(X div 12)*60));
        Inc(X);Inc(I,2);
      end;
      Inc(I);
    end;
    { 图标要在 DFM 全部拼好之后再补：EmitDetailRowBar 执行时 Imgs 还没进 Lines（早前放在那里，
      结果一个都没追加进去，测试报"Imgs 缺少图标"）。 }
    if Buttons.IndexOf('btDetailAppend') >= 0 then EnsureDetailIcons;
    DFM:=Lines.Text;Result:=True;
  finally
    MainDisplayOrder.Free;DetailDisplayOrder.Free;LayOrder.Free;
    RootKeys.Free;OrderedTables.Free;JoinFieldAliases.Free;
    JoinFields.Free;JoinCaptions.Free;DropValue.Free;CheckJSON.Free;AutoJSON.Free;MainUniqueJSON.Free;DetailUniqueJSON.Free;ApprovalJSON.Free;Buttons.Free;MainFields.Free;MainCaptions.Free;MainTypes.Free;MainOptions.Free;DetailFields.Free;DetailCaptions.Free;DetailTypes.Free;DetailOptions.Free;Code.Free;Lines.Free;RequiredMain.Free;RequiredDetail.Free;UniqueMain.Free;UniqueDetail.Free;HiddenMain.Free;HiddenDetail.Free;CheckDetailFields.Free;CheckDetailCaptions.Free;CheckTables.Free;CheckSourceFields.Free;ImportFrameCaptions.Free;ImportFrameNames.Free;ImportFrameMulti.Free;
  end;
end;
end.
