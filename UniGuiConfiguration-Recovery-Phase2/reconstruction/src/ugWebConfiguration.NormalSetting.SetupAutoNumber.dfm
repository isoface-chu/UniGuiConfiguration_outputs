inherited WebNormalSettingSetupAutoNumber: TWebNormalSettingSetupAutoNumber
  ClientHeight = 227
  ClientWidth = 264
  Caption = #35774#32622#21462#21495#35268#21017
  BorderIcons = [biSystemMenu]
  ExplicitWidth = 280
  ExplicitHeight = 266
  PixelsPerInch = 96
  TextHeight = 13
  object pButton: TUniContainerPanel
    Left = 0
    Top = 187
    Width = 264
    Height = 40
    Hint = ''
    ParentColor = False
    Align = alBottom
    TabOrder = 0
    object btOk: TUniButton
      AlignWithMargins = True
      Left = 141
      Top = 3
      Width = 120
      Height = 34
      Hint = ''
      Caption = #30830#23450
      Align = alRight
      TabOrder = 1
      OnClick = btOkClick
    end
  end
  object cbAutoNumberType: TUniComboBox
    AlignWithMargins = True
    Left = 3
    Top = 41
    Width = 258
    Height = 24
    Hint = ''
    Margins.Top = 8
    Style = csDropDownList
    Text = ''
    Items.Strings = (
      'Guid'
      'SeqUence'
      'MaxCode'
      'DateTimeRandom'
      'DBAutoincrement'
    )
    Align = alTop
    TabOrder = 1
    EmptyText = #35831#36873#25321#32534#21495#26041#24335
    FieldLabel = #32534#21495#26041#24335
    FieldLabelAlign = laRight
    IconItems = <
    >
    OnChange = cbAutoNumberTypeChange
  end
  object cbField: TUniComboBox
    AlignWithMargins = True
    Left = 3
    Top = 8
    Width = 258
    Hint = ''
    Margins.Top = 8
    Text = ''
    Align = alTop
    TabOrder = 2
    EmptyText = #35831#35774#32622#32534#21495#23383#27573
    FieldLabel = #32534#21495#23383#27573
    FieldLabelAlign = laRight
    IconItems = <
    >
  end
  object seDigitCapacity: TUniSpinEdit
    AlignWithMargins = True
    Left = 3
    Top = 134
    Width = 258
    Hint = ''
    TabOrder = 3
    Align = alTop
    FieldLabel = #32534#21495#20301#25968
    FieldLabelAlign = laRight
  end
  object edPrefix: TUniEdit
    AlignWithMargins = True
    Left = 3
    Top = 106
    Width = 258
    Hint = ''
    Text = ''
    Align = alTop
    TabOrder = 4
    EmptyText = #35831#35774#32622#21069#32512#35268#21017
    FieldLabel = #32534#21495#21069#32512
    FieldLabelAlign = laRight
  end
  object cbSeqUence: TUniComboBox
    AlignWithMargins = True
    Left = 3
    Top = 76
    Width = 258
    Height = 24
    Hint = ''
    Margins.Top = 8
    Text = ''
    Items.Strings = (
      'Guid'
      'SeqUence'
      'MaxCode'
      'DateTimeRandom'
    )
    Align = alTop
    TabOrder = 5
    EmptyText = #35831#36873#25321#21462#25968#24207#21015
    FieldLabel = #21462#25968#24207#21015
    FieldLabelAlign = laRight
    IconItems = <
    >
  end
  object edSuffix: TUniEdit
    AlignWithMargins = True
    Left = 3
    Top = 162
    Width = 258
    Hint = ''
    Text = ''
    Align = alTop
    TabOrder = 6
    EmptyText = #35831#35774#32622#21518#32512#35268#21017
    FieldLabel = #32534#21495#21518#32512
    FieldLabelAlign = laRight
  end
end
