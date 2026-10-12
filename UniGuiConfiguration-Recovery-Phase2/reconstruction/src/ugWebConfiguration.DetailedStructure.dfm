inherited WebDetailedStructure: TWebDetailedStructure
  inherited pColumns: TUniContainerPanel
    inherited pTypesetting: TUniContainerPanel
      inherited gridTypesetting: TUniDBGrid
        Columns = <
          item
            FieldName = 'fdCOLUMN_NAME'
            Title.Caption = #23383#27573
            Width = 120
            ReadOnly = True
            Menu.MenuEnabled = False
            Menu.ColumnHideable = False
          end
          item
            FieldName = 'fdCAPTION'
            Title.Caption = #26631#39064
            Width = 160
            ReadOnly = True
            Menu.MenuEnabled = False
            Menu.ColumnHideable = False
          end
        >
      end
    end
    inherited gridColumns: TUniDBGrid
      Columns = <
        item
          FieldName = 'fdCOLUMN_NAME'
          Title.Caption = #23383#27573
          Width = 120
          ReadOnly = True
          Locked = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdRECNO'
          Title.Caption = #24207#21495
          Width = 45
          ReadOnly = True
          Locked = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdCAPTION'
          Title.Caption = #26631#39064
          Width = 120
          Locked = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdSELECT'
          Title.Caption = #36873#25321
          Width = 45
          CheckBoxField.AutoPost = True
          Locked = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdGROUP'
          Title.Caption = #32452#21035
          Width = 100
          Locked = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
        end
        item
          FieldName = 'fdOBJECT_TYPE'
          Title.Caption = #23545#35937#31867#22411
          Width = 75
          Editor = edObjectType
          Locked = True
          Menu.MenuEnabled = False
          Menu.ColumnHideable = False
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
          FieldName = 'fdDataCheck'
          Title.Caption = #25968#25454#26657#39564
          Width = 75
          ReadOnly = True
          Locked = True
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
          FieldName = 'COLUMN_SCAL'
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
  end
  inherited cdsTypesetting: TClientDataSet
    Top = 280
  end
end
