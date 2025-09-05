.intel_syntax noprefix

.global reload_segments

reload_segments:
    push rdi
    lea rax, [rel .reload_data]
    push rax
    retfq

.reload_data:
    mov ds, si
    mov es, si
    mov fs, si
    mov gs, si
    mov ss, si
    ret
