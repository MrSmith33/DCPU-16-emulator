/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module dcpu.devices.lem1802;

import anchovy.graphics.bitmap;

import dcpu.devices.idevice;
import dcpu.emulator;
import dcpu.dcpu;

@safe nothrow:

/++
 + NE_LEM1802 v1.0
 + Low Energy Monitor
 + See 'docs/LEM1802 monitor.txt' for specification.
 +/

class Lem1802 : IDevice
{
protected:
	Bitmap _bitmap;
	Dcpu* _dcpu;


public:
	this()
	{
		
	}

	override void attachDcpu(Dcpu* dcpu)
	{
		
	}

	/// Handles hardware interrupt and returns a number of cycles.
	override uint handleInterrupt(ref Emulator emulator)
	{
		ushort aRegister = emulator.dcpu.reg[0]; // A register
		ushort bRegister = emulator.dcpu.reg[1]; // B register

		switch(aRegister)
		{
			case 0:
				mapScreen(bRegister, emulator.dcpu);
				return 0;
			case 1:
				mapFont(bRegister, emulator.dcpu);
				return 0;
			case 2:
				mapPalette(bRegister, emulator.dcpu);
				return 0;
			case 3:
				setBorderColor(bRegister, emulator.dcpu);
				return 0;
			case 4:
				dumpFont(bRegister, emulator.dcpu);
				return 256;
			case 5:
				dumpPalette(bRegister, emulator.dcpu);
				return 16;
			default:
				break;
		}

		return 0;
	}

	/// Called every application frame.
	/// Can be used to update screens.
	override void update()
	{

	}

	/// Returns: 32 bit word identifying the hardware id.
	override uint hardwareId() @property
	{
		return 0x7349f615;
	}

	/// Returns: 16 bit word identifying the hardware version.
	override ushort hardwareVersion() @property
	{
		return 0x1802;
	}

	/// Returns: 32 bit word identifying the manufacturer
	override uint manufacturer() @property
	{
		return 0x1c6c8b36;
	}



	void drawScreen()
	{

	}

	void mapScreen(ushort b, in Dcpu dcpu)
	{

	}

	void mapFont(ushort b, in Dcpu dcpu)
	{

	}

	void mapPalette(ushort b, in Dcpu dcpu)
	{
		
	}

	void setBorderColor(ushort b, in Dcpu dcpu)
	{

	}

	void dumpFont(ushort b, ref Dcpu dcpu)
	{

	}

	void dumpPalette(ushort b, ref Dcpu dcpu)
	{
		
	}
}