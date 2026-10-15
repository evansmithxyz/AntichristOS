; Hellforge stage1.asm -- NASM port of TempleOS BDVD_START..BDVD_END
; (::/Adam/Opt/Boot/BootDVD.HC), the El Torito "no emulation" CD boot loader.
;
; The BIOS loads this (4 virtual 512-byte sectors = one 2048-byte DVD block,
; load_rba 21) at 0000:7C00 and jumps to it with DL = BIOS drive number.
; It relocates itself to BOOT_HIGH_LOC_DVD:0000, prints the boot message,
; reads the kernel (by 2048-byte DVD blocks via INT 13h AH=42h) to 0x7C00,
; shifts it backwards by SHIFT_BLKS*512 bytes to align, and jumps to 07C0:0000
; with EBX = first DVD block and EAX = (shift<<16) | BOOT_SRC_DVD,
; exactly as KStart16.HC expects.
;
; Build-time parameters (all optional, pass with nasm -D):
;   BOOT_MSG_BYTES   comma-separated byte list of the boot message
;                    (default "Loading TempleOS")
;   NOT64_MSG_BYTES  comma-separated byte list of the not-64-bit message
;   MAPFILE          file name of a NASM symbol map to emit (used by mkiso.py
;                    to locate the patch fields BDVD_BLK_LO etc.).  NASM ends
;                    the name at the first blank and keeps quotes literally,
;                    so mkiso runs NASM in its temp dir with a bare name.
;
; Patch fields (filled by mkiso.py like RedSeaISO9660Stage1() does):
;   BDVD_BLK_LO   U32 (LO+HI)  = kernel de.clus>>2  (DVD block)
;   BDVD_BLK_CNT  U16          = ceil(size/2048) (+1 if shift)
;   BDVD_SHIFT_BLKS U16        = de.clus & 3

%ifdef MAPFILE
[map symbols MAPFILE]
%endif

BLK_SIZE_BITS        equ 9
BLK_SIZE             equ (1<<BLK_SIZE_BITS)
DVD_BLK_SIZE         equ (4*BLK_SIZE)
DVD_BOOT_LOADER_SIZE equ DVD_BLK_SIZE
BOOT_RAM_BASE        equ 0x07C00
BOOT_RAM_LIMIT       equ 0x97000
BOOT_STK_SIZE        equ BLK_SIZE
BOOT_SRC_DVD         equ 4
BOOT_HIGH_LOC_DVD    equ ((BOOT_RAM_LIMIT-(BOOT_STK_SIZE+DVD_BOOT_LOADER_SIZE))>>4)

        bits 16
        org 0

BDVD_START:
;DL is supposed to have the BIOS drive number
        cld
        mov     ax,BOOT_HIGH_LOC_DVD
        mov     es,ax

        cli
        mov     ss,ax
        mov     sp,BOOT_STK_SIZE+DVD_BOOT_LOADER_SIZE
        sti

        call    BDVD_GET_RIP
BDVD_GET_RIP:
        pop     bx
        sub     bx,BDVD_GET_RIP-BDVD_START
        shr     bx,4
;This copies this bootloader's code to BOOT_HIGH_LOC_DVD<<4 (0x96600)
        mov     ax,cs
        add     ax,bx
        mov     ds,ax
        mov     cx,DVD_BOOT_LOADER_SIZE
        xor     si,si
        xor     di,di
        rep movsb

        mov     ax,BOOT_HIGH_LOC_DVD
        mov     ds,ax

        jmp     BOOT_HIGH_LOC_DVD:(BDVD_MAIN-BDVD_START)

BDVD_BIOS_DRV_NUM:      db 0
BDVD_PAGE:              db 0

BDVD_DAP:               db 16,0,1,0     ;One blk at a time
BDVD_DAP_BUF:           dw 0,0
BDVD_DAP_BLK:           dq 0

BDVD_TEMPLEOS_MSG:
%ifdef BOOT_MSG_BYTES
        db      BOOT_MSG_BYTES
%else
        db      "Loading TempleOS"
%endif
        db      0

BDVD_NOT64_MSG:
%ifdef NOT64_MSG_BYTES
        db      NOT64_MSG_BYTES
%else
        db      "TempleOS requires a 64-bit capable processor.",10,13
%endif
        db      0

;These get patched.
BDVD_BLK_LO:            dw 0
BDVD_BLK_HI:            dw 0
BDVD_BLK_CNT:           dw 0
BDVD_SHIFT_BLKS:        dw 0
BDVD_PROGRESS_STEP:     dd 0
BDVD_PROGRESS_VAL:      dd 0

