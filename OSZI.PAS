program Pegel;

(*                                                              *)
(*                                                              *)
(* Oszilloskop und FFT, von Felix und Christof                  *)
(*                                                              *)
(* mit '+' und '-' kann man die "Helligkeit" der FFT Anzeige    *)
(* ver�ndern                                                    *)
(*                                                              *)
(*                                                              *)

(* Schalter f�r 640x480 (f�r Fiege), sonst immer 800x600 *)
{ $define sixhundret}

(* Schalter f�r kleine Punkte im Oszilloskop anstelle von Rects *)
(* seit FFT sowieso egal...                                     *)
{ $define maxspeed }

uses dos, crt, fastgraf, protimer;

type
  TRat = double;
  TTime =
    record
      h, m, s, hu: word;
    end;

const
  ati_base     = $220;
  ati_reset    = ati_base + $6;
  ati_Data_in  = ati_base + $A;
  ati_Command  = ati_base + $C;
  ati_Data_out = ati_base + $C;
  ati_Status   = ati_base + $E;
  DSP_OK       = $AA;

{$ifdef sixhundret}
  minx = 10;
  maxx = 629;
  anzx = (maxx - minx) + 1;
  maxy = 479;
  yoffs = 10;

  blob_x = 2;
  blob_y = 2;
{$else}
  minx = 10;
  maxx = 789;
  anzx = (maxx - minx) + 1;
  maxy = 599;
  yoffs = 50;

  blob_x = 2;
  blob_y = 3;
{$endif}

  vg = 128;

const
  max_n    = 512;
  N : word = 512;
  startx   = 256;

var
  i: integer;
  c: char;
  verlassen: boolean;
  sges: TRat;
  old: array [0 .. 800] of byte;
  samples,fftnum: longint;
  t1, t2, td: TTime;

var fr,fi,sampled  :array[1..max_n] of double;
    amp            :array[1..max_n div 2] of word;
    wrtab, witab   :array[0..max_n] of double;
    NN             :word;
    scale          :double;

function reset_dsp: byte;
const
  maxcount = 1000;
var
  count: word;
begin
  port [ati_reset] := 1;
  delay (1);
  port [ati_reset] := 0;
  count := 0;
  repeat
    inc (count)
  until (count >= maxcount) or (((port [ati_Status]) and $80) <> 0);
  reset_dsp := port [ati_data_in];
end;

procedure subtime (ta, tb: TTime; var tdiff: TTime);
begin
  with tdiff do
    begin
      hu := ta.hu - tb.hu;
      if hu > 99 then
        begin
          tb.s := tb.s + 1;
          hu := hu + 100;
        end
      ;
      s := ta.s - tb.s;
      if s > 59 then
        begin
          tb.m := tb.m + 1;
          s := s + 60;
        end
      ;
      m := ta.m - tb.m;
      if m > 59 then
        begin
          tb.h := tb.h + 1;
          m := m + 60;
        end
      ;
      if ta.h >= tb.h then
        h := ta.h - tb.h
      else
        h := (ta.h + 24) - tb.h
      ;
    end
  ;
end;

procedure WriteTime (t: TTime);
begin
  with t do
    begin
      write (h: 2, ':', m: 2, ':', s: 2, ',', hu: 2);
    end
  ;
end;


procedure initbigtab;
var M,L:integer;
    WR,WI,A:double;
    num:integer;
begin
  num:=0;
  l:=1;
  while (L<N) do begin
    for M:=1 to L do begin
      A :=pi*(1-M)/L;
      WRtab[num]:=cos(A);
      WItab[num]:=sin(A);
      inc(num);
    end;
    l:=2*l;
  end;
  NN:=N-1;
end;

{$L fft.obj}

procedure fft; external;
procedure amplitude; external;

procedure Scope;
var
  color: byte;
  h, x: word;
  ende: boolean;
  old: array [0 .. 800] of word;
  ic,xc,i :  integer;
  time  : longint;
