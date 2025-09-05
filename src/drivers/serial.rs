use spin::Mutex;
use lazy_static::lazy_static;
use crate::logger::{LogLevels, Logger};
use core::{arch::asm, fmt::{self, Arguments}};


lazy_static! {
    pub static ref COM1: Mutex<Serial> = Mutex::new(Serial::new(0x3F8).init().unwrap());
}

pub struct Serial {
    port: u16,
}

#[allow(unused)]
impl Serial {
    pub fn new(port: u16) -> Self {
        Self { port }
    }

    pub fn init(self) -> Result<Self, ()> {
        outb(self.port + 1, 0x00); // Disable all interrupts
        outb(self.port + 3, 0x80); // Enable DLAB (set baud rate divisor)
        outb(self.port + 0, 0x03); // Set divisor to 3 (lo byte) 38400 baud
        outb(self.port + 1, 0x00); // (hi byte)
        outb(self.port + 3, 0x03); // Initialize 8N1 (8 bits data, no parity, one stop bit)
        outb(self.port + 2, 0xC7); // Enable FIFO, clear them, with 14-byte threshold
        outb(self.port + 4, 0x0B); // IRQs enabled, RTS/DSR set
        outb(self.port + 4, 0x1E); // Set in loopback mode, test the serial chip
        outb(self.port + 0, 0xAE); // Test serial chip (send byte 0xAE and check if serial returns same byte)

        // Check if serial is faulty
        if inb(self.port) != 0xAE { return Err(()); }

        outb(self.port + 4, 0x0F);

        Ok(self)
    }

    pub fn write_string(&self, s: &str) {
        for b in s.bytes() {
            self.write_serial(b);
        }
    }

    pub fn read_serial(&self) -> u8 {
        while self.serial_received() == 0 {}

        inb(self.port)
    }

    pub fn write_serial(&self, c: u8) {
        while self.is_transmit_empty() == 0 {}

        outb(self.port, c);
    }

    fn is_transmit_empty(&self) -> u8 {
        inb(self.port + 5) & 0x20
    }

    fn serial_received(&self) -> u8 {
        inb(self.port + 5) & 1
    }
}

pub fn outb(port: u16, val: u8) {
    unsafe {
        asm!("out dx, al", in("dx") port, in("al") val);
    }
}

pub fn inb(port: u16) -> u8 {
    let ret: u8;

    unsafe {
        asm!("in al, dx", in("dx") port, out("al") ret);
    }

    ret
}

impl Logger for Serial {
    fn log(&mut self, level: crate::logger::LogLevels, args: Arguments<'_>) {
        use fmt::Write;
        self.write_string(level.as_str());
        self.write_string(": ");
        self.write_fmt(args).unwrap();
        self.write_serial(b'\n');
    }
}

impl fmt::Write for Serial {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        self.write_string(s);
        Ok(())
    }
}

#[macro_export]
macro_rules! serial_log_info {
    ($($fmt:tt)*) => ({
        $crate::drivers::serial::_log($crate::logger::LogLevels::Info, format_args!($($fmt)*));
    });
}

#[macro_export]
macro_rules! serial_log_warn {
    ($($fmt:tt)*) => ({
        $crate::drivers::serial::_log($crate::logger::LogLevels::Warn, format_args!($($fmt)*));
    });
}

#[macro_export]
macro_rules! serial_log_error {
    ($($fmt:tt)*) => ({
        $crate::drivers::serial::_log($crate::logger::LogLevels::Error, format_args!($($fmt)*));
    });
}

#[macro_export]
macro_rules! serial_log_fatal {
    ($($fmt:tt)*) => ({
        $crate::drivers::serial::_log($crate::logger::LogLevels::Fatal, format_args!($($fmt)*));
    });
}

#[macro_export]
macro_rules! serial_log_debug {
    ($($fmt:tt)*) => ({
        $crate::drivers::serial::_log($crate::logger::LogLevels::Debug, format_args!($($fmt)*));
    });
}

#[doc(hidden)]
pub fn _log(level: LogLevels, args: Arguments<'_>) {
    COM1.lock().log(level, args);
}
