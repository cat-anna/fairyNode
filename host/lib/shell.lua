local shell = { }

function shell.Buildcmd(cmd, argsdict, argtable, ...)
	local t = { cmd }
	
	for k,v in pairs(argsdict or {}) do
		if k:len() == 1 then
			t[#t + 1] = "-" .. k;
		else
			t[#t + 1] = "--" .. k;
		end
		t[#t + 1] = "'" .. v .. "'"
	end
	
	for k,v in ipairs(argsdict or {}) do
		if k:len() == 1 then
			t[#t + 1] = "-" .. k;
		else
			t[#t + 1] = "--" .. k;
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
		return line
	end
end

function shell.LinesOf(...)
	local r = { }
	local l
	for l in shell.ForEachLineOf(...) do
		r[#r + 1] = l
	end
	return r
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