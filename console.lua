-- Console "class"
local Console = {}
Console.__index = Console

local utf8 = require("utf8")

function Console.new(x, y, w, h, host)
	local self = setmetatable({}, Console)
	self.host = host

	self.lineWidth = 5
	self.x = x + self.lineWidth
	self.y = y - self.lineWidth
	self.w = w - 2 * self.lineWidth
	self.h = h - 2 * self.lineWidth

	self.permLog = ""
	self.tempLog = {"Welcome to 3DSculptor.\n" ..
		"Run 'listCommands' to see all commmands\n" ..
		"Run 'help [command]' to get help with a command"}
	self.logIndex = 1
	self.text = ""
	self.textScale = 2

	self.timer = 0
	self.backSpaceHoldTimer = 0

	self.args = {}
	self.commands = {
		["listCommands"] = function() self:comListCommands() end,
		["help"] = function() self:comHelp() end,
		["load"] = function() self:comLoadModel() end,
		["save"] = function() self:comSaveModel() end,
		["addVertex"] = function() self:comAddVertex() end,
		["removeVertex"] = function() self:comRemoveVertex() end,
		["connect"] = function() self:comConnect() end,
		["disconnect"] = function() self:comDisconnect() end,
		["vertexNumbering"] = function() self:comVertexNumbering() end,
		["vertexCoords"] = function() self:comVertexCoords() end,
		["spinXZ"] = function() self:comSpinXZ() end,
		["spinYZ"] = function() self:comSpinYZ() end,
		["setDistance"] = function() self:comSetDistance() end,
		["clear"] = function() self:comClear() end
	}
	self.response = ""
	return self
end

function Console:comListCommands()
	self.response = "listCommands, help, load, save, addVertex, connect, vertexNumbering, " .. 
		"vertexCoords, spinXZ, spinYZ, setDistance, clear"
end

function Console:comHelp()
	local helpDictionary = {
		["listCommands"] = "Lists all commands, use 'listCommands'",
		["help"] = "Gets information about a command, use 'help [command]'",
		["load"] = "Loads a model, use 'load [filename]'",
		["save"] = "Saves a model, use 'save [filename]'",
		["addVertex"] = "Adds a vertex, use 'addVertex [x] [y] [z]'",
		['removeVertex'] = "Removes a vertex, use 'removeVertex [vertex]'",
		["connect"] = "Connects two vertices, use 'connect [vertex1] [vertex2]",
		["disconnect"] = "Disconnects two vertices, use 'disconnect [vertex1] [vertex2]",
		["vertexNumbering"] = "Toggles vertexNumbering, use 'vertexNumbering [true/false]'",
		["vertexCoords"] = "Toggles vertexCoords, use 'vertexNumbering [true/false]'",
		["spinXZ"] = "Sets XZ spinning speed, use 'spinXZ [speed]'",
		["spinYZ"] = "Sets YZ spinning speed, use 'spinYZ [speed]'",
		["setDistance"] = "Sets view distance to model, use 'scale [scale]'",
		["clear"] = "Clears the model, use 'clear'"
	}
	local fromDict = helpDictionary[self.args[1]]
	if fromDict ~= nil then
		self.response = fromDict
	end
end

function Console:comLoadModel()
	self.response = self.host.modeler:readFile(self.args[1])
end

function Console:comSaveModel()
	self.response = self.host.modeler:saveFile(self.args[1])
end

function Console:comAddVertex()
	local x, y, z = tonumber(self.args[1]), tonumber(self.args[2]), tonumber(self.args[3])

	if type(x) ~= "number" or (type(y) ~= "number") or (type(z) ~= "number") then
		self.response = "Arguments must be numbers"
	else
		self.host.modeler.currentModel:addVertex(x,y,z)
		self.response = "Added vertex to " .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z)
	end
end

function Console:comRemoveVertex()
	local number = tonumber(self.args[1])

	if type(number) ~= "number" then
		self.response = "Argument must be a number"
	else
		self.host.modeler.currentModel:removeVertex(number)
		self.response = "Removed vertex at "
	end
end

function Console:comConnect()
	local v1, v2 = tonumber(self.args[1]), tonumber(self.args[2])
	if type(v1) ~= "number" or (type(v2) ~= "number") then
		self.response = "Arguments must be numbers"
	else
		self.host.modeler.currentModel:connect(v1, v2)
		self.response = "Connected " .. tostring(v1) .. " to " .. tostring(v2)
	end
end

function Console:comDisconnect()
	local v1, v2 = tonumber(self.args[1]), tonumber(self.args[2])
	if type(v1) ~= "number" or (type(v2) ~= "number") then
		self.response = "Arguments must be numbers"
	else
		self.host.modeler.currentModel:disconnect(v1, v2)
		self.response = "Disconnected " .. tostring(v1) .. " from " .. tostring(v2)
	end
end

function Console:comVertexNumbering()
	local arg = self:toBoolean(self.args[1])
	if not (arg==nil) then
		self.host.modeler.vertexNumbering = arg
		self.response = "Set vertex numbering to " .. tostring(arg)
	else 
		self.response = "Argument must be 'false' or 'true'"
	end
