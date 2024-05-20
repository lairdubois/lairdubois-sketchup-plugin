module Ladb::OpenCutList

  class OutlinerEditWorker

    def initialize(outliner_def,

                   id:

    )

      @outliner_def = outliner_def

      @id = id

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node_def = @outliner_def.get_node_def_by_id(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def

      # Start model modification operation
      model.start_operation('OCL Outliner Edit', true, false, true)


      # Force groups in path to be unique
      if node_def.type != OutlinerNodeModelDef::TYPE_MODEL

        path_by_guid = node_def.path.map { |entity| entity.guid }
        path_by_unique = []
        entities = model.entities
        path_by_guid.each do |guid|
          entity = entities.find { |e| e.guid == guid }
          return { :errors => [ 'default.error' ] } if entity.nil?
          entity = entity.make_unique if entity.is_a?(Sketchup::Group)
          path_by_unique << entity
          entities = entity.definition.entities
        end

      end


      # Commit model modification operation
      model.commit_operation

    end

    # -----

  end

end