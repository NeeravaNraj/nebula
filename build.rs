fn main() {
    println!("cargo:warning=Build script is running!");
    
    let files = &[
        "src/arch/x86_64/asm/gdt.asm",
        "src/arch/x86_64/asm/idt.asm",
        "src/arch/x86_64/asm/isrs.asm",
    ];

    let args = &["-felf64"];
    nasm_rs::compile_library_args("x86-64-asm", files, args).expect("assembler failure");

    println!("cargo:rustc-link-lib=static=x86-64-asm");
    println!("cargo:rerun-if-changed=src/arch/x86_64/asm");
    println!("cargo:warning=Build script completed successfully!");
}