BDVD_PUT_CHAR:
        mov     ah,0x0E
        mov     bl,7            ;Might be foreground color on some BIOS's
        mov     bh,[BDVD_PAGE-BDVD_START]
        int     0x10
BDVD_RET:
        ret
BDVD_PUTS:
.l1:    lodsb
        test    al,al
        jz      BDVD_RET
        call    BDVD_PUT_CHAR
        jmp     .l1

BDVD_MAIN:
        mov     [BDVD_BIOS_DRV_NUM-BDVD_START],dl  ;Passed in by BIOS

        mov     ah,0x0F
        int     0x10
        mov     [BDVD_PAGE-BDVD_START],bh          ;Video page

        mov     eax,0x80000000
        cpuid
        cmp     eax,0x80000001
        jb      .l05

        mov     eax,0x80000001
        cpuid
        bt      edx,29
        jc      .l15
.l05:   mov     si,BDVD_NOT64_MSG-BDVD_START
        call    BDVD_PUTS
.l10:   jmp     .l10

.l15:   mov     si,BDVD_TEMPLEOS_MSG-BDVD_START
        call    BDVD_PUTS

        mov     ax,BOOT_RAM_BASE/16
        mov     es,ax
        xor     ecx,ecx
        mov     cx,[BDVD_BLK_CNT-BDVD_START]

        mov     eax,(80-7-9)*65536      ;80 columns
        xor     edx,edx
        div     ecx
        mov     [BDVD_PROGRESS_STEP-BDVD_START],eax
        mov     dword [BDVD_PROGRESS_VAL-BDVD_START],0

        mov     ax,[BDVD_BLK_LO-BDVD_START]
        mov     dx,[BDVD_BLK_HI-BDVD_START]

.l20:   push    cx              ;Blk cnt

;READ BLK
        push    ax              ;Blk lo
        push    dx              ;Blk hi
        push    es              ;Buf seg
        mov     [BDVD_DAP_BLK-BDVD_START],ax
        mov     [BDVD_DAP_BLK+2-BDVD_START],dx
        mov     ax,es
        mov     [BDVD_DAP_BUF+2-BDVD_START],ax     ;ES:0000
        mov     si,BDVD_DAP-BDVD_START             ;DS:SI=DAP
        mov     ah,0x42
        mov     dl,[BDVD_BIOS_DRV_NUM-BDVD_START]
        int     0x13

        pop     ax              ;ES
        add     ax,DVD_BLK_SIZE/16
        mov     es,ax
        pop     dx
        pop     ax
        inc     ax
        jnz     .l25
        inc     dx

.l25:   push    ax
        mov     bx,[BDVD_PROGRESS_VAL+2-BDVD_START]
        mov     eax,[BDVD_PROGRESS_STEP-BDVD_START]
        add     [BDVD_PROGRESS_VAL-BDVD_START],eax
        cmp     [BDVD_PROGRESS_VAL+2-BDVD_START],bx
        je      .l30
        mov     al,'.'
        call    BDVD_PUT_CHAR
.l30:   pop     ax

        pop     cx
        loop    .l20

;Shift backward to align
        push    ds
        mov     bx,[BDVD_SHIFT_BLKS-BDVD_START]
        shl     bx,BLK_SIZE_BITS-4
        mov     cx,[BDVD_BLK_CNT-BDVD_START]
        mov     ax,BOOT_RAM_BASE/16
        mov     es,ax
        add     ax,bx
        mov     ds,ax
.l35:   push    cx
        xor     si,si
        xor     di,di
        mov     cx,DVD_BLK_SIZE/4
        rep movsd
        mov     ax,ds
        add     ax,DVD_BLK_SIZE/16
        mov     ds,ax
        mov     ax,es
        add     ax,DVD_BLK_SIZE/16
        mov     es,ax
        pop     cx
        loop    .l35
        pop     ds

;See BootDVDProbe().
        mov     ebx,[BDVD_BLK_LO-BDVD_START]
        mov     ax,[BDVD_SHIFT_BLKS-BDVD_START]
        shl     eax,16
        mov     ax,BOOT_SRC_DVD

        jmp     (BOOT_RAM_BASE/16):0000
;Continues in ::/Kernel/KStart16.HC
BDVD_END:

;Assert size < DVD_BOOT_LOADER_SIZE (TIMES goes negative -> error otherwise).
        times   0-((BDVD_END-BDVD_START) >= DVD_BOOT_LOADER_SIZE) db 0
