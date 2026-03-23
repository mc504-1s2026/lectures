#import "@preview/diatypst:0.9.1": *
#import "@preview/diagraph:0.3.6": *

#show: slides.with(
  title: "Memory Management", // Required
  subtitle: "2026-03-10",
  date: "1s2026",
  authors: ("Gabriela Bittencourt, João Pedro Leôncio and Vinícius Peixoto"),

  // Optional (for more see docs at https://mdwm.org/diatypst/)
  ratio: 16/9,
  layout: "medium",
  title-color: rgb("#6565E5"),
  toc: true,
)

= Understanding Resources

== Memory x Storage

When we talk about 'memory' in OS context, we are talking about *RAM*

//TODO: not about the disk

*Memory is NOT Storage*


- Memory
    - fast, expensive, volatile

- Storage
    - slow, cheap, consistent

== Program x Process

- Program

    - Code. Static entity.

    - Needs storage

    - Example: Your C code from MC202: the .c file

- Process

    - The execution of the code. Dynamic entity.

    - Needs memory: the instructions will be load in specific space of memory (), variables will be set to specific spaces in memory ()

//    - Can have multiple instance of the same program at the same time

    - Example: The instance of your text editor while you are writing a program; the instance of the terminal running when you are navigating through it to compile your code and when you run it; the instance of your program during the short period of time your computer is executing your code

== Memory Management Historical Advance

- Contiguous Memory Allocation (no abstraction of memory)

    - One part is reserved to the OS, the other runs a single process

    - One process at the time: in order to change the process executed, the OS must save the previous process in disk and then load the next one.

    - Simple memory management

    - Poor memory utilization

- Non-contiguous Memory Allocation

    - Allows each process to "see" the entire address space as its own
    - Multiple processes can coexist
    - Memory allocation logic is opaque to processes -- the kernel handles virtual memory

== Non-contiguous Memory Allocation

#figure(
    image("images/02.01-mem-allocation-changes.png", width:100%),
    caption: [
        Memory allocation of 5 processes (programs: A, B, C, D and A again) over time. //TODO: add ref Tanenbaum
    ]
)

= Memory management overview
== Physical vs. virtual address spaces

- *Physical addresses*: actual addresses as seen by the CPU on the system memory bus (e.g. DDR RAM, memory-mapped PCIe registers, etc.)
- *Virtual adresseses*: made-up memory addresses that are mapped onto physical memory addresses

Example: `vmlinux` (a Linux kernel image)

```sh
$ llvm-objdump -t ~/kernel/linux/vmlinux 
/home/nuke/kernel/linux/vmlinux:        file format elf64-littleaarch64
SYMBOL TABLE:
ffff80008228b738 l       .init.text     0000000000000054 record_mmu_state
ffff80008228b790 l       .init.text     0000000000000030 preserve_boot_args
ffff8000822655c8 l     F .rodata.text   0000000000000034 __primary_switch
ffff80008228b738 l       .init.text     0000000000000000 $x
ffff80008228b7c0 l     F .init.text     000000000000008c __primary_switched
ffff800080061230 l     F .text  0000000000000020 set_cpu_boot_mode_flag
```

Note that the addresses for the symbols hover around address `0xffff8000822800` $approx$ 65535 TiB (!)

- Clearly no system has that much memory
  - Might need to revisit this claim in the next decade or so :-)
- Those are *virtual addresses* configured by the kernel and translated into physical addresses
- This translation is done by a hardware unit called the Memory Management Unit (MMU)
  - The MMU is in turn configured by setting up data structures called *page tables*
  - Page tables describe the mapping between the virtual $<->$ physical adress spaces

#figure(
  image("images/02-mmu.png", width: 65%),
  caption: [
    Overview of the address translation process.
  ],
)

== Some terminology

- A *page* is a *block of memory* of fixed size
  - All memory is managed in units of pages
  - Traditionally 4KiB, more recently also 16KiB and 64KiB
  - In this class we always assume `PAGE_SIZE` = 4096
- Physical page number (*PPN*): the number of the n-th page in physical memory
  - Linux also calls this the *PFN* (page frame number)
  - Small exercise: what's the physical address of PPN=1024?
  - Another exercise: what's the PPN of physical address `0xffffffffabcde000`?
- Some commonly used idioms:
  - `PAGE_SHIFT`: number of bits to right-shift in order to get the PPN
    - For 4K pages, `PAGE_SHIFT = 12` ($2^12 = 4096$)
  - `PAGE_SIZE`: the size of a page in bytes
    - `PAGE_SIZE = (1 << PAGE_SHIFT)`

