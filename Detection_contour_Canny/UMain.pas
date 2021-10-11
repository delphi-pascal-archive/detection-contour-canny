unit UMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ExtDlgs, ComCtrls;

type
  TFrmDemoMain = class(TForm)
    Panel1: TPanel;
    btnDoOpenBMP: TButton;
    GroupBox1: TGroupBox;
    Panel2: TPanel;
    Splitter1: TSplitter;
    ScrollBox1: TScrollBox;
    imgOriginal: TImage;
    ScrollBox2: TScrollBox;
    imgResized: TImage;
    OpenPictureDialog1: TOpenPictureDialog;
    Button1: TButton;
    GroupBox2: TGroupBox;
    Label1: TLabel;
    ERadius: TEdit;
    Label2: TLabel;
    ETheta: TEdit;
    GroupBox3: TGroupBox;
    Label3: TLabel;
    Label4: TLabel;
    ELow: TEdit;
    EHigh: TEdit;
    ComboStep: TComboBox;
    Label5: TLabel;
    Label6: TLabel;
    ComboMap: TComboBox;
    procedure btnDoOpenBMPClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ComboChange(Sender: TObject);
    procedure CBGrayScaleClick(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  FrmDemoMain: TFrmDemoMain;

implementation

uses UCanny;

{$R *.dfm}

var
  aBmp: TBitmap;

procedure TFrmDemoMain.btnDoOpenBMPClick(Sender: TObject);
begin
  if OpenPictureDialog1.Execute then
  begin
    imgOriginal.Picture.Bitmap.LoadFromFile(OpenPictureDialog1.FileName);
  end;
end;

procedure TFrmDemoMain.Button1Click(Sender: TObject);
var
 theta:single;
 radius:integer;
 l,h:integer;
begin
 if not trystrtoint(ERadius.Text,radius) then radius:=3;
 if not trystrtoFloat(ETheta.Text,theta) then theta:=1.0;

 if not trystrtoint(ELow.Text,l) then l:=30;
 if not trystrtoint(EHigh.Text,h) then h:=60;

 Canny(imgOriginal.Picture.Bitmap,imgResized.Picture.Bitmap,radius,theta,l,h,
       ComboMap.ItemIndex,ComboStep.ItemIndex);
 imgResized.Invalidate;
end;

procedure TFrmDemoMain.ComboChange(Sender: TObject);
begin
 Button1Click(self);
end;

procedure TFrmDemoMain.CBGrayScaleClick(Sender: TObject);
begin
 Button1Click(self);
end;

end.
