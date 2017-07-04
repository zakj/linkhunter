import flattenDeep from 'lodash/fp/flattenDeep';
import uniq from 'lodash/fp/uniq';

import store from '@/store';

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
  return store.hydrate.then(() => {
    if (!store.state.token) throw new Error('missing Pinboard token');
    params = params || {};
    params.auth_token = store.state.token;  // eslint-disable-line camelcase
    params.format = 'json';
    return fetch(`${url}?${queryString(params)}`)
      .then(response => {
        if (!response.ok) {
          // TODO backoff on response.status === 429
          throw new Error(response);
        }
        return response.json();
      })
      .catch(error => {
        store.commit('setPinboardError', error);
        throw error;
      });
  });
}


// Exports.

export function getLoggedIn() {
  return fetch(PINBOARD.password, {credentials: 'include'})
    .then(response => response.ok && response.url === PINBOARD.password)
    .catch(error => {
      store.commit('setPinboardError', error);
      throw error;
    });
}

export function getSuggestedTags(url) {
  return query(PINBOARD.suggest, {url})
    .then(json => uniq(flattenDeep(json.map(Object.values))));
}

export function updateBookmarks() {
  // TODO throttle? careful: events.js is unloaded when idle for ~2s
  store.hydrate.then(() => {
    const updateTime = store.state.updateTime;
    query(PINBOARD.update).then(json => {
      const latestUpdateTime = json.update_time;
      if (latestUpdateTime !== updateTime) {
        query(PINBOARD.all).then(bookmarks => {
          bookmarks = bookmarks.map(bookmark => {
            bookmark.tags = bookmark.tags.split();
            return bookmark;
          });
          store.commit('setBookmarks', bookmarks);
        });
      }
    });
  });
}
