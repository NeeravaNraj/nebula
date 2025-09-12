use crate::arch;

pub struct HalArgs {
}

pub fn init(args: &HalArgs) {
    #[cfg(target_arch = "x86_64")]
    arch::x86_64::init(args);
}
