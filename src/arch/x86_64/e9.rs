use core::fmt::{self, Arguments, Write};

unsafe extern "C" {
    pub fn outb(port: u16, c: u8);
}

static mut _E9: E9 = E9 {};

pub struct E9;

impl E9 {
    pub fn putc(c: u8) {
        unsafe { outb(0xE9, c) }
    }

    pub fn puts(s: &str) {
        for c in s.bytes() {
            Self::putc(c);
        }
    }
}

impl fmt::Write for E9 {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        E9::puts(s);
        Ok(())
    }
}

#[doc(hidden)]
pub fn _print(args: Arguments<'_>) {
    #[allow(static_mut_refs)]
    unsafe { 
        let _ = _E9.write_fmt(args);
        E9::putc(b'\n');
    }
}
