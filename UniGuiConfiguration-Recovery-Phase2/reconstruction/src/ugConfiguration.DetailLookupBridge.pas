unit ugConfiguration.DetailLookupBridge;

interface

uses
  System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, uniDBGrid, uniGUIClasses,
  uniPanel, ugPublicObjectManagement;

type
  TDetailValueChangeEvent = procedure(Sender: TObject; const Value: string) of object;
  TConfigurationDetailLookupBridge = class(TComponent, IUGDesign)
  private
    FGrid: TUniDBGrid;
    FEditor: TUniControl;
    FFieldName: string;
    FPreviousClick: TUniDBGridClickEvent;
    FDialog: TUniPanel;
    FOpen: Boolean;
    FEditable: Boolean;
    FResetFilter: Boolean;
    FPreviousExpand: TNotifyEvent;
    FPreviousValueChange: TDetailValueChangeEvent;
    FOldParent: TWinControl;
    FBookmark: TBookmark;
    FDataSet: TDataSet;
    FOldLeft, FOldTop, FOldWidth, FOldHeight: Integer;
    procedure EditorExpand(Sender: TObject);
    procedure EditorValueChange(Sender: TObject; const Value: string);
    function TextControl: TComponent;
    procedure SetEditorText(const Value: string);
    procedure CellClick(Column: TUniDBGridColumn);
    procedure AcceptClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure RestoreEditor;
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    function GetX: Integer;
    procedure SetX(Value: Integer);
    function GetY: Integer;
    procedure SetY(Value: Integer);
    function GetW: Integer;
    procedure SetW(Value: Integer);
    function GetH: Integer;
    procedure SetH(Value: Integer);
    function GetV: Boolean;
    procedure OnDblClickProc(ADIM: TDeleteItemMethod; AProc: TProcedureMethod);
    function BeforeMouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean;
    procedure AfterMouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    destructor Destroy; override;
  published
    property Grid: TUniDBGrid read FGrid write FGrid;
    property Editor: TUniControl read FEditor write FEditor;
    property FieldName: string read FFieldName write FFieldName;
    property Editable: Boolean read FEditable write FEditable default False;
  end;

implementation

uses
  System.SysUtils, System.TypInfo,
  uniButton;

// The web designer reads IUGDesign, not TComponent.DesignInfo directly.
// Use the same packed coordinates as TComponent's streamed Left/Top so
// generated positions and user moves survive saving and reopening the DFM.
function TConfigurationDetailLookupBridge.GetX: Integer;
begin
  Result := LongRec(DesignInfo).Lo;
end;

procedure TConfigurationDetailLookupBridge.SetX(Value: Integer);
var
  Info: LongRec;
begin
  Info := LongRec(DesignInfo);
  Info.Lo := Word(Value);
  DesignInfo := Integer(Info);
end;

function TConfigurationDetailLookupBridge.GetY: Integer;
begin
  Result := LongRec(DesignInfo).Hi;
end;

procedure TConfigurationDetailLookupBridge.SetY(Value: Integer);
var
  Info: LongRec;
begin
  Info := LongRec(DesignInfo);
  Info.Hi := Word(Value);
  DesignInfo := Integer(Info);
end;

function TConfigurationDetailLookupBridge.GetW: Integer;
begin
  Result := cNotViewComponentLength;
end;

procedure TConfigurationDetailLookupBridge.SetW(Value: Integer);
begin
  // Nonvisual designer icons have a fixed size.
end;

function TConfigurationDetailLookupBridge.GetH: Integer;
begin
  Result := cNotViewComponentLength;
end;

procedure TConfigurationDetailLookupBridge.SetH(Value: Integer);
begin
  // Nonvisual designer icons have a fixed size.
end;

function TConfigurationDetailLookupBridge.GetV: Boolean;
begin
  Result := True;
end;

procedure TConfigurationDetailLookupBridge.OnDblClickProc(
  ADIM: TDeleteItemMethod; AProc: TProcedureMethod);
begin
  // No custom property dialog for the internal lookup bridge.
end;

function TConfigurationDetailLookupBridge.BeforeMouseDown(
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer): Boolean;
begin
  Result := True;
end;

