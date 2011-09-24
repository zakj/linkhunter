## Utilities

# Use Mustache-style templates.
_.templateSettings = {interpolate: /\{\{ *(.+?) *\}\}/g}


# A simple wrapper around `localStorage` to handle JSON conversion.
class Store

  constructor: (@name) ->
    store = localStorage.getItem(@name)
    @data = if store then JSON.parse(store) else {}

  save: (data) ->
    @data = data
    localStorage.setItem(@name, JSON.stringify(data))


# Sync to a `Store` object given as an attribute on the model or collection.
# The only method to support is `read`, to handle `Collection.fetch()`. Saves
# are managed directly by the `Store`.
Backbone.sync = (method, model, options) ->
  store = model.store or model.collection.store

  if method is 'read'
    resp = if model.id
      store.data[model.id]
    else
      _.values(store.data)
    if resp
      options.success(resp)
    else
      options.error('Record not found')
  else
    options.error('This backend is read-only')


## Options

# A simple class to wrap `localStorage` for retrieving options, and provide
# defaults.
class Options

  constructor: ->
    @service = localStorage.service or 'delicious'
    @username = localStorage.username
    @password = localStorage.password
    @firstRun = not @username?
    @validCredentials = localStorage.validCredentials is 'true'

  reload: ->
    @constructor()


# The options page itself.
class OptionsView extends Backbone.View
  el: $('#options')
  template: _.template($('#options-template').html())

  render: ->
    @el.html(@template(app.options))
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

  # Save the options.
  save: (event) =>
    localStorage.service = @$('[name=service]').val()
    localStorage.username = @$('[name=username]').val()
    localStorage.password = @$('[name=password]').val()
    # Reload the app to propagate the new options. Test whether the new
    # credentials are valid. If so, refresh the data. If not, warn the user.
    app.reload()
    $('h2').addClass('feedback').html('Checking credentials&hellip;')
    app.bookmarks.isAuthValid (valid) ->
      if valid
        localStorage.validCredentials = true
        $('h2').html('Updating data&hellip;')
        app.bookmarks.reload ->
          app.navigate('search', true)
      else
        localStorage.validCredentials = false
        $('h2').text('Unable to authenticate.')
    return false


## Models and collections

class Bookmark extends Backbone.Model


# Superclass for cloud bookmark service backends. To support a new backend, add
# a subclass defining `url`, `updateUrl`, `dataType` attributes and a
# `parseBookmarks` method.
class BookmarkCollection extends Backbone.Collection
  model: Bookmark
  store: new Store('bookmarks')
  maxResults: 10
  # Subclasses are expected to set these attributes. `url` is the API URL to
  # retrieve all bookmarks. `updateUrl` is the API URL to check the last update
  # timestamp. `dataType` is the data type `url` is expected to return.
  url: undefined
  updateUrl: undefined
  dataType: undefined
  # `parseBookmarks` takes a single argument: the jQuery-parsed data returned
  # from the query to `url`. It should return the data as an object containing
  # the bookmarks indexed by hash.
  parseBookmarks: undefined

  initialize: (options) ->
    @settings =
      username: options.username
      password: options.password
      error: (jqXHR, textStatus, errorThrown) ->
        console.log('error!', jqXHR, textStatus, errorThrown)  # TODO
    @fetch()
    if options.valid
      @reloadIfNeeded()

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

  # Test the given credentials. `callback` will be called with a single boolean
  # argument, `true` if the credentials seem correct.
  isAuthValid: (callback) ->
    settings = _.clone(@settings)
    settings.dataType = 'xml'
    settings.success = (data) ->
      callback(true)
    settings.error = (data) ->
      callback(false)
    $.ajax(@updateUrl, settings)

  # Update the local cache.
  reload: (callback) ->
    settings = _.clone(@settings)
    settings.dataType = @dataType
    settings.success = (data) =>
      @store.save(@parseBookmarks(data))
      @fetch()
      callback?()
    $.ajax(@url, settings)

  # Find the timestamp marking the most recent remote bookmarks update. The
  # callback will receive the timestamp as a string.
  lastUpdate: (callback) ->
    settings = _.clone(@settings)
    settings.dataType = 'xml'
    settings.success = (data) ->
      callback($(data).find('update').attr('time'))
    $.ajax(@updateUrl, settings)

  # Update the local cache only if the remote bookmarks have changed since the
  # last update.
  reloadIfNeeded: ->
    lastLocalUpdate = localStorage.lastUpdate or '0'
    @lastUpdate (lastRemoteUpdate) =>
      if lastLocalUpdate < lastRemoteUpdate
        @reload -> localStorage.lastUpdate = lastRemoteUpdate


