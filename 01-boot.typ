#import "@preview/diatypst:0.9.1": *

#show: slides.with(
  title: "miniOS", // Required
  subtitle: "the minimum you will need for a bootable OS",
  date: "2s2026",
  authors: ("Gabriela Bittencourt, João Pedro Leôncio and Vinícius Peixoto"),

  // Optional (for more see docs at https://mdwm.org/diatypst/)
  ratio: 16/9,
  layout: "medium",
  title-color: rgb("#6565E5"),
  toc: true,
)

= minimal Operational Systems

== Examples

- minix: Tanenbaum's project, explained on "Modern Operational Systems" book

- xv6: Developed on MIT for educational purpose
    - website: https://pdos.csail.mit.edu/6.1810/2025/xv6.html
    - book: https://pdos.csail.mit.edu/6.1810/2025/xv6/book-riscv-rev5.pdf
    - playlist on youtube: https://www.youtube.com/watch?v=fWUJKH0RNFE&list=PL58sEyo8wOZRpDZCa4LQIfbjPz05PDpWF

- RISC-V Bare Bones: A 'hello world'-sized OS
    - https://wiki.osdev.org/RISC-V_Bare_Bones

== Our project

QEMU - quick emulator
- https://www.qemu.org/

RISC-V
- https://riscv.github.io/riscv-isa-manual/snapshot/privileged

// *Term*: Definition

= Starter files

== kernel.c

- The starting point of the OS

- Definition of a main `kmain` in the case of kernel

```
void kmain(void) {
	print("Hello world!\r\n");
	while(1) {

	}
	return;
}
```

#v(100pt)

```
unsigned char * uart = (unsigned char *)0x10000000; 
void putchar(char c) {
	*uart = c;
	return;
}
 
void print(const char * str) {
	while(*str != '\0') {
		putchar(*str);
		str++;
	}
	return;
}
```

== entry.S

/*#stack(
    dir: ttb,
    rect[stack],
    rect[\ ...\ ],
    rect[heap\ ],
    rect[\ bss\ ],
    rect[data\ ],
    rect[text\ ],
)*/
Assembly code to set up the _stack_ reset _satp_, clear _.bss_ section and *jump to kernel main*.

/ *stack*: Points the next instruction to be executed. To execute a program (or a piece of code), the code has to be loaded in memory (instructions are 'stack' the stack).

/ *satp*: _supervisor address translation and protection register_ -- in the future we will use to set up page table

/ *.bss*: _block starting symbol_ -- portion of the code that contains statically allocated variables that are declared but not have been assigned a value yet.


#figure(
    image("images/Program_memory_layout.pdf", width:17%),
    caption: [
        Typical layout of a simple computer's program memory [https://en.wikipedia.org/wiki/.bss]
    ],
)


```
	(...)
	csrw satp, zero
	
	la sp, stack_top
	
	la t5, bss_start
	la t6, bss_end
bss_clear:
	sd zero, (t5)
	addi t5, t5, 8
	bltu t5, t6, bss_clear
	
	(...)
	/* Jump to kernel! */
	tail kmain
```

== linker.ld

- Specify where our kernel will be loaded at.

- For this example we will use the start of the RAM as our load address.

= Let's dive in

= Next steps
