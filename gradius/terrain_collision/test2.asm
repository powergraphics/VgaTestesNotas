
		%define MISC_OUTPUT  03c2h
		%define GC_INDEX     03ceh
		%define GC_DATA      03cfh
		%define SC_INDEX     03c4h
		%define SC_DATA      03c5h
		%define CRTC_INDEX   03d4h
		%define CRTC_DATA    03d5h
		%define INPUT_STATUS 03dah
		%define AC_WRITE     03c0h
		%define AC_READ      03c1h		
		%define MAP_MASK       02h
		%define MEMORY_MODE    04h
		%define UNDERLINE_LOC  14h
		%define MODE_CONTROL   17h
		%define HIGH_ADDRESS   0ch
		%define LOW_ADDRESS    0dh
		%define LINE_OFFSET    13h
		%define PEL_PANNING    13h

		%define MAP_MASK       02h ;index in SC of Map Mask register
		%define BIT_MASK       08h ;index in GC of Bit Mask register
		
		%define CRTC_LINECOMPARE 24		
		%define CRTC_OVERFLOW     7
		%define CRTC_MAXSCANLINE  9
		
		%define AC_INDEX	    03c0h ; Attribute controller index register
		%define AC_MODE_CONTROL	  10h ; Index of Mode COntrol register in AC
		
		; http://www.scs.stanford.edu/17wi-cs140/pintos/specs/freevga/vga/graphreg.htm		
		%define READ_MAP_SELECT 04h ;index in GC
		
		%define KEY_LEFT  'K'
		%define KEY_RIGHT 'M'
		%define KEY_UP    'H'
		%define KEY_DOWN  'P'
		%define KEY_Z     ','
		%define KEY_X     '-'
		%define KEY_ESC    1
		
		bits 16
		cpu 8086
		org 100h
		
start:
		mov al, 13h
		call set_video_mode
		call set_video_mode_y
		call set_virtual_328
		
		mov si, terrain ; si = image address
		mov bx, 0 ; bx = start x		
		mov dx, 121 ; dx = start y		
		call draw_image	
		
	.next_pixel:	
		mov bx, [x] ; bx = x
		mov dx, [y] ; dx = y
		call get_pixel_2 ; cl = color

		mov bx, [x] ; bx = x
		mov dx, [y] ; dx = y
		sub dx, 100
		; mov cl, 5 ; cl = color
		call set_pixel
		
		inc word [x]
		
		cmp word [x], 328
		jb .next_pixel
		
		mov word [x], 0
		
		inc word [y]
		
		cmp word [y], 200
		jb .next_pixel

		mov ah, 0
		int 16h
		
	.exit:
		mov al, 3h
		call set_video_mode

		mov ah, 0eh
		mov al, cl
		add al, '0'
		int 10h

		mov ax, 4c00h
		int 21h		
		
		
; AL = video mode		
set_video_mode:
		mov ah, 0
		int 10h
		ret
		
; reference: http://www.brackeen.com/vga/source/bc31/modes.c.html		
set_video_mode_y:
		; turn off chain-4 mode 
		mov dx, SC_INDEX
		mov al, MEMORY_MODE
		out dx, al

		mov dx, SC_DATA
		mov al, 06h
		out dx, al

		; set map mask to all 4 planes for screen clearing 
		mov dx, SC_INDEX
		mov al, MAP_MASK
		out dx, al

		mov dx, SC_DATA
		mov al, 0ffh
		out dx, al

		; turn off long mode 
		mov dx, CRTC_INDEX
		mov al, UNDERLINE_LOC
		out dx, al

		mov dx, CRTC_DATA
		mov al, 0
		out dx, al

		; turn on byte mode 
		mov dx, CRTC_INDEX
		mov al, MODE_CONTROL
		out dx, al

		mov dx, CRTC_DATA
		mov al, 0e3h
		out dx, al

		mov dx, MISC_OUTPUT
		mov al, 0e3h
		out dx, al
		
		; clear all video memory
		mov bl, 0ffh
		call change_write_plane
		
		ret

	
