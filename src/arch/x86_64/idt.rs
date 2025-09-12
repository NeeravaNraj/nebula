use core::{u128, u64, mem};
use crate::{arch::x86_64::{gdt::GdtSelectors, isr}, e9_print};

unsafe extern "C" {
    fn load_idt(idtr: *const Idtr);
}

static mut IDT: [u128; 256] = [0; 256];

#[allow(unused)]
#[repr(u8)]
enum GateTypeAttributes {
    Interrupt = 0x8E,
    Trap      = 0x8F,
}

#[repr(C, packed)]
struct Idtr {
    limit: u16,
    base: u64,
}

#[derive(Default)]
#[repr(C, packed)]
struct GateDescriptor {
    offset_1:           u16,
    selector:           u16,
    ist:                u8,
    type_attributes:    u8,
    offset_2:           u16,
    offset_3:           u32,
    reserved:           u32,
}

impl GateDescriptor {
    fn new(offset: u64, selector: u16, ist: u8, type_attributes: GateTypeAttributes) -> Self {
        let offset_1 = (offset & 0xFFFF) as u16;
        let offset_2 = ((offset >> 16) & 0xFFFF) as u16;
        let offset_3 = ((offset >> 32) & 0xFFFFFFFF) as u32;
        let type_attributes = type_attributes as u8;

        Self { offset_1, offset_2, offset_3, ist, selector, type_attributes, reserved: 0 }
    }
}

impl Into<u128> for GateDescriptor {
    fn into(self) -> u128 {
        assert_eq!(mem::size_of::<GateDescriptor>(), 16);
        unsafe { mem::transmute(self) }
    }
}

macro_rules! add_entry {
    ($value:expr, $isr:expr) => {
        {
            let isr_offset = ($isr as u64);
            let selector = GdtSelectors::KernelCode as u16;
            let type_attributes = GateTypeAttributes::Interrupt;
            let gate_descriptor = GateDescriptor::new(isr_offset, selector, 0, type_attributes);
            IDT[$value] = gate_descriptor.into();
        }
    };
}

pub fn init() {
    unsafe  {
        #[allow(static_mut_refs)]
        let idt = IDT.as_mut_ptr();

        #[allow(static_mut_refs)]
        let idtr = Idtr {
            limit: (IDT.len() * 16 - 1) as u16,
            base: idt as u64,
        };
        load_entries();
        load_idt(&idtr);
    }
    e9_print!("Initialized IDT");
}

