/********************************************************************************
 * instruction.d: contains instruction classes for each format                  *
 * 2016 - Ben Perlin                                                            *
 *******************************************************************************/
import std.ascii;
import std.conv;
import std.format;
import std.exception;
import std.uni : toLower;

import register, util;

enum Opcode : ubyte
{
   RType = 0x0,

   /* I type instructions */
   addi = 0x8,
   andi = 0xc,
   ori = 0xd,
   beq = 0x4,
   bne = 0x5,
   lw = 0x23,
   sw = 0x2b,

   /* J type instructions*/
   j = 0x2,
   jal = 0x3
}

enum Funct : ubyte 
{
   /* R type instructions */
   add = 0x20,
   sub = 0x22,
   and = 0x24,
   or  = 0x25,
   nor = 0x27,
   slt = 0x2a,
   sll = 0x00,
   srl = 0x02,
   jr  = 0x08
}

/* Abstract base class for all instructions*/
class Instruction
{
protected:
    uint address_;
    ubyte opcode;
    uint lineNumber;
  
    invariant() {
        assert(opcode < (2<<6));
    }

public:
    static Instruction generate(uint address, const Token[] tokens, string line, uint lineNumber) {
        const Token[] operands = tokens[1 .. $];
	
        Instruction RFormatSTD(ubyte funct) {
            return new RFormatSTDInstruction(address, funct, operands, line, lineNumber);
        }

        Instruction RFormatShift(ubyte funct) {
            return new RFormatShiftInstruction(address, funct, operands, line, lineNumber);
        }

        Instruction RFormatJump(ubyte funct) {
            return new RFormatJumpInstruction(address, funct, operands, line, lineNumber);
        }

        Instruction IFormatSTD(ubyte opcode) {
            return new IFormatSTDInstruction(address, opcode, operands, line, lineNumber);
        }

        Instruction IFormatBranch(ubyte opcode) {
            return new IFormatBranchInstruction(address, opcode, operands, line, lineNumber);
        }

        Instruction IFormatMemory(ubyte opcode) {
            return new IFormatMemoryInstruction(address, opcode, operands, line, lineNumber);
        }

        Instruction JFormat(ubyte opcode) {
            return new JFormatInstruction(address, opcode, operands, line, lineNumber);
        }

        switch(tokens[0].str.toLower()) {
        /* R format instructions */
        case "add": return RFormatSTD(Funct.add);
        case "sub": return RFormatSTD(Funct.sub);
        case "and": return RFormatSTD(Funct.and);
        case "or":  return RFormatSTD(Funct.or);
        case "nor": return RFormatSTD(Funct.nor);
        case "slt": return RFormatSTD(Funct.slt);

        /* R Format Shift */
        case "sll": return RFormatShift(Funct.sll);
        case "srl": return RFormatShift(Funct.srl);

        /* R Format Jump */
        case "jr": return RFormatJump(Funct.jr);
            return new RFormatJumpInstruction(address, Funct.jr, operands, line, lineNumber);

        /* I format */
        case "addi": return IFormatSTD(Opcode.addi);
        case "andi": return IFormatSTD(Opcode.andi);
        case "ori":  return IFormatSTD(Opcode.ori);

        /* I format branch*/
        case "beq": return IFormatBranch(Opcode.beq);
        case "bne": return IFormatBranch(Opcode.bne);

        /* I format memory*/
        case "lw": return IFormatMemory(Opcode.lw);
        case "sw": return IFormatMemory(Opcode.sw);

        /* J format*/
        case "j": return JFormat(Opcode.j);
        case "jal": return JFormat(Opcode.jal);

        default:
            formatException("Error on line %s: Unrecognized mnemonic \"%s\"\n\n%s",
                            lineNumber, tokens[0].str, pointOutError(tokens[0], line));
        }

        assert(0);
    }

    static Instruction decode(uint address, uint instruction, string line, uint lineNumber) {
        ubyte opcode = cast(ubyte) (instruction >> 26);
        switch (opcode) {
        case Opcode.RType:
            return RFormatInstruction.decode(address, instruction, line, lineNumber);

        case Opcode.addi, Opcode.andi, Opcode.ori:
            return new IFormatSTDInstruction(address, instruction);

        case Opcode.beq, Opcode.bne:
            return new IFormatBranchInstruction(address, instruction);

        case Opcode.lw, Opcode.sw:
            return new IFormatMemoryInstruction(address, instruction);

        case Opcode.j, Opcode.jal:
            return new JFormatInstruction(address, instruction);

        default:
            formatException("Error on line %d, address [0x%X]: "
                            "cannot decode unsuported opcode 0x%X\n\n%s",
                            lineNumber, address, opcode, line);
        }

        assert(0);
    }

