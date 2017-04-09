import './options';
import { storage } from '../browser';

const options = document.querySelector('lh-options');

function setToken(token) {
  if (token) {
    options.setAttribute('token', token); 
  }
  else {
    options.removeAttribute('token');
  }
}

storage.addListener(changes => {
  if ('token' in changes) {
    setToken(changes.token.newValue);
  }
});

storage.get('token').then(({token}) => setToken(token));
