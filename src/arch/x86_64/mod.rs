mod gdt;
mod idt;
mod isr;

use crate::serial_log_debug;

pub fn init() {
    gdt::init();
    serial_log_debug!("Initialized GDT");
    idt::init();
    serial_log_debug!("Initialized IDT");
}
