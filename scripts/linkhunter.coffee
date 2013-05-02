# Shorten "a few seconds ago".
moment.relativeTime.s = 'moments'


## BookmarkView

# Display a single bookmark as a clickable element.
class BookmarkView extends CompositeView
  tagName: 'li'
  template: Handlebars.templates.bookmark

  render: ->
    data = @model.toJSON()
    domain = data.url.split('/')[2]
    data.favicon = "https://www.google.com/s2/favicons?domain=#{domain}"
    data.age = moment(data.time).fromNow()
    $(@el).html(@template(data))
    # Show the link's privacy status if it doesn't match the user's default.
    if app.config.private isnt @model.get('private')
      @el.className = 'show-privacy'
    return this

  events:
    'click': 'click'

  click: (event) =>
    # If cmd- or ctrl-clicked, open the link in a new background tab.
    if event.metaKey or event.ctrlKey
      browser.openBackgroundTab(@model.get('url'))
    # Otherwise, open the link in the current tab.
    else
      browser.openUrl(@model.get('url'))
    return false


## BookmarksView

# Display a list of bookmarks and track the currently-selected one.
class BookmarksView extends CompositeView

  initialize: ->
    @container = @el.parent('.results')

  render: (bookmarks) =>
    # Re-rendering is a waste if the contents are the same.
    return if _.isEqual(@previousBookmarks, bookmarks)
    @el.empty()
    # Rendering each bookmark takes only about 3ms, but at around ~100 that
    # stacks up enough to be a noticeable delay when opening the popup. As a
    # workaround, add enough to fill the popup immediately, and append the rest
    # a moment later. It's only useful to jump through this hoop the first
    # time, so subsequent renders handle all bookmarks at once.
    if not @previousBookmarks?
      # Make sure we keep hitting this path until our bookmarks collection has
      # been populated for the first time.
      return unless bookmarks.length > 0
      bookmarksPerPage = 9
      @append(_.first(bookmarks, bookmarksPerPage))
      _.delay((=> @append(_.rest(bookmarks, bookmarksPerPage))), 50)
    else
      @append(bookmarks)
    @el.scrollTop(0)
    @selected = @el.children().first().addClass('selected')
    @container.toggleClass('empty', bookmarks.length is 0)
    @previousBookmarks = bookmarks
    return this

  append: (bookmarks) =>
    bookmarks = [bookmarks] unless _.isArray(bookmarks)
    frag = document.createDocumentFragment()
    _.each bookmarks, (bookmark) =>
      frag.appendChild(@renderChild(new BookmarkView(model: bookmark)))
    @el.append(frag)
    browser.resizePopup?()

  events:
    'mouseover li': 'selectHovered'

  selectHovered: (event) =>
    @select($(event.currentTarget)) unless @scrolling

  select: (item) ->
    @selected?.removeClass('selected')
    @selected = item.addClass('selected')

  selectNext: =>
    next = @selected.next()
    @scrollTo(next) if next.length

  selectPrevious: =>
    previous = @selected.prev()
    @scrollTo(previous) if previous.length

  scrollTo: (item) ->
    # To find the actual scrollTop value for the item, start with its document
    # offset, correct for scrolling, and correct for its parent placement.
    itemTop = item.offset().top + @el.scrollTop() - @el.offset().top
    # We want to keep the selected item in the middle of the scroll area where
    # possible, so don't scroll all the way to itemTop.
    position = itemTop - @el.height() / 2 + 25
    # Track that a scroll is happening so that we can safely ignore mouseover
    # events. Simply deferring @scrolling = false means that rapid calls to
    # this method can stack up resetting scrolling, so instead we reset
    # @scrolling only when this method hasn't been called for 100ms (more than
    # enough time for the scroll to happen, but probably not enough time for a
    # user to switch from keyboard to mouse navigation).
    @scrolling = true
    @el.scrollTop(position)
    (@finishScrolling or= _.debounce((=> @scrolling = false), 100))()
    @select(item)

  visitSelected: =>
    @selected.click()


## SearchView

# The main application view. Handles the search input box and displays results
# using a BookmarksView.
class SearchView extends CompositeView
  tagName: 'form'
  className: 'search'
  template: Handlebars.templates.search

  initialize: (options) ->
    @bookmarks = options.bookmarks
    @bindTo(@bookmarks, 'reset', @updateResults)
    @bindTo(@bookmarks, 'syncError', @showError)

  render: =>
    $(@el).html(@template())
    @resultsView = @addChild(new BookmarksView(el: @$('ul')))
    @updateResults()
    return this

  showError: (status) =>
    messages =
      0: 'sync_error_connect'
      401: 'sync_error_auth'
      429: 'sync_error_toomany'
    error = browser._(messages[status])
    error or= browser._('sync_error_default', status.toString())
    $(@el).addClass('show-error').find('.error').text(error)

  hideError: (event) =>
    $(@el).removeClass('show-error')

  # On escape keypress: clear the input box or, if it is already empty, close
  # the popup.
  escape: ->
    if @$('input').val() is ''
      app.close()
    else
      @clearInput()

  clearInput: ->
    @$('input').val('')
    @updateResults()

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
    'click .error': 'hideError'
    'click .button': 'buttonClick'

  # Restrict input focus to the search box.
  refocus: (event) =>
    _.defer(=> @$('input').focus())

  # Handle keyboard navigation and filter updates.
  keydown: (event) =>
    # Go straight to the add view on ⌘J.
    modifiers = (event.metaKey or event.ctrlKey)
    otherModifiers = (event.altKey or event.shiftKey)
    if modifiers and not otherModifiers and event.keyCode is 74
      app.navigate('add', true)
      return false
    switch event.keyCode
      when 40 then @resultsView.selectNext()      # down arrow
      when 38 then @resultsView.selectPrevious()  # up arrow
      when 13 then @resultsView.visitSelected()   # enter
      # Update the filter and allow the event to propagate.
      else
        _.defer(@updateResults)
        return true
    return false

  # For some reason, Safari popovers don't handle simple A element clicks
  # properly.
  buttonClick: (event) ->
    event.preventDefault()
    window.location.href = $(event.currentTarget).attr('href')


