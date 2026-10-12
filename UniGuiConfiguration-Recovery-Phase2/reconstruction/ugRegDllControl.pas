unit ugRegDllControl;

{ The target DLL contains no additional custom-control unit in PACKAGEINFO.
  The host's corresponding modular DLL implements these as empty hooks. }

interface

procedure AddDllControl;
procedure DelDllControl;

implementation

procedure AddDllControl;
begin
end;

procedure DelDllControl;
begin
end;

end.
