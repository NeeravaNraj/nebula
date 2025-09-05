#![no_std]
#![no_main]

mod arch;
mod boot;
mod logger;
mod drivers;
use core::{arch::asm, panic::PanicInfo};

#[unsafe(no_mangle)]
pub extern "C" fn kmain() -> ! {
    boot::verify();
    arch::x86_64::init();

    loop {}
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {
        unsafe {
            asm!("hlt");
        }
    }
}
