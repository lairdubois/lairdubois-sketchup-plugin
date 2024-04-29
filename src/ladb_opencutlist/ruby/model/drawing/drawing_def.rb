module Ladb::OpenCutList

  class DrawingDef

    VIEW_TYPE_CUSTOM = nil
    VIEW_TYPE_TOP = 'top'.freeze
    VIEW_TYPE_BOTTOM = 'bottom'.freeze
    VIEW_TYPE_LEFT = 'left'.freeze
    VIEW_TYPE_RIGHT = 'right'.freeze
    VIEW_TYPE_FRONT = 'front'.freeze
    VIEW_TYPE_BACK = 'back'.freeze

    attr_reader :faces_bounds, :edges_bounds, :bounds, :face_manipulators, :surface_manipulators, :edge_manipulators, :curve_manipulators
    attr_accessor :transformation, :input_plane_manipulator, :input_line_manipulator, :view_type

    def initialize

      @view_type = VIEW_TYPE_CUSTOM

      @transformation = Geom::Transformation.new

      @faces_bounds = Geom::BoundingBox.new
      @edges_bounds = Geom::BoundingBox.new
      @bounds = Geom::BoundingBox.new

      @face_manipulators = []
      @surface_manipulators = []
      @edge_manipulators = []
      @curve_manipulators = []

      @input_plane_manipulator = nil
      @input_line_manipulator = nil

    end

    # -----

    def translate_to!(point)
      t = Geom::Transformation.translation(Geom::Vector3d.new(point.to_a))
      transform!(t)
    end

    def transform!(transformation)
      return if transformation.identity?

      ti = transformation.inverse

      @transformation *= transformation
      @input_plane_manipulator.transformation = ti * @input_plane_manipulator.transformation unless @input_plane_manipulator.nil?
      @input_line_manipulator.transformation = ti * @input_line_manipulator.transformation unless @input_line_manipulator.nil?

      unless @faces_bounds.empty?
        min = @faces_bounds.min.transform(ti)
        max = @faces_bounds.max.transform(ti)
        @faces_bounds.clear
        @faces_bounds.add(min, max)
      end

      unless @edges_bounds.empty?
        min = @edges_bounds.min.transform(ti)
        max = @edges_bounds.max.transform(ti)
        @edges_bounds.clear
        @edges_bounds.add(min, max)
      end

      unless @bounds.empty?
        min = @bounds.min.transform(ti)
        max = @bounds.max.transform(ti)
        @bounds.clear
        @bounds.add(min, max)
      end

      @face_manipulators.each do |face_manipulator|
        face_manipulator.transformation = ti * face_manipulator.transformation
      end
      @surface_manipulators.each do |surface_manipulator|
        surface_manipulator.transformation = ti * surface_manipulator.transformation
      end

      @edge_manipulators.each do |edge_manipulator|
        edge_manipulator.transformation = ti * edge_manipulator.transformation
      end
      @curve_manipulators.each do |curve_manipulator|
        curve_manipulator.transformation = ti * curve_manipulator.transformation
      end

    end

  end

end