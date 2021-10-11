unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, ComCtrls, JPEG, Downsampling;

type
  TMainForm = class(TForm)
    ButtonPanel: TPanel;
    Img: TImage;
    Trackbar: TTrackBar;
    procedure FormCreate(Sender: TObject);
    procedure TrackbarChange(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  MainForm: TMainForm;
  JPG: TJPEGImage;
  Bmp, Bmp2: TBitmap;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
 { Pour commencer on affiche en taille réelle l'image }
 DoubleBuffered := True;
 Img.Picture.Bitmap := Bmp;
end;

procedure TMainForm.TrackbarChange(Sender: TObject);
begin
 { On réduit l'image en fonction de la trackbar }
 Bmp2.Width := Bmp.Width;
 Bmp2.Height := Bmp.Height;
 Bmp2.PixelFormat := pf32bit;
 Bmp2.Canvas.Draw(0, 0, Bmp);
 Downsample(Bmp2, 11 - Trackbar.Position);
 Img.Picture.Bitmap := Bmp2;
end;

initialization
 { A l'initialisation on charge le JPG et on le convertit en bitmap }
 JPG := TJPEGImage.Create;
 JPG.LoadFromFile('Image.jpg');
 Bmp := TBitmap.Create;
 Bmp.Assign(JPG);
 Bmp.PixelFormat := pf32bit;
 Bmp2 := TBitmap.Create;
 JPG.Free;

finalization
 { A la fermeture on libère les deux bitmaps de travail }
 Bmp2.Free;
 Bmp.Free;

end.
