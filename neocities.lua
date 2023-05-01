
local curl = require("lcurl")
local expect = {
	string = function(v) assert(type(v) == "string", "ERROR: expected string, got "..type(v)) end,
	table = function(v) assert(type(v) == "table", "ERROR: expected table, got "..type(v)) end
}


local api = {}
local auth = {
	user = nil,
	pass = nil
}

function api.getInfo(sitename, writefunction)
	curl.easy({
		url = ("https://neocities.org/api/info?sitename=%s"):format(sitename),
		writefunction = writefunction or print,
	})
	:perform()
	:close()
end

-- function api.uploadFile(name, path)
-- 	-- print("posting...")
-- 	curl.easy()
-- 		:setopt_url(("https://%s:%s@neocities.org/api/upload"):format(auth.user, auth.pass))
-- 		:setopt_writefunction(print)
-- 		:setopt_httppost(curl.form()
-- 			:add_file(name, path, "multipart/form-data")
-- 		)
-- 		:perform()
-- 	:close()
-- end

function api.uploadFiles(files, writefunction)
	expect.table(files)
	local form = curl.form()
	for k, v in pairs(files) do
		local name
		local path

		if type(k) ~= "number" then
			error("Table of tables expected.")
		end

		if type(v) == "table" then
			name = v.name
			path = v.path
		else
			error("Table of tables expected.")
		end

		assert(name)
		assert(path)

		-- local name
		-- local path
		-- if type(v) == "table" then
		-- 	name = v.name
		-- 	path = v.path
		-- end
		-- assert(name)
		-- assert(path)
		form:add_file(name, path, "multipart/form-data")
	end

	curl.easy()
		:setopt_url(("https://%s:%s@neocities.org/api/upload"):format(auth.user, auth.pass))
		:setopt_writefunction(writefunction or print)
		:setopt_httppost(form)
		:perform()
	:close()
end

function api.uploadData(buffers)
	local form = curl.form()
	for k, v in pairs(buffers) do
		local name
		local data

		if type(k) ~= "number" then
			error("Table of tables expected.")
		end

		if type(v) == "table" then
			name = v.name
			data = v.data
		else
			error("Table of tables expected.")
		end

		assert(name)
		assert(data)
		form:add_buffer(name, name, data, "multipart/form-data")
	end

	curl.easy()
		:setopt_url(("https://%s:%s@neocities.org/api/upload"):format(auth.user, auth.pass))
		:setopt_writefunction(print)
		:setopt_httppost(form)
		:perform()
	:close()
end


-- genetic upload function
-- take buffer, filename, directory name



function api.upload(t, resp)

	expect.table(t)
	local form = curl.form()

	for i, t in ipairs(t) do
		expect.table(t)


		if t.data then

			-- has to have a name
			assert(t.name, ("Buffer must be given a remote name."))
			form:add_buffer(t.name, t.name, t.data, "multipart/form-data")
		end

		if t.path then

			-- does not have to have a name
			form:add_file(t.name or t.path, t.path, "multipart/form-data")
		end
	end


	curl.easy()
		:setopt_url(("https://%s:%s@neocities.org/api/upload"):format(auth.user, auth.pass))
		:setopt_writefunction(resp or print)
		:setopt_httppost(form)
		:perform()
	:close()


end


-- todo: multi delete
function api.delete(name)
	expect.string(name)
	local form = curl.form()
	form:add_content("filenames[]", name)
	curl.easy()
		:setopt_url(("https://%s:%s@neocities.org/api/delete"):format(auth.user, auth.pass))
		:setopt_writefunction(print)
		:setopt_httppost(form)
		:perform()
	:close()
end

function api.list(path, writefunction)
	local url = ("https://%s:%s@neocities.org/api/list"):format(auth.user, auth.pass)
	if path then url = url.."?path="..path end
	writefunction = writefunction or print
	curl.easy({
	  url = url,
	  writefunction = writefunction
	})
	:perform()
	:close()
end

return setmetatable({}, {
	__index = function() error("[NEOCITIES API] Initialize module by calling it with username and password") end,
	__call = function(_, user, pass) 
		assert(user, "[NEOCITIES API] No username")
		assert(pass, "[NEOCITIES API] No password")
		auth.user = user
		auth.pass = pass
		return api
	end
})