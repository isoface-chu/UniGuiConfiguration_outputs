unit ugConfiguration.TreeScriptLayout;
interface
uses System.Classes,System.SysUtils;
procedure FormatTreeScript(Code:TStrings);
implementation
procedure FormatTreeScript(Code:TStrings);
var Parts,ResultLines:TStringList;Line,Buffer,Token,T,Low:string;
  I,J,Start,Depth,Level,OutLevel:Integer;Quoted,Decl,Pending:Boolean;
  procedure Flush;
  begin if Trim(Buffer)<>'' then Parts.Add(Trim(Buffer));Buffer:='';end;
begin
  Parts:=TStringList.Create;ResultLines:=TStringList.Create;
  try
    Depth:=0;
    for Line in Code do begin
      Buffer:='';I:=1;Quoted:=False;
      while I<=Length(Line) do begin
        if Line[I]='''' then begin
          Buffer:=Buffer+Line[I];Inc(I);
          if Quoted and (I<=Length(Line)) and (Line[I]='''') then begin Buffer:=Buffer+Line[I];Inc(I);end
          else Quoted:=not Quoted;
          Continue;
        end;
        if Quoted then begin Buffer:=Buffer+Line[I];Inc(I);Continue;end;
        if (Line[I]='/')and(I<Length(Line))and(Line[I+1]='/')then begin
          Flush;Parts.Add(Copy(Line,I,MaxInt));Break;
        end;
        if Line[I]='(' then Inc(Depth);
        if Line[I]=')' then Dec(Depth);
        if (Depth=0)and CharInSet(Line[I],['A'..'Z','a'..'z','_'])then begin
          Start:=I;Inc(I);
          while(I<=Length(Line))and CharInSet(Line[I],['A'..'Z','a'..'z','_','0'..'9'])do Inc(I);
          Token:=Copy(Line,Start,I-Start);Low:=LowerCase(Token);
          if (Low='begin')or(Low='try')or(Low='except')or(Low='finally')or(Low='else')or(Low='var')or(Low='const') then begin
            Flush;Parts.Add(Token);
          end else if Low='end' then begin Flush;Buffer:=Token;end
          else Buffer:=Buffer+Token;
          Continue;
        end;
        Buffer:=Buffer+Line[I];
        if (Depth=0)and(Line[I]=';')then Flush;
        Inc(I);
      end;
      Flush;
    end;
    Level:=0;Decl:=False;Pending:=False;
    for J:=0 to Parts.Count-1 do begin
      T:=Parts[J];Low:=LowerCase(T);
      if (Copy(Low,1,10)='procedure ')or(Copy(Low,1,9)='function ')then begin
        Level:=0;Decl:=False;Pending:=False;
        Start:=ResultLines.Count;
        while (Start>0)and(Copy(Trim(ResultLines[Start-1]),1,2)='//')do Dec(Start);
        if Start>0 then ResultLines.Insert(Start,'');
      end;
      if (Low='begin')then Decl:=False;
      if (Low='var')or(Low='const')then Decl:=False;
      if (Low='end')or(Low='end;')or(Low='end.')or(Low='finally')or(Low='except')then
        if Level>0 then Dec(Level);
      OutLevel:=Level;if Decl then Inc(OutLevel);
      if Pending and (Low<>'begin')and(Low<>'try')then Inc(OutLevel);
      ResultLines.Add(StringOfChar(' ',OutLevel*2)+T);
      if Copy(Low,1,2)='//' then Continue;
      Pending:=False;
      if (Low='var')or(Low='const')then Decl:=True;
      if (Low='begin')or(Low='try')or(Low='except')or(Low='finally')then Inc(Level);
      if Low='else' then Pending:=True;
      if (Length(Low)>=5)and(Copy(Low,Length(Low)-4,5)=' then')then Pending:=True;
      if (Length(Low)>=3)and(Copy(Low,Length(Low)-2,3)=' do')then Pending:=True;
    end;
    Code.Assign(ResultLines);
  finally ResultLines.Free;Parts.Free;end;
end;
end.
