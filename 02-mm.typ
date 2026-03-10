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

== 'Memory'

When we talk about 'memory' in OS context, we are talking about **RAM**

//TODO: not about the disk

**Memory is NOT Storage**

== Program x Process

- Program

    - Code. Static entity.

    - Needs storage

    - Example: Your C code from MC202

- Process

    - The execution of the code. Dynamic entity.

    - Needs memory: the instructions will be load in specific space of memory (), variables will be set to specific spaces in memory ()

    - Needs processessor

    - Can have multiple instance of the same program at the same time

    - Example: The instance of your text editor while you are writing a program; the instance of the terminal running when you are navigating through it to compile your code and when you run it; the instance of your program during the short period of time your computer is executing your code to give you an answer.

== Memory Management Historical Advance

- Contiguous Memory Allocation (no abstraction of memory)

    - One part is reserved to the OS, the other runs a single process

    - One process at the time: in order to change the process executed, the OS must save the previous process in disk and then load the next one.

    - Simple memory management

    - Poor memory utilization

- Non-contiguous Memory Allocation

    - a

= Physical Memory



= Virtual Memory




= Paging

//TODO: explicar pagetable, essas coisas

= Struct

//TODO: explicar stack heap, essas coisas
