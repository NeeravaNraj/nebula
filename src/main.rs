#![no_std]
#![no_main]

mod gdt;
mod serial;
mod logger;
use crate::{serial::{Serial, COM1}};
use core::{arch::asm, panic::PanicInfo};
use limine::{
    BaseRevision,
    request::{FramebufferRequest, RequestsEndMarker, RequestsStartMarker},
};


#[used]
#[unsafe(link_section = ".requests")]
static BASE_REVISION: BaseRevision = BaseRevision::new();

#[used]
#[unsafe(link_section = ".requests")]
static FRAMEBUFFER_REQUEST: FramebufferRequest = FramebufferRequest::new();

#[used]
#[unsafe(link_section = ".requests_start_marker")]
static _START_MARKER: RequestsStartMarker = RequestsStartMarker::new();

#[used]
#[unsafe(link_section = ".requests_end_marker")]
static _END_MARKER: RequestsEndMarker = RequestsEndMarker::new();

#[unsafe(no_mangle)]
pub extern "C" fn kmain() -> ! {
    assert!(BASE_REVISION.is_supported());

    let mut serial = Serial::new(COM1);
    serial.init().unwrap();
    serial_log_info!(serial, "Initialized serial port at - {:#02x}", COM1);
    gdt::init(&mut serial);
    serial_log_info!(serial, "Initialized GDT");
    
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
