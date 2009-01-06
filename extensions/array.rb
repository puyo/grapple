module Array::PolygonEachMethods
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

class Array
  include Array::PolygonEachMethods
end
