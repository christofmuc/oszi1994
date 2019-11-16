program Pegel;

uses dos, crt, fastgraf;

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

  minx = 10;
  maxx = 789;
  anzx = (maxx - minx) + 1;
  maxy = 599;

  vg = 128;

var
  i: integer;
  c: char;
  verlassen: boolean;
  sges: TRat;
  old: array [0 .. 800] of byte;
  samples: longint;
  t1, t2, td: TTime;

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

procedure Scope;
{ $define maxspeed }
const
  blob_x = 2;
  blob_y = 3;
var
  color: byte;
  h, x: word;
  ende: boolean;
  old: array [0 .. 800] of word;
begin
  initgraph(g800x600);
  SetRGBPalette (0,0,0,0);
  SetRGBPalette (255,63,63,0);
  for i := 1 to 31 do
    begin
      SetRGBPalette (    i, 63, 63 - i * 2, 0);
      SetRGBPalette (255-i, 63, 63 - i * 2, 0);
    end
  ;
  for i := 0 to 95 do
    begin
      SetRGBPalette ( 32 + i, 63 - (i div 3), 0, (i div 3));
      SetRGBPalette (223 - i, 63 - (i div 3), 0, (i div 3));
    end
  ;
  for i := 0 to 255 do
    begin
      rect (minx - 10, maxy - i, 5, blob_y, i);
      rect (maxx +  5, maxy - i, 5, blob_y, i);
    end
  ;
  samples := 0;
  for x := 0 to maxx do old [x] := maxy - 128;
  ende := false;
  with t1 do GetTime (h, m, s, hu);
  repeat
    for x := minx to maxx do
      begin
        Port[ati_command] := $20;
        h := maxy - color;
        {$ifdef maxspeed }
          PutPixel (x, old [x], 0);
          PutPIxel (x, h, color);
        {$else }
          rect (x, old [x], blob_x, blob_y, 0);
          rect (x, h, blob_x, blob_y, color);
        {$endif }
        old [x] := h;

        repeat until (port [ati_Status] and 128) <> 0;
        color := port [ati_data_in];
      end
    ;
    inc (samples, anzx);
    ende := keypressed;
  until ende;
  with t2 do GetTime (h, m, s, hu);
  c := readkey;
  closegraph;
end;

var
  input: byte;
  x, ds: word;
  ende, plus: boolean;
  dsquer: TRat;

procedure Freq;
begin
  samples := 0; plus := true;
  ende := false;
  with t1 do GetTime (h, m, s, hu);
  repeat
    ds := 0;
    repeat
      Port[ati_command] := $20;
      inc (ds);
      repeat until (port [ati_Status] and 128) <> 0;
      input := port [ati_data_in];
    until (input > 127) <> plus;
    repeat
      Port[ati_command] := $20;
      inc (ds);
      repeat until (port [ati_Status] and 128) <> 0;
      input := port [ati_data_in];
    until (input > 127) <> plus;
    plus := not plus;
    dsquer := (dsquer * 99 + ds) * 0.01;
    ende := keypressed;
    gotoxy (20,20); write (dsquer:6:3);
    inc (samples, ds);
  until ende;
  with t2 do GetTime (h, m, s, hu);
  c := readkey;
  textmode(c80);
end;

begin
  clrscr;

  if reset_dsp <> dsp_OK then
    begin
      textmode(c80);
      writeln ('DSP - Reset fehlgeschlagen!');
      c := readkey;
      halt;
    end
  ;

  verlassen := false;
  repeat
    gotoxy (1,1);
    WriteLn ('*** Oszi ***');
    WriteLn;
    WriteLn ('<O>: Oszilloskop');
    WriteLn;
    WriteLn ('<F>: Frequenzmessung');
    WriteLn;
    WriteLn ('<E>: Ende');
    WriteLn;
    Write ('->');
    c := readkey;
    case upcase (c) of
      'O':
        begin
          Scope;

          subtime (t2, t1, td);
          gotoxy (1, 10);
          Write   ('Startzeit   : '); WriteTime (t1); WriteLn;
          Write   ('Stopzeit    : '); WriteTime (t2); WriteLn;
          Write   ('Dauer       : '); WriteTime (td); WriteLn;
          Writeln ('Samples     : ', samples:11);
          sges := td.h * 3600 + td.m * 60 + td.s + 0.01 * td.hu;
          WriteLn ('Samplingrate: ', (samples / sges) :6:0, '   Hz');
          WriteLn ('Refreshrate : ',(samples / anzx) / sges :8:1, ' Hz');
        end;
      'F':
        begin
          Freq;

          subtime (t2, t1, td);
          gotoxy (1, 10);
          Write   ('Startzeit   : '); WriteTime (t1); WriteLn;
          Write   ('Stopzeit    : '); WriteTime (t2); WriteLn;
          Write   ('Dauer       : '); WriteTime (td); WriteLn;
          Writeln ('Samples     : ', samples:11);
          sges := td.h * 3600 + td.m * 60 + td.s + 0.01 * td.hu;
          WriteLn ('Samplingrate: ', (samples / sges) :6:0, '   Hz');
        end;
      'E', #27:
        verlassen := true;
      else
    end;
  until verlassen;
end.
