[bits 64]

global load_gdt
global reload_segments

; Args:
; rdi: gdt pointer
; rsi: code segment
; rdx: data segment
load_gdt:
    lgdt [rdi]

    mov rdi, rsi ; move code segment
    mov rsi, rdx ; move data segment
    call reload_segments

    ret

; Args:
; rdi: code segment
; rsi: data segment
reload_segments:
    mov ds, si
    mov es, si
    mov fs, si
    mov gs, si
    mov ss, si

    pop rdx ; pop return address

    push rdi ; push code segment
    push rdx ; restore return address

    retfq ; far jump to new code segment
