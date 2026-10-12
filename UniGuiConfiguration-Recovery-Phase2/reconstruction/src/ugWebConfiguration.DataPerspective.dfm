inherited WebDataPerspective: TWebDataPerspective
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
      Left = 3
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
      Left = 84
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
      Left = 165
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
      Left = 253
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
      Left = 334
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
      Left = 246
      Top = 3
      Width = 1
      Height = 26
      Hint = ''
      Align = alLeft
      TabOrder = 6
      Caption = 'UniPanel1'
      Color = clBackground
    end
  end
  object gridDataPerspective: TUniDBGrid
    Left = 0
    Top = 32
    Width = 1320
    Height = 668
    Hint = ''
    DataSource = dsDataPerspective
    Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow, dgRowNumbers]
    ReadOnly = True
    WebOptions.Paged = False
    Grouping.FieldName = 'fdGroup'
    Grouping.FieldCaption = #32452#21035
    Grouping.Enabled = True
    LoadMask.Message = 'Loading data...'
    Align = alClient
    TabOrder = 1
    OnColumnSort = gridDataPerspectiveColumnSort
    Columns = <
      item
        FieldName = 'fdCOLUMN_NAME'
        Title.Caption = #23383#27573#21517#31216
        Width = 180
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCOLUMN_AS'
        Title.Caption = #21035#31216
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
        FieldName = 'fdGroup'
        Title.Caption = #34920#22836#32452#21035
        Width = 180
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdType'
        Title.Caption = #36879#35270#31867#22411
        Width = 80
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdDBlClickGoToDtails'
        Title.Caption = ' '#36339#36716#26126#32454
        Width = 80
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdSort'
        Title.Caption = #25490#24207
        Width = 80
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
    >
  end
  object cdsDataPerspective: TClientDataSet
    Aggregates = <
    >
    FieldDefs = <
    >
    IndexDefs = <
      item
        Name = 'cdsDataPerspectiveIndex1'
        Fields = 'fdSort'
      end
    >
    IndexName = 'cdsDataPerspectiveIndex1'
    Params = <
    >
    StoreDefs = True
    AfterPost = cdsDataPerspectiveAfterPost
    AfterDelete = cdsDataPerspectiveAfterDelete
    AfterScroll = cdsDataPerspectiveAfterScroll
    Left = 360
    Top = 360
  end
  object dsDataPerspective: TDataSource
    DataSet = cdsDataPerspective
    Left = 360
    Top = 288
  end
end
