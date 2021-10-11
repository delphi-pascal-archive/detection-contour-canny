unit UCanny;

interface

uses Windows, Graphics, Math,StrUtils, SysUtils;

procedure Canny(const bm_in: TBitmap;const bm_out: TBitmap;
                GaussSize:integer;GaussTheta:single;
                lowerThreshold,upperThreshold:integer;
                ColorMap,Level:integer);

implementation

type
 TLongArray = array[0..65535] of integer;
 PLongArray = ^TLongArray;
 TIntArray = array[0..65535] of integer;


var
 Pbm_In, Pbm_Out: PLongArray;
 tmp_In:array of integer;
 Edge_In:array of integer;
 edgeDir:array of integer;
 gradient:array of integer;
 Hyst:array of integer;

 picth:integer;
 Width,Height:integer;
 ColorMapMode:integer;




// fonctions diverses...
//==============================================================================

function RGBA(r, g, b, a: Byte): COLORREF;
begin
  Result := (r or (g shl 8) or (b shl 16) or (a shl 24));
end;

function ArcEnCiel(a:integer):integer;
begin
  while a<0 do a:=a+360;
  Case (a div 60) mod 6 of
      0: result:=RGB(255 ,17*(a Mod 60) shr 2,  0);
      1: result:=RGB(255-17*(a Mod 60) shr 2 ,255 ,  0);
      2: result:=RGB(  0 ,255 ,17*(a Mod 60) shr 2);
      3: result:=RGB(  0 ,255-17*(a Mod 60) shr 2 ,255);
      4: result:=RGB(17*(a Mod 60) shr 2,  0 ,255);
      5: result:=RGB(255 ,  0 ,255-17*(a Mod 60) shr 2);
   end;
end;


function RGBtoGray(c:longint):longint;
var
 r,g,b:cardinal;
begin
  r := (c and $FF0000)   shr 16;
  g := (c and $00FF00) shr  8;
  b := (c and $0000FF) ;

  c:=(r*30+g*59+b*11) div 100;
  result :=$010101*byte(c);
end;

//==============================================================================

function getPixel(pt:pointer;xx,yy:integer):longint;
begin
 result:=0;
 if xx<0 then xx:=0;
 if yy<0 then yy:=0;
 if xx>Width-1 then xx:=Width-1;
 if yy>Height-1 then yy:=Height-1;
 result:= PLongArray(pt)[xx+yy*Width];
end;

procedure SetPixel(pt:pointer;xx,yy,px:integer);
begin
 PLongArray(pt)[xx+yy*Width]:=px;
end;

function getBytePixel(pt:pointer;xx,yy:integer):longint;
begin
 result:=0;
 if xx<0 then xx:=0;
 if yy<0 then yy:=0;
 if xx>Width*4-1 then xx:=Width*4-4+xx mod 4;
 if yy>Height-1 then yy:=Height-1;
 result:= PByteArray(pt)[xx+yy*Width*4];
end;

procedure SetBytePixel(pt:pointer;xx,yy,px:integer);
begin
 if xx<0 then exit;
 if yy<0 then exit;
 if xx>=Width*4 then exit;
 if yy>=Height then exit;
 PByteArray(pt)[xx+yy*Width*4]:=px;
 if ColorMapMode<>1 then
  begin
   PByteArray(pt)[xx+1+yy*Width*4]:=px;
   PByteArray(pt)[xx+2+yy*Width*4]:=px;
   PByteArray(pt)[xx+3+yy*Width*4]:=px;
  end;
end;

procedure copyimage(pt_In,pt_Out:pointer);
var
 i,j:integer;
begin
 for j:=0 to Height-1 do for i:=0 to Width-1 do
      SetPixel(pt_Out,i,j,GetPixel(pt_In,i,j));
end;

//==============================================================================

procedure ColorGradient;
var
 i,j:integer;
begin
 for j:=0 to Height-1 do for i:=0 to Width-1 do
			SetPixel(Pbm_Out,i,j,arcenciel(GetBytePixel(PLongArray(gradient),i*4,j)));
end;

procedure ColorDirection;
var
 i,j:integer;
const
 EdgeColor:array[0..3] of tcolor=($000001,$010000,$010100,$000100);
begin
 for j:=0 to Height-1 do for i:=0 to Width-1 do
			SetPixel(Pbm_Out,i,j,EdgeColor[GetBytePixel(PLongArray(edgeDir),i*4,j)]
                           *GetBytePixel(PLongArray(gradient),i*4,j));
end;

// passe l'image en niveau de gris
//==============================================================================
procedure MakeGrayScale;
var
 i,j:integer;
 c:integer;