    void requestLabel(ref string[uint] reverseSymbolTable) {}

    void patchup(const ref uint[string] symbolTable) {}

    /* Patchup the labels for disassembly and debugging simulator later */
    void patchup(const ref string[uint] reverseSymbolTable) {}

    string mnemonic() const @property {
        switch (opcode) {
        case Opcode.RType: assert(0); /* should be handled by override */
        case Opcode.addi: return "addi";
        case Opcode.andi: return "andi";
        case Opcode.ori: return "ori";
        case Opcode.beq: return "beq";
        case Opcode.bne: return "bne";
        case Opcode.lw: return "lw";
        case Opcode.sw: return "sw";
        case Opcode.j: return "j";
        case Opcode.jal: return "jal";

        default: assert(0);
        }
    }

    abstract string symbolicValue() const; /* disassembled string */

    uint address() const @property {return address_;}

    abstract uint binaryInstruction() const @property;
}

class RFormatInstruction: Instruction
{
protected:
    Register rs, rt, rd;
    ubyte shamt;
    ubyte funct;

    invariant() {
        assert(opcode == Opcode.RType);
        assert(shamt < (2<<5));
        assert(funct < (2<<6));
    }

public:
  this() {} /* needed for implicit super call */

    this(uint address, uint instruction) {
        this.address_ = address;
        opcode = cast(ubyte) (instruction >> 26);
        rs = Register((instruction>>21) & 0x1F);
        rt = Register((instruction>>16) & 0x1F);
        rd = Register((instruction>>11) & 0x1F);
        shamt = cast(ubyte) ((instruction>>6) & 0x1F);
        funct = cast(ubyte) (instruction & 0x3F);
    }

    static RFormatInstruction decode(uint address, uint instruction, string line, uint lineNumber)
    in {
        ubyte opcode = cast(ubyte) (instruction >> 26);
        assert(opcode == Opcode.RType);

    } body {
        ubyte funct = cast(ubyte) (instruction & 0x2F);
        switch (funct) {
        case Funct.add, Funct.sub, Funct.and, Funct.or, Funct.nor, Funct.slt:
            return new RFormatSTDInstruction(address, instruction);

        case Funct.sll, Funct.srl:
            return new RFormatShiftInstruction(address, instruction);

        case Funct.jr:
            return new RFormatJumpInstruction(address, instruction);

        default:
            formatException("Error on line %d, address [0x%08X]: "
                            "cannot decode unsuported funct 0x%X on R-format instruction\n\n%s",
                            lineNumber, address, funct, line);
        }

        assert(0);
    }

    override string mnemonic() const {
        switch (funct) {
        case Funct.add: return "add";
        case Funct.sub: return "sub";
        case Funct.and: return "and";
        case Funct.or:  return "or";
        case Funct.nor: return "nor";
        case Funct.slt: return "slt";
        case Funct.sll: return "sll";
        case Funct.srl: return "srl";
        case Funct.jr:  return "jr";

        default: assert(0); // not allowed by invariants
        }
    }

    override uint binaryInstruction() const {
        return (opcode << 26) | (rs.value << 21) | (rt.value << 16) | (rd.value << 11) | (shamt << 6) | funct;
    }
}

class RFormatSTDInstruction: RFormatInstruction
{
protected:
    invariant() {
        assert((funct == Funct.add)
               ||(funct == Funct.sub)
               ||(funct == Funct.and)
               ||(funct == Funct.or)
               ||(funct == Funct.nor)
               ||(funct == Funct.slt));
    }

public:
    this(uint address, uint instruction) {
        super(address, instruction);
    }

    this(uint address, ubyte funct, const Token[] operands, string line, uint lineNumber) {
        this.lineNumber = lineNumber;
        address_ = address;
        this.opcode = opcode;
        this.funct = funct;

        enforce(operands.length == 3, format("Error on line %d: expected 3 operands, got %s\n\n%s",
                                             lineNumber, operands.length, line));
        rd = Register(operands[0], line, lineNumber);
        rs = Register(operands[1], line, lineNumber);
        rt = Register(operands[2], line, lineNumber);
    }

    override string symbolicValue() const {
        return format("%-4s   %s, %s, %s", mnemonic, rd.symbolicValue, rs.symbolicValue, rt.symbolicValue);
    }
}

class RFormatShiftInstruction: RFormatInstruction
{
protected:
    invariant() {
        assert((funct == Funct.sll) || (funct == Funct.srl));
    }

public:
    this(uint address, uint instruction) {
        super(address, instruction);
    }

