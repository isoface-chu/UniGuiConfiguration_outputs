unit ugWebConfigurationModule;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebCustBaseForm, ugPublicObjectManagement, ugWebConfigurationBase,
  System.Generics.Collections, uniBitBtn, Vcl.Forms;

type
  TWebConfigurationModule = class(TWebCustBaseForm)
    pConfigurationPages: TUniPageControl;
    pDataNodeName: TUniTabSheet;
    pModuletype: TUniTabSheet;
    pFunctionButton: TUniTabSheet;
    pDataStructure: TUniTabSheet;
    pDetailedStructure: TUniTabSheet;
    pDataPerspective: TUniTabSheet;
    pQueryCriteria: TUniTabSheet;
    pNormalSetting: TUniTabSheet;
    pTop: TUniContainerPanel;
    capDataNodeName: TUniLabel;
    arrowhead1: TUniLabel;
    capModuletype: TUniLabel;
    arrowhead2: TUniLabel;
    capFunctionButton: TUniLabel;
    arrowhead3: TUniLabel;
    capDataStructure: TUniLabel;
    arrowhead4: TUniLabel;
    capQueryCriteria: TUniLabel;
    arrowhead7: TUniLabel;
    capNormalSetting: TUniLabel;
    capDataPerspective: TUniLabel;
    arrowhead6: TUniLabel;
    btShowJson: TUniSpeedButton;
    arrowhead5: TUniLabel;
    capDetailedStructure: TUniLabel;
    pBottom: TUniContainerPanel;
    btPrior: TUniButton;
    btNext: TUniButton;
    btComplete: TUniButton;
    btCancel: TUniButton;
    UniNativeImageList1: TUniNativeImageList;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btShowJsonClick(Sender: TObject);
    procedure btPriorClick(Sender: TObject);
    procedure btNextClick(Sender: TObject);
    procedure btCompleteClick(Sender: TObject);
    procedure btCancelClick(Sender: TObject);
    procedure WizardPageChanged(Sender:TObject);
  private
    FWebConfigurations: TDictionary<TUniTabSheet, TWebConfigurationBase>;
    FConfigurationStream: TUgConfigurationStream;
    FConfigurationTarget: TUgConfigurationStream;
    FRunFrameTarget: TComponent;
    FBIOSSerialNumber: string;
    FComputerName: string;
    FResultTime: TDateTime;
    FResultCode: Integer;
    procedure CreateConfigurationPages;
    procedure AddConfigurationPage(APage: TUniTabSheet;
      AConfiguration: TWebConfigurationBase);
    function ActiveConfiguration: TWebConfigurationBase;
    procedure SendConfigurationStream(AConfigurationStream: TUgConfigurationStream);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RefSupportConfiguration(AllShow: Boolean = False);
    procedure AttachConfigurationStream(AConfigurationStream: TUgConfigurationStream);
    procedure AttachRunFrame(ARunFrame: TComponent);
    procedure LoadConfigurationStream;
    procedure SaveConfigurationStream;
    property ConfigurationStream: TUgConfigurationStream read FConfigurationStream
      write SendConfigurationStream;
    property WebConfigurations: TDictionary<TUniTabSheet, TWebConfigurationBase>
      read FWebConfigurations;
    property BIOSSerialNumber: string read FBIOSSerialNumber;
    property ComputerName: string read FComputerName;
    property ResultTime: TDateTime read FResultTime;
    property ResultCode: Integer read FResultCode;
  end;

implementation

{$R *.dfm}

uses
  Graphics, uniGUIApplication,
  ugConfiguration.Document,
  ugWebConfigurationModule.GenerateRunFrame,
  ugWebConfiguration.DataNodeName,
  ugWebConfiguration.Moduletype,
  ugWebConfiguration.FunctionButton,
  ugWebConfiguration.DataStructure,
  ugWebConfiguration.DetailedStructure,
  ugWebConfiguration.DataPerspective,
  ugWebConfiguration.QueryCriteria,
  ugWebConfiguration.NormalSetting,
  ugWebConfigurationModule.ShowJson;

constructor TWebConfigurationModule.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConfigurationStream := TUgConfigurationStream.Create;
  FWebConfigurations := TDictionary<TUniTabSheet, TWebConfigurationBase>.Create;
  CreateConfigurationPages;
  pConfigurationPages.ActivePage := pDataNodeName;
  pConfigurationPages.OnChange:=WizardPageChanged;
  WizardPageChanged(nil);
end;

