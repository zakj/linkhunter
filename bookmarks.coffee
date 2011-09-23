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
    @service = localStorage.service or 'pinboard'
    @username = localStorage.username
    @password = localStorage.password


# The options page itself.
class OptionsView extends Backbone.View
  el: $('form.options')

  initialize: ->
    @service = @$('[name=service]')
    @username = @$('[name=username]')
    @password = @$('[name=password]')
    @render()

  render: ->
    options = new Options
    @service.filter("[value=#{options.service}]").attr('checked', true)
    @username.val(options.username)
    return this

  events:
    'submit': 'submit'

  submit: (event) =>
    newService = @service.filter(':checked').val()
    # Indicate that a refresh is needed if the service has changed.
    if newService isnt localStorage.service
      localStorage.service = newService
      localStorage.lastUpdate = '0'
    localStorage.username = @username.val()
    localStorage.password = @password.val() if @password.val()
    @render()


## Models and collections

class Bookmark extends Backbone.Model


# Superclass for cloud bookmark service backends. To support a new backend, add
# a subclass defining `url`, `updateUrl`, `dataType` attributes and a
# `parseBookmarks` method.
class BookmarkCollection extends Backbone.Collection
  model: Bookmark
  store: new Store('bookmarks')
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

  # Return a list of matching bookmarks.
  search: (query) =>
    re = new RegExp(query, 'i')
    tagMatches = @models.filter (m) ->
      _.any(m.get('tags').split(' '), (tag) -> re.test(tag))
    titleMatches = @models.filter (m) ->
      re.test(m.get('description'))
    # Present tag matches first, followed by title-only matches.
    _.union(tagMatches, titleMatches)

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
  template: _.template($('#bookmark-template').html() or '')

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
    @selected.removeClass('selected')
    @selected = item.addClass('selected')

  selectNext: =>
    next = @selected.next()
    @select(next) if next.length

  selectPrevious: =>
    previous = @selected.prev()
    @select(previous) if previous.length

  visitSelected: =>
    @selected.click()


# The main application view. Manages the bookmarks collection, searching, and
# keyboard input.
class SearchView extends Backbone.View
  el: $('form.search')

  initialize: (options) ->
    @listView = new BookmarksView
    @search = $('input')
    @feedback = $('.feedback')
    @bookmarks = options.bookmarks
    @bookmarks.bind('reset', @render)

  render: =>
    query = @search.val()
    if query.length < 2
      visible = @bookmarks.first(10)
      @feedback.text('10 recent')
    else
      visible = @bookmarks.search(query)
      label = if visible.length is 1 then 'match' else 'matches'
      @feedback.text("#{visible.length} #{label}")
    @listView.render(visible)

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
  collectionTypes:
    'delicious': DeliciousCollection
    'pinboard': PinboardCollection

  initialize: ->
    options = new Options
    @bookmarks = new @collectionTypes[options.service]
      username: options.username
      password: options.password
    @searchView = new SearchView(bookmarks: @bookmarks)
    @optionsView = new OptionsView
    @bookmarks.fetch()
    @bookmarks.reloadIfNeeded()

  routes:
    '': 'search'
    'add': 'add'
    'options': 'options'

  search: ->
    @searchView.render().el.show()
    @optionsView.el.hide()

  add: ->
    options = new Options
    bookmarklet = "vendor/bookmarklets/#{options.service}.js"
    chrome.tabs.executeScript(null, file: bookmarklet, -> window.close())

  options: ->
    @optionsView.render().el.show()
    @searchView.el.hide()
