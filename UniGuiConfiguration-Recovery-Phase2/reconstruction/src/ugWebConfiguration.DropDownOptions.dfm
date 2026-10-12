inherited WebDropDownOptions: TWebDropDownOptions
  ClientHeight = 510
  ClientWidth = 491
  Caption = 'WebDropDownOptions'
  BorderIcons = [biSystemMenu]
  ExplicitWidth = 509
  ExplicitHeight = 557
  PixelsPerInch = 120
  TextHeight = 16
  object edCaption: TUniEdit
    AlignWithMargins = True
    Left = 3
    Top = 41
    Width = 485
    Hint = ''
    Margins.Top = 8
    Text = ''
    Align = alTop
    TabOrder = 0
    ReadOnly = True
    FieldLabel = #26631#39064#26174#31034
    FieldLabelAlign = laRight
  end
  object edObjectType: TUniEdit
    AlignWithMargins = True
    Left = 3
    Top = 8
    Width = 485
    Hint = ''
    Margins.Top = 8
    Text = ''
    Align = alTop
    TabOrder = 1
    ReadOnly = True
    FieldLabel = #23545#35937#31867#22411
    FieldLabelAlign = laRight
  end
  object UniContainerPanel1: TUniContainerPanel
    AlignWithMargins = True
    Left = 3
    Top = 104
    Width = 485
    Height = 367
    Hint = ''
    ParentColor = False
    Align = alClient
    TabOrder = 2
    object edOptionFields: TUniEdit
      AlignWithMargins = True
      Left = 0
      Top = 243
      Width = 485
      Hint = ''
      Margins.Left = 0
      Margins.Top = 8
      Margins.Right = 0
      Text = ''
      Align = alBottom
      TabOrder = 1
      EmptyText = #35831#36755#20837#23637#31034#23383#27573
      FieldLabel = #23637#31034#23383#27573
      FieldLabelAlign = laRight
      Triggers = <
        item
          ButtonId = 0
          IconCls = 'icon iconfont icon-i'
          HandleClicks = True
          Hint = #25552#31034
        end
      >
      OnTriggerEvent = edOptionFieldsTriggerEvent
    end
    object edOptionCaption: TUniEdit
      AlignWithMargins = True
      Left = 0
      Top = 210
      Width = 485
      Hint = ''
      Margins.Left = 0
      Margins.Top = 8
      Margins.Right = 0
      Text = ''
      Align = alBottom
      TabOrder = 2
      EmptyText = #35831#36755#20837#23637#31034#26631#39064
      FieldLabel = #23637#31034#26631#39064
      FieldLabelAlign = laRight
    end
    object edOptionValue: TUniEdit
      AlignWithMargins = True
      Left = 0
      Top = 309
      Width = 485
      Hint = ''
      Margins.Left = 0
      Margins.Top = 8
      Margins.Right = 0
      Text = ''
      Align = alBottom
      TabOrder = 3
      EmptyText = #35831#36755#20837#36873#39033#23383#27573
      FieldLabel = #36873#39033#23383#27573
      FieldLabelAlign = laRight
    end
    object mmText: TUniMemo
      Left = 0
      Top = 0
      Width = 485
      Height = 167
      Hint = ''
      Align = alClient
      TabOrder = 4
      FieldLabel = #36873#39033#20869#23481
      FieldLabelAlign = laRight
    end
    object edOptionDisplay: TUniEdit
      AlignWithMargins = True
      Left = 0
      Top = 342
      Width = 485
      Hint = ''
      Margins.Left = 0
      Margins.Top = 8
      Margins.Right = 0
      Text = ''
      Align = alBottom
      TabOrder = 5
      EmptyText = #35831#36755#20837#24341#29992#23383#27573
      FieldLabel = #24341#29992#23383#27573
      FieldLabelAlign = laRight
    end
    object edOptionLookupFields: TUniEdit
      AlignWithMargins = True
      Left = 0
      Top = 276
      Width = 485
      Hint = ''
      Margins.Left = 0
      Margins.Top = 8
      Margins.Right = 0
      Text = ''
      Align = alBottom
      TabOrder = 6
      EmptyText = #35831#36755#20837#25628#32034#23383#27573
      FieldLabel = #25628#32034#23383#27573
      FieldLabelAlign = laRight
    end
    object pGridPageSetting: TUniContainerPanel
      AlignWithMargins = True
      Left = 0
      Top = 175
      Width = 485
      Height = 24
      Hint = ''
      Margins.Left = 0
      Margins.Top = 8
      Margins.Right = 0
      ParentColor = False
      Align = alBottom
      TabOrder = 7
      object cbGridPageSetting: TUniComboBox
        Left = 0
        Top = 0
        Width = 235
        Height = 24
        Hint = ''
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Style = csDropDownList
        Text = 'Close'
        Items.Strings = (
          'Open'
          'Close'
        )
        ItemIndex = 1
        Align = alClient
        TabOrder = 1
        EmptyText = #35831#35774#32622#20998#39029
        FieldLabel = #20998#39029#35774#32622
        FieldLabelAlign = laRight
        IconItems = <
        >
        OnChange = cbDropDownTypeChange
      end
      object sePageSize: TUniSpinEdit
        Left = 235
        Top = 0
        Width = 250
        Height = 24
        Hint = ''
        Value = 100
        TabOrder = 2
        Align = alRight
        FieldLabel = #20998#39029#34892#25968
        FieldLabelAlign = laRight
      end
    end
  end
  object btOk: TUniButton
    AlignWithMargins = True
    Left = 380
    Top = 477
    Width = 108
    Height = 30
    Hint = ''
    Margins.Left = 380
    Caption = #30830#23450
    Align = alBottom
    TabOrder = 3
    OnClick = btOkClick
  end
  object pDropDownType: TUniContainerPanel
    AlignWithMargins = True
    Left = 3
    Top = 74
    Width = 485
    Height = 24
    Hint = ''
    Margins.Top = 8
    ParentColor = False
    Align = alTop
    TabOrder = 4
    object cbDropDownType: TUniComboBox
      Left = 0
      Top = 0
      Width = 232
      Height = 24
      Hint = ''
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
      Style = csDropDownList
      Text = ''
      Items.Strings = (
        'SetText'
        'SqlText'
        'SqlQuery'
      )
      Align = alClient
      TabOrder = 1
      EmptyText = #35831#36873#25321#36873#39033#31867#22411
      FieldLabel = #36873#39033#31867#22411
      FieldLabelAlign = laRight
      IconItems = <
      >
      OnChange = cbDropDownTypeChange
    end
    object cbDynamicLoading: TUniCheckBox
      AlignWithMargins = True
      Left = 235
      Top = 4
      Width = 100
      Height = 20
      Hint = ''
      Margins.Top = 4
      Margins.Right = 0
      Margins.Bottom = 0
      InputRTL = False
      Caption = ''
      Align = alRight
      TabOrder = 2
      FieldLabel = #21160#24577#21152#36733
      FieldLabelWidth = 80
      FieldLabelAlign = laRight
      OnChange = cbDynamicLoadingChange
    end
    object seMaxRecordCount: TUniSpinEdit
      Left = 335
      Top = 0
      Width = 150
      Height = 24
      Hint = ''
      Enabled = False
      Value = 100
      MaxValue = 300
      TabOrder = 3
      Align = alRight
      FieldLabel = #26368#22823#34892#25968
      FieldLabelWidth = 80
      FieldLabelAlign = laRight
    end
  end
end
