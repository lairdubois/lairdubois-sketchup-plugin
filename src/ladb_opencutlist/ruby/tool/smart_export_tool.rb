module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/geometrix/geometrix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/edge_segments_helper'
  require_relative '../helper/entities_helper'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/loop_manipulator'
  require_relative '../worker/common/common_write_drawing2d_worker'
  require_relative '../worker/common/common_write_drawing3d_worker'
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_drawing_projection_worker'
  require_relative '../observer/plugin_observer'

  class SmartExportTool < SmartTool

    include LayerVisibilityHelper
    include EdgeSegmentsHelper
    include EntitiesHelper

    ACTION_EXPORT_PART_3D = 0
    ACTION_EXPORT_PART_2D = 1
    ACTION_EXPORT_FACE = 2
    ACTION_EXPORT_EDGES = 3

    ACTION_OPTION_FILE_FORMAT = 'file_format'
    ACTION_OPTION_UNIT = 'unit'
    ACTION_OPTION_FACES = 'faces'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_FILE_FORMAT_DXF = FILE_FORMAT_DXF
    ACTION_OPTION_FILE_FORMAT_STL = FILE_FORMAT_STL
    ACTION_OPTION_FILE_FORMAT_OBJ = FILE_FORMAT_OBJ
    ACTION_OPTION_FILE_FORMAT_SVG = FILE_FORMAT_SVG

    ACTION_OPTION_FACES_ONE = 0
    ACTION_OPTION_FACES_ALL = 1

    ACTION_OPTION_OPTIONS_ANCHOR = 'anchor'
    ACTION_OPTION_OPTIONS_SMOOTHING = 'smoothing'
    ACTION_OPTION_OPTIONS_MERGE_HOLES = 'merge_holes'
    ACTION_OPTION_OPTIONS_EDGES = 'edges'

    ACTIONS = [
      {
        :action => ACTION_EXPORT_PART_3D,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_STL, ACTION_OPTION_FILE_FORMAT_OBJ ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_ANCHOR ]
        }
      },
      {
        :action => ACTION_EXPORT_PART_2D,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SVG, ACTION_OPTION_FILE_FORMAT_DXF ],
          ACTION_OPTION_FACES => [ ACTION_OPTION_FACES_ONE, ACTION_OPTION_FACES_ALL ],
          ACTION_OPTION_OPTIONS => [ACTION_OPTION_OPTIONS_ANCHOR, ACTION_OPTION_OPTIONS_SMOOTHING, ACTION_OPTION_OPTIONS_MERGE_HOLES, ACTION_OPTION_OPTIONS_EDGES ]
        }
      },
      {
        :action => ACTION_EXPORT_FACE,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SVG, ACTION_OPTION_FILE_FORMAT_DXF ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_SMOOTHING ]
        }
      },
      # {
      #   :action => ACTION_EXPORT_EDGES,
      #   :options => {
      #     ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SVG, ACTION_OPTION_FILE_FORMAT_DXF ],
      #   }
      # }
    ].freeze

    COLOR_MESH = Sketchup::Color.new(0, 0, 255, 100).freeze
    COLOR_MESH_HIGHLIGHTED = Sketchup::Color.new(0, 0, 255, 200).freeze
    COLOR_PART_UPPER = Kuix::COLOR_BLUE
    COLOR_PART_HOLES = Sketchup::Color.new('#D783FF').freeze
    COLOR_PART_DEPTH = COLOR_PART_UPPER.blend(Kuix::COLOR_WHITE, 0.5).freeze
    COLOR_EDGE = Kuix::COLOR_CYAN
    COLOR_ACTION = Kuix::COLOR_MAGENTA

    @@action = nil

    def initialize(material = nil)
      super(true, false)

      # Create cursors
      @cursor_export_stl = create_cursor('export-stl', 0, 0)
      @cursor_export_obj = create_cursor('export-obj', 0, 0)
      @cursor_export_dxf = create_cursor('export-dxf', 0, 0)
      @cursor_export_svg = create_cursor('export-svg', 0, 0)

    end

    def get_stripped_name
      'export'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_cursor(action)

      case action
      when ACTION_EXPORT_PART_3D
        if fetch_action_option_enabled(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_STL)
          return @cursor_export_stl
        elsif fetch_action_option_enabled(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_OBJ)
          return @cursor_export_obj
        elsif fetch_action_option_enabled(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      when ACTION_EXPORT_PART_2D
        if fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return @cursor_export_svg
        elsif fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      when ACTION_EXPORT_FACE
        if fetch_action_option_enabled(ACTION_EXPORT_FACE, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return @cursor_export_svg
        elsif fetch_action_option_enabled(ACTION_EXPORT_FACE, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      when ACTION_EXPORT_EDGES
        if fetch_action_option_enabled(ACTION_EXPORT_EDGES, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return @cursor_export_svg
        elsif fetch_action_option_enabled(ACTION_EXPORT_EDGES, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      end

      super
    end

    def get_action_options_modal?(action)

      case action
      when ACTION_EXPORT_PART_3D, ACTION_EXPORT_PART_2D, ACTION_EXPORT_FACE
        return true
      end

      super
    end

    def get_action_option_group_unique?(action, option_group)

      case option_group
      when ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_UNIT, ACTION_OPTION_FACES
        return true
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group
      when ACTION_OPTION_FILE_FORMAT
        case option
        when ACTION_OPTION_FILE_FORMAT_STL
          return Kuix::Label.new('STL')
        when ACTION_OPTION_FILE_FORMAT_OBJ
          return Kuix::Label.new('OBJ')
        when ACTION_OPTION_FILE_FORMAT_DXF
          return Kuix::Label.new('DXF')
        when ACTION_OPTION_FILE_FORMAT_SVG
          return Kuix::Label.new('SVG')
        end
      when ACTION_OPTION_FACES
        case option
        when ACTION_OPTION_FACES_ONE
          return Kuix::Label.new('1')
        when ACTION_OPTION_FACES_ALL
          return Kuix::Label.new('∞')
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_ANCHOR
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.273,0L0.273,0.727L1,0.727 M0.091,0.545L0.455,0.545L0.455,0.909L0.091,0.909L0.091,0.545 M0.091,0.182L0.273,0L0.455,0.182 M0.818,0.545L1,0.727L0.818,0.909'))
        when ACTION_OPTION_OPTIONS_SMOOTHING
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M1,0.719L0.97,0.548L0.883,0.398L0.75,0.286L0.587,0.227L0.413,0.227L0.25,0.286L0.117,0.398L0.03,0.548L0,0.719'))
        when ACTION_OPTION_OPTIONS_MERGE_HOLES
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.167L0.5,0L1,0.167L0.75,0.25L0.5,0.167L0.25,0.25L0,0.167 M0.25,0.833L0.5,0.75L0.75,0.833L0.5,0.917L0.25,0.833 M0.5,0.333L0.5,0.667 M0.667,0.5L0.333,0.5'))
        when ACTION_OPTION_OPTIONS_EDGES
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,0L0.167,1 M0,0.167L1,0.167 M0,0.833L1,0.833 M0.833,0L0.833,1'))
        end
      end

      super
    end

    def store_action(action)
      @@action = action
    end

    def fetch_action
      @@action
    end

    def is_action_export_part_3d?
      fetch_action == ACTION_EXPORT_PART_3D
    end

    def is_action_export_part_2d?
      fetch_action == ACTION_EXPORT_PART_2D
    end

    def is_action_export_face?
      fetch_action == ACTION_EXPORT_FACE
    end

    def is_action_export_edges?
      fetch_action == ACTION_EXPORT_EDGES
    end

    # -- Events --

    def onActivate(view)
      super

      # Clear current selection
      Sketchup.active_model.selection.clear if Sketchup.active_model

    end

    def onActionChange(action)

      # Simulate mouse move event
      _handle_mouse_event(:move)

    end

    def onKeyDown(key, repeat, flags, view)
      return true if super
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      return true if super
    end

    def onLButtonDown(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:l_button_down)
      end
    end

    def onLButtonUp(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:l_button_up)
      end
    end

    def onMouseMove(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:move)
      end
    end

    def onMouseLeave(view)
      return true if super
      _reset_active_part
      _reset_active_face
    end

    # -----

    protected

    def _set_active_part(part_entity_path, part, highlighted = false)
      super

      if part

        # Show part infos

        infos = [ "#{part.length} x #{part.width} x #{part.thickness}" ]
        infos << "#{part.material_name} (#{Plugin.instance.get_i18n_string("tab.materials.type_#{part.group.material_type}")})" unless part.material_name.empty?
        infos << Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.5,0L0.5,0.2 M0.5,0.4L0.5,0.6 M0.5,0.8L0.5,1 M0,0.2L0.3,0.5L0,0.8L0,0.2 M1,0.2L0.7,0.5L1,0.8L1,0.2')) if part.flipped
        infos << Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.6,0L0.4,0 M0.6,0.4L0.8,0.2L0.5,0.2 M0.8,0.2L0.8,0.5 M0.8,0L1,0L1,0.2 M1,0.4L1,0.6 M1,0.8L1,1L0.8,1 M0.2,0L0,0L0,0.2 M0,1L0,0.4L0.6,0.4L0.6,1L0,1')) if part.resized

        show_infos(_get_active_part_name, infos)

        if is_action_export_part_3d?

          # Part 3D

          @active_drawing_def = CommonDrawingDecompositionWorker.new(@active_part_entity_path, {
            'use_bounds_min_as_origin' => !fetch_action_option_enabled(ACTION_EXPORT_PART_3D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR),
            'ignore_surfaces' => true,
            'ignore_edges' => true
          }).run
          if @active_drawing_def.is_a?(DrawingDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            preview = Kuix::Group.new
            preview.transformation = @active_drawing_def.transformation
            @space.append(preview)

            @active_drawing_def.face_manipulators.each do |face_info|

              # Highlight face
              mesh = Kuix::Mesh.new
              mesh.add_triangles(FaceManipulator.new(face_info.face, face_info.transformation).triangles)
              mesh.background_color = highlighted ? COLOR_MESH_HIGHLIGHTED : COLOR_MESH
              preview.append(mesh)

            end

            @active_drawing_def.edge_manipulators.each do |edge_info|

              # Highlight edge
              segments = Kuix::Segments.new
              segments.add_segments(EdgeManipulator.new(edge_info.edge, edge_info.transformation).segment)
              segments.color = COLOR_EDGE
              segments.line_width = 2
              segments.on_top = true
              preview.append(segments)

            end

            bounds = Geom::BoundingBox.new
            bounds.add(@active_drawing_def.bounds.min)
            bounds.add(@active_drawing_def.bounds.max)
            bounds.add(ORIGIN)

            # Box helper
            box_helper = Kuix::BoxMotif.new
            box_helper.bounds.origin.copy!(bounds.min)
            box_helper.bounds.size.copy!(bounds)
            box_helper.bounds.apply_offset(inch_offset, inch_offset, inch_offset)
            box_helper.color = Kuix::COLOR_BLACK
            box_helper.line_width = 1
            box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            preview.append(box_helper)

            # Axes helper
            axes_helper = Kuix::AxesHelper.new
            preview.append(axes_helper)

          end

        elsif is_action_export_part_2d?

          # Part 2D

          local_x_axis = part.def.size.oriented_axis(X_AXIS)
          local_y_axis = part.def.size.oriented_axis(Y_AXIS)
          local_z_axis = part.def.size.oriented_axis(Z_AXIS)

          @active_drawing_def = CommonDrawingDecompositionWorker.new(@active_part_entity_path, {
            'input_local_x_axis' => local_x_axis,
            'input_local_y_axis' => local_y_axis,
            'input_local_z_axis' => local_z_axis,
            'input_face_path' => @input_face_path,
            'input_edge_path' => @input_edge.nil? ? nil : @input_face_path + [ @input_edge ],
            'use_bounds_min_as_origin' => !fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR),
            'face_validator' => fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_FACES, ACTION_OPTION_FACES_ONE) ? CommonDrawingDecompositionWorker::FACE_VALIDATOR_ONE : CommonDrawingDecompositionWorker::FACE_VALIDATOR_ALL,
            'ignore_edges' => !fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_EDGES),
            'edge_validator' => CommonDrawingDecompositionWorker::EDGE_VALIDATOR_STRAY_COPLANAR
          }).run
          if @active_drawing_def.is_a?(DrawingDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            projection_def = CommonDrawingProjectionWorker.new(@active_drawing_def, {
              'merge_holes' => fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_MERGE_HOLES)
            }).run

            preview = Kuix::Group.new
            preview.transformation = @active_drawing_def.transformation
            @space.append(preview)

            fn_append_segments = lambda do |layer_def, polygon_def, segs, line_width|

              segments = Kuix::Segments.new
              segments.add_segments(segs)
              if layer_def.upper?
                segments.color = COLOR_PART_UPPER
              elsif layer_def.holes?
                segments.color = COLOR_PART_HOLES
              else
                segments.color = COLOR_PART_DEPTH
              end
              segments.line_width = highlighted ? line_width + 1 : line_width
              segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES unless polygon_def.outer?
              segments.on_top = true
              preview.append(segments)

            end

            projection_def.layer_defs.reverse.each do |layer_def| # reverse layer order to present from Bottom to Top

              layer_def.polygon_defs.each do |polygon_def|
                if fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
                  polygon_def.loop_def.portions.each do |portion|
                    fn_append_segments.call(layer_def, polygon_def, portion.segments, portion.is_a?(Geometrix::ArcLoopPortionDef) ? 4 : 2)
                  end
                else
                  fn_append_segments.call(layer_def, polygon_def, polygon_def.segments, 2)
                end

              end
            end

            @active_drawing_def.edge_manipulators.each do |edge_manipulator|

              # Highlight edge
              segments = Kuix::Segments.new
              segments.add_segments(edge_manipulator.segment)
              segments.color = COLOR_EDGE
              segments.line_width = highlighted ? 3 : 2
              segments.on_top = true
              preview.append(segments)

            end

            bounds = Geom::BoundingBox.new
            bounds.add(Geom::Point3d.new(@active_drawing_def.bounds.min.x, @active_drawing_def.bounds.min.y, @active_drawing_def.bounds.max.z))
            bounds.add(@active_drawing_def.bounds.max)
            bounds.add(Geom::Point3d.new(0, 0, @active_drawing_def.bounds.max.z))

            # Box helper
            box_helper = Kuix::RectangleMotif.new
            box_helper.bounds.origin.copy!(bounds.min)
            box_helper.bounds.size.copy!(bounds)
            box_helper.bounds.apply_offset(inch_offset, inch_offset, 0)
            box_helper.color = Kuix::COLOR_BLACK
            box_helper.line_width = 1
            box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            preview.append(box_helper)

            if @active_drawing_def.input_edge_manipulator

              # Highlight input edge
              segments = Kuix::Segments.new
              segments.add_segments(@active_drawing_def.input_edge_manipulator.segment)
              segments.color = COLOR_ACTION
              segments.line_width = 3
              segments.on_top = true
              preview.append(segments)

            end

            # Axes helper
            axes_helper = Kuix::AxesHelper.new
            axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, @active_drawing_def.bounds.max.z))
            axes_helper.box_0.visible = false
            axes_helper.box_z.visible = false
            preview.append(axes_helper)

          end

        end

      else

        @active_drawing_def = nil

      end

    end

    def _set_active_face(face_path, face, highlighted = false)
      super

      if face

        @active_drawing_def = CommonDrawingDecompositionWorker.new(@input_face_path, {
          'use_bounds_min_as_origin' => true,
          'input_face_path' => @input_face_path,
          'input_edge_path' => @input_edge.nil? ? nil : @input_face_path + [ @input_edge ],
        }).run
        if @active_drawing_def.is_a?(DrawingDef)

          projection_def = CommonDrawingProjectionWorker.new(@active_drawing_def).run

          inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

          preview = Kuix::Group.new
          preview.transformation = @active_drawing_def.transformation
          @space.append(preview)

          fn_append_segments = lambda do |layer_def, polygon_def, segs, line_width|

            segments = Kuix::Segments.new
            segments.add_segments(segs)
            segments.color = COLOR_PART_UPPER
            segments.line_width = highlighted ? line_width + 1 : line_width
            segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES unless polygon_def.outer?
            segments.on_top = true
            preview.append(segments)

          end

          projection_def.layer_defs.reverse.each do |layer_def| # reverse layer order to present from Bottom to Top
            layer_def.polygon_defs.each do |polygon_def|

              if fetch_action_option_enabled(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
                polygon_def.loop_def.portions.each do |portion|
                  fn_append_segments.call(layer_def, polygon_def, portion.segments, portion.is_a?(Geometrix::ArcLoopPortionDef) ? 4 : 2)
                end
              else
                fn_append_segments.call(layer_def, polygon_def, polygon_def.segments, 2)
              end

            end
          end

          bounds = Geom::BoundingBox.new
          bounds.add(Geom::Point3d.new(@active_drawing_def.bounds.min.x, @active_drawing_def.bounds.min.y, @active_drawing_def.bounds.max.z))
          bounds.add(@active_drawing_def.bounds.max)
          bounds.add(Geom::Point3d.new(0, 0, @active_drawing_def.bounds.max.z))

          # Box helper
          box_helper = Kuix::RectangleMotif.new
          box_helper.bounds.origin.copy!(bounds.min)
          box_helper.bounds.size.copy!(bounds)
          box_helper.bounds.apply_offset(inch_offset, inch_offset, 0)
          box_helper.color = Kuix::COLOR_BLACK
          box_helper.line_width = 1
          box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          preview.append(box_helper)

          if @active_drawing_def.input_edge_manipulator

            # Highlight input edge
            segments = Kuix::Segments.new
            segments.add_segments(@active_drawing_def.input_edge_manipulator.segment)
            segments.color = COLOR_ACTION
            segments.line_width = 3
            segments.on_top = true
            preview.append(segments)

          end

          # Axes helper
          axes_helper = Kuix::AxesHelper.new
          axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, @active_drawing_def.bounds.max.z))
          axes_helper.box_0.visible = false
          axes_helper.box_z.visible = false
          preview.append(axes_helper)

        end

      else

        @active_edge = nil

      end

    end

    def _set_active_context(context_path, highlighted = false)
      super

      if context_path

        @active_drawing_def = CommonDrawingDecompositionWorker.new(context_path, {
          'ignore_faces' => true,
          'use_bounds_min_as_origin' => true,
          'input_face_path' => @input_face_path,
          'input_edge_path' => @input_face_path ? @input_edge_path : nil,
          'edge_validator' => CommonDrawingDecompositionWorker::EDGE_VALIDATOR_COPLANAR
        }).run
        if @active_drawing_def.is_a?(DrawingDef)

          inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

          preview = Kuix::Group.new
          preview.transformation = @active_drawing_def.transformation
          @space.append(preview)

            @active_drawing_def.edge_manipulators.each do |edge_info|

              # Highlight edge
              segments = Kuix::Segments.new
              segments.add_segments(EdgeManipulator.new(edge_info.edge, edge_info.transformation).segment)
              segments.color = COLOR_EDGE
              segments.line_width = highlighted ? 3 : 2
              segments.on_top = true
              preview.append(segments)

            end

            bounds = Geom::BoundingBox.new
            bounds.add(Geom::Point3d.new(@active_drawing_def.bounds.min.x, @active_drawing_def.bounds.min.y, @active_drawing_def.bounds.max.z))
            bounds.add(@active_drawing_def.bounds.max)
            bounds.add(Geom::Point3d.new(0, 0, @active_drawing_def.bounds.max.z))

            # Box helper
            box_helper = Kuix::RectangleMotif.new
            box_helper.bounds.origin.copy!(bounds.min)
            box_helper.bounds.size.copy!(bounds)
            box_helper.bounds.apply_offset(inch_offset, inch_offset, 0)
            box_helper.color = Kuix::COLOR_BLACK
            box_helper.line_width = 1
            box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            preview.append(box_helper)

            if @active_drawing_def.input_edge_manipulator

              # Highlight input edge
              segments = Kuix::Segments.new
              segments.add_segments(@active_drawing_def.input_edge_manipulator.segment)
              segments.color = COLOR_ACTION
              segments.line_width = 3
              segments.on_top = true
              preview.append(segments)

            end

            # Axes helper
            axes_helper = Kuix::AxesHelper.new
            axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, @active_drawing_def.bounds.max.z))
            axes_helper.box_0.visible = false
            axes_helper.box_z.visible = false
            preview.append(axes_helper)

        end

      end

    end

    # -----

    private

    def _handle_mouse_event(event = nil)
      if event == :move

        if @input_face_path

          # Check if face is not curved
          if (is_action_export_part_2d? || is_action_export_face?) && @input_face.edges.index { |edge| edge.soft? }
            _reset_active_part
            show_tooltip("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_flat_face')}", MESSAGE_TYPE_ERROR)
            push_cursor(@cursor_select_error)
            return
          end

          if is_action_export_part_3d? || is_action_export_part_2d?

            input_part_entity_path = _get_part_entity_path_from_path(@input_face_path)
            if input_part_entity_path

              if Sketchup.active_model.active_path

                diff = Sketchup.active_model.active_path - input_part_entity_path
                unless diff.empty?
                  _reset_active_part
                  show_tooltip("⚠ Pas exportable", MESSAGE_TYPE_ERROR)
                  push_cursor(@cursor_select_error)
                  return
                end

              end

              part = _generate_part_from_path(input_part_entity_path)
              if part
                _set_active_part(input_part_entity_path, part)
                show_tooltip(_get_active_part_name)
              else
                _reset_active_part
                show_tooltip("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_part')}", MESSAGE_TYPE_ERROR)
                push_cursor(@cursor_select_error)
              end
              return

            else
              _reset_active_part
              show_tooltip("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_part')}", MESSAGE_TYPE_ERROR)
              push_cursor(@cursor_select_error)
              return
            end

          elsif is_action_export_face?

            _set_active_face(@input_face_path, @input_face)
            return

          elsif is_action_export_edges?

            _set_active_context(@input_context_path)
            return

          end

        elsif @input_edge_path

          if is_action_export_edges?
            _set_active_context(@input_context_path)
            return

          end

        end
        _reset_active_part  # No input
        _reset_active_face  # No input

      elsif event == :l_button_down

        if is_action_export_part_3d?
          _refresh_active_part(true)
        elsif is_action_export_part_2d?
          _refresh_active_part(true)
        elsif is_action_export_face?
          _refresh_active_face(true)
        elsif is_action_export_edges?
          _refresh_active_edge(true)
        end

      elsif event == :l_button_up || event == :l_button_dblclick

        if is_action_export_part_3d?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = _get_active_part_name(true)
          file_format = fetch_action_option_value(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT)
          unit = fetch_action_option_value(ACTION_EXPORT_PART_3D, ACTION_OPTION_UNIT)

          worker = CommonWriteDrawing3dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

          # Focus SketchUp
          Sketchup.focus if Sketchup.respond_to?(:focus)

        elsif is_action_export_part_2d?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = _get_active_part_name(true)
          file_format = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT)
          unit = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_UNIT)
          anchor = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR) && (@active_drawing_def.bounds.min.x != 0 || @active_drawing_def.bounds.min.y != 0)    # No anchor if = (0, 0, z)
          smoothing = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
          merge_holes = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_MERGE_HOLES)
          parts_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_stroke_color')
          parts_fill_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_fill_color')
          parts_holes_fill_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_holes_fill_color')
          parts_holes_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_holes_stroke_color')
          edges_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'edges_stroke_color')

          worker = CommonWriteDrawing2dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit,
            'anchor' => anchor,
            'smoothing' => smoothing,
            'merge_holes' => merge_holes,
            'parts_stroke_color' => parts_stroke_color,
            'parts_fill_color' => parts_fill_color,
            'parts_holes_fill_color' => parts_holes_fill_color,
            'parts_holes_stroke_color' => parts_holes_stroke_color,
            'edges_stroke_color' => edges_stroke_color
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

          # Focus SketchUp
          Sketchup.focus if Sketchup.respond_to?(:focus)

        elsif is_action_export_face?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = 'FACE'
          file_format = fetch_action_option_value(ACTION_EXPORT_FACE, ACTION_OPTION_FILE_FORMAT)
          unit = fetch_action_option_value(ACTION_EXPORT_FACE, ACTION_OPTION_UNIT)
          smoothing = fetch_action_option_value(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
          parts_stroke_color = fetch_action_option_value(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, 'parts_stroke_color')
          parts_fill_color = fetch_action_option_value(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, 'parts_fill_color')

          worker = CommonWriteDrawing2dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit,
            'smoothing' => smoothing,
            'parts_stroke_color' => parts_stroke_color,
            'parts_fill_color' => parts_fill_color
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

          # Focus SketchUp
          Sketchup.focus if Sketchup.respond_to?(:focus)

        elsif is_action_export_edges?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = 'EDGES'
          file_format = fetch_action_option_value(ACTION_EXPORT_EDGES, ACTION_OPTION_FILE_FORMAT)
          unit = fetch_action_option_value(ACTION_EXPORT_EDGES, ACTION_OPTION_UNIT)
          smoothing = fetch_action_option_value(ACTION_EXPORT_EDGES, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
          edges_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'edges_stroke_color')

          worker = CommonWriteDrawing2dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit,
            'smoothing' => smoothing,
            'edges_stroke_color' => edges_stroke_color
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

          # Focus SketchUp
          Sketchup.focus if Sketchup.respond_to?(:focus)

        end

      end

    end

  end

end