procedure TWebConfigurationModule.WizardPageChanged(Sender:TObject);
var I:Integer; Labels:array[0..7]of TUniLabel; C:TWebConfigurationBase;
begin
  Labels[0]:=capDataNodeName;Labels[1]:=capModuletype;
  Labels[2]:=capFunctionButton;Labels[3]:=capDataStructure;
  Labels[4]:=capDetailedStructure;Labels[5]:=capDataPerspective;
  Labels[6]:=capQueryCriteria;Labels[7]:=capNormalSetting;
  for I:=0 to 7 do
  begin
    Labels[I].Enabled:=True;
    Labels[I].ParentFont:=False;
    if I=pConfigurationPages.ActivePageIndex then Labels[I].Font.Style:=[fsBold]
    else Labels[I].Font.Style:=[];
  end;
  btPrior.Enabled:=False;btNext.Enabled:=False;
  for I:=0 to pConfigurationPages.PageCount-1 do
    if pConfigurationPages.Pages[I].TabVisible then
    begin
      if I<pConfigurationPages.ActivePageIndex then btPrior.Enabled:=True;
      if I>pConfigurationPages.ActivePageIndex then btNext.Enabled:=True;
    end;
  C:=ActiveConfiguration;
  if C is TWebDataStructure then TWebDataStructure(C).ShowDefaultFieldOrder;
end;

destructor TWebConfigurationModule.Destroy;
begin
  FWebConfigurations.Free;
  FConfigurationStream.Free;
  inherited Destroy;
end;

procedure TWebConfigurationModule.AddConfigurationPage(APage: TUniTabSheet;
  AConfiguration: TWebConfigurationBase);
begin
  AConfiguration.Parent := APage;
  AConfiguration.Align := alClient;
  AConfiguration.CMOwner := Self;
  FWebConfigurations.Add(APage, AConfiguration);
end;

procedure TWebConfigurationModule.CreateConfigurationPages;
begin
  { Each frame must have its own tab sheet as Owner.  In particular,
    TWebDetailedStructure loads the inherited TWebDataStructure resource first;
    sharing Self as Owner with the real TWebDataStructure instance causes the
    transient ancestor name "WebDataStructure" to collide during streaming. }
  AddConfigurationPage(pDataNodeName, TWebDataNodeName.Create(pDataNodeName));
  AddConfigurationPage(pModuletype, TWebModuletype.Create(pModuletype));
  AddConfigurationPage(pFunctionButton, TWebFunctionButton.Create(pFunctionButton));
  AddConfigurationPage(pDataStructure, TWebDataStructure.Create(pDataStructure));
  AddConfigurationPage(pDetailedStructure, TWebDetailedStructure.Create(pDetailedStructure));
  AddConfigurationPage(pDataPerspective, TWebDataPerspective.Create(pDataPerspective));
  AddConfigurationPage(pQueryCriteria, TWebQueryCriteria.Create(pQueryCriteria));
  AddConfigurationPage(pNormalSetting, TWebNormalSetting.Create(pNormalSetting));
end;

function TWebConfigurationModule.ActiveConfiguration: TWebConfigurationBase;
begin
  if not FWebConfigurations.TryGetValue(pConfigurationPages.ActivePage, Result) then
    Result := nil;
end;

procedure TWebConfigurationModule.SendConfigurationStream(
  AConfigurationStream: TUgConfigurationStream);
begin
  if not Assigned(AConfigurationStream) then
    Exit;
  { TUgConfigurationStream.AssignTo in the shared legacy host unit copies in
    the wrong direction.  Copy through the underlying stream here so loading
    an existing host configuration neither clears the caller's stream nor
    depends on that legacy implementation. }
  FConfigurationStream.LoadFromStream(AConfigurationStream.Stream);
  LoadConfigurationStream;
end;

procedure TWebConfigurationModule.AttachConfigurationStream(
  AConfigurationStream: TUgConfigurationStream);
begin
  FConfigurationTarget := AConfigurationStream;
  SendConfigurationStream(AConfigurationStream);
end;

procedure TWebConfigurationModule.AttachRunFrame(ARunFrame: TComponent);
begin
  FRunFrameTarget := ARunFrame;
end;

procedure TWebConfigurationModule.LoadConfigurationStream;
var
  LText: TStringStream;
  LDocument: TUniGuiConfigurationDocument;
  LConfiguration: TWebConfigurationBase;
begin
  if FConfigurationStream.Stream.Size = 0 then
  begin
    pConfigurationPages.ActivePage:=pDataNodeName;
    WizardPageChanged(nil);
    Exit;
  end;
  LText := TStringStream.Create('', TEncoding.UTF8);
  LDocument := TUniGuiConfigurationDocument.Create;
  try
    FConfigurationStream.SaveToStream(LText);
    LDocument.LoadFromText(LText.DataString);
    for LConfiguration in FWebConfigurations.Values do
      LConfiguration.LoadConfigure(LDocument.Root);
    RefSupportConfiguration;
    if (LDocument.Root.GetValue('TWebModuletype')<>nil) and
      (Trim(LDocument.Root.GetValue('TWebModuletype').Value)<>'') and pNormalSetting.TabVisible then
      pConfigurationPages.ActivePage:=pNormalSetting
    else pConfigurationPages.ActivePage:=pDataNodeName;
    WizardPageChanged(nil);
  finally
    LDocument.Free;
    LText.Free;
  end;