## AddView

# Add a new bookmark.
class AddView extends CompositeView
  tagName: 'div'
  className: 'add'
  template: Handlebars.templates.add

  render: ->
    $(@el).html(@template(app.config))
    oldTags = @$('fieldset.tags')
    @tagsView = new TagsView
      name: 'tags'
      placeholder: oldTags.find('input').attr('placeholder')
    oldTags.replaceWith(@renderChild(@tagsView))
    _.defer(=> @tagsView.input.focus())
    browser.getCurrentTabUrlAndTitle (url, title) =>
      app.bookmarks.suggestTags? url, (tags) =>
        @tagsView.addSuggested(tag) for tag in tags
      @$('.url .text').text(url)
      @$('[name=url]').val(url)
      @$('[name=title]').val(title)
      previous = app.bookmarks.find (bookmark) ->
        bookmark.get('url') is url
      if previous
        ago = moment(previous.get('time')).fromNow()
        @$('h2').text(browser._('add_already', ago))
        @$('[name=title]').val(previous.get('title'))
        @tagsView.val(previous.get('tags'))
        @$('[name=private]').attr('checked', previous.get('private'))
      browser.resizePopup?()
    return this

  # Handle escape keypress: return to the search view.
  escape: ->
    app.navigate('search', true)

  events:
    'click .url a': 'editUrl'
    'mouseover .url a': 'hoverEditUrl'
    'mouseout .url a': 'unhoverEditUrl'
    'submit': 'save'
    'click .close': 'escape'

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
    feedback = @$('.feedback')
    # To maintain vertical spacing, the element must always have content.
    feedback.html('&nbsp;')
    model =
      url: @$('[name=url]').val()
      title: @$('[name=title]').val()
      tags: @tagsView.val()
      private: @$('[name=private]').is(':checked')
    $(@el).addClass('loading')
    # If the API server is slow to respond, let the user know what's going on.
    slowResponse = ->
      feedback.text(browser._('add_slow', app.config.serviceName()))
    slowResponseTimeout = setTimeout(slowResponse, 1500)
    app.bookmarks.create model,
      complete: -> clearTimeout(slowResponseTimeout)
      success: =>
        $(@el).addClass('done')
        feedback.text('Bravo!')
        _.delay((-> app.close()), 750)
      error: (data) =>
        $(@el).removeClass('loading')
        msg = if data.status is 401 then 'auth'
        else if not _.isString(data) then 'ajax'
        else if data is 'missing url' then 'url'
        else 'default'
        feedback.text(browser._("add_error_#{msg}"))
    return false


## TagsView

# Handle adding/removing tags and displaying suggested tags.
class TagsView extends CompositeView
  tagName: 'fieldset'
  template: Handlebars.templates.tags

  initialize: (options) ->
    @templateData =
      name: options.name
      value: options.value
      placeholder: options.placeholder
    @delimiter = options.delimiter or ' '
    @allTags = _([])
    app.bookmarks.loaded.then =>
      @allTags = _(app.bookmarks.uniqueTags())

  render: ->
    $(@el).html(@template(@templateData))
    @input = @$('input[name]')
    @autocomplete = @$('.autocomplete input:first-child')
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
    'input input[name]': 'updateAutocomplete'
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
    # If a user presses tab or right-arrow and we have an autocompleted option,
    # select it.
    if event.keyCode in [9, 39] and @autocomplete.val() isnt ''
      @input.val(@autocomplete.val())
      @extractTag()
      return false
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

  updateAutocomplete: ->
    completeText = ''
    val = @input.val()
    if val
      startsWith = (str, starts) ->
        str.length >= starts.length and str.slice(0, starts.length) is starts
      matches = @allTags.filter((tag) -> startsWith(tag, val))
      completeText = matches[0]
    @autocomplete.val(completeText)

  # Extract `length` characters from the beginning of the input box into a new
  # tag object. If `length` is not given, extract the entire input.
  extractTag: (length) =>
    length = @input.val().length unless _.isNumber(length)
    tag = @input.val().slice(0, length).trim()
    if tag
      remainder = @input.val().slice(length).trim()
      @input.val(remainder)
      @updateAutocomplete()
      @add(tag)

  removeTag: (event) =>
    $(event.currentTarget).remove()
    browser.resizePopup?()

  # Handle a click on a suggested tag by adding the tag to the list. Set up a
  # click handler for the newly-added tag to restore visibility to the
  # suggested tag.
  addFromSuggested: (event) =>
    suggested = $(event.currentTarget)
    @add(suggested.hide().text()).click -> suggested.show()

  add: (tag) ->
    @placeholder.hide()
    $(@make('li', {}, tag)).appendTo(@tags)
    browser.resizePopup?()

  addSuggested: (tag) ->
    @suggestedTags.append(@make('li', {id: _.uniqueId()}, tag))
    browser.resizePopup?()

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
    fake = $('<div/>').addClass('pseudo-input').appendTo(@el).css
      position: 'absolute'
      left: -9999
      top: -9999
      whiteSpace: 'nowrap'
      width: 'auto'
    inputWidth = fake.text(@input.val()).width() + padding
    autocompleteWidth = fake.text(@autocomplete.val()).width() + 5
    fakeWidth = Math.max(inputWidth, autocompleteWidth)
    @input.add(@autocomplete).css
      width: Math.min(fakeWidth, $(@el).width())
    fake.remove()


