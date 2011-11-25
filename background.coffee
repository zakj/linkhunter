## Local storage proxy

# Listen for Chrome extension requests to get or set values in localStorage
# (extension content scripts do not have access to localStorage). Requests take
# one of the following forms:
#
#   {'get': 'itemName'}
#   {'set': 'itemName', 'value': 'itemValue'}
chrome.extension.onRequest.addListener (request, sender, sendResponse) ->
  switch request.method
    when 'getItem'
      sendResponse(localStorage.getItem(request.key))
    when 'setItem'
      sendResponse(localStorage.setItem(request.key, request.value))
