use crate::arch;

#[cfg(target_arch = "x86_64")]
pub fn halt() -> ! {
    arch::x86_64::halt();
}
