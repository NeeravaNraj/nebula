pub mod e9;
pub mod cpuid;

mod gdt;
mod idt;
mod isr;

use core::arch::asm;
use crate::hal::HalArgs;

pub fn init(_args: &HalArgs) {
    gdt::init();
    idt::init();
}

pub fn halt() -> ! {
    loop {
        unsafe {
            asm!("cli");
            asm!("hlt");
        }
    }
}