= Physical memory allocation
== Physical memory allocation

#columns(2)[
  Doing pretty much anything requires allocating physical memory.
  One of the first things a kernel needs to implement is a *physical page allocator*:
  - Responsible for managing the available physical memory pages in the system
  - Needs to keep track of which pages are in use and which ones are free
  - Dumb (but perfectly valid) solution: freelist allocator
    - Linked list of all available pages
    - `alloc()` $->$ pop the list head
    - `free(page)` $->$ insert `page` at the front of the list

  #colbreak()

  #figure(
    image("images/02-freelist.png", width: 80%),
    caption: [
      The freelist allocator (a linked-list of free pages)
    ]
  )
]

- This allocator has the upside of being dead simple to implement/debug
- But it would be nice to be able to allocate multiple contiguous pages at once
- In the next class we will go over other more elaborate allocators that solve this problem

= Virtual memory
== Virtual memory

- `riscv64` has 3 virtual memory modes (Sv39, Sv48 and Sv57)
  - We will work exclusively with Sv39 in this class
- We manage virtual memory by mapping *virtual page numbers* (VPNs) to *physical address numbers* (PPNs):

#figure(
  image("images/02-sv39-phys.svg"),
  caption: [ The Sv39 physical address encoding. ]
)

#figure(
  image("images/02-sv39-virt.svg"),
  caption: [ The Sv39 virtual address encoding. ]
)

== Page tables

- In Sv39, a *page table* (PTB) is an array of $2^9 = 512$ words called *page table entries* (*PTEs*)
  - Note that in `riscv64` 1 word = 64 bits = 8 bytes and that $512 times 8$ bytes = 4KB
  - e.g. each page table takes up a physical page (not a coincidence)
- Each PTE can be either a:
  - *leaf page*: Map a VPN to a PPN
  - *non-leaf page*: Point to the PPN of another page table
- Sv39 uses a *3-level page table* scheme, which means that:
  - The *root page table* (also called a *level 1 page table*) contains entries that point
    to to the PPN of a *level 2 page table*
  - Each *level 2 page table* points to a *level 3 page table* containing only leaf pages that map
- The process of following entries from root PTB $->$ level 2 PTB $->$ level 3 PTB until we
  reach a leaf page is called *walking* the page tables

Let's take a closer look at the structure of a PTE:

#figure(
  image("images/02-sv39-pte.svg"),
  caption: [ Sv39 page table entry. ]
)

#columns(2)[
  The `X/W/R` bits have the following meaning:

  #colbreak()

  #{
    show table.cell: set text(size: 10pt)
    table(
      columns: 4,
      [`X`], [`W`], [`R`], [*meaning*],
      [0], [0], [0], [Pointer to a next level page table],
      [0], [0], [1], [Read-only page],
      [0], [1], [0], [Reserved for future use],
      [0], [1], [1], [Read-write page],
      [1], [0], [0], [Execute-only page],
      [1], [0], [1], [Read-execute page],
      [0], [1], [0], [Reserved for future use],
      [1], [1], [1], [Read-write-execute page],
    )
  }
]

#figure(
  image("images/02-sv39-pte.svg"),
  caption: [ Sv39 page table entry. ]
)

For the others:

- `V` (valid): whether the PTE is valid
- `U` (user): whether the page is accessible in U-mode
- `G` (global): whether this is a global mapping that exists in all address spaces
- `A` (access): whether the page has been read/written/fetched since the bit was cleared
- `D` (dirty): whether the page has been written since the bit was cleared
== Walking the page tables

#figure(
  image("images/02-sv39-virt.svg"),
)

We will go into more detail about how to actually implement this, but the (simplified) algorithm
for walking the page tables is as follows:

- Start at the root page table (level 1)
- Check if the PTE at index `VPN[2]` has `V=1`; fail otherwise
- Move to the level 2 PTB at the physical address stored in `PPN[2:0]`
- Check if the PTE at index `VPN[2]` has `V=1`; fail otherwise
- Move to the level 1 PTB at the physical address stored in `PPN[2:0]`
- Extract the PPN that maps to the original VPN by looking at `PPN[2:0]`

= Bitwise idioms

== Basics

Bitwise operations: `NOT` (`~`), `AND` (`&`), `OR` (`|`), `XOR` (`^`)

