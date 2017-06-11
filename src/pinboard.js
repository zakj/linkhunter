import flattenDeep from 'lodash/fp/flattenDeep';
import uniq from 'lodash/fp/uniq';

import {storage} from '@/browser';


// https://pinboard.in/api
const PINBOARD = {
  all: 'https://api.pinboard.in/v1/posts/all',
  password: 'https://pinboard.in/settings/password',
  suggest: 'https://api.pinboard.in/v1/posts/suggest',
  update: 'https://api.pinboard.in/v1/posts/update',
};

function queryString(obj) {
  return Object.entries(obj).map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&');
}

function query(url, params) {
  params = params || {};
  return storage.get('token').then(({token}) => {
    if (!token) throw new Error('missing token');  // TODO handle this?
    params.auth_token = token;  // eslint-disable-line camelcase
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


// Exports.

export function checkLoggedIn() {
  return fetch(PINBOARD.password, {credentials: 'include'})
    .then(response => response.ok && response.url === PINBOARD.password);
}

export function suggestTags(url) {
  return query(PINBOARD.suggest, {url})
    .then(json => uniq(flattenDeep(json.map(Object.values))));
}

export function updateBookmarks() {
  // TODO throttle? careful: events.js is unloaded when idle for ~2s
  return storage.get('updateTime').then(({updateTime}) => {
    query(PINBOARD.update).then(json => {
      const latestUpdateTime = json.update_time;
      if (latestUpdateTime !== updateTime) {
        storage.set({updateTime: latestUpdateTime});
        query(PINBOARD.all).then(response => storage.set({bookmarks: response}));
      }
    });
  });
}

export function updateToken() {
  return checkLoggedIn().then(isLoggedIn => {
    if (isLoggedIn) {
      chrome.tabs.create({url: PINBOARD.password, active: false}, tab => {
        chrome.tabs.executeScript(tab.id,
          {
            file: 'find-api-token.js',
            runAt: 'document_end',
          },
          // Defer closing until sendMessage can complete.
          () => setTimeout(() => chrome.tabs.remove([tab.id]), 250)
        );
      });
    }
    else {
      // TODO
      console.warn('not logged in to Pinboard');
    }
  });
}
