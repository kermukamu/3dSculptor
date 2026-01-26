local cconsole = require("console")
local Console = cconsole.Console
local cmodeler = require("modeler")
local Modeler = cmodeler.Modeler

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

	-- Position console to bottom third
	local consoleW = screenWidth
	local consoleH = screenHeight * (1 / 3)
	local consoleX = 0
	local consoleY = love.graphics.getHeight() - consoleH + yOffset

	self.console = Console.new(consoleX, consoleY, consoleW, consoleH, self)

	-- Position modeler to top two thirds minus y offset
	local modelerW = screenWidth
	local modelerH = screenHeight * (2 / 3)
	local modelerX = 0
	local modelerY = yOffset

	self.modeler = Modeler.new(modelerX, modelerY, modelerW, modelerH, self)

	self.activeSection = self.modeler
	return self
end

function Scene:update(dt)
	self.console:update(dt)
	self.modeler:update(dt)
end

function Scene:draw()
	self.modeler:draw()
	self.console:draw()
end

function Scene:keyPressed(key)
	self.activeSection:keyPressed(key)
end

function Scene:textInput(t)
	self.activeSection:textInput(t)
end

function Scene:mousePressed(mx, my, button)
	if self:isWithinSection(mx, my, self.modeler.x, self.modeler.y,
		self.modeler.w, self.modeler.h) then
		self.activeSection = self.modeler
	elseif 
		self:isWithinSection(mx, my, self.console.x, self.console.y,
		self.console.w, self.console.h) then
		self.activeSection = self.console
	end
	self.activeSection:mousePressed(mx, my, button)
end

function Scene:isWithinSection(x, y, secX, secY, secW, secH)
	return (secX < x and x < (secX + secW)) and
			(secY < y and y < (secY + secH))
end

return {Scene = Scene}