/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module application;

import std.stdio : writeln;
import std.string : format;
import std.file : read;

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

import dcpu.devices.lem1802;
import dcpu.devices.genericclock;

class EmulatorApplication : Application!GlfwWindow
{
	this(uvec2 windowSize, string caption)
	{
		super(windowSize, caption);
	}

	Emulator em;
	Lem1802 monitor;
	Widget reg1, reg2, reg3;
	bool dcpuRunning = false;
	Widget runButton;

	override void load(in string[] args)
	{
		fpsHelper.limitFps = true;

		em = new Emulator();
		monitor = new Lem1802;
		em.dcpu.updateQueue = new UpdateQueue;
		em.attachDevice(monitor);
		em.attachDevice(new GenericClock);
		writeln(monitor.bitmap.size);

		em.loadProgram(cast(ushort[])read("hello.bin"));


		//em.stepInstructions(23);

		writeln(em.dcpu.mem.length);
		printMem(48, 63, 8, em.dcpu);
		writeln("Cycles: ", em.dcpu.cycles);

		// ----------------------------- Creating widgets -----------------------------
		templateManager.parseFile("dcpu.sdl");

		auto mainLayer = context.createWidget("mainLayer");
		context.addRoot(mainLayer);
	
		auto monitorWidget = context.getWidgetById("monitor");
		auto texture = new Texture(monitor.bitmap, TextureTarget.target2d, TextureFormat.rgba);
		monitorWidget.setProperty!("texture")(texture);

		auto stepButton = context.getWidgetById("step");
		stepButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){step(); return true;});

		runButton = context.getWidgetById("run");
		runButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){runPause(); return true;});

		auto dumpButton = context.getWidgetById("dump");
		dumpButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){dump(); return true;});

		auto disassembleButton = context.getWidgetById("disasm");
		disassembleButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){disassembleMemory(); return true;});

		reg1 = context.getWidgetById("reg1");
		reg2 = context.getWidgetById("reg2");
		reg3 = context.getWidgetById("reg3");
		printRegisters();

		writeln("\n----------------------------- Load end -----------------------------\n");
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
	}

	void dump()
	{
		printMem(0, 80, 8, em.dcpu);
	}

	override void update(double dt)
	{
		monitor.updateFrame();
	
		if (dcpuRunning)
		{
			em.stepCycles(1666);
			printRegisters();
		}

		super.update(dt);
	}

	void disassembleMemory()
	{
		foreach(line; disassemble(em.dcpu.mem[0..80]))
			writeln(line);
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
			reg1["text"] = format("PC 0x%04x SP 0x%04x EX 0x%04x IA 0x%04x", pc, sp, ex, ia);
		 	reg2["text"] = format(" A 0x%04x  B 0x%04x  C 0x%04x  X 0x%04x", reg[0], reg[1], reg[2], reg[3]);
		 	reg3["text"] = format(" Y 0x%04x  Z 0x%04x  I 0x%04x  J 0x%04x", reg[4], reg[5], reg[6], reg[7]);
		}
	}

	override void closePressed()
	{
		isRunning = false;
	}
}