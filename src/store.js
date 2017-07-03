import mapValues from 'lodash/fp/mapValues';
import Vue from 'vue';
import Vuex from 'vuex';

import {storage} from './browser';

Vue.use(Vuex);

const store = new Vuex.Store({
  strict: process.env.NODE_ENV !== 'production',

  state: {
    bookmarks: [],
    defaultPrivate: false,
    pinboardError: null,
    token: null,
    updateTime: null,
  },

  getters: {
    username: state => state.token ? state.token.split(':')[0] : null,
  },

  mutations: {
    clearPinboardError(state) {
      state.pinboardError = null;
    },

    clearToken(state) {
      state.token = null;
      storage.set({token: null});
    },

    setPinboardError(state, error) {
      state.pinboardError = 'message' in error ? error.message : error.toString();
    },

    setBookmarks(state, bookmarks) {
      state.bookmarks = bookmarks;
      storage.set({bookmarks});
    },

    setUpdateTime(state, updateTime) {
      state.updateTime = updateTime;
    },

    syncBrowser(state, changes) {
      // This will be called redundantly after one of the other mutations runs,
      // but that's ok---dirty checking will make it a no-op.
      Object.keys(state).forEach(v => {
        if (v in changes) {
          state[v] = changes[v];
        }
      });
    },

    toggleDefaultPrivate(state) {
      state.defaultPrivate = !state.defaultPrivate;
      storage.set({defaultPrivate: state.defaultPrivate});
    },
  },
});

store.hydrate = new Promise(resolve => {
  storage.addListener(changes => {
    store.commit('syncBrowser', mapValues(v => v.newValue, changes));
  });

  storage.get(...Object.keys(store.state)).then(changes => {
    store.commit('syncBrowser', changes);
    resolve();
  });
});

export default store;
