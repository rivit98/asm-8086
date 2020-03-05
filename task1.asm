;  Albert Gierlach
;  File encryption (XOR)

data1 segment
	file_in			db 	40h		dup(0) ;63 bytes + 1 for '0'
	file_out 		db 	40h 	dup(0) ;63 bytes + 1 for '0'
	key				db	80h		dup(0) ;127 bytes + 1 for '0'
	file_in_desc	dw 			?
	file_out_desc	dw			?
	buffer			db	200h	dup(0) 	;512 bytes


	str_emptyArguments		db		"Usage: prog.exe input_file output_file ""encryption key""",10,13,"$"
	str_argumentsError		db		"Arguments are invalid!",10,13,"$"
	str_exitError			db		"Program finished with error :(",10,13,"$"
	str_fileOpenErrorIn		db		"Input file open error!",10,13,"$"
	str_fileOpenErrorOut	db		"Output file open error!",10,13,"$"
	str_fileCreateNew		db		"Creating new input file...",10,13,"$"
	str_fileOverwrite		db		"Overwrite output file? [T/N]: $"
	str_fileReadError		db		"Error during reading from input file",10,13,"$"
	str_fileWriteError		db		"Error during writing to output file",10,13,"$"
	str_success				db		"Encryption successful!",10,13,"$"
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

	call readArgs
	call openFiles
	call xorFile
	call closeFiles

	mov dx, offset str_success
	call putStr

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

			mov di, offset file_in	;point at the start of input file name bufer
			call parseOneArg		;read the first file name
			mov al, 0				;terminate string with 0 byte
			mov ds:[di], al

			mov di, offset file_out	;point at the start of output file name bufer
			call parseOneArg
			mov al, 0				;terminate string with 0 byte
			mov ds:[di], al

			mov di, offset key		;point at the start of key bufer
			call parseLastArg
			mov al, 0				;terminate string with 0 byte
			mov ds:[di], al

		pop di
		pop si
		pop dx
		pop ax
		ret
	readArgs endp

	;parses one argument into [di], requires set di address
	parseOneArg proc
		push ax
		push cx

		call skipSpaces
		mov ch, 0
		loop_copy:
			mov al, es:[si] 
			cmp al, 0dh			;if data ends here then error
			je argumentError

			cmp ch, 40h-1		;overflow protection :)	
			jge copyNext		;-1 because of string termination with 0

			cmp al, ' '			;space = jump to next argument
			je copyNext			;when the arguments are correct, the loop should end here
			mov ds:[di], al
			inc si
			inc di
			inc ch

			jmp loop_copy

		copyNext:
		pop cx
		pop ax
		ret
	parseOneArg endp

	;parses last arg, similar to parseOneArg but accepts spaces
	parseLastArg proc
		push ax
		push cx

		call skipSpaces
		mov ch, 0
		loop_copy:
			mov al, es:[si] 	;get next character from cmd line
			cmp al, 0dh			;no more data
			je exitLoop

			cmp al, '"'			;skip quote
			je skipQuote
			
			cmp ch, 80h-1		;overflow protection :)	
			jge exitLoop		;-1 because of string termination with 0

			mov ds:[di], al
			inc di
			skipQuote:			;if we skip a character we dont increase di
				inc si

			jmp loop_copy

		exitLoop:
		pop cx
		pop ax
		ret
	parseLastArg endp

	;opens input and output file, saves descriptors
	openFiles proc
		push ax
		push dx
		push cx

		;DOS 2+ - OPEN - OPEN EXISTING FILE
		mov dx, offset file_in
		mov al, 0			;read
		mov	ah, 3dh
		int 21h				;errors if CF

		jc fileOpenError	;jump if carry (CF), CF is set when error occured

		mov word ptr ds:[file_in_desc], ax

		;DOS 2+ - OPEN - OPEN EXISTING FILE
		mov dx, offset file_out
		mov al, 1			;save
		mov	ah, 3dh
		int 21h				;errors if CF

		jc createNewFile	;jump if carry (CF), open error - file does not exists

		mov dx, offset str_fileOverwrite
		call putStr

		;DOS 1+ - READ CHARACTER FROM STANDARD INPUT, WITH ECHO
		mov ah, 01h
		int 21h

		call putNewLine

		cmp al, 't'
		je truncFile

		cmp al, 'y'
		je truncFile

		cmp al, 'T'
		je truncFile

		cmp al, 'Y'
		je truncFile

		jmp programExitError

		truncFile:
			;DOS 2+ - CREAT - CREATE OR TRUNCATE FILE
			mov dx, offset file_out
			mov ah, 3ch
			mov cx, 1
			int 21h

			jmp saveFileDescriptor

		createNewFile:
			mov dx, offset str_fileCreateNew
			call putStr

			;DOS 2+ - CREAT - CREATE OR TRUNCATE FILE
			mov dx, offset file_out
			mov ah, 3ch
			mov cx, 1
			int 21h

			jc fileOpenError

		saveFileDescriptor:
			mov ds:[file_out_desc], ax

		pop cx
		pop dx
		pop ax
		ret
	openFiles endp

	;read data from file piece by piece, xor it and save into output file
	xorFile proc
		push cx
		push bx
		push ax
		push dx
		
		loop_loadData:
			;DOS 2+ - READ - READ FROM FILE OR DEVICE
			mov dx, offset buffer		;buffer for data from file
			mov cx, 200h				;sizeof buffer
			mov bx, ds:[file_in_desc]	;file handler goes here
			mov ah, 3fh
			int 21h					;ax stores how many characters have been read

			jc fileReadingError		;error during reading file

			cmp ax, 0				;end of data?
			je readingEnd

			call xorBuffer
			call saveBufferToFile

			cmp ax, 200h			;is the number of loaded data less than the total buffer size?
			jl readingEnd			;yes, finish reading
			jmp loop_loadData		;nope, read another portion of data

		readingEnd:

		pop dx
		pop ax
		pop bx
		pop cx
		ret
	xorFile endp


	;xors buffer with key, stores output in buffer
	xorBuffer proc
		push si
		push di
		push ax
		push bx
		push cx
		
		;ax stores how many characters have been read
		mov di, offset buffer	;buffer iterator
		mov si, offset key		;key iterator
		mov cx, ax				;counter - how many bytes are left to read

		loop_xor:
			cmp cx, 0
			je endXoring

			mov al, byte ptr ds:[di]	;we want only one byte
			xor al, byte ptr ds:[si]	;xor - result in al
			mov byte ptr ds:[di], al	;update buffer

			dec cx
			inc di
			inc si

			mov al, byte ptr ds:[si]
			cmp al, 0 					;if we reached zero in key, we need to start from the beginning of the key
			jne loop_xor

			mov si, offset key			;rewind key

			jmp loop_xor

		endXoring:
		pop si
		pop di
		pop ax
		pop bx
		pop cx
		ret
	xorBuffer endp


	;saves data from buffer to output file
	saveBufferToFile proc
		push dx
		push ax
		push bx
		push cx

		;ax stores how many characters have been read
		mov cx, ax
		mov ah, 40h
		mov bx, ds:[file_out_desc]
		mov dx, offset buffer
		int 21h

		jc fileSavingError		;if CF then error

		pop cx
		pop bx
		pop ax
		pop dx
		ret
	saveBufferToFile endp


	;closes files
	closeFiles proc
		push ax
		push bx

		mov ah, 3eh
		mov bx, ds:[file_in_desc]
		int 21h

		mov ah, 3eh
		mov bx, ds:[file_out_desc]
		int 21h

		pop bx
		pop ax
		ret
	closeFiles endp

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


	;print new line
	putNewLine proc
		push dx

		mov dl, 10
		call putChar

		mov dl, 13
		call putChar

		pop dx
		ret
	putNewLine endp


	;print character from dl
	putChar proc
		push ax

		;DOS 1+ - WRITE CHARACTER TO STANDARD OUTPUT
		mov ah, 02h
		int 21h

		pop ax
		ret
	putChar endp


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
	fileReadingError:
		mov dx, offset str_fileReadError
		call putStr

		call programExitError

	fileSavingError:
		mov dx, offset str_fileWriteError
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

	dw 200h dup(?)
topstack	dw ?

stack1 ends


end start1