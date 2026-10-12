unit ugWebConfigurationBase;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugPublicObjectManagement, ugConfiguration.DataSetJson;

type
  TPageActionType = (patPrior, patNext);

  TWebConfigurationBase = class(TUniFrame)
  private
    FUGMM: IUGMM;
    FCMOwner: TComponent;
    FDataNodeName: string;
  protected
    property UGMM: IUGMM read FUGMM;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function CheckConfigure: Boolean; virtual;
    procedure LoadConfigure(AJSON: TJSONObject); virtual;
    procedure SaveConfigure(AJSON: TJSONObject); virtual;
    procedure CurrentAction(APageActionType: TPageActionType); virtual;
    property CMOwner: TComponent read FCMOwner write FCMOwner;
    property DataNodeName: string read FDataNodeName write FDataNodeName;
  end;

implementation

{$R *.dfm}

constructor TWebConfigurationBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FUGMM := GetUGMM;
end;

destructor TWebConfigurationBase.Destroy;
begin
  inherited Destroy;
end;

function TWebConfigurationBase.CheckConfigure: Boolean;
begin
  Result := True;
end;

procedure TWebConfigurationBase.LoadConfigure(AJSON: TJSONObject);
var
  I: Integer;
  LSection: TJSONObject;
  LDataSetJSON: TJSONValue;
begin
  if not Assigned(AJSON) then
    Exit;
  if not (AJSON.GetValue(ClassName) is TJSONObject) then
    Exit;
  LSection := TJSONObject(AJSON.GetValue(ClassName));
  for I := 0 to ComponentCount - 1 do
    if (Components[I] is TClientDataSet) and (Components[I].Name <> '') then
    begin
      LDataSetJSON := LSection.GetValue(Components[I].Name);
      if LDataSetJSON is TJSONObject then
        LoadDataSetFromJSON(TClientDataSet(Components[I]), TJSONObject(LDataSetJSON));
    end;
end;

procedure TWebConfigurationBase.SaveConfigure(AJSON: TJSONObject);
var
  I: Integer;
  LPair: TJSONPair;
  LSection: TJSONObject;
  LSectionValue, LExistingValue: TJSONValue;
  LExistingDataSet, LSavedDataSet: TJSONObject;
  LMetaIndex: Integer;
  LMetaName: string;
begin
  if not Assigned(AJSON) then
    Exit;
  LSectionValue := AJSON.GetValue(ClassName);
  if LSectionValue is TJSONObject then
    LSection := TJSONObject(LSectionValue)
  else
  begin
    LPair := AJSON.RemovePair(ClassName);
    LPair.Free;
    LSection := TJSONObject.Create;
    AJSON.AddPair(ClassName, LSection);
  end;
  for I := 0 to ComponentCount - 1 do
    if (Components[I] is TClientDataSet) and (Components[I].Name <> '') then
    begin
      LExistingValue := LSection.GetValue(Components[I].Name);
      LSavedDataSet := SaveDataSetToJSON(TClientDataSet(Components[I]));
      try
        { Preserve future/host-specific metadata beside TableStructure/Data.
          The two known members are regenerated from the edited data set. }
        if LExistingValue is TJSONObject then
        begin
          LExistingDataSet := TJSONObject(LExistingValue);
          for LMetaIndex := 0 to LExistingDataSet.Count - 1 do
          begin
            LMetaName := LExistingDataSet.Pairs[LMetaIndex].JsonString.Value;
            if not SameText(LMetaName, 'TableStructure') and
              not SameText(LMetaName, 'Data') then
              LSavedDataSet.AddPair(TJSONString.Create(LMetaName),
                TJSONObject.ParseJSONValue(
                  LExistingDataSet.Pairs[LMetaIndex].JsonValue.ToJSON));
          end;
        end;
        LPair := LSection.RemovePair(Components[I].Name);
        LPair.Free;
        LSection.AddPair(Components[I].Name, LSavedDataSet);
        LSavedDataSet := nil;
      finally
        LSavedDataSet.Free;
      end;
    end;
end;

procedure TWebConfigurationBase.CurrentAction(APageActionType: TPageActionType);
begin
end;

end.
