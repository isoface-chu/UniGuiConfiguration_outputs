procedure RefState(const AValue: Integer); begin end;
procedure ShowNotice(const AMessage: string); begin UGMM.ReportNotice(AMessage); end;
Const
  //数据节点
  cDataNodeName   = 'MSSQL';
  cDataNodeDriver = UGMM.GetNodeNameByDriver(cDataNodeName);
  //编辑窗体
  cEditorFrame = 'mtDetailEditor';
  //查询窗体
  cQueryFrame = 'mtDetailQuery';
  //从表空白行数
  cBlankLineCount = 20;
  //浏览状态
  tyView   = 0;
  //编辑状态【添加、编辑】
  tyEditor = 1;
  //获取导航类型
  tyFirst  = 1;
  tyPrior  = 2;
  tyNext   = 3;
  tyLast   = 4;
  tyAppend = 5;
Procedure QuoteDetailsFromQuery(const AFrame: string; const AMultiSelect: Boolean);
Var
  F : TUgWebForm;
  g : TUgDBGrid;
  s : TUgClientDataSet;
  bm, cb : TBookmark;
  i, n, nFound : Integer;
  v : Variant;
  LSkips : TStringList;
begin
  if cdsMain.IsEmpty then
    RaiseException(UGMM.LT('请先选择主记录，再引用明细。'));
  F := TUgWebForm(UGMM.GetWebSubForm(AFrame));
  try
    F.Caption := UGMM.LT(AFrame);
    //以模态窗体打开来源查询窗体：查询并勾选后点确定，再读取选择
    if F.ShowModal <> mrOK then
      Exit;
    g := gridMain;
    s := cdsMain;
    if (g = nil) or (s = nil) then
      RaiseException(UGMM.LT('查询窗体尚未就绪，请先查询出要引用的记录。'));
    if not s.Active then
      RaiseException(UGMM.LT('查询窗体尚未就绪，请先查询出要引用的记录。'));
    n := g.SelectedRows.Count;
    if AMultiSelect then
    begin
      if n = 0 then
        RaiseException(UGMM.LT('请先选择要引用的明细记录。'));
    end
    else
      n := 1;
    //来源与从表明细没有任何同名字段时不予引用，避免追加空行
    nFound := 0;
    try
      v := s.FieldByName('FLocationCode').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FLocationName').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FLocation').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FRegion').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FRegionRow').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FRegionCol').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FMapX').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FMapY').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FMapWidth').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FMapHeight').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FNote').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FVisualLocation').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FIsOverStorageAge').AsVariant;
      Inc(nFound);
    except
    end;
    try
      v := s.FieldByName('FMaxQtyPiece').AsVariant;
      Inc(nFound);
    except
    end;
    if nFound = 0 then
      RaiseException(UGMM.LT('来源记录与从表明细没有同名字段，无法引用，请检查字段命名。'));
    bm := s.GetBookmark;
    LSkips := TStringList.Create;
    s.DisableControls;
    try
      for i := 0 to n - 1 do
      begin
        if AMultiSelect then
        begin
          cb := GetSelectedRow(i);
          s.GotoBookmark(cb);
        end;
        cdsDetailed.Append;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FLocationCode').AsVariant := s.FieldByName('FLocationCode').AsVariant;
        except
          LSkips.Add('FLocationCode');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FLocationName').AsVariant := s.FieldByName('FLocationName').AsVariant;
        except
          LSkips.Add('FLocationName');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FLocation').AsVariant := s.FieldByName('FLocation').AsVariant;
        except
          LSkips.Add('FLocation');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FRegion').AsVariant := s.FieldByName('FRegion').AsVariant;
        except
          LSkips.Add('FRegion');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FRegionRow').AsVariant := s.FieldByName('FRegionRow').AsVariant;
        except
          LSkips.Add('FRegionRow');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FRegionCol').AsVariant := s.FieldByName('FRegionCol').AsVariant;
        except
          LSkips.Add('FRegionCol');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FMapX').AsVariant := s.FieldByName('FMapX').AsVariant;
        except
          LSkips.Add('FMapX');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FMapY').AsVariant := s.FieldByName('FMapY').AsVariant;
        except
          LSkips.Add('FMapY');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FMapWidth').AsVariant := s.FieldByName('FMapWidth').AsVariant;
        except
          LSkips.Add('FMapWidth');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FMapHeight').AsVariant := s.FieldByName('FMapHeight').AsVariant;
        except
          LSkips.Add('FMapHeight');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FNote').AsVariant := s.FieldByName('FNote').AsVariant;
        except
          LSkips.Add('FNote');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FVisualLocation').AsVariant := s.FieldByName('FVisualLocation').AsVariant;
        except
          LSkips.Add('FVisualLocation');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FIsOverStorageAge').AsVariant := s.FieldByName('FIsOverStorageAge').AsVariant;
        except
          LSkips.Add('FIsOverStorageAge');
        end;
        //来源没有同名列时跳过，并在引用结果里列出未复制的字段
        try
          cdsDetailed.FieldByName('FMaxQtyPiece').AsVariant := s.FieldByName('FMaxQtyPiece').AsVariant;
        except
          LSkips.Add('FMaxQtyPiece');
        end;
        cdsDetailed.Post;
      end;
    if LSkips.Count > 0 then
      ShowNotice(UGMM.LT('已引用 ') + IntToStr(n) + UGMM.LT(' 条明细；来源中无同名列、未复制的字段：') + LSkips.CommaText)
    else
      ShowNotice(UGMM.LT('已引用 ') + IntToStr(n) + UGMM.LT(' 条明细。'));
    finally
      s.GotoBookmark(bm);
      s.FreeBookmark(bm);
      s.EnableControls;
      LSkips.Free;
    end;
    RefState(tyView);
  finally
    UGMM.DelWebSubForm(cQueryFrame);
  end;
end;
procedure cdsDetailedBeforePost(dataset: tdataset);
begin
  //关联字段
  dataset.FieldbyName('FStockID').AsVariant := cdsMain.FieldbyName('FInterID').AsVariant;
end;

begin
  QuoteDetailsFromQuery('mtDetailQuery', False);
end.
