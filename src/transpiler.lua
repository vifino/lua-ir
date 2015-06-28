-- Transpiles LLVM IR to Lua code.
--
-- Made by vifino

local preprocess = require("./preprocess.lua")
local prelude = require("./prelude.lua")

function transpile(givensrc) -- LLVM IR in, Lua code out.
	local luasrc = ""
	local data = preprocess(givensrc)

	return prelude..luasrc
end

local function getInstCode(inst, ...) -- getInstCode("ret", "i32", "0") -> 'return 0'

end