#columns(4)[

  ```
   A: 10110001
   B: 01111001

  ~A: 01001110
  ~B: 10000110
  ```

  #colbreak()

  ```
  A & B:

      10110001
    & 01111001
    ------------
    = 00110001
  ```

  #colbreak()

  ```
  A | B:

      10110001
    | 01111001
    ------------
    = 00000110
  ```

  #colbreak()

  ```
  A ^ B:

      10110001
    ^ 01111001
    ------------
    = 00000110
  ```
]

#pagebreak()

#columns(2)[
  Left shift: `<<`
  ```
   A:       1000000010110001
   A << 5:  0001011000100000
  ```

  #align(center)[
    #rect()[ `n` bit left-shift $->$ multiply by $2^n$ ]
  ]

  #colbreak()

  *Logical* right shift: `>>`
  ```
   A:       1000000010110001
   A >> 5:  0000010000000101
  ```

  #align(center)[
    #rect()[ `n` bit logical right-shift $->$ (unsigned) divide by $2^n$ ]
  ]
]

#pagebreak()

#columns(2)[
  *Logical* right shift: `>>`
  ```
   A:       1000000010110001
   A >> 5:  0000010000000101
  ```

  #align(center)[
    #rect()[ `n` bit (logical) right-shift $->$ (unsigned) divide by $2^n$ ]
  ]

  #colbreak()

  *Arithmetic* right shift: `>>`
  ```
   A:       1000000010110001
   A >> 5:  1111110000000101
  ```
  #align(center)[
    #rect()[ `n` bit (arithmetic) right-shift $->$ (signed) divide by $2^n$ ]
  ]
]

#text(red)[*Watch out:*] in C, `unsigned` $->$ *logical* left-shift, `signed` $->$ *arithmetic* left-shift

#columns(2)[
  ```c
  unsigned int A = 0b1000000010110001;
  A >>= 5;      // 0b0000010000000101
  ```

  #colbreak()

  ```c
  int A =      0b1000000010110001;
  A >>= 5;  // 0b1111110000000101
  ```
]

#pagebreak()

== Bitmasks

A *bitmask* is a carefully constructed number that helps us *read/write specific bits* of another number.

- Quick terminology note: "*clear* a bit" means *make it 0*, "*set* a bit" means *make it 1*

Suppose we have have `A = 0b1000000010110001`, and want to *read bit 4*. We use the following trick:

#[
  #show raw: set text(size: 12pt)
  ```
  Read A[4]: A & (1 << 4)
                        â
  A        0b1000000010110001
  MASK   & 0b0000000000010000 ---> (1 << 4)
         ---------------------
         = 0b0000000000010000
  ```
]


#pagebreak()

Similarly, if we wanted to *set bit 6*:

#[
  #show raw: set text(size: 12pt)
  ```
  Set A[6]: A | (1 << 6):
                      â
  A        0b1000000010110001
  MASK   | 0b0000000001000000 ---> (1 << 6)
         ---------------------
         = 0b1000000011110001
  ```
]

#pagebreak()

What about *clearing bit 5*?

#[
  #show raw: set text(size: 12pt)
  ```
  Clear A[5]: A & ~(1 << 5):
                       â
  A        0b1000000010110001
  ~MASK  & 0b1111111111011111 ---> ~(1 << 5)
         ---------------------
         = 0b1000000010010001
  ```
]

#pagebreak()

Notice the pattern:
- We have some number (or register) `A`
- Want to modify bit `n`? $->$ `MASK = (1 << n)`
- Set bit `n` $->$ `A |= MASK`
- Clear bit `n` $->$ `A &= ~MASK`

Now let's generalize this to *multiple bits*. How to *set bits 12, 3 and 2*?

#pagebreak()

#[
  #show raw: set text(size: 12pt)
  ```
  Set A[12], A[3:2]: A |= MASK
  MASK = ((1 << 12) | (1 << 3) | (1 << 2))
                â        ââ
  A        0b1000000010110001
  MASK   | 0b0001000000001100
         ---------------------
         = 0b1001000010111101
  ```
]

What about *clearing bits 15, 4 and 5*?

#pagebreak()

#[
  #show raw: set text(size: 12pt)
  ```
  Clear A[15], A[5:4]: A &= ~MASK
  MASK = ((1 << 15) | (1 << 5) | (1 << 4))
             â         ââ
  A        0b1000000010110001
  MASK   & 0b0111111111001111
         ---------------------
         = 0b0000000010000001
  ```
]

Last example (may be relevant for your next lab ð): how to write `0b1101` to *bits 4, 5, 6 and 7*?

#pagebreak()

At this point we might as well do it in plain C:

