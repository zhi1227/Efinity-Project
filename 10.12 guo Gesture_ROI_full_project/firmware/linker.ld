OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0xF9000000, LENGTH = 32K }
SECTIONS {
    .text : { KEEP(*(.text.start)) *(.text*) } > RAM
    .rodata : { *(.rodata*) *(.srodata*) } > RAM
    .data : {
        . = ALIGN(4);
        __global_pointer$ = . + 0x800;
        *(.data*) *(.sdata*)
    } > RAM
    .bss (NOLOAD) : {
        . = ALIGN(4); _bss_start = .;
        *(.bss*) *(.sbss*) *(COMMON)
        . = ALIGN(4); _bss_end = .;
    } > RAM
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(_bss_end <= _stack_top - 2048, "Firmware leaves less than 2 KiB stack")
}
