use crate::{common, hal::{self, HalArgs}};

pub struct KernelArgs {

}

pub fn kmain(_args: KernelArgs) -> ! {
    let hal_args = HalArgs {};
    hal::init(&hal_args);
    common::halt();
}
