{ Downsampling.pas
  Auteur : Bacterius

  Cette unité permet de "downsampler" une image, c'est-à-dire réduire sa taille sans perdre de
  qualité (ce qu'on observe souvent en faisant par exemple un simple Stretch dans Delphi). De plus
  cette fonction est très optimisée, et bien qu'il soit probablement possible d'aller plus vite en
  utilisant les ROP intégrées à votre carte graphique, ce qui suit est un exemple d'optimisation
  qui permet de gagner beaucoup de performance à un prix de maintenance du code négligeable.

  Limitations : le code n'est pas adapté pour des images de taille quelconque - il est nécessaire
                que l'image ait une largeur et une hauteur paires pour qu'elle puisse être réduite.
                Il est évidemment possible de modifier le code pour qu'il prenne en charge ces cas,
                mais ce n'était pas le but de la source, qui est d'expliquer comment optimiser. 

  AVERTISSEMENT : le code qui suit n'est pas simple à comprendre pour un néophyte - je recommande
                  au préalable la lecture de mes deux tutoriaux sur Scanline et sur les pointeurs,
                  tous deux situés sur le site DelphiFR (www.delphifr.com) sous mon pseudo.

  Quelques comparaisons pour une image de taille 2048 x 2048 (px), temps observés (en moyenne) :

                          Stretch de Delphi          (moche) : 91  millisecondes
                          StretchBlt Windows simple  (moche) : 47  millisecondes
                          StretchBlt Windows HALFTONE (beau) : 102 millisecondes
                          Downsample                  (beau) : 28  millisecondes
                          GPU ROP                     (beau) : 0.6 millisecondes

                          (GPU ROP utilise un raster operation de la carte graphique spécialisé
                           dans le downsampling (c'est utilisé pour effectuer un anti-aliasing),
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
 { Ici on déclare quelques types utiles pour le parcours du pointeur de bitmap }
 TRGBQUAD = record
  B, G, R, A: Byte;
 end; PRGBQUAD = ^TRGBQUAD;

 { Ce type représente deux pixels sur 32 bits se touchant horizontalement }
 TRGBDUALQUAD = record
  B1, G1, R1, A1, B2, G2, R2, A2: Byte;
 end; PRGBDUALQUAD = ^TRGBDUALQUAD;
Var
 S1, S2: PRGBDUALQUAD;
 D: PRGBQUAD;
 X, Y, W, H: Longword;
begin
 try
  { Ici l'on calcule les nouvelles dimensions du bitmap réduit, donc largeur/hauteur divisés par 2 }
  W := Width shr 1;
  H := Height shr 1;
  { Les deux pointeurs S1 et S2 permettent d'accéder à un carré de 2x2 pixels sur le bitmap. }
  S2 := Ptr(Longword(Src) + Width * 4);
  S1 := Src; D := Dst;

  { Pour chaque pixel du bitmap réduit }
  for Y := 0 to H - 1 do
   begin
    for X := 0 to W - 1 do
     begin
      { On prend le carré de 2x2 pixels de l'image originale et l'on calcule le pixel final en
        prenant la moyenne euclidienne des quatre pixels du carré. Le compilateur se débrouille
        plutôt pas mal avec ces quatre lignes suivantes. }
      D^.R := (S1^.R1 + S1^.R2 + S2^.R1 + S2^.R2) shr 2;
      D^.G := (S1^.G1 + S1^.G2 + S2^.G1 + S2^.G2) shr 2;
      D^.B := (S1^.B1 + S1^.B2 + S2^.B1 + S2^.B2) shr 2;
      D^.A := (S1^.A1 + S1^.A2 + S2^.A1 + S2^.A2) shr 2;

      { Ensuite, on passe au carré suivant. Si on arrive au bout de la ligne du bitmap, on passe
        au début de la ligne suivante (on comprend pourquoi les largeurs paires ne marchent pas) }
      Inc(S1);
      Inc(S2);
      Inc(D);
     end;
    { Quand on arrive au bout de la ligne, on doit aussi faire "descendre" les deux pointeurs d'une
      autre ligne, car comme ils représentent un carré 2x2, les faire descendre d'une seule ligne
      fait que les deux carrés se chevauchent, ce qui n'est pas correct. On saute donc une ligne. }
    Inc(S1, W);
    Inc(S2, W);
   end;

  { Si tout s'est bien passé (pas d'erreur de pointeur, etc...) on renvoie True }
  Result := True;
 except
  { Sinon, on a rencontré une erreur }
  Result := False;
 end;
end;

{ Cette fonction réduit Bmp d'un facteur Factor. Factor est en fait exponential, c'est-à-dire que
  Factor = 0 ne changera pas l'image, Factor = 1 réduira sa taille par 4 (chacune des dimensions
  est réduite par deux), Factor = 2 réduira sa taille par 16, Factor = 3 par 64, etc... }
function Downsample(const Bmp: TBitmap; const Factor: Longword = 1): Boolean;
Var
 N, Q, W, H: Longword;
 D: Pointer;
begin
 { On initialise tout }
 Result := False;
 D := nil; Q := 0;
 { Si le bitmap existe, et Factor est plus grand que zéro, on peut y aller }
 if Assigned(Bmp) and (Factor <> 0) then try
  try
   { On calcule et on alloue la mémoire nécessaire pour stocker les données temporaires }
   { On note qu'il n'est nécessaire d'allouer la mémoire qu'une fois même si Factor est
     plus grand que 1, puisque la taille du bitmap réduit est strictement décroissante. }
   Result := False;
   Q := Bmp.Width * Bmp.Height;
   GetMem(D, Q);
   { En fait, on appelle Downsample Factor fois, d'où la nature exponentielle de ce paramètre }
   for N := 1 to Factor do
    with Bmp do begin
     { On rejette les images de taille incorrecte }
     if (Width and 1 = 1) or (Height and 1 = 1) then Exit;
     W := Width shr 1;
     H := Height shr 1;
     Q := Width * Height;
     { On réduit l'image }
     if PTR_Downsample(ScanLine[Height - 1], D, Width, Height) then
      begin
       { Si la réduction a réussi, on met à jour l'image en copiant les données réduites dedans }
       Width := W;
       Height := H;
       CopyMemory(ScanLine[Height - 1], D, Q);
      end else Exit; { Sinon, on s'en va }
    end;

   { Tout s'est bien passé, on renvoie True }
   Result := True;
  except
   { Un problème est survenu }
   Result := False;
  end;
 finally
  { On n'oublie pas de désallouer la mémoire des données temporaires }
  FreeMem(D, Q);
 end;
end;

end.
