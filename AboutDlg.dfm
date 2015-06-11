object AboutDialog: TAboutDialog
  Left = 394
  Top = 103
  BorderStyle = bsDialog
  Caption = 'About...'
  ClientHeight = 142
  ClientWidth = 375
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  DesignSize = (
    375
    142)
  PixelsPerInch = 96
  TextHeight = 13
  object Bevel1: TBevel
    Left = 8
    Top = 8
    Width = 357
    Height = 125
    Anchors = [akLeft, akTop, akRight]
    Shape = bsFrame
  end
  object ProgNameLabel2: TLabel
    Left = 67
    Top = 16
    Width = 220
    Height = 35
    Caption = 'ProductName'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clAqua
    Font.Height = -29
    Font.Name = 'Verdana'
    Font.Style = [fsBold]
    ParentFont = False
    Transparent = True
  end
  object ProgNameLabel1: TLabel
    Left = 70
    Top = 18
    Width = 220
    Height = 35
    Caption = 'ProductName'
    Color = clBtnFace
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clBlue
    Font.Height = -29
    Font.Name = 'Verdana'
    Font.Style = [fsBold]
    ParentColor = False
    ParentFont = False
    Transparent = True
  end
  object Label3: TLabel
    Left = 24
    Top = 66
    Width = 183
    Height = 13
    Caption = 'Copyright '#169' 2013 Afreet Software, Inc.'
  end
  object Label4: TLabel
    Left = 24
    Top = 86
    Width = 37
    Height = 13
    Caption = 'Author: '
  end
  object Label5: TLabel
    Left = 76
    Top = 86
    Width = 132
    Height = 13
    Cursor = crHandPoint
    Hint = 've3nea@dxatlas.com'
    Caption = 'Alex Shovkoplyas, VE3NEA'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clBlue
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsUnderline]
    ParentFont = False
    ParentShowHint = False
    ShowHint = True
    OnClick = Label5Click
  end
  object Label7: TLabel
    Left = 24
    Top = 106
    Width = 45
    Height = 13
    Caption = 'Web site:'
  end
  object Label6: TLabel
    Left = 76
    Top = 106
    Width = 163
    Height = 13
    Cursor = crHandPoint
    Hint = 'http://www.dxatlas.com/HamVNA'
    Caption = 'http://www.dxatlas.com/HamVNA'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clBlue
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsUnderline]
    ParentFont = False
    ParentShowHint = False
    ShowHint = True
    OnClick = Label6Click
  end
  object Label8: TLabel
    Left = 282
    Top = 53
    Width = 73
    Height = 16
    Anchors = [akTop, akRight]
    Caption = 'Freeware'
    Color = clBtnFace
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clFuchsia
    Font.Height = -13
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold, fsItalic]
    ParentColor = False
    ParentFont = False
  end
  object Image1: TImage
    Left = 25
    Top = 22
    Width = 32
    Height = 32
  end
  object Button1: TButton
    Left = 280
    Top = 96
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = '&Close'
    Default = True
    ModalResult = 1
    TabOrder = 0
  end
end
