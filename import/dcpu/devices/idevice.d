/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module dcpu.devices.idevice;

import dcpu.dcpu;
import dcpu.emulator;

@trusted nothrow:

abstract class IDevice
{

	/// Saves dcpu reference internally for future use.
	void attachDcpu(Dcpu* dcpu);

	/// Handles hardware interrupt and returns a number of cycles.
	uint handleInterrupt(ref Emulator emulator);

	/// Called every application frame.
	/// Can be used to update screens.
	void updateFrame();

	/// Must handle previosly posted update query.
	/// If next updates is not needed must set delay to zero.
	/// If set to non-zero will be called after delay cycles elapsed with provided message.
	void handleUpdateQuery(ref size_t message, ref ulong delay);

	/// Returns: 32 bit word identifying the hardware id.
	uint hardwareId() @property;

	/// Returns: 16 bit word identifying the hardware version.
	ushort hardwareVersion() @property;

	/// Returns: 32 bit word identifying the manufacturer
	uint manufacturer() @property;
}