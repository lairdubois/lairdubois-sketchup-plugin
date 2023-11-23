module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/svg_writer_helper'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../utils/color_utils'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../worker/common/common_drawing_projection_worker'

  class CommonExportDrawing2dWorker

    include DxfWriterHelper
    include SvgWriterHelper
    include SanitizerHelper

    LAYER_PART = 'OCL_PART'.freeze
    LAYER_GUIDE = 'OCL_GUIDE'.freeze
    LAYER_ANCHOR = 'OCL_ANCHOR'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_SVG, FILE_FORMAT_DXF ]

    def initialize(drawing_def, settings = {})

      @drawing_def = drawing_def

      @file_name = _sanitize_filename(settings.fetch('file_name', 'FACE'))
      @file_format = settings.fetch('file_format', nil)
      @unit = settings.fetch('unit', nil)
      @anchor = settings.fetch('anchor', false)
      @smoothing = settings.fetch('smoothing', false)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'default.error' ] } unless @drawing_def.is_a?(DrawingDef)

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('core.savepanel.export_to_file', { :file_format => @file_format.upcase }), '', "#{@file_name}.#{@file_format}")
      if path

        # Force "file_format" file extension
        unless path.end_with?(".#{@file_format}")
          path = "#{path}.#{@file_format}"
        end

        begin

          _write_to_path(path)

          return { :export_path => path }
        rescue => e
          puts e.inspect
          puts e.backtrace
          return { :errors => [ [ 'core.error.failed_export_to', { :path => path, :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

    # -----

    private

    def _write_to_path(path)

      # Compute projection
      projection_def = CommonDrawingProjectionWorker.new(@drawing_def, {
        'down_to_top_union' => true,
        'passthrough_holes' => true
      }).run

      # Open output file
      file = File.new(path , 'w')

      case @file_format
      when FILE_FORMAT_SVG
        _write_to_svg_file(file, projection_def, @drawing_def.edge_manipulators)
      when FILE_FORMAT_DXF
        _write_to_dxf_file(file, projection_def, @drawing_def.edge_manipulators)
      end

      # Close output file
      file.close

    end

    def _write_to_svg_file(file, projection_def, edge_manipulators)

      if @anchor
        # Recompute bounding box to be sure to extends to anchor triangle
        bounds = Geom::BoundingBox.new
        bounds.add(@drawing_def.bounds.min)
        bounds.add(@drawing_def.bounds.max)
        bounds.add([ Geom::Point3d.new, Geom::Point3d.new(0, 10.mm), Geom::Point3d.new(5.mm, 0) ])
      else
        bounds = @drawing_def.bounds
      end

      unit_sign, unit_transformation = _svg_get_unit_sign_and_transformation(@unit)

      origin = Geom::Point3d.new(
        bounds.min.x,
        -(bounds.height + bounds.min.y)
      ).transform(unit_transformation)
      size = Geom::Point3d.new(
        bounds.width,
        bounds.height
      ).transform(unit_transformation)

      x = _svg_value(origin.x)
      y = _svg_value(origin.y)
      width = _svg_value(size.x)
      height = _svg_value(size.y)

      _svg_write_start(file, x, y, width, height, unit_sign)

      unless projection_def.layer_defs.empty?

        _svg_write_group_start(file, id: LAYER_PART)

        _svg_write_projection_def(file, projection_def, @smoothing, unit_transformation, unit_transformation, unit_sign, nil, '#000000')

        _svg_write_group_end(file)

      end

      unless edge_manipulators.empty?

        _svg_write_group_start(file, id: LAYER_GUIDE)

        data = ''
        edge_manipulators.each do |edge_manipulator|

          data += "M #{edge_manipulator.points.each.map { |point| "#{point.transform(unit_transformation).to_a[0..1].join(',')}" }.join(' L')}"

        end

        _svg_write_tag(file, 'path', {
          d: data,
          stroke: '#0068FF',
          fill: 'none',
          'shaper:cutType': 'guide'
        })

        _svg_write_group_end(file)

      end

      if @anchor

        size = Geom::Point3d.new(
          5.mm,
          10.mm
        ).transform(unit_transformation)

        x1 = 0
        y1 = 0
        x2 = 0
        y2 = -size.y.to_f
        x3 = size.x.to_f
        y3 = 0

        _svg_write_group_start(file, id: LAYER_ANCHOR)
        _svg_write_tag(file, 'polygon', {
          points: "#{x1},#{y1} #{x2},#{y2} #{x3},#{y3}",
          fill: '#FF0000'
        })
        _svg_write_group_end(file)

      end

      _svg_write_end(file)

    end

    def _write_to_dxf_file(file, projection_def, edge_manipulators)

      unit_transformation = _dxf_get_unit_transformation(@unit)

      layer_defs = []
      layer_defs.push({ :name => LAYER_PART, :color => 7 }) unless projection_def.layer_defs.empty?
      layer_defs.push({ :name => LAYER_GUIDE, :color => 150 }) unless edge_manipulators.empty?

      min = @drawing_def.bounds.min.transform(unit_transformation)
      max = @drawing_def.bounds.max.transform(unit_transformation)
      block_name = 'PART'

      _dxf_write_start(file)
      _dxf_write_section_header(file, @unit, min, max)
      _dxf_write_section_classes(file)
      _dxf_write_section_tables(file, min, max, layer_defs) do |owner_id|

        _dxf_write_projection_def_block_record(file, projection_def, block_name, owner_id)

      end
      _dxf_write_section_blocks(file) do

        _dxf_write_projection_def_block(file, projection_def, block_name, @smoothing, unit_transformation, LAYER_PART) do

          edge_manipulators.each do |edge_manipulator|

            start_point = edge_manipulator.start_point.transform(unit_transformation)
            end_point = edge_manipulator.end_point.transform(unit_transformation)

            x1 = start_point.x
            y1 = start_point.y
            x2 = end_point.x
            y2 = end_point.y

            _dxf_write_line(file, x1, y1, x2, y2, LAYER_GUIDE)

          end

        end

      end
      _dxf_write_section_entities(file) do

        _dxf_write_insert(file, block_name)

      end
      _dxf_write_section_objects(file)
      _dxf_write_end(file)

    end

  end

end