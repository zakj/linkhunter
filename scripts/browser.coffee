# Abstracts some of the browser-extension APIs.
class Browser

  # Class method to fetch the appropriate subclass.
  @getCurrent: ->
    browsers =
      'chrome': Chrome
      'safari': Safari
    for own name, cls of browsers
      if window[name]?
        $('body').addClass(name)  # allow custom styling
        return new cls
    throw 'Unknown browser'

  # Shortcut for i18n.
  _: -> @getMessage.apply(this, arguments)


# Expose a localStorage-like interface to the extension's background page,
# except that `getItem` and `setItem` return `Promise` objects.
class ChromeStorage

  _promiseRequest: (message) ->
    d = new $.Deferred
    chrome.extension.sendMessage(message, d.resolve)
    d.promise()

  getItem: (key) ->
    @_promiseRequest(method: 'getItem', key: key)

  setItem: (key, value) ->
    @_promiseRequest(method: 'setItem', key: key, value: value)


# Just wrap `localStorage` in `Promise`, to match Chrome's interface.
class SafariStorage

  getItem: (key) ->
    d = new $.Deferred
    # Deferring to match Chrome, which doesn't insta-resolve.
    _.defer -> d.resolve(localStorage.getItem(key))
    d.promise()

  setItem: (key, value) ->
    d = new $.Deferred
    d.resolve(localStorage.setItem(key, value))
    d.promise()


class Chrome extends Browser

  constructor: ->
    @iframed = window isnt top
    $('body').addClass('in-iframe') if @iframed

  storage: new ChromeStorage

  # Return the localized string for the given message name.
  getMessage: (name, args...) ->
    chrome.i18n.getMessage(name, XXX)

  # Close the popup or remove the iframe.
  closePopup: ->
    if @iframed
      chrome.extension.sendMessage(method: 'closePopup')
    else
      window.close()

  # Navigate to the given URL, closing the popover if necessary.
  openUrl: (url) ->
    if @iframed
      top.location.href = url
    else
      chrome.tabs.getSelected null, (tab) ->
        chrome.tabs.update(tab.id, url: url)
      window.close()

  openBackgroundTab: (url) ->
    chrome.extension.sendMessage(method: 'createTab', url: url)

  # Call `callback(url, title)` with data from the current tab.
  getCurrentTabUrlAndTitle: (callback) ->
    chrome.extension.sendMessage method: 'getCurrentTab', (tab) ->
      callback(tab.url, tab.title)


class Safari extends Browser

  constructor: ->
    @popover = safari.extension.popovers.linkhunter
    fetchBookmarks = -> app.bookmarks?.fetchIfStale()
    safari.application.addEventListener('popover', fetchBookmarks, true)

  storage: new SafariStorage

  getMessage: (name, args...) ->
    "MESSAGE: #{name}"  # XXX

  closePopup: ->
    @popover.hide()
    # Since Safari popovers are long-lived, reset the app state. This method
    # doesn't get called if the user clicks away from the popover, rather than
    # explicitly closing it. TODO: Decide whether that's desirable or not. If
    # not, just hide the popover in this method, and instead reset to the
    # default view in safari.application's "popover" event.
    app.default()
    app.currentView?.clearInput?()

  resizePopup: -> _.defer =>
    @popover.height = $('#panel').outerHeight()

  openUrl: (url) ->
    safari.application.activeBrowserWindow.activeTab.url = url
    @closePopup()

  openBackgroundTab: (url) ->
    tab = safari.application.activeBrowserWindow.openTab('background')
    tab.url = url

  getCurrentTabUrlAndTitle: (callback) ->
    tab = safari.application.activeBrowserWindow.activeTab
    _.defer -> callback(tab.url, tab.title)