# <http://pinboard.in/api>
class PinboardCollection extends BookmarkCollection
  url: 'https://api.pinboard.in/v1/posts/all?format=json'
  updateUrl: 'https://api.pinboard.in/v1/posts/update'
  dataType: 'json'

  parseBookmarks: (data) =>
    bookmarks = {}
    _.each data, (b) ->
      bookmarks[b.hash] =
        id: b.hash
        description: b.description
        href: b.href
        tags: b.tags
        time: b.time
    return bookmarks


# <http://www.delicious.com/help/api>
class DeliciousCollection extends BookmarkCollection
  url: 'https://api.del.icio.us/v1/posts/all'
  updateUrl: 'https://api.del.icio.us/v1/posts/update'
  dataType: 'xml'

  parseBookmarks: (data) =>
    bookmarks = {}
    $(data).find('post').each () ->
      post = $(this)
      hash = post.attr('hash')
      bookmarks[hash] =
        id: hash
        description: post.attr('description')
        href: post.attr('href')
        tags: post.attr('tag')
        time: post.attr('time')
    return bookmarks


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
  el: $('ul')

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


# The main application view. Handles the search input box and displays results.
class SearchView extends Backbone.View
  el: $('#search')

  initialize: (options) ->
    @listView = new BookmarksView
    @search = $('input')
    @bookmarks = options.bookmarks
    @bookmarks.bind('reset', @render)

  render: =>
    query = @search.val()
    if query.length < 2
      visible = @bookmarks.recent()
    else
      visible = @bookmarks.search(query)
      label = if visible.length is 1 then 'match' else 'matches'
    @listView.render(visible)
    return this

  events:
    'blur input': 'refocus'
    'keydown': 'keydown'

  # Restrict input focus to the search box.
  refocus: (event) =>
    _.defer(=> @search.focus())

  # Handle up/down/enter navigation of the selected item.
  keydown: (event) =>
    switch event.keyCode
      when 40 then @listView.selectNext()      # down arrow
      when 38 then @listView.selectPrevious()  # up arrow
      when 13 then @listView.visitSelected()   # enter
      # Update the filter and allow the event to propagate.
      else
        _.defer(@render)
        return true
    return false


class BookmarksApp extends Backbone.Router
  serviceCollections:
    'delicious': DeliciousCollection
    'pinboard': PinboardCollection

  initialize: ->
    @options = new Options
    # Use a dummy collection on the first run, to avoid complicated
    # machinations in SearchView.initialize.
    if @options.firstRun
      @bookmarks = new Backbone.Collection
    else
      @bookmarks = new @serviceCollections[@options.service]
        username: @options.username
        password: @options.password
        valid: @options.validCredentials
    @optionsView = new OptionsView unless @optionsView?
    @searchView = new SearchView(bookmarks: @bookmarks)

  # TODO: Ugh. There has to be a better way.
  reload: ->
    @initialize()

  routes:
    '': 'default'
    'search': 'search'
    'add': 'add'
    'options': 'editOptions'

  # Always show the options panel until we have enough data to search.
  default: ->
    if @options.validCredentials? and @options.validCredentials
      @search()
    else
      @editOptions()

  search: ->
    @optionsView.el.hide()
    @searchView.render().el.show()

  add: ->
    bookmarklet = "vendor/bookmarklets/#{@options.service}.js"
    chrome.tabs.executeScript(null, file: bookmarklet, -> window.close())

  editOptions: ->
    @searchView.el.hide()
    @optionsView.render().el.show()
