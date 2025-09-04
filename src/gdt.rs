use core::arch::asm;

use crate::{serial::Serial, serial_log_info};


static mut GDT: [u8; 48] = [0; 48];

#[repr(C, packed)]
struct Gdtr {
    base: u64,
    limit: u16
}

#[allow(unused)]
#[repr(u8)]
pub enum Segements {
    KernelCode = 1,
    KernelData = 2,

    UserCode   = 3,
    UserData   = 4,

    Tss        = 5,
}

#[allow(unused)]
#[derive(Clone, Copy)]
#[repr(u8)]
pub enum PrivilegeLevel {
    Ring0,
    Ring1,
    Ring2,
    Ring3,
}

pub struct GDTEntry {
    limit: u32,
    base: u32,
    access: u8,
    flags: u8,
}

impl GDTEntry {
    fn new(limit: u32, base: u32, access: u8, flags: u8) -> Self {
        Self { limit, base, access, flags }
    }

    fn null() -> Self {
        Self { limit: 0, base: 0, access: 0, flags: 0 }
    }

    fn encode(&self, target: *mut u8) {
        assert!(self.limit <= 0xFFFFF, "limit cannot exceed 0xFFFFF");
        unsafe {
            // Encode limit
            *target.offset(0) = (self.limit & 0xFF) as u8;
            *target.offset(1) = ((self.limit >> 8) & 0xFF) as u8;
            *target.offset(6) = ((self.limit >> 16) & 0x0F) as u8;

            // Encode base
            *target.offset(2) = (self.base & 0xFF) as u8;
            *target.offset(3) = ((self.base >> 8) & 0xFF) as u8;
            *target.offset(4) = ((self.base >> 16) & 0xFF) as u8;
            *target.offset(7) = ((self.base >> 24) & 0xFF) as u8;

            // Encode access byte
            *target.offset(5) = self.access;

            // Encode flags
            *target.offset(6) |= (self.flags & 0xF) << 4;
        }
    }
}

pub fn init(serial: &mut Serial) {
    let null = GDTEntry::null();
    let kernel_code = GDTEntry::new(0xFFFFF, 0, 0x9A, 0xA);
    let kernel_data = GDTEntry::new(0xFFFFF, 0, 0x92, 0xC);

    let user_code = GDTEntry::new(0xFFFFF, 0, 0xFA, 0xA);
    let user_data = GDTEntry::new(0xFFFFF, 0, 0xF2, 0xC);

    unsafe {
        // Populate GDT
        #[allow(static_mut_refs)]
        let gdt = GDT.as_mut_ptr();
        null.encode(gdt.offset(0));

        kernel_code.encode(gdt.offset(8));
        kernel_data.encode(gdt.offset(16));

        user_code.encode(gdt.offset(24));
        user_data.encode(gdt.offset(32));
        serial_log_info!(serial, "Load entries");

        // Load GDT
        #[allow(static_mut_refs)]
        let gdtr = Gdtr { 
            base: gdt as u64,
            limit: (GDT.len() - 1) as u16
        };
        load_gdt(&gdtr);
        serial_log_info!(serial, "Load GDTR");

        reload_segments(Segements::KernelCode, Segements::KernelData, PrivilegeLevel::Ring0);
        serial_log_info!(serial, "Reload segments");
    }
}

fn load_gdt(gdtr: &Gdtr) {
    unsafe {
        asm!(
            "CLI",
            "LGDT [{}]",
            in (reg) gdtr,
            options(readonly, nostack, preserves_flags)
        )
    }
}

fn reload_segments(code: Segements, data: Segements, privilege: PrivilegeLevel) {
    unsafe {
        let code_selector = encode_select(code, privilege);
        let data_selector = encode_select(data, privilege);
        asm!(
            "push {code_selector}",
            "lea rax, [rip + 2f]",
            "push rax",
            "retfq",
            "2:",
            code_selector = in(reg) code_selector as u64,
            out("rax") _,
            options(preserves_flags)
        );

        asm!(
            "mov ds, dx",
            "mov ss, dx",
            "mov es, dx",
            "mov fs, dx",
            "mov gs, dx",
            in("dx") data_selector as u16,
            out("rax") _,
            options(preserves_flags)
        );
    }
}

fn encode_select(segment: Segements, privilege: PrivilegeLevel) -> usize {
    ((segment as usize) << 3 | privilege as usize) | 0
}