#[
  #show raw: set text(size: 11pt)
  ```c
    #define MASK ((1UL << 7) | (1UL << 6) | (1UL << 5) | (1UL << 4))
    #define SHIFT 4
    uint64_t a = 0b1000000010110001 
    a &= ~MASK; // clear a[7:4]
    a |= (0b1101UL << SHIFT)
  ```
]

Notice we use `1UL` for the constants in the macro; numeric constants in C *default to `int` (signed)*,
but we generally want to *avoid signed bit arithmetic*; the `UL` suffix tells specifies that the
numeric constant is an `unsigned long int` (e.g. 64-bit unsigned integer).

Always try to avoid mixing signed and unsigned numbers as it is one of the biggest sources of
*undefined behavior* in C.

= Configuring virtual memory and paging

== Common idioms

#figure(
  image("images/02-sv39-phys.svg"),
  caption: [ The Sv39 physical address encoding. ]
)

#figure(
  image("images/02-sv39-virt.svg"),
  caption: [ The Sv39 virtual address encoding. ]
)

```c
#define PAGE_SHIFT 12
#define PAGE_SIZE (1 << PAGE_SHIFT)
```

*Exercise:* how to calculate `PAGE_MASK`?

#pagebreak()

*Answer:*
```c
#define PAGE_MASK (PAGE_SIZE - 1)
```

// #raw-render(```
//     digraph G {
//         graph   [pad="0.5", nodesep="0.5", ranksep="2"]
//         node    [shape=plain]
//         rankdir=LR
// 
//         PTB3 [label=<
//             <table border="0" cellborder="1" cellspacing="0">
//                 <tr> <td>index</td> <td>PTE</td> </tr>
//                 <tr> <td>0x00000000</td> <td port="0">0xffff</td> </tr>
//             </table>
// 
//         >]
// 
//         PTB2 [label=<
//             <table>
//                 <tr> <td>index</td> <td>PTE</td> </tr>
//                 <tr> <td port="l0">0x00000000</td> <td>0xffff</td> </tr>
//                 <tr> <td port="l1">0x00000000</td> <td>0xffff</td> </tr>
//             </table>
// 
//         >]
// 
//         PTB3:0 -> PTB2:l1
//     }
// ```,
// )

#pagebreak()


= Lab: Memory management

== files

```
├── include (kernel headers)
│   └── arch
│       ├── pgtable.h (defs and helpers for page table)
│       └── kalloc.h (freelist implementation)
└── src
    └── mm.c (implementation for memory management)

```

#pagebreak()

- `pgtable.h`: All the hardware specs and design for the page table

- `kalloc.h`: Implement a `freelist` -- non-allocated pages of memory
    - `page_alloc()`: pop the data struct of freelist
    - `page_free()`: insert in data struct of freelist

- `mm.c`: Memory management
    - `ptb_walker`: walk through the levels of pagetable and returns when valid or !valid, or leaf or !leaf (it is up to implementation)
    - `vm_page_alloc`: allocate a page given a virtual address
    - `mm_init`: allocate all sessions: `.bss`, `.text`, `.data`, `.rodata`


= Free Pages

== Linked list

```
struct node {
    int data;
    struct node *next;
}
```

To add new node:

```
struct create_node {
    struct node new_node = (struct node*)malloc(sizeof(struct node)); // :(
    // ...
}
```

We cannot use a `malloc` when implementing the precursor of `malloc`.

We cannot dinamic alloc the memory if there is no memory management yet.

== Data Structs options for the `freelist`

- Linked list, with all the nodes declared in array

- Directly an array with the addresses and a walker

- Bitmap the used pages and calculate the free addresses from the position of the bit

- Use the pages as node of the linked list -- write at the first word, the address for next page

= Allocating

== Sections

Which flag to use in each section of the kernel executable? (`PTE_READ` , `PTE_WRITE` , `PTE_EXEC`)

- `.text`: contains executable instructions

- `.bss`: contains non-initialized statically allocated variables

- `.rodata`: contains read-only data

- `.data`: contains data that can be altered

== Attention when implementing

```
*** Fatal Exception *** core dump ***
Segmentation fault (core dumped)
```

Will never occur in your code.

= References

== References

- Tanenbaum, Andrew. (2012) '3. Memory Management', in _Modern operating systems_. Pearson Education, Inc., 4th ed.
- _The RISC-V Instruction Set Manual, Volume II: Privileged Architecture_. https://riscv.github.io/riscv-isa-manual/snapshot/privileged/

- _Virtual Memory Layout on RISC-V Linux_. https://docs.kernel.org/arch/riscv/vm-layout.html

