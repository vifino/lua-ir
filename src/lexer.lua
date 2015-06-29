--IR Lexer, tokenizes the IR
--

local lexer = {}

local function unescape(str) --TODO: This could be optimized with pattern matching
	if str == "" then return str end
	
	local buffer = {}
	local i = 1
	while i <= #str do
		if str:sub(i,i) == "\\" then
			if str:sub(i+1,i+1) == "\\\\" then
				buffer[#buffer+1] = "\\"
				i = i+2
			elseif str:sub(i+1,i+2):find("%x%x") then
				buffer[#buffer+1] = string.char(tonumber(str:sub(i+1,i+2),16))
				i = i+3
			else
				buffer[#buffer+1] = str:sub(i+1,i+1)
				i = i+2
			end
		else
			buffer[#buffer+1] = str:sub(i,i) --TODO: Optimize this a little, find next \\
			i = i+1
		end
	end
	return table.concat(buffer)
end

print(unescape("x86_64-unknown-linux-gnu"))

local function isLabelChar(c)
	return select(2,c:find("0-9%-%$%._"))
end

local function isLabelTail(c, i)
	return c:find("^[0-9%-%$%._]*:$", i)
end

function lexer.new(buffer)
	local i = 1
	local TokStart
	local function getNextChar()
		if i > #buffer then
			return -1
		else
			i = i+1
			return buffer:sub(i-1,i-1)
		end
	end
	
	local function readVarName()
		local s, e, n = buffer:find("([%-a-zA-Z%$._][%-a-zA-Z%$._0-9]*)", i)
		if s then
			i = e+1
			return n
		end
	end
	
	local function readString(kind)
		local s, e, n = buffer:find("^\"([^\"]*)\"", i-1)
		if s then
			i = e+1
			print(n)
			return kind, unescape(n)
		end
		return "ERROR"
	end
	
	local function skipLineComment()
		while true do
			if buffer:sub(i,i):find("\r\n") or getNextChar() == -1 then
				return
			end
		end
	end
	
	local function lexVar(var, varid)
		local kind, str = readString(var)
		if kind ~= "ERROR" then
			return var, str
		end
		
		local name = readVarName()
		if name then
			return name
		end
		
		--id
		local s,e,id = buffer:find("([0-9]+)",i)
		if s then
			i = e+1
			return varid, tonumber(id)
		end
		
		return "ERROR"
	end
	
	local function lexAt()
		return lexVar("GLOBALVAR", "GLOBALID")
	end
	
	local function lexDollar()
		local e = isLabelTail(buffer, i)
		if e then
			i = e+1
			return "LABELSTR", buffer:sub(TokStart, i-1)
		end
		
		if buffer:sub(i,i) == "\"" then
			return "COMDATVAR", unescape(buffer:match("\"([^\"]*)\"", i))
		end
		
		local varname = readVarName()
		if varname then
			return "COMDATVAR"
		end
		
		return "ERROR"
	end
	
	local function lexPercent()
		return lexVar("LOCALVAR", "LOCALVARID")
	end
	
	local function lexQuote()
		local kind, str = readString("STRINGCONSTANT")
		if kind == "ERROR" then
			return kind
		end
		
		if buffer:sub(i,i) == ":" then
			i = i+1
			kind = "LABELSTR"
		end
		
		return kind, str
	end
	
	local function lexExclaim()
		if buffer:find("^[A-Z-$._\\]",i) then
			--metadatavar
			i = i+1
			while buffer:find("^[A-Z-$._\\]",i) do
				i = i+1
			end
			return "METADATAVAR", unescape(buffer:sub(TokStart+1, i))
		end
		
		return "EXCLAIM"
	end
	
	local keywords = {
		--TODO: keywords
	}
	
	local typewords = {
	
	}
	
	local instruction = {
		
	}
	
	local function lexIdentifier()
		local start = i
		local intEnd
		if buffer:sub(i-1,i-1) ~= "i" then intEnd = i end
		local keywordEnd
		
		while isLabelChar(buffer:sub(i,i)) do
			if (not intEnd) and not buffer:find("^%d", i) then intEnd = i end
			if (not keywordEnd) and not buffer:find("^[A-Za-z0-9]", i) then keywordEnd = i end
			i=i+1
		end
		
		if buffer:sub(i,i) == ":" then
			i = i+1
			return "LABELSTR", buffer:sub(start-1, i-1)
		end
		
		if not intEnd then intEnd = i end
		if intEnd ~= start then
			--integer type
			return "TYPE", {type="int", size=buffer:sub(start-1, i)}
		end
		
		if not keywordEnd then keywordEnd = i end
		i = keywordEnd
		start = start-1
		local keyword = buffer:sub(start, i)
		if keywords[i] then
			return i:upper()
		elseif typewords[i] then
			return typewords[i]
		elseif instruction[i] then
			return "INSTRUCTION", instruction[i]
		end
		
		--TODO: Parse the rest of the tokens
		
		return "ERROR"
	end
	
	local function lexHash()
		if buffer:find("^%d",i) then
			while buffer:find("^%d",i) do i = i+1 end
			return "ATTRGRPID", tonumber(buffer:sub(TokStart+1, i))
		end
		
		return "ERROR"
	end
	
	local function lexPositive()
		local s, e, number = buffer:find("[0-9]+[.][0-9]*[eE][-+]?[0-9]+", i)
		if not number then
			local s, e, number = buffer:find("[0-9]+[.][0-9]*", i)
			i = e+1
			return "APFLOAT", tonumber(number)
		else
			i = e+1
			return "APFLOAT", tonumber(number)
		end
	end
	
	local function lex0x()
		local s, e, h = buffer:find("([0-9A-Fa-f]+)", i)
		if s then
			i = e+1
			return "APFLOAT", tonumber(h, 16)
		end
		return "ERROR"
	end
	
	local tokenLUT = { --normally I don't use lookup tables, but when I do, they look sexy.
		['+'] = lexPositive,
		['@'] = lexAt,
		['$'] = lexDollar,
		['%'] = lexPercent,
		['"'] = lexQuote,
		['!'] = lexExclaim,
		['#'] = lexHash,
		['0'] = lexDigitOrNegative,
		['1'] = lexDigitOrNegative,
		['2'] = lexDigitOrNegative,
		['3'] = lexDigitOrNegative,
		['4'] = lexDigitOrNegative,
		['5'] = lexDigitOrNegative,
		['6'] = lexDigitOrNegative,
		['7'] = lexDigitOrNegative,
		['8'] = lexDigitOrNegative,
		['9'] = lexDigitOrNegative,
		['-'] = lexDigitOrNegative,
		['='] = "EQUAL",
		['['] = "LSQUARE",
		[']'] = "RSQUARE",
		['{'] = "LBRACE",
		['}'] = "RBRACE",
		['<'] = "LESS",
		['>'] = "GREATER",
		['('] = "LPAREN",
		[')'] = "RPAREN",
		[','] = "COMMA",
		['*'] = "STAR",
		['|'] = "BAR",
	}
	
	local function getToken()
		TokStart = i
		local CurChar = getNextChar()
		--TODO: Prioritize IF statement to milk out the most performance
		if CurChar == -1 then
			return "EOF"
		elseif CurChar:find("[%z%s]") then
			--ignore whitespace
			return getToken()
		elseif tokenLUT[CurChar] then
			local t = tokenLUT[CurChar]
			if type(t) == "function" then
				return t()
			else
				return t
			end
		elseif CurChar == "." then
			local e = isLabelTail(buffer, i)
			if e then
				i = e+1
				return "LABELSTR", buffer:sub(TokStart, i-1)
			end
			
			if buffer:sub(i,i+1) == ".." then
				return "DOTDOTDOT"
			end
			
			return "ERROR"
		elseif CurChar == ";" then
			skipLineComment()
			return getToken()
		end
	end
	
	return getToken
end

return lexer
