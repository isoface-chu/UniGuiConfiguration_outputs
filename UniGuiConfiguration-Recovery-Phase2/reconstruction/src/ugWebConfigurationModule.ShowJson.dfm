inherited WebShowJson: TWebShowJson
  ClientHeight = 530
  ClientWidth = 974
  Caption = 'WebShowJson'
  ExplicitWidth = 990
  ExplicitHeight = 569
  PixelsPerInch = 96
  TextHeight = 13
  object Pages: TUniPageControl
    Left = 0
    Top = 0
    Width = 974
    Height = 530
    Hint = ''
    ActivePage = pJSON
    Align = alClient
    TabOrder = 0
    object pJSON: TUniTabSheet
      Hint = ''
      Caption = #37197#32622#25968#25454
    end
    object pInfo: TUniTabSheet
      Hint = ''
      Caption = #31934#28789#35768#21487
      object mmInfo: TUniMemo
        Left = 0
        Top = 0
        Width = 966
        Height = 502
        Hint = ''
        Align = alClient
        ReadOnly = True
        TabOrder = 0
      end
    end
  end
end