end

function Console:comVertexCoords()
	local arg = self:toBoolean(self.args[1])
	if not (arg==nil) then
		self.host.modeler.vertexCoords = arg
		self.response = "Set vertex coordinates to " .. tostring(arg)
	else 
		self.response = "Argument must be 'false' or 'true'"
	end
end

function Console:comSpinXZ()
	local arg = tonumber(self.args[1])
	if type(arg) ~= "number" then 
		self.response = "Argument must be a number"
	else
		self.host.modeler.currentModel.rotSpeedXZ = arg
		self.response = "Set XZ spinning speed to " .. tostring(arg)
	end
end

function Console:comSpinYZ()
	local arg = tonumber(self.args[1])
	if type(arg) ~= "number" then 
		self.response = "Argument must be a number"
	else
		self.host.modeler.currentModel.rotSpeedYZ = arg
		self.response = "Set YZ spinning speed to " .. tostring(arg)
	end
end

function Console:comSetDistance()
	local arg = tonumber(self.args[1])
	if type(arg) ~= "number" then 
		self.response = "Argument must be a number"
	else
		self.host.modeler.currentModel.dz = arg
		self.response = "Set viewing distance to " .. tostring(arg)
	end
end

function Console:comClear()
	self.host.modeler.currentModel:clear()
	self.response = "Cleared the model"
end

function Console:update(dt)
	self.timer = math.max(self.timer + dt, 0)

	if love.keyboard.isDown("backspace") then
		self.backSpaceHoldTimer = self.backSpaceHoldTimer - dt
		if self.backSpaceHoldTimer <= 0 then
			self:textBackspace()
		end
	else self.backSpaceHoldTimer = 0.5 end
end

function Console:draw()
	love.graphics.setColor(0,0,0,1) -- Opaque black
	love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
	love.graphics.setColor(1,1,1,1) -- Opaque white

	local originalLW = love.graphics.getLineWidth()
	love.graphics.setLineWidth(self.lineWidth)
	love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
	love.graphics.setLineWidth(originalLW)

	self:printCommandLine()
	self:printTempLog()
end

function Console:printTempLog()
	love.graphics.setColor(1,1,1,0.5) -- Gray

	local logX = self.x + self.lineWidth
	local limit = self.w / self.textScale - self.lineWidth
	local align = "left"
	local orientation = 0

	local i, maxTempLogRows = 1, self:maxTempLogRows()
	while i < math.min(#self.tempLog+1, maxTempLogRows+1) do
		local line = self.tempLog[i]
		local logY = self.y + (i+1)*self:textYSize()
		love.graphics.print(line, logX, logY,
			orientation, self.textScale, self.textScale)
		i = i + 1
	end
	love.graphics.setColor(1,1,1,1) -- Back to white
end

function Console:textBackspace()
	local byteoffset = utf8.offset(self.text, -1)
	if byteoffset then
		self.text = string.sub(self.text, 1, byteoffset - 1)
	end
end

function Console:printCommandLine()
	local textFieldX = self.x+self.lineWidth
	local textFieldY = self.y+self.lineWidth
	local limit = self.w / self.textScale - self.lineWidth
	local align = "left"
	local orientation = 0
	if math.mod(math.floor(self.timer*2), 2) == 0 then
		love.graphics.printf(self.text .. "_", textFieldX, textFieldY, limit, align,
			orientation, self.textScale, self.textScale)
	else
		love.graphics.printf(self.text .. "", textFieldX, textFieldY, limit, align,
			orientation, self.textScale, self.textScale)	
	end
end

function Console:textInput(t)
	self.text = self.text .. t
end

function Console:keyPressed(key)
	if key == "return" then
		self:runLine(self.text)
		self.text = ""
	elseif key == "backspace" then
		self:textBackspace()
	end
end

function Console:textXSize(text)
	return love.graphics.getFont():getWidth() * self.textScale
end

function Console:textYSize()
	return love.graphics.getFont():getHeight() * self.textScale
end

function Console:runLine(line)
	local inputPrefix = tostring(self.logIndex) .. ": " 
	local responsePrefix = " (" .. tostring(self.logIndex) .. ") "
	self.args = {}
	self.response = ""
	for arg in line:gmatch("%S+") do
		table.insert(self.args, arg)
	end
	local command = self.commands[table.remove(self.args, 1)]
	if command then
		command()
	else
		self.response = "Unknown command" 
	end
	self.permLog = inputPrefix .. line .. "\n" .. responsePrefix .. self.response .. "\n" .. self.permLog

	local font = love.graphics.getFont()
	local _, wrapped = font:getWrap(self.permLog, self.w/self.textScale)
	self.tempLog = wrapped

	self.logIndex = self.logIndex + 1
end

function Console:maxTempLogRows()
	return self.h/(self:textYSize()) - 3
end

function Console:toBoolean(input)
	if input == "false" then
  		return false
	elseif input == "true" then
  		return true
  	end
  	return nil
end

return {Console = Console}