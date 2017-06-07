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
    token: null,
  },

  getters: {
    username: state => state.token ? state.token.split(':')[0] : null,
  },

  mutations: {
    // addBookmark(state, bookmark) {
    //   state.bookmarks.push(bookmark);  // XXX needed?
    //   // XXX storage
    // },

    changeBookmarks(state, bookmarks) {
      state.bookmarks = bookmarks;
      storage.set({bookmarks});
    },

    changeDefaultPrivate(state, defaultPrivate) {
      state.defaultPrivate = defaultPrivate;
      storage.set({defaultPrivate});
    },

    changeToken(state, token) {
      state.token = token;
      storage.set({token});
    },

    updateFromBrowser(state, changes) {
      // This will be called redundantly after one of the above mutations runs,
      // but that's ok---dirty checking will make it a no-op.
      ['bookmarks', 'defaultPrivate', 'token'].forEach(v => {
        if (v in changes) {
          state[v] = changes[v];
          // Vue.set(state, v, changes[v]);
        }
      });
    },
  },
});

store.hydrated = new Promise(resolve => {
  storage.addListener(changes => {
    store.commit('updateFromBrowser', mapValues(v => v.newValue, changes));
  });

  storage.get('bookmarks', 'defaultPrivate', 'token').then(changes => {
    store.commit('updateFromBrowser', changes);
    resolve();
  });
});

export default store;