begin
 for j:=0 to Height-1 do for i:=0 to Width-1 do
 case ColorMapMode of
 0: SetPixel(PLongArray(Tmp_In),i,j,RGBtoGray(GetPixel(Pbm_In,i,j)));
 1: SetPixel(PLongArray(Tmp_In),i,j,getPixel(Pbm_In,i,j));
 2: SetBytePixel(PLongArray(Tmp_In),i*4,j,getbytePixel(Pbm_In,i*4+2,j));
 3: SetBytePixel(PLongArray(Tmp_In),i*4,j,getbytePixel(Pbm_In,i*4+1,j));
 4: SetBytePixel(PLongArray(Tmp_In),i*4,j,getbytePixel(Pbm_In,i*4+0,j));
 end;
end;


// applique un flou gaussien
//==============================================================================

procedure GaussianBlur(size:integer;theta:single);
var
 i,j,x,y:integer;
 col:single;
 c:dword;
 theta2:single;
 GaussSum:single;
 GaussMatrice:array of array of single;
begin
 // si la taille est 1, il n'y a pas de flou...
 if size=1 then
  begin
   for j:=0 to Height-1 do for i:=0 to Width-1 do
     SetPixel(Pbm_Out,i,j,getPixel(Pbm_In,i,j));
   exit;
  end;

 // calcul la matrice pour le filtre
 theta2:=2*theta*theta;
 size:=size-1;
 setlength(GaussMatrice,size*2+1);
 GaussSum:=0;
 for j:=-size to size do
  begin
    setlength(GaussMatrice[size+j],size*2+1);
    for i:=0 to size-1 do
     begin
      GaussMatrice[size+j,size+i]:=exp(-(j*j+i*i)/theta2)/(pi*theta2);
      GaussSum:=GaussSum+GaussMatrice[size+j,size+i];
      if i=0 then continue;
      GaussMatrice[size+j,size-i]:=GaussMatrice[size+j,size+i];
      GaussSum:=GaussSum+GaussMatrice[size+j,size+i];
     end;
  end;

 // on applique la matrice
 for j:=0 to Height-1 do
  for i:=0 to Width*4-1 do
   if (ColorMapMode<>1) and (i mod 4<>0) then continue
   else
   begin
    col:=0;
    for y:=-size to size do for x:=-size to size do
     begin
      c:=getBytePixel(PLongArray(Tmp_In),i+x*4,j+y);
      col:=col+GaussMatrice[size+x,size+y]*c;
     end;
    SetBytePixel(Pbm_Out,i,j,round(col/GaussSum));
   end;
end;

// applique le filtre de Sobel qui recherche les contours suivant X et Y
//==============================================================================

const
 Matrice_Sobel_x:array[-1..1,-1..1] of integer=((-1,0,1),  (-2,0,2),  (-1,0,1));
 Matrice_Sobel_y:array[-1..1,-1..1] of integer=((1,2,1),  (0,0,0),  (-1,-2,-1));

procedure Sobel;
var
 i,j,x,y:integer;
 colx,coly:integer;
 c:dword;
 angle:integer;
begin
  // on efface le tableau
 for j:=0 to Height-1 do for i:=0 to Width-1 do SetPixel(PLongArray(gradient),i,j,0);
 for j:=0 to Height-1 do for i:=0 to Width-1 do SetPixel(PLongArray(edgeDir),i,j,0);

 for j:=1 to Height-2 do
  for i:=4 to Width*4-5 do
   if (ColorMapMode<>1) and (i mod 4<>0) then continue
   else
   begin
    colx:=0;
    coly:=0;
    for y:=-1 to 1 do for x:=-1 to 1 do
     begin
      c:=getBytePixel(Pbm_Out,i+x*4,j+y);
      colx:=colx+Matrice_Sobel_x[x,y]*c;
      coly:=coly+Matrice_Sobel_y[x,y]*c;
     end;
    SetBytePixel(PLongArray(gradient),i,j,round(sqrt(colx*colx+coly*coly)));
    angle:=round((ArcTan2(colx,coly)*180/pi+202.5)/45) mod 4;
    SetBytePixel(PLongArray(edgeDir),i,j,angle);
   end;
end;

// trace un trait sur chaque contour
//==============================================================================
procedure findEdge(x_Shift,y_Shift, x, y:integer);
var
  g1,g2,g:integer;
begin
 g:=GetBytePixel(PLongArray(gradient),x,y);
 g1:=GetBytePixel(PLongArray(gradient),x+x_Shift,y+y_Shift);
 g2:=GetBytePixel(PLongArray(gradient),x-x_Shift,y-y_Shift);
 if (g>g1) and (g>g2) then SetBytePixel(Pbm_Out,x,y,g)
                      else SetBytePixel(Pbm_Out,x,y,0);
end;

procedure TraceAllEdges;
var
 i,j,x,y:integer;
 rx,vx,bx,ax:integer;
 ry,vy,by,ay:integer;
 c:dword;
