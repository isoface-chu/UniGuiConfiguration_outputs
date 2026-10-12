unit ugConfiguration.TreePresentation;
interface
uses System.Classes,System.SysUtils;
procedure AddTreePresentation(Code,Buttons,Columns:TStrings;MoveColumns,SizeColumns,HideColumns,WriteTree:Boolean);
implementation
procedure AddTreePresentation(Code,Buttons,Columns:TStrings;MoveColumns,SizeColumns,HideColumns,WriteTree:Boolean);
var F:string;
  procedure A(const S:string);begin Code.Add(S);end;
begin
  A('//按用户及模块隔离树列布局；文件名使用字符编码，避免路径字符');
  A('function TreeSettingToken(const V: string): string;');
  A('const HexDigits = ''0123456789ABCDEF'';');
  A('var I, J, N: Integer; Token: string;');A('begin');
  A('  Result := '''';');
  A('  for I := 1 to Length(V) do begin');
  A('    N := Ord(V[I]); Token := '''';');
  A('    for J := 1 to 4 do begin');
  A('      Token := Copy(HexDigits, (N mod 16) + 1, 1) + Token;');
  A('      N := N div 16;');A('    end;');
  A('    Result := Result + Token;');A('  end;');A('end;');
  A('function TreeSettingsFile: string;');A('var U, D: string;');A('begin');
  A('  Result := ''''; U := UGMM.Informations.Values[''UserName'']; if U = '''' then Exit;');
  A('  D := ''..\UserSettings\'' + TreeSettingToken(Self.Guid) + ''\'';');
  A('  CheckDirectory(D); Result := D + ''Tree_'' + TreeSettingToken(U) + ''.ini'';');A('end;');
  A('procedure TreeColumnSettings(LoadSettings: Boolean);');
  A('var Ini: TIniFile; C: TUniBaseDBGridColumn; Path: string; N: Integer;');A('begin');
  A('  Path := TreeSettingsFile; if Path = '''' then Exit;');
  A('  if LoadSettings and not FileExists(Path) then Exit;');
  A('  Ini := TIniFile.Create(Path);');A('  try');
  if MoveColumns then begin
    A('    //按保存的目标位置依次恢复，避免前一次移动改变后续列的位置');
    A('    if LoadSettings then for N := 0 to treeMain.Columns.Count - 1 do begin');
    for F in Columns do begin
      A('      if StrToIntDef(Ini.ReadString('+QuotedStr(F)+', ''Index'', ''-1''), -1) = N then begin');
      A('        C := treeMain.ColumnByName('+QuotedStr(F)+'); if C <> nil then C.Index := N;');
      A('      end;');
    end;
    A('    end;');
  end;
  for F in Columns do begin
    A('    C := treeMain.ColumnByName('+QuotedStr(F)+');');A('    if C <> nil then begin');
    A('      if LoadSettings then begin');
    if SizeColumns then begin
      A('        N := StrToIntDef(Ini.ReadString('+QuotedStr(F)+', ''Width'', IntToStr(C.Width)), C.Width);');
      A('        if (N >= 30) and (N <= 2000) then C.Width := N;');
    end;
    if HideColumns then A('        C.Visible := Ini.ReadString('+QuotedStr(F)+', ''Visible'', ''1'') <> ''0'';');
    A('      end else begin');
    if MoveColumns then A('        Ini.WriteString('+QuotedStr(F)+', ''Index'', IntToStr(C.Index));');
    if SizeColumns then A('        Ini.WriteString('+QuotedStr(F)+', ''Width'', IntToStr(C.Width));');
    if HideColumns then A('        if C.Visible then Ini.WriteString('+QuotedStr(F)+', ''Visible'', ''1'') else Ini.WriteString('+QuotedStr(F)+', ''Visible'', ''0'');');
    A('      end;');A('    end;');
  end;
  A('  finally Ini.Free; end;');A('end;');
  A('procedure treeMainOnAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);');A('begin');
  A('  if not TreeReady then Exit;');
  A('  if (EventName = ''columnhide'') or (EventName = ''columnshow'') or');
  A('    (EventName = ''columnresize'') or (EventName = ''columnmove'') then');
  A('    try TreeColumnSettings(False); ConfigureTreeSort; except ShowTreeError(ExceptionMessage); end;');A('end;');
  if Buttons.IndexOf('btAnnex')>=0 then begin
    A('//沿用原版模块级附件；编辑能力由模块按钮权限决定');
    A('procedure btAnnexOnClick(Sender: TObject);');A('var CanEdit: Boolean;');A('begin');
    A('  if not TreeReady or not btAnnex.Enabled then Exit;');
    if WriteTree then A('  if TreeBusy or TreeNeedsReload then Exit;');
    A('  try');A('    CanEdit := False;');
    for F in TArray<string>.Create('btDelete','btEditor')do if Buttons.IndexOf(F)>=0 then
      A('    CanEdit := CanEdit or ('+F+'.Visible and '+F+'.Enabled);');
    A('    UGMM.OpenFileManager(Self.Guid, '''', 31457280, CanEdit);');
    A('  except ShowTreeError(ExceptionMessage); end;');A('end;');
  end;
end;
end.
