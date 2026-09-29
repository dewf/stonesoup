module stonesoup.sumtype.tokenizer;

import std.format;

struct Token {
	enum Tag {
		Identifier, // includes dots, must start with capital
		LeftBrace,
		RightBrace,
		LeftParen,
		RightParen,
		Comma
	}
	union Content {
		string id;
	}
	Tag tag;
	Content content;
	int line;
	int col;

	static Token mkSimple(Tag tag, int line, int col) {
		return Token(tag, Content(), line, col);
	}

	static Token mkIdentifier(string id, int line, int col) {
		Content c;
		c.id = id;
		return Token(Tag.Identifier, c, line, col);
	}

    string isIdentifier() {
        if (tag == Tag.Identifier) {
            return content.id;
        }
        return null;
	}

	bool isComma() => tag == Tag.Comma;
	bool isLeftParen() => tag == Tag.LeftParen;
	bool isLeftBrace() => tag == Tag.LeftBrace;

	string toString() {
		final switch(tag) {
			case Tag.Identifier:
				return format("Identifier(%s)[%d:%d]", content.id, line, col);
			case Tag.LeftBrace:
				return format("LeftBrace[%d:%d]", line, col);
			case Tag.RightBrace:
				return format("RightBrace[%d:%d]", line, col);
			case Tag.LeftParen:
				return format("LeftParen[%d:%d]", line, col);
			case Tag.RightParen:
				return format("RightParen[%d:%d]", line, col);
			case Tag.Comma:
				return format("Comma[%d:%d]", line, col);
		}
	}
}

bool isWhitespace(char ch) {
	return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n';
}

int wsColumnAdvance(char ch) {
	switch (ch) {
		case ' ':
			return 1;
		case '\t':
			return 4; // uhhh
		case '\r':
			return 0;
		case '\n':
			return 0;
		default:
			return 0;
	}
}

void skipWhitespace(ref string input) {
	int i = 0;
	while (i < input.length && isWhitespace(input[i])) {
		i++;
	}
	input = input[i..$];
}

bool isIdentifierChar(char ch, bool isInitial = false) {
	if (isInitial) {
		return (ch >= 'A' && ch <= 'Z') ||
			   (ch >= 'a' && ch <= 'z') ||
			   (ch == '_');
	} else {
		return (ch >= 'A' && ch <= 'Z') ||
			   (ch >= 'a' && ch <= 'z') ||
			   (ch >= '0' && ch <= '9') ||
			    ch == '_' ||
				ch == '.' ||
			    ch == '!' ||
				ch == '[' || ch == ']';
	}
}

struct TokenizeResult(T) {
	bool _success;
	T thing;
	string etc;
	bool opCast(T: bool)() const {
		return _success;
	}
	static TokenizeResult success(T thing, string etc) {
		return TokenizeResult!T(true, thing, etc);
	}
	static TokenizeResult fail() {
		return TokenizeResult!T(false);
	}
}

struct Whitespace {
	int lines;
	int cols;
}

TokenizeResult!Whitespace readWhitespace(string input) {
	int i;
	int lines;
	int cols;
	while (i < input.length && isWhitespace(input[i])) {
		if (input[i] == '\n') {
			cols = 0;
			lines++;
		} else {
			cols += wsColumnAdvance(input[i]);
		}
		i++;
	}
	if (i > 0) {
		return TokenizeResult!Whitespace.success(Whitespace(lines, cols), input[i..$]);
	}
	return TokenizeResult!Whitespace.fail();
}

TokenizeResult!string readIdentifier(string input) {
	if (input.length > 0 && isIdentifierChar(input[0], true)) {
		int i = 1;
		while (i < input.length && isIdentifierChar(input[i])) {
			i++;
		}
		return TokenizeResult!string.success(input[0..i].idup(), input[i..$]);
	}
	return TokenizeResult!string.fail();
}

TokenizeResult!char readSymbol(string input) {
	if (input.length > 0) {
		switch (input[0]) {
			case '{', '}', '(', ')', ',':
				return TokenizeResult!char.success(input[0], input[1..$]);
			default:
				return TokenizeResult!char.fail();
		}
	}
	return TokenizeResult!char.fail();
}

Token[] tokenize(string input) {
	Token[] tokens;
	int line;
	int col;
	while (input.length > 0) {
		if (auto ws = readWhitespace(input)) {
			if (ws.thing.lines > 0) {
				line += ws.thing.lines;
				col = 0;
			}
			col += ws.thing.cols;
			input = ws.etc;
		} else if (auto id = readIdentifier(input)) {
			tokens ~= Token.mkIdentifier(id.thing, line, col);
			col += id.thing.length;
			input = id.etc;
		} else if (auto sym = readSymbol(input)) {
			switch (sym.thing) {
			case '{':
				tokens ~= Token.mkSimple(Token.Tag.LeftBrace, line, col);
				break;
			case '}':
				tokens ~= Token.mkSimple(Token.Tag.RightBrace, line, col);
				break;
			case '(':
				tokens ~= Token.mkSimple(Token.Tag.LeftParen, line, col);
				break;
			case ')':
				tokens ~= Token.mkSimple(Token.Tag.RightParen, line, col);
				break;
			case ',':
				tokens ~= Token.mkSimple(Token.Tag.Comma, line, col);
				break;
			default:
				throw new Exception("tokenization error: unknown symbol");
			}
			col += 1;
			input = sym.etc;
		} else {
			throw new Exception("tokenization error");
		}
	}
	return tokens;
}
