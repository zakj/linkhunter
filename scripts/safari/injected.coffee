# TODO: This should be customizable, and prettier.
handleKeyDown = (event) ->
  cmd = event.metaKey
  otherMods = (event.altKey or event.ctrlKey or event.shiftKey)
  if cmd and not otherMods and event.keyCode is 74  # "cmd-j"
    event.preventDefault()
    event.stopPropagation()
    safari.self.tab.dispatchMessage('showPopover')
document.addEventListener('keydown', handleKeyDown, false)
