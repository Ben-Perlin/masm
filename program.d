/********************************************************************************
 * program.d:                                                                   *
 *                                                                              *
 * errata:                                                                      *
 *  - does not handle eof in stdin from console                                 *
 *  - does not handle process redirrection (ie. /dev/fd/63)                     *
 *  - lines ending without newlines _______                                     *
 *                                                                              *
 * 2016 - Ben Perlin                                                            *
 *******************************************************************************/
import std.algorithm : sort;
import std.ascii;
import std.exception;
import std.format;
import std.range;
import std.stdio;
import std.string;

import instruction, util;

struct Program
{
private:
    uint startAddress, nextAddress;
    Instruction[] code;
    uint[string] symbolTable;
    bool startDetermined;
    bool strictCompatibility = false;

    string[uint] reverseSymbolTable;

    invariant() {
        assert((startAddress & 0x3) == 0);
        assert((nextAddress & 0x3) == 0);
        assert(nextAddress >= startAddress); /* no overflow */
    }

    void parseLineASM(const string line, const uint lineNumber) {
        enum ScannerState {leading, identifier, loaded, token, seperator, negative}
        string processedLine = line.detab(8);
        ScannerState state = ScannerState.leading;
	Token[] tokens;
	
        char[] token;     /* the token being constructed                     */
        uint tokenColumn; /* column of the token currently being constructed */

        uint nLabels;

        void addLabel(const string label) {
            if (strictCompatibility && (nLabels > 0)) {
                formatException("Error on line %d: strict compatibility mode disallows multiple labels per line\n\n%s",
                                lineNumber, line);
            }

            if (label in symbolTable) {
	        formatException("Error on line %s: duplicate label %s\n\n%s\n%s",
                                lineNumber, label, processedLine, carrotLine(tokenColumn));
            }
            symbolTable[label] = nextAddress;
        }

	uint column = 0;
	
	// column numbering starts at 0
        void scannerError(uint columnNumber, dchar c) {
            formatException("Error scanning line %s: unexpected charactor '%s'\n\n%s\n%s",
                            lineNumber, c, processedLine, carrotLine(columnNumber));
        }

    scanner:
	foreach (dc; processedLine.stride(1)) {
            enforce(isASCII(dc), "We don't take kindly to non ASCII charactors here");
            char c = cast(char) dc; /* cast dchar to char after verifing it is ASCII */	    
            assert(c != '\t'); // check detabber

            final switch (state) {
            case ScannerState.leading:
                switch (c) {
                case ' ': break;

                case '_': goto case;
                case 'a': .. case 'z': goto case;
                case 'A': .. case 'Z':
                    state = ScannerState.identifier;
                    token ~= c;
                    tokenColumn = column;
                    break;

                case '\r', '\n', '#': break scanner;

                default: scannerError(column, c);
                }
                break;

            case ScannerState.identifier:
                switch (c) {
                case '_': goto case;
                case 'a': .. case 'z': goto case;
                case 'A': .. case 'Z': goto case;
                case '0': .. case '9':
                    token ~= c;
                    break;

                case ':':
                    addLabel(token.idup());
                    token = [];
                    state = ScannerState.leading;
                    break;

                case ' ':
                    state = ScannerState.loaded;
                    break;

                default: scannerError(column, c);
                }
                break;

            case ScannerState.loaded:
                switch (c) {
                case ' ': break;

                case ':':
                    addLabel(token.idup());
                    token = [];
                    state = ScannerState.leading;
                    break;

                case '$', '_': goto case;
                case 'a': .. case 'z': goto case;
                case 'A': .. case 'Z': goto case;
		case '0': .. case '9':
                    tokens ~= Token(token.idup(), tokenColumn);
                    token = [c];
                    tokenColumn = column;
                    state = ScannerState.token;
                    break;

                default: scannerError(column, c); /* includes starting a comment here */
                }
                break;

            case ScannerState.token:
                switch (c) {
                case '_': goto case;
                case 'a': .. case 'z': goto case;
                case 'A': .. case 'Z': goto case;
		case '0': .. case '9':
                    token ~= c;
                    break;

                case '(',')':
                    tokens ~= Token(token.idup(), tokenColumn);
                    token = [c];
                    tokens ~= Token(token.idup(), column);
                    token = [];
                    state = ScannerState.seperator;
                    break;

                case ' ', ',':
                    tokens ~= Token(token.idup(), tokenColumn);
                    token = [];
                    state = ScannerState.seperator;
                    break;

                case '#', '\r', '\n':
                    tokens ~= Token(token.idup(), tokenColumn);
                    token = [];
                    break scanner;

                default: scannerError(column, c);
                }
                break;

            case ScannerState.seperator:
                switch (c) {
                case ' ', ',': break;

                case '$', '_': goto case;
                case 'a': .. case 'z': goto case;
                case 'A': .. case 'Z': goto case;
		case '0': .. case '9':
                    token = [c];
                    tokenColumn = column;
                    state = ScannerState.token;
                    break;

                case '-':
                    token = [c];
                    tokenColumn = column;
                    state = ScannerState.negative;
                    break;

                case '\r', '\n', '#':
                    break scanner;

                default: scannerError(column, c);
                }
                break;
            
            case ScannerState.negative:
                switch (c) {
                case ' ': break; /* drop whitespace */

		case '0': .. case '9':
                    token ~= c;
                    state = ScannerState.token;
                    break;

                default: scannerError(column, c);
                }
                break;
            }
	    
	    column++;
        }

        if (token.length > 0) {
            tokens ~= Token(token.idup(), tokenColumn);
        }

        if (tokens.length > 0) {
	    code ~= Instruction.generate(nextAddress, tokens, processedLine, lineNumber);
            nextAddress += 4;
        }
    }

