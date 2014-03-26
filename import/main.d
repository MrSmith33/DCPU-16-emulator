/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module main;

import anchovy.graphics.windows.glfwwindow;

import application;

version(linux)
{
	pragma(lib, "dl");
}

import anchovy.gui;

void main(string[] args)
{
	auto app = new EmulatorApplication(uvec2(1280, 600), "DCPU-16 emulator");
	app.run(args);
}
