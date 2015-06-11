object ProgressDialog: TProgressDialog
  Left = 0
  Top = 0
  Caption = 'Scanning...'
  ClientHeight = 88
  ClientWidth = 284
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnClose = FormClose
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 104
    Top = 48
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    TabOrder = 0
    OnClick = Button1Click
  end
  object ProgressBar1: TProgressBar
    Left = 21
    Top = 15
    Width = 241
    Height = 17
    Step = 1
    TabOrder = 1
  end
end
