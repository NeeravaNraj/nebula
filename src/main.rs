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

    #[allow(unconditional_panic)]
    let a = 20 / 0;

    let x = 20;

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
