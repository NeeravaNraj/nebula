mod limine;

pub fn verify() {
    assert!(limine::BASE_REVISION.is_supported());
}
