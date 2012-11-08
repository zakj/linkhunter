handleMessage = (event) ->
  if event.name is 'showPopover'
    safari.extension.toolbarItems[0].showPopover()
safari.application.addEventListener('message', handleMessage, false)