end;

procedure TWebConfigurationModule.SaveConfigurationStream;
var
  LText: TStringStream;
  LDocument: TUniGuiConfigurationDocument;
  LConfiguration: TWebConfigurationBase;
begin
  LDocument := TUniGuiConfigurationDocument.Create;
  LText := TStringStream.Create('', TEncoding.UTF8);
  try
    { Preserve scalar/unknown options while replacing data-set sections. }
    if FConfigurationStream.Stream.Size > 0 then
    begin
      FConfigurationStream.SaveToStream(LText);
      LDocument.LoadFromText(LText.DataString);
      LText.Size := 0;
      LText.Position := 0;
    end;
    for LConfiguration in FWebConfigurations.Values do
      LConfiguration.SaveConfigure(LDocument.Root);
    LText.WriteString(LDocument.SaveToText);
    LText.Position := 0;
    FConfigurationStream.LoadFromStream(LText);
  finally
    LText.Free;
    LDocument.Free;
  end;
end;

procedure TWebConfigurationModule.RefSupportConfiguration(AllShow: Boolean);
var
  LDocument: TUniGuiConfigurationDocument;
  LText: TStringStream;
  LModuleType: string;
  LConfiguration: TWebConfigurationBase;
  LDataStructureConfiguration: TWebConfigurationBase;
  LDataPerspectiveConfiguration: TWebConfigurationBase;
  LQueryCriteriaConfiguration: TWebConfigurationBase;
  LFunctionButtonConfiguration: TWebConfigurationBase;
  LNormalSettingConfiguration: TWebConfigurationBase;
  LDetailedStructureConfiguration: TWebConfigurationBase;
  LActivePage: TUniTabSheet;
begin
  LActivePage := pConfigurationPages.ActivePage;
  pDataNodeName.TabVisible := True;
  pModuletype.TabVisible := True;
  pFunctionButton.TabVisible := AllShow;
  pDataStructure.TabVisible := AllShow;
  pDetailedStructure.TabVisible := AllShow;
  pDataPerspective.TabVisible := AllShow;
  pQueryCriteria.TabVisible := AllShow;
  pNormalSetting.TabVisible := AllShow;
  if AllShow or (FConfigurationStream.Stream.Size = 0) then
  begin
    if Assigned(LActivePage) and LActivePage.TabVisible then
      pConfigurationPages.ActivePage := LActivePage;
    Exit;
  end;

  LDocument := TUniGuiConfigurationDocument.Create;
  LText := TStringStream.Create('', TEncoding.UTF8);
  try
    FConfigurationStream.SaveToStream(LText);
    LDocument.LoadFromText(LText.DataString);
    LModuleType := LDocument.ModuleType;
    for LConfiguration in FWebConfigurations.Values do
    begin
      LConfiguration.DataNodeName := LDocument.DataNodeName;
      if LConfiguration is TWebFunctionButton then
        TWebFunctionButton(LConfiguration).SetModuleType(LModuleType);
    end;
    if FWebConfigurations.TryGetValue(pDataStructure,
      LDataStructureConfiguration) and
      FWebConfigurations.TryGetValue(pDataPerspective,
      LDataPerspectiveConfiguration) then
      TWebDataPerspective(LDataPerspectiveConfiguration).SetSourceColumns(
        TWebDataStructure(LDataStructureConfiguration).cdsColumns);
    if FWebConfigurations.TryGetValue(pDataStructure,
      LDataStructureConfiguration) and
      FWebConfigurations.TryGetValue(pQueryCriteria,
      LQueryCriteriaConfiguration) then
      TWebQueryCriteria(LQueryCriteriaConfiguration).SetSourceColumns(
        TWebDataStructure(LDataStructureConfiguration).cdsColumns);
    if FWebConfigurations.TryGetValue(pFunctionButton,
      LFunctionButtonConfiguration) and
      FWebConfigurations.TryGetValue(pNormalSetting,
      LNormalSettingConfiguration) then
      TWebNormalSetting(LNormalSettingConfiguration).SetContext(LModuleType,
        TWebFunctionButton(LFunctionButtonConfiguration).SelectedButtons);
    if FWebConfigurations.TryGetValue(pDataStructure,
      LDataStructureConfiguration) and
      FWebConfigurations.TryGetValue(pDetailedStructure,
      LDetailedStructureConfiguration) and
      FWebConfigurations.TryGetValue(pNormalSetting,
      LNormalSettingConfiguration) then
      TWebNormalSetting(LNormalSettingConfiguration).SetSourceColumns(
        TWebDataStructure(LDataStructureConfiguration).cdsColumns,
        TWebDetailedStructure(LDetailedStructureConfiguration).cdsColumns,
        TWebDataStructure(LDataStructureConfiguration).cdsTypesetting);
    pDataStructure.TabVisible := True;
    pNormalSetting.TabVisible := True;
    pFunctionButton.TabVisible := not SameText(LModuleType, 'mtEditor');
    { 从表结构页：mtListEditor 的明细（从表）也在这里配置——没有这一页，精灵里根本进不去配从表。 }
    pDetailedStructure.TabVisible := SameText(LModuleType, 'mtMasterSlave') or
      SameText(LModuleType, 'mtDetail') or SameText(LModuleType, 'mtListEditor');
    pDataPerspective.TabVisible := SameText(LModuleType, 'mtReport');
    pQueryCriteria.TabVisible := SameText(LModuleType, 'mtMultiple') or
      SameText(LModuleType, 'mtListEditor') or
      SameText(LModuleType, 'mtReport');
    { TabVisible=False can make UniGUI select a different page immediately.
      Restore the page that initiated Next so btNextClick calculates the next
      visible page from the correct index. }
    if Assigned(LActivePage) and LActivePage.TabVisible then
      pConfigurationPages.ActivePage := LActivePage;
  finally
    LText.Free;
    LDocument.Free;
  end;
