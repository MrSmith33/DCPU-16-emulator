module build;

version = showBuildString;

import std.file : dirEntries, SpanMode;
import std.process : executeShell;
import std.stdio : writeln;

import std.algorithm : findSplitBefore;
import std.range : retro, chain;
import std.array : array;
import std.conv : to;

enum 
{
	executable,
	staticLib,
	sharedLib,
}

alias pack = packageSettings;
struct packageSettings
{
	string name;
	string sourcePath;
	string[] importPaths;
	string[] libFiles;
	string outputName;
	uint targetType;
	string linkerFlags;
}

version(Windows)
{
	enum exeSuffix = ".exe";
	enum exePrefix = "";
	enum staticLibSuffix = ".lib";
	enum staticLibPrefix = "";
	enum sharedLibSuffix = ".dll";
	enum sharedLibPrefix = "";
}
version(linux)
{
	enum exeSuffix = "";
	enum exePrefix = "";
	enum staticLibSuffix = ".a";
	enum staticLibPrefix = "lib";
	enum sharedLibSuffix = ".so";
	enum sharedLibPrefix = "lib";
}

string withSuffixPrefix(string filePath, string prefix, string suffix)
{
	auto splitted = filePath.retro.findSplitBefore("/");

    return chain(splitted[1].retro,
		prefix,
		splitted[0].array.retro,
		suffix).array.to!string;
}

void buildPackage(ref packageSettings settings, string flags)
{
	string buildString = "dmd"~exeSuffix~" "~flags~" ";
	if (settings.targetType == staticLib) buildString ~= "-lib ";
	
	foreach(string filename; dirEntries(settings.sourcePath, "*.d", SpanMode.depth))
	{
		buildString ~= '"'~filename~"\" ";
	}

	foreach(path; settings.importPaths)
	{
		buildString ~= "-I\""~path~"\" ";
	}
	
	foreach(lib; settings.libFiles)
	{
		buildString ~= "\""~withSuffixPrefix(lib, staticLibPrefix, staticLibSuffix)~"\" ";
	}

	buildString ~= settings.linkerFlags;

	buildString ~= " -of\"";

	switch(settings.targetType)
	{
		case executable: buildString ~= withSuffixPrefix(settings.outputName, exePrefix, exeSuffix) ~ "\""; break;
		case staticLib: buildString ~= withSuffixPrefix(settings.outputName, staticLibPrefix, staticLibSuffix) ~ "\""; break;
		case sharedLib: buildString ~= withSuffixPrefix(settings.outputName, sharedLibPrefix, sharedLibSuffix) ~ "\""; break;
		default: assert(false);
	}
	
	version(showBuildString) writeln(buildString);
	
	auto result = executeShell(buildString);
	if (result.status != 0)
	{
		writeln("Compilation failed:\n"~result.output);
	}
}

import std.getopt;
void main(string[] args)
{
	bool release;

	getopt(
	    args,
	    std.getopt.config.passThrough,
	    "release|r",  &release
	);

	auto imports = ["deps/anchovy/import",
	"deps/anchovy/deps/dlib",
	"deps/anchovy/deps/derelict-fi-master/source",
	"deps/anchovy/deps/derelict-sdl2-master/source",
	"deps/anchovy/deps/derelict-ft-master/source",
	"deps/anchovy/deps/derelict-gl3-master/source",
	"deps/anchovy/deps/derelict-glfw3-master/source",
	"deps/anchovy/deps/derelict-util-1.0.0/source",
	"deps/anchovy/deps/sdlang-d-0.8.4/src"];
	auto packages = [
		pack("application",
			 "import",
			 imports,
				["deps/anchovy/deps/derelict-util-1.0.0/lib/DerelictUtil",
				"deps/anchovy/deps/derelict-glfw3-master/lib/DerelictGLFW3",
				"deps/anchovy/deps/derelict-gl3-master/lib/DerelictGL3",
				"deps/anchovy/deps/derelict-ft-master/lib/DerelictFT",
				"deps/anchovy/deps/derelict-fi-master/lib/DerelictFI",
				"deps/anchovy/deps/dlib/dlib",
				"deps/anchovy/lib/debug/utils",
				"deps/anchovy/lib/debug/core",
				"deps/anchovy/lib/debug/graphics",
				"deps/anchovy/deps/sdlang-d-0.8.4/sdlang-d",
				"deps/anchovy/lib/debug/gui"].retro.array,
			"bin/emulator",
			executable)
	];
	
	foreach(ref pack; packages)
		if(release)
			buildPackage(pack, "-release -O -inline -m32");
		else
			buildPackage(pack, "-debug -gc -de -m32");
}