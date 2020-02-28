;  Albert Gierlach
;  Zoom tekstu

data1 segment
	text			db 	20h		dup(0) 	;31 bajty + 1 na zero
	zoomvalue		db 			1
	oldVideoMode	db			?

	str_emptyArguments		db		"Uzycie: prog.exe ZOOMLEVEL ""tekst""",10,13,"$"
	str_argumentsError		db		"Podane argumenty sa niepoprawne!",10,13,"$"
	str_exitError			db		"Program zakonczyl sie bledem :(",10,13,"$"
	str_success				db		"Plik zaszyfrowany pomyslnie!",10,13,"$"
	str_zoomWrongValue		db		"Zoom musi byc z przedzialu [1,9]",10,13,"$"
data1 ends

code1 segment
start1:
	;inicjalizacja stosu
	mov	sp, offset topstack
	mov	ax, seg topstack
	mov	ss, ax

	;inicjalizacja seg danych
	mov ax, seg data1
	mov ds, ax

	;zapisuje obecny tryb
	;VIDEO - GET CURRENT VIDEO MODE
	mov ah, 0fh
	int 10h
	mov ds:[oldVideoMode], al

	;call readArgs

	;VIDEO - SET VIDEO MODE
	mov ah, 0h
	mov al, 13h			;13h = G  40x25  8x8   320x200  256/256K  .   A000 VGA,MCGA,ATI VIP
	int 10h

	call drawCharacter
	;call displayText

	;czekaj na klawisz
	;DOS 1+ - READ CHARACTER FROM STANDARD INPUT, WITH ECHO
	mov ah, 01h
	int 21h

	;przywracam poprzedni tryb
	;VIDEO - SET VIDEO MODE
	mov ah, 0h
	mov al, ds:[oldVideoMode]
	int 10h


	jmp programExit


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;wczytuje parametry, weryfikuje poprawnosc
	readArgs proc
		push ax
		push dx
		push si
		push di

		xor 	ax, ax
		mov   	al, byte ptr es:[80h] 	;dlugosc linii argumentow na offsecie 80h
		cmp		al, 0					;sprawdz czy sa jakies argumenty
		jne		parseArguments
		mov dx, offset str_emptyArguments
		call putStr
		call programExitError

		parseArguments:
			mov si, 81h			;poczatek argumentow

			call parseZoom			;wczytujemy powiekszenie

			mov di, offset text		;wskaznik na poczatek - odtad bedzie zapis klucza
			call parseLastArg
			mov al, 0				;dodaje zero na koniec stringa
			mov ds:[di], al

		pop di
		pop si
		pop dx
		pop ax
		ret
	readArgs endp

	;parsuje jeden argument i konwertuje na cyfre
	parseZoom proc
		push ax

		call skipSpaces

		mov al, es:[si]		;obecny znak
		cmp al, 0dh			;dane sie skonczyly na pierwszym argumencie = blad
		je argumentError

		;sprawdz czy wczytane napewno jest cyfra
		cmp al, '1'
		jl zoomWrongValue

		cmp al, '9'
		jg zoomWrongValue

		;obsluzyc blad ze nie cyfra
		sub al, '0'			;konwertuje na liczbe
		mov ds:[zoomvalue], al

		inc si

		mov al, es:[si]			;wyciag kolejny znak argumentow
		cmp al, ' '				;jesli nastepny znak po zoomie to nie spacja, to znaczy ze podano cos dluzsze niz 1 znak
		jne argumentError

		call skipSpaces
		cmp al, 0dh				;po przewinieciu spacji zostal tylko znak 0dh, co oznacza ze nie ma drugiego argumentu
		je argumentError

		pop ax
		ret
	parseZoom endp


	;parsuje ostatni argument, podobne do parseOneArg, ale nie sprawdza spacji
	parseLastArg proc
		push ax

		loop_copy:
			mov al, es:[si] 	;wyciag kolejny znak argumentow
			cmp al, 0dh			;dane sie skonczyly
			je exitLoop

			cmp al, '"'			;pomijamy cudzyslow
			je skipQuote
			
			mov ds:[di], al
			inc di
			skipQuote:			;jesli pomijamy jakis znak to nie zwiekszamy di
				inc si

			jmp loop_copy

		exitLoop:
		pop ax
		ret
	parseLastArg endp


	;procedura rysowania pojedynczego znaku, w al wymaga jaki znak rysowac
	drawCharacter proc
		push es
		push ds
		push ax
		push bx
		push cx
		push di
		push si

		;VIDEO - GET FONT INFORMATION (EGA, MCGA, VGA)
		;bh - 02h ROM 8x14 character font pointer
		;bh - 03h ROM 8x8 double dot font pointer
		mov ax, 1130h
		mov bh, 02h
		int 10h

		mov ax, es		;ustawiam datasegment, tam gdzie siedzą czcionki
		mov ds, ax

		;tu zaczyna sie pamiec video
		mov ax, 0a000h
		mov es, ax
		
		xor si, si		;si bedzie iteratorem po 14 bajtach jednego znaku
		add si, bp		;tu zaczynaja sie bitmapy czcionek, bp jest zwracane przez powyzsze przerwanie

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		xor ax, ax
		mov al, 61h		;61h a
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		;kazdy znak zajmuje 14bajtow czyli 112bity. Kazdy zapalony bit to pixel na ekranie. Kazdy wiersz to bajt.
		;bajty 0-13 = znak ascii o indeksie 0
		;14-27 = index 1
		;.... itd

		mov bl, 0eh
		mul bl				;mnoze ax razy 16, bo jeden znak zajmuje 16bajtow
		add si, ax			;po dodaniu si trzyma pierwszy bajt rysowanego znaku

		xor di, di			;iterator po pamieci video 
		; mov di, 320
		; mul di, 064h		;to trzeba wyliczyc

		mov ch, 0eh			;14 wierszy
		loop_row:
			cmp ch, 0
			je drawingFinished

			mov ah,	10000000b		;maska dla kolejnych bitow
			mov cl, 8				;8 kolumn
			loop_column:
				cmp cl, 0
				je drawingColumnFinished

				mov al, ds:[si]		;wyciag bajt czcionki
				and al, ah			;sprawdzam czy dany pixel ma byc zapalony czy nie

				cmp al, 0			;jesli bit niezapalony - rysuj czarny kolor
				je drawBlackPixel

				;w przeciwnym przypadku - bialy
				mov al, 0fh			;bialy kolor
				jmp drawPixel

				drawBlackPixel:
					mov al, 00h			;czarny kolor

				drawPixel:
					mov es:[di], al		;wpisz kolor na pamiec video

					shr ah, 1h			;przesun maske w prawo (bo rysuje od lewej do prawej)
					inc di
					dec cl

				jmp loop_column

			drawingColumnFinished:
				add di, 320 		;przeskakujemy do nowego wiersza...
				sub di, 8			;...ale jestesmy o 8 pixeli za daleko, wiec trzeba odjac
				inc si
				dec ch
			
			jmp loop_row

		drawingFinished:
		pop si
		pop di
		pop cx
		pop bx
		pop ax
		pop ds
		pop es
		ret
	drawCharacter endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;przesuwamy si, az napotkamy nie-spacje
	skipSpaces proc
		push ax

		loop_Chars:
			mov		al, es:[si]
			cmp		al, ' '
			jne		skipSpacesExit
			inc		si
			jmp 	loop_Chars

		skipSpacesExit:
			pop		 ax
			ret
	skipSpaces endp


	;wypisz dl na stdout (jeden znak)
	putChar proc
		push ax

		;DOS 1+ - WRITE CHARACTER TO STANDARD OUTPUT
		mov ah, 02h
		int 21h

		pop ax
		ret
	putChar endp


	;wypisz ds:dx an stdout
	putStr proc
		push ax

		;DOS 1+ - WRITE STRING TO STANDARD OUTPUT
		xor al, al
		mov ah, 09h
		int 21h

		pop ax
		ret
	putStr endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	zoomWrongValue:
		mov dx, offset str_zoomWrongValue
		call putStr

		call programExitError

	argumentError:
		mov dx, offset str_argumentsError
		call putStr

		mov dx, offset str_emptyArguments
		call putStr

		call programExitError

 	programExitError:
		mov dx, offset str_exitError
		call putStr
		
		;DOS 2+ - EXIT - TERMINATE WITH RETURN CODE
		mov al, 1		;kod bledy/wyjscia

	programExit:
		;DOS 2+ - EXIT - TERMINATE WITH RETURN CODE
		mov al, 0		;kod sukcesu
		mov	ah, 4ch  	;zakoncz program i wroc do systemu
		int	21h

code1 ends
 

stack1 segment stack

	dw 300 dup(?)
topstack	dw ?

stack1 ends


end start1