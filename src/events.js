// https://pinboard.in/api
const API = {
  update: 'https://api.pinboard.in/v1/posts/update',
  recent: 'https://api.pinboard.in/v1/posts/recent',
}

// Promise-based chrome.storage helpers.
const storage = {
  get: keys => new Promise(resolve => chrome.storage.local.get(keys, resolve)),
  set: items => new Promise(resolve => chrome.storage.local.set(items, resolve)),
}

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

function handleMessage(request, sender, sendResponse) {
  switch (request.type) {
  case 'updateToken':
    storage.set({token: request.token});
    break;
  default:
    console.warn('unknown message', request);
  }
}

chrome.runtime.onMessage.addListener(handleMessage);

storage.get('updateTime').then(s => {
  query(API.update).then(json => {
    const latestUpdateTime = json.update_time;
    if (latestUpdateTime !== s.updateTime) {
      storage.set({updateTime: latestUpdateTime});
      query(API.recent).then(response => storage.set({bookmarks: response.posts}));
    }
  });
});




const PINBOARD_PASSWORD_URL = 'https://pinboard.in/settings/password';
fetch(PINBOARD_PASSWORD_URL, {credentials: 'include'}).then(response => {
  if (!response.ok || response.url !== PINBOARD_PASSWORD_URL) {
    console.warn('not logged in');
  }
  else {
    console.log('logged in');
  }
});
