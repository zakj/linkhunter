# Listen for Chrome extension messages. Each message should be an object with a
# `method` attribute. Other object attributes vary based on the method.
# "getItem" and "setItem" provide an interface to localStorage (as content
# scripts cannot access it directly). "createTab" opens a new background tab.
# "enableInPagePopup" removes the default popup from the browser action button,
# allowing our listener below to open the popup in an iframe. "closePopup"
# creates a new message to the content script to close the iframe.
chrome.extension.onMessage.addListener (message, sender, sendResponse) ->
  switch message.method
    when 'getItem'
      sendResponse(localStorage.getItem(message.key))
    when 'setItem'
      sendResponse(localStorage.setItem(message.key, message.value))
    when 'getCurrentTab'
      chrome.tabs.getSelected null, (tab) ->
        sendResponse(tab)
    when 'createTab'
      chrome.tabs.create(url: message.url, selected: false)
      sendResponse()
    when 'enableInPagePopup'
      chrome.tabs.getSelected null, (tab) ->
        # Ignore chrome tabs, where we can't modify the page.
        return if tab.url.indexOf('chrome://') is 0
        chrome.browserAction.setPopup(tabId: tab.id, popup: '')
      sendResponse()
    when 'closePopup'
      chrome.tabs.getSelected null, (tab) ->
        chrome.tabs.sendMessage(tab.id, 'closePopup')
      sendResponse()
    else return false
  return true


# Listen for toolbar button clicks to toggle the popup in the active tab.
chrome.browserAction.onClicked.addListener (tab) ->
  chrome.tabs.sendMessage(tab.id, 'togglePopup')
