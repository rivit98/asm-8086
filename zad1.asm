data1 segment
	file_in		db 	65		dup(0)
	file_out 	db 	65 		dup(0)
	key			db	255		dup(0)


	str_emptyArguments		db		"Brak argumentow! Uzycie: prog.exe plik_we plik_wy klucz_szyf",10,13,"$"
	str_exitError			db		"Program zakonczyl sie niepowodzeniem :(",10,13,"$"

data1 ends


code1 segment
start1:
	;inicjalizacja stosu
	mov	sp, offset topstack
	mov	ax, seg topstack
	mov	ss, ax

	;zczytanie parametrow
	call readArgs


	mov al, 0 ; kod wyjscia
	jmp programExit

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;wczytuje parametry
	readArgs proc
		push ax
		push bx
		push cx
		push dx

		xor 	cx, cx
		mov   	cl, byte ptr ds:[80h] 	;dlugosc linii argumentow na offsecie 80h
		cmp		cl, 0
		jne		parseArguments
		mov dx, offset str_emptyArguments
		call putStr
		call programExitError


		parseArguments:

		; DOS 2+ - WRITE - WRITE TO FILE OR DEVICE
        mov     ah, 40h					;
        mov     bx, 1					;stdout
        mov     dx, 81h
        int     21h             

		pop dx
		pop cx
		pop bx
		pop ax
		ret
	readArgs endp


	;wypisz ds:dx an stdout
	putStr proc
		push ax
		push ds

		;DOS 1+ - WRITE STRING TO STANDARD OUTPUT
		mov ax, seg data1
		mov ds, ax
		xor ax, ax
		mov ah, 09h
		int 21h

		pop ds
		pop ax
		ret
	putStr endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 	programExitError:
		mov dx, offset str_exitError
		call putStr
		mov al, 1		;kod bledy/wyjscia
		mov	ah, 4ch  	;zakoncz program i wroc do systemu
		int	21h

	programExit:
		mov	ah, 4ch  	;zakoncz program i wroc do systemu
		int	21h
 
code1 ends
 
 
 
stack1 segment stack

	dw 300 dup(?)
topstack	dw ?

stack1 ends


end start1