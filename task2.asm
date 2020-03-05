;  Albert Gierlach
;  Text zoom + scrolling

data1 segment
	text			db 	40h		dup(0) 	;63 bytes + 1 for string termination with 0
	textLen			db			0
	zoomvalue		db 			1
	oldVideoMode	db			?
	drawOffset		db			0		;index of the character from which we start to draw text

	str_emptyArguments		db		"Uzycie: prog.exe zoomvalue ""tekst""",10,13,"$"
	str_argumentsError		db		"Podane argumenty sa niepoprawne!",10,13,"$"
	str_exitError			db		"Program zakonczyl sie bledem :(",10,13,"$"
	str_success				db		"Plik zaszyfrowany pomyslnie!",10,13,"$"
	str_zoomWrongValue		db		"Zoom musi byc z przedzialu [1,9]",10,13,"$"

data1 ends

code1 segment
start1:
	;init stack
	mov	sp, offset topstack
	mov	ax, seg topstack
	mov	ss, ax

	;init data segment
	mov ax, seg data1
	mov ds, ax

	;store current video mode
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

	loop_zoom:
		;KEYBOARD - GET KEYSTROKE
		;AH = BIOS scan code
		mov ah, 0
		int 16h

		cmp ah, 04Bh	;left arrow
		je right		;scroll right

		cmp ah, 04Dh	;right arrow
		je left			;scroll left

		jmp exitScrollLoop

	left:
		mov si, offset drawOffset
		mov al, ds:[si]
		cmp	al, 0
		jle ignoreLeft

		sub al, 1
		; sub al, 2		;speed of scrolling, 2 means two characters for one press
		mov ds:[si], al
		call clearScreen
		call displayText

		ignoreLeft:
			jmp loop_zoom

	right:
		mov si, offset drawOffset
		mov al, ds:[si]

		mov di, offset textLen
		mov ah, ds:[di]
		sub ah, 1			;subtracts one so that the text does not disappear completely, so there will always be one visible sign

		cmp	al, ah
		jge ignoreRight

		add al, 1
		; add al, 2
		mov ds:[si], al
		call clearScreen
		call displayText

		ignoreRight:
			jmp loop_zoom

	exitScrollLoop:

	;wait for character
	;DOS 1+ - READ CHARACTER FROM STANDARD INPUT, WITH ECHO
	; mov ah, 01h
	; int 21h

	;restore old video mode
	;VIDEO - SET VIDEO MODE
	mov ah, 0h
	mov al, ds:[oldVideoMode]
	int 10h


	jmp programExit


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;reads parameters, verify them
	readArgs proc
		push ax
		push dx
		push si
		push di

		xor 	ax, ax
		mov   	al, byte ptr es:[80h] 	;number of characters of cmd line - offset 80h
		cmp		al, 0					;check if any arguments exists
		jne		parseArguments
		mov dx, offset str_emptyArguments
		call putStr
		call programExitError

		parseArguments:
			mov si, 81h			;cmd line starts at 81h

			call parseZoom			;read zoom value

			mov di, offset text		;point at the start of text bufer
			call parseLastArg
			mov al, 0				;terminate string with 0 byte
			mov ds:[di], al

			;get length of the file, just subtract index registers
			mov si, offset text
			sub di, si
			mov ax, di
			xor ah, ah
			mov si, offset textLen
			mov ds:[si], al

		pop di
		pop si
		pop dx
		pop ax
		ret
	readArgs endp

	;parses first argument and converts it to digit
	parseZoom proc
		push ax

		call skipSpaces

		mov al, es:[si]		;current char
		cmp al, 0dh			;if data ends here then error
		je argumentError

		;check if value is digit
		cmp al, '1'
		jl zoomWrongValue

		cmp al, '9'
		jg zoomWrongValue

		sub al, '0'			;convert to number
		mov ds:[zoomvalue], al

		inc si

		mov al, es:[si]			;get next character
		cmp al, ' '				;if the next character after zoom is not a space, it means something longer than 1 character
		jne argumentError

		call skipSpaces
		cmp al, 0dh				;after skipping spaces, only the 0dh character left, which means that there is no second argument
		je argumentError

		pop ax
		ret
	parseZoom endp


	;parses last arg, similar to parseOneArg but accepts spaces
	parseLastArg proc
		push ax
		push cx

		xor ch, ch
		loop_copy:
			mov al, es:[si] 	;get next character from cmd line
			cmp al, 0dh			;no more data
			je exitLoop

			cmp al, '"'			;skip quote
			je skipQuote

			cmp ch, 40h-1		;overflow protection :)	
			jge exitLoop		;-1 because of string termination with 0
			
			mov ds:[di], al
			inc ch
			inc di
			skipQuote:			;if we skip a character we dont increase di
				inc si

			jmp loop_copy

		exitLoop:
		pop cx
		pop ax
		ret
	parseLastArg endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	clearScreen proc
		push ax
		push dx
		push bx
		push cx

		;VIDEO - SCROLL UP WINDOW
		;AL = number of lines by which to scroll up (00h = clear entire window)
		mov ah, 06h
		mov al, 0h
		mov bh,	0h		;color, black
		mov cx, 0h    	;initial coordinates, upper left corner
		mov dh, 24		;row number
		mov dl, 79		;column number, because it draws like a rectangle, so you have to give two points
		int 10h

		pop cx
		pop bx
		pop dx
		pop ax

	clearScreen endp


	;draw text char by char
	displayText proc
		push ax
		push bx
		push cx
		push di
		push si

		;use mul (TODO)
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
		mov di, 320 * 100		;center text 320 * 100
		;since the font is 14 high, I need to subtract 7 before I can draw * zoomvalue rows, so 7 * 320 * zoomvalue pixels
		sub di, ax				;ax calculated earlier, how many pixels to subtract to jump above
		mov bx, di				;it will be used to detect if the text still fits or not
		add bx, 320				;skips immediately to the new line, if it is bigger than this (bx) then we finish drawing
		add di, 10h				;move the text away from the left edge, e.g. by 16 pixels


		;scrolling support, we just start with which letters
		mov si, offset drawOffset
		xor ax, ax
		mov al, ds:[si]


		mov si, offset text
		add si, ax
		loop_drawLetters:
			;scrolling support - if there is no space then we don't draw further
			call checkIfCanDrawChar
			cmp al, 0
			jne drawingTextFinished

			mov	al, ds:[si]		;text char

			cmp al, 0			;text ended
			je drawingTextFinished

			call drawCharacter

			inc si

			;instead of 8 pixels we have to move 8 * zoomvalue, because the characters are zoomed
			call increase_di
			; add di, 8h		; (DEBUG)

			jmp loop_drawLetters

		drawingTextFinished:

		pop si
		pop di
		pop cx
		pop bx
		pop ax
		ret
	displayText endp


	;check whether we can draw a new character (if it fits in line), returns 0 in al if we can
	checkIfCanDrawChar proc
		push di

		mov al, 1
		call increase_di
		cmp di, bx
		jge notAllowed
		mov al, 0

		notAllowed:

		pop di
		ret
	checkIfCanDrawChar endp


	;adds 8 * zoomvalue to di
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


	;adds zoomvalue to di
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


	;single character drawing procedure
	;in al requires which character to draw
	;in di requires upper left corner (offset ofc) from which to start draw
	drawCharacter proc
		push es
		push ds
		push ax
		push bx
		push cx
		push di
		push si

		xor ah, ah			;only lower 8 bytes (al)
		mov bl, 0eh			;14 - number of rows in font character
		mul bl				;multiply ax (now al) times 14, because one character takes 14bytes
		xor si, si			;si will be an iterator over 14 bytes of one character
		add si, ax			;font data offset

		;VIDEO - GET FONT INFORMATION (EGA, MCGA, VGA)
		;bh - 02h ROM 8x14 character font pointer
		;bh - 03h ROM 8x8 double dot font pointer
		mov ax, 1130h
		mov bh, 02h
		int 10h

		mov ax, es		;set the datasegment where the fonts are
		mov ds, ax		;remember to change the segment when getting zoomvalue

		add si, bp		;bp is returned by previous interrupt, points to memory where font data begin
						;we add this value to the already calculated offset of a given character

		;here the video memory begins
		mov ax, 0a000h
		mov es, ax

		;each character takes 14bytes = 112 bits. Each set bit is a pixel on the screen. Each line is a byte.
		;bytes 0-13 = ascii char with 0 index
		;14-27 = index 1
		;.... etc

		mov ch, 0eh			;14 rows
		loop_row:
			cmp ch, 0
			je drawingFinished

			mov bh,	10000000b		;mask for bytes
			mov cl, 8				;8 columns
			loop_column:
				cmp cl, 0
				je drawingColumnFinished

				mov al, ds:[si]		;get byte of the font
				and al, bh			;check if a given bit is set or not

				cmp al, 0			;if not
				je skipDrawing		;dont draw anything, we clear the screen with black color, so whatever

				;if yes
				mov al, 0fh			;white color

				; mov es:[di], al		; (DEBUG)
				; inc di				; (DEBUG)

				call drawSquare

				skipDrawing:
					call indcrease_di_by_zoomvalue

				shr bh, 1			;shift mask to the right (because it draws from left to right)
				dec cl

				jmp loop_column

			drawingColumnFinished:
				call nextRowBig			;we jump to the new 'big' row... but we have to do it zoomvalue times
										;...but we are 8 * zoomvalue pixels too far, so we have to subtract
				
				; add di, 320 			; (DEBUG)
				; sub di, 8				; (DEBUG)
				
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


	;shifts di for zoomvalue lines
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

			add di, 320			;screen width

			dec cl
			jmp loop_nextRowBig

		exitNextRowBig:

		;now correction, we need to go back 8 * zoomvalue back
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


	;draws square zoomvalue by zoomvalue, requires color in al, di has to point on upper left corner of the square
	drawSquare proc
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
				add di, 320 		;jump to next row...
				xor bx, bx
				mov bl, ds:[si]
				sub di, bx			;...but we are 'zoomvalue' pixels too far so we have to subtract
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
	drawSquare endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;move si until we encountered non-space character
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


	;print ds:dx
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
		mov al, 1		;exit code, error
		mov	ah, 4ch  	;terminate program
		int	21h

	programExit:
		;DOS 2+ - EXIT - TERMINATE WITH RETURN CODE
		mov al, 0		;exit code, 0 means success
		mov	ah, 4ch  	;terminate program
		int	21h

code1 ends
 

stack1 segment stack

	dw 300 dup(?)
topstack	dw ?

stack1 ends


end start1