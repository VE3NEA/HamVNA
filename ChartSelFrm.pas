//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit ChartSelFrm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, ExtCtrls, VnaResults, CommCtrl, Math;

type
  TChartSelectionFrame = class(TFrame)
    ListView1: TListView;
    procedure ListViewChange(Sender: TObject; Item: TListItem;
      Change: TItemChange);
    procedure ListView1CustomDrawItem(Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean);
  private
    TrackChanges: boolean;
    FParamGroup: TVnaParamGroup;
    procedure SetParamGroup(const Value: TVnaParamGroup);
    function GetListViewHeight(Lv: TListView): integer;
  public
    Selection: TVnaParams;
    constructor Create(AOwner: TComponent); override;
    procedure PrepareToShow;
    function IsParamPlottable(APm: TVnaParam): boolean;
    function IsParamSelected(APm: TVnaParam): boolean;

    property ParamGroup: TVnaParamGroup read FParamGroup write SetParamGroup;
  end;



implementation

uses Main;

{$R *.dfm}

constructor TChartSelectionFrame.Create(AOwner: TComponent);
begin
  inherited;
end;


function TChartSelectionFrame.GetListViewHeight(Lv: TListView): integer;
begin
  Result := TSmallpoint(ListView_ApproximateViewRect(Lv.Handle, Word(-1), Word(-1), -1)).y;
end;


procedure TChartSelectionFrame.PrepareToShow;
var
  Pm: TVnaParam;
  Item: TListItem;
begin
  TrackChanges := false;
  for Pm:=Low(TVnaParam) to High(TVnaParam) do
    begin
    Item := ListView1.Items.Add;
    Item.Caption := ParamInfo[Pm].ParamLabel;
    Item.SubItems.Add(ParamInfo[Pm].ParamName);
    Item.Data := Pointer(Ord(Pm));
    end;
  TrackChanges := true;

  ListView1.Parent.ClientHeight := GetListViewHeight(ListView1);
end;


function TChartSelectionFrame.IsParamPlottable(APm: TVnaParam): boolean;
begin
  Result := (APm in AllowedParamsByGroup[FParamGroup]) and (MainForm.Res.Params[APm] <> nil)
end;


function TChartSelectionFrame.IsParamSelected(APm: TVnaParam): boolean;
begin
  Result := IsParamPlottable(APm) and (APm in Selection);
end;

procedure TChartSelectionFrame.ListView1CustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  with ListView1.Canvas.Font do
    if IsParamPlottable(TVnaParam(Item.Data))
    then begin Color := ListView1.Font.Color; Style := [fsBold]; end
    else begin Color := clGrayText; Style := []; end
end;


procedure TChartSelectionFrame.ListViewChange(Sender: TObject; Item: TListItem;
  Change: TItemChange);
begin
  if Item.Caption = '' then Exit;
  if not TrackChanges then Exit;

  if Item.Checked
    then Selection := Selection + [TVnaParam(Item.Data)]
    else Selection := Selection - [TVnaParam(Item.Data)];

  MainForm.Chart.ParamsToChart;
end;


procedure TChartSelectionFrame.SetParamGroup(const Value: TVnaParamGroup);
var
  i: integer;
begin
  FParamGroup := Value;
  TrackChanges := false;

  Selection := [];
  for i:=0 to ListView1.Items.Count-1 do
    with ListView1.Items[i] do if Checked
      then Include(Selection, TVnaParam(Data));

  if (Selection * AllowedParamsByGroup[FParamGroup]) = [] then
    begin
    Selection := Selection + DefaultParamsByGroup[FParamGroup];
    for i:=0 to ListView1.Items.Count-1 do
      with ListView1.Items[i] do
        if TVnaParam(Data) in Selection then Checked := true;
    end;

  TrackChanges := true;
  ListView1.Invalidate;
end;


end.

