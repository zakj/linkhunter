# A quick re-implementation of thoughtbot's [Backbone-Support][] package that
# maps more closely to my usage.
# [Backbone-Support]: https://github.com/thoughtbot/backbone-support

#### ElementRouter
# A `Backbone.Router` used to show a single view at a time. Instances must have
# an `el` attribute, whose contents will be replaced with the rendered view
# each time `show(view)` is called. Any previous view's `tearDown` method will
# be called first, if one exists.
class @ElementRouter extends Backbone.Router
  # If your views use a different naming scheme for their tear down methods,
  # supply that name here.
  tearDownMethod: 'tearDown'

  show: (view) ->
    @currentView?[@tearDownMethod]?()
    @currentView = view
    $(@el).empty().append(view.render().el)


#### CompositeView
# A `Backbone.View` that is aware of its subviews and handles releasing memory
# via `tearDown` methods.
class @CompositeView extends Backbone.View

  constructor: (options) ->
    @bindings = []
    @children = []
    super(options)

  # This method should be called when finished with the view (instead of simply
  # removing `view.el`). It removes all bindings created with `bindTo`, calls
  # `tearDown` on each of its children, and removes itself from its parent view
  # (if any).
  tearDown: ->
    @trigger('leave')
    @unbind()
    _(@bindings).each (binding) ->
      binding.source.unbind(binding.event, binding.callback)
    @remove()
    _(@children).each (child) -> child.tearDown?()
    @parent?.removeChild?(this)

  # Remove the given `view` from the list of children.
  removeChild: (view) ->
    @children = _(@children).without(view)

  # Use `this.bindTo(source, ...)` instead of `source.bind(...)` to ensure
  # bindings are tracked and appropriately removed along with the view.
  bindTo: (source, event, callback) ->
    @bindings.push(source: source, event: event, callback: callback)
    source.bind(event, callback, this)

  # Add a new child view.
  addChild: (view) ->
    @children.push(view)
    view.parent = this
    view

  # Add a new child view and render it immediately. Return the child view's
  # `el` attribute. Convenient for adding and rendering a child in one fell
  # swoop; e.g., `this.$el.append(this.renderChild(new View))`.
  renderChild: (view) ->
    @addChild(view)
    view.render().el
