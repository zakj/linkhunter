import { authenticate, checkLoggedIn, suggestTags, updateBookmarks } from './pinboard';
import { storage } from './browser';

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  const [isAsync, handler] = {
    checkLoggedIn:   [false, checkLoggedIn],  // TODO unused
    setToken:        [false, () => storage.set({token: request.token})],
    showOptions:     [false, () => chrome.runtime.openOptionsPage()],
    suggestTags:     [true,  () => suggestTags(request.url).then(sendResponse)],
    updateBookmarks: [false, updateBookmarks],
    updateToken:     [false, authenticate],
  }[request.type];
  if (handler) {
    handler();
    return isAsync;  // wait for sendResponse if needed
  }
  console.warn('unknown message', request);
});

// TODO: on upgrade, check for existing delicious bookmarks in localstorage.
// add a link to download them as HTML bookmarks, eg
// <li><a href="{{href}}" time_added="{{seconds}}" tags="{{tags}}">{{title}</a></li>
// and instructions for pinboard import. how to handle private?
