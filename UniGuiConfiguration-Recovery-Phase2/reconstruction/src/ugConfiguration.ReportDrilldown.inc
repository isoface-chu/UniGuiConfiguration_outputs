procedure TReportPlan.AddDrillCode(Code: TStrings);
var I: Integer; Allowed: string;
  procedure A(const S:string); begin Code.Add(S); end;
begin
  if not HasDrilldown then Exit;
  A('//明细使用最后一次成功汇总的查询快照，不读取尚未提交的查询控件');
  A('var ReportPendingSQL: string; ReportReady: Boolean = False;');
  A('  ReportDetailBusy: Boolean = False;');
  A('//原生复制查询快照，再解析 SQL 补入分组参数；不使用脚本默认索引');
  A('procedure PrepareReportParams(Target: TUgClientDataSet; SourceParams: TParams; const SQL: string);');
  A('var TargetParams: TParams;');
  A('begin');
  A('  if (SourceParams = nil) or (Target = nil) then');
  A('    RaiseException(UGMM.LT(''报表查询参数集合未初始化。''));');
  A('  Target.Close;');
  A('  Target.CommandText := '''';');
  A('  TargetParams := Target.Params;');
  A('  TargetParams.Assign(SourceParams);');
  A('  Target.CommandText := SQL;'); A('end;');
  A('procedure SyncReportDetail;');
  A('begin');
  A('  ReportDetailBusy := True;'); A('  try');
  A('    edDetailPage.Text := IntToStr(cdsReportDetail.PageIndex);');
  A('    btDetailFirst.Enabled := cdsReportDetail.Active and (cdsReportDetail.PageIndex > 1);');
  A('    btDetailPrior.Enabled := btDetailFirst.Enabled;');
  A('    btDetailNext.Enabled := cdsReportDetail.Active and (cdsReportDetail.PageIndex < cdsReportDetail.PageCount);');
  A('    btDetailLast.Enabled := btDetailNext.Enabled;');
  A('    edDetailPage.Enabled := cdsReportDetail.Active and (cdsReportDetail.PageCount > 0);');
  A('    if not cdsReportDetail.Active then');
  A('    begin');
  A('      edDetailPage.Text := ''0'';');
  A('      capDetailPage.Caption := UGMM.LT(''请双击汇总统计列查看明细'');');
  A('      Exit;'); A('    end;');
  A('    capDetailPage.Caption := Format(UGMM.LT(''第 %s / %s 页，共 %s 行''),');
  A('      [IntToStr(cdsReportDetail.PageIndex), IntToStr(cdsReportDetail.PageCount), IntToStr(cdsReportDetail.TotalRecordCount)]);');
  A('  finally ReportDetailBusy := False; end;'); A('end;');
  if SameText(FSortMode,'ColumnSort') or SameText(FSortMode,'MultiColumnSort') then begin
    A('//明细仅对当前已加载页排序，不改变汇总或钻取条件');
    A('procedure SortReportDetailPage(const Fields, DescFields: string);'); A('begin');
    A('  if not cdsReportDetail.Active then Exit;');
    A('  cdsReportDetail.IndexName := '''';');
    A('  cdsReportDetail.IndexDefs.Update;');
    A('  if cdsReportDetail.IndexDefs.IndexOf(''UgReportDetailSort'') >= 0 then cdsReportDetail.DeleteIndex(''UgReportDetailSort'');');
    A('  if Fields <> '''' then begin');
    A('    cdsReportDetail.AddIndex(''UgReportDetailSort'', Fields, 0, DescFields, '''', 0);');
    A('    cdsReportDetail.IndexName := ''UgReportDetailSort'';'); A('  end;');
    A('  cdsReportDetail.First;'); A('end;');
    if SameText(FSortMode,'ColumnSort') then begin
      A('procedure gridReportDetailOnColumnSort(Column: TUniDBGridColumn; Direction: Boolean);'); A('begin');
      A('  if Direction then SortReportDetailPage(Column.FieldName, Column.FieldName)');
      A('  else SortReportDetailPage(Column.FieldName, '''');'); A('end;');
    end else begin
      A('procedure gridReportDetailOnMultiColumnSort(Columns: TUniDBGridColumnArr; Directions: TUniSortDirections);');
      A('begin SortReportDetailPage(Columns, Directions); end;');
    end;
  end;
  if FFiltering then begin
    A('procedure LoadReportFilteredDetail;'); A('var SQL: string;'); A('begin');
    A('  if not ReportReady then Exit;');
    A('  if cdsReportDetailSource.CommandText = '''' then Exit;');
    A('  SQL := cdsReportDetailSource.CommandText;');
    FilterSQL(Code,True);
    A('  PrepareReportParams(cdsReportDetail, cdsReportDetailSource.Params, SQL);');
    BindFilters(Code,True);
    A('  cdsReportDetail.ClearPageInformation;');
    A('  cdsReportDetail.PageRowCount := StrToIntDef(cbDetailSize.Text,50);');
    A('  try cdsReportDetail.Open; finally SyncReportDetail; end;'); A('end;');
    A('procedure gridReportDetailOnColumnFilter(Sender: TUniDBGrid; const Column: TUniDBGridColumn; const Value: Variant);');
    A('begin LoadReportFilteredDetail; end;');
    A('procedure gridReportDetailOnClearFilters(Sender: TObject);'); A('begin');
    for I:=0 to FRawFields.Count-1 do A('  '+FilterEditor(FRawFields[I],True)+'.Text := '''';');
    A('  LoadReportFilteredDetail;'); A('end;');
  end;
  A('//仅配置允许的统计列可双击；Null 分组使用 IS NULL，其他值使用参数');
  A('procedure gridMainOnDblClick(Sender: TObject);');
  A('var SQL, Col: string;'); A('begin');
  A('  if not ReportReady then Exit;');
  A('  if not cdsMain.Active then Exit;'); A('  if cdsMain.IsEmpty then Exit;');
  A('  if (gridMain.CurrCol < 0) or (gridMain.CurrCol >= gridMain.Columns.Count) then Exit;');
  A('  Col := gridMain.Columns[gridMain.CurrCol].FieldName;');
  Allowed:='';
  for I:=0 to FDrillColumns.Count-1 do begin
    if Allowed<>'' then Allowed:=Allowed+' and ';
    Allowed:=Allowed+'(Col <> '+QuotedStr(FDrillColumns[I])+')';
  end;
  A('  if '+Allowed+' then Exit;');
  A('  cdsReportDetail.Close;');
  A('  SQL := ''select rpt.* from ('' + cdsReportSnapshot.CommandText + '') rpt where 1=1'';');
  for I:=0 to FGroups.Count-1 do begin
    A('  if cdsMain.FieldByName('+QuotedStr(FGroupOutputs[I])+').IsNull then');
    A('    SQL := SQL + '+QuotedStr(' and '+FGroups[I]+' is null'));
    A('  else SQL := SQL + '+QuotedStr(' and '+FGroups[I]+' = :__rgrp'+IntToStr(I))+';');
  end;
  A('  PrepareReportParams(cdsReportDetail, cdsReportSnapshot.Params, SQL);');
  for I:=0 to FGroups.Count-1 do begin
    A('  if not cdsMain.FieldByName('+QuotedStr(FGroupOutputs[I])+').IsNull then');
    A('  begin');
    A('    cdsReportDetail.ParamByName('+QuotedStr('__rgrp'+IntToStr(I))+').DataType := cdsMain.FieldByName('+QuotedStr(FGroupOutputs[I])+').DataType;');
    A('    cdsReportDetail.ParamByName('+QuotedStr('__rgrp'+IntToStr(I))+').Value := cdsMain.FieldByName('+QuotedStr(FGroupOutputs[I])+').Value;');
    A('  end;');
  end;
  if FFiltering then begin
    A('  PrepareReportParams(cdsReportDetailSource, cdsReportDetail.Params, SQL);');
    for I:=0 to FRawFields.Count-1 do A('  '+FilterEditor(FRawFields[I],True)+'.Text := '''';');
    A('  LoadReportFilteredDetail;');
  end else begin
  A('  cdsReportDetail.ClearPageInformation;');
  A('  cdsReportDetail.PageRowCount := StrToIntDef(cbDetailSize.Text,50);');
  A('  cdsReportDetail.Open;'); A('  SyncReportDetail;');
  end;
  A('  reportPages.ActivePage := reportDetailPage;'); A('end;');
  A('//明细独立分页，始终沿用本次钻取的 SQL 和参数');
  A('procedure GoReportDetail(Target: Integer);'); A('begin');
  A('  if ReportDetailBusy or not cdsReportDetail.Active then Exit;');
  A('  try');
  A('    if (Target >= 1) and (Target <= cdsReportDetail.PageCount) then cdsReportDetail.PageIndex := Target;');
  A('  finally SyncReportDetail; end;'); A('end;');
  A('procedure btDetailFirstOnClick(Sender: TObject);'); A('begin GoReportDetail(1); end;');
  A('procedure btDetailPriorOnClick(Sender: TObject);'); A('begin GoReportDetail(cdsReportDetail.PageIndex - 1); end;');
  A('procedure btDetailNextOnClick(Sender: TObject);'); A('begin GoReportDetail(cdsReportDetail.PageIndex + 1); end;');
  A('procedure btDetailLastOnClick(Sender: TObject);'); A('begin GoReportDetail(cdsReportDetail.PageCount); end;');
  A('procedure edDetailPageOnChange(Sender: TObject);'); A('begin GoReportDetail(StrToIntDef(edDetailPage.Text,-1)); end;');
  A('procedure cbDetailSizeOnChange(Sender: TObject);'); A('var N: Integer;'); A('begin');
  A('  if ReportDetailBusy or not cdsReportDetail.Active then Exit;');
  A('  N := StrToIntDef(cbDetailSize.Text,50);');
  A('  if (N < 1) or (N > 5000) or (N = cdsReportDetail.PageRowCount) then Exit;');
  A('  try'); A('    cdsReportDetail.Close; cdsReportDetail.ClearPageInformation;');
  A('    cdsReportDetail.PageRowCount := N; cdsReportDetail.Open;');
  A('  finally SyncReportDetail; end;'); A('end;');
