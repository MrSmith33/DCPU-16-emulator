module dcpu.devices.idevice;

import dcpu.dcpu;

interface IDevice
{
	/// Handles hardware interrupt and returns a number of cycles.
	uint handleInterrupt(ref Dcpu dcpu);

	void update();

	/// Returns: 32 bit word identifying the hardware id.
	uint hardwareId() @property;

	/// Returns: 16 bit word identifying the hardware version.
	ushort version() @property;

	/// Returns: 32 bit word identifying the manufacturer
	uint manufacturer() @property;
}