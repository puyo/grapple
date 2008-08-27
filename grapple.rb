require 'rubygems' rescue nil
require 'gosu'
require 'chipmunk'

class Array
  # e.g. [1,2,3].each_link yields [1,2], [2,3]
  def each_link
    prev = first
    self[1, size].each do |item|
      yield prev, item
      prev = item
    end
  end

  def each_edge
    size.times do |n|
      yield self[n], self[(n + 1) % size]
    end
  end
end

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

# Convenience methods for converting between Gosu degrees, radians, and Vec2 vectors
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

class CP::Vec2
  @@zero = CP::Vec2.new(0.0, 0.0)
  def self.zero
    @@zero
  end
end

# A grappling hook demo
module Grapple

  SCREEN_WIDTH = 800
  SCREEN_HEIGHT = 600

  INF = 1e100

  GRAPPLE_SIZE = 0.3

  # The number of steps to process every Gosu update The Player ship can get
  # going so fast as to "move through" a star without triggering a collision;
  # an increased number of Chipmunk step calls per update will effectively
  # avoid this issue
  SUBSTEPS = 6

  class Rope
    include CP

    attr_reader :links
    attr_reader :circles

    def initialize(space, options=nil)
      options ||= {}
      @space = space
      @length = options[:length] || 100
      @links = []
      @circles = []
      @length.times do |n|
        link = Body.new(10, 10)
        seg = Shape::Circle.new(link, 1.0, Vec2.zero)
        #seg = Shape::Segment.new(link, Vec2.new(0, 0), Vec2.new(1, 0), 1)
        seg.collision_type = :rope
        seg.u = 0.5
        seg.group = :grapple
        space.add_body(link)
        space.add_shape(seg)
        @links << link
        @circles << seg
      end

      @links.each_link do |prev, link|
        joint = Joint::Slide.new(prev, link, Vec2.new(0.0, 0.0), Vec2.new(1.0, 0.0), 0.1, 10.0)
        space.add_joint(joint)
      end
    end

    def draw(window)
      draw_gradient(window)
    end

    def draw_segments(window)
      col1 = Gosu::Color.new(0xffff0000)
      col2 = Gosu::Color.new(0xffffff00)
      @links.each_link do |prev, link|
        window.draw_line(prev.p.x, prev.p.y, col1, link.p.x, link.p.y, col2)
      end
    end

    def draw_gradient(window)
      col = Gosu::Color.new(0xffff0000)
      i = 0
      @links.each_link do |prev, link|
        col.green = (255*i / @links.size)
        window.draw_line(prev.p.x, prev.p.y, col, link.p.x, link.p.y, col)
        i += 1
      end

      @circles.each do |circle|
        draw_circle(window, circle.body, 1.0, Gosu::Color.new(0xffffffff))
      end
    end

    def remove_first
      if @links.any?
        @space.remove_body(@links.shift)
        @space.remove_shape(@circles.shift)
      end
    end
  end

  class Ground
    include CP

    attr_reader :body

    def initialize(space)
      @links = []
      @body = Body.new(INF, INF)
      @p1, @p2 = Vec2.new(0, 500), Vec2.new(SCREEN_WIDTH, 440)
      @width = 100
      @seg = Shape::Segment.new(@body, @p1, @p2, @width)
      @seg.collision_type = :ground
      @seg.u = 0.99
      space.add_static_shape(@seg)
    end

    def draw(window)
      draw_segment(window, body, [@p1, @p2], @width, Gosu::Color.new(0xff0000ff))
    end
  end

  class Castle
    include CP

    attr_reader :body

    def initialize(space, options=nil)
      options ||= {}
      @links = []
      @body = Body.new(INF, INF)
      @main_vertexes = [
        [-100, -100], # bottom left
        [-100, 100], # top left
        [100, 100], # top right
        [100, -100], # bottom right
      ].map{|x,y| Vec2.new(x, y) }
      @main_shape = Shape::Poly.new(@body, @main_vertexes, Vec2.new(0,0)) # body, verts, offset
      @main_shape.collision_type = :castle
      @main_shape.group = :castle
      @main_shape.u = 0.99
      space.add_shape(@main_shape)

      @snag_vertexes = [
        [-90, -100], # bottom left
        [-90, -110], # top left
        [-110, -110], # top right
        [-110, -100], # bottom right
      ].map{|x,y| Vec2.new(x, y) }
      @snag_shape = Shape::Poly.new(@body, @snag_vertexes, Vec2.new(0,0)) # body, verts, offset
      @snag_shape.collision_type = :castle
      @snag_shape.group = :castle
      @snag_shape.u = 0.99
      space.add_shape(@snag_shape)

      #@radius = 200
      #@circle = Shape::Circle.new(@body, @radius, Vec2.new(0.0, 0.0))
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
    attr_reader :shape

    def initialize(space, options=nil)
      options ||= {}
      @links = []
      @body = Body.new(options[:mass] || 100, options[:moment] || 100)
      @vertexes = [
        [-5, -50],
        [-5, 25],
        [-22, 25],
        [-37, 15],
        [-27, 35],
        [-5, 35],
        [0, 50],
        [5, 35],
        [27, 35],
        [37, 15],
        [25, 25],
        [5, 25],
        [5, -50],
      ].map{|x,y| Vec2.new(GRAPPLE_SIZE*x, GRAPPLE_SIZE*y) }
      @shape = Shape::Poly.new(@body, @vertexes, Vec2.new(0,0)) # body, verts, offset
      @shape.collision_type = :hook
      @shape.u = 0.99
      @shape.group = :grapple
      space.add_body(@body)
      space.add_shape(@shape)
    end

    def draw(window)
      draw_poly(window, @body, @vertexes, Gosu::Color.new(0xffff0000))
    end
  end

  class GameWindow < Gosu::Window
    include CP

    def initialize
      super(SCREEN_WIDTH, SCREEN_HEIGHT, false, 16)
      self.caption = "Grapple"

      @space = Space.new
      @space.damping = 0.8    
      @space.gravity = Vec2.new(0.0, 10.0)
      @dt = (1.0/60.0)

      @ground = Ground.new(@space)

      @grapple_origin = Vec2.new(200.0, 370.0)

      @rope = Rope.new(@space, :length => 45)
      @hook = GrappleHook.new(@space)
      joint = Joint::Pin.new(@hook.body, @rope.links.last, Vec2.new(0.0, -20.0 * GRAPPLE_SIZE), Vec2.new(0.0, 0.0))
      @space.add_joint(joint)
      reset_hook

      attach = Joint::Slide.new(@ground.body, @rope.links.first, @grapple_origin, Vec2.new(0.0, 0.0), 0, 0)
      @space.add_joint(attach)

      @rope2 = Rope.new(@space, :length => 10)
      hanging = Body.new(INF, INF)
      joint = Joint::Pin.new(hanging, @rope2.links.first, Vec2.new(0.0, 0.0), Vec2.new(0.0, 0.0))
      @space.add_joint(joint)
      @rope2.links.each_with_index{|link, i| link.p = Vec2.new(100 - 10*i, 200) }
      hanging.p = Vec2.new(150, 0)

      @castle = Castle.new(@space)
      @castle.body.p = Vec2.new(500, 250)

      @space.add_collision_func(:hook, :hook) do
        p 'hook hook ' + rand.to_s
      end
      @space.add_collision_func(:rope, :rope) do
        p 'rope rope ' + rand.to_s
      end
      @space.add_collision_func(:hook, :rope) do
        p 'hook rope ' + rand.to_s
      end
      @space.add_collision_func(:rope, :hook) do
        p 'rope hook ' + rand.to_s
      end
      @space.add_collision_func(:hook, :ground) do
        p 'hook ground ' + rand.to_s
      end
      @space.add_collision_func(:hook, :castle) do
        p 'hook castle ' + rand.to_s
      end
      @space.add_collision_func(:rope, :castle) do
        p 'rope castle ' + rand.to_s
      end
    end

    def update
      SUBSTEPS.times do
        # Check keyboard
        if button_down? Gosu::Button::KbSpace
          @hook.body.v = Vec2.new(50, -100)
        end
        if button_down? char_to_button_id('r')
          reset_hook
        end
        @space.step(@dt)
      end
    end

    def draw
      @rope.draw(self)
      @rope2.draw(self)
      @ground.draw(self)
      @hook.draw(self)
      @castle.draw(self)
    end

    def button_down(id)
      case id
      when Gosu::Button::KbEscape, char_to_button_id('q')
        close
      when char_to_button_id('p')
        @rope.remove_first
        attach = Joint::Slide.new(@ground.body, @rope.links.first, @grapple_origin, Vec2.new(0.0, 0.0), 0, 0)
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
