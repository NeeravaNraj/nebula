[bits 64]

global outb
global inb

outb:
    mov dx, di
    mov ax, si
    out dx, al
    ret

inb:
    mov dx, di
    in al, dx
    ret
