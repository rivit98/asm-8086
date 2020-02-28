;  Albert Gierlach
;  Zoom tekstu

data1 segment
	text			db 	20h		dup(0) 	;31 bajty + 1 na zero
	zoomvalue		db 			1
	oldVideoMode	db			?

	str_emptyArguments		db		"Uzycie: prog.exe zoomvalue ""tekst""",10,13,"$"
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

	call readArgs

	;VIDEO - SET VIDEO MODE
	mov ah, 0h
	mov al, 13h			;13h = G  40x25  8x8   320x200  256/256K  .   A000 VGA,MCGA,ATI VIP
	int 10h

	call displayText

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	displayText proc
		push ax
		push cx
		push di
		push si

		;przerobic to pozniej na mnozenie, mul
		mov di, offset zoomvalue
		mov ch, ds:[di]
		xor ax, ax
		loop_centering:
			cmp ch, 0
			je loop_centering_exit

			add ax, 7h * 140h

			dec ch
			jmp loop_centering

		loop_centering_exit:

		xor di, di
		mov di, 140h * 064h		;centruje tekst 320 * 100
		;skoro czcionka jest wysoka na 14 to zanim zaczne rysowac musze odjac 7 * zoomvalue wierszy. czyli 7 * 320 * zoomvalue pixeli
		sub di, ax				;ax wyliczone wczesniej
		add di, 010h			;odsun troche tekst od lewej krawedzi, np o 16 pixeli


		mov si, offset text
		loop_drawLetters:
			mov	al, ds:[si]		;znak tekstu

			cmp al, 0			;tekst sie skonczyl
			je drawingTextFinished

			call drawCharacter

			inc si

			;zamiast 8 pixeli musimy sie przesunac o 8 * zoomvalue, bo znaki sa powiekszone
			; add di, 8h
			call increase_di

			jmp loop_drawLetters

		drawingTextFinished:

		pop si
		pop di
		pop cx
		pop ax
		ret
	displayText endp


	;dodaje do di wartosc 8 * zoomvalue
	increase_di proc
		push si
		push ax
		push bx
		push ds

			mov bx, seg zoomvalue
			mov ds, bx

			xor bx, bx
			mov si, offset zoomvalue
			mov al, 8
			mov bl, ds:[si]
			mul bl
			add di, ax

		pop ds
		pop bx
		pop ax
		pop si
		ret
	increase_di endp

	indcrease_di_by_zoomvalue proc
		push si
		push ax
		push ds
		push bx

			mov bx, seg zoomvalue
			mov ds, bx

			xor ax, ax
			mov si, offset zoomvalue
			mov al, ds:[si]
			add di, ax

		pop bx
		pop ds
		pop ax
		pop si
		ret
	indcrease_di_by_zoomvalue endp


	;procedura rysowania pojedynczego znaku, w al wymaga jaki znak rysowac, w ah wymaga zoomvalue, w di wymaga lewego gornego pixela (offset) od ktorego ma rysowac
	drawCharacter proc
		push es
		push ds
		push ax
		push bx
		push cx
		push di
		push si

		xor ah, ah			;zostaw tylko dolne 8 bajtow (al)
		mov bl, 0eh			;14 - bo tyle wierszy ma znak
		mul bl				;mnoze ax (czyli teraz juz al) razy 14, bo jeden znak zajmuje 14bajtow
		xor si, si			;si bedzie iteratorem po 14 bajtach jednego znaku
		add si, ax			;offset bitmapy rysowanego znaku

		;VIDEO - GET FONT INFORMATION (EGA, MCGA, VGA)
		;bh - 02h ROM 8x14 character font pointer
		;bh - 03h ROM 8x8 double dot font pointer
		mov ax, 1130h
		mov bh, 02h
		int 10h

		mov ax, es		;ustawiam datasegment, tam gdzie sa czcionki
		mov ds, ax

		add si, bp		;bp jest zwracane przez powyzsze przerwanie, wskazuje na pamiec gdzie zaczynaja sie dane czcionek
						;dodajemy ta wartosc do juz wyliczonego przez nas offsetu danego znaku

		;tu zaczyna sie pamiec video
		mov ax, 0a000h
		mov es, ax

		;kazdy znak zajmuje 14bajtow czyli 112bity. Kazdy zapalony bit to pixel na ekranie. Kazdy wiersz to bajt.
		;bajty 0-13 = znak ascii o indeksie 0
		;14-27 = index 1
		;.... itd

		mov ch, 0eh			;14 wierszy
		loop_row:
			cmp ch, 0
			je drawingFinished

			mov bh,	10000000b		;maska dla kolejnych bitow
			mov cl, 8				;8 kolumn
			loop_column:
				cmp cl, 0
				je drawingColumnFinished

				mov al, ds:[si]		;wyciag bajt czcionki
				and al, bh			;sprawdzam czy dany pixel ma byc zapalony czy nie

				cmp al, 0			;jesli bit niezapalony - rysuj czarny kolor
				je drawBlackPixel

				;w przeciwnym przypadku - bialy
				mov al, 0fh			;bialy kolor
				jmp drawPixel

				drawBlackPixel:
					mov al, 0			;czarny kolor

				drawPixel:

					; mov es:[di], al		;rysuj pixel
					; inc di

					call drawSquares
					call indcrease_di_by_zoomvalue

					shr bh, 1			;przesun maske w prawo (bo rysuje od lewej do prawej)
					dec cl

				jmp loop_column

			drawingColumnFinished:
				call nextRowBig			;przeskakujemy do nowego duzego wiersza... ale musimy to zrobic zoomvalue razy
										;...ale jestesmy o 8 * zoomvalue pixeli za daleko, wiec trzeba odjac
				
				; add di, 320 		
				; sub di, 8			
				
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


	;przesuwa di o zoomvalue wierszy
	nextRowBig proc
		push si
		push cx
		push bx
		push ax
		push ds

		mov ax, seg zoomvalue
		mov ds, ax

		mov si, offset zoomvalue
		mov cl, ds:[si]
		loop_nextRowBig:
			cmp cl, 0
			je exitNextRowBig

			add di, 320			;szerokosc ekranu

			dec cl
			jmp loop_nextRowBig

		exitNextRowBig:

		;teraz korekcja, cofnac sie trzeba o 8 * zoomvalue do tylu
		xor ax, ax
		mov al, ds:[si]
		mov bl, 8
		mul bl
		sub di, ax

		pop ds
		pop ax
		pop bx
		pop cx
		pop si
		ret
	nextRowBig endp


	;rysuje duzy pixel zoomvalue x zoomvalue, wymaga w al koloru, di wskazuje na lewy gorny rog kwadratu
	drawSquares proc
		push di
		push si
		push cx
		push ax
		push bx
		push ds

		mov bx, seg zoomvalue
		mov ds, bx

		mov si, offset zoomvalue
		mov ch, ds:[si]
		loop_drawSquare1:
			cmp ch, 0
			je exitDrawSquare1

			mov cl, ds:[si]
			loop_drawSquare2:
				cmp cl, 0
				je exitDrawSquare2

				mov es:[di], al

				inc di
				dec cl
				jmp loop_drawSquare2

			exitDrawSquare2:
				add di, 320 		;przeskakujemy do nowego wiersza...
				xor bx, bx
				mov bl, ds:[si]
				sub di, bx			;...ale jestesmy o zoomvalue pixeli za daleko, wiec trzeba odjac
				dec ch
				jmp loop_drawSquare1


		exitDrawSquare1:

		pop ds
		pop bx
		pop ax
		pop cx
		pop si
		pop di
		ret
	drawSquares endp

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