## ConfigView

# The config panel.
class ConfigView extends CompositeView
  tagName: 'div'
  className: 'config'
  template: Handlebars.templates.config

  render: ->
    $(@el).html(@template(app.config))
    _.defer(=> @$('[name=username]').focus()) unless app.config.username
    @service = @$('#service')
    @serviceInput = @service.find('input')
    @knob = @service.find('.knob')
    browser.resizePopup?()
    return this

  # Handle escape keypress: close the panel.
  escape: -> @close()

  events:
    'click #service a': 'chooseService'
    'click #service .switch': 'toggleService'
    'click .close': 'close'
    'submit': 'save'
    'click footer a': 'handleLink'

  chooseService: (event) =>
    choice = $(event.currentTarget).attr('class')
    @serviceInput.val(choice)
    @service.attr('class', choice)

  toggleService: (event) =>
    choice = if @service.attr('class') is 'pinboard' then 'delicious' else 'pinboard'
    @serviceInput.val(choice)
    @service.attr('class', choice)

  # Close the config panel. With valid credentials, return to the default
  # route. Otherwise, close the popup.
  close: ->
    if app.config.validCredentials then app.default() else app.close()

  # Safari doesn't handle regular links in a popover.
  handleLink: (event) ->
    browser.openUrl($(event.currentTarget).attr('href'))

  # Save the config and update the view accordingly.
  save: (event) =>
    app.config.service = @$('[name=service]').val()
    app.config.username = @$('[name=username]').val()
    app.config.password = @$('[name=password]').val()
    app.config.private = @$('[name=private]').is(':checked')
    app.loadCollection()
    $(@el).addClass('loading')
    $('h2').addClass('feedback').html(browser._('config_auth_check'))
    app.config.checkCredentials (valid) =>
      app.config.save()
      if valid
        $('h2').html(browser._('config_auth_success'))
        success = =>
          $(@el).removeClass('loading')
          app.navigate('search', true)
        error = =>
          $(@el).removeClass('loading')
          $('h2').html(browser._('sync_error_connect'))
        app.bookmarks.fetch(success: success, error: error)
      else
        $('h2').text(browser._('config_auth_fail', app.config.serviceName()))
        $(@el).removeClass('loading')
    return false


## Main application router

class Linkhunter extends ElementRouter
  el: $('#panel')

  # Build a collection, populate it from the local cache, and fire off a
  # request for updates in the background.
  initialize: ->
    @config = new Config
    @config.loaded.then =>
      @loadCollection().loaded.then =>
        if @config.validCredentials
          @bookmarks?.fetchIfStale()
      Backbone.history.start()
    $(window).on('keydown', @handleEscapeKey)
    # When clicking outside of the panel, close the app (this saves trying to
    # resize the iframe to match the app size).
    $(@el).on('click', (event) -> event.stopPropagation())
    $(window).on('click', @close)

  loadCollection: ->
    @bookmarks = @config.createCollection()

  # Escape keypresses must be caught on the window, rather than on a given
  # element. Do so here, handing off to the current view.
  handleEscapeKey: (event) =>
    if event.keyCode is 27
      @currentView.escape()
      return false

  close: ->
    browser.closePopup()

  routes:
    '': 'default'
    'search': 'search'
    'add': 'add'
    'config': 'editConfig'

  # Redirect to the config panel unless we have valid credentials.
  guard: (fn) ->
    if @config.validCredentials then fn() else @navigate('config', true)

  default: ->
    @guard(=> @navigate('search', true))

  search: ->
    @guard(=> @show(new SearchView(bookmarks: @bookmarks)))

  add: ->
    @guard(=> @show(new AddView))

  editConfig: ->
    @show(new ConfigView)



this.browser = Browser.getCurrent()
this.app = new Linkhunter
