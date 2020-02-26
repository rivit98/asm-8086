;  Albert Gierlach
;  Asembler, szyfrowanie plikow (XOR)

data1 segment
	file_in			db 	80h		dup(0) ;127 bajtow + 1 na zero
	file_out 		db 	80h 	dup(0) ;127 bajtow + 1 na zero
	key				db	80h		dup(0) ;127 bajtow + 1 na zero
	file_in_desc	dw 			?
	file_out_desc	dw			?
	buffer			db	100h	dup(0) ; 256 bajtow


	str_emptyArguments		db		"Uzycie: prog.exe plik_we plik_wy klucz_szyfr",10,13,"$"
	str_argumentsError		db		"Podane argumenty sa niepoprawne!",10,13,"$"
	str_exitError			db		"Program zakonczyl sie niepowodzeniem :(",10,13,"$"
	str_fileOpenErrorIn		db		"Blad otwierania pliku wejsciowego!",10,13,"$"
	str_fileOpenErrorOut	db		"Blad otwierania pliku wyjsciowego!",10,13,"$"
	str_fileCreateNew		db		"Tworze nowy plik wyjsciowy...",10,13,"$"
	str_fileOverwrite		db		"Czy napewno nadpisac plik wyjsciowy? [T/N]: $"
	str_fileReadError		db		"Blad podczas czytania pliku wejsciowego",10,13,"$"

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
	call xor_file



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

			mov di, offset key		;wskaznik na poczatek - odtad bedzie zapis klucza
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

			cmp al, '"'			;pomijamy cudzyslow
			je skipQuote
			
			mov ds:[di], al
			skipQuote:
				inc si
				inc di

			jmp loop_copy

		copyNext:
		pop ax
		ret
	parseLastArg endp


	;otwiera plik wejsciowy i wyjsciowy, zapisuje deskryptory
	openFiles proc
		push ax
		push dx
		push cx

		;DOS 2+ - OPEN - OPEN EXISTING FILE
		mov dx, offset file_in
		mov al, 0			;odczyt
		mov	ah, 3dh
		int 21h				;w CF bledy

		jc fileOpenError	;jump if carry (CF), CF ustawione gdy blad

		mov word ptr ds:[file_in_desc], ax

		;DOS 2+ - OPEN - OPEN EXISTING FILE
		mov dx, offset file_out
		mov al, 1			;zapis
		mov	ah, 3dh
		int 21h				;w CF bledy

		jc fileOpenErrorOut	;jump if carry (CF)

		mov dx, offset str_fileOverwrite
		call putStr

		mov dx, ax			;deskryptor pliku daje do dx, zeby ponizsze przerwanie nie nadpisalo

		;DOS 1+ - READ CHARACTER FROM STANDARD INPUT, WITH ECHO
		mov ah, 01h
		int 21h

		call putNewLine

		cmp al, 't'
		je saveFileDescriptor

		cmp al, 'T'
		je saveFileDescriptor

		jmp fileOpenError

		saveFileDescriptor:
			mov word ptr ds:[file_out_desc], dx
			jmp openingFinished

		fileOpenErrorOut:
			mov dx, offset str_fileOpenErrorOut
			call putStr

			mov dx, offset str_fileCreateNew
			call putStr

			;DOS 2+ - CREAT - CREATE OR TRUNCATE FILE
			mov dx, offset file_out
			mov ah, 3ch
			mov cx, 0
			int 21h

			jc fileOpenError

			mov dx, ax
			jmp saveFileDescriptor

		openingFinished:
			

		pop cx
		pop dx
		pop ax
		ret
	openFiles endp


	xor_file proc
		push cx
		push bx
		push ax

		loop_loadData:
			;DOS 2+ - READ - READ FROM FILE OR DEVICE
			mov dx, offset buffer
			mov cx, 100h
			mov bx, ds:[file_in_desc]
			mov ah, 3fh
			int 21h					;do ax wklada ilosc wczytanych bajtow

			jc fileReadingError		;blad podczas czytania

			cmp ax, 0				;czy dane sie skonczyly?
			je readingEnd

			mov dx, offset buffer
			call putStr



		readingEnd:

		pop ax
		pop bx
		pop cx
	xor_file endp

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


	;wypisz nowa linie
	putNewLine proc
		push dx

		mov dl, 10
		call putChar

		mov dl, 13
		call putChar

		pop dx
		ret
	putNewLine endp


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
	fileReadingError:
		mov dx, offset str_fileReadError
		call putStr

		call programExitError

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