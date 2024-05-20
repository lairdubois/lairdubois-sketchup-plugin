module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../attributes/definition_attributes'

  class AbstractOutlinerNode

    include DefHelper
    include HashableHelper

    attr_reader :id, :depth, :type, :name, :default_name, :locked, :computed_locked, :visible, :computed_visible, :expanded, :expandable, :child_active, :active, :selected, :children

    def initialize(_def)
      @_def = _def

      @id = _def.id
      @depth = _def.depth
      @type = _def.type

      @name = _def.name
      @default_name = _def.default_name

      @locked = _def.locked?
      @computed_locked = _def.computed_locked?
      @visible = _def.visible?
      @computed_visible = _def.computed_visible?
      @expanded = _def.expanded
      @expandable = _def.expandable?
      @child_active = _def.child_active
      @active = _def.active
      @selected = _def.selected

      @children = _def.expanded || _def.child_active || _def.active ? _def.children.map { |node_def| node_def.get_hashable } : []

    end

  end

  class OutlinerNodeModel < AbstractOutlinerNode

    attr_reader :description

    def initialize(_def)
      super

      @description = _def.entity.description

    end

  end

  class OutlinerNodeGroup < AbstractOutlinerNode

    attr_reader :material, :layer

    def initialize(_def)
      super

      @material = _def.material_def ? _def.material_def.get_hashable : nil
      @layer = _def.layer_def ? _def.layer_def.get_hashable : nil

      # @description = "G=#{_def.entity.object_id} entityID=#{_def.entity.entityID} guid=#{_def.entity.guid} persistent_id=#{_def.entity.persistent_id} D=#{_def.entity.definition.object_id} "

    end

  end

  class OutlinerNodeComponent < OutlinerNodeGroup

    attr_reader :definition_name, :description, :url, :tags

    def initialize(_def)
      super

      @default_name = _def.default_name
      @definition_name = _def.definition_name
      @description = _def.description

      definition_attributes = DefinitionAttributes.new(_def.entity.definition)
      @url = definition_attributes.url
      @tags = definition_attributes.tags

    end

  end

  class OutlinerNodePart < OutlinerNodeComponent

    def initialize(_def)
      super
    end

  end

end