require 'rubygems' rescue nil
require 'gosu'
require 'chipmunk'
require 'extensions/array'

def rot_point(body, vec2)
  x = vec2.x
  y = vec2.y
  a = body.a
  body.p + CP::Vec2.new(x*Math.cos(a) - y*Math.sin(a), x*Math.sin(a) + y*Math.cos(a))
end

def draw_poly(window, body, vertexes, colour)
  vertexes.each_edge do |a, b|
    a = rot_point(body, a)
    b = rot_point(body, b)
    window.draw_line(a.x, a.y, colour, b.x, b.y, colour)
  end
end

def draw_segment(window, body, vertexes, width, colour)
  a, b = vertexes[0], vertexes[1]
  a = rot_point(body, a)
  b = rot_point(body, b)
  window.draw_line(a.x, a.y - width, colour, b.x, b.y - width, colour)
  window.draw_line(a.x, a.y + width, colour, b.x, b.y + width, colour)
end

def draw_circle(window, body, radius, colour, options=nil)
  options ||= {}
  segs = options[:segments] || 32
  coef = 2.0*Math::PI / segs

  verts = []
  segs.times do |n|
    rads = n*coef
    verts << CP::Vec2.new(radius*Math.cos(rads + body.a) + body.p.x, radius*Math.sin(rads + body.a) + body.p.y)
  end
  verts.each_edge do |a, b|
    window.draw_line(a.x, a.y, colour, b.x, b.y, colour)
  end
end

# Convenience methods for converting between Gosu degrees, radians, and Vec2
# vectors
class Numeric 
  def gosu_to_radians
    (self - 90) * Math::PI / 180.0
  end
  
  def radians_to_gosu
    self * 180.0 / Math::PI + 90
  end
  
  def radians_to_vec2
    CP::Vec2.new(Math::cos(self), Math::sin(self))
  end
end

