;  Albert Gierlach
;  Zoom tekstu

data1 segment
	text			db 	40h		dup(0) 	;64 bajty + 1 na zero
	zoomvalue		db 			1
	buffer			db	100h	dup(0) 	;256 bajtow


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

	call readArgs
	;call switchMode
	;call displayText

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

		mov al, es:[si] 
		cmp al, 0dh			;dane sie skonczyly na pierwszym argumencie = blad
		je argumentError

		;sprawdz czy wczytane napewno jest cyfra
		cmp al, '0'
		jl zoomWrongValue

		cmp al, '9'
		jg zoomWrongValue

		;obsluzyc blad ze nie cyfra
		sub al, '0'			;konwertuje na liczbe
		mov ds:[zoomvalue], al
		inc si

		pop ax
		ret
	parseZoom endp


	;parsuje ostatni argument, podobne do parseOneArg, ale nie sprawdza spacji
	parseLastArg proc
		push ax

		call skipSpaces

		mov al, es:[si]			;wyciag kolejny znak argumentow
		cmp al, 0dh				;po przewinieciu spacji zostal tylko znak 0dh, co oznacza ze nie ma drugiego argumentu
		je argumentError

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