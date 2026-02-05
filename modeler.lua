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

	self.toolMode = self.host:getToolMode()
	self.subMode = self.host:getSubToolMode()
	self.panSpeed = 100

	-- Setup 3D model
	local modelX2D = (self.x + self.w) / 2 -- X of projection, in other words, x if z = 0 
	local modelY2D = (self.y + self.h) / 2 -- Same for Y
	local distance = 1200
	self.currentModel = Cool3d.new(modelX2D, modelY2D, distance, self)

	-- Other
	self.prevClickX = 0
	self.prevClickY = 0
	self.timer = 0
	return self
end

function Modeler:update(dt)
	self.timer = math.max(self.timer + dt, 0)
	self.currentModel:update(dt)
	self.toolMode = self.host:getToolMode()
	self.subMode = self.host:getSubToolMode()

	if self.host:getActiveSection() == self then self:handleArrowInput(dt) end
end

function Modeler:draw()
    --Black background
    love.graphics.setColor(0,0,0,1) -- Black
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)

    love.graphics.setScissor(self.x, self.y, self.w, self.h) -- Limit drawing area

	self.currentModel:draw()

	-- Selection rectangle
	if self.host:getActiveSection() == self and self.toolMode == "selection"
		and love.mouse.isDown(1) and not love.keyboard.isDown("space") then
		local mx, my = love.mouse.getPosition()
		local w, h = mx-self.prevClickX, my-self.prevClickY
		love.graphics.setColor(1,1,1,0.5) -- Translucent white
		if love.keyboard.isDown("lalt") then love.graphics.setColor(1,0.5,0,0.5) end -- Translucent orange
		love.graphics.rectangle("fill", self.prevClickX, self.prevClickY, w, h)
	end

	if not self.currentModel:getAllModelWithinView() then self:drawHiddenVerticesComplaint() end

	self:drawCurrentToolNotice()

	love.graphics.setScissor() -- Remove drawing area limit

	-- Frame
	local originalLW = love.graphics.getLineWidth()
	love.graphics.setColor(1,1,1,1) -- White
	love.graphics.setLineWidth(self.lineWidth)
	love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
	love.graphics.setLineWidth(originalLW)
end

function Modeler:selectAll()
	self:getCurrentModel():selectAll()
end

function Modeler:deSelectAll()
	self:getCurrentModel():deSelect()
end

function Modeler:copy()
	self:getCurrentModel():copySelected()
end

function Modeler:drawHiddenVerticesComplaint()
    love.graphics.setColor(1,0.2,0,1) -- opaque brown
    local complaint = "The complete model is not visible, try increasing view distance"
    love.graphics.print(complaint, self:getX() + self:getW()/32, self:getY() + self:getH()/32, 0)
end

function Modeler:drawCurrentToolNotice()
	love.graphics.setColor(0.8,0.8,0.8,1) -- opaque gray
    local notice = "Tool: " .. self.toolMode .. " – " .. self.subMode
    local fontH = love.graphics.getFont():getHeight()
    local tx = self:getX() + self:getW()/32
    local ty = self:getY() + self:getH() - self:getH()/32 - fontH
    love.graphics.print(notice, tx, ty, 0)
end

function Modeler:handleArrowInput(dt)
	local cm = self.currentModel
	if love.keyboard.isDown("left") then cm:panCamera(self.panSpeed * dt, 0) end
	if love.keyboard.isDown("right") then cm:panCamera(-self.panSpeed * dt, 0) end
	if love.keyboard.isDown("up") then cm:panCamera(0, -self.panSpeed * dt) end
	if love.keyboard.isDown("down") then cm:panCamera(0, self.panSpeed * dt) end
end

function Modeler:wheelMoved(x, y)
	local dz = self.currentModel:getDZ()
	if y > 0 then -- Wheel moved up
		self.currentModel:setDZ(dz - math.max(dz/10, 1))
	elseif y < 0 then -- Wheel moved down
		self.currentModel:setDZ(dz + math.max(dz/10, 1))
	end
end

function Modeler:textInput(t)
end

function Modeler:mousePressed(mx, my, button)
	local toolMode = self.toolMode
	if not (((love.keyboard.isDown("lshift") or love.keyboard.isDown("lalt") 
		or love.keyboard.isDown("space")) and toolMode == "selection") 
		or toolMode == "move selected" or toolMode == "move camera") then
		self:deSelectAll()
	end
	self.prevClickX = mx
	self.prevClickY = my
end 

function Modeler:mouseReleased(mx, my, button)
    local lAltDown = love.keyboard.isDown("lalt")
    local lShiftDown = love.keyboard.isDown("lshift")
    local lCtrlDown = love.keyboard.isDown("lctrl")
    local spaceDown = love.keyboard.isDown("space")

	if self.toolMode == "selection" then
    	if button == 1 and not spaceDown then -- left click
    		if (math.abs(mx - self.prevClickX) < 5) 
    			and (math.abs(my - self.prevClickY) < 5) then -- Very small area between press and release
                if lAltDown then 
                	self.currentModel:toggleVertexSelectionWithinClick(mx, my, false)
                else 
                	self.currentModel:toggleVertexSelectionWithinClick(mx, my, true) 
                end
            else
                if lAltDown then 
                	self.currentModel:toggleVertexSelectionWithinRectangle(
                		self.prevClickX, self.prevClickY, mx, my, false)
                else
                	self.currentModel:toggleVertexSelectionWithinRectangle(
                		self.prevClickX, self.prevClickY, mx, my, true) 
               	end
            end
    	end
	end
end

function Modeler:mouseMoved(x, y, dx, dy)
	local toolMode = self.host:getToolMode()
	local subMode = self.host:getSubToolMode()
	if (love.keyboard.isDown("space") or (toolMode == "move camera" and subMode == "rotate"))
		and love.mouse.isDown(1) then -- Rotate 
		
		love.mouse.setRelativeMode(true)
		self.currentModel:incrementOrientation(-dy, -dx)
		love.mouse.setRelativeMode(false)
	end
	if toolMode == "move camera" and subMode == "translate" and love.mouse.isDown(1) then
		self.currentModel:panCamera(dx, -dy)
	end
end

-- Getters and setters
function Modeler:getFrameLineWidth() return self.lineWidth end
function Modeler:getX() return self.x end
function Modeler:getY() return self.y end
function Modeler:getW() return self.w end
function Modeler:getH() return self.h end
function Modeler:getCurrentModel() return self.currentModel end
function Modeler:getActiveColor() return self.host:getActiveColor() end
function Modeler:drawAxisMarkerIsOn() return self.host:drawAxisMarkerIsOn() end
function Modeler:vertexNumberingIsOn() return self.host:vertexNumberingIsOn() end
function Modeler:vertexCoordsIsOn() return self.host:vertexCoordsIsOn() end
function Modeler:drawVerticesIsOn() return self.host:drawVerticesIsOn() end
function Modeler:drawLinesIsOn() return self.host:drawLinesIsOn() end
function Modeler:drawFacesIsOn() return self.host:drawFacesIsOn() end

return {Modeler = Modeler}