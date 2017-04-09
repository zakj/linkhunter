import { storage } from './browser';

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  const handler = {
    checkLoggedIn: () => checkLoggedIn().then(sendResponse),  // TODO unused
    updateToken: authenticate,
    setToken: () => storage.set({token: request.token}),
    showOptions: () => chrome.runtime.openOptionsPage(),
    updateBookmarks,
  }[request.type];
  handler ? handler() : console.warn('unknown message', request);
});

// TODO: on upgrade, check for existing delicious bookmarks in localstorage.
// add a link to download them as HTML bookmarks, eg
// <li><a href="{{href}}" time_added="{{seconds}}" tags="{{tags}}">{{title}</a></li>
// and instructions for pinboard import. how to handle private?

// https://pinboard.in/api
const PINBOARD = {
  password: 'https://pinboard.in/settings/password',
  all: 'https://api.pinboard.in/v1/posts/all',
  update: 'https://api.pinboard.in/v1/posts/update',
};

function query(url, params) {
  params = params || {};
  return storage.get('token').then(({token}) => {
    if (!token) throw new Error('missing token');  // TODO handle this?
    params.auth_token = token;
    params.format = 'json';
    return fetch(`${url}?${queryString(params)}`)
      .then(response => {
        if (!response.ok) {
          // TODO backoff on response.status === 429
          // TODO user notification?
          throw new Error(response);  // TODO handle this?
        }
        return response.json();
      });
  });
}

function queryString(obj) {
  return Object.entries(obj).map(([k, v]) => `${k}=${v}`).join('&');
}

function updateBookmarks() {
  // TODO throttle? careful: events.js is unloaded when idle for ~2s
  storage.get('updateTime').then(({updateTime}) => {
    query(PINBOARD.update).then(json => {
      const latestUpdateTime = json.update_time;
      if (latestUpdateTime !== updateTime) {
        storage.set({updateTime: latestUpdateTime});
        query(PINBOARD.all).then(response => storage.set({bookmarks: response}));
      }
    });
  });
}

function checkLoggedIn() {
  return fetch(PINBOARD.password, {credentials: 'include'})
    .then(response => response.ok && response.url === PINBOARD.password);
}

function tabCreated(tab) {
  chrome.tabs.executeScript(tab.id,
    {
      file: 'find-api-token.js',
      runAt: 'document_end',
    },
    // Defer closing until sendMessage can complete.
    () => setTimeout(() => chrome.tabs.remove([tab.id]), 250));
}

function authenticate() {
  checkLoggedIn().then(isLoggedIn => {
    if (isLoggedIn) {
      storage.get('token').then(({token}) => {
        if (token) return;
        chrome.tabs.create(
          {url: PINBOARD.password, active: false},
          tabCreated);
      });
    }
    else {
      // TODO
      console.warn('not logged in to Pinboard');
    }
  });
}
