unit ugWebConfigurationModule.ShowJson;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebCustBaseForm, Vcl.Forms;

type
  TWebShowJson = class(TWebCustBaseForm)
    Pages: TUniPageControl;
    pJSON: TUniTabSheet;
    pInfo: TUniTabSheet;
    mmInfo: TUniMemo;
  private
    FJson: string;
    FJsonMemo: TUniMemo;
    procedure SetJson(const Value: string);
  public
    property Json: string read FJson write SetJson;
  end;

implementation

{$R *.dfm}

procedure TWebShowJson.SetJson(const Value: string);
begin
  FJson := Value;
  if not Assigned(FJsonMemo) then
  begin
    FJsonMemo := TUniMemo.Create(pJSON);
    FJsonMemo.Parent := pJSON;
    FJsonMemo.Align := alClient;
    FJsonMemo.ReadOnly := True;
  end;
  FJsonMemo.Lines.Text := Value;
  Pages.ActivePage := pJSON;
end;

end.
