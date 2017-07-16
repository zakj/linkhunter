import _ from 'lodash/fp';
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

    mostCommonTags(state) {
      return _.flow([
        _.flatMap(b => b.tags),
        _.groupBy(tag => tag),
        _.mapValues(tags => tags.length),
        _.toPairs,
        _.sortBy(([_tag, count]) => -count),
        _.map(([tag, _count]) => tag),
      ])(state.bookmarks);
    },
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
      if (error.hasOwnProperty('message')) {
        state.pinboardError = error.message;
      }
      else {
        state.pinboardError = error.toString();
      }
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
    store.commit('syncBrowser', _.mapValues(v => v.newValue, changes));
  });

  storage.get(...Object.keys(store.state)).then(changes => {
    store.commit('syncBrowser', changes);
    resolve();
  });
});

export default store;
