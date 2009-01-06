module Rubygame::Surface::Fixes
  # Rubygame seems to segfault if you try to draw a line with y < 0
  def draw_line_safe(p1, p2, col)
    if p1[0] < 0.0 or p1[1] < 0.0 or p2[0] < 0.0 or p2[1] < 0.0
      return
    end
    draw_line_old(p1, p2, col)
  end
end

class Rubygame::Surface
  include Rubygame::Surface::Fixes
  alias draw_line_old draw_line
  alias draw_line draw_line_safe 
end


