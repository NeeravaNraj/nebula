[bits 64]

global _check_cpuid
global _query_cpuid

; Returns whether cpuid is available
_check_cpuid:
    pushfq                          ; Save EFLAGS
    pushfq                          ; Store EFLAGS
    xor QWORD [rsp], 0x00200000     ; Invert the ID bit in stored EFLAGS
    popfq                           ; Load stored EFLAGS
    pushfq
    pop rax
    xor rax, [rsp]                  ; EAX = modified EFLAGS
    popfq
    and rax, 0x00200000             ; Check if changed
    ret

_query_cpuid:
    push rbp
    mov rbp, rsp

    push rbx

    xor rax, rax
    xor rcx, rcx

    mov eax, edi
    mov ecx, esi
    cpuid

    shl rbx, 32
    or rax, rbx

    shl rdx, 32
    or rdx, rcx

    pop rbx
    
    mov rsp, rbp
    pop rbp

    ret
