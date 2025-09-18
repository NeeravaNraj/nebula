use limine::{
    memory_map::{self, Entry}, paging::Mode, request::{
        ExecutableAddressRequest, FramebufferRequest, HhdmRequest, MemoryMapRequest, PagingModeRequest, RequestsEndMarker, RequestsStartMarker
    }, BaseRevision
};

use crate::{hal::{KernelAddress, PagingMode}, kernel::{kmain, KernelArgs}};

#[used]
#[unsafe(link_section = ".requests")]
pub static BASE_REVISION: BaseRevision = BaseRevision::new();

#[used]
#[unsafe(link_section = ".requests")]
pub static mut HHDM_REQUEST: HhdmRequest = HhdmRequest::new();

#[used]
#[unsafe(link_section = ".requests")]
pub static mut MEMORY_MAP_REQUEST: MemoryMapRequest = MemoryMapRequest::new();

#[used]
#[unsafe(link_section = ".requests")]
pub static mut KERNEL_ADDRESS_REQUEST: ExecutableAddressRequest = ExecutableAddressRequest::new();

#[used]
#[unsafe(link_section = ".requests")]
pub static mut FRAMEBUFFER_REQUEST: FramebufferRequest = FramebufferRequest::new();

#[used]
#[unsafe(link_section = ".requests")]
#[cfg(target_arch = "x86_64")]
pub static mut PAGING_REQUEST: PagingModeRequest = PagingModeRequest::new().with_mode(Mode::FIVE_LEVEL);

#[used]
#[unsafe(link_section = ".requests_start_marker")]
static _START_MARKER: RequestsStartMarker = RequestsStartMarker::new();

#[used]
#[unsafe(link_section = ".requests_end_marker")]
static _END_MARKER: RequestsEndMarker = RequestsEndMarker::new();

#[unsafe(no_mangle)]
extern "C" fn __boot_start() -> ! {
    assert!(BASE_REVISION.is_supported());
    unsafe {
        #[allow(static_mut_refs)]
        let Some(_fb) = FRAMEBUFFER_REQUEST.get_response_mut() else {
            panic!("Frame buffer not available")
        };

        #[allow(static_mut_refs)]
        let Some(hhdm_response) = HHDM_REQUEST.get_response_mut() else {
            panic!("HHDM request failed.")
        };

        #[allow(static_mut_refs)]
        let Some(kernel_addr_response) = KERNEL_ADDRESS_REQUEST.get_response_mut() else {
            panic!("Kernel address request failed.")
        };

        #[allow(static_mut_refs)]
        let Some(memory_map_response) = MEMORY_MAP_REQUEST.get_response_mut() else {
            panic!("Memory map request failed.")
        };

        #[allow(static_mut_refs)]
        #[cfg(target_arch = "x86_64")]
        let Some(paging_mode_response) = PAGING_REQUEST.get_response_mut() else {
            panic!("Paging mode request failed.")
        };

        let hhdm_offset = hhdm_response.offset();

        let kernel_address_virt = kernel_addr_response.virtual_base();
        let kernel_address_phys = kernel_addr_response.physical_base();
        let kernel_address = KernelAddress {
            virt: kernel_address_virt,
            phys: kernel_address_phys,
        };

        let memory_map = memory_map_response.entries();

        let paging_mode: PagingMode = paging_mode_response.mode().into();

        let args = KernelArgs {
            memory_map,
            hhdm_offset,
            paging_mode,
            kernel_address,
        };

        kmain(args);
    }
}

impl Into<PagingMode> for Mode {
    fn into(self) -> PagingMode {
        match self {
            Self::FIVE_LEVEL => PagingMode::FiveLevel,
            Self::FOUR_LEVEL => PagingMode::FourLevel,
            _ => panic!("Unknown paging mode")
        }
    }
}
