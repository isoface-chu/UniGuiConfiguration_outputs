function ReportFilterKind(const T:string):Integer;
begin
  Result:=0;
  if (Pos('DATE',T)>0) or (Pos('TIME',T)>0) then Result:=2
  else if (T='BIT') or (Pos('BOOL',T)>0) then Result:=3
  else if Pos('INT',T)>0 then Result:=4
  else if (Pos('DECIMAL',T)>0) or (Pos('NUMERIC',T)>0) or
    (Pos('NUMBER',T)>0) or (Pos('MONEY',T)>0) or (Pos('BCD',T)>0) or (Pos('CURRENCY',T)>0) then Result:=5
  else if (Pos('FLOAT',T)>0) or (Pos('DOUBLE',T)>0) or (Pos('REAL',T)>0) then Result:=1;
end;

function TReportPlan.FilterEditor(const Field:string; Detail:Boolean):string;
var I:Integer;
begin
  Result:=''; if not FFiltering then Exit;
  if Detail then begin I:=FRawFields.IndexOf(Field); Result:='reportFilterD'; end
  else begin I:=FNames.IndexOf(Field); Result:='reportFilterS'; end;
  if I<0 then Result:='' else Result:=Result+IntToStr(I);
end;

procedure TReportPlan.FilterSQL(Code:TStrings; Detail:Boolean);
var Names,Types:TStrings; I:Integer; Op,Editor:string;
begin
  if not FFiltering then Exit;
  if Detail then begin Names:=FRawFields; Types:=FRawTypes; end
  else begin Names:=FNames; Types:=FTypes; end;
  Code.Add('  SQL := ''select * from ('' + SQL + '') reportFiltered where 1=1'';');
  for I:=0 to Names.Count-1 do begin
    Editor:=FilterEditor(Names[I],Detail); Op:=' = ';
    if ReportFilterKind(Types[I])=0 then Op:=' like ';
    Code.Add('  if VarToStr('+Editor+'.Text) <> '''' then SQL := SQL + '+
      QuotedStr(' and reportFiltered.'+Names[I]+Op+':'+Editor)+';');
  end;
end;

procedure TReportPlan.BindFilters(Code:TStrings; Detail:Boolean);
var Names,Types:TStrings; I:Integer; Editor,Target,Setter:string;
begin
  if not FFiltering then Exit;
  if Detail then begin Names:=FRawFields; Types:=FRawTypes; Target:='cdsReportDetail'; end
  else begin Names:=FNames; Types:=FTypes; Target:='cdsMain'; end;
  for I:=0 to Names.Count-1 do begin
    Editor:=FilterEditor(Names[I],Detail);
    if ReportFilterKind(Types[I]) in [4,5] then begin
      Code.Add('  if VarToStr('+Editor+'.Text) <> '''' then begin');
      Setter:='ftFMTBcd'; if ReportFilterKind(Types[I])=4 then Setter:='ftLargeint';
      Code.Add('    '+Target+'.ParamByName('+QuotedStr(Editor)+').DataType := '+Setter+';');
      Code.Add('    '+Target+'.ParamByName('+QuotedStr(Editor)+').Value := VarToStr('+Editor+'.Text);');
      Code.Add('  end;'); Continue;
    end;
    case ReportFilterKind(Types[I]) of
      1:Setter:='AsFloat := StrToFloat(VarToStr('+Editor+'.Text))';
      2:Setter:='AsDateTime := StrToDateTime(VarToStr('+Editor+'.Text))';
      3:Setter:='AsBoolean := StrToBool(VarToStr('+Editor+'.Text))';
      else Setter:='AsString := ''%'' + VarToStr('+Editor+'.Text) + ''%''';
    end;
    Code.Add('  if VarToStr('+Editor+'.Text) <> '''' then '+Target+'.ParamByName('+QuotedStr(Editor)+').'+Setter+';');
  end;
end;

procedure TReportPlan.FilterEditors(Lines:TStrings);
var I:Integer; Name:string;
  procedure Editor;
  begin
    Lines.Add('    object '+Name+': TUgEdit');
    Lines.Add('      Width = 120'); Lines.Add('      Height = 26'); Lines.Add('    end');
  end;
begin
  if not FFiltering then Exit;
  Lines.Add('  object reportFilterEditors: TUgHiddenPanel');
  for I:=0 to FNames.Count-1 do begin Name:=FilterEditor(FNames[I],False); Editor; end;
  if HasDrilldown then
    for I:=0 to FRawFields.Count-1 do begin Name:=FilterEditor(FRawFields[I],True); Editor; end;
  Lines.Add('  end');
end;
