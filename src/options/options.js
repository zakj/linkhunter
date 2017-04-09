import { Component } from 'panel';

import { sendMessage, storage } from '../browser';
import template from './options.jade';


document.registerElement('lh-options', class extends Component {
  get config() {
    return {
      defaultState: {
        token: null,
      },

      helpers: {
        username: () => this.state.token ? this.state.token.split(':')[0] : null,
        logIn: () => sendMessage({type: 'updateToken'}),
        logOut: () => storage.remove('token'),
      },

      template,
    };
  }

  attributeChangedCallback(name, oldVal, newVal) {
    if (name in this.state) {
      this.update({[name]: newVal});
    }
  }
});
