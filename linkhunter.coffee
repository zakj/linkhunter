# Use Mustache-style templates.
_.templateSettings = {interpolate: /\{\{ *(.+?) *\}\}/g}


## BookmarkView

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


## BookmarksView

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


## SearchView

# The main application view. Handles the search input box and displays results
# using a BookmarksView.
class SearchView extends Backbone.View
  tagName: 'form'
  className: 'search'
  template: _.template($('#search-template').html())

  initialize: (options) ->
    @bookmarks = options.bookmarks
    @bookmarks.bind('reset', @updateResults)

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


## AddView

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
    $(@el).html(@template(app.config))
    oldTags = @$('fieldset.tags')
    @tagsView = new TagsView
      name: 'tags'
      placeholder: oldTags.find('input').attr('placeholder')
    oldTags.replaceWith(@tagsView.render().el)
    _.defer(=> @tagsView.input.focus())
    chrome.tabs.getSelected null, (tab) =>
      app.bookmarks.suggestTags? tab.url, (tags) =>
        @tagsView.addSuggested(tag) for tag in tags
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


## TagsView

# Handle adding/removing tags and displaying suggested tags.
class TagsView extends Backbone.View
  tagName: 'fieldset'
  template: _.template($('#tags-template').html())

  initialize: (options) ->
    @templateData =
      name: options.name
      value: options.value
      placeholder: options.placeholder
    @delimiter = options.delimiter or ' '

  render: ->
    $(@el).html(@template(@templateData))
    @input = @$('input')
    @tags = @$('ul.tags')
    @placeholder = @$('.placeholder')
    @suggestedTags = @$('ul.suggested-tags')
    _.defer(@fitInputToContents)
    return this

  events:
    'click .pseudo-input': 'focusInput'
    'keydown input': 'handleKeyDown'
    'keypress input': 'handleKeyPress'
    'blur input': 'extractTag'
    'click .tags li': 'removeTag'
    'click .suggested-tags li': 'addFromSuggested'

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

  # Handle a click on a suggested tag by adding the tag to the list. Set up a
  # click handler for the newly-added tag to restore visibility to the
  # suggested tag.
  addFromSuggested: (event) =>
    suggested = $(event.currentTarget)
    @add(suggested.hide().text()).click -> suggested.show()

  add: (tag) ->
    @placeholder.hide()
    $(@make('li', {}, tag)).appendTo(@tags)

  addSuggested: (tag) ->
    @suggestedTags.append(@make('li', {id: _.uniqueId()}, tag))

  # Emulate jQuery's `val` method; when passed a delimited list of tags, set
  # the tags list appropriate. When called with no argument, return the list of
  # tags as a delimited string.
  val: (tags) =>
    if tags?
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


## ConfigView

# The config panel.
class ConfigView extends Backbone.View
  tagName: 'div'
  className: 'config'
  template: _.template($('#config-template').html())

  render: ->
    $(@el).html(@template(app.config))
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

  # Save the config and update the view accordingly.
  save: (event) =>
    app.config.service = @$('[name=service]').val()
    app.config.username = @$('[name=username]').val()
    app.config.password = @$('[name=password]').val()
    app.loadCollection()
    $(@el).addClass('loading')
    $('h2').addClass('feedback').html('Inspecting your hunting license&hellip;')
    app.config.checkCredentials (valid) =>
      app.config.save()
      if valid
        $('h2').html('Rounding up your links&hellip;')
        app.bookmarks.fetch success: =>
          $(@el).removeClass('loading')
          app.navigate('search', true)
      else
        $('h2').text("Blast! Somethin' smells rotten.")
        $(@el).removeClass('loading')
    return false


## Main application router

class Linkhunter extends Backbone.Router

  # Build a collection, populate it from the local cache, and fire off a
  # request for updates in the background.
  initialize: ->
    @config = new Config
    @config.loaded.then =>
      @loadCollection().loaded.then => @bookmarks?.fetchIfStale()
      Backbone.history.start()
    @panel = $('#panel')

  loadCollection: ->
    @bookmarks = @config.createCollection()

  # Render `view` and make it visible, removing any previous view.
  show: (view) ->
    @currentView?.remove()
    @currentView = view
    @panel.html(view.render().el)

  routes:
    '': 'default'
    'search': 'search'
    'add': 'add'
    'config': 'editConfig'

  # Redirect to the config panel unless we have valid credentials.
  guard: (fn) ->
    if @config.validCredentials then fn() else app.navigate('config', true)

  default: ->
    @guard(-> app.navigate('search', true))

  search: ->
    @guard(=> @show(new SearchView(bookmarks: @bookmarks)))

  add: ->
    @guard(=> @show(new AddView))

  editConfig: ->
    @show(new ConfigView)