procedure TConfigurationDetailLookupBridge.AfterMouseDown(
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
end;

function TConfigurationDetailLookupBridge.TextControl: TComponent;
var
  I: Integer;
begin
  Result := FEditor;
  if IsPublishedProp(Result, 'Text') then Exit;
  // GridComboboxExtra.Text is public, not published. Its native getter
  // returns the owned code editor's Text (not the display-name edit).
  if SameText(FEditor.ClassName, 'TUgGridComboboxExtra') then
    for I := 0 to FEditor.ComponentCount - 1 do
      if SameText(FEditor.Components[I].ClassName, 'TUgGridCombobox') and
         IsPublishedProp(FEditor.Components[I], 'Text') then
        Exit(FEditor.Components[I]);
  raise Exception.Create('No supported text accessor for ' + FEditor.ClassName);
end;

procedure TConfigurationDetailLookupBridge.SetEditorText(const Value: string);
var
  CodeEditor: TComponent;
  Changed: TNotifyEvent;
begin
  CodeEditor := TextControl;
  SetStrProp(CodeEditor, 'Text', Value);
  // Preserve the composite control's native display-name refresh.
  if (CodeEditor <> FEditor) and IsPublishedProp(CodeEditor, 'OnChangeValue') then
  begin
    TMethod(Changed) := GetMethodProp(CodeEditor, 'OnChangeValue');
    if Assigned(Changed) then Changed(CodeEditor);
  end;
end;

procedure TConfigurationDetailLookupBridge.EditorExpand(Sender: TObject);
begin
  FResetFilter := True;
  if Assigned(FPreviousExpand) then FPreviousExpand(Sender);
end;

procedure TConfigurationDetailLookupBridge.EditorValueChange(Sender: TObject; const Value: string);
var
  Candidates: TDataSet;
begin
  // Native DoExpand filters by saved Text before calling this event.
  if FResetFilter and Assigned(FEditor) and
     (GetOrdProp(FEditor, 'GridLookupDataSetFilter') <> 0) then
  begin
    Candidates := TDataSet(GetObjectProp(FEditor, 'GridLookupDataSet'));
    if Assigned(Candidates) and Candidates.Active then
    begin
      Candidates.Filtered := False;
      Candidates.Filter := '';
    end;
  end;
  FResetFilter := False;
  if Assigned(FPreviousValueChange) then FPreviousValueChange(Sender, Value);
end;

procedure TConfigurationDetailLookupBridge.Loaded;
var
  ExpandHandler: TNotifyEvent;
  ValueHandler: TDetailValueChangeEvent;
begin
  inherited;
  if Assigned(FGrid) and Assigned(FEditor) then
  begin
    FGrid.FreeNotification(Self);
    FEditor.FreeNotification(Self);
    if SameText(FEditor.ClassName, 'TUgGridCombobox') then
    begin
      TMethod(FPreviousExpand) := GetMethodProp(FEditor, 'OnExpand');
      TMethod(FPreviousValueChange) := GetMethodProp(FEditor, 'OnExtEditValueChange');
      ExpandHandler := EditorExpand;
      ValueHandler := EditorValueChange;
      SetMethodProp(FEditor, 'OnExpand', TMethod(ExpandHandler));
      SetMethodProp(FEditor, 'OnExtEditValueChange', TMethod(ValueHandler));
      Exit;
    end;
    if TMethod(FGrid.OnCellClick).Data = Self then Exit;
    FPreviousClick := FGrid.OnCellClick;
    FGrid.OnCellClick := CellClick;
  end;
end;

procedure TConfigurationDetailLookupBridge.CellClick(Column: TUniDBGridColumn);
var
  B: TUniButton;
begin
  if Assigned(FPreviousClick) then FPreviousClick(Column);
  if FOpen or not Assigned(FEditor) or not Assigned(FGrid) then Exit;
  if not Assigned(Column) then Exit;
  if not SameText(Column.FieldName, FFieldName) or FGrid.ReadOnly or not FEditable then Exit;
  if not Assigned(FGrid.DataSource) then Exit;
  FDataSet := FGrid.DataSource.DataSet;
  if not Assigned(FDataSet) or not FDataSet.Active or FDataSet.IsEmpty then Exit;
  FDataSet.CheckBrowseMode;
  FBookmark := FDataSet.GetBookmark;
  FDataSet.FreeNotification(Self);
  FOldParent := FEditor.Parent;
  if Assigned(FOldParent) then FOldParent.FreeNotification(Self);
  FOldLeft := FEditor.Left;
  FOldTop := FEditor.Top;
  FOldWidth := FEditor.Width;
  FOldHeight := FEditor.Height;
  try
    if not Assigned(FDialog) then
    begin
      // Same owner and parent form as the original editor; never reparent
      // an existing UniGUI control into a different TUniForm.
      FDialog := TUniPanel.Create(FEditor.Owner);
      FDialog.FreeNotification(Self);
      FDialog.Visible := False;
      FDialog.Floating := True;
      FDialog.Modal := True;
      FDialog.Parent := FGrid.Parent;
      FDialog.SetBounds(30, 60, 560, 190);
      FDialog.TitleVisible := True;
      FDialog.ShowCaption := False;
      B := TUniButton.Create(FDialog);
      B.Parent := FDialog;
      B.SetBounds(340, 110, 85, 30);
      B.Caption := '确定';
      B.OnClick := AcceptClick;
      B := TUniButton.Create(FDialog);
      B.Parent := FDialog;
      B.SetBounds(440, 110, 85, 30);
      B.Caption := '取消';
      B.OnClick := CancelClick;
    end;
    FDialog.Title := Column.Title.Caption;
    FEditor.Parent := FDialog;
    FEditor.SetBounds(16, 16, 510, 50);
    SetOrdProp(FEditor, 'ReadOnly', 0);
    SetEditorText(FDataSet.FieldByName(FFieldName).AsString);
    FEditor.Visible := True;
    FOpen := True;
    FDialog.Show;
    FDialog.BringToFront;
  except
    RestoreEditor;
    FreeAndNil(FDialog);
    raise;
  end;
end;

procedure TConfigurationDetailLookupBridge.AcceptClick(Sender: TObject);
var
  Value: string;
begin
  if not FEditable or not Assigned(FGrid) or not Assigned(FEditor) or not Assigned(FDialog) or
     not Assigned(FDataSet) or not FDataSet.Active or
     not FDataSet.BookmarkValid(FBookmark) or FGrid.ReadOnly then
    raise Exception.Create(string('明细记录已改变，请关闭窗口后重新选择。'));
  Value := GetStrProp(TextControl, 'Text');
  FDataSet.GotoBookmark(FBookmark);
  FDataSet.Edit;
  if Value = '' then FDataSet.FieldByName(FFieldName).Clear
  else FDataSet.FieldByName(FFieldName).AsString := Value;
  FDataSet.Post;
  CancelClick(Sender);
end;

procedure TConfigurationDetailLookupBridge.RestoreEditor;
begin
  if Assigned(FEditor) then
  begin
    FEditor.Parent := FOldParent;
    FEditor.SetBounds(FOldLeft, FOldTop, FOldWidth, FOldHeight);
  end;
  if Assigned(FDataSet) then
  begin
    FDataSet.FreeBookmark(FBookmark);
    FDataSet.RemoveFreeNotification(Self);
  end;
  FDataSet := nil;
  FBookmark := nil;
  if Assigned(FOldParent) then FOldParent.RemoveFreeNotification(Self);
  FOldParent := nil;
end;

procedure TConfigurationDetailLookupBridge.CancelClick(Sender: TObject);
begin
  if Assigned(FDialog) then FDialog.Hide;
  RestoreEditor;
  FOpen := False;
end;

procedure TConfigurationDetailLookupBridge.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation <> opRemove then Exit;
  if AComponent = FGrid then FGrid := nil;
  if AComponent = FEditor then FEditor := nil;
  if AComponent = FDataSet then FDataSet := nil;
  if AComponent = FOldParent then FOldParent := nil;
  if AComponent = FDialog then FDialog := nil;
end;

destructor TConfigurationDetailLookupBridge.Destroy;
begin
  if Assigned(FEditor) and SameText(FEditor.ClassName, 'TUgGridCombobox') then
  begin
    if GetMethodProp(FEditor, 'OnExpand').Data = Self then
      SetMethodProp(FEditor, 'OnExpand', TMethod(FPreviousExpand));
    if GetMethodProp(FEditor, 'OnExtEditValueChange').Data = Self then
      SetMethodProp(FEditor, 'OnExtEditValueChange', TMethod(FPreviousValueChange));
  end;
  if Assigned(FGrid) and (TMethod(FGrid.OnCellClick).Data = Self) then
    FGrid.OnCellClick := FPreviousClick;
  if Assigned(FDialog) then
  begin
    if FOpen then RestoreEditor;
    FreeAndNil(FDialog);
  end;
  inherited;
end;

initialization
  RegisterClass(TConfigurationDetailLookupBridge);
finalization
  UnRegisterClass(TConfigurationDetailLookupBridge);
end.
