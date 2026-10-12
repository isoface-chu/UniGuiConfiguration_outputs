unit ugConfiguration.MultiplePresentation;

interface
uses System.SysUtils, System.Classes;
procedure ApplyMultiplePresentation(Code, Lines: TStrings);

implementation

// Rename executable identifiers only; quoted SQL, messages and comments stay intact.
function RenameIdentifier(const S, OldName, NewName: string): string;
var P, First: Integer;
begin
  Result := ''; P := 1;
  while P <= Length(S) do begin
    First := P;
    if Copy(S, P, 2) = '//' then begin
      Result := Result + Copy(S, P, MaxInt); Exit;
    end;
    if S[P] = '''' then begin
      Inc(P);
      while P <= Length(S) do
        if S[P] = '''' then begin
          Inc(P);
          if (P <= Length(S)) and (S[P] = '''') then Inc(P)
          else Break;
        end else Inc(P);
    end else if CharInSet(S[P], ['A'..'Z', 'a'..'z', '_']) then begin
      Inc(P);
      while (P <= Length(S)) and CharInSet(S[P], ['A'..'Z', 'a'..'z', '_', '0'..'9']) do Inc(P);
      if SameText(Copy(S, First, P - First), OldName) then begin
        Result := Result + NewName; Continue;
      end;
    end else Inc(P);
    Result := Result + Copy(S, First, P - First);
  end;
end;

function Q(const S:string):string;
var C:Char;
begin
  // DFM's text reader may use the host ANSI code page. Match the original
  // generator: encode non-ASCII characters as Unicode character constants.
  Result:='''';
  for C in S do
    if (Ord(C)<32) or (Ord(C)>126) then
      Result:=Result+'''#'+IntToStr(Ord(C))+''''
    else if C='''' then Result:=Result+''''''
    else Result:=Result+C;
  Result:=Result+'''';
end;

procedure ApplyMultiplePresentation(Code, Lines:TStrings);
var Helpers, Names, Params:TStringList;
  I,J,K,P,Start,Depth,Slot,CodeStart,CodeEnd:Integer;
  T,R,Token,Handler,Declaration,Arguments,Part,Name:string;
  IsHidden,IsIcon:Boolean;
  procedure Helper(const S:string);
  begin Helpers.Add(S);end;
  procedure Alert(const AName,AType:string; Cancel,Input:Boolean);
  begin
    Lines.Insert(Lines.Count-1,'  object '+AName+': TUgSweetAlert');
    Lines.Insert(Lines.Count-1,'    AlertType = '+AType);
    Lines.Insert(Lines.Count-1,'    ShowConfirmButton = True');
    Lines.Insert(Lines.Count-1,'    ShowCancelButton = '+BoolToStr(Cancel,True));
    if Cancel then begin
      Lines.Insert(Lines.Count-1,'    AllowOutsideClick = False');
      Lines.Insert(Lines.Count-1,'    AllowEscapeKey = True');
    end;
    if Cancel and not Input then Lines.Insert(Lines.Count-1,'    FocusCancel = True');
    if Input then begin
      Lines.Insert(Lines.Count-1,'    InputType = ItTextArea');
      Lines.Insert(Lines.Count-1,'    InputAutoTrim = False');
    end;
    Lines.Insert(Lines.Count-1,'  end');
  end;
begin
  Helpers:=TStringList.Create;Names:=TStringList.Create;Params:=TStringList.Create;
  try
    Helper('//显示一般提示，不改变业务流程');
    Helper('procedure ShowNotice(const AMessage: string);');
    Helper('begin');
    Helper('  noticeAlert.TitleText := UGMM.LT(''提示'');');
    Helper('  noticeAlert.ConfirmButtonText := UGMM.LT(''确定'');');
    Helper('  noticeAlert.Show(AMessage);');Helper('end;');Helper('');
    Helper('//在事件入口显示错误；内部校验异常仍中止当前操作');
    Helper('procedure ShowActionError(const AMessage: string);');Helper('begin');
    Helper('  errorAlert.TitleText := UGMM.LT(''操作未完成'');');
    Helper('  errorAlert.ConfirmButtonText := UGMM.LT(''确定'');');
    Helper('  errorAlert.Show(AMessage);');Helper('end;');Helper('');
    Helper('//编辑校验失败时先等待提示确认，再重新进入编辑模态循环');
    Helper('procedure WaitEditorError(const AMessage: string);');Helper('begin');
    Helper('  errorAlert.TitleText := UGMM.LT(''请修改后重试'');');
    Helper('  errorAlert.ConfirmButtonText := UGMM.LT(''确定'');');
    Helper('  errorAlert.Text := AMessage;');
    Helper('  errorAlert.Execute;');Helper('end;');Helper('');
    Helper('//等待用户确认；取消时返回 False，由调用方停止操作');
    Helper('function ConfirmAction(const AMessage: string): Boolean;');Helper('begin');
    Helper('  confirmAlert.TitleText := UGMM.LT(''请确认'');');
    Helper('  confirmAlert.Text := UGMM.LT(AMessage);');
    Helper('  confirmAlert.ConfirmButtonText := UGMM.LT(''确定'');');
    Helper('  confirmAlert.CancelButtonText := UGMM.LT(''取消'');');
    Helper('  Result := confirmAlert.Execute;');Helper('end;');Helper('');
    Helper('//等待用户输入；仅确认后更新返回值，取消保留原值');
    Helper('function InputAction(const APrompt: string; var AValue: string): Boolean;');Helper('begin');
    Helper('  inputAlert.TitleText := UGMM.LT(''请输入'');');
    Helper('  inputAlert.Text := UGMM.LT(APrompt);');
    Helper('  inputAlert.InputValue := AValue;');
    Helper('  inputAlert.ConfirmButtonText := UGMM.LT(''确定'');');
    Helper('  inputAlert.CancelButtonText := UGMM.LT(''取消'');');
    Helper('  Result := inputAlert.Execute;');
    Helper('  if Result then AValue := inputAlert.InputResult;');Helper('end;');Helper('');
    I:=0;
    while (I<Code.Count) and
      (Pos('procedure ',Trim(Code[I]))<>1) and
      (Pos('function ',Trim(Code[I]))<>1) do Inc(I);
    while (I>0) and ((Trim(Code[I-1])='') or (Pos('//',Trim(Code[I-1]))=1)) do Dec(I);
    for J:=Helpers.Count-1 downto 0 do Code.Insert(I,Helpers[J]);

    // Same literal-only translation rule as mtMasterSlave; preserve field keys.
    for I:=0 to Code.Count-1 do begin
      T:=StringReplace(Code[I],'ShowMessage(','ShowNotice(',[rfReplaceAll]);
      R:='';P:=1;Depth:=0;
      if Pos('//',Trim(T))=1 then Continue;
      while P<=Length(T) do begin
        if (Depth=0) and ((Copy(T,P,15)='RaiseException(') or
          (Copy(T,P,11)='ShowNotice(')) then begin
          if Copy(T,P,15)='RaiseException(' then J:=15 else J:=11;
          R:=R+Copy(T,P,J);Inc(P,J);Depth:=1;Continue;
        end;
        if T[P]='''' then begin
          Start:=P;Inc(P);
          while P<=Length(T) do
            if T[P]='''' then begin
              if (P<Length(T)) and (T[P+1]='''') then Inc(P,2)
              else begin Inc(P);Break;end;
            end else Inc(P);
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
      Code[I]:=R;
    end;

    // Guard only external event entry points. Internal exceptions still unwind.
    Params.StrictDelimiter:=True;Params.Delimiter:=';';
    for I:=0 to Lines.Count-1 do begin
      T:=Lines[I];P:=Pos('|<This>.',T);
      if P=0 then Continue;
      P:=Pos(':',T);if P=0 then Continue;
      Handler:=Copy(T,P+1,MaxInt);
      K:=Pos('''',Handler);if K>0 then Handler:=Copy(Handler,1,K-1);
      if Handler='' then Continue;
      if Names.IndexOf(Handler)<0 then begin
        Declaration:='';
        for J:=0 to Code.Count-1 do
          if Pos('procedure '+Handler+'(',Trim(Code[J]))=1 then
          begin Declaration:=Trim(Code[J]);Break;end;
        if Declaration='' then Continue;
        Names.Add(Handler);
        // Keep public event names identical to the original template. Calls
        // between business routines use implementations, so errors unwind.
        for K:=0 to Code.Count-1 do
          Code[K]:=RenameIdentifier(Code[K],Handler,'Execute'+Handler);
        P:=Pos('(',Declaration);K:=Pos(')',Declaration);
        Params.DelimitedText:=Copy(Declaration,P+1,K-P-1);Arguments:='';
        for Part in Params do begin
          Name:=Trim(Copy(Part,1,Pos(':',Part)-1));
          if Pos('const ',Name)=1 then Delete(Name,1,6);
          if Pos('var ',Name)=1 then Delete(Name,1,4);
          if Arguments<>'' then Arguments:=Arguments+', ';
          Arguments:=Arguments+Name;
        end;
        J:=Code.Count-2;
        if Handler='UgWebRunFrameOnAfterRunScript' then
          Code.Insert(J,'//运行脚本后')
        else Code.Insert(J,'//事件入口：'+Handler+'；执行操作并统一显示异常提示');
        Inc(J);
        Code.Insert(J,Declaration);Inc(J);
        Code.Insert(J,'begin');Inc(J);Code.Insert(J,'  try');Inc(J);
        Code.Insert(J,'    Execute'+Handler+'('+Arguments+');');Inc(J);
        Code.Insert(J,'  except');Inc(J);
        Code.Insert(J,'    ShowActionError(ExceptionMessage);');Inc(J);
        Code.Insert(J,'  end;');Inc(J);Code.Insert(J,'end;');Inc(J);Code.Insert(J,'');
      end;
    end;
    CodeStart:=Lines.IndexOf('  Codes.Strings = (');CodeEnd:=CodeStart+1;
    while (CodeEnd<Lines.Count) and (Lines[CodeEnd]<>'  )') do Inc(CodeEnd);
    if (CodeStart<0) or (CodeEnd>=Lines.Count) then raise Exception.Create('Missing generated code block');
    for I:=CodeEnd-1 downto CodeStart+1 do Lines.Delete(I);
    for I:=Code.Count-1 downto 0 do Lines.Insert(CodeStart+1,'    '+Q(Code[I]));
    Alert('noticeAlert','atInfo',False,False);
    Alert('confirmAlert','atQuestion',True,False);
    Alert('inputAlert','atQuestion',True,True);
    Alert('errorAlert','atError',False,False);

    // Same 80px icon spacing as mtMasterSlave; hidden containers below UI.
    Slot:=0;I:=0;
    while I<Lines.Count do begin
      T:=Lines[I];
      if Copy(T,1,9)='  object ' then begin
        IsHidden:=(Pos(': TUgHiddenPanel',T)>0) or
          (Pos('object pUnitImport:',T)>0) or (Pos('TimeValue: TUgEdit',T)>0);
        IsIcon:=(Pos(': TUgClientDataSet',T)>0) or (Pos(': TUgDataSource',T)>0) or
          (Pos(': TUgPopupMenu',T)>0) or (Pos(': TUGIconClsList',T)>0) or
          (Pos(': TUgSweetAlert',T)>0);
        if IsHidden or IsIcon then begin
          J:=I+1;
          while (J<Lines.Count) and (Copy(Lines[J],1,4)='    ') and
            (Copy(Lines[J],1,6)<>'      ') do begin
            if (Pos('    Left = ',Lines[J])=1) or (Pos('    Top = ',Lines[J])=1) then
              Lines.Delete(J) else Inc(J);
          end;
          if IsHidden then begin
            if Pos('TimeValue: TUgEdit',T)>0 then begin
              Lines.Insert(I+1,'    Left = '+IntToStr(20+(Slot mod 12)*80));
              Lines.Insert(I+2,'    Top = '+IntToStr(650+(Slot div 12)*60));Inc(Slot);
            end else if Pos('object pUnitImport:',T)>0 then begin
              Lines.Insert(I+1,'    Left = 760');Lines.Insert(I+2,'    Top = 384');
            end else begin
              Lines.Insert(I+1,'    Left = 1100');Lines.Insert(I+2,'    Top = 384');
            end;
          end else begin
            Lines.Insert(I+1,'    Left = '+IntToStr(20+(Slot mod 12)*80));
            Lines.Insert(I+2,'    Top = '+IntToStr(550+(Slot div 12)*60));Inc(Slot);
          end;
          Inc(I,2);
        end;
      end;
      Inc(I);
    end;
  finally Params.Free;Names.Free;Helpers.Free;end;
end;
end.
