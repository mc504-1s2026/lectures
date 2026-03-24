#import "@preview/diatypst:0.9.1": *
#import "@preview/diagraph:0.3.6": *

#show: slides.with(
  title: "Traps", // Required
  subtitle: "2026-03-23",
  date: "1s2026",
  authors: ("Gabriela Bittencourt, João Pedro Leôncio and Vinícius Peixoto"),

  // Optional (for more see docs at https://mdwm.org/diatypst/)
  ratio: 16/9,
  layout: "medium",
  title-color: rgb("#6565E5"),
  toc: true,
)

// Topics braindump:
// - Motivation for traps
//   - Example of reading from mouse/kb
//   - Example of how to deal with invalid operation (e.g. page faults)
//   - Arrive at the conclusion that we need some kind of preemption to handle these
// - Definition
//   - Traps = stop current execution and jump to another address upon an event
//   - Synchronous: software traps (exceptions)
//     - Example: page faults
//     - Mention page swapping, CoW, etc
//   - Asynchronous: external traps (interrupts)
//     - Example: timers (systick, rtc, etc), serial, etc
// - Trap considerations
//   - Anatomy of a trap handler
//     - Interrupt enabling disabling in registers
//   - Need handlers to be fast
//     - Mention how Linux does this: top halves vs. bottom halves
//   - Talk about the RISC-V ABI, trap handler needs to save caller-saved registers
//   - All code in the kernel has to assume it can be *preempted*
// - Introduction to concurrency
//   - Concurrency vs. paralellism
//     - Example: Python `async`
//   - Basic race conditions
//   - Need for locking mechanisms

= Introduction

== Motivation

Certain events in a system may need immediate attention:
- Devices
  - User input, such as typing on a keyboard, moving a mouse, etc.
  - GPU finishes a job (e.g. rendering the next frame of your videogame)
  - Network interface card (NIC) receives a new network packet
  - And many more
- Software error conditions (e.g. someone messed up):
  - Invalid instructions
  - Page faults (invalid access to pages)

*Question: how to deal with those events?*

== Idea: polling

- Most hardware devices are exposed to software through *memory-mapped registers*
  - e.g. hardware registers can be accessed by reading/writing to memory addresses
  - For example, the serial device our kernel uses to print to the console:

  ```c
  char *uart = (char*)0x10000000;
  void putchar(char c)
  {
	  *uart = c;
	  return;
  }
  ```
  - But also many others, e.g. PCI devices (GPUs, NICs, SATA/NVMe controllers, etc.)

#pagebreak()

*Idea*: continuously check those memory-mapped registers for any events
  - This is called *busy-waiting*

```c
#define DEV_DATA_AVAIL  *(u64*)0x20000000;
#define DEV_DATA        *(u64*)0x20000008;
u64 dev_read()
{
  volatile u64 data_available = DEV_REG_DATA_AVAIL;
  volatile u64 data = DEV_REG_DATA;

  while (1) {
    if (data_available != 0)
      return data;
  }
}
```

What is the *problem* with this?

#pagebreak()

What is the *problem* with this?
- We waste a lot of CPU cycles checking if data is available
- What if we need to do other work in the meantime?
- Stop doing work periodically to check?
  - How often should we check without risking missing data because we were too slow?
- This game gets complicated very quickly when you have multiple devices
- And what if we have a *bug* in our driver (e.g. nullptr deref)?
- Crash the whole system?

There is a better solution: *traps*

= Traps

== Definition

- A *trap* is an event that causes the CPU to stop whatever it is doing and perform a *jump* to another code location upon an event
- There are generally two types of events:
  - *External*: an external device raises an event that requires immediate attention
    - e.g. a character has arrived in our serial device, or a network packet arrived in a NIC, etc.
    - These are commonly called *interrupts*, or *IRQs* (= interrupt requests)
  - *Internal*: something in the code that the CPU is running raises an event that requires immediate attention
    - e.g. a page fault (accessing invalid pages), but also dividing by zero, executing privileged or invalid instructions, etc
    - These are commonly called *exceptions* or *faults*

How would our serial driver example work with interrupts?

#pagebreak()

== Example

#columns(2)[
```c
struct {
  // buffer for the data
  u64 data[512]; 
  // elements available to read
  size_t available;
} dev;

#define DEV_DATA *(u64*)0x20000008
void dev_irq()
{
  volatile u64 reg_data = DEV_DATA;
  dev.data[dev.end++] = reg_data;
  dev.data_available = true;
}
```

#colbreak()

