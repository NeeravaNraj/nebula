const GdtPtr = struct {
    limit: u16,
    base: u64,
};

const gdt_ptr: *GdtPtr = undefined;

fn read_gdt_ptr() callconv(.C) void {
    asm volatile (
        \\ MOV RAX, GDTR
        \\ MOV [gdt_ptr], RAX
    );
}
