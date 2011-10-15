## Utilities

# Use Mustache-style templates.
_.templateSettings = {interpolate: /\{\{ *(.+?) *\}\}/g}


# A simple wrapper around `localStorage` to handle JSON conversion.
class CollectionCache

  constructor: (@name) ->
    store = localStorage.getItem(@name)
    @models = if store then JSON.parse(store) else []
    @lastUpdated = _.date(localStorage.getItem('lastUpdated') or 0)

  save: ->
    localStorage.setItem(@name, JSON.stringify(@models))
    @lastUpdated = _.date()
    localStorage.setItem('lastUpdated', @lastUpdated.date)

  reset: (collection) =>
    @models = collection.models
    @save()


## Models and Collections

class Bookmark extends Backbone.Model

  defaults: ->
    'time': new Date

  # Since bookmarks are not backed by a `Backbone.sync`-friendly API, all saves
  # should happen through the `create` method of `BookmarkCollection`
  # subclasses.
  save: -> throw 'Use BookmarkCollection.create instead'


# Superclass for cloud bookmark service backends. Subclasses should set `url`
# and `parse` as usual for Backbone collections.
class BookmarkCollection extends Backbone.Collection
  model: Bookmark
  maxResults: 10

  # Subclasses should implement a `fetchIfUpdatedSince` method. It must accept
  # one _.date argument, and call `fetch` if the remote data has been updated
  # since that time.
  fetchIfUpdatedSince: -> throw 'Not implemented'
  # Subclasses should implement an `isAuthValid` method. It must accept one
  # callback argument, calling it with a boolean reporting whether the given
  # username and password are correct.
  isAuthValid: -> throw 'Not implemented'
  # Subclasses should implement a `create` method which takes a model (or
  # model-like object), creates it via the appropriate API calls, and adds it
  # to the collection.
  create: -> throw 'Not implemented'
  # Subclasses may set an ajaxOptions attribute, which will be passed to
  # `fetch`. This is mostly useful for controlling `dataType` in one place.
  ajaxOptions: {}

  initialize: (models, options) ->
    @settings = _.defaults options, @ajaxOptions,
      error: (jqXHR, textStatus, errorThrown) ->
        console.log('error!', jqXHR, textStatus, errorThrown)  # TODO

  # Sort by most-recent first.
  comparator: (bookmark) ->
    return - Date.parse(bookmark.get('time'))

  fetch: (options = {}) ->
    super(_.defaults(options, @settings))

  # Return a list of the most recent bookmarks.
  recent: (n = @maxResults) =>
    @first(n)

  # Return a list of matching bookmarks.
  search: (query) =>
    # Words in the query string are separated by whitespace and/or commas. A
    # bookmark must match all given words to be considered a valid result.
    regexps = (new RegExp(word, 'i') for word in query.split(/[, ]+/))
    # Limit the results to maxResults; abuse _.detect for this purpose because
    # there's no way to exit early from _.filter and there's no point
    # traversing thousands of bookmarks once we've already found maxResults.
    results = []
    @detect (m) =>
      # Search through both tags and title.
      s = m.get('tags') + m.get('title')
      results.push(m) if _.all(regexps, (re) -> re.test(s))
      return results.length >= @maxResults
    return results


# <http://www.delicious.com/help/api>
class DeliciousCollection extends BookmarkCollection
  idAttribute: 'hash'
  url: 'https://api.del.icio.us/v1/posts/all'
  ajaxOptions:
    dataType: 'xml'
  updateUrl: 'https://api.del.icio.us/v1/posts/update'
  addUrl: 'https://api.del.icio.us/v1/posts/add'

  parse: (resp) ->
    _.map resp.getElementsByTagName('post'), (post) ->
      hash: post.getAttribute('hash')
      title: post.getAttribute('description')
      url: post.getAttribute('href')
      tags: post.getAttribute('tags')
      time: post.getAttribute('time')

  fetchIfUpdatedSince: (date) ->
    settings = _.extend _.clone(@settings),
      success: (data) =>
        @fetch() if _.date($(data).find('update').attr('time')) > date
    $.ajax(@updateUrl, settings)

  isAuthValid: (callback) ->
    settings = _.extend _.clone(@settings),
      dataType: 'xml'
      success: (data) -> callback(true)
      error: (data) -> callback(false)
    $.ajax(@updateUrl, settings)

  create: (model, options) ->
    model = @_prepareModel(model)
    return false unless model
    data = model.toJSON()
    data.description = data.title
    data.shared = 'no' if data.private
    settings = _.extend _.clone(@settings),
      data: data
      success: (data) =>
        result = data.getElementsByTagName('result')[0].getAttribute('code')
        if result is 'done'
          @add(model)
          app.cache.reset(this)
          options.success?()
        else
          options.error?(result)
    settings.error = options.error if options.error?
    $.ajax(@addUrl, settings)
    return model


