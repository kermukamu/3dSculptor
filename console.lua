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
		"Run 'listKeys' to see all keys\n" ..
		"Run 'listCombos' to see all combination actions\n" ..
		"Run 'help [command/key]' to get help with a command or key action"}
	self.logIndex = 1
	self.text = ""
	self.textScale = 2

	self.timer = 0
	self.backSpaceHoldTimer = 0

	self.args = {}
	self.commands = {
		["listCommands"] = {function() self:comListCommands() end, "Lists all commands, use 'listCommands'"},
		["listKeys"] = {function() self:comListModelerControls() end, "Lists all keys, use 'listKeys'"},
		["listCombos"] = {function() self:comListCombos() end, "Lists mouse and key combos, use 'listMouse'"},
		["help"] = {function() self:comHelp() end, "Gets information about a command, use 'help [command/control]'"},
		["load"] = {function() self:comLoadModel() end, "Loads a model, use 'load [filename]'"},
		["save"] = {function() self:comSaveModel() end, "Saves a model, use 'save [filename]'"},
		["addVertex"] = {function() self:comAddVertex() end, "Adds a vertex, use 'addVertex [x] [y] [z]'"},
		["removeVertex"] = {function() self:comRemoveVertex() end, "Removes a vertex, use 'removeVertex [vertex]'"},
		["connect"] = {function() self:comConnect() end, "Connects two vertices, use 'connect [vertex1] [vertex2]"},
		["disconnect"] = {function() self:comDisconnect() end, "Disconnects two vertices, use 'disconnect [vertex1] [vertex2]"},
		["vertexNumbering"] = {function() self:comVertexNumbering() end, "Toggles vertexNumbering, use 'vertexNumbering [true/false]'"},
		["vertexCoords"] = {function() self:comVertexCoords() end, "Toggles vertexCoords, use 'vertexNumbering [true/false]'"},
		["drawVertices"] = {function() self:comDrawVertices() end, "Toggles vertex drawing, use 'drawVertices [true/false]'"},
		["spin"] = {function() self:comSpin() end, "Sets spinning speed, use 'spin [phi(deg/s)] [theta (deg/s)]'"},
		["orientation"] = {function() self:comOrientation() end, "Sets orientation, use 'orientation [phi(deg)] [theta (deg)]'"},
		["setDistance"] = {function() self:comSetDistance() end, "Sets view distance to model, use 'scale [scale]'"},
		["clear"] = {function() self:comClear() end, "Clears the model, use 'clear'"},
		["multiplyModel"] = {function() self:comMultiplyModel() end, "Multiplies actual model size, use 'multiplyModel [multiplier]'"},
		["drawCircle"] = {function() self:comDrawCircle() end, "Draws a circle, use 'drawCircle [centerX] [centerY] [centerZ] [radius] [plane] [segments] [connectLines (true/false)]'"}
	}

	self.comboList = {
		["Space+LeftMouse"] = "Rotates 3D view",
		["Shift+LeftMouse"] = "Holds selection if in selection mode"
	}
	self.response = ""
	return self
end

function Console:comListCommands()
	self.response = ""
	for k, _ in pairs(self.commands) do
		self.response = self.response .. k .. ", "
	end
end

function Console:comListModelerControls()
	self.response = ""
	local keyActions = self.host:getModelerKeyActions()
	if keyActions ~= nil then
		for k, _ in pairs(self.host:getModelerKeyActions()) do
			self.response = self.response .. k .. ", "
		end
	end
end

function Console:comListCombos()
	self.response = ""
	for k, _ in pairs(self.comboList) do
		self.response = self.response .. k .. ", "
	end
end

function Console:comHelp()
	local arg = self.args[1]

	-- It is assumed both dictionaries do not share same keys
	if self.commands[arg] ~= nil then
		self.response = "Is a command. " .. self.commands[arg][2]
	elseif self.host:getModelerKeyActions()[arg] ~= nil then
		self.response = "Is a keyboard action. " .. self.host:getModelerKeyActions()[arg][2]
	elseif self.comboList[arg] ~= nil then
		self.response = "Is a combo action. " .. self.comboList[arg]
	else
		self.response = "No command given, use 'help [command]'"
	end
end

function Console:comLoadModel()
	local currentModel = self.host:getCurrentModel()
	if currentModel ~= nil then
		self.response = currentModel:readFile(self.args[1])
	end
end

function Console:comSaveModel()
	local currentModel = self.host:getCurrentModel()
	if currentModel ~= nil then
		self.response = currentModel:saveFile(self.args[1])
	end
end