; bl  = 1 2 4 8
; plane 0 1 2 3
change_write_plane:
		push bx
		push dx
		push ax
		mov dx, SC_INDEX
		mov al, MAP_MASK
		out dx, al
		mov dx, SC_DATA
		mov al, bl
		out dx, al
		pop ax
		pop dx
		pop bx
		ret

; bl  = 0 1 2 3 (plane)
change_read_plane:
		push bx
		push dx
		push ax
		mov dx, GC_INDEX
		mov al, READ_MAP_SELECT
		out dx, al
		mov dx, GC_DATA
		mov al, bl
        out dx, ax 
		pop ax
		pop dx
		pop bx
		ret

		
; root42 - https://github.com/root42/letscode-breakout/blob/master/vga.c		
; http://www.petesqbsite.com/sections/tutorials/tutorials/3scroll.htm
; this register holds the number of bytes (not pixels) difference between the start address of each row
set_virtual_328:
		mov dx, CRTC_INDEX
		mov al, LINE_OFFSET
		out dx, al
		mov dx, CRTC_DATA
		mov al, 328 / 8
		out dx, al
		ret


; bx = x
; dx = y
; cl = color
set_pixel:
		push ds
		mov ax, 0a000h
		mov ds, ax
		
		push dx
		push ax
		mov dx, GC_INDEX          ;set the bit mask to select all bits
        mov ax, 0ff00h + BIT_MASK ; from the latches and none from
        out dx, ax                ; the CPU, so that we can write the
		pop ax
		pop dx
		
		push cx
		push bx
		
		
		mov cl, bl
		and cl, 3
		mov ch, 1
		shl ch, cl
		
		mov bl, ch
		call change_write_plane
		
		pop bx
		pop cx

		mov ax, dx
		
		push cx
		
		mov cl, 6
		shl ax, cl ; 64
		
		add ax, dx ; 1
		add ax, dx ; 1
		
		mov cl, 4
		shl dx, cl
		add ax, dx ; 16
		
		mov cl, 2
		shr bx, cl
		add ax, bx
		
		pop cx
		
		mov bx, ax
		
		mov [bx], cl
		
		pop ds
		ret

; bx = x
; dx = y
; cl = color			
get_pixel:
		push ds
		mov ax, 0a000h
		mov ds, ax

		push cx
		push bx
		
		mov cl, bl
		and cl, 3
		;mov ch, 1
		;shl ch, cl ; ch plane 
		
		mov bl, cl
		call change_read_plane
		
		pop bx
		pop cx


		mov ax, dx
		
		push cx
		
		mov cl, 6
		shl ax, cl ; 64
		
		add ax, dx ; 1
		add ax, dx ; 1
		
		mov cl, 4
		shl dx, cl
		add ax, dx ; 16
		
		mov cl, 2
		shr bx, cl
		add ax, bx
		
		pop cx
		
		mov bx, ax
		
		mov cl, [bx]

		pop ds
		ret
		
; bx = x
; dx = y
; cl = color			
get_pixel_2:
		push ds
		mov ax, 0a000h
		mov ds, ax

		push cx
		push bx
		
		mov cl, bl
		and cl, 3
		;mov ch, 1
		;shl ch, cl ; ch plane 
		
		; mov bl, cl
		mov bl, 0 ; <- fixed to get always plane 0 for this test
		call change_read_plane
		
		pop bx
		pop cx


		mov ax, dx
		
		push cx
		
		mov cl, 6
		shl ax, cl ; 64
		
		add ax, dx ; 1
		add ax, dx ; 1
		
		mov cl, 4
		shl dx, cl
		add ax, dx ; 16
		
		mov cl, 2
		shr bx, cl
		add ax, bx
		
		pop cx
		
		mov bx, ax
		
		mov cl, [bx]

		pop ds
		ret
		
