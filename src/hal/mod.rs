use crate::{arch, e9_print};

pub struct HalArgs {
}

pub fn init(args: &HalArgs) {
    #[cfg(target_arch = "x86_64")]
    arch::x86_64::init(args);

    let result = unsafe { arch::x86_64::cpuid::query_cpuid(0, 0) };
    let result: &str = result.into();
    e9_print!("{}", result);
}
