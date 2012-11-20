handleMessage = (event) ->
  if event.name is 'showPopover'
    for toolbarItem in safari.extension.toolbarItems
      if toolbarItem.browserWindow is event.target.browserWindow
        toolbarItem.showPopover()
safari.application.addEventListener('message', handleMessage, false)
