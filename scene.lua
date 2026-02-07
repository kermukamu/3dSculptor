local cconsole = require("console")
local Console = cconsole.Console
local cmodeler = require("modeler")
local Modeler = cmodeler.Modeler
local cpanel2d = require("panel2d")
local Panel2d = cpanel2d.Panel2d
local cswitchbar = require("switchbar")
local Switchbar = cswitchbar.Switchbar
local ctoolbar = require("toolbar")
local Toolbar = ctoolbar.Toolbar
local ccolortool = require("colortool")
local ColorTool = ccolortool.ColorTool
local coptool = require("optool")
local OpTool = coptool.OpTool

-- Scene "class"
local Scene = {}
Scene.__index = Scene

function Scene.new(title, screenWidth, screenHeight)
	local self = setmetatable({}, Scene)

	-- Setup window
	love.window.setTitle(title)
    love.window.setMode(screenWidth, screenHeight)
    love.graphics.setBackgroundColor(0, 0, 0, 0) -- Black
    love.graphics.setDefaultFilter("nearest", "nearest")

    local yOffset = 10

    -- Flags
	self.vertexNumbering = true
	self.vertexCoords = true
	self.drawAxisMarker = true
	self.drawVertices = true
	self.drawLines = true
	self.drawFaces = true
	self.addLines = true
	self.addFaces = true
	self.toolMode = "selection"
	self.subMode = "rectangle"
	self.circleSegments = 64
	self.sphereSegments = 12
	self.activeColor = {0.4, 0.4, 0.8, 0.6} -- Default

	-- Position console to bottom left third
	local consoleW = screenWidth * (1 / 2)
	local consoleH = screenHeight * (1 / 3)
	local consoleX = 0
	local consoleY = love.graphics.getHeight() - consoleH + yOffset
	self.console = Console.new(consoleX, consoleY, consoleW, consoleH, self)

	-- Position 3d modeler to top and middle left thirds
	local modelerW = screenWidth * (1 / 2)
	local modelerH = screenHeight * (2 / 3)
	local modelerX = 0
	local modelerY = yOffset
	self.modeler = Modeler.new(modelerX, modelerY, modelerW, modelerH, self)

	-- Position XZ 2D panel to top right third
	local xzPanelW = screenWidth * (1 / 2)
	local xzPanelH = screenHeight * (1 / 3)
	local xzPanelX = love.graphics.getWidth() - xzPanelW
	local xzPanelY = yOffset
	self.xzPanel = Panel2d.new(xzPanelX, xzPanelY, xzPanelW, xzPanelH, "xz", self)

	-- Position XY 2D panel to middle right third
	local xyPanelW = screenWidth * (1 / 2)
	local xyPanelH = screenHeight * (1 / 3)
	local xyPanelX = love.graphics.getWidth() - xyPanelW
	local xyPanelY = love.graphics.getHeight()/2 - xyPanelH/2 + yOffset
	self.xyPanel = Panel2d.new(xyPanelX, xyPanelY, xyPanelW, xyPanelH, "xy", self)

	-- Position YZ 2D panel to bottom right third
	local yzPanelW = screenWidth * (1 / 2)
	local yzPanelH = screenHeight * (1 / 3)
	local yzPanelX = love.graphics.getWidth() - yzPanelW
	local yzPanelY = love.graphics.getHeight() - yzPanelH + yOffset
	self.yzPanel = Panel2d.new(yzPanelX, yzPanelY, yzPanelW, yzPanelH, "yz", self)

	-- Position flag switch bar on top of modeler
	local switchbarIconSize = screenHeight * (1 / 32)
	local switchbarX = modelerX + modelerW/8
	local switchbarY = modelerY
	self.switchbar = Switchbar.new(switchbarX, switchbarY, switchbarIconSize, self)

	-- Position Toolbar on top right section of modeler
	local toolbarIconSize = screenWidth * (1 / 32)
	local toolbarX = modelerX + modelerW - toolbarIconSize - self.modeler:getFrameLineWidth()*2
	local toolbarY = modelerY
	self.toolbar = Toolbar.new(toolbarX, toolbarY, toolbarIconSize, self)

	-- Position color tool on bottom right corner of modeler
	local colorToolIconSize = screenWidth * (1 / 32)
	local colorToolX = modelerX + modelerW - colorToolIconSize - self.modeler:getFrameLineWidth()*2
	local colorToolY = modelerY + modelerH - colorToolIconSize - self.modeler:getFrameLineWidth()*2 - yOffset
	self.colorTool = ColorTool.new(colorToolX, colorToolY, colorToolIconSize, self)

	-- Position opacity tool on the left side of color tool
	local opToolIconSize = screenWidth * (1 / 32)
	local opToolX = colorToolX - opToolIconSize
	local opToolY = colorToolY
	self.opTool = OpTool.new(opToolX, opToolY, opToolIconSize, self)

	self.keyActions = {
		["delete"] = {function() self:byActionDelete() end, "Deletes current selection"},
		["a"] = {function() self:byActionA() end, "Selects all"},
		["c"] = {function() self:byActionC() end, "Use while holding left ctrl to copy selected"},
		["f"] = {function() self:byActionF() end, "Creates a face between selected vertices"},
		["j"] = {function() self:byActionJ() end, "Joins selected vertices or disconnects them if left alt is held down"},
		["v"] = {function() self:byActionV() end, "Turns vertex mode on"},
		["z"] = {function() self:byActionZ() end, "Reverts action if left ctrl is held down"},
		["s"] = {function() self:byActionTurnSelectionModeOn() end, "Turns selection mode on"},
		["e"] = {function() self:byActionTurnMoveModeOn() end, "Turns move selected mode on"},
		["escape"] = {function() self:deSelectAll() end, "Deselects all"}
    }

	self.activeSection = self.modeler

	-- Load example model
	self:getCurrentModel():readFile("3d/gem.txt")
	return self
