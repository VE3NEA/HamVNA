object ChartSelectionFrame: TChartSelectionFrame
  Left = 0
  Top = 0
  Width = 221
  Height = 212
  TabOrder = 0
  object ListView1: TListView
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 215
    Height = 206
    Align = alClient
    Checkboxes = True
    Columns = <
      item
        Width = 85
      end
      item
        Width = -2
        WidthType = (
          -2)
      end>
    ShowColumnHeaders = False
    TabOrder = 0
    ViewStyle = vsReport
    OnChange = ListViewChange
    OnCustomDrawItem = ListView1CustomDrawItem
    ExplicitWidth = 211
    ExplicitHeight = 88
  end
end
