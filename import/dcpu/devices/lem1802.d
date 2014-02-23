/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module dcpu.devices.lem1802;

import std.stdio;

import anchovy.graphics.bitmap;

import dcpu.devices.idevice;
import dcpu.emulator;
import dcpu.dcpu;

@trusted nothrow:

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
	bool enabled = false; 
	bool splash = false;

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

	override void attachEmulator(Emulator emulator)
	{
		_dcpu = &emulator.dcpu;
		(cast(uint[])_bitmap.data)[] = 0xFF000000;
		enabled = false;
		splash = false;
		fontAddress = 0;
		videoAddress = 0;
		paletteAddress = 0;
		borderColor = 0;

		_bitmap.dataChanged.emit();
	}

	/// Handles hardware interrupt and returns a number of cycles.
	override uint handleInterrupt(Emulator emulator)
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
	override void updateFrame()
	{
		if (enabled && !splash)
		{
			repaintScreen();
		}
	}

	override void handleUpdateQuery(ref size_t message, ref ulong delay)
	{
		//writefln("1 handleUpdateQuery message %s delay %s", message, delay);
		if (message == 0) // remove splash
		{
			message = 1;
			delay = 70000;
			splash = false;
		}
		else if (message == 1)
		{
			blinkPhase = !blinkPhase;
			delay = 70000;
		}
		else
			writefln("unknown message %s", message);

		//writefln("2 handleUpdateQuery message %s delay %s", message, delay);
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

	void repaintScreen()
	{
		if (_dcpu is null || videoAddress == 0) return;

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
		ushort foreIndex = (charData & 0xF000) >> 12;
		ushort backIndex = (charData & 0xF00) >> 8;

		uint foreRGB = paletteToRGB8(foreIndex);
		uint backRGB = paletteToRGB8(backIndex);

		if (blinkBit && blinkPhase)
		{
			fillCell(x, y, backRGB);
		}
		else if (fontAddress == 0)
		{
			drawCell(x, y, foreRGB, backRGB, (cast(uint[])defaultFont)[charIndex]);
		}
		else
		{
			drawCell(x, y, foreRGB, backRGB, _dcpu.mem[(fontAddress + charIndex) & 0xFFFF] +
					_dcpu.mem[(fontAddress + charIndex + 1) & 0xFFFF] << 16);
		}

		drawBorder();
	}

	uint paletteToRGB8(ushort colorIndex)
	{
		ushort rgb12color;
		if (paletteAddress == 0)
		{
			rgb12color = defaultPalette[colorIndex & 0xF];
		}
		else
		{
			rgb12color = _dcpu.mem[(paletteAddress + (colorIndex & 0xF)) & 0xFFFF];
		}

		return ((rgb12color & 0xF) << 16) * 17 +
			((rgb12color & 0xF0) << 4) * 17 +
			((rgb12color & 0xF00) >> 8) * 17 +
			0xFF000000;
	}

	void fillCell(size_t x, size_t y, uint color)
	{
		uint cellX = borderSize + x * charWidth;
		uint cellY = borderSize + y * charHeight;

		uint[] data = cast(uint[])_bitmap.data;

		size_t dataPos; 
		uint[] cellLine;

		foreach(i; 0..8)
		{
			dataPos = cellX + screenWidth * (cellY + i);
			cellLine = data[dataPos .. dataPos + 4];
			cellLine[] = color;
		}
	}

	void drawCell(size_t x, size_t y, uint foreColor, uint backColor, uint charData)
	{
		uint cellX = borderSize + x * charWidth;
		uint cellY = borderSize + y * charHeight;

		uint[] colorData = cast(uint[])_bitmap.data;

		size_t dataPos;
		uint[] cellLine;

		foreach(i; 0..8)
		{
			dataPos = cellX + screenWidth * (cellY + i);
			cellLine = colorData[dataPos .. dataPos + 4];

			cellLine[0] = charData & (1 << (i +  8)) ? foreColor : backColor;
			cellLine[1] = charData & (1 << (i +  0)) ? foreColor : backColor;
			cellLine[2] = charData & (1 << (i + 24)) ? foreColor : backColor;
			cellLine[3] = charData & (1 << (i + 16)) ? foreColor : backColor;
		}
	}

	void drawBorder()
	{
		uint borderRgb = paletteToRGB8(borderColor);
		uint[] colorData = cast(uint[])_bitmap.data;

		colorData[0..borderSize * screenWidth][] = borderRgb;

		size_t topOffset;
		foreach(line; borderSize..screenHeight - borderSize)
		{
			topOffset = line * screenWidth;
			colorData[topOffset..topOffset + borderSize][] = borderRgb;
			colorData[topOffset + screenWidth - borderSize .. topOffset + screenWidth][] = borderRgb;
		}

		colorData[$-borderSize * screenWidth..$][] = borderRgb;
	}

	void drawSplash()
	{
		import std.bitmanip;
		(cast(uint[])_bitmap.data)[] = splashBackRgb;
		
		BitArray array;
		array.init(cast(void[])splashImage, splashImage.length * 16);

		foreach(line; 0..splashHeight)
		{
			foreach(col; 0.. splashWidth)
			{
				(cast(uint[])_bitmap.data)[(splashY+line+borderSize) * bitmap.size.x + splashX + col + borderSize] =
					array[line * splashWidth + col] ? splashForeRgb : splashBackRgb; 
			}
		}

		_bitmap.dataChanged.emit();
	}

	void mapScreen(ushort b)
	{
		if (b != 0 && videoAddress == 0)
		{
			splash = true;
			enabled = true;

			drawSplash();

			_dcpu.updateQueue.addQuery(this, 70000, 0);
		}
		else if (b == 0)
		{
			(cast(uint[])_bitmap.data)[] = 0xFF000000;
			_dcpu.updateQueue.removeQueries(this);

			enabled = false;
		}

		videoAddress = b;
	}

	void mapFont(ushort b)
	{
		fontAddress = b;
	}

	void mapPalette(ushort b)
	{
		paletteAddress = b;
	}

	void setBorderColor(ushort b)
	{
		borderColor = b & 0xF;
	}

	void dumpFont(ushort b)
	{
		ushort pointer = b;

		foreach(word; cast(ushort[])defaultFont)
		{
			_dcpu.mem[pointer] = word;
			++pointer;
		}
	}

	void dumpPalette(ushort b)
	{
		ushort pointer = b;

		foreach(word; defaultPalette)
		{
			_dcpu.mem[pointer] = word;
			++pointer;
		}
	}
}