begin
 for j:=1 to Height-2 do
  for i:=4 to Width*4-5 do
   if (ColorMapMode<>1) and (i mod 4<>0) then continue
   else
   begin
     case GetBytePixel(PLongArray(edgeDir),i,j) of
       0:findEdge( 4, 0, i, j);
       1:findEdge(-4, 1, i, j);
       2:findEdge( 0, 1, i, j);
       3:findEdge( 4, 1, i, j);
     end;
   end;
end;

// cherche les points maxi sur les contours et efface les autres
//==============================================================================

procedure suppressNonMax( i, j, lowerThreshold:integer);
begin
 // pas assez blanc
 if GetBytePixel(Pbm_Out,i,j)<=lowerThreshold then exit;
 // déjà vu
 if GetBytePixel(PLongArray(Hyst),i,j)=255 then exit;

 SetBytePixel(PLongArray(Hyst),i,j,255);
 SetBytePixel(Pbm_Out,i,j,255);
 suppressNonMax(i-4,j-1,lowerThreshold);
 suppressNonMax(i  ,j-1,lowerThreshold);
 suppressNonMax(i+4,j-1,lowerThreshold);
 suppressNonMax(i-4,j  ,lowerThreshold);
 suppressNonMax(i+4,j  ,lowerThreshold);
 suppressNonMax(i-4,j+1,lowerThreshold);
 suppressNonMax(i  ,j+1,lowerThreshold);
 suppressNonMax(i+4,j+1,lowerThreshold);
end;

procedure Hysteresis(lowerThreshold,upperThreshold:integer);
var
 i,j:integer;
begin
 // on efface le tableau
 for j:=0 to Height-1 do for i:=0 to Width-1 do SetPixel(PLongArray(Hyst),i,j,0);

 // on crée un cadre noir autour
 for j:=0 to Height-1 do SetPixel(Pbm_Out,0,j,0);
 for j:=0 to Height-1 do SetPixel(Pbm_Out,Width-1,j,0);
 for i:=0 to Width-1 do SetPixel(Pbm_Out,i,0,0);
 for i:=0 to Width-1 do SetPixel(Pbm_Out,i,Height-1,0);

 for j:=0 to Height-1 do for i:=0 to Width*4-1 do
  if (ColorMapMode<>1) and (i mod 4<>0) then continue
   else
		 begin
      // point dejà traité, on passe au suivant
      if GetBytePixel(PLongArray(Hyst),i,j)=255 then continue;
      // pas assez blanc pour le traitement
			if GetBytePixel(Pbm_Out,i,j)<upperThreshold then continue;
	   	suppressNonMax( i, j, lowerThreshold);
		 end;
end;

procedure ClearNonWhitePixel;
var
 i,j:integer;
 c:integer;
begin
  for j:=0 to Height-1 do for i:=0 to Width*4-1 do
  if (ColorMapMode<>1) and (i mod 4<>0) then continue
   else
		 begin
      c:=GetBytePixel(Pbm_Out,i,j);
			if c<255 then SetBytePixel(Pbm_Out,i,j,0);
		 end;
end;

//==============================================================================
//==============================================================================

procedure Canny(const bm_in: TBitmap;const bm_out: TBitmap;
                GaussSize:integer;GaussTheta:single;
                lowerThreshold,upperThreshold:integer;
                ColorMap,Level:integer);
begin
 // initialisation des variables
 Width :=bm_In.Width;
 Height:=bm_In.Height;

 bm_Out.Width:=bm_In.Width;
 bm_Out.Height:=bm_In.Height;

 bm_In.PixelFormat := pf32bit;
 bm_Out.PixelFormat := pf32bit;

 picth:=bm_In.Width*4;

 Pbm_In := PLongArray(bm_In.ScanLine[bm_In.Height-1]);
 Pbm_Out := PLongArray(bm_Out.ScanLine[bm_Out.Height-1]);

 setlength(Tmp_In,Width*Height*4);
 setlength(edgeDir,Width*Height*4);
 setlength(gradient,Width*Height*4);
 setlength(Hyst,Width*Height*4);

 ColorMapMode:=ColorMap;

 //traitement de l'image
 MakeGrayScale;
    if level=0 then begin copyimage(PLongArray(Tmp_In),Pbm_Out); exit; end;
 GaussianBlur(GaussSize,GaussTheta);
    if level=1 then exit;
 Sobel;
    if level=2 then begin ColorGradient; exit; end;
    if level=3 then begin ColorDirection; exit; end;

 TraceAllEdges;
    if level=4 then exit;

 Hysteresis(lowerThreshold,upperThreshold);
    if level=5 then exit;
 ClearNonWhitePixel;
end;

{
  Level=
    0:GrayScale
    1:Gaussian Blur
    2:Sobel Gradient
    3:Sobel Direction
    4:Find Edge
    5:Hysteresis
    6:Complete
}

end.


