



local lfs = require("lfs")
local inspect = require("inspect")
local lpeg = require("lpeg")
local cjson = require("cjson")


-- local present = (...):gsub(".tools", "")
-- local utils = require(present..".utils")




local mt_fileslist = {}
local mt_file_metadata = {}

local mt_buffer = {}
local mt_buffers = {}


-----------------------------------------------
-- utils
------------------------------------------------


local utils = {}

function utils.afterDot(path)
	return path:match("^[%.]*(.*)$")
end

function utils.concatPaths(left, right)
	left = left:match("(.-)[/]*$")
	right = utils.afterDot(right)
	return left..right
end

function utils.justDir(path)
	return assert(path:match("(.*)/[^/]+$"), "error!!!!!")
end

function utils.beforeDot(path)
	return path:match("^[^%.]*")
end

function utils.path(p)
	return p:match("(.*)/[^/]+$")
end

function utils.dateFromString(str)
	if not str then return nil end
	local d, m, y = str:match("(%d+)/(%d+)/(%d+)")
	d = tonumber(d)
	m = tonumber(m)
	y = tonumber(y)
	if not d or not m or not y then return nil end
	return d, m, y
end

function utils.noLines(str)
	return str:gsub("\n", "")
end

function utils.endsWith(str, patt)
	return string.match(str, patt.."$")
end




-------------------------------------------
-- reading writing
-------------------------------------------

local function readm(filepath, getText)
	local f = assert(io.open(filepath, "r"), "ERROR opening file")
	local data = {}
	local text = ""
	
	while true do
		local line = f:read()
		if not line then break end
		local m = line:match("^#.*")
		if m then
			local key, value = m:match("^#%s*(.+)%s*:%s*(.+)")
			if key and value then
				data[key] = value
			end
		else
			if getText then
				text = text..line.."\n"
			else
				break
			end
		end
	end
	f:close()
	return setmetatable(data, mt_file_metadata), text
end

local function reada(filename)
	local f = assert(io.open(filename, "r"), "ERROR opening file")
	local text = f:read("*a")
	f:close()
	return text
end

local function mkdir(path)
	local str = ""
	for dir in path:gmatch("([^/]+)") do
		str = str..dir.."/"
		lfs.mkdir(str)
	end
end

function write(data, filename)
	assert(filename)
	assert(data)

	local o = io.open(filename, "w")
	if o then
		o:write(data)
		o:close()
		return
	end
	
	local path = utils.path(filename)
	if not path then error("Error with path.") end

	mkdir(path)

	o = io.open(filename, "w")
	if o then
		o:write(data)
		o:close()
		return
	end

	if lfs.attributes(filename, "mode") == "directory" then
		error("Destination is a directory.")
	end

	error("Could not write file.")
end

local function _listFiles(dir, files, pattern)
	--local files = files or {}

	if dir:match("/$") == nil then dir = dir.."/" end
	for f in lfs.dir(dir) do
		if utils.beforeDot(f) ~= "" then
			f = dir..f
			if lfs.attributes(f, "mode") == "directory" then
				_listFiles(f, files, pattern)
			elseif lfs.attributes(f, "mode") == "file" then
				if not pattern then
					table.insert(files, f)
				elseif type(pattern) == "string" and f:match(pattern) then
					table.insert(files, f)
				end
			end
		end
	end
	return files
end

function listFiles(dir, pattern)
	dir = dir or "."
	return _listFiles(dir, setmetatable({}, mt_fileslist),  pattern)
end


-------------------------
-- patterns
-------------------------


local function gsub (s, patt, repl)
  patt = lpeg.Cs((patt / repl + 1)^0)
  return lpeg.match(patt, s)
end


local patterns = {}

do
	local left = lpeg.P("{{")
	local right = lpeg.P("}}")
	patterns.macro = left * lpeg.C((1-right)^0) * right

	left = lpeg.P(">>")
	right = lpeg.P("<<")
	patterns.exec = left * lpeg.C((1-right)^0) * right 

	left = lpeg.P("<body>")
	right = lpeg.P("</body>")
	local content = left * lpeg.C((1-right)^0) * right

	patterns.body = lpeg.P((content + 1)^0)
end

function expand(str, repl)
	-- 	return gsub(str, patterns.macro, function (capture) return repl[capture] end)

	return gsub(str, patterns.macro, repl)
end



----------------------------------------------------------
-- file reading and parsing
------------------------------------------



-- read formatted page
function page(filename, vars)

	local meta, text = readm(filename, true)
	
	if vars then 
		-- text = gsub(text, patterns.macro,
		-- 	function(capture)
		-- 		return vars[capture] or meta[capture]
		-- 	end)
	end

	-- local current = lfs.currentdir()
	-- lfs.chdir(utils.justDir(filename))
	-- text = gsub(text, patterns.exec, function(cap)
	-- 	local env = {}
	-- 	local f = load("return "..cap, ("function: %s"):format(cap), "t", env)
	-- 	local success, v = pcall(f, print)
	-- 	if success then
	-- 		return v
	-- 	else
	-- 		error(("error in parsing: %s, cap: %s"):format(filename, cap))
	-- 	end
	-- end)
	-- lfs.chdir(current)


	return setmetatable({
		name = filename,
		data = text,
		meta = meta
	}, mt_buffer)
end



function pages(dir, vars)
	local buffers = {}
	for k, v in pairs(listFiles(dir)) do
		table.insert(buffers, page(v, vars))
	end
	return setmetatable(buffers, mt_buffers)
end


-- read non-formatted page
function read(f)
	if type(f) == "string" then
		return reada(f)
	end
	if type(f) == "table" then
		local buffers = {}
		for i, v in ipairs(f) do
			table.insert(buffers, reada(f))
		end
		return buffers
	end
