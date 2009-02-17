text = "No collision yet."

local newWorld = function()
	local self = love.physics.newWorld(2000, 2000)
	self:setGravity(0, 100)
	self:setCallback(collision)
	return self
end

local newGround = function()
	local self = {}
	function self:draw()
		love.graphics.setColor(0, 255, 0)
		love.graphics.polygon(love.draw_line, self.shape:getPoints())
	end
	self.body = love.physics.newBody(world, 0, 0, 0)
	self.shape = love.physics.newRectangleShape(self.body, 400, 500, 600, 10)
	self.shape:setData("Ground")
	return self
end

local newCircle = function()
	local self = {}
	function self:draw()
		love.graphics.setColor(0, 0, 255)
		love.graphics.circle(love.draw_line, self.body:getX(), self.body:getY(), 28, 20)
	end
	self.body = love.physics.newBody(world, 400, 200)
	self.shape = love.physics.newCircleShape(self.body, 28)
	self.shape:setRestitution(0.5) -- More bounce
	self.shape:setData("Ball")
	self.body:setMassFromShapes()
	return self
end

local newHook = function()
	local self = {}
	self.body = love.physics.newBody(world, 400, 200)
	return self
end

local newGrapple = function()
	local self = {}
	function self:draw()
		love.graphics.setColor(255, 0, 255)
		love.graphics.polygon(love.draw_line, self.shaft:getPoints())
		love.graphics.polygon(love.draw_line, self.cross:getPoints())
	end
	--self.hook = newHook()
	self.body = love.physics.newBody(world, 400, 200)
	self.body:setAngularDamping(0.1)
	local shaft_v = {
		-50,   -5,  -- top left
		-50,   5, -- bottom left
		 35.5, 5,  -- bototm right
		 51,   0,  -- tip (far right)
		 35.5, -5,  -- top right
	}
	self.shaft = love.physics.newPolygonShape(self.body, unpack(shaft_v))
	self.shaft:setData("Grapple Shaft")
	self.shaft:setRestitution(0.5)
	local cross_v = {
		24.5, -24,
		35,   -24,
		35,   24,
		24.5, 24,
	}
	self.cross = love.physics.newPolygonShape(self.body, unpack(cross_v))
	self.cross:setData("Grapple Cross Bar")
	self.cross:setRestitution(0.5)
	self.body:setMassFromShapes()
	return self
end

local initFont = function()
	local font = love.graphics.newFont(love.default_font, 12)
	love.graphics.setFont(font)
end

function load()
	initFont()

	world = newWorld()
	ground = newGround()
	circle = newCircle()
	grapple = newGrapple()
end

function update(dt)
	world:update(dt)
end

function draw()
	ground:draw()
	circle:draw()
	grapple:draw()

	-- text
	love.graphics.setColor(255, 255, 0)
	love.graphics.draw(text, 50, 50)
end

function keypressed(k)
	if k == love.key_space then
		circle.body:applyImpulse(1000000, -10000000)
	end
end

-- This is called every time a collision occurs.
function collision(a, b, contact)
	local f, r = contact:getFriction(), contact:getRestitution()
	local s = contact:getSeparation()
	local px, py = contact:getPosition()
	local vx, vy = contact:getVelocity()
	local nx, ny = contact:getNormal()

	text = "Last Collision:\n"
	text = text .. "Shapes: " .. a .. " and " .. b .. "\n"
	text = text .. "Position: " .. px .. "," .. py .. "\n"
	text = text .. "Velocity: " .. vx .. "," .. vy .. "\n"
	text = text .. "Normal: " .. nx .. "," .. ny .. "\n"
	text = text .. "Friction: " .. f .. "\n"
	text = text .. "Restitution: " .. r .. "\n"
	text = text .. "Separation: " .. s .. "\n"
end
