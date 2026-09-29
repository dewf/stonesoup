module stonesoup.sumtype.parser;

import stonesoup.sumtype.tokenizer: Token, tokenize;
import std.typecons: Nullable, nullable;
import std.exception: enforce;

T tryToken(T)(Token[] input, int index, T delegate(Token t) func) {
	if (input.length > index) {
		return func(input[index]);
	}
	return T.init;
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

ParseResult!string parseIdentifier(Token[] input) {
	if (auto id = tryToken(input, 0, t => t.isIdentifier)) {
		return ParseResult!string.success(id, input[1..$]);
	}
	return ParseResult!string.fail();
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

ParseResult!(Token[]) parseContentBetween(Token[] input, Token.Tag start, Token.Tag end) {
	if (input.length >= 2) {
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
						auto inner = input[1 .. i];   // up to the end token
						auto etc = input[i + 1 .. $]; // +1 to skip the end token!
						return ParseResult!(Token[]).success(inner, etc);
					}
				}
				i++;
			}
			// oops, went past the end
		}
		// start tag didn't match
	}
	// input wasn't even long enough for start/end tokens!
	return ParseResult!(Token[]).fail();
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

ParseResult!NamedParam parseNamedParam(Token[] input) {
	if (auto type = tryToken(input, 0, t => t.isIdentifier())) {
		if (auto name = tryToken(input, 1, t => t.isIdentifier())) {
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

ParseResult!string parseSingleType(Token[] input) {
	if (auto result = parseIdentifier(input)) {
		if (result.etc.length == 0) {
			return ParseResult!string.success(result.thing, result.etc);
		}
		// else had some other crap
	}
	// else not an identifier
	return ParseResult!string.fail();
}

ParseResult!Case parseCase(Token[] input) {
	if (auto nameResult = parseIdentifier(input)) {
		// does it have params + content?
		if (auto contentResult = parseContentBetween(nameResult.etc, Token.Tag.LeftParen, Token.Tag.RightParen)) {
			auto content = contentResult.thing;
			auto etc = contentResult.etc;

			if (auto singleType = parseSingleType(content)) {
				auto c = Case(nameResult.thing, CasePayload.makeSingleType(singleType.thing));
				return ParseResult!Case.success(c, etc);
			} else if (auto namedParams = parseNamedParams(content)) {
				auto c = Case(nameResult.thing, CasePayload.makeNamedParams(namedParams.thing));
				return ParseResult!Case.success(c, etc);
			} else {
				// otherwise unexpected
				return ParseResult!Case.fail();
			}
		} else {
			// just a name
			auto c = Case(nameResult.thing, CasePayload.makeNameOnly());
			return ParseResult!Case.success(c, nameResult.etc);
		}
	} // else no identifier
	return ParseResult!Case.fail();
}

ParseResult!(Case[]) parseCases(Token[] input) {
	Case[] cases;
	while (auto caseResult = parseCase(input)) {
		cases ~= caseResult.thing;
		if (auto commaOrEnd = parseCommaOrEnd(caseResult.etc)) {
			input = commaOrEnd.etc;
		} else {
			// missing required comma (or end of input)
			return ParseResult!(Case[]).fail();
		}
	}
	if (cases.length > 0) {
		return ParseResult!(Case[]).success(cases, input); // input effectively etc
	}
	// not a single case!
	return ParseResult!(Case[]).fail();
}

struct SumType {
	string name;
	string[] typeParams;
	Case[] cases;
}

ParseResult!(string[]) parseTypeParams(Token[] input) {
	string[] typeParams;
	while(auto id = parseIdentifier(input)) {
		typeParams ~= id.thing;

		if (auto commaOrEnd = parseCommaOrEnd(id.etc)) {
			input = commaOrEnd.etc;
		} else {
			// missing comma, or failed to end
			return ParseResult!(string[]).fail();
		}
	}
	if (typeParams.length == 0) {
		// needed at least one ...
		return ParseResult!(string[]).fail();
	}
	return ParseResult!(string[]).success(typeParams, input); // input is effective etc
}

ParseResult!SumType parseSumType(string input) {
	auto tokens = tokenize(input);
	if (auto name = parseIdentifier(tokens)) {
		auto startFrom = name.etc;

		// optional type parameters
		string[] typeParams;
		if (auto content = parseContentBetween(startFrom, Token.Tag.LeftParen, Token.Tag.RightParen)) {
			if (auto tpResult = parseTypeParams(content.thing)) {
				typeParams = tpResult.thing;
				startFrom = content.etc; // outside of right paren
			}
		}

		// parse content
		if (auto content = parseContentBetween(startFrom, Token.Tag.LeftBrace, Token.Tag.RightBrace)) {
			if (auto cases = parseCases(content.thing)) {
				return ParseResult!SumType.success(SumType(name.thing, typeParams, cases.thing), content.etc);
			}
			// else had no cases
		}
		// else had no braced content
	}
	// else no name
	return ParseResult!SumType.fail();
}
