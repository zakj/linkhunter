# Listen for Chrome extension requests. Each request should be an object with a
# `method` attribute. Other object attributes vary based on the method.
# "getItem" and "setItem" provide an interface to localStorage (as content
# scripts cannot access it directly). "createTab" opens a new background tab.
# "togglePopup" opens or closes the Linkhunter popup in the active tab.
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
      sendResponse(null)
    when 'togglePopup'
      chrome.tabs.getSelected null, (tab) ->
        chrome.tabs.sendRequest(tab.id, 'togglePopup')
      sendResponse(null)


# Listen for toolbar button clicks to toggle the popup in the active tab.
chrome.browserAction.onClicked.addListener (tab) ->
  chrome.tabs.sendRequest(tab.id, 'togglePopup')