end

function Scene:update(dt)
	self.console:update(dt)
	self.modeler:update(dt)
	self.xzPanel:update(dt)
	self.xyPanel:update(dt)
	self.yzPanel:update(dt)
	self.switchbar:update(dt)
	self.toolbar:update(dt)
	self.colorTool:update(dt)
	if self.colorTool:isSetOpen() then
		self.opTool:setX(self.colorTool:getOpenX()-self.opTool:getSize())
	else
		self.opTool:setX(self.colorTool:getX()-self.opTool:getSize())
	end
	self.opTool:update(dt)
	local color = self.colorTool:getSelectedColor()
	local opacity = self.opTool:getSelectedOpacity()
	self.activeColor = {color[1], color[2], color[3], opacity}
end

function Scene:draw()
	self.modeler:draw()
	self.xzPanel:draw()
	self.xyPanel:draw()
	self.yzPanel:draw()
	self.console:draw()
	self.switchbar:draw()
	self.toolbar:draw()
	self.opTool:draw()
	self.colorTool:draw()
end

function Scene:keyPressed(key)
	if key == nil or self.activeSection == nil then return end
	if getmetatable(self.activeSection).__index == Console then
		self.activeSection:keyPressed(key)
	else
		local action = self:getModelerKeyActions()[key]
		if action then action[1]() end 
	end
end

function Scene:textInput(t)
	if self.activeSection and self.activeSection.textInput then
		self.activeSection:textInput(t)
	end
end

function Scene:mousePressed(mx, my, button)
	if self.switchbar:isWithinSection(mx, my) then
		self.activeSection = self.switchbar
	elseif self.colorTool:isWithinSection(mx, my) then
		self.activeSection = self.colorTool
	elseif self.opTool:isWithinSection(mx, my) then
		self.activeSection = self.opTool
	elseif self.toolbar:isWithinSection(mx, my) then
		self.activeSection = self.toolbar
	elseif self:isWithinSection(mx, my, self.modeler.x, self.modeler.y,
		self.modeler.w, self.modeler.h) then
		self.activeSection = self.modeler
	elseif self:isWithinSection(mx, my, self.xzPanel.x, self.xzPanel.y,
		self.xzPanel.w, self.xzPanel.h) then
		self.activeSection = self.xzPanel
	elseif self:isWithinSection(mx, my, self.xyPanel.x, self.xyPanel.y,
		self.xyPanel.w, self.xyPanel.h) then
		self.activeSection = self.xyPanel
	elseif self:isWithinSection(mx, my, self.yzPanel.x, self.yzPanel.y,
		self.yzPanel.w, self.yzPanel.h) then
		self.activeSection = self.yzPanel
	elseif self:isWithinSection(mx, my, self.console.x, self.console.y,
		self.console.w, self.console.h) then
		self.activeSection = self.console
	else
		self.activeSection = nil
	end
	if self.activeSection and self.activeSection.mousePressed then
		self.activeSection:mousePressed(mx, my, button)
	end
end

function Scene:mouseReleased(mx, my, button)
	if self.activeSection and self.activeSection.mouseReleased then
		self.activeSection:mouseReleased(mx, my, button)
	end
end

function Scene:mouseMoved(x, y, dx, dy)
	if self.activeSection and self.activeSection.mouseMoved then
		self.activeSection:mouseMoved(x, y, dx, dy)
	end
