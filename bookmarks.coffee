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
      # Search through both tags and description.
      s = m.get('tags') + m.get('description')
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

  parse: (resp) ->
    _.map $(resp).find('post'), (post) ->
      hash: post.getAttribute('hash')
      description: post.getAttribute('description')
      href: post.getAttribute('href')
      tags: post.getAttribute('tags')
      time: post.getAttribute('time')

  fetchIfUpdatedSince: (date) ->
    settings = _.extend _.clone(@settings),
      success: (data) =>
        @fetch() if _.date($(data).find('update').attr('time')) > date
    $.ajax(@updateUrl, settings)

  isAuthValid: (callback) ->
    settings = _.clone(@settings)
    settings.dataType = 'xml'
    settings.success = (data) ->
      callback(true)
    settings.error = (data) ->
      callback(false)
    $.ajax(@updateUrl, settings)


# <http://pinboard.in/api>
class PinboardCollection extends DeliciousCollection
  url: 'https://api.pinboard.in/v1/posts/all?format=json'
  updateUrl: 'https://api.pinboard.in/v1/posts/update'
  ajaxOptions: {}
  parse: (resp) -> resp


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
      chrome.tabs.create(url: @model.get('href'), selected: false)
    # Otherwise, open the link in the current tab and close the popup.
    else
      chrome.tabs.getSelected null, (tab) =>
        chrome.tabs.update(tab.id, url: @model.get('href'))
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


# The options panel.
class OptionsView extends Backbone.View
  tagName: 'form'
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
    bookmarklet = "vendor/bookmarklets/#{@options.service}.js"
    chrome.tabs.executeScript(null, file: bookmarklet, -> window.close())

  editOptions: ->
    @show(new OptionsView)
