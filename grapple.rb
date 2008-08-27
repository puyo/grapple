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

    def initialize(space, options=nil)
      options ||= {}
      @length = options[:length] || 100
      @links = []
      @length.times do |n|
        link = Body.new(1, 0.1)
        seg = Shape::Circle.new(link, 0.1, Vec2.new(0.0, 0.0))
        seg.collision_type = :rope
        seg.u = 0.5
        seg.group = :grapple
        space.add_body(link)
        space.add_shape(seg)
        @links << link
      end

      @links.each_link do |prev, link|
        joint = Joint::Slide.new(prev, link, Vec2.new(0.0, 0.0), Vec2.new(1.0, 0.0), 0.1, 4.0)
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
      col = Gosu::Color.new(0xff0000ff)
      window.draw_line(@p1.x, @p1.y - @width, col, @p2.x, @p2.y - @width, col)
      window.draw_line(@p1.x, @p1.y + @width, col, @p2.x, @p2.y + @width, col)
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
        [-100, -100],
        [-100, 100],
        [100, 100],
        [100, -100],
      ].map{|x,y| Vec2.new(x, y) }
      @shape = Shape::Poly.new(@body, @main_vertexes, Vec2.new(0,0)) # body, verts, offset
      @shape.collision_type = :castle
      @shape.group = :castle
      @shape.u = 0.99
      space.add_static_shape(@shape)
    end

    def draw(window)
      draw_poly(window, @body, @main_vertexes, Gosu::Color.new(0xffaaaaaa))
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

      @rope = Rope.new(@space, :length => 15)
      @hook = GrappleHook.new(@space)
      joint = Joint::Pin.new(@hook.body, @rope.links.last, Vec2.new(0.0, -20.0 * GRAPPLE_SIZE), Vec2.new(0.0, 0.0))
      @space.add_joint(joint)
      @rope.links.each_with_index{|link, i| link.p = Vec2.new(@grapple_origin.x + 100*Math.cos(i.to_f * Math::PI*2 / @rope.links.size), @grapple_origin.y) }
      @hook.body.p = @grapple_origin

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
          @hook.body.p = @grapple_origin
          @rope.links.each{|link| link.p = @grapple_origin }
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
      end
    end
  end
end

if $0 == __FILE__
  window = Grapple::GameWindow.new
  window.show
end
