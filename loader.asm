;   ____  _                                _____ _     _____ 
;  / ___|| |_ _ __ __ _ _ __   __ _  ___  | .___| |   |  ___|
;  \___ \| __| '__/ _` | '_ \ / _` |/ _ \ |  _| | |   | |_   
;   ___) | |_| | | (_| | | | | (_| |  __/ | |___| |___|  _|  
;  |____/ \__|_|  \__,_|_| |_|\__, |\___| |_____|_____|_|    
;                             |___/       
;                                                    
;                 (@linuxthor - dc151 13/2/2019) 
;    First stage loader / OS detection that loads the second stage 
;                 on Linux in memory via a memfd 
;

BITS 64
osabi 0x09                     ; FreeBSD 

global _start
_start:
    mov  rax, 12               ; Haiku create_sem / BSD chdir / Linux brk 
    mov  rdi, tmp              
    mov  rsi, tmp
    syscall

    cmp  rax, 0xffff           ; Haiku will give a different value each time 
    jl   maybe_haiku           ; (e.g 0x1175)

                               ; If we're greater than 0xffff then Linux sys_brk()
                               ; returning current brk
linux:
    mov  rax, 319              ; memfd_create
    mov  rdi, memfdna          
    mov  rsi, 0
    syscall

    add [peffdee+14], rax      ; we don't hard code /proc/self/fd/3 as if we're
                               ; open in a debugger like GDB there may be extra
                               ; file descriptors open

    mov  rdi, rax
    mov  rax, 1                ; Linux sys_write
    mov  rsi, pload            ; Write second stage into memfd fd
    mov  rdx, ploadlen
    syscall

    mov rax,  59               ; Linux sys_execve
    mov rdi,  peffdee
    mov rsi,  0
    mov rdx,  0
    syscall

maybe_haiku:                   ; We're < 0xffff but are we > 1 ? 
    cmp  rax, 1                ; could be that chdir("/tmp") was successful 
    jl   bors                  ; so we're BSD or SunOS 

haiku:
    ;
    ; Haiku code
    ;
    mov  rax, 144              ; Haiku write
    mov  rdi, 1
    mov  rsi, 0
    mov  rdx, hmsg
    mov  r10, hmsglen
    syscall

    jmp  hexit

bors:
    ;
    ; SunOS code 
    ;
    mov rdi, sunz
    mov rax, 12                ; Can we chdir to /system ?  
    syscall                    ; which exists by default on SunOS but not BSD

    cmp rax,0
    jne bsd

sun:
    mov rdi, 1
    mov rsi, suns
    mov rdx, sunsb
    mov rax, 4
    syscall

    jmp bexit

    ;   
    ; BSD code
    ;
bsd:
    mov rdi, 1
    mov rsi, bsds
    mov rdx, bsdslen
    mov rax, 4               ; sys_write
    syscall

bexit:
    mov rdi, 69
    mov rax, 1               ; sys_exit for BSD and SunOS
    syscall

hexit:
    mov rdi, 0
    mov rax, 56             ; exit for Haiku
    syscall

section .data
    sunz db '/system',0
    tmp  db '/tmp',0
    suns:
    incbin   "inc/sunos.txt"
    sunsb    equ $-suns
    bsds:
    incbin   "inc/bsd.txt"
    bsdslen  equ $-bsds
    hmsg:
    incbin   "inc/haiku.txt"
    hmsglen  equ $-hmsg
    pload:
    incbin   "pload"         ; Second stage
    ploadlen equ $-pload
    memfdna  db 'blah',0
    peffdee  db '/proc/self/fd/0',0

section .note.openbsd.ident   
    align   2                 
    dd      8                    
    dd      4
    dd      1
    db      'OpenBSD',0 
    dd      0 
    align   2

section .note.netbsd.ident   
    dd      7,4,1           
    db      'NetBSD',0
    db      0
    dd      200000000

section .comment
    db      0,"GCC: (GNU) 4.2.0",0  ; Haiku 
