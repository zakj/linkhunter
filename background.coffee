# Listen for Chrome extension requests. Each request should be an object with a
# `method` attribute. Other object attributes vary based on the method.
# "getItem" and "setItem" provide an interface to localStorage (as content
# scripts cannot access it directly). "createTab" opens a new background tab.
# "enableInPagePopup" removes the default popup from the browser action button,
# allowing our listener below to open the popup in an iframe. "closePopup"
# creates a new request to the content script to close the iframe.
chrome.extension.onRequest.addListener (request, sender, sendResponse) ->
  switch request.method
    when 'getItem'
      sendResponse(localStorage.getItem(request.key))
    when 'setItem'
      sendResponse(localStorage.setItem(request.key, request.value))
    when 'getCurrentTab'
      chrome.tabs.getSelected null, (tab) ->
        sendResponse(tab)
    when 'createTab'
      chrome.tabs.create(url: request.url, selected: false)
      sendResponse()
    when 'enableInPagePopup'
      chrome.tabs.getSelected null, (tab) ->
        chrome.browserAction.setPopup(tabId: tab.id, popup: '')
      sendResponse()
    when 'closePopup'
      chrome.tabs.getSelected null, (tab) ->
        chrome.tabs.sendRequest(tab.id, 'closePopup')
      sendResponse()


# Listen for toolbar button clicks to toggle the popup in the active tab.
chrome.browserAction.onClicked.addListener (tab) ->
  chrome.tabs.sendRequest(tab.id, 'togglePopup')