    this(uint address, ubyte funct, const Token[] operands, string line, uint lineNumber) {
        this.lineNumber = lineNumber;
        address_ = address;
        this.opcode = Opcode.RType;
        this.funct = funct;

        enforce(operands.length == 3, format("Error on line %s: expected 3 operands, got %s\n\n%s",
                                             lineNumber, operands.length, line));
        rd = Register(operands[0], line, lineNumber);
        rt = Register(operands[1], line, lineNumber);

        shamt = cast(ubyte) parseIntegerToken(operands[2], 5, false, line, lineNumber);
    }

    override string symbolicValue() const {
        return format("%-4s   %s, %s, %d", mnemonic, rd.symbolicValue, rt.symbolicValue, shamt);
    }
}

class RFormatJumpInstruction: RFormatInstruction
{
protected:
    invariant() {
        assert(funct == Funct.jr);
    }

public:
    this(uint address, uint instruction) {
        super(address, instruction);
    }

    this(uint address, ubyte funct, const Token[] operands, string line, uint lineNumber) {
        this.lineNumber = lineNumber;
        address_ = address;
        this.opcode = Opcode.RType;
        this.funct = funct;

        enforce(operands.length == 1, format("Error on line %s: expected 1 operand, got %s\n\n%s",
                                             lineNumber, operands.length, line));
        rs = Register(operands[0], line, lineNumber);
    }

    override string symbolicValue() const {
        return format("%-4s   %s", mnemonic, rs.symbolicValue);
    }
}

class IFormatInstruction: Instruction
{
protected:
    Register rs, rt;
    short immediate;

public:
    this() {} /* needed for implicit super call */

    this(uint address, uint instruction) {
        address_ = address;
        opcode = cast(ubyte) (instruction >> 26);
        rs = Register((instruction>>21) & 0x1F);
        rt = Register((instruction>>16) & 0x1F);
        immediate = cast(short) (instruction & 0xFFFF);
    }

    override uint binaryInstruction() const {
        return (opcode << 26) | (rs.value << 21) | (rt.value << 16) | (immediate & 0xFFFF);
    }
}

class IFormatSTDInstruction: IFormatInstruction
{
protected:
    invariant() {
        assert((opcode == Opcode.addi) || (opcode == Opcode.andi) || (opcode == Opcode.ori));
    }

    bool isLogical() const @property {
        return (opcode == Opcode.andi) || (opcode == Opcode.ori);
    }

public:
    this(uint address, uint instruction) {
        super(address, instruction);
    }

    this(uint address, ubyte opcode, const Token[] operands, string line, uint lineNumber) {
        this.lineNumber = lineNumber;
        address_ = address;
        this.opcode = opcode;

        enforce(operands.length == 3, format("Error on line %s: expected 3 operands, got %s\n\n%s",
                                             lineNumber, operands.length, line));
        rt = Register(operands[0], line, lineNumber);
        rs = Register(operands[1], line, lineNumber);

        void parseError() {
            formatException("Error on line %d: failed to parse immediate\n\n%s",
                            lineNumber, pointOutError(operands[2], line));
        }

        immediate = cast(short) parseIntegerToken(operands[2], 16, true, line, lineNumber);
    }

    override string symbolicValue() const {
        if (isLogical) {
            return format("%-4s   %s, %s, 0x%04X",
                          mnemonic, rt.symbolicValue, rs.symbolicValue, immediate);
        } else {
            return format("%-4s   %s, %s, %d",
                          mnemonic, rt.symbolicValue, rs.symbolicValue, immediate);
        }
    }
}

class IFormatBranchInstruction: IFormatInstruction
{
protected:
    string label;

    invariant() {
        assert((opcode == Opcode.beq) || (opcode == Opcode.bne));
    }

public:
    this(uint address, uint instruction) {
        super(address, instruction);
    }

    this(uint address, ubyte opcode, const Token[] operands, string line, uint lineNumber) {
        this.lineNumber = lineNumber;
        address_ = address;
        this.opcode = opcode;

        enforce(operands.length == 3, format("Error on line %s: expected 3 operands, got %s\n\n%s",
                                             lineNumber, operands.length, line));
        rs = Register(operands[0], line, lineNumber);
        rt = Register(operands[1], line, lineNumber);

        switch (operands[2].str[0]) {
        case '-': goto case;
        case '0': .. case '9':
            throw new Exception(errorString("Operand of incorrect type", operands[2], line, lineNumber));
            break;

        case '_': goto case;
        case 'A': .. case 'Z': goto case;
        case 'a': .. case 'z':
            label = operands[2].str;
            break;

        default: formatException("Error on line %d: failed to parse offset/label\n\n%s",
                                 lineNumber, pointOutError(operands[2], line));
        }
    }

