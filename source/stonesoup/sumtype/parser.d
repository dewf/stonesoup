module stonesoup.sumtype.parser;

import std.stdio;
import stonesoup.sumtype.tokenizer: Token, tokenize;
import std.typecons: Nullable, nullable;
import std.exception: enforce;

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

struct NamedParam {
	string type;
	string name;
}

struct CasePayload {
	enum Tag { NameOnly, SingleType, NamedParams }
	union Content {
		string singleType;
		NamedParam[] namedParams;
	}
	Tag _tag;
	Content content;

	Tag tag() => _tag;

	static CasePayload makeNameOnly() {
		return CasePayload(Tag.NameOnly, Content());
	}
	bool isNameOnly() {
		return _tag == Tag.NameOnly;
	}

	static CasePayload makeSingleType(string type) {
		Content c = { singleType: type };
		return CasePayload(Tag.SingleType, c);
	}
	const (string)* isSingleType() {
		return _tag == Tag.SingleType ? &content.singleType : null;
	}
	string singleType() {
		enforce(_tag == Tag.SingleType, "CasePayload.singleType(): tag didn't match");
		return content.singleType;
	}

	static CasePayload makeNamedParams(NamedParam[] params) {
		Content c = { namedParams: params };
		return CasePayload(Tag.NamedParams, c);
	}
	const (NamedParam[]) isNamedParams() {
		return _tag == Tag.NamedParams ? content.namedParams : null;
	}

	struct _NameOnly {}
	T match(T)(
		T delegate(ref const(_NameOnly)) nameOnlyFunc,
		T delegate(string) singleTypeFunc,
		T delegate(ref const(NamedParam[]))  namedParamsFunc)
	{
		_NameOnly fakeArg;
		final switch(_tag) {
			case Tag.NameOnly:
				return nameOnlyFunc(fakeArg);
			case Tag.SingleType:
				return singleTypeFunc(content.singleType);
			case Tag.NamedParams:
				return namedParamsFunc(content.namedParams);
		}
	}
}

struct Case {
	string name;
	CasePayload payload;
}

struct ParseResult(T) {
	bool _success;
	T thing;
	Token[] etc;
	bool opCast(T: bool)() const {
		return _success;
	}
	static ParseResult success(T thing, Token[] etc) {
		return ParseResult!T(true, thing, etc);
	}
	static ParseResult fail() {
		return ParseResult!T(false);
	}
}

ParseResult!bool parseCommaOrEnd(Token[] input) {
	if (input.length == 0) {
		return ParseResult!bool.success(true, input); // already at end, no need to advance
	} else if (tryToken(input, 0, t => t.isComma())) {
		return ParseResult!bool.success(true, input[1..$]);
	} else {
		// something amiss ...
		return ParseResult!bool.fail();
	}
}

T tryToken(T)(Token[] input, int index, T delegate(Token t) func) {
	if (input.length > index) {
		return func(input[index]);
	}
	return T.init;
}

bool tryToken(T)(Token[] input, int index, T delegate(Token t) func, out T outVar) {
	if (input.length > index) {
		outVar = func(input[index]);
		return true;
	}
	return false;
}

void advance(ref Token[] tokens) {
	if (tokens.length > 0) {
		tokens = tokens[1..$];
	} else {
		throw new Exception("advance() on tokens failed - none left!");
	}
}

ParseResult!NamedParam parseNamedParam(Token[] input) {
	if (auto type = tryToken(input, 0, t => t.isIdentifier())) {
		if (auto name = tryToken(input, 1, t => t.isIdentifier())) {
			// auto outParam = NamedParam(type, name);
			// Token[] etc;
			// if (tryToken(input, 2, t => t.isComma())) {
			// 	etc = input[3..$];
			// } else {
			// 	etc = input[2..$];
			// }
			return ParseResult!NamedParam.success(NamedParam(type, name), input[2..$]);
		}
	}
	return ParseResult!NamedParam.fail();
}

ParseResult!(NamedParam[]) parseNamedParams(Token[] input) {
	NamedParam[] params;
	while (auto npResult = parseNamedParam(input)) {
		params ~= npResult.thing;
		// input = npResult.etc;
		if (auto commaResult = parseCommaOrEnd(npResult.etc)) {
			input = commaResult.etc;
		} else {
			// missing required comma (or end of input)
			return ParseResult!(NamedParam[]).fail();
		}
	}
	if (params.length > 0) {
		return ParseResult!(NamedParam[]).success(params, input); // input is effective etc, see above - also, if the above works, it should be empty
	}
	return ParseResult!(NamedParam[]).fail();
}

bool parseCase(Token[] input, out Case outCase, out Token[] etc) {
	if (auto name = tryToken(input, 0, t => t.isIdentifier())) {
		// does it have params?
		if (tryToken(input, 1, t => t.isLeftParen())) {
			if (auto content = contentBetween(Token.Tag.LeftParen, Token.Tag.RightParen, input[1..$], etc)) {
				string id;
				// first check - is it a single unnamed type?
				if (content.length == 1 && tryToken(content, 0, t => t.isIdentifier(), id)) {
					outCase = Case(name, CasePayload.makeSingleType(id));
				} else if (auto pnpResult = parseNamedParams(content)) {
					outCase = Case(name, CasePayload.makeNamedParams(pnpResult.thing));
				}
				// etc should be good

				// comma required unless we're at the end of input
				if (auto commaResult = parseCommaOrEnd(etc)) {
					etc = commaResult.etc;
					return true;
				} else {
					// neither comma nor end, boo
					return false;
				}
			}
			// had left parent, but couldn't match to right, bad!
			return false;
		}
		// else
		// no params, just name
		outCase = Case(name, CasePayload.makeNameOnly());
		// advance past name
		advance(input);
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
	string[] typeParams;
	Case[] cases;
}

string[] parseTypeParams(Token[] input) {
	string[] typeParams;
	string current;
	while(tryToken(input, 0, t => t.isIdentifier(), current)) {
		typeParams ~= current;
		// advance past identifier
		advance(input);
		if (input.length == 0) {
			// all done
			return typeParams;
		} else if (tryToken(input, 0, t => t.isComma())) {
			// skip comma and continue
			advance(input);
		}
	}
	return null;
}

Nullable!SumType parseSumType(string input) {
	auto tokens = tokenize(input);
	if (auto name = tryToken(tokens, 0, t => t.isIdentifier())) {
		// this advancing is bad in general, because we're mutating something that doesn't only belong to this branch
		// this this function we don't have any 'else' branches, so it's OK for the moment
		advance(tokens);

		// does it have type parameters?
		string[] typeParams;
		if (tryToken(tokens, 0, t => t.isLeftParen)) {
			Token[] afterRightParen;
			if (auto content = contentBetween(Token.Tag.LeftParen, Token.Tag.RightParen, tokens[0..$], afterRightParen)) {
				if (auto tp = parseTypeParams(content)) {
					// cool, done
					typeParams = tp;
					// advance beyond
					tokens = afterRightParen;
				}
			}
		}

		// parse content
		if (tryToken(tokens, 0, t => t.isLeftBrace)) {
			// might have something ...
			Token[] etc_unused;
			if (auto content = contentBetween(Token.Tag.LeftBrace, Token.Tag.RightBrace, tokens[0..$], etc_unused)) {
				auto cases = parseCases(content);
				return nullable(SumType(name, typeParams, cases));
			}
		}
	}
	return Nullable!SumType();
}
