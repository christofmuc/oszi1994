        .model TPascal
        .386
        .387

        .data

        EXTRN  N:word
        EXTRN NN:word
        EXTRN FR
        EXTRN FI
        EXTRN WRTAB
        EXTRN WITAB
        EXTRN AMP
        EXTRN scale:qword

        .code

        public fft
fft     proc

        local num:word, L:word

        finit

        mov   cx, 1                             ; cx ist SchleifenzÑhler M
        xor   ax, ax                            ; ax ist MR
        mov   num, ax

bitumkehr:
        mov   bx, N                             ; bx ist L

shiftloop:
        mov   dx, ax                            ; while (MR+L>NN) do L>>=2
        add   dx, bx
        cmp   dx, NN
        jle smallenough
        shr   bx, 1
        jmp shiftloop

smallenough:
        xor   dx, dx
        div   bx
        add   dx, bx
        mov   ax, dx                            ; ax = MR mod L + L
        cmp   ax, cx
        jle loopend                             ; if (MR>M) -> loopend

        mov   si, cx
        shl   si, 3                             ; si ist Index fÅr M (+1)
        mov   di, ax
        shl   di, 3                             ; di ist Index fÅr MR (+1)

        fld   qword ptr [fr+si]                 ; Vertauschen der Werte
        fld   qword ptr [fr+di]
        fstp  qword ptr [fr+si]
        fstp  qword ptr [fr+di]

loopend:
        inc   cx
        cmp   cx, NN
        jle bitumkehr

        mov   ax, 1
        mov   L, ax                             ; L := 1

outerloop:
        mov   ax, L
        cmp   ax, N
        jge ende                                ; while (L<N)

        shl   ax, 1                             ; ax = ISTEP := 2*L
        mov   cx, 1                             ; cx = M := 1

for:
        mov   bx, cx                            ; bx = I := M
repeat:
        mov   si, num
        shl   si, 3
        fld   qword ptr [witab+si]
        fld   qword ptr [wrtab+si]

        mov   dx, bx
        add   dx, L                             ; dx = J := I + L
        mov   si, bx
        dec   si
        shl   si, 3                             ; si Index fÅr I
        mov   di, dx
        dec   di
        shl   di, 3                             ; di Index fÅr J

        ;tr:=wr*fr[j]-wi*fi[j]
        ;ti:=wr*fi[j]+wi*fr[j]

        fld   qword ptr [fi+di]                 ; Laden von fr[j] und fi[j]
        fld   qword ptr [fr+di]

        fld   st
        fmul  st,st(3)
        fld   st(4)
        fmul  st,st(3)
        fsubp st(1),st                          ; tr berechnet

        fxch  st(4)                             ; tr nach unten

        fmulp
        fxch
        fmulp st(2),st
        faddp

        ;fr[j]:=fr[i]-tr
        ;fi[j]:=fi[i]-ti
        ;fr[i]:=fr[i]+tr
        ;fi[i]:=fi[i]+ti

        fld   qword ptr [fr+si]                 ; Laden von fr[i] und fi[i]
        fld   qword ptr [fi+si]

        fld   st                                ; Verdoppeln von fi[i]
        fsub  st, st(3)
        fstp  qword ptr [fi+di]
        faddp st(2), st
        fxch
        fstp  qword ptr [fi+si]

        fld   st                                ; Verdoppeln von fr[i]
        fsub  st,st(2)
        fstp  qword ptr [fr+di]
        faddp
        fstp  qword ptr [fr+si]

        add   bx, ax                            ; I:=I+ISTEP
        cmp   bx, N                             ; if (I<N) -> repeat
        jl repeat

        inc   num
        inc   cx
        cmp   cx, L
        jle for                                 ; if (++M<=L) -> for

        mov   L, ax                             ; L := ISTEP
        jmp outerloop

ende:
        finit
        ret

fft     endp


;
; Berechnen der Amplitude des komplexen Ergebnisses der FFT
;
; Skalieren mit Faktor scale
;

        public amplitude
amplitude proc

        mov   di, 0
        mov   si, 0
        mov   cx, N
        shr   cx, 1
        fld   qword ptr scale

@@loop:
        fld   qword ptr [fr+di]
        fmul  st, st
        fld   qword ptr [fi+di]
        fmul  st, st
        faddp
        fsqrt
        fmul  st, st(1)
        fistp word ptr [amp+si]
        add   di, 8
        add   si, 2
        dec   cx
        jnz @@loop

        finit

        ret
amplitude endp


;
; Berechnen der Amplitude des komplexen Ergebnisses der FFT
;
; Logarithmieren und Skalieren mit Faktor scale
;

        public amplitudelog
amplitudelog proc

        mov   di, 0
        mov   si, 0
        mov   cx, N
        shr   cx, 1
        fld   qword ptr scale

@@loop2:
        fld   qword ptr [fr+di]
        fmul  st, st
        fld   qword ptr [fi+di]
        fmul  st, st
        faddp
        fsqrt
;        fld1                            ;
;        fxch                            ;
;        fyl2x                           ;
        fsqrt                           ;
        fmul  st, st(1)
        fistp word ptr [amp+si]
        add   di, 8
        add   si, 2
        dec   cx
        jnz @@loop2

        finit

        ret
amplitudelog endp

        END

