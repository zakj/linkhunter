export function getSelectedTab() {
  const queryInfo = {active: true, currentWindow: true};
  return new Promise(resolve => chrome.tabs.query(queryInfo, resolve));
};

export function openUrl({url, background=false}) {
  if (background) {
    chrome.tabs.create({url, active: false});
  }
  else {
    chrome.tabs.update({url});
    window.close();
  }
};

export function sendMessage(msg) {
  return new Promise(resolve => chrome.runtime.sendMessage(msg, resolve));
};

export const storage = {
  get: (...keys) => new Promise(resolve => chrome.storage.local.get(keys, resolve)),
  set: items => new Promise(resolve => chrome.storage.local.set(items, resolve)),
  remove: (...keys) => new Promise(resolve => chrome.storage.local.remove(keys, resolve)),
  addListener: fn => chrome.storage.onChanged.addListener(fn),
};
