/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module dcpu.devices.idevice;

import dcpu.dcpu;
import dcpu.emulator;

@safe nothrow:

interface IDevice
{
	/// Handles hardware interrupt and returns a number of cycles.
	uint handleInterrupt(ref Emulator emulator);

	void update();

	/// Returns: 32 bit word identifying the hardware id.
	uint hardwareId() @property;

	/// Returns: 16 bit word identifying the hardware version.
	ushort hardwareVersion() @property;

	/// Returns: 32 bit word identifying the manufacturer
	uint manufacturer() @property;
}