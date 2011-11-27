# Listen for requests to open or close the popup.
chrome.extension.onRequest.addListener (request, sender, sendResponse) ->
  if request is 'togglePopup'
    togglePopupIframe()
    sendResponse({})


# Open the popup on ⌘J.
window.addEventListener 'keydown', (event) ->
  otherModifiers = (event.altKey or event.ctrlKey or event.shiftKey)
  if event.metaKey and event.keyCode is 74 and not otherModifiers
    togglePopupIframe()


# Open a popup iframe and inject the appropriate CSS. If a popup already
# exists, remove it.
togglePopupIframe = ->
  # Do nothing in subframes, to avoid multiple popups.
  return unless window is top
  className = 'linkhunter-iframe'
  frame = document.querySelector(".#{className}")
  if frame
    frame.parentNode.removeChild(frame)
  else
    css = document.createElement('link')
    css.rel = 'stylesheet'
    css.href = chrome.extension.getURL('iframe.css')
    document.querySelector('head').appendChild(css)
    frame = document.createElement('iframe')
    frame.className = className
    frame.src = chrome.extension.getURL('popup.html')
    document.querySelector('body').appendChild(frame)
  return false
