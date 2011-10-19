## Utilities

# Use Mustache-style templates.
_.templateSettings = {interpolate: /\{\{ *(.+?) *\}\}/g}


# A simple wrapper around `localStorage` to handle JSON conversion.
class CollectionCache

  constructor: (@name) ->
    store = localStorage.getItem(@name)
    @models = if store then JSON.parse(store) else []
    @lastUpdated = _.date(localStorage.getItem('lastUpdated') or 0)

  save: (collection) =>
    @models = collection.models
    localStorage.setItem(@name, JSON.stringify(@models))

  update: (collection) =>
    @save(collection)
    @lastUpdated = _.date()
    localStorage.setItem('lastUpdated', @lastUpdated.date)


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

  # Handle re-adding an existing bookmark, or delegate to the superclass's
  # `add`.
  add: (model, options) ->
    # Detect an existing bookmark by matching the URL. If one exists, just
    # update it with the new model's attributes. Otherwise, add as usual.
    previous = @find (bookmark) -> model.get('url') is bookmark.get('url')
    if previous
      previous.set(model.attributes)
    else
      super(model, options)

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
      tags: post.getAttribute('tag')
      time: post.getAttribute('time')
      private: post.getAttribute('shared') is 'no'

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
          app.cache.save(this)
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
      private: post.shared is 'no'


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
    oldTagsInput = @$('[name=tags]')
    @tagsView = new TagInputView
      name: 'tags'
      placeholder: oldTagsInput.attr('placeholder')
    oldTagsInput.replaceWith(@tagsView.render().el)
    _.defer(=> @tagsView.input.focus())
    chrome.tabs.getSelected null, (tab) =>
      @$('.url .text').text(tab.url)
      @$('[name=url]').val(tab.url)
      @$('[name=title]').val(tab.title)
      previous = app.bookmarks.find (bookmark) ->
        bookmark.get('url') is tab.url
      if previous
        ago = _.date(previous.get('time')).fromNow()
        @$('h2').text("You added this link #{ago}.")
        @$('[name=title]').val(previous.get('title'))
        @tagsView.val(previous.get('tags'))
        @$('[name=private]').attr('checked', previous.get('private'))
    # TODO: suggest tags -- new view? tag.click adds to tags
    # TODO: tag autocomplete
    return this

  events:
    'click .url a': 'editUrl'
    'mouseover .url a': 'hoverEditUrl'
    'mouseout .url a': 'unhoverEditUrl'
    'submit': 'save'

  # Reveal the edit-url input, first sliding the fieldset "open". To increase
  # the height of the fieldset without affecting the layout of the rest of the
  # page elements, pull the fieldset out of the flow by positioning it
  # absolutely and increasing the padding of the following element to make up
  # for it.
  editUrl: (event) =>
    fieldset = @$('fieldset').first()
    fieldset.css
      position: 'absolute'
      top: fieldset.position().top
      height: fieldset.find('input').outerHeight() * 2 + (5 * 3)
    @$('.url').css
      paddingTop: fieldset.outerHeight(true) + 5
      visibility: 'hidden'
    fieldset.one 'webkitTransitionEnd', =>
      # Focus the input box, but ensure the beginning of the URL remains
      # visible (by default, focus puts the cursor at the end of the content).
      @$('.edit-url').show().find('input').get(0).setSelectionRange(0, 0)

  hoverEditUrl: (event) =>
    @$('.url a').addClass('hover')

  unhoverEditUrl: (event) =>
    @$('.url a').removeClass('hover')

  save: (event) =>
    @$('h2').html('&nbsp;')
    model =
      url: @$('[name=url]').val()
      title: @$('[name=title]').val()
      tags: @tagsView.val()
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


class TagInputView extends Backbone.View
  tagName: 'div'
  className: 'pseudo-input'

  initialize: (options) ->
    @name = options.name
    @value = options.value
    @placeholderText = options.placeholder
    @delimiter = options.delimiter or ' '

  render: ->
    @tags = $(@make('ul', class: 'tags'))
    @input = $(@make('input', name: @name, value: @value))
    @placeholder = $(@make('span', class: 'placeholder', @placeholderText))
    $(@el).append(@tags, @input, @placeholder)
    _.defer(@fitInputToContents)
    return this

  events:
    'click': 'focusInput'
    'keydown input': 'handleKeyDown'
    'keypress input': 'handleKeyPress'
    'blur input': 'extractTag'
    'click .tags li': 'removeTag'

  focusInput: (event) =>
    @input.focus()

  handleKeyDown: (event) =>
    # If a user presses backspace when the input box is empty, unextract the
    # last stored tag for editing.
    if event.keyCode is 8 and @input.val() is ''
      @unextractTag()
      return false
    # If a user presses enter in the input box, ensure any entered text is
    # extracted.
    if event.keyCode is 13
      @extractTag()
    # Defer resizing the input until its value has been updated for this
    # keypress. Calling fitInputToContents in a keyup handler makes more sense,
    # but this method reduces visual lag.
    _.defer(@fitInputToContents)

  # If a user presses the delimiter key, extract the tag rather than inserting
  # the delimiter.
  handleKeyPress: (event) =>
    if event.keyCode is @delimiter.charCodeAt(0)
      @extractTag(@input.get(0).selectionStart)
      return false

  # Extract `length` characters from the beginning of the input box into a new
  # tag object. If `length` is not given, extract the entire input.
  extractTag: (length) =>
    length = @input.val().length unless _.isNumber(length)
    tag = @input.val().slice(0, length).trim()
    if tag
      remainder = @input.val().slice(length).trim()
      @input.val(remainder)
      @add(tag)

  removeTag: (event) =>
    $(event.currentTarget).remove()

  add: (tag) ->
    @tags.append(@make('li', {}, tag))

  # Emulate jQuery's `val` method; when passed a delimited list of tags, set
  # the tags list appropriate. When called with no argument, return the list of
  # tags as a delimited string.
  val: (tags) =>
    if tags?
      @placeholder.hide() unless tags is ''
      @tags.empty()
      _.each tags.split(@delimiter), (tag) => @add(tag) if tag
    else
      _.map(@tags.children(), (tag) -> tag.textContent).join(@delimiter)

  # Remove the last tag from the tag list (if any) and place its value in the
  # input. Re-fit the input when done.
  unextractTag: ->
    tag = @tags.children().last().remove().text().trim()
    @input.val(tag)
    _.defer(@fitInputToContents)

  # Resize the input to just fit its contents, while remaining small enough to
  # fit inside its container. To calculate the content width, create a
  # temporary invisible div with the same class and contents and measure it.
  fitInputToContents: =>
    padding = 30
    @placeholder.hide() unless @input.val() is ''
    fake = $('<div/>').addClass('pseudo-input').css
      position: 'absolute'
      left: -9999
      top: -9999
      whiteSpace: 'nowrap'
      width: 'auto'
    fake.text(@input.val()).appendTo(@el)
    @input.css(width: Math.min(fake.width() + padding, $(@el).width()))
    fake.remove()


# The options panel.
class OptionsView extends Backbone.View
  tagName: 'div'
  className: 'options'
  template: _.template($('#options-template').html())

  render: ->
    $(@el).html(@template(app.options))
    @service = @$('#service')
    @serviceInput = @service.find('input')
    @knob = @service.find('.knob')
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
    @bookmarks?.bind('reset', @cache.update)

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
