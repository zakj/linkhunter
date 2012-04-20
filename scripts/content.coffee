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
  modifiers = (event.metaKey or event.ctrlKey)
  otherModifiers = (event.altKey or event.shiftKey)
  if modifiers and not otherModifiers and event.keyCode is 66
    iframe.open()


# Manage opening and closing the popup in an iframe. A div wrapping the iframe
# is used to provide a fixed-position context for the pop-in animation. Without
# a container, the animation's origin is relative to the body, so the page
# scrolls to the top when Linkhunter opens.
iframe =
  id: 'linkhunter-iframe-container'
  el: document.querySelector("##{@id}")

  open: ->
    if not @el?
      css = document.createElement('link')
      css.rel = 'stylesheet'
      css.href = chrome.extension.getURL('styles/iframe.css')
      document.querySelector('body').appendChild(css)
      @el = document.createElement('div')
      @el.id = @id
      frame = document.createElement('iframe')
      frame.src = chrome.extension.getURL('popup.html')
      @el.appendChild(frame)
    document.querySelector('body').appendChild(@el)
    closeOnClick = (event) ->
      document.removeEventListener('click', closeOnClick)
      iframe.close()
    document.addEventListener('click', closeOnClick)

  close: ->
    return unless @el?.parentNode?
    @el.parentNode.removeChild(@el)

  toggle: ->
    if @el?.parentNode? then @close() else @open()
