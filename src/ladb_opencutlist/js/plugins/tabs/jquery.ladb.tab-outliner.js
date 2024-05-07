+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabOutliner = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.activeNode = null;
        this.selectedNodes = [];
        this.editedNode = null;
        this.lastEditNodeTab = null;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);

        this.$page = $('.ladb-page', this.$element);

        this.showHiddenInstances = true;

    };
    LadbTabOutliner.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabOutliner.DEFAULTS = {};

    // List /////

    LadbTabOutliner.prototype.generateOutliner = function (callback) {
        var that = this;

        this.rootNode = null;
        this.$page.empty();
        this.$btnGenerate.prop('disabled', true);
        this.setObsolete(false);

        window.requestAnimationFrame(function () {

            // Start progress feedback
            that.dialog.startProgress(1);

            rubyCallCommand('outliner_generate', {}, function (response) {

                var errors = response.errors;
                var warnings = response.warnings;
                var tips = response.tips;
                var filename = response.filename;
                var modelName = response.model_name;
                var root_node = response.root_node;
                var available_layers = response.available_layers;

                // Keep useful data
                that.rootNode = root_node;
                that.availableLayers = available_layers;

                var fn_set_parent = function (node, parent) {
                    node.parent = parent;
                    for (let i = 0; i < node.children.length; i++) {
                        fn_set_parent(node.children[i], node);
                    }
                };
                fn_set_parent(root_node, null);

                // Update filename
                that.$fileTabs.empty();
                that.$fileTabs.append(Twig.twig({ ref: "tabs/outliner/_file-tab.twig" }).render({
                    filename: filename,
                    modelName: modelName
                }));

                // Update page
                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "tabs/outliner/_list.twig" }).render({
                    capabilities: that.dialog.capabilities,
                    errors: errors,
                    warnings: warnings,
                    tips: tips,
                    root_node: root_node
                }));

                that.$tbody = $('#ladb_outliner_tbody', that.$page);

                that.refreshActivePath(function () {
                    that.refreshSelection(function () {
                        that.renderNodes();
                    });
                });

                var $toggleHiddenBtn = $('#ladb_btn_toggle_hidden')
                if (that.showHiddenInstances) {
                    $('i', $toggleHiddenBtn).addClass('ladb-opencutlist-icon-check-box-with-check-sign');
                }

                // Bind buttons
                $toggleHiddenBtn.on('click', function () {
                    $(this).blur();
                    that.showHiddenInstances = !that.showHiddenInstances;
                    if (that.showHiddenInstances) {
                        $('i', $(this)).addClass('ladb-opencutlist-icon-check-box-with-check-sign');
                    } else {
                        $('i', $(this)).removeClass('ladb-opencutlist-icon-check-box-with-check-sign');
                    }
                    that.renderNodes();
                    return false;
                });

                // Restore button state
                that.$btnGenerate.prop('disabled', false);

                // Stick header
                that.stickSlideHeader(that.$rootSlide);

                // Finish progress feedback
                that.dialog.finishProgress();

                // Callback
                if (typeof callback === 'function') {
                    callback();
                }

            });

        });

    };

    LadbTabOutliner.prototype.renderNodes = function () {
        var that = this;

        this.$tbody.empty();

        var fnRenderNode = function (node, activeOnly, parentLocked, parentVisible) {

            var layerVisible = true;
            if (node.layer) {
                layerVisible = node.layer.visible;
                if (layerVisible) {
                    for (const folder of node.layer.folders) {
                        layerVisible = layerVisible && folder.visible
                    }
                }
            }
            var visible = parentVisible && node.visible && layerVisible;

            if (!visible && !that.showHiddenInstances) {
                return;
            }

            var locked = parentLocked && node.locked;

            var $row = $(Twig.twig({ ref: "tabs/outliner/_list-row-node.twig" }).render({
                capabilities: that.dialog.capabilities,
                node: node,
                locked: locked,
                visible: visible,
                layerVisible: layerVisible
            }));
            that.$tbody.append($row);

            $row.on('click', function (e) {
                $(this).blur();
                $('.ladb-click-tool', $(this)).click();
                return false;
            });
            $('a.ladb-btn-node-toggle-folding', $row).on('click', function () {
                $(this).blur();

                node.expanded = !node.expanded;
                that.renderNodes();
                rubyCallCommand('outliner_set_expanded', {
                    id: node.id,
                    expanded: node.expanded
                });

                return false;
            });
            $('a.ladb-btn-node-select', $row).on('click', function () {
                $(this).blur();

                rubyCallCommand('outliner_select', { id: node.id }, function (response) {

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    } else {
                        that.refreshSelection();
                    }

                });

                return false;
            });
            $('a.ladb-btn-node-open-url', $row).on('click', function () {
                $(this).blur();
                rubyCallCommand('core_open_url', { url: $(this).attr('href') });
                return false;
            });
            $('a.ladb-btn-node-set-active', $row).on('click', function () {
                $(this).blur();
                var nodeId = $row.data('node-id');

                rubyCallCommand('outliner_set_active', { id: nodeId }, function (response) {

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    } else {

                    }

                });

                return false;
            });
            $('a.ladb-btn-node-toggle-visible', $row).on('click', function () {
                $(this).blur();

                node.visible = !node.visible;
                that.renderNodes();
                rubyCallCommand('outliner_set_visible', {
                    id: node.id,
                    visible: node.visible
                });

                return false;
            });
            $('a.ladb-btn-node-edit', $row).on('click', function () {
                $(this).blur();
                var nodeId = $row.data('node-id');
                that.editNode(nodeId);
                return false;
            });

            if (node.active) { activeOnly = false; }

            if (node.expanded || node.child_active || node.active) {
                for (const child of node.children) {
                    if (activeOnly && !child.child_active && !child.active) {
                        continue;
                    }
                    fnRenderNode(child, activeOnly, locked, visible);
                }
            }

        };
        fnRenderNode(this.rootNode, true, false, true);

        // Setup tooltips
        this.dialog.setupTooltips();

    }

    LadbTabOutliner.prototype.refreshActivePath = function (callback) {
        var that = this;

        rubyCallCommand('outliner_get_active', {}, function (response) {

            var fnPropagateUp = function (node, child_active) {
                if (node !== null) {
                    node.child_active = child_active
                    if (node.parent !== null) {
                        fnPropagateUp(node.parent, child_active);
                    }
                }
            }

            if (that.activeNode) {
                that.activeNode.active = false;
                fnPropagateUp(that.activeNode.parent, false);
            }

            var activeNode;
            if (response.node) {
                activeNode = that.findNodeById(response.node.id);
            }

            if (activeNode) {
                activeNode.active = true
                fnPropagateUp(activeNode.parent, true);
            }
            that.activeNode = activeNode;

            if (typeof callback === 'function') {
                callback();
            }

        });

    };

    LadbTabOutliner.prototype.refreshSelection = function (callback) {
        var that = this;

        rubyCallCommand('outliner_get_selection', {}, function (response) {

            for (const node of that.selectedNodes) {
                node.selected = false;
            }

            var selectedNodes = []
            if (response.nodes) {
                for (const n of response.nodes) {
                    let node = that.findNodeById(n.id);
                    if (node) {
                        node.selected = true;
                        selectedNodes.push(node);
                    }
                }
            }
            that.selectedNodes = selectedNodes;

            if (typeof callback === 'function') {
                callback();
            }

        });

    };

    LadbTabOutliner.prototype.editNode = function (id, tab) {
        var that = this;

        var node = this.findNodeById(id);
        if (node) {

            if (tab === undefined) {
                tab = this.lastEditNodeTab;
            }
            if (tab === null || tab.length === 0) {
                tab = 'general';
            }
            this.lastEditNodeTab = tab;

            // Keep the edited node
            this.editedNode = node;

            var $modal = this.appendModalInside('ladb_outliner_modal_edit', 'tabs/outliner/_modal-edit.twig', {
                capabilities: that.dialog.capabilities,
                mass_unit_strippedname: that.massUnitStrippedname,
                length_unit_strippedname: that.lengthUnitStrippedname,
                node: node,
                tab: tab,
            });

            // Fetch UI elements
            var $tabs = $('.modal-header a[data-toggle="tab"]', $modal);
            var $inputName = $('#ladb_outliner_node_input_name', $modal);
            var $inputDefinitionName = $('#ladb_outliner_node_input_definition_name', $modal);
            var $inputLayerName = $('#ladb_outliner_node_input_layer_name', $modal);
            var $inputDescription = $('#ladb_outliner_node_input_description', $modal);
            var $inputUrl = $('#ladb_outliner_node_input_url', $modal);
            var $inputTags = $('#ladb_outliner_node_input_tags', $modal);
            var $btnExplode = $('#ladb_outliner_node_explode', $modal);
            var $btnUpdate = $('#ladb_outliner_node_update', $modal);

            // Bind tabs
            $tabs.on('shown.bs.tab', function (e) {
                that.lastEditNodeTab = $(e.target).attr('href').substring('#tab_edit_node_'.length);
            });

            // Bind input
            $inputName.ladbTextinputText();
            $inputDefinitionName.ladbTextinputText();
            $inputLayerName.ladbTextinputText({
                autocomplete: {
                    source: that.availableLayers.map(function (layer) { return {
                        value: layer.name,
                        category: layer.path.join(' / '),
                        icon: 'fill',
                        color: layer.color
                    } }),
                    delay: 0,
                    minLength: 0,
                    categoryIcon: 'folder'
                }
            });
            $inputDescription.ladbTextinputArea();
            $inputUrl.ladbTextinputUrl();
            $inputTags.ladbTextinputTokenfield({
                unique: true
            });

            // Bind buttons
            $btnExplode.on('click', function () {

                var names = [];
                if (that.editedNode.name) {
                    names.push(that.editedNode.name);
                }
                if (that.editedNode.definition_name) {
                    var definitionName = that.editedNode.definition_name
                    if (that.editedNode.type === 2 || that.editedNode.type === 3) {   // 2 = TYPE_COMPONENT, 3 = TYPE_PART
                        definitionName = '<' + definitionName + '>'
                    }
                    names.push(definitionName);
                }

                that.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.outliner.edit_node.explode_message', { name: names.join(' ') }), function () {

                    rubyCallCommand('outliner_explode', { id: that.editedNode.id }, function (response) {

                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        } else {

                            // Reload the list
                            that.generateOutliner();

                            // Reset edited material
                            that.editedNode = null;

                            // Hide modal
                            $modal.modal('hide');

                        }

                    });

                }, {
                    confirmBtnType: 'danger',
                    confirmBtnLabel: i18next.t('tab.outliner.edit_node.explode')
                });

            });
            $btnUpdate.on('click', function () {

                var data = {
                    id: that.editedNode.id,
                    name: $inputName.val()
                }
                if ($inputDefinitionName.length > 0) {
                    data.definition_name = $inputDefinitionName.val();
                }
                if ($inputLayerName.length > 0) {
                    data.layer_name = $inputLayerName.val();
                }
                if ($inputDescription.length > 0) {
                    data.description = $inputDescription.val();
                }
                if ($inputUrl.length > 0) {
                    data.url = $inputUrl.val();
                }
                if ($inputTags.length > 0) {
                    data.tags = $inputTags.tokenfield('getTokensList').split(';')
                }

                rubyCallCommand('outliner_update', data, function (response) {

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    } else {

                        // Reload the list
                        var nodeId = that.editedNode.id;
                        that.generateOutliner(function() {
                            that.scrollSlideToTarget(null, $('[data-node-id=' + nodeId + ']', that.$page), false, true);
                        });

                        // Reset edited material
                        that.editedNode = null;

                        // Hide modal
                        $modal.modal('hide');

                    }

                });

            });

            // Show modal
            $modal.modal('show');

            // Setup tooltips & popovers
            this.dialog.setupTooltips();
            this.dialog.setupPopovers();

        } else {
            alert('Node not found (id=' + id + ')');
        }

    };

    // Internals /////

    LadbTabOutliner.prototype.findNodeById = function (id, parent) {
        if (parent === undefined) {
            parent = this.rootNode;
        }
        if (parent.id === id) {
            return parent;
        }
        for (var i = 0; i < parent.children.length; i++) {
            var node = this.findNodeById(id, parent.children[i]);
            if (node) {
                return node;
            }
        }
        return null;
    };

    LadbTabOutliner.prototype.showObsolete = function (messageI18nKey, forced) {
        if (!this.isObsolete() || forced) {

            var that = this;

            // Set tab as obsolete
            this.setObsolete(true);

            var $modal = this.appendModalInside('ladb_outliner_modal_obsolete', 'tabs/outliner/_modal-obsolete.twig', {
                messageI18nKey: messageI18nKey
            });

            // Fetch UI elements
            var $btnGenerate = $('#ladb_outliner_obsolete_generate', $modal);

            // Bind buttons
            $btnGenerate.on('click', function () {
                $modal.modal('hide');
                that.generateOutliner();
            });

            // Show modal
            $modal.modal('show');

        }
    };

    // Init ///

    LadbTabOutliner.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        var that = this;

        this.registerCommand('edit_node', function (parameters) {
            var nodeId = parameters.node_id;
            var tab = parameters.tab;
            window.requestAnimationFrame(function () {
                that.generateOutliner(function () {
                    that.editNode(nodeId, tab);
                });
            });
        });

    };

    LadbTabOutliner.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

        // Bind buttons
        this.$btnGenerate.on('click', function () {
            that.generateOutliner();
            this.blur();
        });

        // Events

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function (params) {
            that.showObsolete('core.event.model_change', true);
        });
        addEventCallback([ 'on_layer_changed', 'on_layer_removed', 'on_layers_folder_changed', 'on_layers_folder_removed', 'on_remove_all_layers' ], function (params) {
            that.showObsolete('core.event.layers_change', true);
        });
        addEventCallback([ 'on_selection_bulk_change', 'on_selection_cleared' ], function (params) {
            that.refreshSelection(function () { that.renderNodes(); });
        });
        addEventCallback([ 'on_active_path_changed' ], function (params) {
            that.refreshActivePath(function () { that.renderNodes(); });
        });

    };

    LadbTabOutliner.prototype.defaultInitializedCallback = function () {
        LadbAbstractTab.prototype.defaultInitializedCallback.call(this);

        this.generateOutliner();

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabOutliner.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabOutliner(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabOutliner;

    $.fn.ladbTabOutliner = Plugin;
    $.fn.ladbTabOutliner.Constructor = LadbTabOutliner;


    // NO CONFLICT
    // =================

    $.fn.ladbTabOutliner.noConflict = function () {
        $.fn.ladbTabOutliner = old;
        return this;
    }

}(jQuery);