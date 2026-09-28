module stonesoup.sumtype.parser;

import stonesoup.sumtype.tokenizer: Token, tokenize;
import std.typecons: Nullable, nullable;

Token[] contentBetween(Token.Tag start, Token.Tag end, Token[] input, out Token[] etc) {
	if (input.length == 0) return null;
	if (input[0].tag == start) {
		// seek to end tag, ignoring nested
		int i = 1;
		int level;
		while (i < input.length) {
			if (input[i].tag == start) {
				level++;
			} else if (input[i].tag == end) {
				if (level > 0) {
					level--;
				} else {
					// done! return inner content + etc
					etc = input[i + 1 .. $]; // +1 to skip the end token!
					return input[1 .. i];    // up to the end token
				}
			}
			i++;
		}
		// oops, went past the end
	}
	return null;
}

struct Param {
	string type;
	string name;
}

struct Case {
	string name;
	Param[] params;
}

T tryToken(T)(Token[] input, int index, T delegate(Token t) func) {
	if (input.length > index) {
		return func(input[index]);
	}
	return T.init;
}

bool parseParam(Token[] input, out Param outParam, out Token[] etc) {
	if (auto type = tryToken(input, 0, t => t.isIdentifier())) {
		if (auto name = tryToken(input, 1, t => t.isIdentifier())) {
			outParam = Param(type, name);
			if (tryToken(input, 2, t => t.isComma())) {
				etc = input[3..$];
			} else {
				etc = input[2..$];
			}
			return true;
		}
	}
	return false;
}

Param[] parseParams(Token[] input) {
	Param[] params;
	Param current;
	Token[] etc;
	while (input.length > 0 && parseParam(input, current, etc)) {
		params ~= current;
		input = etc;
	}
	return params;
}

bool parseCase(Token[] input, out Case outCase, out Token[] etc) {
	if (auto name = tryToken(input, 0, t => t.isIdentifier())) {
		// does it have params?
		if (tryToken(input, 1, t => t.isLeftParen())) {
			if (auto content = contentBetween(Token.Tag.LeftParen, Token.Tag.RightParen, input[1..$], etc)) {
				auto params = parseParams(content);
				outCase = Case(name, params);
				// etc should be good
				// comma required unless we're at the end of input
				if (etc.length > 0 && etc[0].isComma()) {
					etc = etc[1..$];
					return true;
				} else if (etc.length == 0) {
					return true;
				} else {
					// neither comma nor end of stream, bad
					return false;
				}
			}
			// had left parent, but couldn't match to right, bad!
			return false;
		}
		// else
		// no params, just name
		outCase = Case(name, []);
		// advance past name
		input = input[1..$];
		// comma required unless we're at the end of input
		if (input.length > 0 && input[0].isComma()) {
			// OK
			etc = input[1..$];
			return true;
		} else if (input.length == 0) {
			// nothing more, no comma needed
			etc = input;
			return true;
		} else {
			// else neither comma nor end of stream, bad
			return false;
		}
	}
	// not even a name - totally bad
	return false;
}

Case[] parseCases(Token[] input) {
	Case[] cases;
	Case current;
	Token[] etc;
	while (input.length > 0 && parseCase(input, current, etc)) {
		cases ~= current;
		input = etc;
	}
	return cases;
}

struct SumType {
	string name;
	Case[] cases;
}

Nullable!SumType parseSumType(string input) {
	auto tokens = tokenize(input);
	if (auto name = tryToken(tokens, 0, t => t.isIdentifier())) {
		if (tryToken(tokens, 1, t => t.isLeftBrace)) {
			// might have something ...
			Token[] etc_unused;
			if (auto content = contentBetween(Token.Tag.LeftBrace, Token.Tag.RightBrace, tokens[1..$], etc_unused)) {
				auto cases = parseCases(content);
				return nullable(SumType(name, cases));
			}
		}
	}
	return Nullable!SumType();
}
