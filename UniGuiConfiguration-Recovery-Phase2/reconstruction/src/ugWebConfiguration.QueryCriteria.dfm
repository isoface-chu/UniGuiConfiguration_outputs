inherited WebQueryCriteria: TWebQueryCriteria
  object pButtons: TUniContainerPanel
    Left = 0
    Top = 0
    Width = 1320
    Height = 32
    Hint = ''
    ParentColor = False
    Align = alTop
    TabOrder = 0
    object btAppend: TUniButton
      AlignWithMargins = True
      Left = 116
      Top = 3
      Width = 75
      Height = 26
      Hint = ''
      Caption = #26032#22686
      Align = alLeft
      TabOrder = 1
      Images = WebConfigurationModule.UniNativeImageList1
      ImageIndex = 1
      OnClick = btAppendClick
    end
    object btDelete: TUniButton
      AlignWithMargins = True
      Left = 197
      Top = 3
      Width = 75
      Height = 26
      Hint = ''
      Caption = #21024#38500
      Align = alLeft
      TabOrder = 2
      Images = WebConfigurationModule.UniNativeImageList1
      ImageIndex = 2
      OnClick = btDeleteClick
    end
    object btEditor: TUniButton
      AlignWithMargins = True
      Left = 278
      Top = 3
      Width = 75
      Height = 26
      Hint = ''
      Caption = #20462#25913
      Align = alLeft
      TabOrder = 3
      Images = WebConfigurationModule.UniNativeImageList1
      ImageIndex = 3
      OnClick = btEditorClick
    end
    object btUp: TUniButton
      AlignWithMargins = True
      Left = 366
      Top = 3
      Width = 75
      Height = 26
      Hint = ''
      Caption = #21521#19978
      Align = alLeft
      TabOrder = 4
      Images = WebConfigurationModule.UniNativeImageList1
      ImageIndex = 10
      OnClick = btUpClick
    end
    object btDown: TUniButton
      AlignWithMargins = True
      Left = 447
      Top = 3
      Width = 75
      Height = 26
      Hint = ''
      Caption = #21521#19979
      Align = alLeft
      TabOrder = 5
      Images = WebConfigurationModule.UniNativeImageList1
      ImageIndex = 11
      OnClick = btDownClick
    end
    object UniPanel1: TUniPanel
      AlignWithMargins = True
      Left = 359
      Top = 3
      Width = 1
      Height = 26
      Hint = ''
      Align = alLeft
      TabOrder = 6
      Caption = 'UniPanel1'
      Color = clBackground
    end
    object btBatchAppend: TUniButton
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 100
      Height = 26
      Hint = ''
      Caption = #25209#37327#26032#22686
      Align = alLeft
      TabOrder = 7
      Images = WebConfigurationModule.UniNativeImageList1
      ImageIndex = 0
      OnClick = btBatchAppendClick
    end
    object UniPanel2: TUniPanel
      AlignWithMargins = True
      Left = 109
      Top = 3
      Width = 1
      Height = 26
      Hint = ''
      Align = alLeft
      TabOrder = 8
      Caption = 'UniPanel1'
      Color = clBackground
    end
  end
  object gridQueryCriteria: TUniDBGrid
    Left = 0
    Top = 32
    Width = 1320
    Height = 668
    Hint = ''
    ClicksToEdit = 1
    DataSource = dsQueryCriteria
    Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow, dgRowNumbers]
    ReadOnly = True
    WebOptions.Paged = False
    LoadMask.Message = 'Loading data...'
    Align = alClient
    TabOrder = 1
    OnKeyDown = gridQueryCriteriaKeyDown
    OnCellClick = gridQueryCriteriaCellClick
    OnDblClick = gridQueryCriteriaDblClick
    OnDrawColumnCell = gridQueryCriteriaDrawColumnCell
    Columns = <
      item
        FieldName = 'fdColumn_name'
        Title.Caption = #23383#27573#21517#31216
        Width = 180
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCaption'
        Title.Caption = #23383#27573#26631#39064
        Width = 180
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdComparisonOperator'
        Title.Caption = #27604#36739#36816#31639#31526
        Width = 180
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdObject_Type'
        Title.Caption = #23545#35937#31867#22411
        Width = 180
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdDropDownOptions'
        Title.Caption = #19979#25289#36873#39033
        Width = 100
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdIndePendence'
        Title.Caption = #29420#31435#26465#20214
        Width = 100
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdHideCaption'
        Title.Caption = #38544#34255#26631#39064
        Width = 100
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdSort'
        Title.Caption = #25490#24207#23383#27573
        Width = 80
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
    >
  end
  object cdsQueryCriteria: TClientDataSet
    Aggregates = <
    >
    FieldDefs = <
    >
    IndexDefs = <
      item
        Name = 'cdsQueryCriteriaIndex1'
        Fields = 'fdSort'
      end
    >
    IndexName = 'cdsQueryCriteriaIndex1'
    Params = <
    >
    StoreDefs = True
    AfterPost = cdsQueryCriteriaAfterPost
    AfterDelete = cdsQueryCriteriaAfterDelete
    AfterScroll = cdsQueryCriteriaAfterScroll
    Left = 616
    Top = 232
  end
  object dsQueryCriteria: TDataSource
    DataSet = cdsQueryCriteria
    Left = 416
    Top = 240
  end
end
