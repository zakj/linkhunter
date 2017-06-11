import {checkLoggedIn, suggestTags, updateBookmarks, updateToken} from '@/pinboard';
import {storage} from '@/browser';

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  const [isAsync, handler] = {
    checkLoggedIn:   [true,  () => checkLoggedIn().then(sendResponse)],
    setToken:        [false, () => storage.set({token: request.token})],
    suggestTags:     [true,  () => suggestTags(request.url).then(sendResponse)],
    updateBookmarks: [false, updateBookmarks],
    updateToken:     [false, updateToken],
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