pub fn load_entries() {
    unsafe {
        add_entry!(0, isr::isr_0);
        add_entry!(1, isr::isr_1);
        add_entry!(2, isr::isr_2);
        add_entry!(3, isr::isr_3);
        add_entry!(4, isr::isr_4);
        add_entry!(5, isr::isr_5);
        add_entry!(6, isr::isr_6);
        add_entry!(7, isr::isr_7);
        add_entry!(8, isr::isr_8);
        add_entry!(9, isr::isr_9);
        add_entry!(10, isr::isr_10);
        add_entry!(11, isr::isr_11);
        add_entry!(12, isr::isr_12);
        add_entry!(13, isr::isr_13);
        add_entry!(14, isr::isr_14);

        add_entry!(16, isr::isr_16);
        add_entry!(17, isr::isr_17);
        add_entry!(18, isr::isr_18);
        add_entry!(19, isr::isr_19);
        add_entry!(20, isr::isr_20);

        add_entry!(32, isr::isr_32);
        add_entry!(33, isr::isr_33);
        add_entry!(34, isr::isr_34);
        add_entry!(35, isr::isr_35);
        add_entry!(36, isr::isr_36);
        add_entry!(37, isr::isr_37);
        add_entry!(38, isr::isr_38);
        add_entry!(39, isr::isr_39);
        add_entry!(40, isr::isr_40);
        add_entry!(41, isr::isr_41);
        add_entry!(42, isr::isr_42);
        add_entry!(43, isr::isr_43);
        add_entry!(44, isr::isr_44);
        add_entry!(45, isr::isr_45);
        add_entry!(46, isr::isr_46);
        add_entry!(47, isr::isr_47);
        add_entry!(48, isr::isr_48);
        add_entry!(49, isr::isr_49);
        add_entry!(50, isr::isr_50);
        add_entry!(51, isr::isr_51);
        add_entry!(52, isr::isr_52);
        add_entry!(53, isr::isr_53);
        add_entry!(54, isr::isr_54);
        add_entry!(55, isr::isr_55);
        add_entry!(56, isr::isr_56);
        add_entry!(57, isr::isr_57);
        add_entry!(58, isr::isr_58);
        add_entry!(59, isr::isr_59);
        add_entry!(60, isr::isr_60);
        add_entry!(61, isr::isr_61);
        add_entry!(62, isr::isr_62);
        add_entry!(63, isr::isr_63);
        add_entry!(64, isr::isr_64);
        add_entry!(65, isr::isr_65);
        add_entry!(66, isr::isr_66);
        add_entry!(67, isr::isr_67);
        add_entry!(68, isr::isr_68);
        add_entry!(69, isr::isr_69);
        add_entry!(70, isr::isr_70);
        add_entry!(71, isr::isr_71);
        add_entry!(72, isr::isr_72);
        add_entry!(73, isr::isr_73);
        add_entry!(74, isr::isr_74);
        add_entry!(75, isr::isr_75);
        add_entry!(76, isr::isr_76);
        add_entry!(77, isr::isr_77);
        add_entry!(78, isr::isr_78);
        add_entry!(79, isr::isr_79);
        add_entry!(80, isr::isr_80);
        add_entry!(81, isr::isr_81);
        add_entry!(82, isr::isr_82);
        add_entry!(83, isr::isr_83);
        add_entry!(84, isr::isr_84);
        add_entry!(85, isr::isr_85);
        add_entry!(86, isr::isr_86);
        add_entry!(87, isr::isr_87);
        add_entry!(88, isr::isr_88);
        add_entry!(89, isr::isr_89);
        add_entry!(90, isr::isr_90);
        add_entry!(91, isr::isr_91);
        add_entry!(92, isr::isr_92);
        add_entry!(93, isr::isr_93);
        add_entry!(94, isr::isr_94);
        add_entry!(95, isr::isr_95);
        add_entry!(96, isr::isr_96);
        add_entry!(97, isr::isr_97);
        add_entry!(98, isr::isr_98);
        add_entry!(99, isr::isr_99);
        add_entry!(100, isr::isr_100);
        add_entry!(101, isr::isr_101);
        add_entry!(102, isr::isr_102);
        add_entry!(103, isr::isr_103);
        add_entry!(104, isr::isr_104);
        add_entry!(105, isr::isr_105);
        add_entry!(106, isr::isr_106);
        add_entry!(107, isr::isr_107);
        add_entry!(108, isr::isr_108);
        add_entry!(109, isr::isr_109);
        add_entry!(110, isr::isr_110);
        add_entry!(111, isr::isr_111);
        add_entry!(112, isr::isr_112);
        add_entry!(113, isr::isr_113);
        add_entry!(114, isr::isr_114);
        add_entry!(115, isr::isr_115);
        add_entry!(116, isr::isr_116);
        add_entry!(117, isr::isr_117);
        add_entry!(118, isr::isr_118);
        add_entry!(119, isr::isr_119);
        add_entry!(120, isr::isr_120);
        add_entry!(121, isr::isr_121);
        add_entry!(122, isr::isr_122);
        add_entry!(123, isr::isr_123);
        add_entry!(124, isr::isr_124);
        add_entry!(125, isr::isr_125);
        add_entry!(126, isr::isr_126);
        add_entry!(127, isr::isr_127);
        add_entry!(128, isr::isr_128);
        add_entry!(129, isr::isr_129);
        add_entry!(130, isr::isr_130);
        add_entry!(131, isr::isr_131);
        add_entry!(132, isr::isr_132);
        add_entry!(133, isr::isr_133);
        add_entry!(134, isr::isr_134);
        add_entry!(135, isr::isr_135);
        add_entry!(136, isr::isr_136);
        add_entry!(137, isr::isr_137);
        add_entry!(138, isr::isr_138);
        add_entry!(139, isr::isr_139);
        add_entry!(140, isr::isr_140);
        add_entry!(141, isr::isr_141);
        add_entry!(142, isr::isr_142);
        add_entry!(143, isr::isr_143);
        add_entry!(144, isr::isr_144);
        add_entry!(145, isr::isr_145);
        add_entry!(146, isr::isr_146);
        add_entry!(147, isr::isr_147);
        add_entry!(148, isr::isr_148);
        add_entry!(149, isr::isr_149);
        add_entry!(150, isr::isr_150);
        add_entry!(151, isr::isr_151);
        add_entry!(152, isr::isr_152);
        add_entry!(153, isr::isr_153);
        add_entry!(154, isr::isr_154);
        add_entry!(155, isr::isr_155);
        add_entry!(156, isr::isr_156);
        add_entry!(157, isr::isr_157);
        add_entry!(158, isr::isr_158);
        add_entry!(159, isr::isr_159);
        add_entry!(160, isr::isr_160);
        add_entry!(161, isr::isr_161);
        add_entry!(162, isr::isr_162);
        add_entry!(163, isr::isr_163);
        add_entry!(164, isr::isr_164);
        add_entry!(165, isr::isr_165);
        add_entry!(166, isr::isr_166);
        add_entry!(167, isr::isr_167);
        add_entry!(168, isr::isr_168);
        add_entry!(169, isr::isr_169);
        add_entry!(170, isr::isr_170);
        add_entry!(171, isr::isr_171);
        add_entry!(172, isr::isr_172);
        add_entry!(173, isr::isr_173);
        add_entry!(174, isr::isr_174);
        add_entry!(175, isr::isr_175);
        add_entry!(176, isr::isr_176);
        add_entry!(177, isr::isr_177);
        add_entry!(178, isr::isr_178);
        add_entry!(179, isr::isr_179);
        add_entry!(180, isr::isr_180);
        add_entry!(181, isr::isr_181);
        add_entry!(182, isr::isr_182);
        add_entry!(183, isr::isr_183);
        add_entry!(184, isr::isr_184);
        add_entry!(185, isr::isr_185);
        add_entry!(186, isr::isr_186);
        add_entry!(187, isr::isr_187);
        add_entry!(188, isr::isr_188);
        add_entry!(189, isr::isr_189);
        add_entry!(190, isr::isr_190);
        add_entry!(191, isr::isr_191);
        add_entry!(192, isr::isr_192);
        add_entry!(193, isr::isr_193);
        add_entry!(194, isr::isr_194);
        add_entry!(195, isr::isr_195);
        add_entry!(196, isr::isr_196);
        add_entry!(197, isr::isr_197);
        add_entry!(198, isr::isr_198);
        add_entry!(199, isr::isr_199);
        add_entry!(200, isr::isr_200);
        add_entry!(201, isr::isr_201);
        add_entry!(202, isr::isr_202);
        add_entry!(203, isr::isr_203);
        add_entry!(204, isr::isr_204);
        add_entry!(205, isr::isr_205);
        add_entry!(206, isr::isr_206);
        add_entry!(207, isr::isr_207);
        add_entry!(208, isr::isr_208);
        add_entry!(209, isr::isr_209);
        add_entry!(210, isr::isr_210);
        add_entry!(211, isr::isr_211);
        add_entry!(212, isr::isr_212);
        add_entry!(213, isr::isr_213);
        add_entry!(214, isr::isr_214);
        add_entry!(215, isr::isr_215);
        add_entry!(216, isr::isr_216);
        add_entry!(217, isr::isr_217);
        add_entry!(218, isr::isr_218);
        add_entry!(219, isr::isr_219);
        add_entry!(220, isr::isr_220);
        add_entry!(221, isr::isr_221);
        add_entry!(222, isr::isr_222);
        add_entry!(223, isr::isr_223);
        add_entry!(224, isr::isr_224);
        add_entry!(225, isr::isr_225);
        add_entry!(226, isr::isr_226);
        add_entry!(227, isr::isr_227);
        add_entry!(228, isr::isr_228);
        add_entry!(229, isr::isr_229);
        add_entry!(230, isr::isr_230);
        add_entry!(231, isr::isr_231);
        add_entry!(232, isr::isr_232);
        add_entry!(233, isr::isr_233);
        add_entry!(234, isr::isr_234);
        add_entry!(235, isr::isr_235);
        add_entry!(236, isr::isr_236);
        add_entry!(237, isr::isr_237);
        add_entry!(238, isr::isr_238);
        add_entry!(239, isr::isr_239);
        add_entry!(240, isr::isr_240);
        add_entry!(241, isr::isr_241);
        add_entry!(242, isr::isr_242);
        add_entry!(243, isr::isr_243);
        add_entry!(244, isr::isr_244);
        add_entry!(245, isr::isr_245);
        add_entry!(246, isr::isr_246);
        add_entry!(247, isr::isr_247);
        add_entry!(248, isr::isr_248);
        add_entry!(249, isr::isr_249);
        add_entry!(250, isr::isr_250);
        add_entry!(251, isr::isr_251);
        add_entry!(252, isr::isr_252);
        add_entry!(253, isr::isr_253);
        add_entry!(254, isr::isr_254);
        add_entry!(255, isr::isr_255);
    }
}
