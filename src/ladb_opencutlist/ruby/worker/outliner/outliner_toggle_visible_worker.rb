module Ladb::OpenCutList

  class OutlinerToggleVisibleWorker

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

      entity = node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?

      # Start model modification operation
      model.start_operation('OCL Outliner Toggle Visible', true, false, false)


      entity.visible = !entity.visible?


      # Commit model modification operation
      model.commit_operation

      { :visible => entity.visible? }
    end

    # -----

  end

end