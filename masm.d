/********************************************************************************
 * masm.d: main file for mips assembler/disassembler                            *
 * 2016 - Ben Perlin                                                            *
 *******************************************************************************/
import std.getopt;
import std.stdio;

import program;
import util;

int main(string[] args) {
    uint startAddress = 0x0040_0000;
    string startAddressString;
    string outputFilename;
    bool disassemblyMode;
    bool printSymbolTable;
    bool strictCompatibility;

    auto helpInformation = getopt(args,
          std.getopt.config.passThrough,
          "start|s", &startAddressString,
          "disassemble|d", &disassemblyMode,
          "output-file|o", &outputFilename,
          "strict", &strictCompatibility,
          "print-symbol-table", &printSymbolTable);

    if (helpInformation.helpWanted) {
        defaultGetoptPrinter("Usage masm [filename]", helpInformation.options);
        return 0;
    }

    if (startAddressString != "") {
        try {
            startAddress = parseStartAddress(startAddressString);
        } catch (Exception exception) {
            stderr.writeln(exception.msg);
            return 1;
        }
    }

    File codeFile = stdin; /* note does not work from console yet */

    if (args.length == 2) {
        string inputFilename = args[1];
	
        if (inputFilename != "") {
            try {
                codeFile = File(inputFilename, "r");

            } catch (Throwable o) {
                stderr.writeln("Failed to open file: ", inputFilename);
                return 1;
            }
        }
    }
    
    Program program;

    File outputFile = stdout;

    if (outputFilename != "") {
        try {
            outputFile = File(outputFilename, "w");

        } catch (Throwable o) {
            stderr.writeln("Failed to open file: ", outputFilename);
            return 1;
        }
    }

    try {
        if (disassemblyMode) {
            program.disassemble(codeFile);
            program.printDisassembled(outputFile);

        } else {
            program.assemble(codeFile, startAddress, strictCompatibility);

            if (printSymbolTable) {
                writeln();
                program.printSymbolTable(outputFile);
            }

            program.printAssembled(outputFile);
        }
    } catch (Exception exception) {
        /* print exception message without stacktrace */
        stderr.writeln(exception.msg);
    }

    return 0;
}
