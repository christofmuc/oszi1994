procedure pascal_FFT;
var MR,M,NN,L,ISTEP,EL,I,J:integer;
    TR, TI,A,WR,WI   :double;
    num:integer;
begin
  MR:=0;
  NN:=N-1;
  for M:=1 to NN do begin
    L:=N;
    while (MR+L > NN) do L:=L div 2;

    MR:=MR mod L + L;
    if (MR > M) then begin
      TR      :=FR[M+1];
      FR[M+1] :=FR[MR+1];
      FR[MR+1]:=TR;
(*      TI      :=FI[M+1];
      FI[M+1] :=FI[MR+1];
      FI[MR+1]:=TI;*)
    end;
  end;

  num:=0;
  L:=1;
  while (L<N) do begin
    ISTEP:=2*L;
    EL   :=L;
    for M:=1 to L do begin
{      A :=pi*(1-M)/EL;
      WR:=cos(A);
      WI:=sin(A);}
      wr:=wrtab[num];
      wi:=witab[num];
      inc(num);
      I :=M;
      repeat
        J:=I+L;
        TR:=WR*FR[J]-WI*FI[J];
        TI:=WR*FI[J]+WI*FR[J];
        FR[J]:=FR[I]-TR;
        FI[J]:=FI[I]-TI;
        FR[I]:=FR[I]+TR;
        FI[I]:=FI[I]+TI;
        I:=I+ISTEP;
      until I>=N;
    end;
    L:=ISTEP;
  end

end;

