/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module dcpu.devices.floppydrive;

import std.stdio;
import std.math : abs;

import dcpu.devices.idevice;
import dcpu.emulator;
import dcpu.dcpu;

@trusted nothrow:

/++
 + Mackapar 3.5"
 + Floppy Drive (M35FD)
 + See 'docs/floppy drive.txt' for specification.
 +/

struct Sector
{
	ushort[512] data;
}

struct Floppy
{
	Sector[1440] sectors;
	bool isWriteProtected;
}

class FloppyDrive : IDevice
{
protected:
	Emulator _emulator;

	Floppy* _floppy;

	StateCode _state = StateCode.ready;
	ErrorCode _error = ErrorCode.none;

	ushort interruptMessage;

	ushort curentTrack; // Read-write head position.
	ushort targetSector; // Floppy sector number to read/write.
	ushort ramAddress; // DCPU ram address.

	// reading if true, writing otherwise.
	bool isReading;

	enum seekingTime = 2.4 / 1000.0; // seconds per track.
	enum sectorReadWriteSpeed = 512.0 / 30700.0; // seconds per sector.
	enum sectorSize = 512; // 512 words.
	enum sectorsPerTrack = 18;

public:
	this()
	{

	}

	Floppy* floppy(Floppy* newFloppy) @property
	{
		if (newFloppy == _floppy) return _floppy;

		if (newFloppy)
		{
			_floppy = newFloppy;
			setStateError(_floppy.isWriteProtected ? StateCode.readyWp : StateCode.ready);
		}
		else
		{
			_floppy = newFloppy;

			if (_state == StateCode.busy)
			{
				_emulator.dcpu.updateQueue.removeQueries(this);

				setStateError(StateCode.noMedia, ErrorCode.eject);

				return _floppy;
			}

			setStateError(StateCode.noMedia);
		}

		return _floppy;
	}

	override void attachEmulator(Emulator emulator)
	{
		_emulator = emulator;
	}

	/// Handles hardware interrupt and returns a number of cycles.
	override uint handleInterrupt()
	{
		ushort aRegister = _emulator.dcpu.reg_a; // A register
		ushort bRegister = _emulator.dcpu.reg_b; // B register

		switch(aRegister)
		{
			case 0: // Poll device
				_emulator.dcpu.reg_b = _state;
				_emulator.dcpu.reg_c = _error;
				_error = ErrorCode.none;

				return 0;

			case 1: // Set interrupt message
				interruptMessage = _emulator.dcpu.reg_x;

				return 0;

			case 2: // Read sector
				return setupReadWrite!true;

			case 3: // Write sector
				return setupReadWrite!false;

			default:
				break;
		}

		return 0;
	}

	override void updateFrame()
	{

	}

	override void handleUpdateQuery(ref size_t message, ref ulong delay)
	in
	{
		assert(_floppy);
	}
	body
	{
		if (isReading)
		{
			auto ram = _emulator.dcpu.mem;
			auto sector = _floppy.sectors[targetSector].data;

			foreach(i; 0..sectorSize)
			{
				ram[(ramAddress + i) & 0xFFFF] = sector[i];
			}

			delay = 0;
		}
		else
		{
			auto ram = _emulator.dcpu.mem;
			auto sector = _floppy.sectors[targetSector].data;

			foreach(i; 0..sectorSize)
			{
				sector[i] = ram[(ramAddress + i) & 0xFFFF];
			}

			delay = 0;
		}
	}

	/// Returns: 32 bit word identifying the hardware id.
	override uint hardwareId() @property
	{
		return 0x4fd524c5;
	}

	/// Returns: 16 bit word identifying the hardware version.
	override ushort hardwareVersion() @property
	{
		return 0x000b;
	}

	/// Returns: 32 bit word identifying the manufacturer
	override uint manufacturer() @property
	{
		return 0x1eb37e91;
	}

protected:

	uint setupReadWrite(bool read)()
	{
		bool validState;

		static if (read)
			validState = _state == StateCode.ready || _state == StateCode.readyWp;
		else
			validState = _state == StateCode.ready;

		if (validState)
		{
			isReading = read;
			targetSector = _emulator.dcpu.reg_x;
			ramAddress = _emulator.dcpu.reg_y;

			uint distance = abs(targetSector/sectorsPerTrack - curentTrack);

			uint ticksToWait = cast(uint)(((distance * seekingTime) + sectorReadWriteSpeed) * _emulator.dcpu.clockSpeed);

			_emulator.dcpu.updateQueue.addQuery(this, ticksToWait, 0);

			_emulator.dcpu.reg_b = 1;
			setStateError(StateCode.busy);

			return 0;
		}
		
		_emulator.dcpu.reg_b = 0;

		if (_state == StateCode.readyWp)
			setStateError(ErrorCode.floppyProtected);
		else if (_state == StateCode.noMedia)
			setStateError(ErrorCode.noMedia);
		else
			setStateError(ErrorCode.busy);

		return 0;
	}

	void setStateError(StateCode state, ErrorCode error)
	{
		_state = state;
		_error = error;
		stateErrorUpdated();
	}

	void setStateError(ErrorCode error)
	{
		_error = error;
		stateErrorUpdated();
	}

	void setStateError(StateCode state)
	{
		_state = state;
		stateErrorUpdated();
	}

	void stateErrorUpdated()
	{
		if (interruptMessage)
		{
			_emulator.triggerInterrupt(interruptMessage);
		}
	}
}

enum StateCode : ushort
{
	noMedia,
	ready,
	readyWp,
	busy,
}

enum ErrorCode : ushort
{
	none,
	busy,
	noMedia,
	floppyProtected,
	eject,
	badSector,
	broken = 0xFFFF
}
