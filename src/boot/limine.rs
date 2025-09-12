use limine::{
    BaseRevision,
    request::{FramebufferRequest, RequestsEndMarker, RequestsStartMarker},
};

use crate::{kernel::{kmain, KernelArgs}};

#[used]
#[unsafe(link_section = ".requests")]
pub static BASE_REVISION: BaseRevision = BaseRevision::new();

#[used]
#[unsafe(link_section = ".requests")]
pub static mut FRAMEBUFFER_REQUEST: FramebufferRequest = FramebufferRequest::new();

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

        let args = KernelArgs {};

        kmain(args);
    }
}