static immutable ushort[] defaultPalette = [
	0x000, 0x00a, 0x0a0, 0x0aa,
	0xa00, 0xa0a, 0xa50, 0xaaa,
	0x555, 0x55f, 0x5f5, 0x5ff,
	0xf55, 0xf5f, 0xff5, 0xfff
];

static immutable ushort[] defaultFont = [
0x000f, 0x0808, 0x080f, 0x0808, 0x08f8, 0x0808, 0x00ff, 0x0808, 
0x0808, 0x0808, 0x08ff, 0x0808, 0x00ff, 0x1414, 0xff00, 0xff08,
0x1f10, 0x1714, 0xfc04, 0xf414, 0x1710, 0x1714, 0xf404, 0xf414,
0xff00, 0xf714, 0x1414, 0x1414, 0xf700, 0xf714, 0x1417, 0x1414,
0x0f08, 0x0f08, 0x14f4, 0x1414, 0xf808, 0xf808, 0x0f08, 0x0f08,
0x001f, 0x1414, 0x00fc, 0x1414, 0xf808, 0xf808, 0xff08, 0xff08,
0x14ff, 0x1414, 0x080f, 0x0000, 0x00f8, 0x0808, 0xffff, 0xffff, 
0xf0f0, 0xf0f0, 0xffff, 0x0000, 0x0000, 0xffff, 0x0f0f, 0x0f0f, 
0x0000, 0x0000, 0x005f, 0x0000, 0x0300, 0x0300, 0x3e14, 0x3e00, 
0x266b, 0x3200, 0x611c, 0x4300, 0x3629, 0x7650, 0x0002, 0x0100, 
0x1c22, 0x4100, 0x4122, 0x1c00, 0x2a1c, 0x2a00, 0x083e, 0x0800, 
0x4020, 0x0000, 0x0808, 0x0800, 0x0040, 0x0000, 0x601c, 0x0300, 
0x3e41, 0x3e00, 0x427f, 0x4000, 0x6259, 0x4600, 0x2249, 0x3600, 
0x0f08, 0x7f00, 0x2745, 0x3900, 0x3e49, 0x3200, 0x6119, 0x0700, 
0x3649, 0x3600, 0x2649, 0x3e00, 0x0024, 0x0000, 0x4024, 0x0000, 
0x0814, 0x2241, 0x1414, 0x1400, 0x4122, 0x1408, 0x0259, 0x0600, 
0x3e59, 0x5e00, 0x7e09, 0x7e00, 0x7f49, 0x3600, 0x3e41, 0x2200, 
0x7f41, 0x3e00, 0x7f49, 0x4100, 0x7f09, 0x0100, 0x3e49, 0x3a00, 
0x7f08, 0x7f00, 0x417f, 0x4100, 0x2040, 0x3f00, 0x7f0c, 0x7300, 
0x7f40, 0x4000, 0x7f06, 0x7f00, 0x7f01, 0x7e00, 0x3e41, 0x3e00, 
0x7f09, 0x0600, 0x3e41, 0xbe00, 0x7f09, 0x7600, 0x2649, 0x3200, 
0x017f, 0x0100, 0x7f40, 0x7f00, 0x1f60, 0x1f00, 0x7f30, 0x7f00, 
0x7708, 0x7700, 0x0778, 0x0700, 0x7149, 0x4700, 0x007f, 0x4100, 
0x031c, 0x6000, 0x0041, 0x7f00, 0x0201, 0x0200, 0x8080, 0x8000, 
0x0001, 0x0200, 0x2454, 0x7800, 0x7f44, 0x3800, 0x3844, 0x2800, 
0x3844, 0x7f00, 0x3854, 0x5800, 0x087e, 0x0900, 0x4854, 0x3c00, 
0x7f04, 0x7800, 0x447d, 0x4000, 0x2040, 0x3d00, 0x7f10, 0x6c00, 
0x417f, 0x4000, 0x7c18, 0x7c00, 0x7c04, 0x7800, 0x3844, 0x3800, 
0x7c14, 0x0800, 0x0814, 0x7c00, 0x7c04, 0x0800, 0x4854, 0x2400, 
0x043e, 0x4400, 0x3c40, 0x7c00, 0x1c60, 0x1c00, 0x7c30, 0x7c00, 
0x6c10, 0x6c00, 0x4c50, 0x3c00, 0x6454, 0x4c00, 0x0836, 0x4100, 
0x0077, 0x0000, 0x4136, 0x0800, 0x0201, 0x0201, 0x704c, 0x7000
];

