use core::fmt::Arguments;

#[allow(unused)]
pub enum LogLevels {
    Info,
    Warn,
    Error,
    Fatal,
    Debug,
}

impl LogLevels {
    pub fn as_str(&self) -> &str {
        match self {
            LogLevels::Info => "info",
            LogLevels::Warn => "warn",
            LogLevels::Error => "error",
            LogLevels::Fatal => "fatal",
            LogLevels::Debug => "debug",
        }
    }
}

pub trait Logger {
    fn log(&mut self, level: LogLevels, args: Arguments<'_>);
}
