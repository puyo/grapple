module CP::Vec2::Zero
  @@zero = ::CP::Vec2.new(0, 0)
  def self.zero
    @@zero
  end
end

module CP::Vec2::RotatedAndOffset
  def rotated_and_offset(body)
    a = body.a
    body.p + CP::Vec2.new(x*Math.cos(a) - y*Math.sin(a),
                          x*Math.sin(a) + y*Math.cos(a))
  end
end

class CP::Vec2
  include ::CP::Vec2::Zero
  include ::CP::Vec2::RotatedAndOffset
end
