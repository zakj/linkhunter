export function fetchPinboardToken() {
  const url = 'https://pinboard.in/settings/password';
  chrome.tabs.create({url, active: false}, tab => {
    chrome.tabs.executeScript(tab.id,
      {
        file: 'find-api-token.js',
        runAt: 'document_end',
      },
      // Defer closing until sendMessage in find-api-token.js can complete.
      () => setTimeout(() => chrome.tabs.remove([tab.id]), 250)
    );
  });
}

export function getKeyboardShortcut() {
  return new Promise(resolve => {
    chrome.commands.getAll(commands => {
      const action = commands.find(c => c.name === '_execute_browser_action');
      resolve(action && action.shortcut);
    });
  });
}

export function getSelectedTab() {
  const queryInfo = {active: true, currentWindow: true};
  return new Promise(resolve => {
    chrome.tabs.query(queryInfo, tabs => resolve(tabs[0]));
  });
}

export function openUrl({url, background=false}) {
  if (background) {
    chrome.tabs.create({url, active: false});
  }
  else {
    chrome.tabs.update({url});
    window.close();
  }
}

export function sendMessage(msg) {
  return new Promise(resolve => chrome.runtime.sendMessage(msg, resolve));
}

export const storage = {
  get: (...keys) => new Promise(resolve => chrome.storage.local.get(keys, resolve)),
  set: items => new Promise(resolve => chrome.storage.local.set(items, resolve)),
  remove: (...keys) => new Promise(resolve => chrome.storage.local.remove(keys, resolve)),
  addListener: fn => chrome.storage.onChanged.addListener(fn),
};