end

function Scene:wheelMoved(x, y)
	if self.activeSection and self.activeSection.wheelMoved then
		self.activeSection:wheelMoved(x, y)
	end
end

function Scene:isWithinSection(x, y, secX, secY, secW, secH)
	return (secX < x and x < (secX + secW)) and
			(secY < y and y < (secY + secH))
end

function Scene:byActionA()
	if love.keyboard.isDown("lalt") then
		self.modeler:deSelectAll()
	else
		self.modeler:selectAll()
	end
end

function Scene:deSelectAll()
	return self.modeler:deSelectAll()
end

function Scene:byActionDelete()
	local currentModel = self:getCurrentModel()
	if currentModel ~= nil then
		currentModel:saveToBuffer()
		currentModel:deleteSelected()
	end
end

function Scene:byActionV()
	if love.keyboard.isDown("lctrl") then
		if self.activeSection and self.activeSection.paste then
			self:getCurrentModel():saveToBuffer()
			self.activeSection:paste()
		end
	else
		self.toolMode = "vertex"
	
		-- If already in any vertex submode, shift submode forward
		self.subMode = self.toolbar:next(self.toolMode, self.subMode)
	end
end

function Scene:byActionC()
	if love.keyboard.isDown("lctrl") then
		if self.activeSection and self.activeSection.copy then
			self.activeSection:copy()
		end
	else
		self.toolMode = "move camera"

		-- If already in any vertex submode, shift submode forward
		self.subMode = self.toolbar:next(self.toolMode, self.subMode)
	end
end

function Scene:byActionJ()
	local currentModel = self:getCurrentModel()
	if currentModel ~= nil then
		local count = currentModel:getSelectedCount()
		if count >= 2 then
			currentModel:saveToBuffer()
			if love.keyboard.isDown("lalt") then
				self:getCurrentModel():disconnectSelected()
			else
				self:getCurrentModel():joinSelected()
			end
		end
	end
end

function Scene:byActionF()
	local currentModel = self:getCurrentModel()
	if currentModel ~= nil then
		if currentModel:getSelectedCount() >= 3 then
			self:getCurrentModel():saveToBuffer()
			currentModel:addFaceForSelected(self.activeColor)
		end
	end
end

function Scene:byActionZ()
	if self.activeSection ~= self.console and love.keyboard.isDown("lctrl") then
		self:getCurrentModel():loadFromBuffer()
	end
end

function Scene:byActionTurnSelectionModeOn()
	self.toolMode = "selection"
	self.subMode = "rectangle"
end

function Scene:byActionTurnMoveModeOn()
	self.toolMode = "move selected"

	-- If already in any vertex submode, shift submode forward
	self.subMode = self.toolbar:next(self.toolMode, self.subMode)
end

-- Getters and setters

function Scene:vertexNumberingIsOn() return self.vertexNumbering end
function Scene:vertexCoordsIsOn() return self.vertexCoords end
function Scene:drawVerticesIsOn() return self.drawVertices end
function Scene:drawLinesIsOn() return self.drawLines end
function Scene:drawFacesIsOn() return self.drawFaces end
function Scene:drawAxisMarkerIsOn() return self.drawAxisMarker end
function Scene:addLinesIsOn() return self.addLines end
function Scene:addFacesIsOn() return self.addFaces end

function Scene:getToolMode() return self.toolMode end
function Scene:getSubToolMode() return self.subMode end
function Scene:getActiveSection() return self.activeSection end
function Scene:getCircleSegments() return self.circleSegments end
function Scene:getSphereSegments() return self.sphereSegments end
function Scene:getActiveColor() return self.activeColor end

function Scene:getCurrentModel()
	if self.modeler ~= nil then
		return self.modeler:getCurrentModel()
	else 
		return nil 
	end
end

function Scene:getModelerKeyActions()
	if self.modeler ~= nil then
		return self.keyActions
	else 
		return nil 
	end
end

function Scene:setVertexNumbering(value) self.vertexNumbering = value end
function Scene:setVertexCoords(value) self.vertexCoords = value end
function Scene:setDrawVertices(value) self.drawVertices = value end
function Scene:setDrawLines(value) self.drawLines = value end
function Scene:setDrawFaces(value) self.drawFaces = value end
function Scene:setAddLines(value) self.addLines = value end
function Scene:setAddFaces(value) self.addFaces = value end
function Scene:setDrawAxis(value) self.drawAxisMarker = value end
function Scene:setToolMode(mode) self.toolMode = mode end
function Scene:setSubToolMode(mode) self.subMode = mode end


return {Scene = Scene}