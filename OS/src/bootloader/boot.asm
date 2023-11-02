org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;FAT 12 Header
; first 3 bytes must be a jmp instruction to NOP
jmp short start
nop

bdb_oem:			db 'MSWIN4.1'		;8 bytes
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:			db 2
bdb_dir_entries_count:		dw 0E0h
bdb_total_sectors:		dw 2880			; 2880 * 512 = 1.44 MB
bdb_media_descriptor_type:	db 0F0h			; F0 = 3.5" floppy disk
bdb_sectors_per_fat:		dw 9			; 9 sectors/fat
bdb_sectors_per_track:		dw 18
bdb_heads:			dw 2
bdb_hidden_sectors:		dd 0
bdb_large_sector_count:		dd 0

; extended boot record
ebr_drive_number: 		db 0			; 0x00 floppy, 0x80 hdd
				db 0			; reserved
ebr_signature:			db 29h
ebr_volume_id:			db 12h, 34h, 56h, 78h	; serial number, value doesnt need
ebr_volume_lable:		db 'ALT OS     '	; 11 bytes padded with space
ebr_system_id:			db 'FAT12   '		; 8 bytes

; code here

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
	
	; read something from floppy disk
	; BIOS should set DL to drive number
	mov [ebr_drive_number],dl
	mov ax, 1				; LBA=1, second sector from disk
	mov cl, 1				; 1 sector to read
	mov bx, 0x7E00				; data should be after bootloader
	call disk_read

	;print message
	mov si, msg_hello
	call puts
	
	cli					; disable interrupts, this way CPU cant get out of halt state	
	hlt

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h					; wait for keypress
	jmp 0FFFFh:0				; jump to beginning of BIOS, so reboot

.halt:
	cli					; disable interrupts, this way CPU can't get out of halt state
	hlt

; Disk routines

; Converts an LBA address to a CHS address
; Parameters:
;	- ax: LBA address
; Returns:
;	- cx (bits 0-5): sector number
;	- cx (bits 6-15): cylinder
;	- dh: head

lba_to_chs:

	push ax
	push dx

	xor dx, dx				; dx = 0
	div word [bdb_sectors_per_track]	; ax = LBA / SectorsPerTrack
						; dx = LBA % SectorsPerTrack
	inc dx					; dx = (LBA % SectorsPerTrack + 1) = sector
	mov cx, dx				; cx = sector

	xor dx, dx				; dx = 0
	div word [bdb_heads]			; ax = (LBA / SectorsPerTrack) / heads = cylinder
						; dx = (LBA / SectorsPerTrack) % heads = head
	mov dh, dl				; dh = head
	mov ch, al				; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah				; put upper 2 bits of cylinder in cl
	
	pop ax
	mov dl, al				; restore dl
	pop ax
	ret

; Reads sectors from a disk
; Parameters:
;	- ax: LBA address
;	- cl: number of sectors to read (up to 128)
;	- dl: points to drive number
;	- es:bx: memory address where to store read data = buffer
; Return:
;	- AH = status see int 13
;	- AL = number of sectors read
;	- CF = 0 if successful
;	     = 1 if error

disk_read:
	
	push ax					; save registers we will modify
	push bx
	push cx
	push dx
	push di
	
	push cx					; temporarily save CL (number of sectors to read)
	call lba_to_chs				; compute CHS	
	pop ax					; AL = number of sectors to read
	
	mov ah, 02h
	mov di, 3				; rety count since irl floppy disk are unreliable
	
.retry:
	pusha					; save all registers, we don't know what bios modifies
	stc					; set carry flag, some BIOS'es don't set it	
	int 13h					; carry flag cleared = success
	jnc .done				; jump if carry not set

	; read failed try 3 times to read
	popa
	call disk_reset
	
	dec di
	test di, di
	jnz .retry
.fail:
	;attempts are exhausted
	jmp floppy_error

.done:
	popa
	
	pop di					; restore registers modified
	pop dx
	pop cx
	pop bx
	pop ax
	ret

; Reset disk controller
; Parameters:
;	dl: drive number
;
disk_reset:
	pusha
	mov ah,0
	stc
	int 13h
	jc floppy_error
	popa
	ret	
	

msg_hello: db 'Hello World!', ENDL, 0
msg_read_failed: db 'Read from disk failed!',ENDL, 0

times 510-($-$$) db 0
dw 0AA55h

;db = define bytes = writes given bytes to the assmbled binary file
;Times number instruction/data(directive) repreats given instruction or piece of data a number times
;$ = memory offset of current line
;$$ = memory offset of the beginning of current section (program)
;$-$$ = size of program so far in bytes
;Dw (directive) = define words = writes words(2 byte valye, encoded in little endian) to assembled binary file

