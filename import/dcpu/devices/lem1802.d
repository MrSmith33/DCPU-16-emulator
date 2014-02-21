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
	Dcpu* _dcpu;
	Bitmap _bitmap;

	ushort fontAddress;
	ushort videoAddress;
	ushort paletteAddress;
	ushort borderColor;

	bool blinkPhase;

	enum numRows = 12;
	enum numCols = 32;
	enum charWidth = 4;
	enum charHeight = 8;
	enum borderSize = 4;
	enum screenWidth = numCols * charWidth + borderSize * 2;
	enum screenHeight = numRows * charHeight + borderSize * 2;

public:
	this()
	{
		_bitmap = new Bitmap(screenWidth, screenHeight, 4);
	}

	Bitmap bitmap() @property
	{
		return _bitmap;
	}

	override void attachDcpu(Dcpu* dcpu)
	{
		_dcpu = dcpu;
	}

	/// Handles hardware interrupt and returns a number of cycles.
	override uint handleInterrupt(ref Emulator emulator)
	{
		ushort aRegister = emulator.dcpu.reg[0]; // A register
		ushort bRegister = emulator.dcpu.reg[1]; // B register

		switch(aRegister)
		{
			case 0:
				mapScreen(bRegister);
				return 0;
			case 1:
				mapFont(bRegister);
				return 0;
			case 2:
				mapPalette(bRegister);
				return 0;
			case 3:
				setBorderColor(bRegister);
				return 0;
			case 4:
				dumpFont(bRegister);
				return 256;
			case 5:
				dumpPalette(bRegister);
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
		drawScreen();
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

protected:

	void drawScreen()
	{
		if (_dcpu is null) return;

		foreach(line; 0..numRows)
		{
			foreach(column; 0..numCols)
			{
				ushort memoryAddress = (videoAddress + line * numCols + column) & 0xFFFF;
				drawChar(_dcpu.mem[memoryAddress], column, line);
			}
		}

		_bitmap.dataChanged.emit();
	}

	void drawChar(ushort charData, size_t x, size_t y)
	{
		uint charIndex = charData & 0x7F;
		bool blinkBit  = (charData & 0x80) > 0;
		uint foreIndex = (charData & 0xF000) >> 12;
		uint backIndex = (charData & 0xF00) >> 8;

		ushort foreColor;
		ushort backColor;

		if (paletteAddress == 0)
		{
			foreColor = defaultPalette[foreIndex];
			backColor = defaultPalette[backIndex];
		}
		else
		{
			foreColor = _dcpu.mem[(paletteAddress + foreIndex) & 0xFFFF];
			backColor = _dcpu.mem[(paletteAddress + backIndex) & 0xFFFF];
		}

		uint foreRGB = ((foreColor & 0xF) << 16) * 17 +
						((foreColor & 0xF0) << 4) * 17 +
						((foreColor & 0xF00) >> 8) * 17 +
						0xFF000000;
		uint backRGB = ((backColor & 0xF) << 16) * 17 +
						((backColor & 0xF0) << 4) * 17 +
						((backColor & 0xF00) >> 8) * 17 +
						0xFF000000;

		if (blinkBit && blinkPhase)
		{
			fillCell(x, y, backRGB);
		}
		else if (fontAddress == 0)
		{
			drawCell(x, y, foreRGB, backRGB, defaultFont[charIndex]);
		}
		else
		{
			drawCell(x, y, foreRGB, backRGB, _dcpu.mem[(fontAddress + charIndex) & 0xFFFF]);
		}

		drawBorder();
	}

	void fillCell(size_t x, size_t y, uint color)
	{
		uint cellX = borderSize + x * charWidth;
		uint cellY = borderSize + y * charHeight;

		ubyte[] data = _bitmap.data;

		size_t dataPos; 
		uint[] cellLine;

		foreach(i; 0..8)
		{
			dataPos = cellX + _bitmap.size.x * cellY + i;
			cast(uint[4])data[dataPos .. dataPos + 16] = [color, color, color, color];
		}
	}

	void drawCell(size_t x, size_t y, uint foreColor, uint backColor, uint charData)
	{
		uint cellX = borderSize + x * charWidth;
		uint cellY = borderSize + y * charHeight;

		ubyte[] data = _bitmap.data;

		size_t dataPos; 
		uint[] cellLine;

		foreach(i; 0..8)
		{
			dataPos = cellX + _bitmap.size.x * cellY + i;
			cellLine = cast(uint[4])data[dataPos .. dataPos + 16];

			if (charData & (1 << i + 8))
			{
				cast(uint[1])cellLine[0..4] = foreColor;
			}
			else
			{
				cast(uint[1])cellLine[0..4] = backColor;
			}

			if (charData & (1 << i))
			{
				cast(uint[1])cellLine[4..8] = foreColor;
			}
			else
			{
				cast(uint[1])cellLine[4..8] = backColor;
			}

			if (charData & (1 << i + 24))
			{
				cast(uint[1])cellLine[8..12] = foreColor;
			}
			else
			{
				cast(uint[1])cellLine[8..12] = backColor;
			}

			if (charData & (1 << i + 16))
			{
				cast(uint[1])cellLine[12..16] = foreColor;
			}
			else
			{
				cast(uint[1])cellLine[12..16] = backColor;
			}
		}
	}

	void drawBorder()
	{

	}

	void mapScreen(ushort b)
	{

	}

	void mapFont(ushort b)
	{

	}

	void mapPalette(ushort b)
	{
		
	}

	void setBorderColor(ushort b)
	{
		borderColor = b & 0xF;
	}

	void dumpFont(ushort b)
	{

	}

	void dumpPalette(ushort b)
	{
		
	}
}

static immutable ushort[] defaultPalette = [
	0x000, 0x00a, 0x0a0, 0x0aa,
	0xa00, 0xa0a, 0xa50, 0xaaa,
	0x555, 0x55f, 0x5f5, 0x5ff,
	0xf55, 0xf5f, 0xff5, 0xfff
];

static immutable uint[] defaultFont = [
	0xb79e388e, 0x722c75f4, 0x19bb7f8f, 0x85f9b158,
	0x242e2400, 0x082a0800, 0x00080000, 0x08080808,
	0x00ff0000, 0x00f80808, 0x08f80000, 0x080f0000,
	0x000f0808, 0x00ff0808, 0x08f80808, 0x08ff0000,
	0x080f0808, 0x08ff0808, 0x663399cc, 0x993366cc,
	0xfef8e080, 0x7f1f0701, 0x01071f7f, 0x80e0f8fe,
	0x5500aa00, 0x55aa55aa, 0xffaaff55, 0x0f0f0f0f,
	0xf0f0f0f0, 0x0000ffff, 0xffff0000, 0xffffffff,
	0x00000000, 0x005f0000, 0x03000300, 0x3e143e00,
	0x266b3200, 0x611c4300, 0x36297650, 0x00020100,
	0x1c224100, 0x41221c00, 0x14081400, 0x081c0800,
	0x40200000, 0x08080800, 0x00400000, 0x601c0300,
	0x3e493e00, 0x427f4000, 0x62594600, 0x22493600,
	0x0f087f00, 0x27453900, 0x3e493200, 0x61190700,
	0x36493600, 0x26493e00, 0x00240000, 0x40240000,
	0x08142200, 0x14141400, 0x22140800, 0x02590600,
	0x3e595e00, 0x7e097e00, 0x7f493600, 0x3e412200,
	0x7f413e00, 0x7f494100, 0x7f090100, 0x3e417a00,
	0x7f087f00, 0x417f4100, 0x20403f00, 0x7f087700,
	0x7f404000, 0x7f067f00, 0x7f017e00, 0x3e413e00,
	0x7f090600, 0x3e617e00, 0x7f097600, 0x26493200,
	0x017f0100, 0x3f407f00, 0x1f601f00, 0x7f307f00,
	0x77087700, 0x07780700, 0x71494700, 0x007f4100,
	0x031c6000, 0x417f0000, 0x02010200, 0x80808000,
	0x00010200, 0x24547800, 0x7f443800, 0x38442800,
	0x38447f00, 0x38545800, 0x087e0900, 0x48543c00,
	0x7f047800, 0x047d0000, 0x20403d00, 0x7f106c00,
	0x017f0000, 0x7c187c00, 0x7c047800, 0x38443800,
	0x7c140800, 0x08147c00, 0x7c040800, 0x48542400,
	0x043e4400, 0x3c407c00, 0x1c601c00, 0x7c307c00,
	0x6c106c00, 0x4c503c00, 0x64544c00, 0x08364100,
	0x00770000, 0x41360800, 0x02010201, 0x02050200
];