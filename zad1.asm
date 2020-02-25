data1 segment
	file_in			db 	65		dup(0)
	file_out 		db 	65 		dup(0)
	key				db	255		dup(0)
	file_in_desc	dw 			?
	file_out_desc	dw			?


	str_emptyArguments		db		"Uzycie: prog.exe plik_we plik_wy klucz_szyfr",10,13,"$"
	str_argumentsError		db		"Podane argumenty sa niepoprawne!",10,13,"$"
	str_exitError			db		"Program zakonczyl sie niepowodzeniem :(",10,13,"$"
	str_fileOpenErrorIn		db		"Blad otwierania pliku wejsciowego!",10,13,"$"
	str_fileOpenErrorOut	db		"Blad otwierania pliku wyjsciowego!",10,13,"$"
	str_fileCreateNew		db		"Tworze nowy plik wyjsciowy...",10,13,"$"

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

	;wczytanie parametrow
	call readArgs
	call openFiles




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
		cmp		al, 0
		jne		parseArguments
		mov dx, offset str_emptyArguments
		call putStr
		call programExitError

		parseArguments:
			mov si, 81h			;poczatek argumentow

			mov di, offset file_in	;wskaznik na poczatek - odtad bedzie zapis nazwy
			call parseOneArg		;wczytujemy nazwe pierwszego pliku
			mov al, 0				;asci zero terminated string
			mov ds:[di], al

			mov di, offset file_out		;wskaznik na poczatek - odtad bedzie zapis nazwy
			call parseOneArg
			mov al, 0				;asci zero terminated string
			mov ds:[di], al

			mov di, offset key
			call parseLastArg
			mov al, 0				;asci zero terminated string
			mov ds:[di], al

		pop di
		pop si
		pop dx
		pop ax
		ret
	readArgs endp


	;parsuje jeden argument pod adres w di, wymaga wczesniej ustawionego si
	parseOneArg proc
		push ax

		call skipSpaces
		loop_copy:
			mov al, es:[si] 
			cmp al, 0dh			;dane sie skonczyly na pierwszym argumencie = blad
			je argumentError

			cmp al, ' '			;spacja = skaczemy do nastepnego argumentu
			je copyNext			;gdy argumenty sa poprawne, to tutaj powinna sie skonczyc petla
			mov ds:[di], al
			inc si
			inc di

			jmp loop_copy

		copyNext:
		pop ax
		ret
	parseOneArg endp


	;parsuje ostatni argument, podobne do parseOneArg, ale nie sprawdza spacji
	parseLastArg proc
		push ax

		call skipSpaces
		loop_copy:
			mov al, es:[si] 
			cmp al, 0dh			;dane sie skonczyly na pierwszym argumencie = blad
			je copyNext

			cmp al, '"'			;spacja = skaczemy do nastepnego argumentu
			je skipQuote			;gdy argumenty sa poprawne, to tutaj powinna sie skonczyc petla
			
			mov ds:[di], al
			skipQuote:
				inc si
				inc di

			jmp loop_copy

		copyNext:
		pop ax
		ret
	parseLastArg endp

	;otwiera plik wejsciowy, zapisuje deskryptor
	openFiles proc
		push ax
		push dx

		;DOS 2+ - OPEN - OPEN EXISTING FILE
		mov dx, offset file_in
		mov al, 0			;odczyt
		mov	ah, 3dh
		int 21h				;w CF bledy

		jc fileOpenError	;jump if carry (CF)

		mov word ptr ds:[file_in_desc], ax

		;DOS 2+ - OPEN - OPEN EXISTING FILE
		mov dx, offset file_out
		mov al, 1			;zapis
		mov	ah, 3dh
		int 21h				;w CF bledy

		jc fileOpenErrorOut	;jump if carry (CF)
		mov word ptr ds:[file_out_desc], ax


		jmp openingFinished

		fileOpenErrorOut:
			mov dx, offset str_fileOpenErrorOut
			call putStr

			mov dx, offset str_fileCreateNew
			call putStr

			; create new file



		openingFinished:

		pop dx
		pop ax
		ret
	openFiles endp

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
	argumentError:
		mov dx, offset str_argumentsError
		call putStr

		mov dx, offset str_emptyArguments
		call putStr

		call programExitError

	fileOpenError:
		mov dx, offset str_fileOpenErrorIn
		call putStr

		call programExitError

 	programExitError:
		mov dx, offset str_exitError
		call putStr
		
		;DOS 2+ - EXIT - TERMINATE WITH RETURN CODE
		mov al, 1		;kod bledy/wyjscia
		mov	ah, 4ch  	;zakoncz program i wroc do systemu
		int	21h

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