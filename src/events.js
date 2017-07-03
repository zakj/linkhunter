import {storage, fetchPinboardToken} from '@/browser';

chrome.runtime.onMessage.addListener(request => {
  const handler = {
    fetchPinboardToken,
    setPinboardToken: () => storage.set({token: request.token}),
  }[request.type];
  if (handler) handler();
  else throw new Error(`unknown message ${request}`);
});
