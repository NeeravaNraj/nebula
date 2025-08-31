use core::arch::asm;


pub struct Serial;

impl Serial {
    pub const COM1: u16 = 0x3F8;

    pub fn init() -> Option<Self> {
        outb(Serial::COM1 + 1, 0x00); // Disable all interrupts
        outb(Serial::COM1 + 3, 0x80); // Enable DLAB (set baud rate divisor)
        outb(Serial::COM1 + 0, 0x03); // Set divisor to 3 (lo byte) 38400 baud
        outb(Serial::COM1 + 1, 0x00); // (hi byte)
        outb(Serial::COM1 + 3, 0x03); // Initialize 8N1 (8 bits data, no parity, one stop bit)
        outb(Serial::COM1 + 2, 0xC7); // Enable FIFO, clear them, with 14-byte threshold
        outb(Serial::COM1 + 4, 0x0B); // IRQs enabled, RTS/DSR set
        outb(Serial::COM1 + 4, 0x1E); // Set in loopback mode, test the serial chip
        outb(Serial::COM1 + 0, 0xAE); // Test serial chip (send byte 0xAE and check if serial returns same byte)

        // Check if serial is faulty
        if inb(Serial::COM1) != 0xAE {
            return None;
        }

        outb(Serial::COM1 + 4, 0x0F);

        Some(Self {})
    }

    pub fn write_string(&self, s: &str) {
        for b in s.bytes() {
            self.write_serial(b);
        }
    }

    pub fn read_serial(&self) -> u8 {
        while self.serial_received() == 0 {}

        inb(Serial::COM1)
    }

    pub fn write_serial(&self, c: u8) {
        while self.is_transmit_empty() == 0 {}

        outb(Serial::COM1, c);
    }

    fn is_transmit_empty(&self) -> u8 {
        inb(Serial::COM1 + 5) & 0x20
    }

    fn serial_received(&self) -> u8 {
        inb(Serial::COM1 + 5) & 1
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
