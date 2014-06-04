/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module application;

import std.file : read, write, exists;
import std.path : setExtension;
import std.range;
import std.stdio : writeln;
import std.string : format;

import anchovy.core.input;

import anchovy.graphics.windows.glfwwindow;
import anchovy.graphics.texture;
import anchovy.graphics.bitmap;
import anchovy.gui;
import anchovy.gui.guirenderer;

import anchovy.gui.application.application;

import emulator.dcpu.emulator;
import emulator.dcpu.disassembler;
import emulator.dcpu.memoryanalyzer;
import emulator.dcpu.dcpu;
import emulator.dcpu.updatequeue;
import emulator.dcpu.memoryview;

import emulator.dcpu.devices.lem1802;
import emulator.dcpu.devices.genericclock;
import emulator.dcpu.devices.generickeyboard;
import emulator.dcpu.devices.floppydrive;

class EmulatorApplication : Application!GlfwWindow
{
	this(uvec2 windowSize, string caption)
	{
		super(windowSize, caption);
	}

	Emulator!Dcpu emulator;
	Lem1802!Dcpu monitor;
	GenericClock!Dcpu clock;
	GenericKeyboard!Dcpu keyboard;
	FloppyDrive!Dcpu floppyDrive;
	Widget registerView;
	MemoryView!Dcpu memoryList;
	MemoryAnalyzer!Dcpu memAnalyzer;

	bool isRunningForward = true;
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
		emulator.dcpu.updateQueue = new UpdateQueue!Dcpu;
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

		emulator = new Emulator!Dcpu();
		monitor = new Lem1802!Dcpu;
		clock = new GenericClock!Dcpu;
		keyboard = new GenericKeyboard!Dcpu;
		floppyDrive = new FloppyDrive!Dcpu;
		floppyDrive.floppy = new Floppy;
		memAnalyzer = new MemoryAnalyzer!Dcpu(&emulator.dcpu);
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

		auto stepButtonHandler = delegate bool(Widget widget, PointerClickEvent event)
		{
			step(widget.getPropertyAs!("stepSize", int));
			return true;
		};

		context.getWidgetById("unstep").addEventHandler(stepButtonHandler);
		context.getWidgetById("unstep10").addEventHandler(stepButtonHandler);
		context.getWidgetById("unstep100").addEventHandler(stepButtonHandler);
		context.getWidgetById("unstep1000").addEventHandler(stepButtonHandler);
		context.getWidgetById("step").addEventHandler(stepButtonHandler);
		context.getWidgetById("step10").addEventHandler(stepButtonHandler);
		context.getWidgetById("step100").addEventHandler(stepButtonHandler);
		context.getWidgetById("step1000").addEventHandler(stepButtonHandler);

		auto speedButtonHandler = delegate bool(Widget widget, PointerClickEvent event)
		{
			setCpuClockSpeed(cast(uint)(widget.getPropertyAs!("speed", int)));
			return true;
		};

		context.getWidgetById("speed10").addEventHandler(speedButtonHandler);
		context.getWidgetById("speed100").addEventHandler(speedButtonHandler);
		context.getWidgetById("speed1k").addEventHandler(speedButtonHandler);
		context.getWidgetById("speed10k").addEventHandler(speedButtonHandler);
		context.getWidgetById("speed100k").addEventHandler(speedButtonHandler);
		context.getWidgetById("speed500k").addEventHandler(speedButtonHandler);
		context.getWidgetById("speed1m").addEventHandler(speedButtonHandler);

