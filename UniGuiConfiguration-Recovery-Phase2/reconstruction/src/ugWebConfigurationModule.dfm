object WebConfigurationModule: TWebConfigurationModule
  Left = 0
  Top = 0
  Caption = #27169#22359#37197#32622#31934#28789'[WEB]'
  ClientHeight = 800
  ClientWidth = 1280
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCloseQuery = FormCloseQuery
  PixelsPerInch = 96
  TextHeight = 13
  object pConfigurationPages: TUniPageControl
    Left = 0
    Top = 28
    Width = 1280
    Height = 734
    Hint = ''
    ActivePage = pDataNodeName
    TabBarVisible = False
    Align = alClient
    TabOrder = 0
    ExplicitWidth = 1302
    ExplicitHeight = 645
    object pDataNodeName: TUniTabSheet
      Hint = ''
      Caption = #25968#25454#33410#28857
      ExplicitWidth = 1294
      ExplicitHeight = 617
    end
    object pModuletype: TUniTabSheet
      Hint = ''
      Caption = #27169#22359#31867#22411
      ExplicitWidth = 1294
      ExplicitHeight = 617
    end
    object pFunctionButton: TUniTabSheet
      Hint = ''
      Caption = #21151#33021#25353#38062
      ExplicitWidth = 1294
      ExplicitHeight = 617
    end
    object pDataStructure: TUniTabSheet
      Hint = ''
      Caption = #25968#25454#32467#26500
      ExplicitWidth = 1294
      ExplicitHeight = 617
    end
    object pDetailedStructure: TUniTabSheet
      Hint = ''
      Caption = #20174#34920#32467#26500
      ExplicitWidth = 1294
      ExplicitHeight = 617
    end
    object pDataPerspective: TUniTabSheet
      Hint = ''
      Caption = #25968#25454#36879#35270
      ExplicitWidth = 1294
      ExplicitHeight = 617
    end
    object pQueryCriteria: TUniTabSheet
      Hint = ''
      Caption = #26597#35810#26465#20214
      ExplicitWidth = 1294
      ExplicitHeight = 617
    end
    object pNormalSetting: TUniTabSheet
      Hint = ''
      Caption = #24120#35268#35774#32622
      ExplicitWidth = 1294
      ExplicitHeight = 617
    end
  end
  object pTop: TUniContainerPanel
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 1274
    Height = 22
    Hint = ''
    ParentColor = False
    Align = alTop
    TabOrder = 1
    ExplicitWidth = 1296
    object capDataNodeName: TUniLabel
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 48
      Height = 13
      Hint = ''
      Enabled = False
      Caption = #25968#25454#33410#28857
      Align = alLeft
      TabOrder = 1
    end
    object arrowhead1: TUniLabel
      AlignWithMargins = True
      Left = 57
      Top = 3
      Width = 12
      Height = 13
      Hint = ''
      Enabled = False
      Caption = '->'
      Align = alLeft
      TabOrder = 2
    end
    object capModuletype: TUniLabel
      AlignWithMargins = True
      Left = 75
      Top = 3
      Width = 48
      Height = 13
      Hint = ''
      Enabled = False
      Caption = #27169#22359#31867#22411
      Align = alLeft
      TabOrder = 3
    end
    object arrowhead2: TUniLabel
      AlignWithMargins = True
      Left = 129
      Top = 3
      Width = 12
      Height = 13
      Hint = ''
      Enabled = False
      Caption = '->'
      Align = alLeft
      TabOrder = 4
    end
    object capFunctionButton: TUniLabel
      AlignWithMargins = True
      Left = 147
      Top = 3
      Width = 48
      Height = 13
      Hint = ''
      Enabled = False
      Caption = #21151#33021#25353#38062
      Align = alLeft
      TabOrder = 5
    end
    object arrowhead3: TUniLabel
      AlignWithMargins = True
      Left = 201
      Top = 3
      Width = 12
      Height = 13
      Hint = ''
      Enabled = False
      Caption = '->'
      Align = alLeft
      TabOrder = 6
    end
    object capDataStructure: TUniLabel
      AlignWithMargins = True
      Left = 219
      Top = 3
      Width = 48
      Height = 13
      Hint = ''
      Enabled = False
      Caption = #25968#25454#32467#26500
      Align = alLeft
      TabOrder = 7
    end
    object arrowhead4: TUniLabel
      AlignWithMargins = True
      Left = 273
      Top = 3
      Width = 12
      Height = 13
      Hint = ''
      Enabled = False
      Caption = '->'
      Align = alLeft
      TabOrder = 8
    end
    object capQueryCriteria: TUniLabel
      AlignWithMargins = True
      Left = 435
      Top = 3
      Width = 48
      Height = 13
      Hint = ''
      Enabled = False
      Caption = #26597#35810#26465#20214
      Align = alLeft
      TabOrder = 9
    end
    object arrowhead7: TUniLabel
      AlignWithMargins = True
      Left = 489
      Top = 3
      Width = 12
      Height = 13
      Hint = ''
      Enabled = False
      Caption = '->'
      Align = alLeft
      TabOrder = 10
    end
    object capNormalSetting: TUniLabel
      AlignWithMargins = True
      Left = 507
      Top = 3
      Width = 48
      Height = 13
      Hint = ''
      Enabled = False
      Caption = #24120#35268#35774#32622
      Align = alLeft
      TabOrder = 11
    end
    object capDataPerspective: TUniLabel
      AlignWithMargins = True
      Left = 363
      Top = 3
      Width = 48
      Height = 13
      Hint = ''
      Enabled = False
      Caption = #25968#25454#36879#35270
      Align = alLeft
      TabOrder = 12
    end
    object arrowhead6: TUniLabel
      AlignWithMargins = True
      Left = 417
      Top = 3
      Width = 12
      Height = 13
      Hint = ''
      Enabled = False
      Caption = '->'
      Align = alLeft
      TabOrder = 13
    end
    object btShowJson: TUniSpeedButton
      Left = 1251
      Top = 0
      Width = 23
      Height = 22
      Hint = ''
      Caption = ''
      Align = alRight
      ParentColor = False
      Images = UniNativeImageList1
      ImageIndex = 14
      TabOrder = 14
      OnClick = btShowJsonClick
      ExplicitLeft = 1273
    end
    object arrowhead5: TUniLabel
      AlignWithMargins = True
      Left = 345
      Top = 3
      Width = 12
      Height = 13
      Hint = ''
      Enabled = False
      Caption = '->'
      Align = alLeft
      TabOrder = 15
    end
    object capDetailedStructure: TUniLabel
      AlignWithMargins = True
      Left = 291
      Top = 3
      Width = 48
      Height = 13
      Hint = ''
      Enabled = False
      Caption = #20174#34920#32467#26500
      Align = alLeft
      TabOrder = 16
    end
  end
  object pBottom: TUniContainerPanel
    AlignWithMargins = True
    Left = 3
    Top = 765
    Width = 1274
    Height = 32
    Hint = ''
    ParentColor = False
    Align = alBottom
    TabOrder = 2
    ExplicitTop = 676
    ExplicitWidth = 1296
    object btPrior: TUniButton
      AlignWithMargins = True
      Left = 953
      Top = 3
      Width = 75
      Height = 26
      Hint = ''
      Caption = #19978#19968#27493
      Align = alRight
      TabOrder = 1
      OnClick = btPriorClick
      ExplicitLeft = 975
    end
    object btNext: TUniButton
      AlignWithMargins = True
      Left = 1034
      Top = 3
      Width = 75
      Height = 26
      Hint = ''
      Caption = #19979#19968#27493
      Align = alRight
      TabOrder = 2
      OnClick = btNextClick
      ExplicitLeft = 1056
    end
    object btComplete: TUniButton
      AlignWithMargins = True
      Left = 1115
      Top = 3
      Width = 75
      Height = 26
      Hint = ''
      Caption = #23436#25104
      Align = alRight
      TabOrder = 3
      OnClick = btCompleteClick
      ExplicitLeft = 1137
    end
    object btCancel: TUniButton
      AlignWithMargins = True
      Left = 1196
      Top = 3
      Width = 75
      Height = 26
      Hint = ''
      Caption = #25918#24323
      Align = alRight
      TabOrder = 4
      OnClick = btCancelClick
      ExplicitLeft = 1218
    end
  end
  object UniNativeImageList1: TUniNativeImageList
    Left = 188
    Top = 180
    Images = {
      0F000000FFFFFF1F061E00000069636F6E2069636F6E666F6E742069636F6E2D
      63686178756E3B66615F3BFFFFFF1F061F00000069636F6E2069636F6E666F6E
      742069636F6E2D616464456467653B66615F3BFFFFFF1F062000000069636F6E
      2069636F6E666F6E742069636F6E2D7368616E636875333B66615F3BFFFFFF1F
      061F00000069636F6E2069636F6E666F6E742069636F6E2D786975676169313B
      66615F3BFFFFFF1F062B00000069636F6E2069636F6E666F6E742069636F6E2D
      69636F5F64616F72755F7875616E7A686F6E673B66615F3BFFFFFF1F061F0000
      0069636F6E2069636F6E666F6E742069636F6E2D62616F63756E313B66615F3B
      FFFFFF1F062000000069636F6E2069636F6E666F6E742069636F6E2D63686578
      69616F343B66615F3BFFFFFF1F062100000069636F6E2069636F6E666F6E7420
      69636F6E2D7765622D69636F6E2D3B66615F3BFFFFFF1F061E00000069636F6E
      2069636F6E666F6E742069636F6E2D646179696E333B66615F3BFFFFFF1F061F
      00000069636F6E2069636F6E666F6E742069636F6E2D6775616E6269333B6661
      5F3BFFFFFF1F062200000069636F6E2069636F6E666F6E742069636F6E2D7869
      616E677368616E673B66615F3BFFFFFF1F062000000069636F6E2069636F6E66
      6F6E742069636F6E2D7869616E677869613B66615F3BFFFFFF1F062000000069
      636F6E2069636F6E666F6E742069636F6E2D7869616E677A756F3B66615F3BFF
      FFFF1F062000000069636F6E2069636F6E666F6E742069636F6E2D7869616E67
      796F753B66615F3BFFFFFF1F062000000069636F6E2069636F6E666F6E742069
      636F6E2D7368657A68695F323B66615F3B}
  end
end