begin
{$ifdef sixhundret}
  initgraph(g640x480);
{$else}
  initgraph(g800x600);
{$endif}

  SetRGBPalette (0,0,0,0);
  SetRGBPalette (255,63,63,0);
  for i := 1 to 31 do
    begin
      SetRGBPalette (    i, 63, 63 - i * 2, 0);
{      SetRGBPalette (255-i, 63, 63 - i * 2, 0);}
    end
  ;
  for i := 0 to 95 do
    begin
      SetRGBPalette ( 32 + i, 63 - (i div 3), 0, (i div 3));
{      SetRGBPalette (223 - i, 63 - (i div 3), 0, (i div 3));}
    end
  ;
  for i := 0 to 127 do
    SetRGBPalette(i+128, i div 2, i div 2, i div 2);

  for i := 0 to 127 do
    begin
{$ifdef sixhundret}
      rect (minx - 10, maxy - i div 2, 5, blob_y, i);
      rect (maxx +  5, maxy - i div 2, 5, blob_y, i);
      rect (minx - 10, maxy - 128 + i div 2, 5, blob_y, i);
      rect (maxx +  5, maxy - 128 + i div 2, 5, blob_y, i);
{$else}
      rect (minx - 10, maxy - i, 5, blob_y, i);
      rect (maxx +  5, maxy - i, 5, blob_y, i);
      rect (minx - 10, maxy - 256 + i, 5, blob_y, i);
      rect (maxx +  5, maxy - 256 + i, 5, blob_y, i);
{$endif}
    end
  ;


  samples := 0;
  fftnum  := 0;
  for x := 0 to maxx do old [x] := maxy - 128;
  ende := false;
  with t1 do GetTime (h, m, s, hu);
  ic   := startx;
  xc   := minx;
  scale:= 1/8;


  for i:=1 to N do begin
    fr[i]:=0;
    fi[i]:=0;
  end;

  repeat
    for x := minx to maxx do
      begin
        Port[ati_command] := $20;

        {$ifdef sixhundret}
          h:=maxy - (color shr 1);
        {$else}
          h:=maxy - color;
        {$endif}

        {$ifdef maxspeed }
          PutPixel (x, old [x], 0);
          PutPIxel (x, h, 128-abs(color-128));
        {$else }
          rect (x, old [x], blob_x, blob_y, 0);
          rect (x, h, blob_x, blob_y, 128-abs(color-128));
        {$endif }
        old [x] := h;


        (* neuen Samplewert einlesen *)
        repeat until (port [ati_Status] and 128) <> 0;
        color := port [ati_data_in];

        sampled[ic]  := color-128;
        inc(ic);

        (* Buffer voll? -> Dann FFT *)
        if (ic>N) then begin
          (* init *)
          fr:=sampled;
          fillchar(fi,sizeof(fi),#0);
          (* call fft *)
          fft;
          inc(fftnum);
          ic:=startx;

          (* move samples in buffer *)
          if startx>1 then
            for i:=startx to N do
              sampled[i-startx+1]:=sampled[i];


          (* Berechnen des Betrags des komplexen Ergebnisses *)
          amplitude;

          (* plot result *)
          for i:=1 to N div 2 do begin
            if amp[i]>126 then amp[i]:=127;
            PutPixel (xc, yoffs+N div 2-i, 128+amp[i]);
          end;

          (* next column *)
          inc(xc);
          if xc>maxx then xc:=minx;
        end;
      end
    ;
    inc (samples, anzx);

    (* Tastaturabfrage *)
    if keypressed then begin
      case readkey of
        '+': scale:=scale*2;
        '-': scale:=scale/2;
        ' ': begin xc:=minx; rect(minx,yoffs,maxx-minx+1,yoffs+N div 2,0); end;
        #27: ende:=true;
      end;
    end;
  until ende;
  with t2 do GetTime (h, m, s, hu);
  closegraph;
end;

begin
  (* Initialisieren der Sinus/Cosinus-Tabelle *)
  initbigtab;

  (* DSP Reset *)
  if reset_dsp <> dsp_OK then begin
    textmode(c80);
    writeln ('DSP-Reset fehlgeschlagen!');
    c := readkey;
    halt;
  end;

  (* Aufruf der Hauptroutine *)
  Scope;

  (* Statistik ausgeben *)
  subtime (t2, t1, td);
  Write   ('Startzeit   : '); WriteTime (t1); WriteLn;
  Write   ('Stopzeit    : '); WriteTime (t2); WriteLn;
  Write   ('Dauer       : '); WriteTime (td); WriteLn;
  Writeln ('Samples     : ', samples:11);
  sges := td.h * 3600 + td.m * 60 + td.s + 0.01 * td.hu;
  WriteLn ('Samplingrate: ', (samples / sges) :8:0, ' Hz');
  WriteLn ('Refreshrate : ',(samples / anzx) / sges :8:1, ' Hz');
  WriteLn ('FFTs        : ',fftnum:11);
  WriteLn ('FFTs pro s  : ',fftnum / sges :11:1);
end.


benchmark:
          pt_starttimer;
          save:=fr;
          for i:=1 to 100 do begin
            fr:=save;
            fillchar(fi,sizeof(fi),#0);
            pascal_fft;
          end;
          time:=pt_readtimer;

Ergebnisse:
-----------

47 / s bei N = 512 in Assembler 486/33Mhz
10 / s      "      in Pascal      "


