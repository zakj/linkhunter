export function sendMessage(msg) {
  return new Promise(resolve => chrome.runtime.sendMessage(msg, resolve));
};

export const storage = {
  get: (...keys) => new Promise(resolve => chrome.storage.local.get(keys, resolve)),
  set: items => new Promise(resolve => chrome.storage.local.set(items, resolve)),
  remove: (...keys) => new Promise(resolve => chrome.storage.local.remove(keys, resolve)),
  addListener: fn => chrome.storage.onChanged.addListener(fn),
};
