/********************************************************************************
 * util.d: assorted utility functions                                           *
 * 2016 - Ben Perlin                                                            *
 *******************************************************************************/
import std.ascii;
import std.format;
import std.range;
import std.string : chomp;
import std.traits;

struct Token
{
    string str;
    uint column;
}

char[] carrotLine(const uint columnNumber) {return ' '.repeat(columnNumber).array ~ '^';}

string pointOutError(const Token errorToken, const string line) {
  return format("%s\n%s", line.chomp(), carrotLine(errorToken.column));
}

void formatException(Char, Args...)(const Char[] fmt, Args args)
    if (isSomeChar!Char)
{
    throw new Exception(format(fmt, args));
}

/* Provides standardized error handling 
 * Introduced late, not used everywhere */
string errorString(string error, Token token, string line, uint lineNumber) {
    return format("Error on line %d: %s\n\n%s",
                  lineNumber, error, pointOutError(token, line));
}

long parseIntegerToken(Token token, uint bitWidth, bool signed, string line, uint lineNumber)
in {
    import std.string;

    assert(bitWidth < 60); /* ensures no overflow is possable under any circumstances */
    assert(token.str.length >= 1);
    assert(indexOf(token.str, '-', 1) == -1); /* negative sign may only appear in first column */

} body {

    void parseError() {
        throw new Exception(errorString("failed to parse numeric token",
                                        token, line, lineNumber));
    }

    bool negative = (token.str[0] == '-');
    if (negative && !signed) {
        throw new Exception(errorString("negative token not accepted by unsigned feild",
                                        token, line, lineNumber));
    }
    
    string numeralToken = token.str[negative .. $];
    long base = 10;

    switch (numeralToken[0]) {
    case '0':
        if (numeralToken.length == 1) return 0;
        else if (numeralToken[1].toLower() == 'x') {
            base = 16;
            if (numeralToken.length == 2) parseError();
            numeralToken = numeralToken[2 .. $];
        } else {
            base = 8;
            numeralToken = numeralToken[1 .. $];
        }
        break;

    case '1': .. case '9':
        base = 10;
        break;

    default: parseError();
    }

    long intermediate;

parse:
    foreach (c; numeralToken) {
        long digit;
        char cu = c.toUpper();

        switch (cu) {
        case '0': .. case '9':
            digit = cu - '0';
            break;

        case 'A': .. case 'F':
            digit = 0xA + cu - 'A';
            break;

        case '_': continue parse;

        default: parseError();
        }

        if (digit >= base) parseError();

        intermediate = intermediate*base + digit;
    }

    intermediate *= negative ? -1 : 1;

    if (signed ? intermediate < -(1L<<(bitWidth-1)) || intermediate >= (1<<(bitWidth-1))
               : intermediate < 0 || intermediate >= (1UL<<bitWidth)) {
        throw new Exception(errorString(format("numeric token out of range for %d bit %s integer",
	                                       bitWidth, (signed ? "signed" : "unsigned")),
					token, line, lineNumber));
    }

    return intermediate;
}

/* wrapper for parseIntegerToken to parse start address from command line */
uint parseStartAddress(string startAddressString) {
    return cast(uint) parseIntegerToken(Token(startAddressString, 0), 32, false,
                                        startAddressString, 0);
}

unittest {
    /* does not test error handling, messages will be incorrectly */
    void runTest(string token, uint bitWidth, bool signed, long expected) {
        long output = parseIntegerToken(Token(token, 0), bitWidth, signed, token, 0);
        assert(output == expected, format("ASSERTION: integer token \"%s\" parses to %d, expected %d",
					  token, output, expected));
    }

    runTest("0", 5, false, 0);
    runTest("00", 5, false, 0);
    runTest("0x0", 5, false, 0);

    runTest("0", 16, true, 0);
    runTest("00", 16, true, 0);
    runTest("0x0", 16, true, 0);

    runTest("42", 26, false, 42);
    runTest("052", 26, false, 42);
    runTest("0x2A", 26, false, 42);

    runTest("42", 16, true, 42);
    runTest("052", 16, true, 42);
    runTest("0x2A", 16, true, 42);

    // todo test negatives and overflows
}
