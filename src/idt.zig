const IdtEntry = packed struct {
    offset_1: u16,
    selector: u16,
    ist: u3,
    reserved: u5 = 0,
    gate_type: u4,
    zero: u1 = 0,
    dpl: u2,
    preset: u1,
    offset_2: u16,
    offset_3: u32,
    reserved_2: u32 = 0,
};

const IdtPtr = packed struct {
    size: u16,
    offset: u64,
};