end




function markup(text)
	local sep = lpeg.P("\n")
  local elem = lpeg.C((1 - sep)^1) / function (v) return "<p>"..v.."</p>" end
  local line = (1-elem)^0 * elem
  local lines = lpeg.Ct(line * line^0)

	local matches = lines:match(text)

	if not matches then 
		error("text has no non-newline characters")
	end

	local s = table.concat(matches, "\n")

	return s
end



-------------------------------------
-- manipulation
-------------------------------------

local expect = {
	string = function(v) assert(type(v) == "string", "ERROR: expected string, got "..type(v)) end,
	table = function(v) assert(type(v) == "table", "ERROR: expected table, got "..type(v)) end
}

local function concat(...)
	local s = ""
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v then	s = s..v.." " end
	end
	return s
end

function rep(array, stringfunc)
	local s = ""
	for _, v in ipairs(array) do
		s = s..stringfunc(v)
	end
	return s
end

function foreach(array, func)
	for i = 1, #array do
		if func(array[i]) == nil then
			array[i] = nil
		end
	end
	return array
end

local function get_upvalue(fn, search_name)
  local idx = 1
  while true do
    local name, val = debug.getupvalue(fn, idx)
    if not name then break end
    if name == search_name then
      return idx, val
    end
    idx = idx + 1
  end
end

function map(array, func, newglobals)
	if newglobals then
		local env_i, env = get_upvalue(func, "_ENV")
		for k, v in pairs(newglobals) do
			env[k] = v
		end
	end

	local ret = {}
	for i = 1, #array do
		ret[#ret+1] = func(array[i])
	end
	return ret
end


function map_inplace(array, func)
	local write_i = 0
	local n = #array --cache, so splitting the sequence doesn't stop iteration

	for i = 1, n do
		local v = func(array[i])

		if v ~= nil then
			write_i = write_i + 1
			array[write_i] = v
		end

		if i ~= write_i then
			array[i] = nil
		end
	end
	return array
end

function filter(array, func)
	local ret = {}
	for i = 1, #array do
		local v = array[i]
		if func(v) then
			table.insert(ret, v)
		end
	end
	return ret
end



function separate(array, ...)

	local filters = {...}
	local num_filters = #filters

	-- prepare return table
	local separated = {}
	for j = 1, num_filters do separated[j] = {} end

	for i = 1, #array do
		for j = 1, num_filters do
			local v = filters[j](array[i])
			if v then
				table.insert(separated[j], array[i])
				break
			end
		end
	end

	return table.unpack(separated)
end


function smatch(array, ...)

	local patterns = {...}
	local num_patts = #patterns

	-- prepare return table
	local piles = {}
	for j = 1, num_patts do
		piles[j] = {}
	end

	for i = 1, #array do
		for j = 1, num_patts do
			local match = string.match(array[i], patterns[j])
			if match then
				table.insert(piles[j], array[i])
			end		
		end
	end

	return table.unpack(piles)
end



----------------------------------
-- methods
----------------------------------

-- function mt_fileslist.__tostring(self)
-- 	local s = ""
-- 	for i, v in ipairs(self) do
-- 		s = s..("%s - %s\n"):format(i, v)
-- 	end
-- 	return s
-- end


mt_fileslist.__index = mt_fileslist
mt_fileslist.foreach = foreach
mt_fileslist.rep = rep
mt_fileslist.map = map




-- function mt_fileslist.sortByDate(self)
-- 	print("implement later")
-- end


mt_buffer.__index = mt_buffer

-- function mt_buffer.__tostring(self)
-- 	return ("name: %s\ndata: %s\nmeta: %s\n"):format(self.name, self.data:sub(1, 30):gsub("\n", "").."...", tostring(self.meta))
-- end

function mt_buffer.write(self, dest)
	-- what's self.name again?
	write(dest or self.name, self.data)
end


mt_buffers.__index = mt_buffers
mt_buffers.rep = rep
mt_buffers.foreach = foreach
mt_buffers.map = map

mt_buffers.map_inplace = map_inplace


mt_buffers.filter = filter
mt_buffers.smatch = smatch


-- function mt_buffers.__tostring(self)
-- 	local s = ""
-- 	for _, buf in ipairs(self) do
-- 		s = s.."\n"..tostring(buf)
-- 	end
-- 	return s
-- end

function mt_buffers.encodejson(self)
	local ret = {}
	for k, v in pairs(self) do
		v.data = nil
		table.insert(ret, v)
	end
	return cjson.encode(ret)
end




function mt_buffers.write(self, destDir)
	for _, buffer in ipairs(self) do
		local name = utils.concatPaths(destDir, buffer.name)
		write(name, buffer.data)
	end
end

function mt_buffers.sortByDate(self)
	for k, v in ipairs(self) do
		local day, month, year = utils.dateFromString(v.meta.date)
		if day then
			v.day, v.month, v.year = day, month, year
		else
			v.day, v.month, v.year = 0, 0, 0
		end
	end

	table.sort(self, function(a, b)
		-- sort function has to check each possibility

		if a.month > b.month then
			return true
		elseif a.month == b.month then
			if a.day > b.day then
				return true
			end
		end

	end)

	-- table.sort(self, function(a, b) return b.year > a.year end)
	-- table.sort(self, function(a, b) return b.month > a.month end)
	-- table.sort(self, function(a, b) return b.day > a.day end)
end

-- function mt_file_metadata.__tostring(self)
-- 	local s = ""
-- 	for k, v in pairs(self) do
-- 		s = s..("\n  %s: %s"):format(k, v)
-- 	end
-- 	s = s.."\n"
-- 	return s
-- end





return module