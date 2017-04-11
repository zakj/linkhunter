import { Component } from 'panel';

import { sendMessage } from '../browser';
import template from './popup.jade';
import './popup.styl';

// Used for parsing URLs in iconFor.
const linkEl = document.createElement('a');


// Words in the query string are separated by whitespace and/or commas. Every
// word in the query must match in a bookmark's tags or description.
function filterBookmarks(query, bookmarks) {
  if (!query) return bookmarks;
  const regexps = query.split(/[, ]+/).map(word => new RegExp(word, 'i'));
  // TODO optimize for displaying only visible results
  return bookmarks.filter(b => {
    const s = [b.tags, b.description].join(' ');
    return regexps.every(re => re.test(s));
  });
}


// TODO extract into browser.js
function openUrl({url, background=false}) {
  if (background) {
    chrome.tabs.create({url, active: false});
  }
  else {
    chrome.tabs.update({url});
    window.close();
  }
}


document.registerElement('lh-popup', class extends Component {
  get config() {
    return {
      defaultState: {
        bookmarks: [],
        filterString: '',
        selectedIndex: 0,
      },

      helpers: {
        filteredBookmarks: () => {
          return filterBookmarks(this.state.filterString, this.state.bookmarks);
        },

        handleBookmarkClick: (ev, url) => {
          openUrl({url, background: ev.metaKey || ev.ctrlKey});
        },

        handleKeyDown: ev => {
          const handler = {
            Escape: () => !this.state.filterString && window.close(),
            Enter: () => {
              const url = this.helpers.filteredBookmarks()[this.state.selectedIndex].href;
              openUrl({url, background: ev.metaKey || ev.ctrlKey});
            },
            ArrowDown: () => {
              this.update({
                selectedIndex: Math.min(
                  this.helpers.filteredBookmarks().length - 1,
                  this.state.selectedIndex + 1
                ),
              });
            },
            ArrowUp: () => {
              this.update({selectedIndex: Math.max(0, this.state.selectedIndex - 1)});
            },
          }[ev.key];
          handler && handler();
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
