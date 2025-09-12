[bits 64]

extern __boot_start
global __arch_start

__arch_start:
    xor rbp, rbp
    push rbp
    call __boot_start
    hlt