```c
u64 dev_read()
{
  if (dev.available != 0)
    return dev.data[--dev.end];
  else
    return 0;
}
```
Note how we:
- `dev_irq` is called *asynchronously* to read data upon an interrupt
- We don't block when doing `dev_read` anymore
- We use a buffer $->$ no more risk of dropping data
]

== Trap numbers

There are several different kinds of traps. On most architectures, each trap
type is identified by a *number*
  - For exceptions, there are usually *architecturally defined* codes identifying
    each exception type
  - For interrupts, there are usually *platform defined* numbers identifying
    each interrupt type
      - These are called *IRQ numbers* in the Linux world
      - Generally used for hardware interrupts
      - Usually correspond to physical hardware pins connected to the CPU/interrupt controller

#pagebreak()

#figure(
    image("images/03-scause.svg", width:100%),
    caption: [
        The `scause` CSR in RISC-V.
    ]
)

#figure(
    image("images/03-interrupt-codes.png", width:40%),
    caption: [
        The `scause` interrupt codes in RISC-V.
    ]
)

#figure(
    image("images/03-exception-codes.png", width:35%),
    caption: [
        The `scause` exception codes in RISC-V.
    ]
)

#pagebreak()

Keep in mind the fundamental difference between *exceptions* and *interrupts*:

- Exceptions are *synchronous*:
  - Triggered upon executing a code instruction
    - Illegal instruction
    - Load/store/instruction page faults
    - Environment calls (`ecall`)
  - Identifying codes are architecturally *fixed*
- Interrupts are *asynchronous*:
  - Triggered by various hardware events that may happen at any time
    - Can have various meanings depending on hardware (serial device has data available, GPU finishes rendering frame, etc.)
  - IRQ numbers are defined by the *platform* (e.g. each defined by the architecture of the motherboard/system-on-chip)

== Trap handlers

A *trap handler* is a function that the CPU jumps to when a trap happens.

There are normally two ways of going about it:
- Have a single function that handles all traps
  - This is what is generally used in RISC-V (AFAIK)
- Have an array of functions that handle different trap types (generally interrupts)
  - This scheme is what is usually called *vectored interrupts* (and the array is the *interrupt vector table*)
  - IRQ 0 triggered $->$ CPU jumps to the address stored in `IVT[0]`, IRQ 1 $->$ `IVT[1]` and so on
  - RISC-V supports this, but we won't use it (for simplicity)

#pagebreak()

A trap handler generally has this structure:

#[
  #show raw: set text(size: 6pt)
    ```c
    void trap_handler()
    {
        bool is_irq = trap_is_irq();
        u64 cause = trap_get_cause();

        if (is_irq) {
            handle_irq(cause);
            return;
        }

        switch (cause) {
            case TRAP_PAGE_FAULT:
                handle_page_fault();
                break;
            case TRAP_INVALID_INSTR:
                handle_invalid_instr();
                break;
            ...
        }
    }
    ```
]

#pagebreak()

There is an additional detail about traps that we have to worry about.

Thinking in terms of assembly, what happens when we *call another function* here?

```c
void trap_handler()
{
    bool is_irq = trap_is_irq();
    u64 cause = trap_get_cause();

    if (is_irq)
       handle_irq(cause);
    // ...
}
```

#pagebreak()

*Answer:* we overwrite (at the very least) `ra` and `a0`/`a1`/`a2`!

- Remember that any part of the kernel code can suddenly be interrupted and jump to the trap handler
- We have to make sure the trap handler doesn't overwrite any state (registers) from what was running before
- This is usually achieved by *dumping all registers* onto the stack before entering the trap handler 
    - This "block" of register/state dumps on the stack is called a *trap frame*

#pagebreak()

```asm
.globl trap_entry
.align 4
trap_entry:
    addi sp, sp, -144
    sd ra, 0(sp)
    sd sp, 8(sp)
    sd gp, 16(sp)
    # write the rest of the registers...

    call trap_handler
    
    ld ra, 0(sp)
    ld sp, 8(sp)
    ld gp, 16(sp)
    # reload the rest of the registers...
```

#pagebreak()

Other things to note:
- Your trap handler should be *fast*
    - Otherwise you will hog resources from the rest of the operating system
    - Preferrably defer slow/heavy work for later
        - Linux: top vs. bottom halves
- Your trap handler *should never block*``
    - e.g. waiting for something to happen for an unknown amount of time
    - This risks having one of the CPUs stuck inside the trap handler forever
- Your *kernel code* need to assume they can be *preempted*
    - e.g. another higher-priority interrupt can occur during their duration
    - This creates a whole other class of problems that we will cover next class when we talk about *concurrency*

#pagebreak()

Next class:

- Intro to concurrency
- In-depth implementation of trap handling in RISC-V

