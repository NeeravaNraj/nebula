use crate::common;
use crate::e9_print;
use core::{panic::PanicInfo};

#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    e9_print!("{}", info);
    common::halt();
}
