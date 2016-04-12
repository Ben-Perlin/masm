/********************************************************************************
 * register.d:                                                                  *
 * 2016 - Ben Perlin                                                            *
 *******************************************************************************/
import util;

struct Register
{
private:
    ubyte value_;

    invariant() {
        assert(value_ < 32);
    }

public:
    this(ubyte value) {
        value_ = value;
    }

    this(Token token, string line, uint lineNumber) {
        if (token.str[0] != '$') {
            formatException("Error on line %s: expected register type\n%s",
                            lineNumber, pointOutError(token, line));
        }

        switch (token.str[1 .. $]) {
        case "0", "zero": value_ = 0; break;

        case "1", "at": value_ = 1; break;

        case "2", "v0": value_ = 2; break;
        case "3", "v1": value_ = 3; break;

        case "4", "a0": value_ = 4; break;
        case "5", "a1": value_ = 5; break;
        case "6", "a2": value_ = 6; break;
        case "7", "a3": value_ = 7; break;

        case "8", "t0": value_ = 8; break;
        case "9", "t1": value_ = 9; break;
        case "10", "t2": value_ = 10; break;
        case "11", "t3": value_ = 11; break;
        case "12", "t4": value_ = 12; break;
        case "13", "t5": value_ = 13; break;
        case "14", "t6": value_ = 14; break;
        case "15", "t7": value_ = 15; break;

        case "16", "s0": value_ = 16; break;
        case "17", "s1": value_ = 17; break;
        case "18", "s2": value_ = 18; break;
        case "19", "s3": value_ = 19; break;
        case "20", "s4": value_ = 20; break;
        case "21", "s5": value_ = 21; break;
        case "22", "s6": value_ = 22; break;
        case "23", "s7": value_ = 23; break;

        case "24", "t8": value_ = 24; break;
        case "25", "t9": value_ = 25; break;

        case "26", "k0": value_ = 26; break;
        case "27", "k1": value_ = 27; break;

        case "28", "gp": value_ = 28; break;

        case "29", "sp": value_ = 29; break;

        case "30", "fp": value_ = 30; break;

        case "31", "ra": value_ = 31; break;

        default:
            formatException("Error on line %s: Invalid register \"%s\"\n%s",
                            lineNumber, token.str, pointOutError(token, line));
        }
    }

    string symbolicValue() const @property {
        switch (value_) {
        case 0: return "$zero";

        case 1: return "$at";

        case 2: return "$v0";
        case 3: return "$v1";

        case 4: return "$a0";
        case 5: return "$a1";
        case 6: return "$a2";
        case 7: return "$a3";

        case 8:  return "$t0";
        case 9:  return "$t1";
        case 10: return "$t2";
        case 11: return "$t3";
        case 12: return "$t4";
        case 13: return "$t5";
        case 14: return "$t6";
        case 15: return "$t7";

        case 16: return "$s0";
        case 17: return "$s1";
        case 18: return "$s2";
        case 19: return "$s3";
        case 20: return "$s4";
        case 21: return "$s5";
        case 22: return "$s6";
        case 23: return "$s7";

        case 24: return "$t8";
        case 25: return "$t9";

        case 26: return "$k0";
        case 27: return "$k1";

        case 28: return "$gp";

        case 29: return "$sp";

        case 30: return "$fp";

        case 31: return "$ra";

        default: assert(0);
        }
    }

    ubyte value() const @property {
        return value_;
    }
}
