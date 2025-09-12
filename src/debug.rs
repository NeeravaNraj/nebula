#[macro_export]
macro_rules! e9_print {
    ($($fmt:tt)*) => ({
        #[cfg(target_arch = "x86_64")]
        {
            $crate::arch::x86_64::e9::_print(format_args!($($fmt)*));
        }
    });
}
