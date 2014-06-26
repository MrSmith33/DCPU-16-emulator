DCPU-16 emulator
================

![screen3](https://cloud.githubusercontent.com/assets/1129910/3400128/af054176-fd42-11e3-9655-ff2ab7b23463.png)

**Alpha stage**
----------------

[Anchovy](https://github.com/MrSmith33/anchovy) is used for GUI.

Already works:
 - emulator
 - disassembler
 - memory view
 - registers view
 - execution by step
 - reverse debugging
 - CPU speed editing
 - Statistics of execution (outputted in console)
 - Collapsing of zero lines in memory view

Devices implemented:
 - generic clock
 - generic keyboard
 - LEM1802 monitor
 - M35FD floppy drive

Planned features:
 
 - assembler (0xSCA compatible)
 - non-standart devices
 - workspaces


Emulator is still buggy, but most of programs already works.
Enhancement propositions, pull requests and bug reports are highly appreciated.

### Building

Build derendencies:
```
dub fetch anchovy --version=0.6.2
dub build anchovy
```
After that you can use command to build emulator:
```
dub build --nodeps
```
this will prevent dub from pulling all the versions of anchovy.
