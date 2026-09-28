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

	static Token mkSimple(Tag tag) {
		return Token(tag, Content());
	}

	static Token mkIdentifier(string id) {
		Content c;
		c.id = id;
		return Token(Tag.Identifier, c);
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
				return format("Identifier(%s)", content.id);
			case Tag.LeftBrace:
				return "LeftBrace";
			case Tag.RightBrace:
				return "RightBrace";
			case Tag.LeftParen:
				return "LeftParen";
			case Tag.RightParen:
				return "RightParen";
			case Tag.Comma:
				return "Comma";
		}
	}
}

bool isWhitespace(char ch) {
	return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n';
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
			   (ch == '_' || ch == '.' || ch == '!');
	}
}

string readIdentifier(string input, out string etc) {
	if (input.length > 0 && isIdentifierChar(input[0], true)) {
		int i = 1;
		while (i < input.length && isIdentifierChar(input[i])) {
			i++;
		}
		etc = input[i .. $];
		return input[0 .. i].idup();
	}
	return null;
}

char readSymbol(string input, out string etc) {
	if (input.length > 0) {
		switch (input[0]) {
			case '{', '}', '(', ')', ',':
				etc = input[1..$];
				return input[0];
			default:
				return 0;
		}
	}
	return 0;
}

bool nextToken(string input, out Token outToken, out string etc) {
	skipWhitespace(input);
	if (auto id = readIdentifier(input, etc)) {
		outToken = Token.mkIdentifier(id);
		return true;
	} else if (auto sym = readSymbol(input, etc)) {
		with(Token)
		switch (sym) {
			case '{':
				outToken = Token.mkSimple(Tag.LeftBrace);
				break;
			case '}':
				outToken = Token.mkSimple(Tag.RightBrace);
				break;
			case '(':
				outToken = Token.mkSimple(Tag.LeftParen);
				break;
			case ')':
				outToken = Token.mkSimple(Tag.RightParen);
				break;
			case ',':
				outToken = Token.mkSimple(Tag.Comma);
				break;
			default:
				assert(0, "unknown symbol");
		}
		return true;
	}
	return false;
}

Token[] tokenize(string input) {
	Token[] tokens;
	Token current;
	string etc;
	while (input.length > 0 && nextToken(input, current, etc)) {
		input = etc;
		tokens ~= current;
	}
	return tokens;
}
