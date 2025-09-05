use crate::serial_log_info;

mod gdt;

unsafe extern "C" {
    pub fn reload_segments(code: u16, data: u16);
}

pub fn init() {
    gdt::init();
    serial_log_info!("Initialized GDT");
}
