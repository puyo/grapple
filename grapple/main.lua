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
		for i, shape in ipairs(self.shapes) do
			love.graphics.polygon(love.draw_line, shape:getPoints())
		end
	end
	self.body = love.physics.newBody(world, 0, 0, 0)
	self.shapes = {}
	self.shapes[1] = love.physics.newRectangleShape(self.body, -1000, 500, 4000, 20)
	self.shapes[1]:setData("Ground")

	self.shapes[2] = love.physics.newRectangleShape(self.body, 0, 0, 20, 1000)
	self.shapes[2]:setData("Ground")

	self.shapes[3] = love.physics.newRectangleShape(self.body, 800, 0, 20, 1000)
	self.shapes[3]:setData("Ground")
	return self
end

local newSquare = function()
	local self = {}
	function self:draw()
		love.graphics.setColor(0, 0, 255)
		love.graphics.polygon(love.draw_line, self.shape:getPoints())
	end
	self.body = love.physics.newBody(world, 500, 200)
	self.shape = love.physics.newRectangleShape(self.body, 0, 0, 50, 50)
	self.shape:setRestitution(0.2)
	self.shape:setData("Square")
	self.body:setMassFromShapes()
	return self
end

local newCircle = function()
	local self = {}
	function self:draw()
		love.graphics.setColor(0, 0, 255)
		love.graphics.circle(love.draw_line, self.body:getX(), self.body:getY(), 28, 20)
	end
	self.body = love.physics.newBody(world, 300, 200)
	self.shape = love.physics.newCircleShape(self.body, 28)
	self.shape:setRestitution(0.7) -- bouncy
	self.shape:setData("Ball")
	self.body:setMassFromShapes()
	return self
end

local newHook = function()
	local self = {}
	function self:draw()
		love.graphics.setColor(255, 0, 255)
		love.graphics.polygon(love.draw_line, self.shaft:getPoints())
		love.graphics.polygon(love.draw_line, self.cross:getPoints())
		love.graphics.polygon(love.draw_line, self.left_tip:getPoints())
		love.graphics.polygon(love.draw_line, self.right_tip:getPoints())
	end
	self.body = love.physics.newBody(world, 400, 100)

	local shaft_v = {
		-50,   -5,  -- top left
		-50,    5,  -- bottom left
		 35.5,  5,  -- bototm right
		 51,    0,  -- tip (far right)
		 35.5, -5,  -- top right
	}
	self.shaft = love.physics.newPolygonShape(self.body, unpack(shaft_v))
	self.shaft:setData("Grapple Shaft")

	local cross_v = {
		24, -24,  -- top left
		35, -24,  -- top right
		35,  24,  -- bottom right
		24,  24,  -- bottom left
	}
	self.cross = love.physics.newPolygonShape(self.body, unpack(cross_v))
	self.cross:setData("Grapple Cross Bar")

	local left_tip_v = {
		24, -24,
		35, -24,
		15, -37,
		24, -24,
	}
	self.left_tip = love.physics.newPolygonShape(self.body, unpack(left_tip_v))
	self.left_tip:setData("Grapple Left Tip")

	local right_tip_v = {
		24, 24,
		35, 24,
		15, 37,
		24, 24,
	}
	self.right_tip = love.physics.newPolygonShape(self.body, unpack(right_tip_v))
	self.right_tip:setData("Grapple Right Tip")

	for i, shape in ipairs({self.shaft, self.cross, self.left_tip, self.right_tip}) do
		shape:setRestitution(0)
		shape:setDensity(10)
		shape:setFriction(0.7)
		shape:setMaskBits(0xfffd)
		shape:setCategoryBits(0x0002)
	end

	self.body:setMassFromShapes()
	return self
end

local newRope = function(segments)
	local self = {}
	function self:draw()
		local last = nil
		for i, segment in ipairs(self.segments) do
			love.graphics.setColor(i * 255 / #self.segments, 255, 0)
			love.graphics.polygon(love.draw_line, segment.shape:getPoints())
			last = segment
		end
	end

	self.segment_length = 5

	self.segments = {}
	local last -- = ground
	for i = 1, segments do
		local body = love.physics.newBody(world, 200 + i*self.segment_length, 25)
		local shape = love.physics.newRectangleShape(body, 0, 0, 
			self.segment_length, 1)
		shape:setDensity(20)
		shape:setFriction(0.2)
		shape:setMaskBits(0xfffd)
		shape:setCategoryBits(0x0002)
		shape:setData("Rope")
		shape:setRestitution(0)
		local joint
		if last then
			joint = love.physics.newRevoluteJoint(last.body, body, 
				body:getX(), body:getY())
		end
		body:setMassFromShapes()
		last = { body = body, shape = shape, joint = joint }
		self.segments[i] = last
	end

	return self
end

local newGrapple = function()
	local self = {}
	self.body = love.physics.newBody(world, 400, 200)
	self.hook = newHook()
	self.rope = newRope(50)

	-- Join hook to rope
	local last_segment = self.rope.segments[#self.rope.segments]
	self.hook.body:setX(last_segment.body:getX() + 
		self.rope.segment_length + 50)
	self.hook.body:setY(last_segment.body:getY())
	self.joint = love.physics.newRevoluteJoint(last_segment.body, 
	    self.hook.body, 
		last_segment.body:getX() + self.rope.segment_length,
		last_segment.body:getY())

	function self:draw()
		self.hook:draw()
		self.rope:draw()
	end
	return self
end

local initFont = function()
	local font = love.graphics.newFont(love.default_font, 12)
	love.graphics.setFont(font)
end

function load()
	text = "No collision yet."
	initFont()
	world = newWorld()
	ground = newGround()
	circle = newCircle()
	square = newSquare()
	circle.body:setMass(0, 0, 0, 0)
	square.body:setMass(0, 0, 0, 0)
	grapple = newGrapple()
end

function update(dt)
	world:update(dt)
	world:update(dt) -- twice as fast!
	world:update(dt) -- twice as fast!
end

function draw()
	ground:draw()
	circle:draw()
	square:draw()
	grapple:draw()

	-- text
	love.graphics.setColor(255, 255, 0)
	love.graphics.draw(text, 50, 50)
end

function keypressed(k)
	local scale = 1000 * 1000
	if k == love.key_up then
		grapple.hook.body:applyImpulse(0, -10*scale)
	elseif k == love.key_left then
		grapple.hook.body:applyImpulse(-10*scale, 0)
	elseif k == love.key_right then
		grapple.hook.body:applyImpulse(10*scale, 0)
	elseif k == love.key_down then
		grapple.hook.body:applyImpulse(0, 10*scale)
	elseif k == love.key_q then
		love.system.exit()
	elseif k == love.key_escape then
		love.system.exit()
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
