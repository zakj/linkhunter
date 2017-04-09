import { Component } from 'panel';

import { sendMessage } from '../browser';
import template from './popup.jade';

// Used for parsing URLs in iconFor.
const linkEl = document.createElement('a');


document.registerElement('lh-popup', class extends Component {
  get config() {
    return {
      defaultState: {
        bookmarks: [],
        filterString: '',
      },

      helpers: {
        filteredBookmarks: () => {
          const query = this.state.filterString;
          if (!query) return this.state.bookmarks;
          // Words in the query string are separated by whitespace and/or
          // commas. Each words must match a bookmark's tags or description.
          const regexps = query.split(/[, ]+/).map(word => new RegExp(word, 'i'));
          // TODO optimize for displaying only visible results
          return this.state.bookmarks.filter(b => {
            const s = [b.tags, b.description].join(' ');
            return regexps.every(re => re.test(s));
          });
        },

        handleBookmarkClick: (ev, url) => {
          // TODO: openUrl({url, background: ev.metaKey || ev.ctrlKey});
          if (ev.metaKey || ev.ctrlKey) {
            chrome.tabs.create({url, active: false});
          }
          else {
            chrome.tabs.update({url});
            window.close();
          }
        },

        handleKeyDown: ev => {
          if (ev.key === 'Escape' && !this.state.filterString) {
            window.close();
          }
          else if (ev.key === 'Enter') {
            // TODO
            // url = filteredBookmarks[selectedIndex]
            // openUrl({url, background: ev.metaKey || ev.ctrlKey});
          }
        },

        handleOptionsClick: () => {
          sendMessage({type: 'showOptions'});
          window.close();
        },

        handleSearchInput: ev => {
          this.update({filterString: ev.target.value});
        },

        iconFor: (url) => {
          linkEl.href = url;
          return `https://icons.duckduckgo.com/ip2/${linkEl.host}.ico`;
        },

        refocus: ev => ev.target.focus(),
      },

      template,
    };
  }

  get bookmarks() {
    return this.state.bookmarks;
  }

  set bookmarks(bookmarks) {
    this.update({bookmarks});
  }
});