# <http://pinboard.in/api>
class PinboardCollection extends DeliciousCollection
  url: 'https://api.pinboard.in/v1/posts/all?format=json'
  updateUrl: 'https://api.pinboard.in/v1/posts/update'
  addUrl: 'https://api.pinboard.in/v1/posts/add'
  ajaxOptions: {}

  parse: (resp) ->
    _.map resp, (post) ->
      hash: post.hash
      url: post.href
      title: post.description
      tags: post.tags
      time: post.time


## Options

# A simple class to wrap `localStorage` to manage options with defaults.
class Options
  serviceCollections:
    'delicious': DeliciousCollection
    'pinboard': PinboardCollection

  constructor: ->
    # Use getters and setters for a simpler interface.
    property = (name, fn) =>
      @__defineGetter__ name, fn
      @__defineSetter__ name, (value) -> localStorage.setItem(name, value)
    property 'service', -> localStorage.service or 'delicious'
    property 'username', -> localStorage.username
    property 'password', -> localStorage.password
    property 'firstRun', -> not localStorage.service?
    property 'validCredentials', -> localStorage.validCredentials is 'true'

  # Create a collection instance using the class defined by `service`.
  createCollection: (models = []) ->
    unless @firstRun
      new @serviceCollections[@service] models,
        username: @username
        password: @password
        valid: @validCredentials


## Views

# Display a single bookmark as a clickable element.
class BookmarkView extends Backbone.View
  tagName: 'li'
  template: _.template($('#bookmark-template').html())

  render: ->
    $(@el).html(@template(@model.toJSON()))
    return this

  events:
    'click': 'click'

  click: (event) =>
    # If cmd- or ctrl-clicked, open the link in a new background tab.
    if event.metaKey or event.ctrlKey
      chrome.tabs.create(url: @model.get('url'), selected: false)
    # Otherwise, open the link in the current tab and close the popup.
    else
      chrome.tabs.getSelected null, (tab) =>
        chrome.tabs.update(tab.id, url: @model.get('url'))
      window.close()
    return false


# Display a list of bookmarks and track the currently-selected one.
class BookmarksView extends Backbone.View

  render: (bookmarks) =>
    @el.html('')
    _.each(bookmarks, @append)
    @selected = @el.children().first().addClass('selected')
    return this

  append: (model) =>
    view = new BookmarkView(model: model)
    @el.append(view.render().el)

  events:
    'mouseover li': 'selectHovered'

  selectHovered: (event) =>
    @select($(event.currentTarget))

  select: (item) ->
    @selected?.removeClass('selected')
    @selected = item.addClass('selected')

  selectNext: =>
    next = @selected.next()
    @select(next) if next.length

  selectPrevious: =>
    previous = @selected.prev()
    @select(previous) if previous.length

  visitSelected: =>
    @selected.click()


# The main application view. Handles the search input box and displays results
# using a BookmarksView.
class SearchView extends Backbone.View
  tagName: 'form'
  className: 'search'
  template: _.template($('#search-template').html())

  initialize: (options) ->
    @bookmarks = options.bookmarks
    @bookmarks.bind('reset', @render)

  render: =>
    $(@el).html(@template())
    @resultsView = new BookmarksView(el: @$('ul'))
    @updateResults()
    return this

  updateResults: =>
    query = @$('input').val()
    visible = if query.length < 2
      @bookmarks.recent()
    else
      @bookmarks.search(query)
    @resultsView.render(visible)

  events:
    'blur input': 'refocus'
    'keydown': 'keydown'

  # Restrict input focus to the search box.
  refocus: (event) =>
    _.defer(=> @$('input').focus())

  # Handle up/down/enter navigation of the selected item.
  keydown: (event) =>
    switch event.keyCode
      when 40 then @resultsView.selectNext()      # down arrow
      when 38 then @resultsView.selectPrevious()  # up arrow
      when 13 then @resultsView.visitSelected()   # enter
      # Update the filter and allow the event to propagate.
      else
        _.defer(@updateResults)
        return true
    return false