    void parseLineBin(string line, uint lineNumber) {
        uint address;
        uint binaryInstruction;
        uint hexInstruction;

	// ERATA note does not handle uppercase x
        uint nMatched = formattedRead(line, " [0x%x] %b 0x%x", &address, &binaryInstruction, &hexInstruction);
	
        if (nMatched != 3) {
            formatException("Error on line %d: Invalid format, expected \" [0x%%x] %%b %%x\"\n\n%s",
                            lineNumber, line);
        }

        if (binaryInstruction != hexInstruction) {
            formatException("Error on line %d: binary and hex instructions do not match\n\n%s",
                            lineNumber, line);
        }

        if (startDetermined) {
            if (address != nextAddress) {
                formatException("Error on line %d: address given [0x%X] does not match expected [0x%X]\n\n%s",
                                lineNumber, address, nextAddress, line);
            }
        } else {
            startAddress = address;
            nextAddress = address;
            startDetermined = true;
        }

        Instruction newInstruction = Instruction.decode(address, hexInstruction, line, lineNumber);
        newInstruction.requestLabel(reverseSymbolTable);
	code ~= newInstruction;
        nextAddress += 4;
    }

public:
    /* Read in an assembly file to assemble */
    void assemble(File codeFile, const uint startAddress, bool strictCompatibility = false) {
        this.startAddress = startAddress;
        this.strictCompatibility = strictCompatibility;
        startDetermined = true;
        nextAddress = startAddress;
        uint lineNumber = 1;

	foreach (line; codeFile.byLineCopy(KeepTerminator.yes)) {
            assert(lineNumber > 0);
	    parseLineASM(line, lineNumber);
            lineNumber++;
	}

        foreach (instruction; code) {
            instruction.patchup(symbolTable);
        }
    }

    /* Read in an assembled file to disassemble */
    void disassemble(File codeFile) {
        uint lineNumber = 1;

	foreach (line; codeFile.byLineCopy()) {
            assert(lineNumber > 0);
            parseLineBin(line, lineNumber);
            lineNumber++;
	}
        
        /* create labels for addresses corresponding to lines of code */
	uint index;
        foreach (address; reverseSymbolTable.keys.sort()) {
            if (startAddress <= address && address <= nextAddress) {
                string label = format("L%d", index);
                symbolTable[label] = address;
                reverseSymbolTable[address] = label;
		index++;
            }
        }

	foreach (instruction; code) {
            instruction.patchup(reverseSymbolTable);
	}
    }
  
    void printAssembled(File outputFile) const {
        // outputFile.writeln("[Address]     Instruction");
        foreach (instruction; code) {
	  outputFile.writefln("[0x%08X]\t%032b\t0x%08X", instruction.address,
                              instruction.binaryInstruction, instruction.binaryInstruction);
        }
    }

    void printDisassembled(File outputFile) const {
        foreach (instruction; code) {
            string label = "        ";
            if (instruction.address in reverseSymbolTable) {
                label = format("%-8s", reverseSymbolTable[instruction.address] ~ ':');
            }

            outputFile.writeln(label, instruction.symbolicValue);
        }

        if (nextAddress in reverseSymbolTable) {
            outputFile.writefln("%s:", reverseSymbolTable[nextAddress]);
        }
    }

    void printSymbolTable(File outputFile) const {
        outputFile.writeln("Symbol Table");
        outputFile.writeln("Label     : Address");

        foreach (label; symbolTable.keys.sort()) {
            outputFile.writefln("%-10s: [0x%X]", label, symbolTable[label]);
        }
    }
}
