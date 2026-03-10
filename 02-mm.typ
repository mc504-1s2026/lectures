#import "@preview/diatypst:0.9.1": *

#show: slides.with(
  title: "Memory Management", // Required
  subtitle: "subtitle",
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

    - a

== Non-contiguous Memory Allocation

#figure(
    image("images/02.01-mem-allocation-changes.png", width:100%),
    caption: [
        Memory allocation of 5 processes (programs: A, B, C, D and A again) over time. //TODO: add ref Tanenbaum
    ]
)

= Physical Memory

== Limited resource

```
$ free -h
               total        used        free      shared  buff/cache   available
Mem:            14Gi        12Gi       803Mi       4.5Gi       6.2Gi       2.7Gi
Swap:          4.0Gi       2.6Gi       1.4Gi
```



= Virtual Memory

== Motivation

- Resource management

    - Ideally all processes would have access to the full memory at the moment of execution

    - In reality, each process has a access to a limited amount of memory that can expand and shrink depending on demand

- Scope security

    - security of data from different processes


= Paging

== Page Table Entries (PTE)

pte

== Levels

pte is cool and all, but it's not enough
//TODO: explicar pagetable, essas coisas

== Linux Kernel implementation/design

#figure(
    image("images/02.02-lk-page-table.png", width:70%),
    caption: [
        a - https://www.kernel.org/doc/gorman/html/understand/understand006.html
    ]
)

= Struct

//TODO: explicar stack heap, essas coisas

= References

== References

- Tanenbaum, Andrew. (2012) '3. Memory Management', in _Modern operating systems_. Pearson Education, Inc., 4th ed.

- TODO: add kernel codes

- TODO: add kernel docs