# Add a new bookmark.
class AddView extends Backbone.View
  tagName: 'div'
  className: 'add'
  template: _.template($('#add-template').html())

  errorMessages:
    'default': 'You missed!'
    'ajax error': 'API service failure. What have you done?!'
    'missing url': 'Or not. Your URL blows.'

  render: ->
    $(@el).html(@template(app.options))
    chrome.tabs.getSelected null, (tab) =>
      @$('.url .text').text(tab.url)
      @$('[name=url]').val(tab.url)
      @$('[name=title]').val(tab.title)
    # TODO: suggest tags -- new view? tag.click adds to tags
    # TODO: indicate if this URL has already been bookmarked
    # TODO: tag autocomplete
    return this

  events:
    'click .url a': 'editUrl'
    'mouseover .url a': 'hoverEditUrl'
    'mouseout .url a': 'unhoverEditUrl'
    'submit': 'save'

  editUrl: (event) =>
    @$('.url').hide()
    @$('.edit-url').show()

  hoverEditUrl: (event) =>
    @$('.url a').addClass('hover')

  unhoverEditUrl: (event) =>
    @$('.url a').removeClass('hover')

  save: (event) =>
    @$('h2').html('&nbsp;')
    model =
      url: @$('[name=url]').val()
      title: @$('[name=title]').val()
      tags: @$('[name=tags]').val()
      private: @$('[name=private]').is(':checked')
    $(@el).addClass('loading')
    app.bookmarks.create model,
      success: =>
        $(@el).addClass('done')
        @$('h2').text('Bravo!')
        _.delay((-> window.close()), 750)
      error: (data) =>
        $(@el).removeClass('loading')
        data = 'ajax error' unless _.isString(data)
        msg = @errorMessages[data] or @errorMessages.default
        @$('h2').text(msg)
    return false


# The options panel.
class OptionsView extends Backbone.View
  tagName: 'div'
  className: 'options'
  template: _.template($('#options-template').html())

  render: ->
    $(@el).html(@template(app.options))
    @service = @$('#service')
    @serviceInput = @service.find('input')
    @nob = @service.find('.nob')
    return this

  events:
    'click #service a': 'chooseService'
    'click #service .switch': 'toggleService'
    'submit': 'save'

  chooseService: (event) =>
    choice = $(event.currentTarget).attr('class')
    @serviceInput.val(choice)
    @service.attr('class', choice)

  toggleService: (event) =>
    choice = if @service.attr('class') is 'pinboard' then 'delicious' else 'pinboard'
    @serviceInput.val(choice)
    @service.attr('class', choice)

  # Save the options and update the view accordingly.
  save: (event) =>
    app.options.service = @$('[name=service]').val()
    app.options.username = @$('[name=username]').val()
    app.options.password = @$('[name=password]').val()
    # Reload the app's collection and test whether the new credentials are
    # valid. If so, fetch the data. If not, warn the user.
    app.loadCollection()
    $(@el).addClass('loading')
    $('h2').addClass('feedback').html('Inspecting your hunting license&hellip;')
    app.bookmarks.isAuthValid (valid) =>
      if valid
        localStorage.validCredentials = true
        $('h2').html('Rounding up your links&hellip;')
        app.bookmarks.fetch success: =>
          $(@el).removeClass('loading')
          app.navigate('search', true)
      else
        localStorage.validCredentials = false
        $('h2').text("Blast! Somethin' smells rotten.")
        $(@el).removeClass('loading')
    return false


## Router

class BookmarksApp extends Backbone.Router

  # Build a collection, populate it from the local cache, and fire off a
  # request for updates in the background.
  initialize: ->
    @options = new Options
    @cache = new CollectionCache('bookmarks')
    @loadCollection()
    @bookmarks?.fetchIfUpdatedSince(@cache.lastUpdated)
    @panel = $('#panel')

  loadCollection: ->
    @bookmarks = @options.createCollection(@cache.models)
    @bookmarks?.bind('reset', @cache.reset)

  # Render `view` and make it visible, removing any previous view.
  show: (view) ->
    @currentView?.remove()
    @currentView = view
    @panel.html(view.render().el)

  routes:
    '': 'default'
    'search': 'search'
    'add': 'add'
    'options': 'editOptions'

  # Redirect to the options panel unless we have valid credentials.
  guard: (fn) ->
    if @options.validCredentials then fn() else app.navigate('options', true)

  default: ->
    @guard(-> app.navigate('search', true))

  search: ->
    @guard(=> @show(new SearchView(bookmarks: @bookmarks)))

  add: ->
    @guard(=> @show(new AddView))

  editOptions: ->
    @show(new OptionsView)
