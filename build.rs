fn main() {
    let mut cc = cc::Build::new();

    cc.file("src/arch/x86_64/utils.s").compile("x86_64-utils");
}
