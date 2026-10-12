inherited WebQueryCriteriaSetup: TWebQueryCriteriaSetup
  ClientHeight = 220
  ClientWidth = 284
  Caption = 'WebQueryCriteriaSetup'
  BorderIcons = [biSystemMenu]
  ExplicitWidth = 302
  ExplicitHeight = 267
  PixelsPerInch = 120
  TextHeight = 16
  object cbField: TUniComboBox
    AlignWithMargins = True
    Left = 3
    Top = 8
    Width = 278
    Hint = ''
    Margins.Top = 8
    Text = ''
    Align = alTop
    TabOrder = 0
    EmptyText = #35831#36873#25321#23383#27573#21517#31216
    FieldLabel = #23383#27573#21517#31216
    FieldLabelAlign = laRight
    IconItems = <
    >
    OnChange = cbFieldChange
  end
  object edCaption: TUniEdit
    AlignWithMargins = True
    Left = 3
    Top = 41
    Width = 278
    Hint = ''
    Margins.Top = 8
    Text = ''
    Align = alTop
    TabOrder = 1
    EmptyText = #35831#36755#20837#26631#39064#26174#31034
    FieldLabel = #26631#39064#26174#31034
    FieldLabelAlign = laRight
  end
  object cbObjectType: TUniComboBox
    AlignWithMargins = True
    Left = 3
    Top = 97
    Width = 278
    Hint = ''
    Style = csDropDownList
    Text = ''
    Align = alTop
    TabOrder = 2
    EmptyText = #35831#36873#25321#23545#35937#31867#22411
    MatchFieldWidth = False
    FieldLabel = #23545#35937#31867#22411
    FieldLabelAlign = laRight
    IconItems = <
    >
  end
  object cbComparisonOperator: TUniComboBox
    AlignWithMargins = True
    Left = 3
    Top = 69
    Width = 278
    Hint = ''
    Style = csDropDownList
    Text = ''
    Align = alTop
    TabOrder = 3
    EmptyText = #35831#36873#25321#27604#36739#36816#31639#31526
    FieldLabel = #27604#36739#36816#31639#31526
    FieldLabelAlign = laRight
    IconItems = <
    >
  end
  object ckIndePendence: TUniCheckBox
    AlignWithMargins = True
    Left = 3
    Top = 130
    Width = 278
    Height = 17
    Hint = ''
    Margins.Top = 8
    Caption = ''
    Align = alTop
    TabOrder = 4
    FieldLabel = #29420#31435#26465#20214
    FieldLabelAlign = laRight
  end
  object ckHideCaption: TUniCheckBox
    AlignWithMargins = True
    Left = 3
    Top = 158
    Width = 278
    Height = 17
    Hint = ''
    Margins.Top = 8
    Caption = ''
    Align = alTop
    TabOrder = 5
    FieldLabel = #38544#34255#26631#39064
    FieldLabelAlign = laRight
  end
  object btOK: TUniButton
    AlignWithMargins = True
    Left = 180
    Top = 181
    Width = 101
    Height = 36
    Hint = ''
    Margins.Left = 180
    Caption = #30830#23450
    Align = alClient
    TabOrder = 6
    OnClick = btOKClick
  end
end
