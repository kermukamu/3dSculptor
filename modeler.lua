local ccool3d = require("cool3d")
Cool3d = ccool3d.Cool3d

-- Modeler "class"
local Modeler = {}
Modeler.__index = Modeler

function Modeler.new(x, y, w, h, host)
	local self = setmetatable({}, Modeler)
	self.host = host

	self.lineWidth = 5
	self.x = x + self.lineWidth
	self.y = y - self.lineWidth
	self.w = w - 2 * self.lineWidth
	self.h = h - 2 * self.lineWidth

	-- Flags
	self.vertexNumbering = true
	self.vertexCoords = true
	self.drawAxis = true

	-- Setup 3D model
	local modelX2D = (self.x + self.w) / 2 -- X of projection, in other words, x if z = 0 
	local modelY2D = (self.y + self.h) / 2 -- Same for Y
	local distance = 1
	self.currentModel = Cool3d.new(modelX2D, modelY2D, distance, self)
	self.currentModel.axisX = 100
	self.currentModel.axisY = self.h - 100

	-- Other
	self.timer = 0
	self.keyActions = {
		["delete"] = function() self.currentModel:deleteSelected() end,
		["e"] = function() self.currentModel:joinToFirstSelected() end
	}
	return self
end

function Modeler:update(dt)
	self.timer = math.max(self.timer + dt, 0)

	self.currentModel:update(dt)
end

function Modeler:draw()
	local originalLW = love.graphics.getLineWidth()
	love.graphics.setLineWidth(self.lineWidth)
	love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
	love.graphics.setLineWidth(originalLW)

	self.currentModel:draw()
end

function Modeler:readFile(filename)
	return self.currentModel:readFile(filename)
end

function Modeler:saveFile(filename)
	return self.currentModel:saveFile(filename)
end

function Modeler:keyPressed(key)
	if key == "delete" then self.currentModel:deleteSelected() end
end

function Modeler:textInput(t)
end

function Modeler:mousePressed(mx, my, button)
	self.currentModel:mousePressed(mx, my, button)
end

return {Modeler = Modeler}