    override void requestLabel(ref string[uint] reverseSymbolTable) {
        reverseSymbolTable[(address_+4) + ((cast(int) immediate)<<2)] = "";
    }

    override void patchup(const ref uint[string] symbolTable) {
        if (label != "") {
            int destination = ((cast(int) symbolTable[label]) - cast(int) (address + 4)) >> 2;
            immediate = cast(short) destination;
            if (immediate != destination) {
                formatException("Error on line %s: unable to jump to label \"%s\" from address [0x%x], "
                                "destination too far away for I format instruction",
                                lineNumber, label, address_);
            }
        }
    }

    override void patchup(const ref string[uint] reverseSymbolTable) {
        label = reverseSymbolTable[(address_+4) + ((cast(int) immediate)<<2)];
    }

    override string symbolicValue() const @property {
        if (label == "") {
            return format("%-4s   %s, %s, %d", mnemonic, rs.symbolicValue, rt.symbolicValue, immediate);
        } else {
            return format("%-4s   %s, %s, %s", mnemonic, rs.symbolicValue, rt.symbolicValue, label);
        }
    }
}

class IFormatMemoryInstruction: IFormatInstruction
{
protected:
    invariant() {
        assert((opcode == Opcode.lw) || (opcode == Opcode.sw));
    }

public:
    this(uint address, uint instruction) {
        super(address, instruction);
    }

    this(uint address, ubyte opcode, const Token[] operands, string line, uint lineNumber) { 
        this.lineNumber = lineNumber;
        address_ = address;
        this.opcode = opcode;

        rt = Register(operands[0], line, lineNumber);

        immediate = cast(short) parseIntegerToken(operands[1], 16, true, line, lineNumber);

	void match(uint operand, string token) {
            if (operands[operand].str != token) {
                formatException("Error on line %s: expected token %s, got \"%s\"\n\n%s",
                                lineNumber, token, operands[operand].str,
                                pointOutError(operands[operand], line));
	    }
	}
	
	match(2, "(");
        rs = Register(operands[3], line, lineNumber);
	match(4, ")");	
    }

    override string symbolicValue() const @property {
        return format("%-4s   %s, %d(%s)", mnemonic, rt.symbolicValue, immediate, rs.symbolicValue);
    }
}

class JFormatInstruction: Instruction
{
protected:
    uint target;
    string label;

    invariant() {
        assert(target < (2<<26));
        assert((opcode == Opcode.j) || (opcode == Opcode.jal));
    }

public:
    this(uint address, uint instruction) {
        address_ = address;
        opcode = cast(ubyte) (instruction >> 26);
        target = instruction & 0x03FF_FFFF;
    }

    this(uint address, ubyte opcode, const Token[] operands, string line, uint lineNumber) {
        this.lineNumber = lineNumber;
        address_ = address;
        this.opcode = opcode;

        enforce(operands.length == 1, format("Error on line %s: expected 1 operand, got %s\n\n%s",
                                             lineNumber, operands.length, line));

        void parseError(string error) {
            formatException("Error on line %d: failed to parse target/label, %s\n\n%s",
                            lineNumber, error,  pointOutError(operands[0], line));
        }

        switch (operands[0].str[0]) {
        case '-': goto case;
        case '0': .. case '9':
            throw new Exception(errorString("Operand of incorrect type", operands[0], line, lineNumber));
            break;

        case '_': goto case;
        case 'A': .. case 'Z': goto case;
        case 'a': .. case 'z':
            label = operands[0].str;
            break;

        default: parseError("invalid token");
        }
    }

    override uint binaryInstruction() const {
        return (opcode << 26) | target;
    }

    override void requestLabel(ref string[uint] reverseSymbolTable) {
        reverseSymbolTable[((address+4) & 0xF000_0000) | (target<<2)] = "";
    }

    override void patchup(const ref uint[string] symbolTable) {
        if (label != "") {
            uint destination = symbolTable[label];
            assert((destination & 0x3) == 0);

            if ((destination & 0xF000_0000) != ((address + 4) & 0xF000_0000)) {
                formatException("Error on line %s: unable to jump to label \"%s\" from address [0x%x], "
                                "j type instructions cannot jump across 28 bit boundaries",
                                lineNumber, label, address);
            }

            target = (destination & 0x0FFF_FFFC) >> 2;
        }
    }

    override void patchup(const ref string[uint] reverseSymbolTable) {
        label = reverseSymbolTable[((address+4) & 0xF000_0000) | (target<<2)];
    }

    override string symbolicValue() const @property {
        if (label == "") {
            return format("%-4s   %d", mnemonic, target);
        } else {
            return format("%-4s   %s", mnemonic, label);
        }
    }
}
