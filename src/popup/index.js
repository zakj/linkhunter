import { sendMessage, storage } from '../browser';
import './popup';

const popup = document.querySelector('lh-popup');


storage.addListener(changes => {
  if ('bookmarks' in changes) {
    popup.bookmarks = changes.bookmarks.newValue;
  }
});

storage.get('bookmarks', 'token').then(({bookmarks, token}) => {
  if (!token) {
    // TODO: auth directly here instead?
    sendMessage({type: 'showOptions'});
    window.close();
    return;
  }

  sendMessage({type: 'updateBookmarks'});

  if (bookmarks) {
    popup.bookmarks = bookmarks;
    // TODO: delay?
    document.body.classList.add('loaded');
  }
});
