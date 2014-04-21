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
import dcpu.memoryanalyzer;
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
	Widget registerView;
	MemoryView!DebugDcpu memoryList;
	MemoryAnalyzer!DebugDcpu memAnalyzer;

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
		memAnalyzer = new MemoryAnalyzer!DebugDcpu(&emulator.dcpu);
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

		auto statsButton = context.getWidgetById("stats");
		statsButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){emulator.stats.print(); return true;});

		registerView = context.getWidgetById("registerView");
		foreach(i; 0..15) context.createWidget("label", registerView);
		printRegisters();


		memoryList = new MemoryView!DebugDcpu(&emulator.dcpu);
		auto memoryView = context.getWidgetById("memoryview");
		memoryView.setProperty!("list", List!dstring)(memoryList);
		memoryView.setProperty!("sliderPos")(0.0);

		writeln("\n----------------------------- Load end -----------------------------\n");
	}

	bool reset(Widget widget, PointerClickEvent event)
	{
		emulator.reset();
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
		memAnalyzer.buildMemoryMap();

		writeln("\nBlocks");
		foreach(block; memAnalyzer.memoryMap.blocks)
		{
			writefln("    %s",*block);
		}

		writeln("\nTransitions");
		foreach(transition; memAnalyzer.memoryMap.transitions)
		{
			writefln("    %s",*transition);
		}

		writeln("\nLabels");
		foreach(label; memAnalyzer.memoryMap.labels)
		{
			writefln("    %s",*label);
		}

		writeln("\nDisassembly");
		foreach(line; disassembleSome(emulator.dcpu.mem.memory, memAnalyzer.memoryMap, 0, 0))
		{
			writefln("%s",line);
		}
	}

	void printRegisters()
	{
		with(emulator.dcpu)
		{
		 	registerView.getPropertyAs!("children", Widget[])[ 0]["text"] = format("PC %04x | [PC] %04x", regs.pc, mem[regs.pc]);
		 	registerView.getPropertyAs!("children", Widget[])[ 1]["text"] = format("SP %04x | [SP] %04x", regs.sp, mem[regs.sp]);
		 	registerView.getPropertyAs!("children", Widget[])[ 2]["text"] = format("EX %04x | [EX] %04x", regs.ex, mem[regs.ex]);
		 	registerView.getPropertyAs!("children", Widget[])[ 3]["text"] = format("IA %04x | [IA] %04x", regs.ia, mem[regs.ia]);
		 	registerView.getPropertyAs!("children", Widget[])[ 4]["text"] = format(" A %04x | [ A] %04x", regs.a , mem[regs.a ]);
		 	registerView.getPropertyAs!("children", Widget[])[ 5]["text"] = format(" B %04x | [ B] %04x", regs.b , mem[regs.b ]);
		 	registerView.getPropertyAs!("children", Widget[])[ 6]["text"] = format(" C %04x | [ C] %04x", regs.c , mem[regs.c ]);
		 	registerView.getPropertyAs!("children", Widget[])[ 7]["text"] = format(" X %04x | [ X] %04x", regs.x , mem[regs.x ]);
		 	registerView.getPropertyAs!("children", Widget[])[ 8]["text"] = format(" Y %04x | [ Y] %04x", regs.y , mem[regs.y ]);
		 	registerView.getPropertyAs!("children", Widget[])[ 9]["text"] = format(" Z %04x | [ Z] %04x", regs.z , mem[regs.z ]);
		 	registerView.getPropertyAs!("children", Widget[])[10]["text"] = format(" I %04x | [ I] %04x", regs.i , mem[regs.i ]);
		 	registerView.getPropertyAs!("children", Widget[])[11]["text"] = format(" J %04x | [ J] %04x", regs.j , mem[regs.j ]);
		 	registerView.getPropertyAs!("children", Widget[])[12]["text"] = format("Ticks: %s", regs.cycles);
		 	registerView.getPropertyAs!("children", Widget[])[13]["text"] = "Instructions done";
		 	registerView.getPropertyAs!("children", Widget[])[14]["text"] = format("%s", regs.instructions);
		}
	}

	override void closePressed()
	{
		isRunning = false;
	}
}