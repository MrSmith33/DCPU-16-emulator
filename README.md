DCPU-16 emulator
================

![screen1](https://cloud.githubusercontent.com/assets/1129910/2623807/0780eb22-bd09-11e3-85e7-5c52e7fe4686.png)

**Alpha stage**
----------------

[Anchovy](https://github.com/MrSmith33/anchovy) is used for GUI.

Already works:
 - emulator
 - disassembler
 - memory view
 - registers view
 - execution by step

Devices implemented:
 - generic clock
 - generic keyboard
 - LEM1802 monitor
 - M35FD floppy drive

Planned features:
 - reverse debugging
 - assembler (0xSCA compatible)
 - non-standart devices
 - workspaces


Emulator is still buggy, but most of programs already works.
Enhancement propositions, pull requests and bug reports are highly appreciated.

### Building

First build derendencies:
```
dub fetch anchovy --version=0.6.1
dub build anchovy
```
After that you can use command to build emulator:
```
dub build --nodeps
```
this will prevent dub from pulling all the versions of anchovy.