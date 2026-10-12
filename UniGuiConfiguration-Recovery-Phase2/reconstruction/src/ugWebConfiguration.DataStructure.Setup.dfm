inherited WebDataStructureSetup: TWebDataStructureSetup
  ClientHeight = 181
  ClientWidth = 404
  Caption = #37197#32622#25968#25454#34920
  BorderIcons = [biSystemMenu]
  ExplicitWidth = 422
  ExplicitHeight = 228
  PixelsPerInch = 120
  TextHeight = 16
  object pAssociationMethod: TUniContainerPanel
    Left = 0
    Top = 0
    Width = 404
    Height = 28
    Hint = ''
    ParentColor = False
    Align = alTop
    TabOrder = 0
    object edLEpithet: TUniEdit
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 118
      Hint = ''
      Enabled = False
      Text = ''
      Align = alLeft
      TabOrder = 1
      FieldLabel = #20851#32852#26041#24335
      FieldLabelWidth = 68
      FieldLabelAlign = laRight
    end
    object cbAssociationMethod: TUniComboBox
      AlignWithMargins = True
      Left = 127
      Top = 3
      Width = 162
      Hint = ''
      Style = csDropDownList
      Text = ''
      Items.Strings = (
        'left join'
        'right join'
        'inner join'
      )
      Align = alLeft
      TabOrder = 2
      IconItems = <
      >
    end
  end
  object pTableName: TUniContainerPanel
    Left = 0
    Top = 28
    Width = 404
    Height = 28
    Hint = ''
    ParentColor = False
    Align = alTop
    TabOrder = 1
    object cbTableName: TUniComboBox
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 286
      Hint = ''
      Text = ''
      Align = alLeft
      TabOrder = 1
      EmptyText = #35831#36873#25321#25968#25454#34920
      MatchFieldWidth = False
      FieldLabel = #34920#21333#21517#31216
      FieldLabelWidth = 68
      FieldLabelAlign = laRight
      IconItems = <
      >
      OnChange = cbTableNameChange
    end
    object edEpithet: TUniEdit
      AlignWithMargins = True
      Left = 295
      Top = 3
      Width = 50
      Hint = ''
      Enabled = False
      Text = '?'
      Align = alLeft
      TabOrder = 2
      ExplicitLeft = 239
    end
    object capTableComments: TUniLabel
      AlignWithMargins = True
      Left = 353
      Top = 8
      Width = 93
      Height = 13
      Hint = ''
      Margins.Left = 5
      Margins.Top = 8
      Caption = 'capTableComments'
      Align = alClient
      TabOrder = 3
      ExplicitLeft = 297
    end
  end
  object pCriteria1: TUniContainerPanel
    Left = 0
    Top = 56
    Width = 404
    Height = 28
    Hint = ''
    ParentColor = False
    Align = alTop
    TabOrder = 2
    object edCriteriaEpithet1: TUniEdit
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 118
      Hint = ''
      Enabled = False
      Text = ''
      Align = alLeft
      TabOrder = 1
      FieldLabel = #26465#20214'1'
      FieldLabelWidth = 68
      FieldLabelAlign = laRight
    end
    object edCriteriaLField1: TUniComboBox
      AlignWithMargins = True
      Left = 127
      Top = 3
      Width = 106
      Hint = ''
      Text = ''
      Align = alLeft
      TabOrder = 2
      IconItems = <
      >
    end
    object edCriteriaEqual1: TUniEdit
      AlignWithMargins = True
      Left = 239
      Top = 3
      Width = 50
      Hint = ''
      Enabled = False
      Text = ' = '
      Align = alLeft
      TabOrder = 3
    end
    object edCriteriaRField1: TUniComboBox
      AlignWithMargins = True
      Left = 295
      Top = 3
      Width = 106
      Hint = ''
      Text = ''
      Align = alLeft
      TabOrder = 4
      IconItems = <
      >
    end
  end
  object pCriteria2: TUniContainerPanel
    Left = 0
    Top = 84
    Width = 404
    Height = 28
    Hint = ''
    ParentColor = False
    Align = alTop
    TabOrder = 3
    object edCriteriaEpithet2: TUniEdit
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 118
      Hint = ''
      Enabled = False
      Text = ''
      Align = alLeft
      TabOrder = 1
      FieldLabel = #26465#20214'2'
      FieldLabelWidth = 68
      FieldLabelAlign = laRight
    end
    object edCriteriaLField2: TUniComboBox
      AlignWithMargins = True
      Left = 127
      Top = 3
      Width = 106
      Hint = ''
      Text = ''
      Align = alLeft
      TabOrder = 2
      IconItems = <
      >
    end
    object edCriteriaEqual2: TUniEdit
      AlignWithMargins = True
      Left = 239
      Top = 3
      Width = 50
      Hint = ''
      Enabled = False
      Text = ' = '
      Align = alLeft
      TabOrder = 3
    end
    object edCriteriaRField2: TUniComboBox
      AlignWithMargins = True
      Left = 295
      Top = 3
      Width = 106
      Hint = ''
      Text = ''
      Align = alLeft
      TabOrder = 4
      IconItems = <
      >
    end
  end
  object pCriteria3: TUniContainerPanel
    Left = 0
    Top = 112
    Width = 404
    Height = 28
    Hint = ''
    ParentColor = False
    Align = alTop
    TabOrder = 4
    object edCriteriaEpithet3: TUniEdit
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 118
      Hint = ''
      Enabled = False
      Text = ''
      Align = alLeft
      TabOrder = 1
      FieldLabel = #26465#20214'3'
      FieldLabelWidth = 68
      FieldLabelAlign = laRight
    end
    object edCriteriaLField3: TUniComboBox
      AlignWithMargins = True
      Left = 127
      Top = 3
      Width = 106
      Hint = ''
      Text = ''
      Align = alLeft
      TabOrder = 2
      IconItems = <
      >
    end
    object edCriteriaEqual3: TUniEdit
      AlignWithMargins = True
      Left = 239
      Top = 3
      Width = 50
      Hint = ''
      Enabled = False
      Text = ' = '
      Align = alLeft
      TabOrder = 3
    end
    object edCriteriaRField3: TUniComboBox
      AlignWithMargins = True
      Left = 295
      Top = 3
      Width = 106
      Hint = ''
      Text = ''
      Align = alLeft
      TabOrder = 4
      IconItems = <
      >
    end
  end
  object btOk: TUniButton
    Left = 280
    Top = 143
    Width = 121
    Height = 35
    Hint = ''
    Anchors = [akRight, akBottom]
    Caption = #30830#23450
    TabOrder = 5
    OnClick = btOkClick
  end
end