end;

procedure TWebConfigurationModule.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := True;
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebConfigurationModule.btShowJsonClick(Sender: TObject);
var
  LText: TStringStream;
  LForm: TWebShowJson;
  LJson: string;
begin
  SaveConfigurationStream;
  LText := TStringStream.Create('', TEncoding.UTF8);
  try
    FConfigurationStream.SaveToStream(LText);
    LJson := LText.DataString;
  finally
    LText.Free;
  end;

  LForm := TWebShowJson.Create(UniApplication);
  try
    LForm.Json := LJson;
    LForm.FreeOnClose := True;
    LForm.ShowModal;
  except
    LForm.Free;
    raise;
  end;
end;

procedure TWebConfigurationModule.btPriorClick(Sender: TObject);
var
  I: Integer;
  LActive: TWebConfigurationBase;
begin
  LActive := ActiveConfiguration;
  if Assigned(LActive) then
    LActive.CurrentAction(patPrior);
  for I := pConfigurationPages.ActivePageIndex - 1 downto 0 do
    if pConfigurationPages.Pages[I].TabVisible then
    begin
      pConfigurationPages.ActivePageIndex := I;
      Break;
    end;
  WizardPageChanged(nil);
end;

procedure TWebConfigurationModule.btNextClick(Sender: TObject);
var
  I: Integer;
  LActive: TWebConfigurationBase;
begin
  LActive := ActiveConfiguration;
  if Assigned(LActive) and not LActive.CheckConfigure then
    Exit;
  if Assigned(LActive) then
    LActive.CurrentAction(patNext);
  SaveConfigurationStream;
  RefSupportConfiguration;
  for I := pConfigurationPages.ActivePageIndex + 1 to pConfigurationPages.PageCount - 1 do
    if pConfigurationPages.Pages[I].TabVisible then
    begin
      pConfigurationPages.ActivePageIndex := I;
      Break;
    end;
  WizardPageChanged(nil);
end;

procedure TWebConfigurationModule.btCompleteClick(Sender: TObject);
var
  LActive: TWebConfigurationBase;
  LText: TStringStream;
  LJSON: TJSONValue;
  LGenerated: Boolean;
  LDesignFrame: IUGDesignFrame;
begin
  LActive := ActiveConfiguration;
  if Assigned(LActive) and not LActive.CheckConfigure then
    Exit;
  SaveConfigurationStream;
  LGenerated := False;
  if Assigned(FRunFrameTarget) then
  begin
    LText := TStringStream.Create('', TEncoding.UTF8);
    try
      FConfigurationStream.SaveToStream(LText);
      LJSON := TJSONObject.ParseJSONValue(LText.DataString);
      try
        if not (LJSON is TJSONObject) then
          raise ERunFrameGeneration.Create('生成配置不是 JSON 对象。');
        LGenerated := TryApplyEmbeddedRunFrameReference(TJSONObject(LJSON),
          FRunFrameTarget);
      finally
        LJSON.Free;
      end;
    finally
      LText.Free;
    end;
  end;
  if Assigned(FConfigurationTarget) then
    FConfigurationTarget.LoadFromStream(FConfigurationStream.Stream);
  if LGenerated and Assigned(FRunFrameTarget.Owner) and
    FRunFrameTarget.Owner.GetInterface(IUGDesignFrame, LDesignFrame) then
  begin
    LDesignFrame.RefDesignScriptCode;
  end;
  ModalResult := mrOk;
end;

procedure TWebConfigurationModule.btCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
