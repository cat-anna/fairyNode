local shell = { }

function shell.Buildcmd(cmd, argsdict, argtable, ...)
	local t = { }
	if cmd then
		table.insert(t, tostring(cmd))
	end

	for k,v in pairs(argsdict or {}) do
		if type(k) == "number" then
			if v:len() == 1 then
				t[#t + 1] = "-" .. v;
			else
				t[#t + 1] = "--" .. v;
			end
		else
			if k:len() == 1 then
				t[#t + 1] = "-" .. k;
			else
				t[#t + 1] = "--" .. k;
			end
			t[#t + 1] = "'" .. v .. "'"
		end
	end

	for i,v in ipairs(argtable or {}) do
		t[#t + 1] = v
	end

	for i,v in ipairs({...}) do
		t[#t + 1] = v
	end

	return table.concat(t, " ")
end

function shell.Start(...)
	return shell.Execute(shell.Buildcmd(...))
end

function shell.Execute(cmd)
	print("OS: ".. cmd)
	local file = io.popen(cmd)
	local l
	while true do
		l = file:read "*l"
		if not l then
			break
		end
	end
	return file:close()
end

function shell.ForEachLineOf(...)
	local c = shell.Buildcmd(...)
	print("OS: ".. c)

	local h = io.popen(c)

	return function()
		local line = h:read "*l"
		if not line then
			h:close()
			return nil
		end
		print("OS: " .. line)
		return line
	end
end

function shell.LinesOf(...)
	local c = shell.Buildcmd(...)
	print("OS: ".. c)

	local h = io.popen(c)
	local lines = { }
	while true do
		local line = h:read "*l"
		if not line then
			return lines, h:close()
		end
		print("OS: " .. line)
		table.insert(lines, line)
	end
end

function shell.FileSize(fn)
	local file = io.open(fn)
	if not file then
		error(string.format("Unable to open file '%s' to get file size!", fn))
		return 0
	end
	local size = file:seek("end")    -- get file size
	file:close()
	return size
end

return shell