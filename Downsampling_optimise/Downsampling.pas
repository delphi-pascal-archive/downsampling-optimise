{ Downsampling.pas
  Auteur : Bacterius

  Cette unit� permet de "downsampler" une image, c'est-�-dire r�duire sa taille sans perdre de
  qualit� (ce qu'on observe souvent en faisant par exemple un simple Stretch dans Delphi). De plus
  cette fonction est tr�s optimis�e, et bien qu'il soit probablement possible d'aller plus vite en
  utilisant les ROP int�gr�es � votre carte graphique, ce qui suit est un exemple d'optimisation
  qui permet de gagner beaucoup de performance � un prix de maintenance du code n�gligeable.

  Limitations : le code n'est pas adapt� pour des images de taille quelconque - il est n�cessaire
                que l'image ait une largeur et une hauteur paires pour qu'elle puisse �tre r�duite.
                Il est �videmment possible de modifier le code pour qu'il prenne en charge ces cas,
                mais ce n'�tait pas le but de la source, qui est d'expliquer comment optimiser. 

  AVERTISSEMENT : le code qui suit n'est pas simple � comprendre pour un n�ophyte - je recommande
                  au pr�alable la lecture de mes deux tutoriaux sur Scanline et sur les pointeurs,
                  tous deux situ�s sur le site DelphiFR (www.delphifr.com) sous mon pseudo.

  Quelques comparaisons pour une image de taille 2048 x 2048 (px), temps observ�s (en moyenne) :

                          Stretch de Delphi          (moche) : 91  millisecondes
                          StretchBlt Windows simple  (moche) : 47  millisecondes
                          StretchBlt Windows HALFTONE (beau) : 102 millisecondes
                          Downsample                  (beau) : 28  millisecondes
                          GPU ROP                     (beau) : 0.6 millisecondes

                          (GPU ROP utilise un raster operation de la carte graphique sp�cialis�
                           dans le downsampling (c'est utilis� pour effectuer un anti-aliasing),
                           il est donc normal qu'elle soit beaucoup plus rapide puisqu'elle est
                           faite en hardware et pas en software )                                  }           

unit Downsampling;

interface

uses Windows, Graphics;

function Downsample(const Bmp: TBitmap; const Factor: Longword = 1): Boolean;
function PTR_Downsample(const Src, Dst: Pointer; const Width, Height: Longword): Boolean;

implementation

{ Here be dragons }
function PTR_Downsample(const Src, Dst: Pointer; const Width, Height: Longword): Boolean;
type
 { Ici on d�clare quelques types utiles pour le parcours du pointeur de bitmap }
 TRGBQUAD = record
  B, G, R, A: Byte;
 end; PRGBQUAD = ^TRGBQUAD;

 { Ce type repr�sente deux pixels sur 32 bits se touchant horizontalement }
 TRGBDUALQUAD = record
  B1, G1, R1, A1, B2, G2, R2, A2: Byte;
 end; PRGBDUALQUAD = ^TRGBDUALQUAD;
Var
 S1, S2: PRGBDUALQUAD;
 D: PRGBQUAD;
 X, Y, W, H: Longword;
begin
 try
  { Ici l'on calcule les nouvelles dimensions du bitmap r�duit, donc largeur/hauteur divis�s par 2 }
  W := Width shr 1;
  H := Height shr 1;
  { Les deux pointeurs S1 et S2 permettent d'acc�der � un carr� de 2x2 pixels sur le bitmap. }
  S2 := Ptr(Longword(Src) + Width * 4);
  S1 := Src; D := Dst;

  { Pour chaque pixel du bitmap r�duit }
  for Y := 0 to H - 1 do
   begin
    for X := 0 to W - 1 do
     begin
      { On prend le carr� de 2x2 pixels de l'image originale et l'on calcule le pixel final en
        prenant la moyenne euclidienne des quatre pixels du carr�. Le compilateur se d�brouille
        plut�t pas mal avec ces quatre lignes suivantes. }
      D^.R := (S1^.R1 + S1^.R2 + S2^.R1 + S2^.R2) shr 2;
      D^.G := (S1^.G1 + S1^.G2 + S2^.G1 + S2^.G2) shr 2;
      D^.B := (S1^.B1 + S1^.B2 + S2^.B1 + S2^.B2) shr 2;
      D^.A := (S1^.A1 + S1^.A2 + S2^.A1 + S2^.A2) shr 2;

      { Ensuite, on passe au carr� suivant. Si on arrive au bout de la ligne du bitmap, on passe
        au d�but de la ligne suivante (on comprend pourquoi les largeurs paires ne marchent pas) }
      Inc(S1);
      Inc(S2);
      Inc(D);
     end;
    { Quand on arrive au bout de la ligne, on doit aussi faire "descendre" les deux pointeurs d'une
      autre ligne, car comme ils repr�sentent un carr� 2x2, les faire descendre d'une seule ligne
      fait que les deux carr�s se chevauchent, ce qui n'est pas correct. On saute donc une ligne. }
    Inc(S1, W);
    Inc(S2, W);
   end;

  { Si tout s'est bien pass� (pas d'erreur de pointeur, etc...) on renvoie True }
  Result := True;
 except
  { Sinon, on a rencontr� une erreur }
  Result := False;
 end;
end;

{ Cette fonction r�duit Bmp d'un facteur Factor. Factor est en fait exponential, c'est-�-dire que
  Factor = 0 ne changera pas l'image, Factor = 1 r�duira sa taille par 4 (chacune des dimensions
  est r�duite par deux), Factor = 2 r�duira sa taille par 16, Factor = 3 par 64, etc... }
function Downsample(const Bmp: TBitmap; const Factor: Longword = 1): Boolean;
Var
 N, Q, W, H: Longword;
 D: Pointer;
begin
 { On initialise tout }
 Result := False;
 D := nil; Q := 0;
 { Si le bitmap existe, et Factor est plus grand que z�ro, on peut y aller }
 if Assigned(Bmp) and (Factor <> 0) then try
  try
   { On calcule et on alloue la m�moire n�cessaire pour stocker les donn�es temporaires }
   { On note qu'il n'est n�cessaire d'allouer la m�moire qu'une fois m�me si Factor est
     plus grand que 1, puisque la taille du bitmap r�duit est strictement d�croissante. }
   Result := False;
   Q := Bmp.Width * Bmp.Height;
   GetMem(D, Q);
   { En fait, on appelle Downsample Factor fois, d'o� la nature exponentielle de ce param�tre }
   for N := 1 to Factor do
    with Bmp do begin
     { On rejette les images de taille incorrecte }
     if (Width and 1 = 1) or (Height and 1 = 1) then Exit;
     W := Width shr 1;
     H := Height shr 1;
     Q := Width * Height;
     { On r�duit l'image }
     if PTR_Downsample(ScanLine[Height - 1], D, Width, Height) then
      begin
       { Si la r�duction a r�ussi, on met � jour l'image en copiant les donn�es r�duites dedans }
       Width := W;
       Height := H;
       CopyMemory(ScanLine[Height - 1], D, Q);
      end else Exit; { Sinon, on s'en va }
    end;

   { Tout s'est bien pass�, on renvoie True }
   Result := True;
  except
   { Un probl�me est survenu }
   Result := False;
  end;
 finally
  { On n'oublie pas de d�sallouer la m�moire des donn�es temporaires }
  FreeMem(D, Q);
 end;
end;

end.