end;

procedure TReportPlan.AddDrillEvents(Lines: TStrings);
var S:string;
begin
  if not HasDrilldown then Exit;
  Lines.Add('    ''gridMain|<This>.OnDblClick:gridMainOnDblClick''');
  if SameText(FSortMode,'ColumnSort') then
    Lines.Add('    ''gridReportDetail|<This>.OnColumnSort:gridReportDetailOnColumnSort''');
  if SameText(FSortMode,'MultiColumnSort') then
    Lines.Add('    ''gridReportDetail|<This>.OnMultiColumnSort:gridReportDetailOnMultiColumnSort''');
  if FFiltering then begin
    Lines.Add('    ''gridReportDetail|<This>.OnColumnFilter:gridReportDetailOnColumnFilter''');
    Lines.Add('    ''gridReportDetail|<This>.OnClearFilters:gridReportDetailOnClearFilters''');
  end;
  for S in TArray<string>.Create('btDetailFirst','btDetailPrior','btDetailNext','btDetailLast') do
    Lines.Add('    '+QuotedStr(S+'|<This>.OnClick:'+S+'OnClick'));
  for S in TArray<string>.Create('edDetailPage','cbDetailSize') do
    Lines.Add('    '+QuotedStr(S+'|<This>.OnChange:'+S+'OnChange'));
