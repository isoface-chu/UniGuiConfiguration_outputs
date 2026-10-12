inherited WebDataStructure: TWebDataStructure
  object UniLabel1: TUniLabel
    Left = 104
    Top = 400
    Width = 46
    Height = 13
    Hint = ''
    Caption = 'UniLabel1'
    TabOrder = 0
  end
  object pTables: TUniContainerPanel
    Left = 0
    Top = 0
    Width = 1320
    Height = 217
    Hint = ''
    ParentColor = False
    Align = alTop
    TabOrder = 1
    object treeTables: TUniDBTreeGrid
      Left = 0
      Top = 32
      Width = 1320
      Height = 185
      Hint = ''
      DataSource = dsTables
      Align = alClient
      TabOrder = 1
      LoadMask.Message = 'Loading data...'
      Options = [dgEditing, dgTitles, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete]
      IdParentField = 'fdParent'
      IdField = 'fdGuid'
      Columns = <
        item
          FieldName = 'fdTableName'
          Title.Caption = #34920#21517
          Width = 200
          ReadOnly = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdEpithet'
          Title.Caption = #21035#31216
          Width = 60
          ReadOnly = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdAssociationMethod'
          Title.Caption = #20851#32852#26041#24335
          Width = 120
          ReadOnly = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdCriteria1'
          Title.Caption = #26465#20214'1'
          Width = 200
          ReadOnly = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdCriteria2'
          Title.Caption = #26465#20214'2'
          Width = 200
          ReadOnly = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdCriteria3'
          Title.Caption = #26465#20214'3'
          Width = 200
          ReadOnly = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
      >
    end
    object pTableButtons: TUniContainerPanel
      Left = 0
      Top = 0
      Width = 1320
      Height = 32
      Hint = ''
      ParentColor = False
      Align = alTop
      TabOrder = 2
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
    end
  end
  object pColumns: TUniContainerPanel
    Left = 0
    Top = 223
    Width = 1320
    Height = 477
    Hint = ''
    ParentColor = False
    Align = alClient
    TabOrder = 2
    object pTypesetting: TUniContainerPanel
      Left = 960
      Top = 0
      Width = 360
      Height = 477
      Hint = ''
      ParentColor = False
      Align = alRight
      TabOrder = 1
      object gridTypesetting: TUniDBGrid
        Left = 0
        Top = 0
        Width = 324
        Height = 477
        Hint = ''
        DataSource = dsTypesetting
        Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgTitleClick, dgAutoRefreshRow, dgRowNumbers]
        WebOptions.Paged = False
        Grouping.FieldName = 'fdGROUP'
        Grouping.FieldCaption = 'GROUP'
        Grouping.Enabled = True
        LoadMask.Message = 'Loading data...'
        Align = alClient
        TabOrder = 1
        OnTitleClick = gridTypesettingTitleClick
        OnColumnSort = gridTypesettingColumnSort
        Columns = <
          item
            FieldName = 'fdCOLUMN_NAME'
            Title.Caption = #23383#27573
            Width = 120
            ReadOnly = True
            Menu.MenuEnabled = True
            Menu.ColumnHideable = True
          end
          item
            FieldName = 'fdCAPTION'
            Title.Caption = #26631#39064
            Width = 150
            ReadOnly = True
            Menu.MenuEnabled = True
            Menu.ColumnHideable = True
          end
        >
      end
      object pTypesettingButton: TUniContainerPanel
        Left = 324
        Top = 0
        Width = 36
        Height = 477
        Hint = ''
        ParentColor = False
        Align = alRight
        TabOrder = 2
        object btDown: TUniButton
          AlignWithMargins = True
          Left = 3
          Top = 63
          Width = 30
          Height = 25
          Hint = ''
          Caption = ''
          Align = alTop
          TabOrder = 1
          Images = WebConfigurationModule.UniNativeImageList1
          ImageIndex = 11
          OnClick = btDownClick
        end
        object btUp: TUniButton
          AlignWithMargins = True
          Left = 3
          Top = 32
          Width = 30
          Height = 25
          Hint = ''
          Margins.Top = 32
          Caption = ''
          Align = alTop
          TabOrder = 2
          Images = WebConfigurationModule.UniNativeImageList1
          ImageIndex = 10
          OnClick = btUpClick
        end
      end
    end
    object gridColumns: TUniDBGrid
      Left = 0
      Top = 0
      Width = 960
      Height = 477
      Hint = ''
      ClicksToEdit = 1
      DataSource = dsColumns
      Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgTitleClick, dgAutoRefreshRow]
      WebOptions.Paged = False
      Grouping.FieldName = 'fdTABLE_NAME'
      Grouping.FieldCaption = 'TableName'
      Grouping.Enabled = True
      LoadMask.Message = 'Loading data...'
      Align = alClient
      TabOrder = 2
      OnKeyDown = gridColumnsKeyDown
      OnCellClick = gridColumnsCellClick
      OnTitleClick = gridColumnsTitleClick
      OnColumnSort = gridColumnsColumnSort
      OnDblClick = gridColumnsDblClick
      OnDrawColumnCell = gridColumnsDrawColumnCell
      Columns = <
        item
          FieldName = 'fdCOLUMN_NAME'
          Title.Caption = #23383#27573
          Width = 120
          ReadOnly = True
          Menu.MenuEnabled = True
          Menu.ColumnHideable = True
          Locked = True
        end
        item
          FieldName = 'fdRECNO'
          Title.Caption = #24207#21495
          Width = 45
          ReadOnly = True
          Locked = True
        end
        item
          FieldName = 'fdCAPTION'
          Title.Caption = #26631#39064
          Width = 120
          Menu.MenuEnabled = True
          Menu.ColumnHideable = True
          Locked = True
        end
        item
          FieldName = 'fdSELECT'
          Title.Caption = #36873#25321
          Width = 45
          CheckBoxField.AutoPost = True
          Locked = True
        end
        item
          FieldName = 'fdGROUP'
          Title.Caption = #32452#21035
          Width = 100
          Locked = True
        end
        item
          FieldName = 'fdOBJECT_TYPE'
          Title.Caption = #23545#35937#31867#22411
          Width = 75
          Editor = edObjectType
          Locked = True
        end
        item
          FieldName = 'fdDropDownOptions'
          Title.Caption = #19979#25289#36873#39033
          Width = 75
          ReadOnly = True
          Locked = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdCOLUMN_TYPENAME'
          Title.Caption = #23383#27573#31867#22411
          Width = 80
          ReadOnly = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdCOLUMN_PRECISION'
          Title.Caption = #25968#20540#38271#24230
          Width = 80
          ReadOnly = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          ShowToolTipAlways = False
          FieldName = 'fdCOLUMN_SCAL'
          Title.Caption = #25968#20540#20301#25968
          Width = 80
          ReadOnly = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdCOLUMN_LENGTH'
          Title.Caption = #23383#31526#38271#24230
          Width = 80
          ReadOnly = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
      >
    end
    object UniHiddenPanel1: TUniHiddenPanel
      Left = 3
      Top = 346
      Width = 160
      Height = 128
      Hint = ''
      Visible = True
      object edObjectType: TUniComboBox
        Left = 12
        Top = 29
        Width = 145
        Height = 24
        Hint = ''
        Text = 'edObjectType'
        Items.Strings = (
          'edit'
          'memo'
          'check'
          'number'
          'date'
          'time'
          'datetime'
          'combobox'
          'lookupedit'
          'lookupeditextra'
          'gridcombobox'
          'gridcomboboxextra'
        )
        TabOrder = 1
        AnyMatch = True
        MatchFieldWidth = False
        IconItems = <
        >
      end
    end
  end
  object UniSplitter1: TUniSplitter
    Left = 0
    Top = 217
    Width = 1320
    Height = 6
    Cursor = crVSplit
    Hint = ''
    Align = alTop
    ParentColor = False
    Color = clBtnFace
  end
  object cdsTables: TClientDataSet
    Aggregates = <
    >
    FieldDefs = <
    >
    IndexDefs = <
    >
    Params = <
    >
    StoreDefs = True
    AfterPost = cdsTablesAfterPost
    BeforeDelete = cdsTablesBeforeDelete
    AfterDelete = cdsTablesAfterDelete
    Left = 304
    Top = 112
  end
  object cdsColumns: TClientDataSet
    Aggregates = <
    >
    FieldDefs = <
    >
    IndexDefs = <
      item
        Name = 'cdsColumnsIndex1'
        Fields = 'fdEpithet;fdRECNO'
      end
    >
    IndexName = 'cdsColumnsIndex1'
    Params = <
    >
    StoreDefs = True
    BeforePost = cdsColumnsBeforePost
    BeforeDelete = cdsColumnsBeforeDelete
    Left = 304
    Top = 168
  end
  object dsTables: TDataSource
    DataSet = cdsTables
    Left = 408
    Top = 112
  end
  object dsColumns: TDataSource
    DataSet = cdsColumns
    Left = 408
    Top = 168
  end
  object cdsTypesetting: TClientDataSet
    Aggregates = <
    >
    Params = <
    >
    Left = 304
    Top = 224
  end
  object dsTypesetting: TDataSource
    DataSet = cdsTypesetting
    Left = 520
    Top = 152
  end
end
