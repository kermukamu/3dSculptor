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
	local dz = self.currentModel:getDZ()
	if y > 0 then -- Wheel moved up
		self.currentModel:setDZ((dz - dz/10))
	elseif y < 0 then -- Wheel moved down
		self.currentModel:setDZ((dz + dz/10))
	end
end

function Modeler:textInput(t)
end

function Modeler:mousePressed(mx, my, button)
	local toolMode = self.host:getToolMode()
	if not ((love.keyboard.isDown("lshift") and toolMode == "selection") or toolMode == "move")
		then self.currentModel:deSelect() end
	if toolMode == "selection" then
		if button == 1 then -- left click
        	self.currentModel:selectVertexWithin(mx, my)
    	end
	end
end

function Modeler:mouseMoved(x, y, dx, dy)
	if love.keyboard.isDown("space") and love.mouse.isDown(1) then
		love.mouse.setRelativeMode(true)
		self.currentModel:pan(dy, dx)
		love.mouse.setRelativeMode(false)
	end
end

-- Getters and setters
function Modeler:getX() return self.x end
function Modeler:getY() return self.y end
function Modeler:getW() return self.w end
function Modeler:getH() return self.h end
function Modeler:getCurrentModel() return self.currentModel end
function Modeler:drawAxisMarkerIsOn() return self.host:drawAxisMarkerIsOn() end
function Modeler:vertexNumberingIsOn() return self.host:vertexNumberingIsOn() end
function Modeler:vertexCoordsIsOn() return self.host:vertexCoordsIsOn() end
function Modeler:drawVerticesIsOn() return self.host:drawVerticesIsOn() end

return {Modeler = Modeler}