; si = image address
; bx = start x		
; dx = start y		
draw_image:		
		mov [img_start_x], bx
		mov [img_start_y], dx
		mov word [img_x], 0
		mov word [img_y], 0
		mov word [img_i], 0
		mov di, si
	.next_pixel:
		mov bx, [img_x] ; x
		mov dx, [img_y] ; y
		add bx, [img_start_x] ; x
		add dx, [img_start_y] ; y
		
		mov si, di
		add si, [img_i]
		mov cl, [si] ; pixel color
		call set_pixel
		
		inc word [img_i]
		
		inc word [img_x]
		mov bx, [di - 4] ; image width
		cmp  [img_x], bx
		jb .next_pixel
		
		mov word [img_x], 0
		inc word [img_y]
		mov dx, [di - 2] ; image height
		cmp [img_y], dx
		jb .next_pixel
		
		ret 

	
; --- keyboard ---


	install_key_handler:
			cli
			push es
			mov ax, 0
			mov es, ax
			mov ax, [es:4 * 9 + 2]
			mov [ds:int9_original_segment], ax
			mov ax, [es:4 * 9]
			mov [ds:int9_original_offset], ax
			mov ax, cs
			mov word [es:4 * 9 + 2], ax
			mov word [es:4 * 9], key_handler
			pop es
			sti
			ret

	uninstall_key_handler:
			push es
			mov ax, 0
			mov es, ax
			cli
			mov ax, [int9_original_offset]
			mov [es:4 * 9], ax
			mov ax, [int9_original_segment]
			mov [es:4 * 9 + 2], ax
			sti
			pop es
			ret

	; bl = code
	; al = 1 = true / 0 = false
	is_key_pressed:
			mov bh, 0
			mov al, [key_pressed + bx]
			mov ah, 0
			ret
			
	key_handler:
			push es
			push ax
			push bx
			
			mov ax, cs
			mov es, ax
			
			in al, 60h
			mov bh, al
			
			in    al, 061h       
			mov   bl, al
			or    al, 080h
			out   061h, al     
			mov   al, bl
			out   061h, al 
			
			mov al, bh
			cmp al, 0e0h
			jz .ignore
			mov ah, 0
			mov bx, ax
			and bl, 01111111b
			and al, 10000000b
			cmp al, 10000000b
			jz .key_released
		.key_pressed:
			mov byte [es:key_pressed + bx], 1
			jmp .ignore
		.key_released:
			mov byte [es:key_pressed + bx], 0
		.ignore:
			mov al, 20h
			out 20h, al
			pop bx
			pop ax
			pop es		
			iret                          

check_key:
		mov bl, KEY_ESC
		call is_key_pressed
		cmp al, 0
		ja start.exit

	.check_up:
		mov bl, KEY_UP
		call is_key_pressed
		cmp al, 0
		jz .check_down
	.up_pressed:
		sub word [y], 1

	.check_down:
		mov bl, KEY_DOWN
		call is_key_pressed
		cmp al, 0
		jz .check_left
	.down_pressed:
		add word [y], 1
	
	.check_left:
		mov bl, KEY_LEFT
		call is_key_pressed
		cmp al, 0
		jz .check_right
	.left_pressed:
		sub word [x], 1
		
	.check_right:
		mov bl, KEY_RIGHT
		call is_key_pressed
		cmp al, 0
		jz .check_key_end
	.right_pressed:
		add word [x], 1

	.check_key_end:
		ret

; --- data ---

int9_original_offset	dw 0
int9_original_segment	dw 0

key_pressed		times 256 db 0


x dw 0
y dw 0
		
; image file
img_start_x dw 0
img_start_y dw 0
img_x dw 0
img_y dw 0
img_i dw 0

terrain_vram_location equ 0
terrain_width dw 328
terrain_height dw 57
terrain:
		incbin "terrain.bmp", 54 + 1024 ; skip header and palette information		
		