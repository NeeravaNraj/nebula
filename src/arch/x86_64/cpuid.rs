unsafe extern "C" {
    pub fn check_cpuid() -> u32;
    pub fn query_cpuid(eax: u32, ecx: u32) -> CpuIdResult;
}

#[repr(C, packed)] 
pub struct CpuIdResult {
    pub eax: u32,
    pub ebx: u32,
    pub ecx: u32,
    pub edx: u32,
}

impl Into<&str> for CpuIdResult {
    fn into(self) -> &'static str {
        static mut BUF: [u8; 13] = [0; 13];

        unsafe {
            BUF[0..4].copy_from_slice(&self.ebx.to_le_bytes());
            BUF[4..8].copy_from_slice(&self.edx.to_le_bytes());
            BUF[8..12].copy_from_slice(&self.ecx.to_le_bytes());
            BUF[12] = 0;
            match str::from_utf8(&BUF[..12]) {
                Ok(s) => s,
                Err(_) => "INVALID"
            }
        }
    }
}

#[allow(unused)]
#[repr(u32)]
pub enum EcxFeatures {
    Sse3         = 1 << 0,
    Pclmul       = 1 << 1,
    Dtes64       = 1 << 2,
    Monitor      = 1 << 3,
    DsCpl        = 1 << 4,
    Vmx          = 1 << 5,
    Smx          = 1 << 6,
    Est          = 1 << 7,
    Tm2          = 1 << 8,
    Ssse3        = 1 << 9,
    Cid          = 1 << 10,
    Sdbg         = 1 << 11,
    Fma          = 1 << 12,
    Cx16         = 1 << 13,
    Xtpr         = 1 << 14,
    Pdcm         = 1 << 15,
    Pcid         = 1 << 17,
    Dca          = 1 << 18,
    Sse4_1       = 1 << 19,
    Sse4_2       = 1 << 20,
    X2apic       = 1 << 21,
    Movbe        = 1 << 22,
    Popcnt       = 1 << 23,
    Tsc          = 1 << 24,
    Aes          = 1 << 25,
    Xsave        = 1 << 26,
    Osxsave      = 1 << 27,
    Avx          = 1 << 28,
    F16c         = 1 << 29,
    Rdrand       = 1 << 30,
    Hypervisor   = 1 << 31,
}

#[allow(unused)]
#[repr(u32)]
pub enum EdxFeatures {
    Fpu          = 1 << 0,
    Vme          = 1 << 1,
    De           = 1 << 2,
    Pse          = 1 << 3,
    Tsc          = 1 << 4,
    Msr          = 1 << 5,
    Pae          = 1 << 6,
    Mce          = 1 << 7,
    Cx8          = 1 << 8,
    Apic         = 1 << 9,
    Sep          = 1 << 11,
    Mtrr         = 1 << 12,
    Pge          = 1 << 13,
    Mca          = 1 << 14,
    Cmov         = 1 << 15,
    Pat          = 1 << 16,
    Pse36        = 1 << 17,
    Psn          = 1 << 18,
    Clflush      = 1 << 19,
    Ds           = 1 << 21,
    Acpi         = 1 << 22,
    Mmx          = 1 << 23,
    Fxsr         = 1 << 24,
    Sse          = 1 << 25,
    Sse2         = 1 << 26,
    Ss           = 1 << 27,
    Htt          = 1 << 28,
    Tm           = 1 << 29,
    Ia64         = 1 << 30,
    Pbe          = 1 << 31
}