		auto runBackwardButton = context.getWidgetById("runback");
		runBackwardButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){runBackward(); return true;});

		auto runForwardButton = context.getWidgetById("run");
		runForwardButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){runForward(); return true;});

		auto pauseButton = context.getWidgetById("pause");
		pauseButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){pause(); return true;});

		auto resetButton = context.getWidgetById("reset");
		resetButton.addEventHandler(&reset);

		auto disassembleButton = context.getWidgetById("disasm");
		disassembleButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){disassembleMemory(); return true;});

		auto swapButton = context.getWidgetById("swap");
		swapButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){swapFileEndian(file); return true;});

		auto statsButton = context.getWidgetById("stats");
		statsButton.addEventHandler(delegate bool(Widget widget, PointerClickEvent event){emulator.stats.print(); return true;});

		registerView = context.getWidgetById("registerView");
		foreach(i; 0..17) context.createWidget("label", registerView);
		printRegisters();


		memoryList = new MemoryView!Dcpu(&emulator.dcpu);
		auto memoryView = context.getWidgetById("memoryview");
		memoryView.setProperty!("list", List!dstring)(memoryList);
		memoryView.setProperty!("sliderPos")(0.0);

		auto collapseZerosCheck = context.getWidgetById("collapseZeros");
		memoryList.collapseZeros = collapseZerosCheck.getPropertyAs!("isChecked", bool);
		collapseZerosCheck
			.property("isChecked")
			.valueChanged
			.connect((FlexibleObject a, Variant b)
			{
				memoryList.collapseZeros = b.get!bool;
				writeln(b.get!bool);
				updateMemoryView();
			});

		updateMemoryView();

		writeln("\n----------------------------- Load end -----------------------------\n");
	}

	bool reset(Widget widget, PointerClickEvent event)
	{
		emulator.reset();
		attachDevices();
		emulator.loadProgram(loadBinary(file));
		printRegisters();
		updateMemoryView();

		return true;
	}

	void pause()
	{
		emulator.dcpu.isRunning = false;
	}

	void runBackward()
	{
		emulator.dcpu.isRunning = true;
		isRunningForward = false;
	}

	void runForward()
	{
		emulator.dcpu.isRunning = true;
		isRunningForward = true;
	}

	void step(long numFrames)
	{
		if (emulator.dcpu.isRunning) return;
		
		if (numFrames < 0)
			emulator.unstep(cast(ulong)(-numFrames));
		else
			emulator.step(cast(ulong)(numFrames));

		printRegisters();
		updateMemoryView();
	}

	void setCpuClockSpeed(uint clockSpeed)
	{
		emulator.dcpu.clockSpeed = clockSpeed;
	}

	override void update(double dt)
	{
		super.update(dt);

		if (emulator.dcpu.isRunning)
		{
			if (isRunningForward)
				emulator.stepCycles(emulator.dcpu.clockSpeed / 60);
			else
				emulator.unstepCycles(emulator.dcpu.clockSpeed / 60);

			printRegisters();
			updateMemoryView();
		}

		monitor.updateFrame();
		keyboard.updateFrame();
	}

	void disassembleMemory()
	{
		memAnalyzer.buildMemoryMap();

		auto file = File(file.setExtension("dis.asm"), "w");

		file.lockingTextWriter.put(
		disassembleSome(cast(ushort[])emulator.dcpu.mem.observableArray[], memAnalyzer.memoryMap, 0, 0)
			.joiner("\n").array
		);
	}

	void printRegisters()
	{
		with(emulator.dcpu)
		{
			auto lines = registerView.getPropertyAs!("children", Widget[]);
		 	lines[ 0]["text"] = format("PC %04x | [PC] %04x", regs.pc, mem[regs.pc]);
		 	lines[ 1]["text"] = format("SP %04x | [SP] %04x", regs.sp, mem[regs.sp]);
		 	lines[ 2]["text"] = format("EX %04x | [EX] %04x", regs.ex, mem[regs.ex]);
		 	lines[ 3]["text"] = format("IA %04x | [IA] %04x", regs.ia, mem[regs.ia]);
		 	lines[ 4]["text"] = format(" A %04x | [ A] %04x", regs.a , mem[regs.a ]);
		 	lines[ 5]["text"] = format(" B %04x | [ B] %04x", regs.b , mem[regs.b ]);
		 	lines[ 6]["text"] = format(" C %04x | [ C] %04x", regs.c , mem[regs.c ]);
		 	lines[ 7]["text"] = format(" X %04x | [ X] %04x", regs.x , mem[regs.x ]);
		 	lines[ 8]["text"] = format(" Y %04x | [ Y] %04x", regs.y , mem[regs.y ]);
		 	lines[ 9]["text"] = format(" Z %04x | [ Z] %04x", regs.z , mem[regs.z ]);
		 	lines[10]["text"] = format(" I %04x | [ I] %04x", regs.i , mem[regs.i ]);
		 	lines[11]["text"] = format(" J %04x | [ J] %04x", regs.j , mem[regs.j ]);
		 	lines[12]["text"] = format("Ticks: %s", regs.cycles);
		 	lines[13]["text"] = "Instructions done";
		 	lines[14]["text"] = format("%s", regs.instructions);
		 	lines[15]["text"] = "Undo size:";
		 	lines[16]["text"] = format("%sb", emulator.undoStackSize);
		}
	}

	void updateMemoryView()
	{
		memoryList.update();
		memoryList.listChangedSignal.emit();
	}

	override void closePressed()
	{
		isRunning = false;
	}
}