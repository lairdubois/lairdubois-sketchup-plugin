module Ladb::OpenCutList::Kuix

  class Mesh < Entity3d

    attr_accessor :background_color

    def initialize(id = nil)
      super(id)

      @background_color = nil
      @segments = [] # Array<Geom::Point3d>

      @points = []

    end

    def add_triangles(triangles) # Array<Geom::Point3d>
      raise 'Points count must be a multiple of 3' if triangles.length % 3 != 0
      @segments.concat(triangles)
    end

    # -- LAYOUT --

    def do_layout(transformation)
      @points = @segments.map { |point|
        point.transform(transformation * @transformation)
      }
      super
    end

    # -- Render --

    def paint_content(graphics)
      graphics.draw_triangles(@points, @background_color)
      super
    end

  end

end