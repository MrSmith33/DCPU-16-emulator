/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module dcpu.devices.generickeyboard;

import std.array;
import std.bitmanip;
import std.stdio;

import anchovy.core.input;
import anchovy.graphics.bitmap;

import dcpu.devices.idevice;
import dcpu.emulator;
import dcpu.dcpu;

@trusted nothrow:

/++
 + Generic keyboard (compatible) v1.0
 + See 'docs/generic keyboard.txt' for specification.
 +/

class GenericKeyboard : IDevice
{
protected:
	Emulator _emulator;
	ushort interruptMessage;
	ushort[] buffer;
	BitArray pressedKeys;

	/// 
	bool triggeredInterrupt = false;

public:

	this()
	{
		pressedKeys.length = 0x91 + 1; // control + 1. total keys
	}

	override void attachEmulator(Emulator emulator)
	{
		_emulator = emulator;
		reset();
	}

	override uint handleInterrupt()
	{
		ushort aRegister = _emulator.dcpu.reg[0]; // A register
		ushort bRegister = _emulator.dcpu.reg[1]; // B register

		switch(aRegister)
		{
			case 0:
				buffer.length = 0;
				return 0;
			case 1:
				if (buffer.length > 0)
				{
					_emulator.dcpu.reg[2] = buffer.front;
					buffer.popFront;
				}
				else
				{
					_emulator.dcpu.reg[2] = 0;
				}
				return 0;
			case 2:
				if (bRegister <= 0x91)
					_emulator.dcpu.reg[2] = pressedKeys[bRegister];
				else
					_emulator.dcpu.reg[2] = 0;
				return 0;
			case 3:
				interruptMessage = bRegister;
				return 0;
			default:
				break;
		}

		return 0;
	}

	void onKey(KeyCode keyCode, KeyModifiers modifiers, bool pressed)
	{
		if (interruptMessage == 0) return;

		ushort code = 0;

		if (keyCode <= 348)
		{
			if (modifiers & KeyModifiers.SHIFT)
			{
				code = shiftScancodes[keyCode];
			}
			else
			{
				code = bareScancodes[keyCode];
			}
		}

		if (code != 0)
		{
			buffer ~= code;
			writefln("key %s %s", cast(char)code, pressed ? "pressed" : "released");

			if (code >= 0x09 && code <= 0x91)
			{
				if (pressed)
				{
					/*if ((code >= 0x20 && code <= 0x7f) || code == 0x09) // Printable
					{

					}*/
					pressedKeys[code] = true;
				}
				else
				{
					pressedKeys[code] = false;
				}
			}

			if (!triggeredInterrupt)
			{
				_emulator.triggerInterrupt(interruptMessage);
				triggeredInterrupt = true;
			}
		}
	}

	/// Called when application does rendering
	override void updateFrame()
	{
		triggeredInterrupt = false;
	}

	override void handleUpdateQuery(ref size_t message, ref ulong delay)
	{
		triggeredInterrupt = false;
	}

	/// Returns: 32 bit word identifying the hardware id.
	override uint hardwareId() @property
	{
		return 0x30cf7406;
	}

	/// Returns: 16 bit word identifying the hardware version.
	override ushort hardwareVersion() @property
	{
		return 1;
	}

	/// Returns: 32 bit word identifying the manufacturer
	override uint manufacturer() @property
	{
		return 0;
	}

protected:
	void reset()
	{
		pressedKeys.length = 0;
		pressedKeys.length = 0x91 + 1; // control + 1. total keys
	}
}

// Mapped from anchovy.core.input.KeyCode to generic keyboard codes. (Mostly ASCII)
// On 0x09 TAB mapping added.

// When shift key IS NOT pressed. From 0 to 348
static immutable ushort[] bareScancodes = [
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 39, 0, 0, 0, 0, 44, 45, 46, 47, 48, 49, 50,
51, 52, 53, 54, 55, 56, 57, 0, 59, 0, 61, 0, 0, 0, 97, 98, 99, 100, 101, 102, 103,
104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119,
120, 121, 122, 91,
92, 93, 0, 0, 96, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0x11, 0x9, 0x10, 0x12, 0x13, 0x83, 0x82, 0x81, 0x80, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 48, 49, 50,
51, 52, 53, 54, 55, 56, 57, 46, 47, 42, 45, 43, 0x11, 61, 0, 0, 0, 0x90, 0x91,
0, 0, 0x90, 0x91, 0, 0, 0,
];

// When shift key IS pressed. From 0 to 348
static immutable ushort[] shiftScancodes = [
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 34, 0, 0, 0, 0, 60, 95, 62, 63, 33, 64, 35,
36, 37, 94, 38, 42, 40, 41, 0, 58, 0, 43, 0, 0, 0, 65, 66, 67, 68, 69, 70, 71,
72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 123,
124, 125, 0, 0, 126, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0x11, 0x9, 0x10, 0x12, 0x13, 0x83, 0x82, 0x81, 0x80, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 48, 49, 50,
51, 52, 53, 54, 55, 56, 57, 46, 47, 42, 45, 43, 0x11, 61, 0, 0, 0, 0x90, 0x91,
0, 0, 0x90, 0x91, 0, 0, 0,
];