// 1bit image. 1 - splashForeRgb, 0 - splashBackRgb.
// only center piece 52 x 36.
static immutable ushort[] splashImage = [
0x6000, 0x0180, 0x0000, 0x0000, 0x1806, 0x0000, 0x0000, 0x80e0, 0x0001, 0x0000,
0x0c00, 0x0018, 0x0000, 0xc000, 0x0181, 0x0000, 0x3000, 0x1818, 0x0000, 0x0000,
0x8383, 0x0001, 0x0000, 0x3070, 0x0018, 0x0000, 0x0700, 0x8187, 0x0fff, 0xf000,
0x1860, 0xfff8, 0x0000, 0x8e0f, 0x0001, 0x0000, 0xc1f0, 0x0018, 0x0000, 0x1b00,
0x019c, 0x0000, 0xb000, 0x1983, 0x0000, 0x0000, 0xb833, 0x0001, 0x0000, 0x0730,
0x001b, 0x0000, 0x6300, 0x01f0, 0x0000, 0x3000, 0x1e0e, 0x0000, 0x0000, 0xe0c3,
0xff81, 0x000f, 0x1c30, 0xf81c, 0x00ff, 0x8300, 0x01c1, 0x0000, 0x3000, 0x1838,
0x0000, 0x0000, 0x8303, 0x0001, 0x0000, 0x7030, 0x0000, 0x0000, 0x0300, 0x0006,
0x0000, 0x3000, 0x00e0, 0x0000, 0x0000, 0x0c03, 0x0000, 0x0000, 0xc030, 0x0000,
0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x6530, 0xb8b8, 0xcbba,
0x75ca, 0x8987, 0x9919, 0x5e64, 0xb852, 0x92bb, 0xaa6a, 0x0000, 
];

enum splashBackRgb = 0xFFAA0000;
enum splashForeRgb = 0xFF00FFFF;

enum splashWidth = 52;
enum splashHeight = 36;

enum splashX = 38;
enum splashY = 25;