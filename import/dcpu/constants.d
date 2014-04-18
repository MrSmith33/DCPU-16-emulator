/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.constants;

/// Table of literal values which may be stored in 'a' operand.
static ushort[32] literals =
	[0xFFFF, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
	 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
	 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
	 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E];

/// Operands which will read nex word increasing pc register are '1', other are '0'.
static immutable ushort[64] nextWordOperands =
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 1,
	 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

/// Table of basic instructions cost.
static immutable ubyte[32] basicCycles =
	[10, 1, 2, 2, 2, 2, 3, 3, 3, 3, 1, 1, 1, 1, 1, 1, 
	 2, 2, 2, 2, 2, 2, 2, 2, 10, 10, 3, 3, 10, 10, 2, 2];

/// Table of special instructions cost.
static immutable ubyte[32] specialCycles = 
	[10, 3, 10, 10, 10, 10, 10, 10, 4, 1, 1, 3, 2, 10, 10, 10,
	 2, 4, 4, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10];

// Enums for opcodes. Just a bit of self documented code.
enum {SET = 0x01, ADD, SUB, MUL, MLI, DIV, DVI,
	  MOD, MDI, AND, BOR, XOR, SHR, ASR, SHL,
	  IFB, IFC, IFE, IFN, IFG, IFA, IFL, IFU,
	  ADX = 0x1A, SBX, STI = 0x1E, STD}

enum {JSR = 0x01, INT = 0x08, IAG, IAS, RFI, IAQ, HWN = 0x10, HWQ, HWI}

static string[] registerNames = ["A", "B", "C", "X", "Y", "Z", "I", "J"];

static string[] basicOpcodeNames =
	["0x00", "SET", "ADD", "SUB", "MUL", "MLI", "DIV", "DVI",
	 "MOD", "MDI", "AND", "BOR", "XOR", "SHR", "ASR", "SHL",
	 "IFB", "IFC", "IFE", "IFN", "IFG", "IFA", "IFL", "IFU",
	 "0x18", "0x19", "ADX", "SBX", "0x1c", "0x1d", "STI", "STD"];

static string[] specialOpcodeNames =
	["0x00", "JSR", "0x02", "0x03", "0x04", "0x05", "0x06", "0x07",
	 "INT", "IAG", "IAS", "RFI", "IAQ", "0x0d", "0x0e", "0x0f",
	 "HWN", "HWQ", "HWI", "0x0d", "0x13", "0x14", "0x15", "0x16",
	 "0x17", "0x18", "0x19", "0x1a", "0x1b", "0x1c", "0x1d", "0x1e", "0x1f"];

static bool[32] isValidBasicOpcode =
	[0,1,1,1,1,1,1,1,
	 1,1,1,1,1,1,1,1,
	 1,1,1,1,1,1,1,1,
	 0,0,1,1,0,0,1,1];

static bool[32] isValidSpecialOpcode =
	[0,1,0,0,0,0,0,0,
	 1,1,1,1,1,0,0,0,
	 1,1,1,0,0,0,0,0,
	 0,0,0,0,0,0,0,0];