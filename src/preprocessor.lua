-- IR Preprocessor, strips out unneeded parts and extracts basic information.
--
-- Made by vifino

function preprocess(src) -- Takes src in string form, returns a table, the preprocessed string is named "src".
	local info = {
		moduleid="",
		triple="",
		datalayout=""
	}
	local attributes = {}
	-- Extract information and clean up a little.
	local newsrc = string.gsub("\n"..tostring(src), "(\n; ModuleID = '(.-)')", function(_,module) -- ModuleID
		info.moduleid = module
		return ""
	end):gsub("(\ntarget (.-) = \"(.-)\")", function(_, name, val) -- target triple/datalayout
		info[name] = val
		return ""
	end):gsub("\nattributes #(%d+) = {(.-)}", function(number, attr)
		local vals = {}
		local attr = " "..attr.." "
		attr:gsub('("(.-)")', function(_, name)
			vals[name] = true
			return ""
		end):gsub('("(.-)"="(.-)")', function(_, name, val)
			local value = val
			if val == "true" then
				value = true
			elseif val == "false" then
				value = false
			end
			vals[name] = value
			return ""
		end):gsub(' (.-) ', function(name)
			vals[name] = true
		end)
		attributes[tostring(number)] = vals
		return ""
	end)

	-- Clean up the rest.
	local cleansrc = newsrc:gsub("(\n;.-)\n", "")

	return {
		src=cleansrc:gsub("^(\n+)",""):gsub("(\n+)", "\n"),
		info=info,
		attributes=attributes
	}
end
return preprocess
