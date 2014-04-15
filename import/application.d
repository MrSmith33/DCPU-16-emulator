/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module application;

import std.stdio : writeln;
import std.string : format;
import std.file : read, write, exists;

import anchovy.core.input;

import anchovy.graphics.windows.glfwwindow;
import anchovy.graphics.texture;
import anchovy.graphics.bitmap;
import anchovy.gui;
import anchovy.gui.guirenderer;

import anchovy.gui.application.application;

import dcpu.emulator;
import dcpu.disassembler;
import dcpu.dcpu;
import dcpu.updatequeue;
import memoryview;

import dcpu.devices.lem1802;
import dcpu.devices.genericclock;
import dcpu.devices.generickeyboard;
import dcpu.devices.floppydrive;

class EmulatorApplication : Application!GlfwWindow
{
	this(uvec2 windowSize, string caption)
	{
		super(windowSize, caption);
	}

	Emulator!DebugDcpu emulator;
	Lem1802!DebugDcpu monitor;
	GenericClock!DebugDcpu clock;
	GenericKeyboard!DebugDcpu keyboard;
	FloppyDrive!DebugDcpu floppyDrive;
	Widget reg1, reg2, reg3, reg4;
	MemoryView!DebugDcpu memoryList;

	bool dcpuRunning = false;
	Widget runButton;
	string file = "hello.bin";

	void swapFileEndian(string filename)
	{
		import std.bitmanip : swapEndian;
		ubyte[] binary = cast(ubyte[])read(filename);
		foreach(ref srt; cast(ushort[])binary)
		{
			srt = swapEndian(srt);
		}
		write(filename, cast(void[])binary);
		reset(null, null);
	}

	ushort[] loadBinary(string filename)
	{
		if (!exists(filename)) return [];
		ubyte[] binary = cast(ubyte[])read(filename);
		assert(binary.length % 2 == 0);
		return cast(ushort[])binary;
	}

	void attachDevices()
	{
		emulator.dcpu.updateQueue = new UpdateQueue!DebugDcpu;
		emulator.attachDevice(monitor);
		emulator.attachDevice(keyboard);
		emulator.attachDevice(clock);
		emulator.attachDevice(floppyDrive);
	}

	override void load(in string[] args)
	{
		if (args.length > 1)
		{
			file = args[1];
			writefln("loading '%s'", file);
		}

		fpsHelper.limitFps = true;

		emulator = new Emulator!DebugDcpu();
		monitor = new Lem1802!DebugDcpu;
		clock = new GenericClock!DebugDcpu;
		keyboard = new GenericKeyboard!DebugDcpu;
		floppyDrive = new FloppyDrive!DebugDcpu;
		floppyDrive.floppy = new Floppy;
		attachDevices();
		
		emulator.loadProgram(loadBinary(file));

		// ----------------------------- Creating widgets -----------------------------
		templateManager.parseFile("dcpu.sdl");

		auto mainLayer = context.createWidget("mainLayer");
		context.addRoot(mainLayer);
	
		auto monitorWidget = context.getWidgetById("monitor");
		auto texture = new Texture(monitor.bitmap, TextureTarget.target2d, TextureFormat.rgba);
		monitorWidget.setProperty!("texture")(texture);
		monitorWidget.addEventHandler(delegate bool(Widget widget, KeyPressEvent event){
			keyboard.onKey(cast(KeyCode)event.keyCode, event.modifiers, true);
			return true;
		});
		monitorWidget.addEventHandler(delegate bool(Widget widget, KeyReleaseEvent event){
			keyboard.onKey(cast(KeyCode)event.keyCode, event.modifiers, false);
			return true;
		});
		monitorWidget.addEventHandler(delegate bool(Widget widget, PointerPressEvent event){
			return true;
		});
		monitorWidget.setProperty!"isFocusable"(true);

		auto stepButton = context.getWidgetById("step");
		stepButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){step(); return true;});

		auto stepButton10 = context.getWidgetById("step10");
		stepButton10.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){emulator.stepInstructions(10); printRegisters(); return true;});
		auto stepButton100 = context.getWidgetById("step100");
		stepButton100.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){emulator.stepInstructions(100); printRegisters(); return true;});
		

		runButton = context.getWidgetById("run");
		runButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){runPause(); return true;});

		auto resetButton = context.getWidgetById("reset");
		resetButton.addEventHandler(&reset);

		auto disassembleButton = context.getWidgetById("disasm");
		disassembleButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){disassembleMemory(); return true;});

		auto swapButton = context.getWidgetById("swap");
		swapButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){swapFileEndian(file); return true;});

		reg1 = context.getWidgetById("reg1");
		reg2 = context.getWidgetById("reg2");
		reg3 = context.getWidgetById("reg3");
		reg4 = context.getWidgetById("reg4");
		printRegisters();

		memoryList = new MemoryView!DebugDcpu(&emulator.dcpu);
		auto memoryView = context.getWidgetById("memoryview");
		memoryView.setProperty!("list", List!dstring)(memoryList);
		memoryView.setProperty!("sliderPos")(0.0);

		writeln("\n----------------------------- Load end -----------------------------\n");
	}

	bool reset(Widget widget, PointerClickEvent event)
	{
		emulator.dcpu.reset();
		attachDevices();
		emulator.loadProgram(loadBinary(file));
		printRegisters();
		memoryList.listChangedSignal.emit();
		return true;
	}

	void runPause()
	{
		emulator.dcpu.isRunning = !emulator.dcpu.isRunning;

		if (emulator.dcpu.isRunning)
			runButton.setProperty!"text"("Pause");
		else
			runButton.setProperty!"text"("Run");
	}

	void step()
	{
		if (emulator.dcpu.isRunning) return;
		emulator.step();
		printRegisters();
		memoryList.listChangedSignal.emit();
	}

	override void update(double dt)
	{
		super.update(dt);

		if (emulator.dcpu.isRunning)
		{
			emulator.stepCycles(1666);
			printRegisters();
			memoryList.listChangedSignal.emit();
		}

		monitor.updateFrame();
		keyboard.updateFrame();
	}

	void disassembleMemory()
	{
		foreach(line; disassembleSome(emulator.dcpu.mem.memory, 0, 0))
		{
			writeln(line);
		}
	}

	void printRegisters()
	{
		with(emulator.dcpu)
		{
			reg1["text"] = format("PC 0x%04x SP 0x%04x EX 0x%04x IA 0x%04x", regs.pc, regs.sp, regs.ex, regs.ia);
		 	reg2["text"] = format(" A 0x%04x  B 0x%04x  C 0x%04x  X 0x%04x", regs.a, regs.b, regs.c, regs.x);
		 	reg3["text"] = format(" Y 0x%04x  Z 0x%04x  I 0x%04x  J 0x%04x", regs.y, regs.z, regs.i, regs.j);
		 	reg4["text"] = format("Ticks: %s Instructions: %s", emulator.dcpu.regs.cycles, emulator.dcpu.regs.instructions);
		}
	}

	override void closePressed()
	{
		isRunning = false;
	}
}