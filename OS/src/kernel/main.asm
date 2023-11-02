org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

start:
	jmp main
;prints a string to the screen
;Params:
;	- ds:si points to string

puts:
	;save registers we will modify
	push si
	push ax
	push bx

.loop:
	lodsb ; loads next character in al
	or al,al ;verify if next character is null?
	jz .done
	
	mov ah, 0x0e ; call bios interrupt
	mov bh, 0 ;set page number to 0
	int 0x10

	jmp .loop
	
.done:
	pop bx
	pop ax
	pop si
	ret
	
main:
	;setup data segments
	mov ax,0 ; can't write to ds/es directly
	mov ds, ax
	mov es, ax
	;setup stack
	mov ss,ax
	mov sp,0x7C00 ; stack grows downwards where memory we are loaded in memory

	;print message
	mov si, msg_hello
	call puts
	
	hlt

.halt:
	jmp.halt

msg_hello: db 'Hello Nigga!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h

;db = define bytes = writes given bytes to the assmbled binary file
;Times number instruction/data(directive) repreats given instruction or piece of data a number times
;$ = memory offset of current line
;$$ = memory offset of the beginning of current section (program)
;$-$$ = size of program so far in bytes
;Dw (directive) = define words = writes words(2 byte valye, encoded in little endian) to assembled binary file