end;

procedure TReportPlan.AddDrillUI(Lines: TStrings);
var I,X:Integer; DFMOptions:string;
  function DFMString(const S:string):string;
  var C:Char;
  begin
    Result:='';
    for C in S do Result:=Result+'#'+IntToStr(Ord(C));
    if Result='' then Result:=QuotedStr('');
  end;
  procedure A(const S:string); begin Lines.Add(S); end;
  procedure Button(const Name,Caption:string);
  begin
    A('      object '+Name+': TUgButton'); A('        Align = alLeft');
    A('        AlignWithMargins = True'); A('        Top = 3');
    A('        Left = '+IntToStr(X)); Inc(X,38);
    A('        Width = 32'); A('        Height = 26'); A('        AutoWidth = False'); A('        Caption = '+DFMString(Caption));
    A('        Enabled = False'); A('      end');
  end;
begin
  if not HasDrilldown then Exit;
  X:=3;
  //调用处位于 reportPages 内、汇总页结束之后。
  A('    object reportDetailPage: TUniTabSheet'); A('      Caption = '+DFMString('明细'));
  A('      object pDetailPages: TUgContainerPanel'); A('        Align = alBottom'); A('        Height = 32');
  Button('btDetailFirst','<<'); Button('btDetailPrior','<');
  A('      object edDetailPage: TUgEdit'); A('        Align = alLeft'); A('        Left = '+IntToStr(X)); Inc(X,81);
  A('        AlignWithMargins = True'); A('        Top = 3'); A('        Height = 26');
  A('        Width = 75'); A('        Text = ''1'''); A('        Enabled = False'); A('      end');
  Button('btDetailNext','>'); Button('btDetailLast','>>');
  A('      object cbDetailSize: TUgComboBox'); A('        Align = alLeft'); A('        Width = 75');
  A('        Left = '+IntToStr(X));
  A('        AlignWithMargins = True'); A('        Top = 3'); A('        Height = 26'); Inc(X,81);
  A('        Style = csDropDownList'); A('        Text = ''50''');
  A('        Items.Strings = (''30'' ''50'' ''100'' ''200'' ''500'')'); A('      end');
  A('      object capDetailPage: TUgLabel'); A('        Align = alLeft');
  A('        AlignWithMargins = True'); A('        Left = '+IntToStr(X));
  A('        Top = 3'); A('        Height = 26');
  A('        Caption = '+DFMString('请双击汇总统计列查看明细')); A('      end');
  A('      end');
  A('      object gridReportDetail: TUgDBGrid'); A('        Align = alClient');
  A('        DataSource = dsReportDetail'); A('        ReadOnly = True');
  A('        WebOptions.Paged = False'); A('        StoreUserSettings = False');
  A('        MultiColumnSort = '+BoolToStr(SameText(FSortMode,'MultiColumnSort'),True));
  DFMOptions:='dgTitles, dgIndicator, dgColLines, dgRowLines, dgRowSelect';
  if FRowNumbers then DFMOptions:=DFMOptions+', dgRowNumbers';
  if FResize then DFMOptions:=DFMOptions+', dgColumnResize';
  if FMove then DFMOptions:=DFMOptions+', dgColumnMove';
  A('        Options = ['+DFMOptions+']');
  A('        Columns = <');
  for I:=0 to FRawFields.Count-1 do begin
    A('          item'); A('            FieldName = '+DFMString(FRawFields[I]));
    A('            Title.Caption = '+DFMString(FRawCaptions[I]));
    if FRawHeaders[I]<>'' then A('            GroupHeader = '+DFMString(FRawHeaders[I]));
    A('            Sortable = '+BoolToStr(SameText(FSortMode,'ColumnSort') or SameText(FSortMode,'MultiColumnSort'),True));
    A('            Menu.ColumnHideable = '+BoolToStr(FHide,True));
    if FRawHidden.IndexOf(FRawFields[I])>=0 then A('            Visible = False');
    if FFiltering then begin
      A('            Filtering.Enabled = True');
      A('            Filtering.Editor = '+FilterEditor(FRawFields[I],True));
    end;
    A('            Width = 120'); A('            ReadOnly = True'); A('          end');
  end;
  A('        >'); A('      end'); A('    end');
end;
