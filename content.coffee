# Listen for requests to open or close the popup.
chrome.extension.onRequest.addListener (request, sender, sendResponse) ->
  switch request
    when 'openPopup' then iframe.open()
    when 'closePopup' then iframe.close()
    when 'togglePopup' then iframe.toggle()
    # Don't sendResponse unless we handled the request.
    else return
  sendResponse()


# Instruct the background page to intercept the default popup and open in an
# iframe instead, so long as we have a body to which we can append (frameset
# pages do not, and aren't worth fighting for).
if document.querySelector('body')
  chrome.extension.sendRequest(method: 'enableInPagePopup')


# Open the popup on ⌘J.
window.addEventListener 'keydown', (event) ->
  otherModifiers = (event.altKey or event.ctrlKey or event.shiftKey)
  if event.metaKey and event.keyCode is 74 and not otherModifiers
    iframe.open()


# Manage opening and closing the popup in an iframe.
iframe =
  className: 'linkhunter-iframe'
  el: document.querySelector(".#{@className}")

  open: ->
    if not @el?
      css = document.createElement('link')
      css.rel = 'stylesheet'
      css.href = chrome.extension.getURL('iframe.css')
      document.querySelector('head').appendChild(css)
      @el = document.createElement('iframe')
      @el.className = @className
      @el.src = chrome.extension.getURL('popup.html')
    document.querySelector('body').appendChild(@el)

  close: ->
    return unless @el?.parentNode?
    @el.parentNode.removeChild(@el)

  toggle: ->
    if @el?.parentNode? then @close() else @open()
