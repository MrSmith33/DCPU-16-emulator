/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module application;

import std.stdio : writeln;
import std.string : format;
import std.file : read, write;

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

class EmulatorApplication : Application!GlfwWindow
{
	this(uvec2 windowSize, string caption)
	{
		super(windowSize, caption);
	}

	Emulator em;
	Lem1802 monitor;
	GenericClock clock;
	GenericKeyboard keyboard;
	Widget reg1, reg2, reg3, reg4;
	MemoryView memoryList;

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
	}

	ushort[] loadBinary(string filename)
	{
		ubyte[] binary = cast(ubyte[])read(filename);
		assert(binary.length % 2 == 0);
		return cast(ushort[])binary;
	}

	void attachDevices()
	{
		em.dcpu.updateQueue = new UpdateQueue;
		em.attachDevice(monitor);
		em.attachDevice(keyboard);
		em.attachDevice(clock);
	}

	override void load(in string[] args)
	{
		if (args.length > 1)
		{
			file = args[1];
			writefln("loading '%s'", file);
		}

		fpsHelper.limitFps = true;

		em = new Emulator();
		monitor = new Lem1802;
		clock = new GenericClock;
		keyboard = new GenericKeyboard;
		attachDevices();
		
		em.loadProgram(loadBinary(file));

		// ----------------------------- Creating widgets -----------------------------
		templateManager.parseFile("dcpu.sdl");

		auto mainLayer = context.createWidget("mainLayer");
		context.addRoot(mainLayer);
	
		auto monitorWidget = context.getWidgetById("monitor");
		auto texture = new Texture(monitor.bitmap, TextureTarget.target2d, TextureFormat.rgba);
		monitorWidget.setProperty!("texture")(texture);
		monitorWidget.addEventHandler(delegate bool(Widget widget, KeyPressEvent event){
			writeln("KeyPressEvent");
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
		stepButton10.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){em.stepInstructions(10); printRegisters(); return true;});
		auto stepButton100 = context.getWidgetById("step100");
		stepButton100.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){em.stepInstructions(100); printRegisters(); return true;});
		

		runButton = context.getWidgetById("run");
		runButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){runPause(); return true;});

		auto resetButton = context.getWidgetById("reset");
		resetButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){
			em.reset();
			attachDevices();
			em.loadProgram(loadBinary(file));
			printRegisters();
			memoryList.listChangedSignal.emit();
			return true;
		});

		auto dumpButton = context.getWidgetById("dump");
		dumpButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){dump(); return true;});

		auto disassembleButton = context.getWidgetById("disasm");
		disassembleButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){disassembleMemory(); return true;});

		auto swapButton = context.getWidgetById("swap");
		swapButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){swapFileEndian(file); return true;});

		reg1 = context.getWidgetById("reg1");
		reg2 = context.getWidgetById("reg2");
		reg3 = context.getWidgetById("reg3");
		reg4 = context.getWidgetById("reg4");
		printRegisters();

		memoryList = new MemoryView(&em.dcpu);
		auto memoryView = context.getWidgetById("memoryview");
		memoryView.setProperty!("list", List!dstring)(memoryList);
		memoryView.setProperty!("sliderPos")(0.0);

		writeln("\n----------------------------- Load end -----------------------------\n");

		/*foreach(i, code; bareScancodes)
		{
			writefln("%03s %03s %s %03s %s", i, code, cast(char)code, shiftScancodes[i], cast(char)shiftScancodes[i]);
		}*/
	}

	void runPause()
	{
		dcpuRunning = !dcpuRunning;
		if (dcpuRunning)
			runButton.setProperty!"text"("Pause");
		else
			runButton.setProperty!"text"("Run");
	}

	void step()
	{
		if (dcpuRunning) return;
		em.step();
		printRegisters();
		memoryList.listChangedSignal.emit();
	}

	void dump()
	{
		printMem(0, 80, 8, em.dcpu);
	}

	override void update(double dt)
	{
		super.update(dt);

		if (dcpuRunning)
		{
			em.stepCycles(1666);
			printRegisters();
			memoryList.listChangedSignal.emit();
		}

		monitor.updateFrame();
		keyboard.updateFrame();
	}

	void disassembleMemory()
	{
		foreach(line; disassemble(em.dcpu.mem[0..80]))
		{
			writeln(line);
		}
	}

	void printMem(ushort start, ushort end, ushort padding, ref Dcpu dcpu)
	{
		for(uint i = start; i < end; i += padding)
		{
			writef("%04x: ", i);
			for(uint pad = 0; pad < padding; ++pad)
			{
				if (end <= i+pad)
					writef("%04x ", 0);
				else
					writef("%04x ", dcpu.mem[i+pad]);
			}
			writeln;
		}
	}

	void printRegisters()
	{
		with(em.dcpu)
		{
			reg1["text"] = format("PC 0x%04x SP 0x%04x EX 0x%04x IA 0x%04x", reg_pc, reg_sp, reg_ex, reg_ia);
		 	reg2["text"] = format(" A 0x%04x  B 0x%04x  C 0x%04x  X 0x%04x", reg[0], reg[1], reg[2], reg[3]);
		 	reg3["text"] = format(" Y 0x%04x  Z 0x%04x  I 0x%04x  J 0x%04x", reg[4], reg[5], reg[6], reg[7]);
		 	reg4["text"] = format("Ticks: %s", em.dcpu.cycles);
		}
	}

	override void closePressed()
	{
		isRunning = false;
	}
}