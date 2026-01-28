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

	-- Setup 3D model
	local modelX2D = (self.x + self.w) / 2 -- X of projection, in other words, x if z = 0 
	local modelY2D = (self.y + self.h) / 2 -- Same for Y
	local distance = 1200
	self.currentModel = Cool3d.new(modelX2D, modelY2D, distance, self)

	-- Other
	self.timer = 0
	return self
end

function Modeler:update(dt)
	self.timer = math.max(self.timer + dt, 0)

	self.currentModel:update(dt)
end

function Modeler:draw()
    --Black background
    love.graphics.setColor(0,0,0,1) -- Black
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)

	self.currentModel:draw()

	-- Frame
	local originalLW = love.graphics.getLineWidth()
	love.graphics.setColor(1,1,1,1) -- White
	love.graphics.setLineWidth(self.lineWidth)
	love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
	love.graphics.setLineWidth(originalLW)
end

function Modeler:keyPressed(key)
	local action = self.host:getModelerKeyActions()[key]
	if action then action[1]() end
end

function Modeler:wheelMoved(x, y)
	if y > 0 then -- Wheel moved up
		self.currentModel:setDZ((self.currentModel:getDZ() - 50))
	elseif y < 0 then -- Wheel moved down
		self.currentModel:setDZ((self.currentModel:getDZ() + 50))
	end
end

function Modeler:textInput(t)
end

function Modeler:mousePressed(mx, my, button)
	if not love.keyboard.isDown("lshift") then self.currentModel:deSelect() end
    if button == 1 then -- left click
        self.currentModel:selectVertexWithin(mx, my)
    end
end

-- Getters and setters

function Modeler:getCurrentModel()
	return self.currentModel
end

function Modeler:drawAxisMarkerIsOn()
	return self.host:drawAxisMarkerIsOn()
end

function Modeler:vertexNumberingIsOn()
	return self.host:vertexNumberingIsOn()
end

function Modeler:vertexCoordsIsOn()
	return self.host:vertexCoordsIsOn()
end

return {Modeler = Modeler}