# A grappling hook demo
module Grapple

  SCREEN_WIDTH = 800
  SCREEN_HEIGHT = 600

  INF = 1e100

  # The number of steps to process every Gosu update The Player ship can get
  # going so fast as to "move through" a star without triggering a collision;
  # an increased number of Chipmunk step calls per update will effectively
  # avoid this issue
  SUBSTEPS = 6

  class Rope
    include CP

    attr_reader :shapes
    attr_reader :segment_length
    def links() @bodies end

    def initialize(space, options=nil)
      options ||= {}
      @space = space
      @length = options[:length] || 100
      @bodies = []
      @vertexes = []
      @shapes = []
      @segment_length = 10
      @length.times do |n|
        vertexes = [
          [-@segment_length/2, -2], # top left
          [-@segment_length/2, +2], # bottom left
          [+@segment_length/2, +2], # bottom right
          [+@segment_length/2, -2], # top right
        ].map{|x,y| Vec2.new(x, y) }
        mass = 1
        #body = Body.new(mass, moment_for_poly(mass, vertexes, Vec2.new(0, 0)))
        body = Body.new(mass, 100)
        body.p.x = n*@segment_length
        shape = Shape::Poly.new(body, vertexes, Vec2.new(0, 0)) # body, verts, offset
        shape.collision_type = :rope
        shape.u = 0.1 # slippery
        shape.group = :grapple
        space.add_body(body)
        space.add_shape(shape)
        @bodies << body
        @vertexes << vertexes
        @shapes << shape
      end

      i = 0
      @bodies.each_link do |prev_body, body|
        joint = Joint::Pivot.new(prev_body, body, body.p - Vec2.new(@segment_length/2, 0))
        space.add_joint(joint)
        i += 1
      end
    end

    def draw(window)
      #draw_gradient(window)
      draw_segments(window)
    end

    def draw_segments(window)
      col1 = Gosu::Color.new(0xffff0000)
      col2 = Gosu::Color.new(0xffffff00)
      i = 0
      @bodies.each_with_index do |body, i|
        draw_poly(window, body, @vertexes[i], col2)
        i += 1
      end
    end

    def draw_gradient(window)
      col = Gosu::Color.new(0xffff0000)
      i = 0
      @bodies.each_link do |prev, link|
        col.green = (255*i / @bodies.size)
        window.draw_line(prev.p.x, prev.p.y, col, link.p.x, link.p.y, col)
        i += 1
      end
    end

    def remove_first
      if @bodies.any?
        @space.remove_body(@bodies.shift)
        @space.remove_shape(@shapes.shift)
      end
    end
  end

  class Ground
    include CP

    attr_reader :body

    def initialize(space)
      @body = Body.new(INF, INF)
      @vertexes = [
        [0, SCREEN_HEIGHT-200], # top left
        [0, SCREEN_HEIGHT], # bottom left
        [SCREEN_WIDTH, SCREEN_HEIGHT], # bottom right
        [SCREEN_WIDTH, SCREEN_HEIGHT-200], # top right
      ].map{|x,y| Vec2.new(x, y) }
      @shape = Shape::Poly.new(@body, @vertexes, Vec2.new(0, 0)) # body, verts, offset
      @shape.collision_type = :ground
      @shape.group = :ground
      @shape.u = 1.0
      space.add_shape(@shape)
    end

    def draw(window)
      draw_poly(window, body, @vertexes, Gosu::Color.new(0xff0000ff))
    end
  end

  class Castle
    include CP

    attr_reader :body

    def initialize(space, options=nil)
      options ||= {}
      @body = Body.new(INF, INF)
      @main_vertexes = [
        [-100, -100], # bottom left
        [-100, 100], # top left
        [100, 100], # top right
        [100, -100], # bottom right
      ].map{|x,y| Vec2.new(x, y) }
      @main_shape = Shape::Poly.new(@body, @main_vertexes, Vec2.new(0, 0)) # body, verts, offset
      @main_shape.collision_type = :castle
      @main_shape.group = :castle
      @main_shape.u = 1.0
      space.add_shape(@main_shape)

      @snag_vertexes = [
        [-90, -100], # bottom left
        [-90, -110], # top left
        [-110, -110], # top right
        [-110, -100], # bottom right
      ].map{|x,y| Vec2.new(x, y) }
      @snag_shape = Shape::Poly.new(@body, @snag_vertexes, Vec2.new(0, 0)) # body, verts, offset
      @snag_shape.collision_type = :castle
      @snag_shape.group = :castle
      @snag_shape.u = 1.0
      space.add_shape(@snag_shape)

      #@radius = 200
      #@circle = Shape::Circle.new(@body, @radius, Vec2.new(0, 0))
      #@circle.collision_type = :castle
      #@circle.u = 0.5
      #@circle.group = :castle
      #space.add_shape(@circle)
    end

    def draw(window)
      draw_poly(window, @body, @main_vertexes, Gosu::Color.new(0xffaaaaaa))
      draw_poly(window, @body, @snag_vertexes, Gosu::Color.new(0xffaaaaaa))
      #draw_circle(window, @body, @radius, Gosu::Color.new(0xff00ff00))
    end
  end

  class GrappleHook
    include CP

    attr_reader :body
    attr_reader :shaft_v
    attr_reader :cross_v
    attr_reader :left_tip_v
    attr_reader :right_tip_v

    def initialize(space)
      @shaft_v = [
        [-50,   -5],  # top left
        [-50,    5],  # bottom left
        [ 35.5,  5],  # bottom right
        [ 51,    0],  # tip (far right)
        [ 35.5, -5],  # top right
      ]
      @cross_v = [
        [24, -24],  # top left
        [35, -24],  # top right
        [35,  24],  # bottom right
        [24,  24],  # bottom left
      ]
      @left_tip_v = [
        [24, -24],
        [35, -24],
        [15, -37],
        [24, -24],
      ]
      @right_tip_v = [
        [24, 24],
        [35, 24],
        [15, 37],
        [24, 24],
      ]
      @vertexes = [@shaft_v, @cross_v, @left_tip_v, @right_tip_v]

      scale = 0.3
      for v in @vertexes
        v.map!{|x,y| Vec2.new(scale*(x - 14), scale*y) }
      end

      mass = 30
      moment = @vertexes.map{|v| moment_for_poly(mass, v, Vec2.new(0, 0)) }.inject(0){|s,m| s += m }
      @body = Body.new(mass, moment)
      space.add_body(@body)
      for v in @vertexes
        shape = Shape::Poly.new(@body, v, Vec2.new(0, 0)) # body, verts, offset
        shape.collision_type = :hook
        shape.u = 1.0
        shape.group = :grapple
        space.add_shape(shape)
      end
    end

    def draw(window)
      for v in @vertexes
        draw_poly(window, @body, v, Gosu::Color.new(0xffff0000))
      end
    end
  end

  class GameWindow < Gosu::Window
    include CP

    def initialize
      super(SCREEN_WIDTH, SCREEN_HEIGHT, false, 16)
      self.caption = "Grapple"

      @space = Space.new
      @space.damping = 0.8    
      @space.gravity = Vec2.new(0, 10.0)
      @dt = (1.0/60.0)

      @ground = Ground.new(@space)

      @grapple_origin = Vec2.new(200.0, 370.0)

      @rope = Rope.new(@space, :length => 45)
      @hook = GrappleHook.new(@space)
      # attach rope and hook
      between = @rope.links.last.p + Vec2.new(@rope.segment_length/2, 0)
      @hook.body.p = between + Vec2.new(-@hook.shaft_v.first.x, 0)
      joint = Joint::Pivot.new(@hook.body, @rope.links.last, between)
      @space.add_joint(joint)
      reset_hook

      # attach other end of rope to ground
      @rope.links.first.p = @grapple_origin
      attach = Joint::Pivot.new(@ground.body, @rope.links.first, @grapple_origin)
      @space.add_joint(attach)

      # make a nice hanging rope
      @rope2 = Rope.new(@space, :length => 10)
      hanging = Body.new(INF, INF)
      joint = Joint::Pin.new(hanging, @rope2.links.first, Vec2.new(0, 0), Vec2.new(0, 0))
      @space.add_joint(joint)
      @rope2.links.each_with_index{|link, i| link.p = Vec2.new(100 - 10*i, 200) }
      hanging.p = Vec2.new(150, 0)

      @castle = Castle.new(@space)
      @castle.body.p = Vec2.new(500, 250)

      @space.add_collision_func(:hook, :hook) do
        #p 'hook hook ' + rand.to_s
      end
      @space.add_collision_func(:rope, :rope) do
        #p 'rope rope ' + rand.to_s
      end
      @space.add_collision_func(:hook, :rope) do
        #p 'hook rope ' + rand.to_s
      end
      @space.add_collision_func(:rope, :hook) do
        #p 'rope hook ' + rand.to_s
      end
      @space.add_collision_func(:hook, :ground) do
        #p 'hook ground ' + rand.to_s
      end
      @space.add_collision_func(:hook, :castle) do
        #p 'hook castle ' + rand.to_s
      end
      @space.add_collision_func(:rope, :castle) do
        #p 'rope castle ' + rand.to_s
      end
    end

    def update
      SUBSTEPS.times do
        @space.step(@dt)
      end
    end

    def draw
      @rope.draw(self)
      @rope2.draw(self)
      @ground.draw(self)
      @hook.draw(self)
      @castle.draw(self)

      #@t0 = @t0 || Time.now
      #t = Time.now
      #p 1.0/(t - @t0)
      #@t0 = t
    end

    def button_down(id)
      case id
      when Gosu::Button::KbUp
        @hook.body.v += Vec2.new(0, -100)
      when Gosu::Button::KbDown
        @hook.body.v += Vec2.new(0, 100)
      when Gosu::Button::KbLeft
        @hook.body.v += Vec2.new(-100, 0)
      when Gosu::Button::KbRight
        @hook.body.v += Vec2.new(100, 0)
      when Gosu::Button::KbSpace # 'throw'
        @hook.body.v += Vec2.new(100, -200)
      when char_to_button_id('r')
        reset_hook
      when Gosu::Button::KbEscape, char_to_button_id('q')
        close
      when char_to_button_id('p')
        @rope.remove_first
        attach = Joint::Slide.new(@ground.body, @rope.links.first, @grapple_origin, Vec2.new(0, 0), 0, 0)
        @space.add_joint(attach)
      end
    end

    def reset_hook
      @hook.body.p = @grapple_origin
      @rope.links.each_with_index{|link, i| link.p = Vec2.new(@grapple_origin.x + 10*Math.cos(i.to_f * Math::PI*2 / @rope.links.size), @grapple_origin.y) }
    end
  end
end

if $0 == __FILE__
  window = Grapple::GameWindow.new
  window.show
end