function Console:comAddVertex()
	local x, y, z = tonumber(self.args[1]), tonumber(self.args[2]), tonumber(self.args[3])

	if type(x) ~= "number" or (type(y) ~= "number") or (type(z) ~= "number") then
		self.response = "Arguments must be numbers"
	else
		local currentModel = self.host:getCurrentModel()
		if currentModel ~= nil then
			currentModel:addVertex(x,y,z)
			self.response = "Added vertex to " .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z)
		end
	end
end

function Console:comRemoveVertex()
	local number = tonumber(self.args[1])

	if type(number) ~= "number" then
		self.response = "Argument must be a number"
	else
		local currentModel = self.host:getCurrentModel()
		if currentModel ~= nil then
			currentModel:removeVertex(number)
			self.response = "Removed vertex at "
		end
	end
end

function Console:comConnect()
	local v1, v2 = tonumber(self.args[1]), tonumber(self.args[2])
	if type(v1) ~= "number" or (type(v2) ~= "number") then
		self.response = "Arguments must be numbers"
	else
		local currentModel = self.host:getCurrentModel()
		if currentModel ~= nil then
			currentModel:connect(v1, v2)
			self.response = "Connected " .. tostring(v1) .. " to " .. tostring(v2)
		end
	end
end

function Console:comDisconnect()
	local v1, v2 = tonumber(self.args[1]), tonumber(self.args[2])
	if type(v1) ~= "number" or (type(v2) ~= "number") then
		self.response = "Arguments must be numbers"
	else
		local currentModel = self.host:getCurrentModel()
		if currentModel ~= nil then
			currentModel:disconnect(v1, v2)
			self.response = "Disconnected " .. tostring(v1) .. " from " .. tostring(v2)
		end
	end
end

function Console:comVertexNumbering()
	local arg = self:toBoolean(self.args[1])
	if not (arg==nil) then
		self.host:setVertexNumbering(arg)
		self.response = "Set vertex numbering to " .. tostring(arg)
	else 
		self.response = "Argument must be 'false' or 'true'"
	end
end

function Console:comVertexCoords()
	local arg = self:toBoolean(self.args[1])
	if not (arg==nil) then
		self.host:setVertexCoords(arg)
		self.response = "Set vertex coordinate visibility to " .. tostring(arg)
	else 
		self.response = "Argument must be 'false' or 'true'"
	end
end

function Console:comDrawVertices() 
	local arg = self:toBoolean(self.args[1])
	if not (arg==nil) then
		self.host:setDrawVertices(arg)
		self.response = "Set vertice drawing to " .. tostring(arg)
	else 
		self.response = "Argument must be 'false' or 'true'"
	end
end

function Console:comSpin()
	local argPhi = tonumber(self.args[1])
	local argTheta = tonumber(self.args[2])
	if type(argPhi) ~= "number" or type(argTheta) ~= "number" then
		self.response = "Arguments must be numbers"
	else
		local currentModel = self.host:getCurrentModel()
		if currentModel ~= nil then
			currentModel:setRotation(argPhi, argTheta)
			self.response = "Set spinning speed at phi to " .. tostring(argPhi) .. 
			" and at theta to " .. tostring(argTheta)
		end
	end
end

function Console:comOrientation()
	local argPhi = tonumber(self.args[1])
	local argTheta = tonumber(self.args[2])
	if type(argPhi) ~= "number" or type(argTheta) ~= "number" then
		self.response = "Arguments must be numbers"
	else
		local currentModel = self.host:getCurrentModel()
		if currentModel ~= nil then
			currentModel:setOrientation(argPhi, argTheta)
			self.response = "Setting orientation at phi to " .. tostring(argPhi) .. 
			" and at theta to " .. tostring(argTheta)
		end
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

function Console:comDrawCircle()
	local centerX, centerY, centerZ, radius, plane, segments, con = 
		tonumber(self.args[1]), tonumber(self.args[2]), tonumber(self.args[3]),
		tonumber(self.args[4]), self.args[5], tonumber(self.args[6]), self:toBoolean(self.args[7])
	if not (con == nil) then
		self.response = self.host.modeler.currentModel:drawCircle(centerX, centerY, centerZ,
			radius, plane, segments, con)
	else self.response = "connectLines must be a boolean value" end
end

function Console:comMultiplyModel()
	local arg = tonumber(self.args[1])
	if type(arg) ~= "number" then
		self.response = "Argument must be a number"
	else
		local currentModel = self.host:getCurrentModel()
		if currentModel ~= nil then
			currentModel:multiplyModelSize(arg)
			self.response = "Multiplied actual model by " .. tostring(arg)
		end
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
	if self.host.activeSection == self and math.mod(math.floor(self.timer*2), 2) == 0 then
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

function Console:mousePressed(mx, my, button)
end

function Console:wheelMoved(x, y)
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
		command[1]()
	else
		self.response = "Unknown command. Use 'listCommands' to see all commands." 
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