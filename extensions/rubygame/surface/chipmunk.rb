require 'extensions/chipmunk/vec2'

# Methods on Rubygame::Surface for drawing Chipmunk physics engine primatives.
module Rubygame::Surface::Chipmunk
  def draw_chipmunk_poly(body, vertexes, colour)
    vertexes.each_edge do |a, b|
      a = a.rotated_and_offset(body)
      b = b.rotated_and_offset(body)
      draw_line([a.x, a.y], [b.x, b.y], colour)
    end
  end

  def draw_chipmunk_segment(body, vertexes, width, colour)
    a, b = vertexes[0], vertexes[1]
    a = a.rotated_and_offset(body)
    b = b.rotated_and_offset(body)
    draw_line([a.x, a.y - width], [b.x, b.y - width], colour)
    draw_line([a.x, a.y + width], [b.x, b.y + width], colour)
  end

  def draw_chipmunk_circle(body, radius, colour, options=nil)
    draw_circle([body.p.x, body.p.y], radius, colour)
  end
end

class Rubygame::Surface
  include Rubygame::Surface::Chipmunk
end
