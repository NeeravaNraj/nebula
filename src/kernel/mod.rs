use limine::memory_map::Entry;

use crate::{common, hal::{self, HalArgs, KernelAddress, PagingMode}};

pub struct KernelArgs {
    pub hhdm_offset: u64,
    pub paging_mode: PagingMode,
    pub kernel_address: KernelAddress,
    pub memory_map: &'static [&'static Entry],
}

pub fn kmain(_args: KernelArgs) -> ! {
    let hal_args = HalArgs {};
    hal::init(&hal_args);
    common::halt();
}
